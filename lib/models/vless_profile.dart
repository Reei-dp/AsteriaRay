import 'dart:convert';

import '../models/vless_types.dart';
import '../services/vless_uri.dart';

class VlessProfile {
  final String id;
  final String name;
  final String host;
  final int port;
  final String uuid;
  final String encryption; // usually "none"
  final String security; // none | tls | reality
  final String? sni;
  final List<String> alpn;
  final String? fingerprint;
  final String? flow;
  final String? realityPublicKey; // For Reality protocol
  final String? realityShortId; // For Reality protocol
  /// REALITY `spiderX` (VLESS `spx=`).
  final String? realitySpiderX;
  final VlessTransport transport;
  final String? path;
  final String? hostHeader;
  /// XHTTP mode: `stream-up`, `packet-up`, `stream-one`, `auto`, … (from URI `mode=`).
  final String? xhttpMode;
  /// Merged into Xray `xhttpSettings.extra` (from URI `extra=` or storage).
  final Map<String, dynamic>? xhttpExtra;
  final String? remark;

  const VlessProfile({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.uuid,
    this.encryption = 'none',
    this.security = 'none',
    this.sni,
    this.alpn = const [],
    this.fingerprint,
    this.flow,
    this.realityPublicKey,
    this.realityShortId,
    this.realitySpiderX,
    this.transport = VlessTransport.tcp,
    this.path,
    this.hostHeader,
    this.xhttpMode,
    this.xhttpExtra,
    this.remark,
  });

