import 'package:asteriaray/utils/vless_display.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('subscriptionNodeDisplay', () {
    test('cascade: entry flag (RU) like Happ', () {
      const name = '🇷🇺 Russia → 🇩🇪 Germany · Main';
      final d = subscriptionNodeDisplay(name);
      expect(d.flag, '🇷🇺');
      expect(d.title, 'Russia → 🇩🇪 Germany · Main');
    });

    test('cascade netherlands entry flag', () {
      const name = '🇷🇺 Russia → 🇳🇱 Netherlands · Main';
      final d = subscriptionNodeDisplay(name);
      expect(d.flag, '🇷🇺');
      expect(d.title, 'Russia → 🇳🇱 Netherlands · Main');
    });

    test('direct country', () {
      const name = '🇳🇱 Netherlands';
      final d = subscriptionNodeDisplay(name);
      expect(d.flag, '🇳🇱');
      expect(d.title, 'Netherlands');
    });

    test('direct germany and france', () {
      expect(subscriptionNodeDisplay('🇩🇪 Germany').flag, '🇩🇪');
      expect(subscriptionNodeDisplay('🇩🇪 Germany').title, 'Germany');
      expect(subscriptionNodeDisplay('🇫🇷 France').flag, '🇫🇷');
      expect(subscriptionNodeDisplay('🇫🇷 France').title, 'France');
    });
  });
}
