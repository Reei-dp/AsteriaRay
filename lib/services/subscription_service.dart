import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/routing_profile.dart';
import '../models/vless_profile.dart';
import '../models/vpn_subscription.dart';
import 'routing_profile_parser.dart';
import 'subscription_userinfo_parser.dart';
import 'vless_node_key.dart';

class SubscriptionFetchResult {
  const SubscriptionFetchResult({
    required this.profiles,
    required this.title,
    required this.userInfo,
    this.updateIntervalHours = 3,
    this.supportUrl,
    this.webPageUrl,
    this.announce,
    this.routingImports = const [],
    this.routingEnable,
  });

  final List<VlessProfile> profiles;
  final String title;
  final SubscriptionUserInfo userInfo;
  final int updateIntervalHours;
  final String? supportUrl;
  final String? webPageUrl;
  final String? announce;
  final List<HappRoutingImport> routingImports;
  final bool? routingEnable;
}

abstract final class SubscriptionService {
  SubscriptionService._();

  static bool looksLikeSubscriptionUrl(String text) {
    final uri = Uri.tryParse(text.trim());
    if (uri == null || !uri.hasScheme) return false;
    if (!uri.path.toLowerCase().contains('/sub/')) return false;
    return extractSubscriptionId(text) != null;
  }

  static String? extractSubscriptionId(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;
    final segments = uri.pathSegments;
    final subIdx = segments.indexWhere((s) => s.toLowerCase() == 'sub');
    if (subIdx >= 0 && subIdx + 1 < segments.length) {
      return segments[subIdx + 1];
    }
    if (segments.isNotEmpty) {
      final last = segments.last;
      if (RegExp(r'^[0-9a-f-]{36}$', caseSensitive: false).hasMatch(last)) {
        return last;
      }
    }
    return null;
  }

  static Future<SubscriptionFetchResult> fetch(
    String url, {
    SubscriptionFetchOptions options = const SubscriptionFetchOptions(),
  }) async {
    final normalized = url.trim();
    final uri = Uri.parse(normalized);
    final headers = <String, String>{
      'User-Agent': _userAgentHeader(options.userAgent),
    };
    if (options.sendHwidInCookie && options.hwid != null) {
      headers['Cookie'] = 'HWID=${options.hwid}';
    }
    final response = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SubscriptionFetchException(
        'HTTP ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final bodyText = _decodeBody(response.body, encrypted: options.encryptedSubscription);
    final uris = _extractVlessUris(bodyText);
    if (uris.isEmpty) {
      throw const SubscriptionFetchException('No VLESS nodes in subscription');
    }

    final subscriptionId = extractSubscriptionId(normalized);
    final profiles = <VlessProfile>[];
    for (final line in uris) {
      final nodeKey = vlessNodeKeyFromUri(line);
      final parsed = VlessProfile.fromUri(line);
      profiles.add(
        parsed.copyWith(
          subscriptionId: subscriptionId,
          subscriptionNodeKey: nodeKey,
        ),
      );
    }

    final responseHeaders = response.headers;
    final userInfo = parseSubscriptionUserInfo(
      responseHeaders['subscription-userinfo'] ??
          responseHeaders['Subscription-Userinfo'],
    );
    final title = (responseHeaders['profile-title'] ??
            responseHeaders['Profile-Title'] ??
            'Asteria')
        .trim();
    final intervalRaw = responseHeaders['profile-update-interval'] ??
        responseHeaders['Profile-Update-Interval'];
    final interval = int.tryParse(intervalRaw ?? '') ?? 3;
    final supportUrl =
        responseHeaders['support-url'] ?? responseHeaders['Support-Url'];
    final webPageUrl = responseHeaders['profile-web-page-url'] ??
        responseHeaders['Profile-Web-Page-Url'];
    final announce = decodeAnnounceHeader(
      responseHeaders['announce'] ?? responseHeaders['Announce'],
    );

    final routingHeader = responseHeaders['routing'] ?? responseHeaders['Routing'];
    final routingImports = <HappRoutingImport>[
      if (routingHeader != null)
        ?RoutingProfileParser.parseHeader(routingHeader),
      ...RoutingProfileParser.parseBodyLines(bodyText),
    ].whereType<HappRoutingImport>().toList();

    final routingEnable = RoutingProfileParser.parseRoutingEnable(
      responseHeaders['routing-enable'] ?? responseHeaders['Routing-Enable'],
    );

    return SubscriptionFetchResult(
      profiles: profiles,
      title: title.isEmpty ? 'Asteria' : title,
      userInfo: userInfo,
      updateIntervalHours: interval,
      supportUrl: supportUrl,
      webPageUrl: webPageUrl,
      announce: announce,
      routingImports: routingImports,
      routingEnable: routingEnable,
    );
  }

  static String _userAgentHeader(String? key) {
    return switch (key) {
      'chrome-android' =>
        'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36',
      'chrome-win' =>
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36',
      'safari-ios' =>
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Version/17.0 Mobile/15E148 Safari/604.1',
      'safari-mac' =>
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 Version/17.0 Safari/605.1.15',
      'firefox-win' =>
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0',
      _ => 'AsteriaRay/1.0',
    };
  }

  static String _decodeBody(String body, {bool encrypted = false}) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.contains('vless://')) return trimmed;
    try {
      final decoded = utf8.decode(base64.decode(trimmed));
      if (decoded.contains('vless://')) return decoded;
    } catch (_) {}
    if (encrypted) {
      throw const SubscriptionFetchException(
        'Encrypted subscription: unsupported format',
      );
    }
    return trimmed;
  }

  static List<String> _extractVlessUris(String text) {
    return text
        .split(RegExp(r'\r?\n'))
        .map((e) => e.trim())
        .where((e) => e.toLowerCase().startsWith('vless://'))
        .toList();
  }

  static VpnSubscription mergeIntoSubscription({
    required VpnSubscription existing,
    required SubscriptionFetchResult result,
  }) {
    return existing.copyWith(
      title: existing.title.trim().isNotEmpty ? existing.title : result.title,
      uploadBytes: result.userInfo.upload,
      downloadBytes: result.userInfo.download,
      totalBytes: result.userInfo.total,
      expiresAt: result.userInfo.expiresAt,
      updateIntervalHours: result.updateIntervalHours,
      supportUrl: result.supportUrl,
      webPageUrl: result.webPageUrl,
      announce: result.announce,
      lastUpdatedAt: DateTime.now(),
    );
  }
}

class SubscriptionFetchException implements Exception {
  const SubscriptionFetchException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
