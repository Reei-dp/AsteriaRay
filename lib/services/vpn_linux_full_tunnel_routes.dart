import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Must match [xray_core_client_config] `tun` inbound `settings.name`.
const kXrayLinuxTunName = 'xray0';

final _ipv4Re = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
final _ifaceRe = RegExp(r'^[a-zA-Z0-9._-]+$');

class _Ipv4DefaultRoute {
  const _Ipv4DefaultRoute({required this.via, required this.device});
  final String via;
  final String device;
}

/// Xray Linux TUN only creates `xray0`; it does not configure system routing (see Xray `proxy/tun/README.md`).
/// We add split IPv4 defaults + /32 to the VLESS server via the physical gateway (avoids routing loops).
///
/// Prefer [bundleRouteHelperScript] (`linux/asteriaray-vpn-routes.sh`) + `/etc/sudoers.d` NOPASSWD so
/// `sudo -n` works and pkexec is not shown every connect/disconnect.
class VpnLinuxFullTunnelRoutes {
  /// Full argv for undo: `[script, undo, tun, gw, dev, ...ips]`.
  List<String>? _undoArgv;

  bool get isActive => _undoArgv != null;

  static String defaultRouteHelperPath() {
    final exe = File(Platform.resolvedExecutable);
    return p.join(exe.parent.path, 'asteriaray-vpn-routes.sh');
  }

  Future<void> apply({
    required String vlessServerHost,
    required Future<int> Function(List<String> argv) runElevatedArgv,
    required Future<int> Function(String shellScript) runElevatedSh,
    void Function(String message)? debugLog,
  }) async {
    await remove(
      runElevatedArgv: runElevatedArgv,
      runElevatedSh: runElevatedSh,
      debugLog: debugLog,
    );

    final def = await _parseDefaultRouteV4();
    if (def == null) {
      debugLog?.call('VpnLinuxFullTunnel: no IPv4 default route; skipping policy routes');
      return;
    }
    if (!_ipv4Re.hasMatch(def.via) || !_ifaceRe.hasMatch(def.device)) {
      debugLog?.call('VpnLinuxFullTunnel: parsed default route looks unsafe; skipping');
      return;
    }

    final serverIps = await _resolveServerIpv4(vlessServerHost);
    if (serverIps.isEmpty) {
      debugLog?.call('VpnLinuxFullTunnel: no IPv4 for $vlessServerHost; skipping policy routes');
      return;
    }

    final safeIps = serverIps.where(_ipv4Re.hasMatch).toList();
    if (safeIps.isEmpty) return;

    await _waitForTunInterface(debugLog: debugLog);

    final helper = defaultRouteHelperPath();
    final useHelper = File(helper).existsSync();

    int code;
    if (useHelper) {
      final argv = <String>[
        helper,
        'apply',
        def.via,
        def.device,
        kXrayLinuxTunName,
        ...safeIps,
      ];
      code = await runElevatedArgv(argv);
      if (code == 0) {
        _undoArgv = <String>[
          helper,
          'undo',
          kXrayLinuxTunName,
          def.via,
          def.device,
          ...safeIps,
        ];
      }
    } else {
      final applyLines = <String>[
        for (final ip in safeIps)
          'ip -4 route replace $ip/32 via ${def.via} dev ${def.device}',
        'ip -4 route replace 0.0.0.0/1 dev $kXrayLinuxTunName',
        'ip -4 route replace 128.0.0.0/1 dev $kXrayLinuxTunName',
      ];
      final undoLines = <String>[
        'ip -4 route del 0.0.0.0/1 dev $kXrayLinuxTunName || true',
        'ip -4 route del 128.0.0.0/1 dev $kXrayLinuxTunName || true',
        for (final ip in safeIps) 'ip -4 route del $ip/32 via ${def.via} dev ${def.device} || true',
      ];
      code = await runElevatedSh(applyLines.join(' && '));
      if (code == 0) {
        _undoScriptLegacy = undoLines.join(' && ');
      }
    }

    if (code != 0) {
      throw Exception(
        'Linux: не удалось настроить маршруты для TUN (код $code). '
        'Нужны права (sudo/pkexec). Чтобы не вводить пароль каждый раз: см. linux/sudoers.d/asteriaray-vpn.example',
      );
    }

    debugLog?.call('VpnLinuxFullTunnel: IPv4 traffic steered via $kXrayLinuxTunName');
  }

