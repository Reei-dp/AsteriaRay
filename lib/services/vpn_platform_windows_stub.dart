import 'vpn_platform_base.dart';

/// Web / non-Windows VM placeholder (real implementation needs `dart:io`).
class VpnPlatformWindows extends VpnPlatform {
  @override
  void dispose() {}

  @override
  Future<bool> prepareVpn() async {
    throw UnsupportedError('Windows VPN requires a native Windows build');
  }

  @override
  Future<void> startVpn({
    required String configPath,
    required String workDir,
    required String logPath,
    String? profileName,
    String? transport,
    String? vlessServerHost,
  }) async {
    throw UnsupportedError('Windows VPN requires a native Windows build');
  }

  @override
  Future<void> startAwgVpn({
    required String conf,
    required String profileName,
    String? profileId,
  }) async {
    throw UnsupportedError('Windows VPN requires a native Windows build');
  }

  @override
  Future<void> stopVpn() async {}

  @override
  Future<bool> isTunnelProcessRunning() async {
    throw UnsupportedError('Windows VPN requires a native Windows build');
  }

  @override
  Future<bool> isVpnTunnelEstablished() async {
    throw UnsupportedError('Windows VPN requires a native Windows build');
  }

  @override
  Future<String?> getLastVlessStartError() async => null;

  @override
  Future<Map<String, int>> getStats() async =>
      {'upload': 0, 'download': 0};
}
