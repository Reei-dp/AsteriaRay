import '../models/vless_profile.dart';
import 'xray_core_stream_settings.dart';
import 'xray_net_utils.dart';

const _userLevel = 8;

const _analyticsSuffixes = [
  'appcenter.ms',
  'firebase.io',
  'crashlytics.com',
];

/// Full Xray-core JSON for TUN + VLESS (Android VPN fd, Linux `tun`, Windows Wintun).
Map<String, dynamic> buildXrayCoreClientConfig(
  VlessProfile profile,
  bool useDoh,
) {
  final needsBootstrap = xrayHostNeedsDnsBootstrap(profile.host);
  final stream = xrayVlessStreamSettings(profile);

  final user = <String, dynamic>{
    'id': profile.uuid,
    'encryption': profile.encryption,
    'level': _userLevel,
  };
  if (profile.flow != null && profile.flow!.isNotEmpty) {
    user['flow'] = profile.flow;
  }

  final proxyOutbound = <String, dynamic>{
    'tag': 'proxy',
    'protocol': 'vless',
    'settings': {
      'vnext': [
        {
          'address': profile.host,
          'port': profile.port,
          'users': [user],
        },
      ],
    },
    'streamSettings': stream,
    'mux': {'enabled': false},
  };

  return {
    'stats': <String, dynamic>{},
    'log': {
      'loglevel': 'debug',
    },
    'policy': {
      'levels': {
        '$_userLevel': {
          'handshake': 4,
          'connIdle': 300,
          'uplinkOnly': 1,
          'downlinkOnly': 1,
        },
      },
      'system': {
        'statsOutboundUplink': true,
        'statsOutboundDownlink': true,
      },
    },
    'dns': _xrayDns(profile, useDoh, needsBootstrap),
    // TUN-only: no SOCKS on 127.0.0.1 (not needed for tunnel; on Windows :2080 can hit "Access is denied").
    'inbounds': [
      {
        'tag': 'tun-in',
        'port': 0,
        'protocol': 'tun',
        'settings': {
          'name': 'xray0',
          'MTU': 1500,
          'userLevel': _userLevel,
        },
        'sniffing': _sniffing(),
      },
    ],
    'outbounds': [
      proxyOutbound,
      {
        'tag': 'dns-out',
        'protocol': 'dns',
      },
      {
        'tag': 'direct',
        'protocol': 'freedom',
        'settings': {
          'domainStrategy': 'UseIP',
        },
      },
      {
        'tag': 'block',
        'protocol': 'blackhole',
        'settings': {
          'response': {'type': 'http'},
        },
      },
    ],
    'routing': {
      'domainStrategy': 'IPIfNonMatch',
      'rules': _routingRules(),
    },
  };
}

Map<String, dynamic> _sniffing() => {
      'enabled': true,
      'destOverride': ['http', 'tls', 'quic'],
    };

Map<String, dynamic> _xrayDns(
  VlessProfile profile,
  bool useDoh,
  bool needsBootstrap,
) {
  final servers = <dynamic>[];

  if (needsBootstrap) {
    servers.add({
      'address': '1.1.1.1',
      'port': 53,
      'domains': [profile.host],
      'skipFallback': true,
    });
  }

  if (useDoh) {
    servers.add('https://1.1.1.1/dns-query');
  } else {
    servers.add('8.8.8.8');
    servers.add('1.1.1.1');
  }
  // Avoid `localhost` here: on Android+gVisor TUN it often breaks internal DNS routing.

  return {
    'hosts': <String, dynamic>{},
    'servers': servers,
    'queryStrategy': 'UseIPv4',
  };
}

List<Map<String, dynamic>> _routingRules() {
  // Without this, queries to the VPN-assigned DNS (e.g. 172.19.x) match [geoip:private] → [direct]
  // and never hit Xray's [dns] stack — common "connected but no internet" on TUN (cf. v2rayNG tun + port 53 → dns-out).
  final rules = <Map<String, dynamic>>[
    {
      'type': 'field',
      'inboundTag': ['tun-in'],
      'port': '53',
      'outboundTag': 'dns-out',
    },
    {
      'type': 'field',
      'ip': ['geoip:private'],
      'outboundTag': 'direct',
    },
  ];

  rules.add({
    'type': 'field',
    'domain': [
      for (final s in _analyticsSuffixes) 'domain:$s',
    ],
    'outboundTag': 'block',
  });

  rules.add({
    'type': 'field',
    'ip': ['224.0.0.0/3', 'ff00::/8'],
    'outboundTag': 'block',
  });

  rules.add({
    'type': 'field',
    'network': 'tcp,udp',
    'outboundTag': 'proxy',
  });

  return rules;
}
