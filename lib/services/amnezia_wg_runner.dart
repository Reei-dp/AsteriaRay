import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/amnezia_wg_profile.dart';
import 'vpn_platform_base.dart';

/// AmneziaWG connect path: Android needs notification permission; Linux/Windows use [VpnPlatform.startAwgVpn].
sealed class AmneziaWgRunner {
  Future<void> connect(VpnPlatform platform, AmneziaWgProfile profile);
}

final class AmneziaWgRunnerAndroid implements AmneziaWgRunner {
  @override
  Future<void> connect(VpnPlatform platform, AmneziaWgProfile profile) async {
    final status = await Permission.notification.status;
    if (!status.isGranted) {
      await Permission.notification.request();
    }
    await platform.prepareVpn();
    await platform.startAwgVpn(
      conf: profile.conf,
      profileName: profile.name,
      profileId: profile.id,
    );
  }
}

final class AmneziaWgRunnerLinux implements AmneziaWgRunner {
  @override
  Future<void> connect(VpnPlatform platform, AmneziaWgProfile profile) async {
    await platform.prepareVpn();
    await platform.startAwgVpn(
      conf: profile.conf,
      profileName: profile.name,
      profileId: profile.id,
    );
  }
}

final class AmneziaWgRunnerWindows implements AmneziaWgRunner {
  @override
  Future<void> connect(VpnPlatform platform, AmneziaWgProfile profile) async {
    await platform.prepareVpn();
    await platform.startAwgVpn(
      conf: profile.conf,
      profileName: profile.name,
      profileId: profile.id,
    );
  }
}

AmneziaWgRunner createAmneziaWgRunner() {
  if (kIsWeb) {
    throw UnsupportedError('AmneziaWG is not used on web');
  }
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => AmneziaWgRunnerAndroid(),
    TargetPlatform.linux => AmneziaWgRunnerLinux(),
    TargetPlatform.windows => AmneziaWgRunnerWindows(),
    _ => throw UnsupportedError(
          'AmneziaWG runner is only for Android, Linux, and Windows',
        ),
  };
}
