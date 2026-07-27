import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/vless_profile.dart';
import 'vpn_platform.dart';
import 'xray_latency_probe_config.dart';
import 'xray_runner.dart';

/// Measures VLESS latency via Xray (libv2ray [MeasureOutboundDelay] on Android).
abstract final class VlessLatencyService {
  VlessLatencyService._();

  static int recommendedConcurrency() {
    if (kIsWeb) return 1;
    return kXrayLatencyProbeConcurrency;
  }

  static Future<int?> measureProfile(
    VlessProfile profile, {
    required XrayRunnerBase runner,
    required VpnPlatform platform,
    bool useDoh = true,
    String testUrl = kXrayLatencyTestUrl,
    Duration timeout = kXrayLatencyProbeTimeout,
    int socksPort = kXrayProbeSocksPort,
  }) async {
    if (kIsWeb) return null;
    try {
      final probeConfig =
          buildXrayLatencyProbeConfig(profile, useDoh, socksPort: socksPort);
      final prepared = await runner.prepareConfig(profile, useDoh: useDoh);
      final probePath = '${prepared.workDir}/probe_${profile.id}.json';
      await File(probePath).writeAsString(jsonEncode(probeConfig));

      final configJson = jsonEncode(probeConfig);
      final ms = await platform
          .measureVlessDelay(
            configJson: configJson,
            configPath: probePath,
            workDir: prepared.workDir,
            testUrl: testUrl,
          )
          .timeout(timeout, onTimeout: () => null);
      if (ms == null || ms < 0) return null;
      return ms;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, int?>> measureProfiles(
    Iterable<({String id, VlessProfile profile})> nodes, {
    required XrayRunnerBase runner,
    required VpnPlatform platform,
    bool useDoh = true,
    int? concurrency,
    Duration timeout = kXrayLatencyProbeTimeout,
    void Function(String profileId, int? latencyMs)? onResult,
  }) async {
    final results = <String, int?>{};
    final list = nodes.toList();
    if (list.isEmpty) return results;

    final workers = (concurrency ?? recommendedConcurrency()).clamp(1, list.length);
    var index = 0;

    Future<void> worker(int workerId) async {
      final socksPort = kXrayProbeSocksPort + workerId;
      while (index < list.length) {
        final i = index++;
        final node = list[i];
        final ms = await measureProfile(
          node.profile,
          runner: runner,
          platform: platform,
          useDoh: useDoh,
          timeout: timeout,
          socksPort: socksPort,
        );
        results[node.id] = ms;
        onResult?.call(node.id, ms);
      }
    }

    await Future.wait(
      List.generate(workers, worker),
    );
    return results;
  }
}
