import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/amnezia_wg_profile.dart';
import '../models/stored_vpn_profile.dart';
import '../models/vless_profile.dart';
import '../models/vless_types.dart';
import 'app_settings_notifier.dart';
import '../services/amnezia_wg_runner.dart';
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
        _platform = platform ?? createVpnPlatform() {
    _platform.onVpnStopped = _onNativeVpnStopped;
  }

  /// VLESS vs AmneziaWG teardown is async; a late `vpnStopped:vless` after AWG is up must not clear UI.
  void _onNativeVpnStopped(String event) {
    if (_status == VpnStatus.connecting) {
      return;
    }
    if (_status != VpnStatus.connected) {
      return;
    }
    if (event == 'vpnStopped:vless') {
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

  final XrayRunnerBase _runner;
  final AppSettingsNotifier? _appSettings;
  final VpnPlatform _platform;
  VpnStatus _status = VpnStatus.disconnected;
  _ActiveTunnel _activeTunnel = _ActiveTunnel.none;
  VlessProfile? _current;
  String? _lastError;
  int _uploadBytes = 0;
  int _downloadBytes = 0;
  Timer? _statsTimer;

  /// Prevents overlapping [connect] (double-tap / duplicate startVpn).
  bool _connectInFlight = false;

  VpnStatus get status => _status;
  VlessProfile? get current => _current;
  String? get lastError => _lastError;

  /// Укороченное сообщение для тостов; полный текст остаётся в [lastError].
  String? get lastErrorBrief => _briefVpnError(_lastError);

  String? _briefVpnError(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    var line = raw.split('\n').first.trim();
    line = line.replaceFirst(RegExp(r'^Bad state: '), '');
    line = line.replaceFirst(RegExp(r'^StateError: '), '');
    if (line.length > 160) line = '${line.substring(0, 157)}...';
    return line;
  }
  String? _logPath;
  String? get logPath => _logPath;
  int get uploadBytes => _uploadBytes;
  int get downloadBytes => _downloadBytes;

  /// VLESS via Xray-core, or AmneziaWG (Android [GoBackend], Linux `awg-quick`).
  Future<bool> connect(StoredVpnProfile profile) async {
    if (_connectInFlight) return false;
    _connectInFlight = true;
    try {
      switch (profile) {
        case AmneziaWgStoredVpnProfile(:final profile):
          await _connectAwg(profile);
          return _status == VpnStatus.connected;
        case VlessStoredVpnProfile(:final profile):
          await _connectVless(profile);
          return _status == VpnStatus.connected;
      }
    } finally {
      _connectInFlight = false;
    }
  }

  Future<void> _connectAwg(AmneziaWgProfile profile) async {
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.linux) {
      _status = VpnStatus.error;
      _lastError = 'AmneziaWG is only supported on Android and Linux';
      notifyListeners();
      return;
    }
    _status = VpnStatus.connecting;
    _current = null;
    _lastError = null;
    notifyListeners();

    try {
      await createAmneziaWgRunner().connect(_platform, profile);
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
        vlessServerHost: profile.host,
      );
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _waitAndroidXrayTunnelStable();
      }
      _status = VpnStatus.connected;
      _activeTunnel = _ActiveTunnel.vless;
      _startStatsTimer();
      notifyListeners();
    } catch (e) {
      _activeTunnel = _ActiveTunnel.none;
      _status = VpnStatus.error;
      _lastError = await _formatVlessError(e);
      notifyListeners();
      if (defaultTargetPlatform == TargetPlatform.android) {
        try {
          await _platform.stopVpn();
        } catch (_) {}
      }
    }
  }

  Future<String> _formatVlessError(Object e) async {
    var s = e.toString();
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final native = await _platform.getLastVlessStartError();
        if (native != null && native.isNotEmpty) {
          s = '$s\n\nXray: $native';
        }
      } catch (_) {}
    }
    return s;
  }

  /// [startVpn] returns before TUN exists; [VpnService.establish] runs later in [LibxrayVpnService].
  Future<void> _waitAndroidXrayTunnelStable() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    var consecutive = 0;
    for (var i = 0; i < 70; i++) {
      final tun = await _platform.isVpnTunnelEstablished();
      if (tun) {
        consecutive++;
        if (consecutive >= 3) return;
      } else {
        consecutive = 0;
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    final native = await _platform.getLastVlessStartError();
    final buf = StringBuffer(
      'Интерфейс VPN не создан (нет ключа в статус-баре).',
    );
    if (native != null && native.isNotEmpty) {
      buf.write('\n\nXray: ');
      buf.write(native);
    } else {
      buf.write(
        ' В logcat: процесс :xrayvpn, тег LibxrayVpnService — «Failed to establish VPN», '
        '«VPN permission not granted» или ошибка старта Xray.',
      );
    }
    throw StateError(buf.toString());
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
    _status = VpnStatus.disconnected;
    _current = null;
    _logPath = null;
    _uploadBytes = 0;
    _downloadBytes = 0;
    notifyListeners();
    // Native Android stopVpn can block several seconds (waits for :xrayvpn); UI must not lag.
    await _platform.stopVpn();
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
