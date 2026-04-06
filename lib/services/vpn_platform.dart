import 'package:flutter/foundation.dart';

import 'vpn_platform_android.dart';
import 'vpn_platform_base.dart';
import 'vpn_platform_linux.dart'
    if (dart.library.html) 'vpn_platform_linux_stub.dart';

export 'vpn_platform_base.dart';

/// Android: MethodChannel + libcore / AmneziaWG. Linux: sing-box (VLESS) + `awg-quick` (AmneziaWG).
VpnPlatform createVpnPlatform() {
  if (kIsWeb) {
    throw UnsupportedError('VPN is not supported on web');
  }
  if (defaultTargetPlatform == TargetPlatform.linux) {
    return VpnPlatformLinux();
  }
  if (defaultTargetPlatform == TargetPlatform.android) {
    return VpnPlatformAndroid();
  }
  throw UnsupportedError('VPN is only supported on Android and Linux');
}
