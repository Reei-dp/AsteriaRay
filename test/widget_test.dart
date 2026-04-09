// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:asteriaray/notifiers/app_settings_notifier.dart';
import 'package:asteriaray/notifiers/profile_notifier.dart';
import 'package:asteriaray/notifiers/vpn_notifier.dart';
import 'package:asteriaray/screens/home_screen.dart';
import 'package:asteriaray/models/vless_profile.dart';
import 'package:asteriaray/services/profile_store.dart';
import 'package:asteriaray/services/xray_runner.dart';
import 'package:asteriaray/services/vpn_platform.dart';

class _FakeRunner extends XrayRunnerBase {
  @override
  Future<void> prepare() async {}

  @override
  Future<XrayConfigContext> prepareConfig(
    VlessProfile profile, {
    bool useDoh = false,
  }) async {
    return XrayConfigContext(
      configPath: '/tmp/config.json',
      workDir: '/tmp',
      logPath: '/tmp/log.txt',
    );
  }

  @override
  Map<String, dynamic> buildConfig(VlessProfile profile, bool useDoh) => {};
}

class _FakePlatform extends VpnPlatform {
  @override
  void dispose() {}

  @override
  Future<bool> prepareVpn() async => true;

  @override
  Future<void> startVpn({
    required String configPath,
    required String workDir,
    required String logPath,
    String? profileName,
    String? transport,
    String? vlessServerHost,
  }) async {}

  @override
  Future<void> startAwgVpn({
    required String conf,
    required String profileName,
    String? profileId,
  }) async {}

  @override
  Future<void> stopVpn() async {}

  @override
  Future<bool> isTunnelProcessRunning() async => true;

  @override
  Future<bool> isVpnTunnelEstablished() async => true;

  @override
  Future<String?> getLastVlessStartError() async => null;

  @override
  Future<Map<String, int>> getStats() async =>
      {'upload': 0, 'download': 0};
}

void main() {
  testWidgets('Home screen renders', (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final store = await ProfileStore.create();
    final profileNotifier = ProfileNotifier(store);
    await profileNotifier.init();
    final appSettings = await AppSettingsNotifier.create();
    final runner = _FakeRunner();
    final platform = _FakePlatform();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: profileNotifier),
          ChangeNotifierProvider.value(value: appSettings),
          ChangeNotifierProvider(
            create: (_) => VpnNotifier(
              runner,
              platform: platform,
              appSettings: appSettings,
            ),
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    expect(find.text('Asteria 🚀'), findsOneWidget);
  });
}
