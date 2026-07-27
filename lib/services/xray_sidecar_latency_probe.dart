import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'xray_latency_probe_config.dart';

/// Desktop sidecar: `xray run` + curl via local SOCKS (probe config).
abstract final class XraySidecarLatencyProbe {
  XraySidecarLatencyProbe._();

  static Future<int?> measure({
    required String xrayBinary,
    required String configPath,
    required Map<String, String> environment,
    String testUrl = kXrayLatencyTestUrl,
  }) async {
    if (kIsWeb) return null;
    Process? probe;
    try {
      final socksPort = await _socksPortFromConfig(configPath);
      probe = await Process.start(
        xrayBinary,
        ['run', '-config', configPath],
        environment: environment,
        mode: ProcessStartMode.normal,
      );
      await Future<void>.delayed(const Duration(milliseconds: 400));

      final nullDevice = Platform.isWindows ? 'NUL' : '/dev/null';
      final sw = Stopwatch()..start();
      final curl = await Process.run(
        'curl',
        [
          '-x',
          'socks5h://127.0.0.1:$socksPort',
          '-o',
          nullDevice,
          '-s',
          '-w',
          '%{time_total}',
          '--connect-timeout',
          '4',
          '--max-time',
          '4',
          testUrl,
        ],
      );
      sw.stop();
      if (curl.exitCode != 0) return null;
      final sec = double.tryParse('${curl.stdout}'.trim());
      if (sec == null) return null;
      return (sec * 1000).round();
    } catch (_) {
      return null;
    } finally {
      probe?.kill();
      try {
        await probe?.exitCode.timeout(const Duration(seconds: 3));
      } catch (_) {
        probe?.kill(ProcessSignal.sigkill);
      }
    }
  }

  static Future<int> _socksPortFromConfig(String configPath) async {
    try {
      final raw = await File(configPath).readAsString();
      final config = jsonDecode(raw);
      if (config is Map) {
        final inbounds = config['inbounds'];
        if (inbounds is List && inbounds.isNotEmpty) {
          final first = inbounds.first;
          if (first is Map) {
            final port = first['port'];
            if (port is int) return port;
            if (port is num) return port.toInt();
          }
        }
      }
    } catch (_) {}
    return kXrayProbeSocksPort;
  }
}
