import 'dart:convert';

import '../models/routing_profile.dart';

abstract final class RoutingProfileParser {
  RoutingProfileParser._();

  static HappRoutingImport? parseHeader(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return parseHappLink(raw.trim());
  }

  static List<HappRoutingImport> parseBodyLines(String body) {
    final out = <HappRoutingImport>[];
    for (final line in body.split(RegExp(r'\r?\n'))) {
      final t = line.trim();
      if (!t.toLowerCase().startsWith('happ://routing/')) continue;
      final imp = parseHappLink(t);
      if (imp != null) out.add(imp);
    }
    return out;
  }

  static bool? parseRoutingEnable(String? raw) {
    if (raw == null) return null;
    final s = raw.trim().toLowerCase();
    if (s == '0' || s == 'false' || s == 'off') return false;
    if (s == '1' || s == 'true' || s == 'on') return true;
    return null;
  }

  static HappRoutingImport? parseHappLink(String link) {
    final uri = Uri.tryParse(link.trim());
    if (uri == null || uri.scheme != 'happ') return null;
    if (uri.host != 'routing') return null;

    final action = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    if (action == 'off') {
      return const HappRoutingImport(disableRouting: true);
    }

    if (action != 'onadd' && action != 'add') return null;
    final b64 = uri.pathSegments.length > 1
        ? uri.pathSegments.sublist(1).join('/')
        : (uri.path.length > 1 ? uri.path.substring(1) : '');
    if (b64.isEmpty) return null;

    try {
      final normalized = b64.replaceAll('-', '+').replaceAll('_', '/');
      final pad = normalized.length % 4;
      final padded = pad == 0 ? normalized : normalized.padRight(normalized.length + (4 - pad), '=');
      final jsonText = utf8.decode(base64.decode(padded));
      final map = jsonDecode(jsonText) as Map<String, dynamic>;
      return HappRoutingImport(
        profile: RoutingProfile.fromHappJson(map),
        activate: action == 'onadd',
      );
    } catch (_) {
      return null;
    }
  }
}
