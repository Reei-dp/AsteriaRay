import 'dart:async';
import 'package:flutter/services.dart';

import 'vpn_platform_base.dart';

/// Android: MethodChannel to Kotlin (Xray VLESS + AmneziaWG).
class VpnPlatformAndroid extends VpnPlatform {
  static const _channel = MethodChannel('asteriaray/vpn');
  static const _eventChannel = EventChannel('asteriaray/vpn/events');

  StreamSubscription<dynamic>? _eventSubscription;

  VpnPlatformAndroid() {
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is String &&
            (event == 'vpnStopped' || event.startsWith('vpnStopped:'))) {
          onVpnStopped?.call(event);
        }
      },
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
  }

  @override
  Future<bool> prepareVpn() async {
    final result = await _channel.invokeMethod<bool>('prepareVpn');
    return result ?? false;
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
    await _channel.invokeMethod('startVpn', {
      'mode': 'singbox',
      'configPath': configPath,
      'workDir': workDir,
      'logPath': logPath,
      'profileName': profileName,
      'transport': transport,
    });
  }

  @override
  Future<void> startAwgVpn({
    required String conf,
    required String profileName,
    String? profileId,
  }) async {
    await _channel.invokeMethod('startVpn', {
      'mode': 'awg',
      'conf': conf,
      'profileName': profileName,
    });
  }

  @override
  Future<void> stopVpn() async {
    await _channel.invokeMethod('stopVpn');
  }

  @override
  Future<bool> isTunnelProcessRunning() async {
    final r = await _channel.invokeMethod<bool>('isTunnelProcessRunning');
    return r ?? false;
  }

  @override
  Future<bool> isVpnTunnelEstablished() async {
    final r = await _channel.invokeMethod<bool>('isVpnTunnelEstablished');
    return r ?? false;
  }

  @override
  Future<String?> getLastVlessStartError() async {
    final r = await _channel.invokeMethod<String>('getLastVlessStartError');
    return r;
  }

  @override
  Future<Map<String, int>> getStats() async {
    final result =
        await _channel.invokeMethod<Map<Object?, Object?>>('getStats');
    if (result == null) {
      return {'upload': 0, 'download': 0};
    }
    return {
      'upload': (result['upload'] as num?)?.toInt() ?? 0,
      'download': (result['download'] as num?)?.toInt() ?? 0,
    };
  }
}
