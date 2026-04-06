import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'vpn_platform_base.dart';

/// Linux: [sing-box](https://github.com/SagerNet/sing-box) for VLESS; AmneziaWG via `awg-quick`
/// from [amneziawg-tools](https://github.com/amnezia-vpn/amneziawg-tools) (not stock `wg-quick`).
///
/// **sing-box** lookup: `SING_BOX`, bundle `sing-box`, `which sing-box`.
///
/// **awg-quick** lookup: `AWG_QUICK`, bundle `awg-quick` next to the app (with bundled `awg` in the same folder), `which awg-quick`.
///
/// AmneziaWG: bundled `awg-quick` is a shell script that calls `sudo` when not root (interactive).
/// We always run it elevated (`sudo -n` or `pkexec`) so the process is UID 0 and that path is skipped.
///
/// If the `amneziawg` kernel module is missing, `awg-quick` falls back to userspace when
/// `WG_QUICK_USERSPACE_IMPLEMENTATION` points to bundled `amneziawg-go` (see `tools/fetch_amneziawg_go_linux.sh`).
class VpnPlatformLinux extends VpnPlatform {
  Process? _process;
  StreamSubscription<List<int>>? _stderrSub;
  StreamSubscription<List<int>>? _stdoutSub;

  /// Config path passed to `awg-quick down` when stopping AmneziaWG (kernel iface).
  String? _awgConfPath;

  @override
  void dispose() {
    _stderrSub?.cancel();
    _stderrSub = null;
    _stdoutSub?.cancel();
    _stdoutSub = null;
    _process = null;
  }

  Future<String?> _resolveSingBox() async {
    final fromEnv = Platform.environment['SING_BOX'];
    if (fromEnv != null && fromEnv.isNotEmpty) {
      final f = File(fromEnv);
      if (await f.exists()) return fromEnv;
    }

    final exe = File(Platform.resolvedExecutable);
    final bundleSingBox = File(p.join(exe.parent.path, 'sing-box'));
    if (await bundleSingBox.exists()) {
      return bundleSingBox.path;
    }

    try {
      final r = await Process.run('which', ['sing-box'], runInShell: false);
      if (r.exitCode == 0) {
        final line = (r.stdout as String).trim().split('\n').first.trim();
        if (line.isNotEmpty) return line;
      }
    } catch (_) {}

    return null;
  }

  Future<String?> _resolveAwgQuick() async {
    final fromEnv = Platform.environment['AWG_QUICK'];
    if (fromEnv != null && fromEnv.isNotEmpty) {
      final f = File(fromEnv);
      if (await f.exists()) return fromEnv;
    }

    final exe = File(Platform.resolvedExecutable);
    final bundle = File(p.join(exe.parent.path, 'awg-quick'));
    if (await bundle.exists()) {
      return bundle.path;
    }

    try {
      final r = await Process.run('which', ['awg-quick'], runInShell: false);
      if (r.exitCode == 0) {
        final line = (r.stdout as String).trim().split('\n').first.trim();
        if (line.isNotEmpty) return line;
      }
    } catch (_) {}

    return null;
  }

  /// Standard locations for `ip`, `iptables`, etc. Apps started via `flutter run` often omit `/usr/sbin`.
  static const _linuxSystemPath =
      '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin';

  /// Environment with [awgQuick]'s directory first on `PATH` so the script finds bundled `awg`.
  /// Sets `WG_QUICK_USERSPACE_IMPLEMENTATION` when `amneziawg-go` sits next to the app (kernel module optional).
  Future<Map<String, String>> _awgEnvironment(String awgQuick) async {
    final env = Map<String, String>.from(Platform.environment);
    final bundleDir = File(awgQuick).parent.path;
    final path = env['PATH'] ?? '';
    env['PATH'] = '$bundleDir:$path:$_linuxSystemPath';
    final go = File(p.join(bundleDir, 'amneziawg-go'));
    if (await go.exists()) {
      env['WG_QUICK_USERSPACE_IMPLEMENTATION'] = go.path;
    }
    return env;
  }

