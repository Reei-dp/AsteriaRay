import 'dart:async';
import 'dart:io';

/// Must match [xray_core_client_config] `tun` inbound `settings.name` (Xray / Wintun adapter name).
const kXrayWindowsTunName = 'xray0';

final _ipv4Re = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');

/// Xray TUN on Windows only brings the Wintun adapter up; it does not add system routes
/// (see Xray `proxy/tun/README.md`). Split IPv4 defaults + /32 to the VLESS server avoid loops.
class VpnWindowsFullTunnelRoutes {
  /// [tunIfIndex, phyIfIndex, ...serverIpv4]
  List<int>? _undo;

  bool get isActive => _undo != null;

  Future<void> apply({
    required String vlessServerHost,
    /// Prefer this adapter name (e.g. AmneziaWG Wintun) before `xray0` / generic Wintun fallback.
    String? preferredTunnelInterfaceName,
    void Function(String message)? debugLog,
  }) async {
    await remove(debugLog: debugLog);

    final def = await _powershellDefaultRouteV4();
    if (def == null) {
      debugLog?.call('VpnWindowsFullTunnel: no IPv4 default route; skipping policy routes');
      return;
    }
    final (gw, phyIdx) = def;
    if (!_ipv4Re.hasMatch(gw) || phyIdx <= 0) {
      debugLog?.call('VpnWindowsFullTunnel: parsed default route looks unsafe; skipping');
      return;
    }

    final serverIps = await _resolveServerIpv4(vlessServerHost);
    final safeIps = serverIps.where(_ipv4Re.hasMatch).toList();
    if (safeIps.isEmpty) {
      debugLog?.call('VpnWindowsFullTunnel: no IPv4 for $vlessServerHost; skipping policy routes');
      return;
    }

    final tunIdx = await _waitForTunInterfaceIndex(
      preferredName: preferredTunnelInterfaceName,
      debugLog: debugLog,
    );
    if (tunIdx == null || tunIdx <= 0) {
      throw Exception(
        'Windows: не найден сетевой адаптер TUN (ожидали имя «${preferredTunnelInterfaceName ?? kXrayWindowsTunName}» или Wintun). '
        'Убедитесь, что рядом с xray.exe лежит wintun.dll и приложение запущено от имени администратора.',
      );
    }

    for (final ip in safeIps) {
      final code = await _routeAddHostViaGateway(ip, gw, phyIdx, debugLog);
      if (code != 0) {
        await _rollbackAddedHostRoutes(safeIps, gw, phyIdx, debugLog);
        throw Exception(
          'Windows: не удалось добавить маршрут к серверу $ip (код $code). '
          'Запустите AsteriaRay от имени администратора.',
        );
      }
    }

    var code = await _routeAddSplitDefault(tunIdx, '0.0.0.0', debugLog);
    if (code != 0) {
      await _rollbackAddedHostRoutes(safeIps, gw, phyIdx, debugLog);
      throw Exception(
        'Windows: не удалось добавить маршрут 0.0.0.0/1 через TUN (код $code).',
      );
    }
    code = await _routeAddSplitDefault(tunIdx, '128.0.0.0', debugLog);
    if (code != 0) {
      await _routeDeleteSplit(tunIdx, '0.0.0.0', debugLog);
      await _rollbackAddedHostRoutes(safeIps, gw, phyIdx, debugLog);
      throw Exception(
        'Windows: не удалось добавить маршрут 128.0.0.0/1 через TUN (код $code).',
      );
    }

    _undo = [tunIdx, phyIdx, ...safeIps.map(_ipv4ToInt)];
    debugLog?.call('VpnWindowsFullTunnel: IPv4 via TUN ifIndex=$tunIdx');
  }

