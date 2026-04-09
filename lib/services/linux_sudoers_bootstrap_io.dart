import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// v2: includes [awg-quick] (AmneziaWG) alongside route helper; uses NOPASSWD:SETENV for [sudo -E].
const _prefsInstalled = 'linux_vpn_sudoers_v2_installed';
const _prefsPathSig = 'linux_vpn_sudoers_v2_path_sig';

final _safeUserRe = RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._-]{0,31}$');

bool _safeUnixUser(String u) => _safeUserRe.hasMatch(u);

bool _safeAbsPath(String path) {
  if (!path.startsWith('/') || path.contains('\n') || path.length > 4096) {
    return false;
  }
  if (path.contains(' ') || path.contains('..')) {
    return false;
  }
  return true;
}

String _shellSingleQuote(String s) => "'${s.replaceAll("'", "'\\''")}'";

/// Paths to bundled helpers next to the executable (see [linux/CMakeLists.txt]).
List<String> _bundleVpnCmdPaths() {
  final out = <String>[];
  try {
    final exe = File(Platform.resolvedExecutable);
    final dir = exe.parent.path;
    final routes = p.join(dir, 'asteriaray-vpn-routes.sh');
    if (File(routes).existsSync()) out.add(routes);
    final awg = p.join(dir, 'awg-quick');
    if (File(awg).existsSync()) out.add(awg);
  } catch (_) {}
  out.sort();
  return out.where(_safeAbsPath).toList();
}

String _pathSignature(List<String> paths) => paths.join('|');

/// One-time [pkexec] to install [asteriaray-vpn] sudoers so [sudo -n] / [sudo -n -E] work (no password spam).
Future<void> linuxBootstrapSudoersIfNeeded() async {
  if (kIsWeb || !Platform.isLinux) return;

  final paths = _bundleVpnCmdPaths();
  if (paths.isEmpty) {
    debugPrint('linuxBootstrapSudoers: no bundled helpers (asteriaray-vpn-routes.sh / awg-quick) next to binary');
    return;
  }

  final user = Platform.environment['USER'] ?? Platform.environment['LOGNAME'] ?? '';
  if (user.isEmpty || !_safeUnixUser(user)) {
    debugPrint('linuxBootstrapSudoers: USER not set or unsafe, skip');
    return;
  }

  final sig = _pathSignature(paths);
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_prefsInstalled) == true && prefs.getString(_prefsPathSig) == sig) {
    return;
  }

  final exitCode = await _pkexecWriteSudoers(sortedPaths: paths, unixUser: user);
  if (exitCode == 0) {
    await prefs.setBool(_prefsInstalled, true);
    await prefs.setString(_prefsPathSig, sig);
    debugPrint('linuxBootstrapSudoers: installed /etc/sudoers.d/asteriaray-vpn (${paths.length} helper(s))');
  } else {
    debugPrint('linuxBootstrapSudoers: pkexec exited $exitCode (user cancelled or error)');
  }
}

Future<int> _pkexecWriteSudoers({
  required List<String> sortedPaths,
  required String unixUser,
}) async {
  final qUser = _shellSingleQuote(unixUser);
  final arrayBody = StringBuffer();
  for (final path in sortedPaths) {
    arrayBody.writeln('  ${_shellSingleQuote(path)}');
  }
  final pathsArray = 'PATHS=(\n${arrayBody.toString()})';

  final installHead = '''
set -e
U=$qUser
F=/etc/sudoers.d/asteriaray-vpn
$pathsArray
''';

  final installTail = r'''
all_ok() {
  [ -f "$F" ] || return 1
  for P in "${PATHS[@]}"; do
    grep -Fq "Defaults!${P} !requiretty" "$F" 2>/dev/null || return 1
    grep -Fq "NOPASSWD:SETENV: ${P}" "$F" 2>/dev/null || return 1
  done
  return 0
}
all_ok && exit 0
TMP="$(mktemp)"
{
  echo "# AsteriaRay — NOPASSWD for bundled VPN helpers (managed by app)"
  for P in "${PATHS[@]}"; do
    echo "Defaults!${P} !requiretty"
  done
  for P in "${PATHS[@]}"; do
    echo "${U} ALL=(root) NOPASSWD:SETENV: ${P}"
  done
} > "$TMP"
visudo -cf "$TMP" || { rm -f "$TMP"; exit 1; }
install -m 0440 "$TMP" "$F"
rm -f "$TMP"
visudo -cf "$F" || { rm -f "$F"; exit 1; }
''';

  final installBody = installHead + installTail;

  try {
    final r = await Process.run(
      'pkexec',
      ['bash', '-lc', installBody],
      environment: Platform.environment,
      runInShell: false,
    );
    if (r.exitCode != 0) {
      final err = '${r.stderr}${r.stdout}'.trim();
      if (err.isNotEmpty) {
        debugPrint('linuxBootstrapSudoers: $err');
      }
    }
    return r.exitCode;
  } on ProcessException catch (e) {
    debugPrint('linuxBootstrapSudoers: $e');
    return -1;
  }
}