  /// Arguments for `pkexec env …` so elevated `awg-quick` sees PATH and userspace fallback.
  List<String> _pkexecEnvPrefix(Map<String, String> env) {
    final args = <String>['env', 'PATH=${env['PATH']}'];
    final w = env['WG_QUICK_USERSPACE_IMPLEMENTATION'];
    if (w != null && w.isNotEmpty) {
      args.add('WG_QUICK_USERSPACE_IMPLEMENTATION=$w');
    }
    return args;
  }

  /// Linux netdevice names max 15 bytes (IFNAMSIZ-1); `awg-quick` rejects longer `.conf` basenames.
  static String _linuxAwgInterfaceBaseName(String profileName, String? profileId) {
    var safe = profileName
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (safe.isEmpty) safe = 'awg';
    if (safe.length <= 15) return safe;
    if (profileId != null && profileId.isNotEmpty) {
      final hex = profileId.replaceAll(RegExp(r'[^a-fA-F0-9]'), '');
      if (hex.length >= 14) {
        return 'w${hex.substring(0, 14)}'.toLowerCase();
      }
    }
    final h = profileName.hashCode.abs().toRadixString(36).replaceAll('-', 'z');
    final t = h.length > 14 ? h.substring(0, 14) : h.padLeft(14, '0');
    return 'a$t';
  }

  /// `awg-quick` runs `resolvconf` for `[Interface] DNS = …`; many desktops (e.g. Arch) have no `resolvconf`
  /// unless `openresolv` is installed — that yields exit 127 after the tunnel is already up.
  /// Stripping `DNS=` lines skips that path; DNS can still be handled in-app or via systemd-resolved.
  static String _stripWgQuickDnsLines(String conf) {
    final out = <String>[];
    for (final line in conf.split('\n')) {
      if (RegExp(r'^\s*DNS\s*=').hasMatch(line)) {
        continue;
      }
      out.add(line);
    }
    return out.join('\n');
  }

  Future<bool> _isUid0() async {
    try {
      final r = await Process.run('id', ['-u'], runInShell: false);
      if (r.exitCode != 0) return false;
      return (r.stdout as String).trim() == '0';
    } catch (_) {
      return false;
    }
  }

  bool _sudoWantsInteractivePassword(String combinedStderrStdout) {
    final s = combinedStderrStdout.toLowerCase();
    return s.contains('a password is required') ||
        s.contains('password is required') ||
        s.contains('no tty present') ||
        (s.contains('sudo:') && s.contains('password'));
  }

  /// Runs bundled `awg-quick` with privileges so its internal `auto_su` does not prompt on stdin.
  Future<ProcessResult> _runAwgQuickElevated(String awgQuick, List<String> args) async {
    final env = await _awgEnvironment(awgQuick);
    final goImpl = env['WG_QUICK_USERSPACE_IMPLEMENTATION'];
    if (goImpl != null) {
      debugPrint('VpnPlatformLinux: userspace AmneziaWG fallback: $goImpl');
    }

    if (await _isUid0()) {
      return Process.run(awgQuick, args, environment: env, runInShell: false);
    }

    ProcessResult? sudoN;
    try {
      sudoN = await Process.run(
        'sudo',
        ['-n', '-E', awgQuick, ...args],
        environment: env,
        runInShell: false,
      );
    } on ProcessException catch (_) {
      sudoN = null;
    }

    if (sudoN != null) {
      if (sudoN.exitCode == 0) return sudoN;
      final err = '${sudoN.stderr}${sudoN.stdout}';
      if (!_sudoWantsInteractivePassword(err)) {
        return sudoN;
      }
    }

    try {
      return await Process.run(
        'pkexec',
        [..._pkexecEnvPrefix(env), awgQuick, ...args],
        environment: env,
        runInShell: false,
      );
    } on ProcessException catch (e) {
      throw Exception(
        'AmneziaWG needs root for TUN (same as sing-box). awg/awg-quick are already bundled next to the app; '
        'nothing extra to install. Configure passwordless sudo for awg-quick or install pkexec (polkit). '
        'Underlying error: $e',
      );
    }
  }

  @override
  Future<bool> prepareVpn() async {
    return true;
  }

  static void _debugPrintLong(String text) {
    const chunk = 900;
    for (var i = 0; i < text.length; i += chunk) {
      debugPrint(text.substring(i, math.min(i + chunk, text.length)));
    }
  }

