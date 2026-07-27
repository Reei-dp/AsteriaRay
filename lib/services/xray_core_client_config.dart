import '../models/routing_profile.dart';
import '../models/vless_profile.dart';
import 'xray_core_stream_settings.dart';
import 'xray_net_utils.dart';
import 'xray_routing_builder.dart';

const _userLevel = 8;

/// Full Xray-core JSON for TUN + VLESS (Android VPN fd, Linux `tun`, Windows Wintun).
Map<String, dynamic> buildXrayCoreClientConfig(
  VlessProfile profile,
  bool useDoh, {
  RoutingProfile? routing,
}) {
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

  final dns = routing != null
      ? XrayRoutingBuilder.buildDns(profile, routing, needsBootstrap)
      : _xrayDns(profile, useDoh, needsBootstrap);

  final routingBlock = routing != null
      ? XrayRoutingBuilder.buildRouting(routing)
      : {
          'domainStrategy': 'IPIfNonMatch',
          'rules': _defaultRoutingRules(),
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
    'dns': dns,
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
    'routing': routingBlock,
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

  return {
    'hosts': <String, dynamic>{},
    'servers': servers,
    'queryStrategy': 'UseIPv4',
  };
}

List<Map<String, dynamic>> _defaultRoutingRules() {
  const analyticsSuffixes = [
    'appcenter.ms',
    'firebase.io',
    'crashlytics.com',
  ];

  return [
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
    {
      'type': 'field',
      'domain': [for (final s in analyticsSuffixes) 'domain:$s'],
      'outboundTag': 'block',
    },
    {
      'type': 'field',
      'ip': ['224.0.0.0/3', 'ff00::/8'],
      'outboundTag': 'block',
    },
    {
      'type': 'field',
      'network': 'tcp,udp',
      'outboundTag': 'proxy',
    },
  ];
}
