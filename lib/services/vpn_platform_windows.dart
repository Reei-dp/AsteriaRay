import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'awg_conf_utils.dart';
import 'vpn_platform_base.dart';
import 'vpn_windows_full_tunnel_routes.dart';

/// Windows: **Xray-core** + Wintun for VLESS (same JSON as Linux/Android); AmneziaWG via **amneziawg-go** + **awg.exe**.
///
/// **xray.exe** and **wintun.dll** must sit next to the app executable (see `windows/xray/` + CMake),
/// or set `XRAY=C:\path\to\xray.exe` (directory must contain `wintun.dll` unless Xray finds it on PATH).
///
/// Full-tunnel IPv4 uses split `route add` (see Xray `proxy/tun/README.md` — OS must steer traffic into TUN).
/// **Administrator** rights are required for Wintun and for `route`.
///
/// AmneziaWG: bundle `amneziawg-go.exe` + `awg.exe` next to the executable (see `tools/fetch_amneziawg_windows.bat`),
/// plus `wintun.dll`. Fetch script patches UAPI to `\\.\pipe\AsteriaRayAWG_<iface>` (single segment; avoids `ProtectedPrefix` / multi-level pipe issues).
/// Optional: `AMNEZIAWG_GO`, `AWG_EXE`.
class VpnPlatformWindows extends VpnPlatform {
  Process? _process;
  StreamSubscription<List<int>>? _stderrSub;
  StreamSubscription<List<int>>? _stdoutSub;

  Process? _awgProcess;
  StreamSubscription<List<int>>? _awgStderrSub;
  StreamSubscription<List<int>>? _awgStdoutSub;

  final VpnWindowsFullTunnelRoutes _windowsRoutes = VpnWindowsFullTunnelRoutes();
  final VpnWindowsFullTunnelRoutes _awgRoutes = VpnWindowsFullTunnelRoutes();

  @override
  void dispose() {
    unawaited(_windowsRoutes.remove(debugLog: debugPrint));
    unawaited(_awgRoutes.remove(debugLog: debugPrint));
    _stderrSub?.cancel();
    _stderrSub = null;
    _stdoutSub?.cancel();
    _stdoutSub = null;
    _process = null;
    _awgStderrSub?.cancel();
    _awgStderrSub = null;
    _awgStdoutSub?.cancel();
    _awgStdoutSub = null;
    _awgProcess = null;
  }

