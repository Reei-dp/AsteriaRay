import 'dart:async';
import 'package:flutter/services.dart';

class VpnPlatform {
  static const _channel = MethodChannel('lumaray/vpn');
  static const _eventChannel = EventChannel('lumaray/vpn/events');
  
  /// Native teardown: `vpnStopped`, `vpnStopped:libcore`, `vpnStopped:awg`.
  void Function(String event)? onVpnStopped;
  StreamSubscription<dynamic>? _eventSubscription;

  VpnPlatform() {
    // Listen for events from native side
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is String &&
            (event == 'vpnStopped' ||
                event.startsWith('vpnStopped:'))) {
          onVpnStopped?.call(event);
        }
      },
      onError: (error) {
        // Ignore errors
      },
    );
  }

  void dispose() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
  }

  Future<bool> prepareVpn() async {
    final result = await _channel.invokeMethod<bool>('prepareVpn');
    return result ?? false;
  }

  /// Sing-box / libcore (VLESS) tunnel.
  Future<void> startVpn({
    required String configPath,
    required String workDir,
    required String logPath,
    String? profileName,
    String? transport,
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

  /// AmneziaWG userspace tunnel (Android [GoBackend]).
  Future<void> startAwgVpn({
    required String conf,
    required String profileName,
  }) async {
    await _channel.invokeMethod('startVpn', {
      'mode': 'awg',
      'conf': conf,
      'profileName': profileName,
    });
  }

  Future<void> stopVpn() async {
    await _channel.invokeMethod('stopVpn');
  }

  Future<Map<String, int>> getStats() async {
    final result = await _channel.invokeMethod<Map<Object?, Object?>>('getStats');
    if (result == null) {
      return {'upload': 0, 'download': 0};
    }
    return {
      'upload': (result['upload'] as num?)?.toInt() ?? 0,
      'download': (result['download'] as num?)?.toInt() ?? 0,
    };
  }
}