  Future<void> remove({void Function(String message)? debugLog}) async {
    final u = _undo;
    _undo = null;
    if (u == null || u.length < 2) return;

    final tunIdx = u[0];
    final phyIdx = u[1];
    final serverInts = u.sublist(2);

    await _routeDeleteSplit(tunIdx, '0.0.0.0', debugLog);
    await _routeDeleteSplit(tunIdx, '128.0.0.0', debugLog);

    for (final n in serverInts) {
      final ip = _intToIpv4(n);
      await _routeDeleteHost(ip, phyIdx, debugLog);
    }
  }

  static Future<List<String>> _resolveServerIpv4(String host) async {
    final h = host.trim();
    if (_ipv4Re.hasMatch(h)) {
      return [h];
    }
    try {
      final addrs = await InternetAddress.lookup(h).timeout(
        const Duration(seconds: 12),
        onTimeout: () => throw TimeoutException('DNS lookup for $h'),
      );
      final out = <String>{};
      for (final a in addrs) {
        if (a.type == InternetAddressType.IPv4) {
          out.add(a.address);
        }
      }
      return out.toList();
    } on SocketException catch (_) {
      return [];
    } on TimeoutException catch (_) {
      return [];
    }
  }

  /// Returns `(gateway, interfaceIndex)` for the best IPv4 default route.
  Future<(String, int)?> _powershellDefaultRouteV4() async {
    const script = r'''
$r = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -AddressFamily IPv4 -ErrorAction SilentlyContinue |
  Where-Object { $null -ne $_.NextHop -and $_.NextHop -ne '0.0.0.0' } |
  Sort-Object -Property RouteMetric |
  Select-Object -First 1
if ($null -eq $r) { exit 2 }
Write-Output ($r.NextHop + '|' + $r.InterfaceIndex)
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
      if (r.exitCode != 0) return null;
      final line = (r.stdout as String).trim().split('\n').last.trim();
      final parts = line.split('|');
      if (parts.length != 2) return null;
      final gw = parts[0].trim();
      final idx = int.tryParse(parts[1].trim());
      if (idx == null) return null;
      return (gw, idx);
    } catch (_) {
      return null;
    }
  }

  /// One PowerShell process with an internal loop (was: up to 50× separate powershell.exe — very slow).
  Future<int?> _waitForTunInterfaceIndex({
    String? preferredName,
    void Function(String message)? debugLog,
  }) async {
    final escaped = preferredName == null || preferredName.isEmpty
        ? ''
        : preferredName.replaceAll("'", "''");
    final script = preferredName == null || preferredName.isEmpty
        ? '''
for (\$i = 0; \$i -lt 45; \$i++) {
  \$adapters = @(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object {
    \$_.Name -eq 'xray0' -or
    \$_.InterfaceDescription -like '*Wintun*' -or
    \$_.InterfaceDescription -like '*Xray*'
  } | Sort-Object -Property ifIndex)
  if (\$adapters.Count -gt 0) {
    \$exact = @(\$adapters | Where-Object { \$_.Name -eq 'xray0' } | Select-Object -First 1)
    if (\$exact.Count -gt 0) { Write-Output \$exact[0].ifIndex; exit 0 }
    Write-Output \$adapters[0].ifIndex
    exit 0
  }
  Start-Sleep -Milliseconds 35
}
exit 3
'''
        : '''
\$pn = '$escaped'
for (\$i = 0; \$i -lt 45; \$i++) {
  \$a = Get-NetAdapter -Name \$pn -ErrorAction SilentlyContinue
  if (\$null -ne \$a) { Write-Output \$a.ifIndex; exit 0 }
  \$adapters = @(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object {
    \$_.Name -eq 'xray0' -or
    \$_.InterfaceDescription -like '*Wintun*' -or
    \$_.InterfaceDescription -like '*Xray*'
  } | Sort-Object -Property ifIndex)
  if (\$adapters.Count -gt 0) {
    \$exact = @(\$adapters | Where-Object { \$_.Name -eq \$pn } | Select-Object -First 1)
    if (\$exact.Count -gt 0) { Write-Output \$exact[0].ifIndex; exit 0 }
    \$exact2 = @(\$adapters | Where-Object { \$_.Name -eq 'xray0' } | Select-Object -First 1)
    if (\$exact2.Count -gt 0) { Write-Output \$exact2[0].ifIndex; exit 0 }
    Write-Output \$adapters[0].ifIndex
    exit 0
  }
  Start-Sleep -Milliseconds 35
}
exit 3
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
      if (r.exitCode != 0) {
        debugLog?.call('VpnWindowsFullTunnel: TUN adapter not found in time');
        return null;
      }
      final line = (r.stdout as String).trim().split('\n').last.trim();
      return int.tryParse(line);
    } catch (_) {
      debugLog?.call('VpnWindowsFullTunnel: TUN poll failed');
      return null;
    }
  }

  Future<int> _routeAddHostViaGateway(
    String serverIp,
    String gateway,
    int phyIfIndex,
    void Function(String message)? debugLog,
  ) async {
    final r = await Process.run(
      'route',
      [
        'add',
        serverIp,
        'mask',
        '255.255.255.255',
        gateway,
        'metric',
        '1',
        'if',
        '$phyIfIndex',
      ],
      runInShell: false,
    );
    if (r.exitCode != 0) {
      debugLog?.call(
        'VpnWindowsFullTunnel: route add host failed ${r.exitCode} stderr=${r.stderr}',
      );
    }
    return r.exitCode;
  }

  Future<int> _routeAddSplitDefault(
    int tunIfIndex,
    String dest,
    void Function(String message)? debugLog,
  ) async {
    final r = await Process.run(
      'route',
      [
        'add',
        dest,
        'mask',
        '128.0.0.0',
        '0.0.0.0',
        'metric',
        '1',
        'if',
        '$tunIfIndex',
      ],
      runInShell: false,
    );
    if (r.exitCode != 0) {
      debugLog?.call(
        'VpnWindowsFullTunnel: route add split $dest failed ${r.exitCode} stderr=${r.stderr}',
      );
    }
    return r.exitCode;
  }

  Future<void> _routeDeleteSplit(
    int tunIfIndex,
    String dest,
    void Function(String message)? debugLog,
  ) async {
    try {
      final r = await Process.run(
        'route',
        ['delete', dest, 'mask', '128.0.0.0', 'if', '$tunIfIndex'],
        runInShell: false,
      );
      if (r.exitCode != 0) {
        debugLog?.call('VpnWindowsFullTunnel: route delete $dest exit ${r.exitCode}');
      }
    } catch (e) {
      debugLog?.call('VpnWindowsFullTunnel: route delete $dest failed: $e');
    }
  }

  Future<void> _routeDeleteHost(
    String serverIp,
    int phyIfIndex,
    void Function(String message)? debugLog,
  ) async {
    try {
      final r = await Process.run(
        'route',
        ['delete', serverIp, 'mask', '255.255.255.255', 'if', '$phyIfIndex'],
        runInShell: false,
      );
      if (r.exitCode != 0) {
        await Process.run(
          'route',
          ['delete', serverIp],
          runInShell: false,
        );
      }
    } catch (e) {
      debugLog?.call('VpnWindowsFullTunnel: route delete host failed: $e');
    }
  }

  Future<void> _rollbackAddedHostRoutes(
    List<String> safeIps,
    String gw,
    int phyIdx,
    void Function(String message)? debugLog,
  ) async {
    for (final ip in safeIps) {
      await _routeDeleteHost(ip, phyIdx, debugLog);
    }
  }

  static int _ipv4ToInt(String ip) {
    final p = ip.split('.');
    var n = 0;
    for (final x in p) {
      n = (n << 8) + (int.parse(x) & 0xff);
    }
    return n;
  }

  static String _intToIpv4(int n) {
    return '${(n >> 24) & 0xff}.${(n >> 16) & 0xff}.${(n >> 8) & 0xff}.${n & 0xff}';
  }
}
