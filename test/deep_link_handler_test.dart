import 'package:asteriaray/services/deep_link_handler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('subscriptionUrlFromDeepLink', () {
    test('parses asteriaray://add/ prefix', () {
      const feed = 'https://sub.asteriamirror.cloud/api/sub/abc-123';
      expect(
        DeepLinkHandler.subscriptionUrlFromDeepLink(
          'asteriaray://add/$feed',
        ),
        feed,
      );
    });

    test('parses uri path form', () {
      const feed = 'https://sub.example.com/api/sub/uuid';
      expect(
        DeepLinkHandler.subscriptionUrlFromDeepLink(
          'asteriaray://add/$feed',
        ),
        feed,
      );
    });

    test('returns null for unrelated schemes', () {
      expect(
        DeepLinkHandler.subscriptionUrlFromDeepLink('https://example.com'),
        isNull,
      );
    });
  });
}
