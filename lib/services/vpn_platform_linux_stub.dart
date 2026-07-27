import 'vpn_platform_base.dart';

/// Placeholder when `dart:io` is unavailable (e.g. web). Not used if [createVpnPlatform] runs on VM.
class VpnPlatformLinux extends VpnPlatform {
  @override
  void dispose() {}

  @override
  Future<bool> prepareVpn() async {
    throw UnsupportedError('Linux VPN requires a native build');
  }

  @override
  Future<void> startVpn({
    required String configPath,
    required String workDir,
    required String logPath,
    String? profileName,
    String? transport,
    String? vlessServerHost,
    String? localeCode,
  }) async {
    throw UnsupportedError('Linux VPN requires a native build');
  }

  @override
  Future<void> startAwgVpn({
    required String conf,
    required String profileName,
    String? profileId,
    String? localeCode,
  }) async {
    throw UnsupportedError('Linux VPN requires a native build');
  }

  @override
  Future<void> stopVpn() async {}

  @override
  Future<bool> isTunnelProcessRunning() async {
    throw UnsupportedError('Linux VPN requires a native build');
  }

  @override
  Future<bool> isVpnTunnelEstablished() async {
    throw UnsupportedError('Linux VPN requires a native build');
  }

  @override
  Future<String?> getLastVlessStartError() async => null;

  @override
  Future<Map<String, int>> getStats() async =>
      {'upload': 0, 'download': 0};

  @override
  Future<int?> measureVlessDelay({
    required String configJson,
    required String configPath,
    required String workDir,
    String testUrl = 'https://www.google.com/generate_204',
  }) async => null;
}
