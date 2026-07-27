import 'dart:convert';

/// Happ-style routing profile (https://www.happ.su/main/dev-docs/routing).
class RoutingProfile {
  const RoutingProfile({
    required this.name,
    this.globalProxy = true,
    this.routeOrder = RouteOrder.blockDirectProxy,
    this.remoteDnsType = DnsType.dou,
    this.remoteDnsDomain = '',
    this.remoteDnsIp = '1.1.1.1',
    this.domesticDnsType = DnsType.dou,
    this.domesticDnsDomain = '',
    this.domesticDnsIp = '1.0.0.1',
    this.geoipUrl,
    this.geositeUrl,
    this.dnsHosts = const {},
    this.directSites = const [],
    this.directIp = const [],
    this.proxySites = const [],
    this.proxyIp = const [],
    this.blockSites = const [],
    this.blockIp = const [],
    this.domainStrategy = 'IPIfNonMatch',
    this.fakeDns = false,
    this.subscriptionId,
    this.lastUpdated,
  });

  final String name;
  final bool globalProxy;
  final RouteOrder routeOrder;
  final DnsType remoteDnsType;
  final String remoteDnsDomain;
  final String remoteDnsIp;
  final DnsType domesticDnsType;
  final String domesticDnsDomain;
  final String domesticDnsIp;
  final String? geoipUrl;
  final String? geositeUrl;
  final Map<String, String> dnsHosts;
  final List<String> directSites;
  final List<String> directIp;
  final List<String> proxySites;
  final List<String> proxyIp;
  final List<String> blockSites;
  final List<String> blockIp;
  final String domainStrategy;
  final bool fakeDns;
  final String? subscriptionId;
  final DateTime? lastUpdated;

