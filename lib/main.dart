import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'l10n/app_localizations.dart';
import 'theme/asteria_themes.dart';

import 'notifiers/app_settings_notifier.dart';
import 'notifiers/profile_notifier.dart';
import 'notifiers/routing_notifier.dart';
import 'notifiers/subscription_notifier.dart';
import 'notifiers/vpn_notifier.dart';
import 'screens/home_screen.dart';
import 'services/deep_link_handler.dart';
import 'services/linux_sudoers_bootstrap.dart';
import 'services/profile_store.dart';
import 'services/routing_profile_store.dart';
import 'services/subscription_store.dart';
import 'services/vpn_platform.dart';
import 'services/xray_runner.dart';
import 'widgets/desktop_tray_holder.dart';

/// Same as [linux/runner/my_application.cc] (`kWindowWidth`, default height, geometry hints).
const double kDesktopNarrowWidth = 550;
const double kDesktopDefaultHeight = 800;
const double kDesktopMinHeight = 480;
const double kDesktopMaxHeight = 10000;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await linuxBootstrapSudoersIfNeeded();
  if (desktopTraySupported) {
    await windowManager.ensureInitialized();
    // Must run before runApp so the close button cannot destroy the window while
    // DesktopTrayHolder is still initializing tray / setPreventClose.
    await windowManager.setPreventClose(true);
    // Windows: match Linux GTK geometry — fixed width, vertical resize only.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      await windowManager.setMinimumSize(
        const Size(kDesktopNarrowWidth, kDesktopMinHeight),
      );
      await windowManager.setMaximumSize(
        const Size(kDesktopNarrowWidth, kDesktopMaxHeight),
      );
      await windowManager.setSize(
        const Size(kDesktopNarrowWidth, kDesktopDefaultHeight),
      );
      await windowManager.center();
    }
  }
  final store = await ProfileStore.create();
  final profileNotifier = ProfileNotifier(store);
  await profileNotifier.init();
  final appSettings = await AppSettingsNotifier.create();
  final xrayRunner = createXrayRunner();
  await xrayRunner.prepare();
  final subscriptionStore = await SubscriptionStore.create();
  final routingStore = await RoutingProfileStore.create();
  final routingNotifier = RoutingNotifier(routingStore);
  await routingNotifier.init();
  final subscriptionNotifier = SubscriptionNotifier(
    subscriptionStore,
    profileNotifier,
    runner: xrayRunner,
    platform: createVpnPlatform(),
    appSettings: appSettings,
    routing: routingNotifier,
  );
  await subscriptionNotifier.init();

  if (!kIsWeb) {
    await DeepLinkHandler(subscriptionNotifier).init();
  }

  runApp(MyApp(
    profileNotifier: profileNotifier,
    subscriptionNotifier: subscriptionNotifier,
    routingNotifier: routingNotifier,
    appSettings: appSettings,
    xrayRunner: xrayRunner,
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.profileNotifier,
    required this.subscriptionNotifier,
    required this.routingNotifier,
    required this.appSettings,
    required this.xrayRunner,
  });

  final ProfileNotifier profileNotifier;
  final SubscriptionNotifier subscriptionNotifier;
  final RoutingNotifier routingNotifier;
  final AppSettingsNotifier appSettings;
  final XrayRunnerBase xrayRunner;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: profileNotifier),
        ChangeNotifierProvider.value(value: subscriptionNotifier),
        ChangeNotifierProvider.value(value: routingNotifier),
        ChangeNotifierProvider.value(value: appSettings),
        ChangeNotifierProvider(
          create: (_) => VpnNotifier(
            xrayRunner,
            appSettings: appSettings,
            routing: routingNotifier,
          ),
        ),
      ],
      child: Consumer<AppSettingsNotifier>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'AsteriaRay',
            debugShowCheckedModeBanner: false,
            locale: settings.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: AsteriaThemes.light,
            darkTheme: AsteriaThemes.dark,
            themeMode: settings.themeMode,
            home: desktopTraySupported
                ? const DesktopTrayHolder(child: HomeScreen())
                : const HomeScreen(),
          );
        },
      ),
    );
  }
}