  /// Keeps last [maxChars] of process output for error messages (UI may truncate file-based logs).
  static void _appendRolling(StringBuffer buf, String s, {int maxChars = 12000}) {
    buf.write(s);
    if (buf.length > maxChars) {
      final t = buf.toString();
      buf.clear();
      buf.write(t.substring(t.length - maxChars));
    }
  }

  Map<String, String> _singBoxEnvironment() {
    final env = Map<String, String>.from(Platform.environment);
    final p = env['PATH'];
    env['PATH'] = (p == null || p.isEmpty)
        ? _linuxSystemPath
        : '$p:$_linuxSystemPath';
    return env;
  }

  Future<void> _killProcBestEffort(Process? proc) async {
    if (proc == null) return;
    try {
      proc.kill(ProcessSignal.sigterm);
      await proc.exitCode.timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          proc.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
    } catch (_) {
      try {
        proc.kill(ProcessSignal.sigkill);
      } catch (_) {}
    }
  }

  /// True if [path] already has file caps (e.g. from AUR post_install or a prior run).
  Future<bool> _singBoxHasNetCaps(String path) async {
    try {
      final r = await Process.run('getcap', [path], runInShell: false);
      final out = '${r.stdout}${r.stderr}';
      return out.contains('cap_net_admin');
    } catch (_) {
      return false;
    }
  }

  /// One graphical password prompt (pkexec) to run [setcap] on the binary; afterwards sing-box
  /// can open TUN without sudo/pkexec on every connect.
  Future<void> _ensureSingBoxCapabilities(String singBoxPath) async {
    if (await _isUid0()) return;
    if (await _singBoxHasNetCaps(singBoxPath)) {
      debugPrint('VpnPlatformLinux: sing-box already has cap_net_admin (+ bind)');
      return;
    }
    debugPrint(
      'VpnPlatformLinux: asking for password once to allow VPN (setcap on sing-box)',
    );
    final r = await Process.run(
      'pkexec',
      [
        'setcap',
        'cap_net_admin,cap_net_bind_service+ep',
        singBoxPath,
      ],
      runInShell: false,
    );
    if (r.exitCode != 0) {
      final hint = '${r.stderr}${r.stdout}'.trim();
      throw Exception(
        'Could not grant VPN capabilities to sing-box (pkexec exit ${r.exitCode}). '
        '${hint.isNotEmpty ? '$hint ' : ''}'
        'Run once in a terminal: sudo setcap cap_net_admin,cap_net_bind_service+ep $singBoxPath',
      );
    }
    if (!await _singBoxHasNetCaps(singBoxPath)) {
      debugPrint(
        'VpnPlatformLinux: setcap finished but getcap still shows no caps (unusual)',
      );
    }
  }

  Future<String> _readLogTail(String path, [int maxBytes = 4096]) async {
    try {
      final f = File(path);
      if (!await f.exists()) return '(no log file)';
      final len = await f.length();
      final start = len > maxBytes ? len - maxBytes : 0;
      final raf = await f.open();
      try {
        await raf.setPosition(start);
        final bytes = await raf.read(maxBytes);
        return utf8.decode(bytes, allowMalformed: true);
      } finally {
        await raf.close();
      }
    } catch (e) {
      return '(could not read log: $e)';
    }
  }

  Future<void> _stopSingBoxProcess() async {
    final proc = _process;
    if (proc == null) return;
    try {
      proc.kill(ProcessSignal.sigterm);
      await proc.exitCode.timeout(const Duration(seconds: 5), onTimeout: () {
        proc.kill(ProcessSignal.sigkill);
        return -1;
      });
    } catch (_) {
      try {
        proc.kill(ProcessSignal.sigkill);
      } catch (_) {}
    }
    _process = null;
    await _stderrSub?.cancel();
    _stderrSub = null;
    await _stdoutSub?.cancel();
    _stdoutSub = null;
  }

  Future<void> _awgQuickDown() async {
    final confPath = _awgConfPath;
    if (confPath == null) return;
    _awgConfPath = null;
    final awgQuick = await _resolveAwgQuick();
    if (awgQuick == null) return;
    try {
      final r = await _runAwgQuickElevated(awgQuick, ['down', confPath]);
      if (r.exitCode != 0) {
        debugPrint(
          'VpnPlatformLinux: awg-quick down exit ${r.exitCode} stderr=${r.stderr}',
        );
      }
    } catch (e) {
      debugPrint('VpnPlatformLinux: awg-quick down failed: $e');
    }
  }