  RoutingProfile copyWith({
    String? name,
    bool? globalProxy,
    RouteOrder? routeOrder,
    DnsType? remoteDnsType,
    String? remoteDnsDomain,
    String? remoteDnsIp,
    DnsType? domesticDnsType,
    String? domesticDnsDomain,
    String? domesticDnsIp,
    String? geoipUrl,
    String? geositeUrl,
    Map<String, String>? dnsHosts,
    List<String>? directSites,
    List<String>? directIp,
    List<String>? proxySites,
    List<String>? proxyIp,
    List<String>? blockSites,
    List<String>? blockIp,
    String? domainStrategy,
    bool? fakeDns,
    String? subscriptionId,
    DateTime? lastUpdated,
  }) {
    return RoutingProfile(
      name: name ?? this.name,
      globalProxy: globalProxy ?? this.globalProxy,
      routeOrder: routeOrder ?? this.routeOrder,
      remoteDnsType: remoteDnsType ?? this.remoteDnsType,
      remoteDnsDomain: remoteDnsDomain ?? this.remoteDnsDomain,
      remoteDnsIp: remoteDnsIp ?? this.remoteDnsIp,
      domesticDnsType: domesticDnsType ?? this.domesticDnsType,
      domesticDnsDomain: domesticDnsDomain ?? this.domesticDnsDomain,
      domesticDnsIp: domesticDnsIp ?? this.domesticDnsIp,
      geoipUrl: geoipUrl ?? this.geoipUrl,
      geositeUrl: geositeUrl ?? this.geositeUrl,
      dnsHosts: dnsHosts ?? this.dnsHosts,
      directSites: directSites ?? this.directSites,
      directIp: directIp ?? this.directIp,
      proxySites: proxySites ?? this.proxySites,
      proxyIp: proxyIp ?? this.proxyIp,
      blockSites: blockSites ?? this.blockSites,
      blockIp: blockIp ?? this.blockIp,
      domainStrategy: domainStrategy ?? this.domainStrategy,
      fakeDns: fakeDns ?? this.fakeDns,
      subscriptionId: subscriptionId ?? this.subscriptionId,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'globalProxy': globalProxy,
        'routeOrder': routeOrder.storageKey,
        'remoteDnsType': remoteDnsType.name,
        'remoteDnsDomain': remoteDnsDomain,
        'remoteDnsIp': remoteDnsIp,
        'domesticDnsType': domesticDnsType.name,
        'domesticDnsDomain': domesticDnsDomain,
        'domesticDnsIp': domesticDnsIp,
        if (geoipUrl != null) 'geoipUrl': geoipUrl,
        if (geositeUrl != null) 'geositeUrl': geositeUrl,
        'dnsHosts': dnsHosts,
        'directSites': directSites,
        'directIp': directIp,
        'proxySites': proxySites,
        'proxyIp': proxyIp,
        'blockSites': blockSites,
        'blockIp': blockIp,
        'domainStrategy': domainStrategy,
        'fakeDns': fakeDns,
        if (subscriptionId != null) 'subscriptionId': subscriptionId,
        if (lastUpdated != null) 'lastUpdated': lastUpdated!.toIso8601String(),
      };

  factory RoutingProfile.fromMap(Map<String, dynamic> map) {
    return RoutingProfile(
      name: map['name'] as String? ?? 'Profile',
      globalProxy: map['globalProxy'] as bool? ?? true,
      routeOrder: routeOrderFromStorage(map['routeOrder'] as String?),
      remoteDnsType: dnsTypeFromString(map['remoteDnsType'] as String?),
      remoteDnsDomain: map['remoteDnsDomain'] as String? ?? '',
      remoteDnsIp: map['remoteDnsIp'] as String? ?? '1.1.1.1',
      domesticDnsType: dnsTypeFromString(map['domesticDnsType'] as String?),
      domesticDnsDomain: map['domesticDnsDomain'] as String? ?? '',
      domesticDnsIp: map['domesticDnsIp'] as String? ?? '1.0.0.1',
      geoipUrl: map['geoipUrl'] as String?,
      geositeUrl: map['geositeUrl'] as String?,
      dnsHosts: _stringMap(map['dnsHosts']),
      directSites: _stringList(map['directSites']),
      directIp: _stringList(map['directIp']),
      proxySites: _stringList(map['proxySites']),
      proxyIp: _stringList(map['proxyIp']),
      blockSites: _stringList(map['blockSites']),
      blockIp: _stringList(map['blockIp']),
      domainStrategy: map['domainStrategy'] as String? ?? 'IPIfNonMatch',
      fakeDns: map['fakeDns'] as bool? ?? false,
      subscriptionId: map['subscriptionId'] as String?,
      lastUpdated: map['lastUpdated'] != null
          ? DateTime.tryParse(map['lastUpdated'] as String)
          : null,
    );
  }

  /// Parse Happ JSON (`Name`, `GlobalProxy`, …).
  factory RoutingProfile.fromHappJson(
    Map<String, dynamic> json, {
    String? subscriptionId,
  }) {
    return RoutingProfile(
      name: _str(json['Name']) ?? 'Profile',
      globalProxy: _bool(json['GlobalProxy'], defaultValue: true),
      routeOrder: routeOrderFromHapp(json['RouteOrder'] as String?),
      remoteDnsType: dnsTypeFromString(json['RemoteDNSType'] as String?),
      remoteDnsDomain: _str(json['RemoteDNSDomain']) ?? '',
      remoteDnsIp: _str(json['RemoteDNSIP']) ?? '1.1.1.1',
      domesticDnsType: dnsTypeFromString(json['DomesticDNSType'] as String?),
      domesticDnsDomain: _str(json['DomesticDNSDomain']) ?? '',
      domesticDnsIp: _str(json['DomesticDNSIP']) ?? '1.0.0.1',
      geoipUrl: _emptyToNull(_str(json['Geoipurl'] ?? json['GeoipUrl'])),
      geositeUrl: _emptyToNull(_str(json['Geositeurl'] ?? json['GeositeUrl'])),
      dnsHosts: _stringMap(json['DnsHosts']),
      directSites: _stringList(json['DirectSites']),
      directIp: _stringList(json['DirectIp']),
      proxySites: _stringList(json['ProxySites']),
      proxyIp: _stringList(json['ProxyIp']),
      blockSites: _stringList(json['BlockSites']),
      blockIp: _stringList(json['BlockIp']),
      domainStrategy: _str(json['DomainStrategy']) ?? 'IPIfNonMatch',
      fakeDns: _bool(json['FakeDNS'], defaultValue: false),
      subscriptionId: subscriptionId,
      lastUpdated: DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory RoutingProfile.fromJson(String source) =>
      RoutingProfile.fromMap(jsonDecode(source) as Map<String, dynamic>);

  static List<String> _stringList(dynamic v) {
    if (v is! List) return const [];
    return v.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
  }

  static Map<String, String> _stringMap(dynamic v) {
    if (v is! Map) return const {};
    return v.map((k, val) => MapEntry(k.toString(), val.toString()));
  }

  static String? _str(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static String? _emptyToNull(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    return s.trim();
  }

  static bool _bool(dynamic v, {required bool defaultValue}) {
    if (v == null) return defaultValue;
    if (v is bool) return v;
    final s = v.toString().trim().toLowerCase();
    if (s == 'true' || s == '1') return true;
    if (s == 'false' || s == '0') return false;
    return defaultValue;
  }
}

enum DnsType { dou, doh }

extension DnsTypeX on DnsType {
  String get label => this == DnsType.doh ? 'DoH' : 'DoU';
}

DnsType dnsTypeFromString(String? raw) {
  final s = raw?.trim().toLowerCase() ?? '';
  if (s == 'doh') return DnsType.doh;
  return DnsType.dou;
}

enum RouteOrder {
  blockDirectProxy,
  blockProxyDirect,
  proxyDirectBlock,
  proxyBlockDirect,
  directProxyBlock,
  directBlockProxy,
}

extension RouteOrderX on RouteOrder {
  String get storageKey {
    switch (this) {
      case RouteOrder.blockDirectProxy:
        return 'block-direct-proxy';
      case RouteOrder.blockProxyDirect:
        return 'block-proxy-direct';
      case RouteOrder.proxyDirectBlock:
        return 'proxy-direct-block';
      case RouteOrder.proxyBlockDirect:
        return 'proxy-block-direct';
      case RouteOrder.directProxyBlock:
        return 'direct-proxy-block';
      case RouteOrder.directBlockProxy:
        return 'direct-block-proxy';
    }
  }

  String displayLabel(String block, String direct, String proxy) {
    final parts = switch (this) {
      RouteOrder.blockDirectProxy => [block, direct, proxy],
      RouteOrder.blockProxyDirect => [block, proxy, direct],
      RouteOrder.proxyDirectBlock => [proxy, direct, block],
      RouteOrder.proxyBlockDirect => [proxy, block, direct],
      RouteOrder.directProxyBlock => [direct, proxy, block],
      RouteOrder.directBlockProxy => [direct, block, proxy],
    };
    return parts.join(' → ');
  }

  Iterable<RouteCategory> get categories sync* {
    switch (this) {
      case RouteOrder.blockDirectProxy:
        yield RouteCategory.block;
        yield RouteCategory.direct;
        yield RouteCategory.proxy;
      case RouteOrder.blockProxyDirect:
        yield RouteCategory.block;
        yield RouteCategory.proxy;
        yield RouteCategory.direct;
      case RouteOrder.proxyDirectBlock:
        yield RouteCategory.proxy;
        yield RouteCategory.direct;
        yield RouteCategory.block;
      case RouteOrder.proxyBlockDirect:
        yield RouteCategory.proxy;
        yield RouteCategory.block;
        yield RouteCategory.direct;
      case RouteOrder.directProxyBlock:
        yield RouteCategory.direct;
        yield RouteCategory.proxy;
        yield RouteCategory.block;
      case RouteOrder.directBlockProxy:
        yield RouteCategory.direct;
        yield RouteCategory.block;
        yield RouteCategory.proxy;
    }
  }
}

RouteOrder routeOrderFromStorage(String? raw) => routeOrderFromHapp(raw);

RouteOrder routeOrderFromHapp(String? raw) {
  final s = raw?.trim().toLowerCase().replaceAll('_', '-').replaceAll(' ', '-');
  return switch (s) {
    'block-proxy-direct' => RouteOrder.blockProxyDirect,
    'proxy-direct-block' => RouteOrder.proxyDirectBlock,
    'proxy-block-direct' => RouteOrder.proxyBlockDirect,
    'direct-proxy-block' => RouteOrder.directProxyBlock,
    'direct-block-proxy' => RouteOrder.directBlockProxy,
    _ => RouteOrder.blockDirectProxy,
  };
}

enum RouteCategory { block, direct, proxy }

class HappRoutingImport {
  const HappRoutingImport({
    this.profile,
    this.activate = false,
    this.disableRouting = false,
  });

  final RoutingProfile? profile;
  final bool activate;
  final bool disableRouting;
}
