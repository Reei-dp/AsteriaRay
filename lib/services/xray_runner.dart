import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/vless_profile.dart';
import '../models/vless_types.dart';

class XrayRunner {
  static const _assetDir = 'assets/xray';

  String? _workDir;
  String? _geoipPath;
  String? _geositePath;
  String? _logPath;

  String? get logPath => _logPath;

  Future<void> prepare() async {
    final dir = await getApplicationSupportDirectory();
    final workDir = Directory(p.join(dir.path, 'xray'));
    if (!await workDir.exists()) {
      await workDir.create(recursive: true);
    }
    _workDir = workDir.path;

    final geoipPath = p.join(workDir.path, 'geoip.dat');
    final geositePath = p.join(workDir.path, 'geosite.dat');

    await _copyAsset('$_assetDir/geoip.dat', geoipPath);
    await _copyAsset('$_assetDir/geosite.dat', geositePath);

    _geoipPath = geoipPath;
    _geositePath = geositePath;
    _logPath = p.join(workDir.path, 'log.txt');
  }

  Future<XrayConfigContext> prepareConfig(
    VlessProfile profile, {
    bool useDoh = false,
  }) async {
    final workDir = _workDir ?? (await _ensurePrepared());
    final configPath = p.join(workDir, 'config.json');
    final logPath = _logPath ?? p.join(workDir, 'log.txt');

    // truncate old log
    try {
      final logFile = File(logPath);
      if (await logFile.exists()) {
        await logFile.writeAsString('');
      }
    } catch (_) {}

    final config = _buildConfig(profile, workDir, useDoh);
    final configFile = File(configPath);
    await configFile.writeAsString(jsonEncode(config));
    return XrayConfigContext(
      configPath: configPath,
      workDir: workDir,
      logPath: logPath,
    );
  }

  Future<String> _ensurePrepared() async {
    if (_workDir != null) return _workDir!;
    await prepare();
    return _workDir!;
  }

