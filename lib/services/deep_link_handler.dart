import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import '../notifiers/subscription_notifier.dart';
import 'subscription_service.dart';

/// Handles `asteriaray://add/{subscription_feed_url}` from the subscription site.
final class DeepLinkHandler {
  DeepLinkHandler(this._subscriptions);

  final SubscriptionNotifier _subscriptions;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;

  Future<void> init() async {
    if (kIsWeb) return;

    final initial = await _appLinks.getInitialLink();
    if (initial != null) {
      await _handleUri(initial);
    }

    _linkSub = _appLinks.uriLinkStream.listen(
      (uri) => unawaited(_handleUri(uri)),
      onError: (_) {},
    );
  }

  void dispose() {
    unawaited(_linkSub?.cancel());
    _linkSub = null;
  }

  Future<void> _handleUri(Uri uri) async {
    final url = subscriptionUrlFromDeepLink(uri.toString());
    if (url == null) return;
    if (!SubscriptionService.looksLikeSubscriptionUrl(url)) return;
    try {
      await _subscriptions.addFromUrl(url);
    } catch (_) {}
  }

  /// Parses magnet-style links: `asteriaray://add/https://…/api/sub/{uuid}`.
  static String? subscriptionUrlFromDeepLink(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    const prefix = 'asteriaray://add/';
    if (trimmed.toLowerCase().startsWith(prefix)) {
      return trimmed.substring(prefix.length);
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;
    if (uri.scheme.toLowerCase() != 'asteriaray') return null;
    if (uri.host.toLowerCase() != 'add') return null;

    final path = uri.path;
    if (path.length > 1) {
      final candidate = path.startsWith('/') ? path.substring(1) : path;
      if (candidate.startsWith('http://') || candidate.startsWith('https://')) {
        return Uri.decodeFull(candidate);
      }
    }

    if (uri.queryParameters.containsKey('url')) {
      return uri.queryParameters['url'];
    }

    return null;
  }
}
