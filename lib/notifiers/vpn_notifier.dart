import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/amnezia_wg_profile.dart';
import '../models/stored_vpn_profile.dart';
import '../models/vless_profile.dart';
import '../models/vless_types.dart';
import 'app_settings_notifier.dart';
import '../services/vpn_platform.dart';
import '../services/xray_runner.dart';

enum VpnStatus { disconnected, connecting, connected, error }

/// Which native tunnel matches [VpnStatus.connected] (used to ignore stale [vpnStopped] events).
enum _ActiveTunnel { none, vless, awg }

class VpnNotifier extends ChangeNotifier {
  VpnNotifier(
    this._runner, {
    VpnPlatform? platform,
    AppSettingsNotifier? appSettings,
  })  : _appSettings = appSettings,
        _platform = platform ?? VpnPlatform() {
    _platform.onVpnStopped = _onNativeVpnStopped;
  }

  /// Libcore vs AmneziaWG teardown is async; a late `vpnStopped:libcore` after AWG is up must not clear UI.
  void _onNativeVpnStopped(String event) {
    if (_status == VpnStatus.connecting) {
      return;
    }
    if (_status != VpnStatus.connected) {
      return;
    }
    if (event == 'vpnStopped:libcore') {
      if (_activeTunnel != _ActiveTunnel.vless) {
        return;
      }
    } else if (event == 'vpnStopped:awg') {
      if (_activeTunnel != _ActiveTunnel.awg) {
        return;
      }
    }
    _status = VpnStatus.disconnected;
    _activeTunnel = _ActiveTunnel.none;
    _current = null;
    _logPath = null;
    _uploadBytes = 0;
    _downloadBytes = 0;
    _statsTimer?.cancel();
    _statsTimer = null;
    notifyListeners();
  }

  final XrayRunner _runner;
  final AppSettingsNotifier? _appSettings;
  final VpnPlatform _platform;
  VpnStatus _status = VpnStatus.disconnected;
  _ActiveTunnel _activeTunnel = _ActiveTunnel.none;
  VlessProfile? _current;
  String? _lastError;
  int _uploadBytes = 0;
  int _downloadBytes = 0;
  Timer? _statsTimer;

  VpnStatus get status => _status;
  VlessProfile? get current => _current;
  String? get lastError => _lastError;
  String? _logPath;
  String? get logPath => _logPath;
  int get uploadBytes => _uploadBytes;
  int get downloadBytes => _downloadBytes;

  /// VLESS via sing-box, or AmneziaWG via [GoBackend] on Android.
  Future<bool> connect(StoredVpnProfile profile) async {
    switch (profile) {
      case AmneziaWgStoredVpnProfile(:final profile):
        await _connectAwg(profile);
        return _status == VpnStatus.connected;
      case VlessStoredVpnProfile(:final profile):
        await _connectVless(profile);
        return _status == VpnStatus.connected;
    }
  }

  Future<void> _connectAwg(AmneziaWgProfile profile) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      _status = VpnStatus.error;
      _lastError = 'AmneziaWG is only supported on Android';
      notifyListeners();
      return;
    }
    _status = VpnStatus.connecting;
    _current = null;
    _lastError = null;
    notifyListeners();

    try {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }

      await _platform.prepareVpn();
      await _platform.startAwgVpn(
        conf: profile.conf,
        profileName: profile.name,
      );
      _status = VpnStatus.connected;
      _activeTunnel = _ActiveTunnel.awg;
      _startStatsTimer();
      notifyListeners();
    } catch (e) {
      _activeTunnel = _ActiveTunnel.none;
      _status = VpnStatus.error;
      _lastError = e.toString();
      notifyListeners();
    }
  }

  Future<void> _connectVless(VlessProfile profile) async {
    _status = VpnStatus.connecting;
    _current = profile;
    _lastError = null;
    notifyListeners();

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final status = await Permission.notification.status;
        if (!status.isGranted) {
          await Permission.notification.request();
        }
      }

      final prepared = await _runner.prepareConfig(
        profile,
        useDoh: !(_appSettings?.dnsViaTunnel ?? true),
      );
      _logPath = prepared.logPath;
      await _platform.prepareVpn();
      await _platform.startVpn(
        configPath: prepared.configPath,
        workDir: prepared.workDir,
        logPath: prepared.logPath,
        profileName: profile.name,
        transport: transportToString(profile.transport),
      );
      _status = VpnStatus.connected;
      _activeTunnel = _ActiveTunnel.vless;
      _startStatsTimer();
      notifyListeners();
    } catch (e) {
      _activeTunnel = _ActiveTunnel.none;
      _status = VpnStatus.error;
      _lastError = e.toString();
      notifyListeners();
    }
  }

  void _startStatsTimer() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_status == VpnStatus.connected) {
        try {
          final stats = await _platform.getStats();
          updateStats(stats['upload'] ?? 0, stats['download'] ?? 0);
        } catch (e) {
          // Ignore errors
        }
      }
    });
  }

  Future<void> disconnect() async {
    _statsTimer?.cancel();
    _statsTimer = null;
    _activeTunnel = _ActiveTunnel.none;
    await _platform.stopVpn();
    _status = VpnStatus.disconnected;
    _current = null;
    _logPath = null;
    _uploadBytes = 0;
    _downloadBytes = 0;
    notifyListeners();
  }

  void updateStats(int upload, int download) {
    _uploadBytes = upload;
    _downloadBytes = download;
    notifyListeners();
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    _platform.dispose();
    super.dispose();
  }
}