  /// Wintun / `route` need an elevated token; child [xray.exe] inherits the Flutter process token.
  static Future<bool> _isProcessElevated() async {
    try {
      final r = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          r'[bool]([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)',
        ],
        runInShell: false,
      );
      if (r.exitCode != 0) return false;
      return (r.stdout as String).trim().toLowerCase() == 'true';
    } catch (_) {
      return false;
    }
  }

  /// AmneziaWG UAPI uses a named pipe (`\\.\pipe\AsteriaRayAWG_<iface>` after fetch). Wintun still needs elevation;
  /// optional check for **High** mandatory IL (some UAC-filtered tokens break drivers / pipes).
  static Future<bool> _hasHighMandatoryLevel() async {
    try {
      final r = await Process.run(
        'whoami',
        ['/groups'],
        runInShell: false,
      );
      if (r.exitCode != 0) return true;
      final out = r.stdout as String;
      if (out.contains(r'S-1-16-12288')) return true;
      if (out.contains(r'S-1-16-16384')) return true;
      return false;
    } catch (_) {
      return true;
    }
  }

  Future<String?> _resolveXray() async {
    final fromEnv = Platform.environment['XRAY'];
    if (fromEnv != null && fromEnv.isNotEmpty) {
      final f = File(fromEnv);
      if (await f.exists()) return fromEnv;
    }

    final exe = File(Platform.resolvedExecutable);
    final bundle = File(p.join(exe.parent.path, 'xray.exe'));
    if (await bundle.exists()) {
      return bundle.path;
    }

    try {
      final r = await Process.run(
        'where',
        ['xray.exe'],
        runInShell: false,
      );
      if (r.exitCode == 0) {
        final line = (r.stdout as String).trim().split('\n').first.trim();
        if (line.isNotEmpty) return line;
      }
    } catch (_) {}

    return null;
  }

  String _bundleExeDir() => File(Platform.resolvedExecutable).parent.path;

  Future<String?> _resolveAmneziaWgGo() async {
    final fromEnv = Platform.environment['AMNEZIAWG_GO'];
    if (fromEnv != null && fromEnv.isNotEmpty) {
      final f = File(fromEnv);
      if (await f.exists()) return fromEnv;
    }
    final bundle = File(p.join(_bundleExeDir(), 'amneziawg-go.exe'));
    if (await bundle.exists()) return bundle.path;
    return null;
  }

  Future<String?> _resolveAwgExe() async {
    final fromEnv = Platform.environment['AWG_EXE'];
    if (fromEnv != null && fromEnv.isNotEmpty) {
      final f = File(fromEnv);
      if (await f.exists()) return fromEnv;
    }
    final bundle = File(p.join(_bundleExeDir(), 'awg.exe'));
    if (await bundle.exists()) return bundle.path;
    return null;
  }

  /// Wintun loads from the directory of the process loading the DLL.
  Future<void> _ensureWintunDllBeside(String sidecarExe) async {
    final dir = File(sidecarExe).parent.path;
    final w = File(p.join(dir, 'wintun.dll'));
    if (await w.exists()) return;
    final xray = await _resolveXray();
    if (xray != null) {
      final src = File(p.join(File(xray).parent.path, 'wintun.dll'));
      if (await src.exists()) {
        try {
          await src.copy(w.path);
        } catch (e) {
          debugPrint('VpnPlatformWindows: copy wintun.dll next to AWG failed: $e');
        }
      }
    }
  }

  Future<Set<String>> _wintunAdapterNames() async {
    const script = r'''
Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object {
  $_.InterfaceDescription -like '*Wintun*'
} | ForEach-Object { $_.Name }
''';
    try {
      final r = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy',
          'Bypass',
          '-Command',
          script,
        ],
        runInShell: false,
      );
      if (r.exitCode != 0) return {};
      final lines = (r.stdout as String)
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty);
      return lines.toSet();
    } catch (_) {
      return {};
    }
  }

  /// One PowerShell with internal polling — avoids dozens of `powershell.exe` cold starts (~30s before).
  Future<String> _resolveWintunAdapterAlias(Set<String> before, String iface) async {
    final escIface = iface.replaceAll("'", "''");
    final safeBefore = before.map((n) => n.replaceAll('|', '_')).join('|');
    final script = '''
\$beforeRaw = '$safeBefore'
\$iface = '$escIface'
\$h = @{}
foreach (\$x in \$beforeRaw.Split('|')) {
  \$t = \$x.Trim()
  if (\$t) { \$h[\$t] = \$true }
}
for (\$i = 0; \$i -lt 32; \$i++) {
  \$a = Get-NetAdapter -Name \$iface -ErrorAction SilentlyContinue
  if (\$null -ne \$a) { Write-Output \$iface; exit 0 }
  \$names = @(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { \$_.InterfaceDescription -like '*Wintun*' } | ForEach-Object { \$_.Name })
  foreach (\$n in \$names) { if (-not \$h.ContainsKey(\$n)) { Write-Output \$n; exit 0 } }
  Start-Sleep -Milliseconds 35
}
Write-Output \$iface
exit 0
''';
    try {
      final r = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy',
          'Bypass',
          '-Command',
          script,
        ],
        runInShell: false,
      );
      if (r.exitCode != 0) return iface;
      final line = (r.stdout as String).trim().split('\n').first.trim();
      return line.isNotEmpty ? line : iface;
    } catch (_) {
      return iface;
    }
  }

  /// `Process.run(awg setconf …)` can block indefinitely if UAPI never answers.
  Future<ProcessResult> _runAwgSetconf({
    required String awgPath,
    required String interfaceName,
    required String confPath,
    required Map<String, String> env,
  }) async {
    final p = await Process.start(
      awgPath,
      ['setconf', interfaceName, confPath],
      environment: env,
      runInShell: false,
    );
    final outFut = p.stdout.fold<List<int>>([], (a, b) => a..addAll(b));
    final errFut = p.stderr.fold<List<int>>([], (a, b) => a..addAll(b));
    try {
      final code = await p.exitCode.timeout(const Duration(seconds: 45));
      final out = utf8.decode(await outFut, allowMalformed: true);
      final err = utf8.decode(await errFut, allowMalformed: true);
      return ProcessResult(p.pid, code, out, err);
    } on TimeoutException {
      try {
        p.kill(ProcessSignal.sigkill);
      } catch (_) {}
      await _killAwgSidecarProcess();
      throw Exception(
        'awg setconf: таймаут 45 с (нет ответа по UAPI). '
        'Проверьте пару amneziawg-go.exe + awg.exe из одной сборки (fetch_amneziawg_windows), '
        'закройте лишний amneziawg-go.exe.',
      );
    }
  }

  /// UAPI `setconf` cannot apply `Address=` / `DNS=` (wg-quick only). Wintun needs an IPv4 on the adapter.
  Future<void> _applyWireGuardInterfaceIpAndDns({
    required String adapterAlias,
    required String originalConf,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final cidrs = interfaceIpv4CidrsFromConf(originalConf);
    final dns = interfaceIpv4DnsFromConf(originalConf);

    for (final cidr in cidrs) {
      final parsed = ipv4CidrToIpAndNetmask(cidr);
      if (parsed == null) continue;
      final (ip, mask) = parsed;
      await Process.run(
        'netsh',
        [
          'interface',
          'ipv4',
          'delete',
          'address',
          'name=$adapterAlias',
          'address=$ip',
        ],
        runInShell: false,
      );
      final r = await Process.run(
        'netsh',
        [
          'interface',
          'ipv4',
          'add',
          'address',
          'name=$adapterAlias',
          'address=$ip',
          'mask=$mask',
        ],
        runInShell: false,
      );
      if (r.exitCode != 0) {
        final err = '${r.stderr}${r.stdout}'.trim();
        throw Exception(
          'Не удалось назначить IPv4 туннелю «$adapterAlias» ($cidr). '
          'netsh exit ${r.exitCode}. $err',
        );
      }
      debugPrint('VpnPlatformWindows: netsh add address $adapterAlias $ip mask $mask');
    }

    if (cidrs.isEmpty) {
      debugPrint(
        'VpnPlatformWindows: в конфиге нет IPv4 Address= — без адреса на Wintun сеть может не работать.',
      );
    }

    if (dns.isEmpty) return;

    final escaped = adapterAlias.replaceAll("'", "''");
    final dnsArgs = dns.map((d) => "'$d'").join(',');
    final ps =
        "Set-DnsClientServerAddress -InterfaceAlias '$escaped' -ServerAddresses @($dnsArgs)";
    final dr = await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        ps,
      ],
      runInShell: false,
    );
    if (dr.exitCode != 0) {
      debugPrint(
        'VpnPlatformWindows: DNS на адаптер не применены (exit ${dr.exitCode}): '
        '${dr.stderr}${dr.stdout}',
      );
    } else {
      debugPrint('VpnPlatformWindows: DNS на $adapterAlias: ${dns.join(', ')}');
    }
  }

  Map<String, String> _sidecarEnvironment({required String xrayDir, String? xrayAssetDir}) {
    final env = Map<String, String>.from(Platform.environment);
    final path = env['PATH'] ?? '';
    env['PATH'] = '$xrayDir${Platform.pathSeparator}$path';
    if (xrayAssetDir != null && xrayAssetDir.isNotEmpty) {
      // Xray (Go) accepts both; forward slashes avoid rare path edge cases on Windows.
      final normalized = xrayAssetDir.replaceAll(r'\', '/');
      env['xray.location.asset'] = normalized;
      env['XRAY_LOCATION_ASSET'] = normalized;
    }
    return env;
  }

  /// Xray resolves `geoip.dat` / `geosite.dat` from [xray.location.asset] and the exe dir — copy as backup.
  Future<void> _ensureDatFilesBesideXray(String xrayExePath, String workDir) async {
    final beside = File(xrayExePath).parent;
    for (final name in ['geoip.dat', 'geosite.dat']) {
      final src = File(p.join(workDir, name));
      final dst = File(p.join(beside.path, name));
      if (!await src.exists()) {
        debugPrint('VpnPlatformWindows: missing $name in workDir $workDir');
        continue;
      }
      try {
        await src.copy(dst.path);
      } catch (e) {
        debugPrint('VpnPlatformWindows: copy $name next to xray failed: $e');
      }
    }
  }

  static String _hintForXrayFailure(String detail, int exitCode) {
    final d = detail.toLowerCase();
    if (d.contains('failed to start')) {
      return ' В выводе Xray есть строка «Failed to start: …» — это точная причина (часто geoip/geosite или конфиг).';
    }
    if (exitCode == 23) {
      return ' Код 23 у Xray — ядро не поднялось при разборе конфига (до TUN). Смотри «Failed to start» в логе ниже.';
    }
    if (d.contains('device installation mutex') ||
        d.contains('private namespace')) {
      return ' Процесс не с правами администратора (Wintun). Запустите AsteriaRay от имени администратора.';
    }
    if (d.contains('wintun') ||
        d.contains('access is denied') ||
        d.contains('administrator')) {
      return ' Нужны права администратора и wintun.dll рядом с xray.exe.';
    }
    return '';
  }

  static String _hintAwgGoFailure(String detail) {
    final d = detail.toLowerCase();
    if (d.contains('winerr=183') ||
        d.contains('winerr = 183') ||
        (d.contains('uapi') && d.contains('183'))) {
      return ' Канал UAPI занят (часто остался процесс amneziawg-go.exe). Завершите его в диспетчере задач или перезапустите AsteriaRay — приложение теперь снимает «осиротевшие» процессы перед стартом.';
    }
    if (d.contains('failed to listen on uapi') ||
        d.contains('uapi socket') ||
        (d.contains('pipe') && d.contains('protectedprefix'))) {
      return ' Пересоберите AmneziaWG: .\\tools\\fetch_amneziawg_windows.bat (актуальный скрипт: pipe AsteriaRayAWG_<iface> + SD без mandatory label). '
          'Закройте другие WireGuard/Amnezia, запустите exe от администратора. Если в логе есть WinErr=183 — занято имя pipe (старый amneziawg-go).';
    }
    if (d.contains('failed to create tun') ||
        (d.contains('create tun') && d.contains('fail'))) {
      return ' Часто: нет/не тот wintun.dll (amd64) рядом с amneziawg-go.exe, или нет прав администратора.';
    }
    if (d.contains('access is denied') ||
        d.contains('отказано') ||
        d.contains('denied')) {
      return ' Запустите AsteriaRay от имени администратора.';
    }
    if ((d.contains('cannot find') && d.contains('wintun')) ||
        (d.contains('failed to load') && d.contains('wintun'))) {
      return ' Положите wintun.dll из windows/xray в папку с amneziawg-go.exe (рядом с asteriaray.exe после сборки).';
    }
    return '';
  }

  /// One line for toasts. Skips amneziawg-go `main_windows.go` stderr banner ("test program…").
  /// Prefers `WinErr=` lines (UAPI errno), then any line with "Failed".
  static String? _firstAwgErrorSummaryLine(String text) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    const upstreamBanner = 'warning: this is a test program for windows';
    bool isUpstreamBanner(String t) =>
        t.toLowerCase().startsWith(upstreamBanner);

    int capFor(String t) {
      final l = t.toLowerCase();
      if (l.contains('uapi listen') ||
          l.contains('failed to listen') ||
          l.contains('winerr=')) {
        return 2000;
      }
      return 280;
    }

    String clip(String t) {
      final c = capFor(t);
      return t.length > c ? '${t.substring(0, c - 3)}...' : t;
    }

    for (final t in lines) {
      if (isUpstreamBanner(t)) continue;
      if (t.toLowerCase().contains('winerr=')) {
        return clip(t);
      }
    }
    for (final t in lines) {
      if (isUpstreamBanner(t)) continue;
      if (t.toLowerCase().contains('failed')) {
        return clip(t);
      }
    }
    for (final t in lines) {
      if (isUpstreamBanner(t)) continue;
      return clip(t);
    }
    return null;
  }

  static void _debugPrintLong(String text) {
    const chunk = 900;
    for (var i = 0; i < text.length; i += chunk) {
      debugPrint(text.substring(i, math.min(i + chunk, text.length)));
    }
  }

  static void _appendRolling(StringBuffer buf, String s, {int maxChars = 12000}) {
    buf.write(s);
    if (buf.length > maxChars) {
      final t = buf.toString();
      buf.clear();
      buf.write(t.substring(t.length - maxChars));
    }
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

  Future<void> _killAwgSidecarProcess() async {
    final proc = _awgProcess;
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
    _awgProcess = null;
    await _awgStderrSub?.cancel();
    _awgStderrSub = null;
    await _awgStdoutSub?.cancel();
    _awgStdoutSub = null;
  }

  /// Kills any leftover `amneziawg-go.exe` not tracked in this isolate (crash, second instance, etc.).
  /// Otherwise `NtCreateNamedPipe` often fails with WinErr=183 (pipe name still in use).
  Future<void> _killOrphanAmneziaWgGoProcesses() async {
    if (!Platform.isWindows) return;
    try {
      final r = await Process.run(
        'taskkill',
        const ['/F', '/IM', 'amneziawg-go.exe'],
        runInShell: false,
      );
      if (r.exitCode == 0) {
        debugPrint(
          'VpnPlatformWindows: ended stray amneziawg-go.exe (pipe cleanup)',
        );
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    } catch (e) {
      debugPrint('VpnPlatformWindows: taskkill amneziawg-go skipped: $e');
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

  Future<void> _stopXraySidecarProcess() async {
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

  @override
  Future<bool> prepareVpn() async => true;

  @override
  Future<void> startVpn({
    required String configPath,
    required String workDir,
    required String logPath,
    String? profileName,
    String? transport,
    String? vlessServerHost,
  }) async {
    await stopVpn();

    if (!await _isProcessElevated()) {
      throw StateError(
        'Windows: для Wintun и системных маршрутов AsteriaRay должна быть запущена от имени администратора.\n'
        'Закройте приложение и запустите снова: правый клик по asteriaray.exe → «Запуск от имени администратора» '
        '(или терминал/cmd от администратора → flutter run).\n'
        'Если окно UAC не появлялось — выполните flutter build windows и запустите exe из build/windows/x64/runner/Release (или Debug).',
      );
    }

    const sidecarLabel = 'xray';
    final x = await _resolveXray();
    if (x == null) {
      throw StateError(
        'xray.exe not found. Place xray.exe + wintun.dll next to the app (run .\\tools\\fetch_xray_windows.ps1), '
        'or set XRAY=C:\\path\\to\\xray.exe',
      );
    }
    final binary = x;
    final xrayDir = File(binary).parent.path;
    final wintunDll = File(p.join(xrayDir, 'wintun.dll'));
    if (!await wintunDll.exists()) {
      debugPrint('VpnPlatformWindows: wintun.dll not found next to xray in $xrayDir');
    }
    await _ensureDatFilesBesideXray(binary, workDir);
    final env = _sidecarEnvironment(xrayDir: xrayDir, xrayAssetDir: workDir);
    debugPrint('VpnPlatformWindows: using xray at $binary');

    final logFile = File(logPath);
    await logFile.parent.create(recursive: true);
    final sink = logFile.openWrite(mode: FileMode.append);
    sink.writeln('--- $sidecarLabel ${DateTime.now().toIso8601String()} (Windows) ---');
    await sink.flush();

    final capturedOut = StringBuffer();
    Process? proc;
    final configArg = configPath.replaceAll(r'\', '/');
    proc = await Process.start(
      binary,
      ['run', '-c', configArg],
      workingDirectory: workDir,
      environment: env,
    );

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

    if (earlyExit != -999) {
      await _stderrSub?.cancel();
      _stderrSub = null;
      await _stdoutSub?.cancel();
      _stdoutSub = null;
      _process = null;
      try {
        await sink.flush();
        await sink.close();
      } catch (_) {}

      final fromProc = capturedOut.toString().trim();
      final fromFile = await _readLogTail(logPath);
      final detail = fromProc.isNotEmpty
          ? fromProc
          : (fromFile.isNotEmpty ? fromFile : '(no output captured)');

      final fileBlock = StringBuffer()
        ..writeln()
        ..writeln(
          '========== AsteriaRay: $sidecarLabel failed (exit $earlyExit) ==========',
        )
        ..writeln('Log file: $logPath')
        ..writeln('Binary: $binary')
        ..writeln('--- $sidecarLabel output ---')
        ..writeln(detail)
        ..writeln('========== end ==========');
      try {
        await File(logPath).writeAsString(fileBlock.toString(), mode: FileMode.append);
      } catch (_) {}

      developer.log(
        '$sidecarLabel exit $earlyExit | $logPath\n$detail',
        name: 'VpnPlatformWindows',
        level: 1000,
      );
      _debugPrintLong(detail);

      final hint = _hintForXrayFailure(detail, earlyExit);
      throw Exception(
        '$sidecarLabel exited with code $earlyExit.$hint\nDetails appended to:\n$logPath',
      );
    }

    if (vlessServerHost != null && vlessServerHost.isNotEmpty) {
      try {
        await _windowsRoutes.apply(
          vlessServerHost: vlessServerHost,
          debugLog: debugPrint,
        );
      } catch (e) {
        await _stderrSub?.cancel();
        _stderrSub = null;
        await _stdoutSub?.cancel();
        _stdoutSub = null;
        await _killProcBestEffort(_process);
        _process = null;
        try {
          await sink.flush();
          await sink.close();
        } catch (_) {}
        rethrow;
      }
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
      unawaited(_windowsRoutes.remove(debugLog: debugPrint));
      onVpnStopped?.call('vpnStopped:vless');
    });
  }

  @override
  Future<void> startAwgVpn({
    required String conf,
    required String profileName,
    String? profileId,
  }) async {
    await stopVpn();
    await _killOrphanAmneziaWgGoProcesses();

    if (!await _isProcessElevated()) {
      throw StateError(
        'Windows: AmneziaWG (Wintun) требует запуск AsteriaRay от имени администратора.',
      );
    }
    final highIl = await _hasHighMandatoryLevel();
    if (!highIl) {
      debugPrint(
        'VpnPlatformWindows: в whoami /groups нет S-1-16-12288 (High mandatory level). '
        'Если далее будет ошибка UAPI pipe (ProtectedPrefix), запустите asteriaray.exe через '
        '«Запуск от имени администратора» с полным UAC.',
      );
    }

    final go = await _resolveAmneziaWgGo();
    final awg = await _resolveAwgExe();
    if (go == null) {
      throw StateError(
        'amneziawg-go.exe not found. Run .\\tools\\fetch_amneziawg_windows.bat or place amneziawg-go.exe next to the app. '
        'Or set AMNEZIAWG_GO=C:\\path\\to\\amneziawg-go.exe',
      );
    }
    if (awg == null) {
      throw StateError(
        'awg.exe not found. Run .\\tools\\fetch_amneziawg_windows.bat or place awg.exe next to the app. '
        'Or set AWG_EXE=C:\\path\\to\\awg.exe',
      );
    }

    await _ensureWintunDllBeside(go);
    final wintun = File(p.join(File(go).parent.path, 'wintun.dll'));
    if (!await wintun.exists()) {
      throw StateError(
        'wintun.dll must sit next to amneziawg-go.exe (copy from windows\\xray after fetch_xray_windows.ps1).',
      );
    }

    final iface = awgInterfaceBaseName(profileName, profileId);
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'awg'));
    await dir.create(recursive: true);
    final confPath = p.join(dir.path, '$iface.conf');
    final confToWrite = confForWgUapiSetconf(conf);
    await File(confPath).writeAsString(confToWrite, flush: true);

    final goDir = File(go).parent.path;
    final env = Map<String, String>.from(Platform.environment);
    final path = env['PATH'] ?? '';
    env['PATH'] = '$goDir${Platform.pathSeparator}$path';
    env['LOG_LEVEL'] = 'verbose';

    final beforeTun = await _wintunAdapterNames();
    debugPrint('VpnPlatformWindows: starting AmneziaWG userspace $go $iface');

    final captured = StringBuffer();
    final proc = await Process.start(
      go,
      [iface],
      environment: env,
      workingDirectory: goDir,
    );
    _awgProcess = proc;

    _awgStderrSub = proc.stderr.listen((bytes) {
      try {
        final s = utf8.decode(bytes, allowMalformed: true);
        _appendRolling(captured, s);
        debugPrint(s);
      } catch (_) {}
    });
    _awgStdoutSub = proc.stdout.listen((bytes) {
      try {
        final s = utf8.decode(bytes, allowMalformed: true);
        _appendRolling(captured, s);
      } catch (_) {}
    });

    // Wait briefly for a fast crash. If the daemon stays up, exitCode does not complete → TimeoutException.
    // (Do not use Future.any + ~800ms vs exitCode: stderr was often still empty when the process exited.)
    try {
      final code = await proc.exitCode.timeout(const Duration(milliseconds: 700));
      await Future<void>.delayed(const Duration(milliseconds: 450));
      final detail = captured.toString().trim();
      await _awgStderrSub?.cancel();
      _awgStderrSub = null;
      await _awgStdoutSub?.cancel();
      _awgStdoutSub = null;
      _awgProcess = null;
      developer.log(
        'amneziawg-go exit $code\n$detail',
        name: 'VpnPlatformWindows',
        level: 1000,
      );
      _debugPrintLong(detail);
      final hint = _hintAwgGoFailure(detail);
      final head = _firstAwgErrorSummaryLine(detail) ??
          'нет текста stderr — см. консоль flutter run';
      final tail = detail.isNotEmpty ? '\n\n$detail' : '';
      throw Exception('amneziawg-go (код $code): $head.$hint$tail');
    } on TimeoutException {
      // Still running — tunnel daemon expected to keep exitCode pending.
    }

    // `awg setconf` uses UAPI (named pipe), not NetAdapter enumeration — do not wait for Wintun in WMI first.
    await Future<void>.delayed(const Duration(milliseconds: 40));
    var setconf = await _runAwgSetconf(
      awgPath: awg,
      interfaceName: iface,
      confPath: confPath,
      env: env,
    );
    if (setconf.exitCode != 0) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      setconf = await _runAwgSetconf(
        awgPath: awg,
        interfaceName: iface,
        confPath: confPath,
        env: env,
      );
    }
    if (setconf.exitCode != 0) {
      final err = '${setconf.stderr}${setconf.stdout}'.trim();
      await _killAwgSidecarProcess();
      throw Exception(
        'awg setconf failed (exit ${setconf.exitCode}). '
        'Interface: $iface. $err',
      );
    }

    final tunName = await _resolveWintunAdapterAlias(beforeTun, iface);

    try {
      await _applyWireGuardInterfaceIpAndDns(
        adapterAlias: tunName,
        originalConf: conf,
      );
    } catch (e) {
      await _killAwgSidecarProcess();
      rethrow;
    }

    final ep = peerEndpointHostForRoutes(conf);
    final wantFull = awgPeerAllowsFullIpv4(conf);
    if (wantFull && ep != null && ep.isNotEmpty) {
      try {
        await _awgRoutes.apply(
          vlessServerHost: ep,
          preferredTunnelInterfaceName: tunName,
          debugLog: debugPrint,
        );
      } catch (e) {
        await _killAwgSidecarProcess();
        rethrow;
      }
    }

    proc.exitCode.then((code) {
      _awgProcess = null;
      _awgStderrSub?.cancel();
      _awgStderrSub = null;
      _awgStdoutSub?.cancel();
      _awgStdoutSub = null;
      unawaited(_awgRoutes.remove(debugLog: debugPrint));
      onVpnStopped?.call('vpnStopped:awg');
    });
  }

  @override
  Future<void> stopVpn() async {
    await _awgRoutes.remove(debugLog: debugPrint);
    await _killAwgSidecarProcess();
    await _windowsRoutes.remove(debugLog: debugPrint);
    await _stopXraySidecarProcess();
  }

  @override
  Future<bool> isTunnelProcessRunning() async =>
      _process != null || _awgProcess != null;

  @override
  Future<bool> isVpnTunnelEstablished() async =>
      _process != null || _awgProcess != null;

  @override
  Future<String?> getLastVlessStartError() async => null;

  @override
  Future<Map<String, int>> getStats() async {
    return {'upload': 0, 'download': 0};
  }
}