  @override
  Future<void> startVpn({
    required String configPath,
    required String workDir,
    required String logPath,
    String? profileName,
    String? transport,
  }) async {
    await stopVpn();

    final singBox = await _resolveSingBox();
    if (singBox == null) {
      throw StateError(
        'sing-box binary not found. Place it next to the app, set SING_BOX=/path/to/sing-box, '
        'or install on PATH. See tools/fetch_singbox_linux.sh',
      );
    }
    debugPrint('VpnPlatformLinux: using sing-box at $singBox');

    await _ensureSingBoxCapabilities(singBox);

    final logFile = File(logPath);
    await logFile.parent.create(recursive: true);
    final sink = logFile.openWrite(mode: FileMode.append);
    sink.writeln('--- sing-box ${DateTime.now().toIso8601String()} ---');
    await sink.flush();

    final env = _singBoxEnvironment();
    final isRoot = await _isUid0();
    final maxAttempts = isRoot ? 1 : 3;
    final capturedOut = StringBuffer();

    Process? proc;
    var startedOk = false;
    var lastExitCode = 1;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      await _stderrSub?.cancel();
      _stderrSub = null;
      await _stdoutSub?.cancel();
      _stdoutSub = null;
      await _killProcBestEffort(proc);
      proc = null;

      if (isRoot) {
        proc = await Process.start(
          singBox,
          ['run', '-c', configPath],
          workingDirectory: workDir,
          environment: env,
        );
      } else if (attempt == 1) {
        // Works when sing-box has cap_net_admin+ep (e.g. AUR post_install setcap).
        proc = await Process.start(
          singBox,
          ['run', '-c', configPath],
          workingDirectory: workDir,
          environment: env,
        );
      } else if (attempt == 2) {
        debugPrint('VpnPlatformLinux: retrying sing-box via sudo -n (TUN needs privileges)');
        try {
          proc = await Process.start(
            'sudo',
            ['-n', '-E', singBox, 'run', '-c', configPath],
            workingDirectory: workDir,
            environment: env,
          );
        } on ProcessException catch (e) {
          debugPrint('VpnPlatformLinux: sudo -n spawn failed: $e');
          continue;
        }
      } else {
        debugPrint('VpnPlatformLinux: retrying sing-box via pkexec');
        try {
          proc = await Process.start(
            'pkexec',
            [
              'env',
              'PATH=${env['PATH'] ?? ''}',
              singBox,
              'run',
              '-c',
              configPath,
            ],
            workingDirectory: workDir,
            environment: env,
          );
        } on ProcessException catch (e) {
          throw Exception(
            'Could not start sing-box with privileges: $e. '
            'Install polkit (pkexec) or use: sudo setcap cap_net_admin,cap_net_bind_service+ep \$path/sing-box',
          );
        }
      }

      _process = proc;
      _stderrSub = proc.stderr.listen((bytes) {
        try {
          final s = utf8.decode(bytes, allowMalformed: true);
          _appendRolling(capturedOut, s);
          sink.write(s);
        } catch (_) {}
      });
      _stdoutSub = proc.stdout.listen((bytes) {
        try {
          final s = utf8.decode(bytes, allowMalformed: true);
          _appendRolling(capturedOut, s);
          sink.write(s);
        } catch (_) {}
      });

      final earlyExit = await Future.any<int>([
        proc.exitCode,
        Future<int>.delayed(const Duration(milliseconds: 800), () => -999),
      ]);
      if (earlyExit == -999) {
        startedOk = true;
        break;
      }
      lastExitCode = earlyExit;
      if (attempt < maxAttempts) {
        debugPrint(
          'VpnPlatformLinux: sing-box attempt $attempt exited $earlyExit, trying next',
        );
      }
    }