  VlessProfile copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? uuid,
    String? encryption,
    String? security,
    String? sni,
    List<String>? alpn,
    String? fingerprint,
    String? flow,
    String? realityPublicKey,
    String? realityShortId,
    String? realitySpiderX,
    VlessTransport? transport,
    String? path,
    String? hostHeader,
    String? xhttpMode,
    Map<String, dynamic>? xhttpExtra,
    String? remark,
  }) {
    return VlessProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      uuid: uuid ?? this.uuid,
      encryption: encryption ?? this.encryption,
      security: security ?? this.security,
      sni: sni ?? this.sni,
      alpn: alpn ?? this.alpn,
      fingerprint: fingerprint ?? this.fingerprint,
      flow: flow ?? this.flow,
      realityPublicKey: realityPublicKey ?? this.realityPublicKey,
      realityShortId: realityShortId ?? this.realityShortId,
      realitySpiderX: realitySpiderX ?? this.realitySpiderX,
      transport: transport ?? this.transport,
      path: path ?? this.path,
      hostHeader: hostHeader ?? this.hostHeader,
      xhttpMode: xhttpMode ?? this.xhttpMode,
      xhttpExtra: xhttpExtra ?? this.xhttpExtra,
      remark: remark ?? this.remark,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'host': host,
      'port': port,
      'uuid': uuid,
      'encryption': encryption,
      'security': security,
      'sni': sni,
      'alpn': alpn,
      'fingerprint': fingerprint,
      'flow': flow,
      'realityPublicKey': realityPublicKey,
      'realityShortId': realityShortId,
      if (realitySpiderX != null && realitySpiderX!.trim().isNotEmpty)
        'realitySpiderX': realitySpiderX!.trim(),
      'transport': transportToString(transport),
      'path': path,
      'hostHeader': hostHeader,
      if (xhttpMode != null) 'xhttpMode': xhttpMode,
      if (xhttpExtra != null && xhttpExtra!.isNotEmpty) 'xhttpExtra': xhttpExtra,
      'remark': remark,
    };
  }

  factory VlessProfile.fromMap(Map<String, dynamic> map) {
    return VlessProfile(
      id: map['id'] as String,
      name: map['name'] as String,
      host: map['host'] as String,
      port: (map['port'] as num).toInt(),
      uuid: map['uuid'] as String,
      encryption: (map['encryption'] as String?) ?? 'none',
      security: _normSecurity(map['security']),
      sni: map['sni'] as String?,
      alpn: (map['alpn'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      fingerprint: map['fingerprint'] as String?,
      flow: map['flow'] as String?,
      realityPublicKey: _str(map['realityPublicKey'])?.trim(),
      realityShortId: _str(map['realityShortId'])?.trim(),
      realitySpiderX: _str(map['realitySpiderX'])?.trim(),
      transport: transportFromString(map['transport'] as String?),
      path: map['path'] as String?,
      hostHeader: map['hostHeader'] as String?,
      xhttpMode: map['xhttpMode'] as String?,
      xhttpExtra: _xhttpExtraFromMap(map['xhttpExtra']),
      remark: map['remark'] as String?,
    );
  }

  static Map<String, dynamic>? _xhttpExtraFromMap(dynamic v) {
    if (v == null) return null;
    if (v is Map) return Map<String, dynamic>.from(v);
    if (v is String && v.trim().isNotEmpty) {
      return parseXhttpExtraParam(v);
    }
    return null;
  }

  static String? _str(dynamic v) {
    if (v == null) return null;
    if (v is String) return v;
    return v.toString();
  }

  static String? _trimOrNull(String? s) {
    final t = s?.trim();
    if (t == null || t.isEmpty) return null;
    return t;
  }

  static String _normSecurity(dynamic v) {
    final s = _str(v)?.trim();
    if (s == null || s.isEmpty) return 'none';
    return s.toLowerCase();
  }

  String toJson() => jsonEncode(toMap());

  factory VlessProfile.fromJson(String source) =>
      VlessProfile.fromMap(jsonDecode(source) as Map<String, dynamic>);

  factory VlessProfile.fromUri(String uri, {String? fallbackName}) {
    final parsed = parseVlessUri(uri);
    final xm = parsed.xhttpMode?.trim();
    return VlessProfile(
      id: parsed.id,
      name: parsed.name ?? fallbackName ?? parsed.host,
      host: parsed.host,
      port: parsed.port,
      uuid: parsed.uuid,
      encryption: parsed.encryption ?? 'none',
      security: _normSecurity(parsed.security),
      sni: parsed.sni,
      alpn: parsed.alpn ?? const [],
      fingerprint: parsed.fingerprint,
      flow: parsed.flow,
      realityPublicKey: parsed.realityPublicKey,
      realityShortId: parsed.realityShortId,
      realitySpiderX: _trimOrNull(parsed.realitySpiderX),
      transport: parsed.transport ?? VlessTransport.tcp,
      path: parsed.path,
      hostHeader: parsed.hostHeader,
      xhttpMode: (xm == null || xm.isEmpty) ? null : xm,
      xhttpExtra: parsed.xhttpExtra,
      remark: parsed.remark,
    );
  }

  String toUri() {
    final query = <String, String>{};
    query['encryption'] = encryption;
    if (security.isNotEmpty && security != 'none') {
      query['security'] = security;
    }
    if (sni?.isNotEmpty ?? false) query['sni'] = sni!;
    if (alpn.isNotEmpty) query['alpn'] = alpn.join(',');
    if (fingerprint?.isNotEmpty ?? false) query['fp'] = fingerprint!;
    if (flow?.isNotEmpty ?? false) query['flow'] = flow!;
    if (transport != VlessTransport.tcp) {
      query['type'] = transportToString(transport);
    }
    if (path?.isNotEmpty ?? false) query['path'] = path!;
    if (hostHeader?.isNotEmpty ?? false) query['host'] = hostHeader!;
    if (realityPublicKey?.isNotEmpty ?? false) query['pbk'] = realityPublicKey!;
    if (realityShortId?.isNotEmpty ?? false) query['sid'] = realityShortId!;
    if (realitySpiderX != null && realitySpiderX!.trim().isNotEmpty) {
      query['spx'] = realitySpiderX!.trim();
    }
    if (transport == VlessTransport.xhttp) {
      if (xhttpMode != null && xhttpMode!.trim().isNotEmpty) {
        query['mode'] = xhttpMode!.trim();
      }
      if (xhttpExtra != null && xhttpExtra!.isNotEmpty) {
        query['extra'] = Uri.encodeQueryComponent(jsonEncode(xhttpExtra));
      }
    }

    final uri = Uri(
      scheme: 'vless',
      userInfo: uuid,
      host: host,
      port: port,
      queryParameters: query.isEmpty ? null : query,
      fragment: name,
    );
    return uri.toString();
  }
}