  Future<void> _copyAsset(String assetPath, String destPath) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();
    final file = File(destPath);
    await file.writeAsBytes(bytes, flush: true);
  }

  /// True when [host] is a domain name (needs bootstrap DNS); false for literal IPs.
  static bool _hostNeedsDnsBootstrap(String host) =>
      InternetAddress.tryParse(host) == null;

  /// [useDoh]: public DoH over `direct`. Otherwise UDP DNS via `proxy` (tunnel to VPS).
  ///
  /// Linux uses the sing-box 1.12+ DNS schema (typed servers, `final`, `predefined` rules).
  /// Android libcore still expects the legacy `address` strings.
  Map<String, dynamic> _buildDnsSection(VlessProfile profile, bool useDoh) {
    if (!kIsWeb && Platform.isLinux) {
      return _buildDnsSectionSingBox12(profile, useDoh);
    }
    return _buildDnsSectionLegacy(profile, useDoh);
  }

  /// sing-box ≥1.12 — see https://sing-box.sagernet.org/migration/#migrate-to-new-dns-server-formats
  Map<String, dynamic> _buildDnsSectionSingBox12(
    VlessProfile profile,
    bool useDoh,
  ) {
    final needsBootstrap = _hostNeedsDnsBootstrap(profile.host);
    const analyticsSuffixes = [
      'appcenter.ms',
      'firebase.io',
      'crashlytics.com',
    ];

    if (useDoh) {
      return {
        'independent_cache': true,
        'strategy': 'ipv4_only',
        'servers': [
          {
            'type': 'local',
            'tag': 'dns-local',
            'detour': 'direct',
          },
          if (needsBootstrap)
            {
              'type': 'udp',
              'tag': 'dns-bootstrap',
              'server': '1.1.1.1',
              'detour': 'direct',
            },
          {
            'type': 'https',
            'tag': 'dns-doh',
            'server': '1.1.1.1',
            'path': '/dns-query',
          },
        ],
        'rules': [
          if (needsBootstrap)
            {
              'domain': [profile.host],
              'action': 'route',
              'server': 'dns-bootstrap',
            },
          {
            'domain_suffix': analyticsSuffixes,
            'action': 'predefined',
            'rcode': 'NOERROR',
            'answer': <dynamic>[],
          },
        ],
        'final': 'dns-doh',
      };
    }

    return {
      'independent_cache': true,
      'strategy': 'ipv4_only',
      'servers': [
        {
          'type': 'local',
          'tag': 'dns-local',
          'detour': 'direct',
        },
        if (needsBootstrap)
          {
            'type': 'udp',
            'tag': 'dns-bootstrap',
            'server': '1.1.1.1',
            'detour': 'direct',
          },
        {
          'type': 'udp',
          'tag': 'dns-remote',
          'server': '8.8.8.8',
          'detour': 'proxy',
        },
      ],
      'rules': [
        if (needsBootstrap)
          {
            'domain': [profile.host],
            'action': 'route',
            'server': 'dns-bootstrap',
          },
        {
          'domain_suffix': analyticsSuffixes,
          'action': 'predefined',
          'rcode': 'NOERROR',
          'answer': <dynamic>[],
        },
      ],
      'final': 'dns-remote',
    };
  }

  Map<String, dynamic> _buildDnsSectionLegacy(
    VlessProfile profile,
    bool useDoh,
  ) {
    final needsBootstrap = _hostNeedsDnsBootstrap(profile.host);

    if (useDoh) {
      return {
        'independent_cache': true,
        'servers': [
          {
            'tag': 'dns-local',
            'address': 'local',
            'detour': 'direct',
          },
          if (needsBootstrap)
            {
              'tag': 'dns-bootstrap',
              'address': '1.1.1.1',
              'detour': 'direct',
              'strategy': 'ipv4_only',
            },
          // Legacy DoH URL without detour: TUN libcore rejects
          // "detour to an empty direct outbound" for type:https + detour:direct.
          {
            'tag': 'dns-doh',
            'address': 'https://1.1.1.1/dns-query',
          },
          {
            'tag': 'dns-block',
            'address': 'rcode://success',
          },
        ],
        'rules': [
          if (needsBootstrap)
            {
              'domain': [profile.host],
              'server': 'dns-bootstrap',
            },
          {
            'disable_cache': true,
            'domain_suffix': [
              'appcenter.ms',
              'firebase.io',
              'crashlytics.com',
            ],
            'server': 'dns-block',
          },
          {
            'outbound': ['any'],
            'server': 'dns-doh',
          },
        ],
      };
    }

    return {
      'independent_cache': true,
      'servers': [
        {
          'tag': 'dns-local',
          'address': 'local',
          'detour': 'direct',
        },
        if (needsBootstrap)
          {
            'tag': 'dns-bootstrap',
            'address': '1.1.1.1',
            'detour': 'direct',
            'strategy': 'ipv4_only',
          },
        {
          'tag': 'dns-remote',
          'address': '8.8.8.8',
          'detour': 'proxy',
          'strategy': 'ipv4_only',
        },
        {
          'tag': 'dns-block',
          'address': 'rcode://success',
        },
      ],
      'rules': [
        if (needsBootstrap)
          {
            'domain': [profile.host],
            'server': 'dns-bootstrap',
          },
        {
          'disable_cache': true,
          'domain_suffix': [
            'appcenter.ms',
            'firebase.io',
            'crashlytics.com',
          ],
          'server': 'dns-block',
        },
        {
          'outbound': ['any'],
          'server': 'dns-remote',
        },
      ],
    };
  }

  Map<String, dynamic> _buildConfig(
    VlessProfile profile,
    String workDir,
    bool useDoh,
  ) {
    final tlsEnabled = profile.security != 'none';
    final transport = profile.transport;
    Map<String, dynamic>? transportSettings;

    if (transport == VlessTransport.ws) {
      transportSettings = {
        'type': 'ws',
        'path': profile.path ?? '/',
        if (profile.hostHeader != null)
          'headers': {
            'Host': profile.hostHeader,
          },
      };
    } else if (transport == VlessTransport.grpc) {
      transportSettings = {
        'type': 'grpc',
        'serviceName': profile.path ?? '',
      };
    } else if (transport == VlessTransport.h2) {
      transportSettings = {
        'type': 'http',
        'path': profile.path ?? '/',
        if (profile.hostHeader != null)
          'host': [profile.hostHeader],
      };
    }

    final outbound = {
      'type': 'vless',
      'tag': 'proxy',
      'server': profile.host,
      'server_port': profile.port,
      'uuid': profile.uuid,
      'packet_encoding': '',
      if (profile.flow != null && profile.flow!.isNotEmpty) 'flow': profile.flow,
      'tls': tlsEnabled
          ? {
              'enabled': true,
              'insecure': false,
              'server_name': profile.sni ?? profile.host,
              if (profile.alpn.isNotEmpty) 'alpn': profile.alpn,
              if (profile.fingerprint != null)
                'utls': {'enabled': true, 'fingerprint': profile.fingerprint},
              if (profile.security == 'reality' &&
                  profile.realityPublicKey != null &&
                  profile.realityShortId != null)
                'reality': {
                  'enabled': true,
                  'public_key': profile.realityPublicKey!,
                  'short_id': profile.realityShortId!.toString(),
                },
            }
          : {
              'enabled': false,
            },
      if (transportSettings != null) 'transport': transportSettings,
    };

    // sing-box ≥1.13: sniff/domain_strategy on inbounds removed — use route rule actions.
    // Android libcore keeps legacy inbound fields.
    final modernSingBox = !kIsWeb && Platform.isLinux;

    final tunInbound = <String, dynamic>{
      'type': 'tun',
      'tag': 'tun-in',
      'address': ['172.19.0.1/30'],
      'auto_route': true,
      'strict_route': false,
      'mtu': 1500,
      'stack': 'mixed',
      'endpoint_independent_nat': true,
    };
    if (!modernSingBox) {
      tunInbound['sniff'] = true;
      tunInbound['sniff_override_destination'] = false;
      tunInbound['domain_strategy'] = 'ipv4_only';
    }

    final mixedInbound = <String, dynamic>{
      'type': 'mixed',
      'tag': 'mixed-in',
      'listen': '127.0.0.1',
      'listen_port': 2080,
    };
    if (!modernSingBox) {
      mixedInbound['sniff'] = true;
      mixedInbound['sniff_override_destination'] = false;
      mixedInbound['domain_strategy'] = 'ipv4_only';
    }

    final routeRules = <Map<String, dynamic>>[
      if (modernSingBox) ...[
        {
          'inbound': 'tun-in',
          'action': 'resolve',
          'strategy': 'ipv4_only',
        },
        {'inbound': 'tun-in', 'action': 'sniff'},
        {
          'inbound': 'mixed-in',
          'action': 'resolve',
          'strategy': 'ipv4_only',
        },
        {'inbound': 'mixed-in', 'action': 'sniff'},
      ],
      {
        'action': 'hijack-dns',
        'port': [53],
      },
      {
        'action': 'hijack-dns',
        'protocol': ['dns'],
      },
      {
        'outbound': 'direct',
        'domain': [profile.host],
      },
      {
        'action': 'reject',
        'domain_suffix': [
          'appcenter.ms',
          'firebase.io',
          'crashlytics.com',
        ],
      },
      {
        'action': 'reject',
        'ip_cidr': ['224.0.0.0/3', 'ff00::/8'],
        'source_ip_cidr': ['224.0.0.0/3', 'ff00::/8'],
      },
    ];

    final needsBootstrap = _hostNeedsDnsBootstrap(profile.host);
    final routeBody = <String, dynamic>{
      'auto_detect_interface': true,
      'rules': routeRules,
      'final': 'proxy',
    };
    // sing-box ≥1.12: outbound dial must know which dns server resolves domain names (VLESS server, etc.)
    if (modernSingBox) {
      routeBody['default_domain_resolver'] = {
        'server': needsBootstrap
            ? 'dns-bootstrap'
            : (useDoh ? 'dns-doh' : 'dns-remote'),
      };
    }

    return {
      'log': {
        'level': 'debug',
        'timestamp': true,
      },
      'dns': _buildDnsSection(profile, useDoh),
      'inbounds': [
        tunInbound,
        mixedInbound,
      ],
      'outbounds': [
        outbound,
        {
          'type': 'direct',
          'tag': 'direct',
        },
        {
          'type': 'direct',
          'tag': 'bypass',
        },
      ],
      'route': routeBody,
    };
  }
}

class XrayConfigContext {
  final String configPath;
  final String workDir;
  final String logPath;

  XrayConfigContext({
    required this.configPath,
    required this.workDir,
    required this.logPath,
  });
}