    proc = _process;
    if (proc == null || !startedOk) {
      final earlyExit = lastExitCode;
      // Allow stream listeners to finish writing before we read the file.
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await _stderrSub?.cancel();
      _stderrSub = null;
      await _stdoutSub?.cancel();
      _stdoutSub = null;
      _process = null;
      try {
        await sink.flush();
        await sink.close();
      } catch (_) {}
      final fromFile = await _readLogTail(logPath);
      final fromProc = capturedOut.toString().trim();
      final detail = fromProc.isNotEmpty
          ? fromProc
          : (fromFile.isNotEmpty ? fromFile : '(no output captured)');

      final fileBlock = StringBuffer()
        ..writeln()
        ..writeln('========== AsteriaRay: sing-box failed (exit $earlyExit) ==========')
        ..writeln('Log file (copy from here): $logPath')
        ..writeln('Binary: $singBox')
        ..writeln('--- sing-box output ---')
        ..writeln(detail)
        ..writeln('========== end ==========');
      try {
        await File(logPath).writeAsString(fileBlock.toString(), mode: FileMode.append);
      } catch (_) {}

      developer.log(
        'sing-box exit $earlyExit | $logPath\n$detail',
        name: 'VpnPlatformLinux',
        level: 1000,
      );
      debugPrint(
        'VpnPlatformLinux: sing-box failed (exit $earlyExit). Full text is in log file:',
      );
      debugPrint(logPath);
      _debugPrintLong(detail);

      // Use Exception so UI does not prefix with "Bad state:".
      throw Exception(
        'sing-box exited with code $earlyExit. Full details were appended to:\n$logPath\n'
        '(Also printed to the terminal if you started the app with flutter run.)',
      );
    }

    proc.exitCode.then((code) {
      _process = null;
      _stderrSub?.cancel();
      _stderrSub = null;
      _stdoutSub?.cancel();
      _stdoutSub = null;
      try {
        sink.writeln('--- exit $code ---');
        sink.close();
      } catch (_) {}
      onVpnStopped?.call('vpnStopped:libcore');
    });
  }

  @override
  Future<void> startAwgVpn({
    required String conf,
    required String profileName,
    String? profileId,
  }) async {
    await stopVpn();

    final awgQuick = await _resolveAwgQuick();
    if (awgQuick == null) {
      throw StateError(
        'awg-quick not found. Run ./tools/fetch_amneziawg_tools_linux.sh (installs linux/awg + linux/awg-quick), '
        'or set AWG_QUICK=/path/to/awg-quick (same folder must contain awg).',
      );
    }

    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'awg'));
    await dir.create(recursive: true);
    final name = _linuxAwgInterfaceBaseName(profileName, profileId);
    final confPath = p.join(dir.path, '$name.conf');
    final confToWrite = _stripWgQuickDnsLines(conf);
    if (confToWrite != conf) {
      debugPrint(
        'VpnPlatformLinux: removed DNS= lines from AWG conf (no system resolvconf required)',
      );
    }
    await File(confPath).writeAsString(confToWrite, flush: true);

    debugPrint('VpnPlatformLinux: awg-quick up $confPath (binary: $awgQuick)');
    final r = await _runAwgQuickElevated(awgQuick, ['up', confPath]);
    if (r.exitCode != 0) {
      final detail = '${r.stderr}${r.stdout}'.trim();
      final shown = detail.isEmpty
          ? '(no stdout/stderr captured; check the terminal where you ran flutter run)'
          : detail;
      debugPrint('VpnPlatformLinux: awg-quick failed exit=${r.exitCode}\n$shown');
      final kernelHint = shown.contains('Unknown device type') ||
              shown.contains('Protocol not supported')
          ? ' Without the amneziawg kernel module, bundle userspace: run ./tools/fetch_amneziawg_go_linux.sh then rebuild.'
          : '';
      throw Exception(
        'awg-quick up failed (exit ${r.exitCode}). '
        'Long profile names are hashed to ≤15 chars. '
        'If you see "Unknown device type", the kernel module is missing or use bundled amneziawg-go.$kernelHint '
        'Ensure `ip` is on PATH. Output:\n$shown',
      );
    }
    _awgConfPath = confPath;
  }

  @override
  Future<void> stopVpn() async {
    await _stopSingBoxProcess();
    await _awgQuickDown();
  }

  @override
  Future<Map<String, int>> getStats() async {
    // TODO: wire sing-box experimental / clash_api or parse counters
    return {'upload': 0, 'download': 0};
  }
}
