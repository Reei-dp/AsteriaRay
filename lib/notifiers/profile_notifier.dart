import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/amnezia_wg_profile.dart';
import '../models/stored_vpn_profile.dart';
import '../models/vless_profile.dart';
import '../models/vless_types.dart';
import '../services/config_import_detector.dart';
import '../services/profile_store.dart';

class ProfileNotifier extends ChangeNotifier {
  ProfileNotifier(this._store);

  final ProfileStore _store;
  final _uuid = const Uuid();

  List<StoredVpnProfile> _profiles = [];
  String? _activeId;
  bool _initialized = false;

  List<StoredVpnProfile> get profiles => _profiles;
  String? get activeId => _activeId;

  StoredVpnProfile? get activeProfile {
    if (_profiles.isEmpty) return null;
    final idx = _profiles.indexWhere((p) => p.id == _activeId);
    return idx >= 0 ? _profiles[idx] : _profiles.first;
  }

  bool get initialized => _initialized;

  Future<void> init() async {
    _profiles = await _store.loadProfiles();
    _activeId = await _store.loadActiveId();
    _initialized = true;
    notifyListeners();
  }

  Future<void> addOrUpdate(StoredVpnProfile profile) async {
    final idx = _profiles.indexWhere((p) => p.id == profile.id);
    if (idx >= 0) {
      _profiles[idx] = profile;
    } else {
      _profiles = [..._profiles, profile];
      _activeId ??= profile.id;
    }
    await _persist();
  }

  Future<void> createManual({
    required String name,
    required String host,
    required int port,
    required String uuid,
    String encryption = 'none',
    String security = 'none',
    String? sni,
    List<String> alpn = const [],
    String? fingerprint,
    String? flow,
    String? realityPublicKey,
    String? realityShortId,
    VlessTransport transport = VlessTransport.tcp,
    String? path,
    String? hostHeader,
    String? remark,
  }) async {
    final profile = VlessProfile(
      id: _uuid.v4(),
      name: name,
      host: host,
      port: port,
      uuid: uuid,
      encryption: encryption,
      security: security,
      sni: sni,
      alpn: alpn,
      fingerprint: fingerprint,
      flow: flow,
      realityPublicKey: realityPublicKey,
      realityShortId: realityShortId,
      transport: transport,
      path: path,
      hostHeader: hostHeader,
      remark: remark,
    );
    await addOrUpdate(VlessStoredVpnProfile(profile));
  }

  /// Import a single `vless://…` line (e.g. line-by-line from a file).
  Future<VlessStoredVpnProfile> importUri(String uri, {String? fallbackName}) async {
    final profile = VlessProfile.fromUri(uri, fallbackName: fallbackName);
    final stored = VlessStoredVpnProfile(profile);
    await addOrUpdate(stored);
    return stored;
  }

  /// Clipboard or whole file: auto-detect VLESS URI vs WireGuard/AmneziaWG `.conf`.
  Future<StoredVpnProfile> importFromClipboard(String text) async {
    final t = text.trim();
    final kind = ConfigImportDetector.detect(t);
    switch (kind) {
      case ConfigImportKind.vlessUri:
        return importUri(t);
      case ConfigImportKind.wireGuardConf:
        final wg = AmneziaWgProfile.fromConf(t, id: _uuid.v4());
        final stored = AmneziaWgStoredVpnProfile(wg);
        await addOrUpdate(stored);
        return stored;
      case ConfigImportKind.unknown:
        throw FormatException(
          'Не удалось распознать формат. Ожидается vless:// или WireGuard .conf',
        );
    }
  }

  Future<void> delete(String id) async {
    _profiles = _profiles.where((p) => p.id != id).toList();
    if (_activeId == id) {
      _activeId = _profiles.isNotEmpty ? _profiles.first.id : null;
    }
    await _persist();
  }

  Future<void> setActive(String id) async {
    _activeId = id;
    await _store.saveActiveId(id);
    notifyListeners();
  }

  Future<void> _persist() async {
    await _store.saveProfiles(_profiles);
    if (_activeId != null) {
      await _store.saveActiveId(_activeId);
    }
    notifyListeners();
  }
}
