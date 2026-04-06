/// Native VPN bridge: Android uses MethodChannel; Linux runs sing-box.
abstract class VpnPlatform {
  /// Native teardown: `vpnStopped`, `vpnStopped:libcore`, `vpnStopped:awg`.
  void Function(String event)? onVpnStopped;

  void dispose();

  Future<bool> prepareVpn();

  /// Sing-box / libcore (VLESS) tunnel.
  Future<void> startVpn({
    required String configPath,
    required String workDir,
    required String logPath,
    String? profileName,
    String? transport,
  });

  /// AmneziaWG tunnel: Android [GoBackend]; Linux `awg-quick` (amneziawg-tools).
  Future<void> startAwgVpn({
    required String conf,
    required String profileName,
    String? profileId,
  });

  Future<void> stopVpn();

  Future<Map<String, int>> getStats();
}
