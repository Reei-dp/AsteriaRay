import 'vless_uri.dart';

/// Stable identity for a subscription node across refreshes.
String vlessNodeKeyFromUri(String uri) {
  final parsed = parseVlessUri(uri.trim());
  return '${parsed.uuid}@${parsed.host}:${parsed.port}';
}