  /// Legacy undo when helper script was missing at apply time.
  String? _undoScriptLegacy;

  Future<void> remove({
    required Future<int> Function(List<String> argv) runElevatedArgv,
    required Future<int> Function(String shellScript) runElevatedSh,
    void Function(String message)? debugLog,
  }) async {
    final argv = _undoArgv;
    _undoArgv = null;
    final legacy = _undoScriptLegacy;
    _undoScriptLegacy = null;

    if (argv != null && argv.isNotEmpty) {
      try {
        final code = await runElevatedArgv(argv);
        if (code != 0) {
          debugLog?.call('VpnLinuxFullTunnel: undo routes exit $code');
        }
      } catch (e) {
        debugLog?.call('VpnLinuxFullTunnel: undo routes failed: $e');
      }
      return;
    }
    if (legacy != null && legacy.isNotEmpty) {
      try {
        final code = await runElevatedSh(legacy);
        if (code != 0) {
          debugLog?.call('VpnLinuxFullTunnel: undo routes exit $code');
        }
      } catch (e) {
        debugLog?.call('VpnLinuxFullTunnel: undo routes failed: $e');
      }
    }
  }

  static Future<List<String>> _resolveServerIpv4(String host) async {
    try {
      final addrs = await InternetAddress.lookup(host);
      final out = <String>{};
      for (final a in addrs) {
        if (a.type == InternetAddressType.IPv4) {
          out.add(a.address);
        }
      }
      return out.toList();
    } on SocketException catch (_) {
      return [];
    }
  }

  static Future<_Ipv4DefaultRoute?> _parseDefaultRouteV4() async {
    try {
      final r = await Process.run('ip', ['-json', '-4', 'route', 'show', 'default']);
      if (r.exitCode == 0 && (r.stdout as String).isNotEmpty) {
        final decoded = jsonDecode(r.stdout as String);
        if (decoded is List && decoded.isNotEmpty) {
          final rows = List<Map<String, dynamic>>.from(
            decoded.map((e) => Map<String, dynamic>.from(e as Map)),
          );
          rows.sort((a, b) {
            final ma = (a['metric'] as num?)?.toInt() ?? 99999;
            final mb = (b['metric'] as num?)?.toInt() ?? 99999;
            return ma.compareTo(mb);
          });
          for (final row in rows) {
            final dev = row['dev'] as String?;
            final via = row['gateway'] as String?;
            if (dev != null && via != null && _ifaceRe.hasMatch(dev) && _ipv4Re.hasMatch(via)) {
              return _Ipv4DefaultRoute(via: via, device: dev);
            }
          }
        }
      }
    } catch (_) {}

    try {
      final r = await Process.run('ip', ['-4', 'route', 'show', 'default']);
      if (r.exitCode != 0) return null;
      final line = (r.stdout as String).split('\n').first.trim();
      final viaM = RegExp(r'default via (\S+) dev (\S+)').firstMatch(line);
      if (viaM != null) {
        return _Ipv4DefaultRoute(via: viaM.group(1)!, device: viaM.group(2)!);
      }
    } catch (_) {}

    return null;
  }

  static Future<void> _waitForTunInterface({
    void Function(String message)? debugLog,
  }) async {
    for (var i = 0; i < 40; i++) {
      try {
        final r = await Process.run('ip', ['link', 'show', kXrayLinuxTunName]);
        if (r.exitCode == 0 && (r.stdout as String).contains('UP')) {
          return;
        }
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    debugLog?.call('VpnLinuxFullTunnel: $kXrayLinuxTunName not UP in time; applying routes anyway');
  }
}
