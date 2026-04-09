/// Native VPN bridge: Android uses MethodChannel; Linux runs Xray-core for VLESS.
abstract class VpnPlatform {
  /// Native teardown: `vpnStopped`, `vpnStopped:vless`, `vpnStopped:awg`.
  void Function(String event)? onVpnStopped;

  void dispose();

  Future<bool> prepareVpn();

  /// VLESS tunnel (Android / Linux / Windows: Xray-core).
  Future<void> startVpn({
    required String configPath,
    required String workDir,
    required String logPath,
    String? profileName,
    String? transport,
    /// Linux: VLESS server hostname for `ip route` (full-tunnel through `xray0`). Ignored on Android.
    String? vlessServerHost,
  });

  /// AmneziaWG tunnel: Android [GoBackend]; Linux `awg-quick` (amneziawg-tools).
  Future<void> startAwgVpn({
    required String conf,
    required String profileName,
    String? profileId,
  });

  Future<void> stopVpn();

  /// Native worker alive: Android `:xrayvpn`, Linux Xray [Process].
  Future<bool> isTunnelProcessRunning();

  /// Android: [VpnService.establish] succeeded (system VPN key). Linux: Xray process up.
  Future<bool> isVpnTunnelEstablished();

  /// Android: last native start error (UTF-8 file). Linux: always null.
  Future<String?> getLastVlessStartError();

  Future<Map<String, int>> getStats();
}
