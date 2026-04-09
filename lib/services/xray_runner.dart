import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'xray_runner_android.dart';
import 'xray_runner_base.dart';
import 'xray_runner_linux.dart';

export 'xray_config_context.dart';
export 'xray_runner_android.dart';
export 'xray_runner_base.dart';
export 'xray_runner_linux.dart';

/// Android: [XrayRunnerAndroid] (Xray-core JSON + libv2ray). Linux: [XrayRunnerLinux] (Xray-core).
typedef XrayRunner = XrayRunnerBase;

/// VLESS: **Android** and **Linux** — Xray-core JSON.
XrayRunnerBase createXrayRunner() {
  if (kIsWeb) {
    throw UnsupportedError('VLESS config is not used on web');
  }
  if (Platform.isLinux) {
    return XrayRunnerLinux();
  }
  return XrayRunnerAndroid();
}
