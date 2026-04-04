import 'package:shared_preferences/shared_preferences.dart';

import '../models/stored_vpn_profile.dart';
import 'stored_profile_codec.dart';

class ProfileStore {
  ProfileStore._(this._prefs);

  final SharedPreferences _prefs;

  /// Legacy list without a `protocol` field (VLESS-only).
  static const _legacyProfilesKey = 'vless_profiles';
  static const _profilesKey = 'vpn_stored_profiles_v2';
  static const _activeKey = 'vless_active_profile';

  static Future<ProfileStore> create() async {
    final prefs = await SharedPreferences.getInstance();
    return ProfileStore._(prefs);
  }

  Future<List<StoredVpnProfile>> loadProfiles() async {
    final v2 = _prefs.getStringList(_profilesKey);
    if (v2 != null && v2.isNotEmpty) {
      return v2
          .map(StoredProfileCodec.decode)
          .whereType<StoredVpnProfile>()
          .toList();
    }

    final legacy = _prefs.getStringList(_legacyProfilesKey);
    if (legacy != null && legacy.isNotEmpty) {
      final migrated = legacy
          .map(StoredProfileCodec.decode)
          .whereType<StoredVpnProfile>()
          .toList();
      await saveProfiles(migrated);
      await _prefs.remove(_legacyProfilesKey);
      return migrated;
    }

    return [];
  }

  Future<void> saveProfiles(List<StoredVpnProfile> profiles) async {
    final encoded = profiles.map(StoredProfileCodec.encode).toList();
    await _prefs.setStringList(_profilesKey, encoded);
  }

  Future<String?> loadActiveId() async {
    return _prefs.getString(_activeKey);
  }

  Future<void> saveActiveId(String? id) async {
    if (id == null) {
      await _prefs.remove(_activeKey);
    } else {
      await _prefs.setString(_activeKey, id);
    }
  }
}
