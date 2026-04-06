import 'package:flutter_test/flutter_test.dart';
import 'package:asteriaray/services/config_import_detector.dart';

void main() {
  group('ConfigImportDetector', () {
    test('vless URI', () {
      expect(
        ConfigImportDetector.detect('vless://uuid@host:443?encryption=none#name'),
        ConfigImportKind.vlessUri,
      );
    });

    test('wireguard conf', () {
      const conf = '''
[Interface]
PrivateKey = abc=
Address = 10.0.0.2/32

[Peer]
PublicKey = def=
Endpoint = 1.2.3.4:51820
''';
      expect(ConfigImportDetector.detect(conf), ConfigImportKind.wireGuardConf);
    });

    test('unknown', () {
      expect(ConfigImportDetector.detect('hello'), ConfigImportKind.unknown);
      expect(ConfigImportDetector.detect('{}'), ConfigImportKind.unknown);
    });
  });
}
