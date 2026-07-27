import 'package:shared_preferences/shared_preferences.dart';

import '../models/routing_profile.dart';

class RoutingProfileStore {
  RoutingProfileStore(this._prefs);

  final SharedPreferences _prefs;
  static const _profilesKey = 'routing_profiles_v1';
  static const _enabledKey = 'routing_enabled_v1';
  static const _activeKey = 'routing_active_v1';
  static const _userAgentKey = 'routing_user_agent_v1';

  static Future<RoutingProfileStore> create() async {
    final prefs = await SharedPreferences.getInstance();
    return RoutingProfileStore(prefs);
  }

  bool get enabled => _prefs.getBool(_enabledKey) ?? true;

  String? get activeProfileName => _prefs.getString(_activeKey);

  String get userAgent => _prefs.getString(_userAgentKey) ?? 'chrome-android';

  Future<void> saveEnabled(bool value) async {
    await _prefs.setBool(_enabledKey, value);
  }

  Future<void> saveActiveProfileName(String? name) async {
    if (name == null) {
      await _prefs.remove(_activeKey);
    } else {
      await _prefs.setString(_activeKey, name);
    }
  }

  Future<void> saveUserAgent(String value) async {
    await _prefs.setString(_userAgentKey, value);
  }

  Future<List<RoutingProfile>> loadProfiles() async {
    final raw = _prefs.getStringList(_profilesKey);
    if (raw == null || raw.isEmpty) return [];
    final out = <RoutingProfile>[];
    for (final line in raw) {
      try {
        out.add(RoutingProfile.fromJson(line));
      } catch (_) {}
    }
    return out;
  }

  Future<void> saveProfiles(List<RoutingProfile> profiles) async {
    await _prefs.setStringList(
      _profilesKey,
      profiles.map((p) => p.toJson()).toList(),
    );
  }
}
