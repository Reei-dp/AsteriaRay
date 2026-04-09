import 'package:flutter/foundation.dart';

import 'vpn_platform_android.dart';
import 'vpn_platform_base.dart';
import 'vpn_platform_linux.dart'
    if (dart.library.html) 'vpn_platform_linux_stub.dart';
import 'vpn_platform_windows.dart'
    if (dart.library.html) 'vpn_platform_windows_stub.dart';

export 'vpn_platform_base.dart';

/// Android: MethodChannel + Xray / AmneziaWG. Linux: Xray (VLESS) + `awg-quick` (AmneziaWG).
/// Windows: Xray (VLESS) + Wintun + routes; AmneziaWG: `amneziawg-go` + `awg.exe` + routes.
VpnPlatform createVpnPlatform() {
  if (kIsWeb) {
    throw UnsupportedError('VPN is not supported on web');
  }
  if (defaultTargetPlatform == TargetPlatform.linux) {
    return VpnPlatformLinux();
  }
  if (defaultTargetPlatform == TargetPlatform.windows) {
    return VpnPlatformWindows();
  }
  if (defaultTargetPlatform == TargetPlatform.android) {
    return VpnPlatformAndroid();
  }
  throw UnsupportedError('VPN is only supported on Android, Linux, and Windows');
}
