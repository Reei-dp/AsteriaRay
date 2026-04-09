import 'dart:convert';
import 'package:uuid/uuid.dart';

import '../models/vless_types.dart';

const _uuid = Uuid();

class ParsedVlessUri {
  final String id;
  final String host;
  final int port;
  final String uuid;
  final String? name;
  final String? encryption;
  final String? security;
  final String? sni;
  final List<String>? alpn;
  final String? fingerprint;
  final String? flow;
  final String? realityPublicKey;
  final String? realityShortId;
  /// REALITY `spiderX` (share links use query key `spx`).
  final String? realitySpiderX;
  final VlessTransport? transport;
  final String? path;
  final String? hostHeader;
  /// XHTTP / splithttp: `stream-up`, `packet-up`, `stream-one`, `auto`, …
  final String? xhttpMode;
  /// XHTTP nested options (merged into [xhttpSettings.extra] in Xray JSON).
  final Map<String, dynamic>? xhttpExtra;
  final String? remark;

  ParsedVlessUri({
    required this.id,
    required this.host,
    required this.port,
    required this.uuid,
    this.name,
    this.encryption,
    this.security,
    this.sni,
    this.alpn,
    this.fingerprint,
    this.flow,
    this.realityPublicKey,
    this.realityShortId,
    this.realitySpiderX,
    this.transport,
    this.path,
    this.hostHeader,
    this.xhttpMode,
    this.xhttpExtra,
    this.remark,
  });
}

ParsedVlessUri parseVlessUri(String raw) {
  final trimmed = raw.trim();
  
  // Extract fragment from raw string before parsing, as Uri.parse may not decode it correctly
  String? decodedFragment;
  final hashIndex = trimmed.indexOf('#');
  if (hashIndex != -1 && hashIndex < trimmed.length - 1) {
    final fragmentPart = trimmed.substring(hashIndex + 1);
    // Decode the fragment - it's URL-encoded in the URI
    // Manually decode percent-encoded UTF-8 bytes
    final bytes = <int>[];
    bool allEncoded = true;
    for (int i = 0; i < fragmentPart.length; i++) {
      if (fragmentPart[i] == '%' && i + 2 < fragmentPart.length) {
        final hex = fragmentPart.substring(i + 1, i + 3);
        final byte = int.tryParse(hex, radix: 16);
        if (byte != null) {
          bytes.add(byte);
          i += 2; // Skip the %XX
        } else {
          allEncoded = false;
          break;
        }
      } else {
        allEncoded = false;
        break;
      }
    }
    
    if (allEncoded && bytes.isNotEmpty) {
      // All percent-encoded, decode as UTF-8
      try {
        decodedFragment = utf8.decode(bytes);
      } catch (e) {
        // If UTF-8 decode fails, try Uri.decodeQueryComponent
        decodedFragment = Uri.decodeQueryComponent(fragmentPart);
      }
    } else {
      // Mixed or already decoded, use Uri.decodeQueryComponent
      try {
        decodedFragment = Uri.decodeQueryComponent(fragmentPart);
      } catch (e) {
        decodedFragment = fragmentPart;
      }
    }
  }
  
  final uri = Uri.parse(trimmed);
  if (uri.scheme != 'vless') {
    throw FormatException('URI scheme must be vless://');
  }

  final uuid = uri.userInfo.isNotEmpty ? uri.userInfo.split(':').first : '';
  if (uuid.isEmpty) {
    throw FormatException('Missing UUID in VLESS URI');
  }

  final host = uri.host;
  final port = uri.port == 0 ? 443 : uri.port;

  final params = uri.queryParameters;
  final alpnRaw = params['alpn'];
  final alpn =
      alpnRaw != null && alpnRaw.isNotEmpty ? alpnRaw.split(',') : <String>[];
  final transport = transportFromString(params['type']);

  return ParsedVlessUri(
    id: _uuid.v4(),
    host: host,
    port: port,
    uuid: uuid,
    name: decodedFragment,
    encryption: params['encryption'],
    security: params['security'],
    sni: params['sni'],
    alpn: alpn,
    fingerprint: params['fp'],
    flow: params['flow'],
    realityPublicKey: params['pbk'] ?? params['publicKey'],
    realityShortId: params['sid'] ?? params['shortId'],
    realitySpiderX: params['spx'],
    transport: transport,
    path: params['path'] ?? params['serviceName'],
    hostHeader: params['host'],
    xhttpMode: params['mode'],
    xhttpExtra: parseXhttpExtraParam(params['extra']),
    remark: decodedFragment,
  );
}

/// Decodes Xray [xhttpSettings.extra] from share links: URL-encoded JSON, raw JSON, or base64(JSON).
Map<String, dynamic>? parseXhttpExtraParam(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final t = raw.trim();

  Map<String, dynamic>? tryJson(String s) {
    try {
      final j = jsonDecode(s);
      if (j is Map) return Map<String, dynamic>.from(j);
    } catch (_) {}
    return null;
  }

  for (final s in [t, Uri.decodeQueryComponent(t)]) {
    final m = tryJson(s);
    if (m != null) return m;
  }

  List<int>? decodeB64(String s) {
    try {
      final pad = (4 - s.length % 4) % 4;
      final padded = pad == 0 ? s : s + ('=' * pad);
      return base64Decode(padded);
    } catch (_) {
      return null;
    }
  }

  for (final variant in [t, t.replaceAll('-', '+').replaceAll('_', '/')]) {
    final bytes = decodeB64(variant);
    if (bytes == null) continue;
    try {
      final j = jsonDecode(utf8.decode(bytes));
      if (j is Map) return Map<String, dynamic>.from(j);
    } catch (_) {}
  }

  return null;
}

