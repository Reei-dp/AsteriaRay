import '../models/vless_profile.dart';
import '../models/vless_types.dart';

/// Xray-core [streamSettings] for VLESS outbound (`network`, `security`, transport blocks).
Map<String, dynamic> xrayVlessStreamSettings(VlessProfile profile) {
  final tlsEnabled = profile.security != 'none';
  final network = _xrayNetwork(profile.transport);

  final stream = <String, dynamic>{
    'network': network,
    if (network == 'tcp') ..._tcpLikeTransport(profile.transport),
    if (network == 'ws') 'wsSettings': _wsSettings(profile),
    if (network == 'grpc') 'grpcSettings': _grpcSettings(profile),
    if (network == 'http') 'httpSettings': _httpSettings(profile),
    if (network == 'xhttp') 'xhttpSettings': _xhttpSettings(profile),
  };

  if (!tlsEnabled) {
    stream['security'] = 'none';
    return stream;
  }

  final sec = profile.security.trim().toLowerCase();
  stream['security'] = sec == 'reality' ? 'reality' : 'tls';

  final hasRealityKeys = profile.realityPublicKey != null &&
      profile.realityPublicKey!.trim().isNotEmpty &&
      profile.realityShortId != null &&
      profile.realityShortId!.toString().trim().isNotEmpty;

  if (sec == 'reality' && hasRealityKeys) {
    final fp = profile.fingerprint?.trim();
    final xhttp = profile.transport == VlessTransport.xhttp;
    final spx = profile.realitySpiderX?.trim();
    stream['realitySettings'] = {
      'show': false,
      'serverName': _vlessTlsServerName(profile),
      'publicKey': profile.realityPublicKey!.trim(),
      'shortId': profile.realityShortId!.toString().trim(),
      if (spx != null && spx.isNotEmpty) 'spiderX': spx,
      if (fp != null && fp.isNotEmpty)
        'fingerprint': fp
      else if (xhttp)
        'fingerprint': 'chrome',
    };
  } else {
    // TLS stream (incl. degraded REALITY→TLS): use xhttp ALPN defaults whenever not REALITY with valid keys.
    final xhttpTls = profile.transport == VlessTransport.xhttp &&
        !(sec == 'reality' && hasRealityKeys);
    stream['tlsSettings'] = {
      'serverName': _vlessTlsServerName(profile),
      'allowInsecure': false,
      if (profile.alpn.isNotEmpty)
        'alpn': profile.alpn
      else if (xhttpTls)
        'alpn': ['h2', 'http/1.1'],
      if (profile.fingerprint != null && profile.fingerprint!.trim().isNotEmpty)
        'fingerprint': profile.fingerprint!.trim(),
    };
    // REALITY without pbk/sid is invalid with security=reality + tlsSettings; load as plain TLS so core starts.
    if (sec == 'reality' && !hasRealityKeys) {
      stream['security'] = 'tls';
    }
  }

  return stream;
}

String _vlessTlsServerName(VlessProfile profile) {
  final s = profile.sni?.trim();
  if (s != null && s.isNotEmpty) return s;
  return profile.host.trim();
}

String _xrayNetwork(VlessTransport t) {
  switch (t) {
    case VlessTransport.tcp:
      return 'tcp';
    case VlessTransport.ws:
      return 'ws';
    case VlessTransport.grpc:
      return 'grpc';
    case VlessTransport.h2:
      return 'http';
    case VlessTransport.xhttp:
      return 'xhttp';
  }
}

Map<String, dynamic> _tcpLikeTransport(VlessTransport t) {
  if (t != VlessTransport.tcp) return {};
  return {};
}

Map<String, dynamic> _wsSettings(VlessProfile profile) {
  return {
    'path': profile.path ?? '/',
    if (profile.hostHeader != null && profile.hostHeader!.isNotEmpty)
      'headers': {'Host': profile.hostHeader},
  };
}

Map<String, dynamic> _grpcSettings(VlessProfile profile) {
  return {
    'serviceName': profile.path ?? '',
    if (profile.hostHeader != null && profile.hostHeader!.isNotEmpty)
      'authority': profile.hostHeader,
  };
}

Map<String, dynamic> _httpSettings(VlessProfile profile) {
  return {
    'path': profile.path ?? '/',
    if (profile.hostHeader != null && profile.hostHeader!.isNotEmpty)
      'host': [profile.hostHeader],
  };
}

Map<String, dynamic> _xhttpSettings(VlessProfile profile) {
  // Xray splithttp: host > serverName > address. Many URIs omit `host` but set `sni` — set HTTP Host from SNI when missing.
  final modeRaw = profile.xhttpMode?.trim();
  final modeLc = modeRaw?.toLowerCase();
  final map = <String, dynamic>{
    'path': profile.path ?? '/',
    if (_xhttpHostHeader(profile) case final String h) 'host': h,
    if (modeRaw != null && modeRaw.isNotEmpty && modeLc != 'auto') 'mode': modeRaw,
  };
  final extra = profile.xhttpExtra;
  if (extra != null && extra.isNotEmpty) {
    map['extra'] = Map<String, dynamic>.from(extra);
  }
  return map;
}

/// Resolves SplitHTTP `host` (TLS SNI / HTTP Host), not the dial address.
String? _xhttpHostHeader(VlessProfile profile) {
  final h = profile.hostHeader?.trim();
  if (h != null && h.isNotEmpty) return h;
  final s = profile.sni?.trim();
  if (s != null && s.isNotEmpty) return s;
  return null;
}
