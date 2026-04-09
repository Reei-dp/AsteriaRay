import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/vless_profile.dart';
import 'xray_config_context.dart';
import 'xray_net_utils.dart';

/// Shared file prep; subclasses only implement [buildConfig].
abstract class XrayRunnerBase {
  static const assetDir = 'assets/xray';

  String? _workDir;
  String? _logPath;

  String? get logPath => _logPath;

  static bool hostNeedsDnsBootstrap(String host) =>
      xrayHostNeedsDnsBootstrap(host);

  Future<void> prepare() async {
    final dir = await getApplicationSupportDirectory();
    final workDir = Directory(p.join(dir.path, 'xray'));
    if (!await workDir.exists()) {
      await workDir.create(recursive: true);
    }
    _workDir = workDir.path;

    final geoipPath = p.join(workDir.path, 'geoip.dat');
    final geositePath = p.join(workDir.path, 'geosite.dat');

    await _copyAsset('$assetDir/geoip.dat', geoipPath);
    await _copyAsset('$assetDir/geosite.dat', geositePath);

    _logPath = p.join(workDir.path, 'log.txt');
  }

  Future<XrayConfigContext> prepareConfig(
    VlessProfile profile, {
    bool useDoh = false,
  }) async {
    final workDir = _workDir ?? (await _ensurePrepared());
    final configPath = p.join(workDir, 'config.json');
    final logPath = _logPath ?? p.join(workDir, 'log.txt');

    try {
      final logFile = File(logPath);
      if (await logFile.exists()) {
        await logFile.writeAsString('');
      }
    } catch (_) {}

    final config = buildConfig(profile, useDoh);
    final configFile = File(configPath);
    await configFile.writeAsString(jsonEncode(config));
    return XrayConfigContext(
      configPath: configPath,
      workDir: workDir,
      logPath: logPath,
    );
  }

  Future<String> _ensurePrepared() async {
    if (_workDir != null) return _workDir!;
    await prepare();
    return _workDir!;
  }

  Future<void> _copyAsset(String assetPath, String destPath) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();
    final file = File(destPath);
    await file.writeAsBytes(bytes, flush: true);
  }

  Map<String, dynamic> buildConfig(VlessProfile profile, bool useDoh);
}
