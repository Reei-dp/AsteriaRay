import '../models/routing_profile.dart';
import '../models/vless_profile.dart';

const _analyticsSuffixes = [
  'appcenter.ms',
  'firebase.io',
  'crashlytics.com',
];

/// Builds Xray DNS + routing from Happ routing profile.
abstract final class XrayRoutingBuilder {
  XrayRoutingBuilder._();

  static Map<String, dynamic> buildDns(
    VlessProfile profile,
    RoutingProfile routing,
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

    final remote = _dnsServer(
      type: routing.remoteDnsType,
      ip: routing.remoteDnsIp,
      domain: routing.remoteDnsDomain,
    );
    if (remote != null) servers.add(remote);

    final domestic = _dnsServer(
      type: routing.domesticDnsType,
      ip: routing.domesticDnsIp,
      domain: routing.domesticDnsDomain,
    );
    if (domestic != null) servers.add(domestic);

    if (servers.isEmpty) {
      servers.add('1.1.1.1');
    }

    return {
      'hosts': routing.dnsHosts,
      'servers': servers,
      'queryStrategy': 'UseIPv4',
      if (routing.fakeDns) 'disableCache': false,
    };
  }

  static dynamic _dnsServer({
    required DnsType type,
    required String ip,
    required String domain,
  }) {
    if (type == DnsType.doh) {
      final d = domain.trim();
      if (d.isNotEmpty) return d;
      final host = ip.trim();
      if (host.startsWith('http')) return host;
      if (host.isNotEmpty) return 'https://$host/dns-query';
      return null;
    }
    final host = ip.trim();
    if (host.isEmpty) return null;
    if (host.contains('://')) return host;
    return host;
  }

  static Map<String, dynamic> buildRouting(RoutingProfile routing) {
    return {
      'domainStrategy': routing.domainStrategy,
      'rules': buildRules(routing),
    };
  }

  static List<Map<String, dynamic>> buildRules(RoutingProfile routing) {
    final rules = <Map<String, dynamic>>[
      {
        'type': 'field',
        'inboundTag': ['tun-in'],
        'port': '53',
        'outboundTag': 'dns-out',
      },
    ];

    for (final category in routing.routeOrder.categories) {
      switch (category) {
        case RouteCategory.block:
          _addDomainRule(rules, routing.blockSites, 'block');
          _addIpRule(rules, routing.blockIp, 'block');
        case RouteCategory.direct:
          _addDomainRule(rules, routing.directSites, 'direct');
          _addIpRule(rules, routing.directIp, 'direct');
        case RouteCategory.proxy:
          _addDomainRule(rules, routing.proxySites, 'proxy');
          _addIpRule(rules, routing.proxyIp, 'proxy');
      }
    }

    rules.add({
      'type': 'field',
      'domain': [for (final s in _analyticsSuffixes) 'domain:$s'],
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
      'outboundTag': routing.globalProxy ? 'proxy' : 'direct',
    });

    return rules;
  }

  static void _addDomainRule(
    List<Map<String, dynamic>> rules,
    List<String> domains,
    String outbound,
  ) {
    if (domains.isEmpty) return;
    rules.add({
      'type': 'field',
      'domain': domains,
      'outboundTag': outbound,
    });
  }

  static void _addIpRule(
    List<Map<String, dynamic>> rules,
    List<String> ips,
    String outbound,
  ) {
    if (ips.isEmpty) return;
    rules.add({
      'type': 'field',
      'ip': ips,
      'outboundTag': outbound,
    });
  }
}
