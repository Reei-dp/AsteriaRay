import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide settings (SharedPreferences).
class AppSettingsNotifier extends ChangeNotifier {
  AppSettingsNotifier(this._prefs);

  final SharedPreferences _prefs;

  static const _keyViaTunnel = 'settings.dns_via_tunnel';
  static const _keyLegacyDoh = 'settings.dns_doh_enabled';

  static Future<AppSettingsNotifier> create() async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateFromLegacyDoh(prefs);
    return AppSettingsNotifier(prefs);
  }

  /// Legacy: [true] meant public DoH — migrate into [dnsViaTunnel] as the inverse.
  static Future<void> _migrateFromLegacyDoh(SharedPreferences prefs) async {
    if (prefs.containsKey(_keyViaTunnel)) return;
    if (!prefs.containsKey(_keyLegacyDoh)) return;
    final legacyDohOn = prefs.getBool(_keyLegacyDoh) ?? false;
    await prefs.setBool(_keyViaTunnel, !legacyDohOn);
    await prefs.remove(_keyLegacyDoh);
  }

  /// **true** (default): DNS via outbound `proxy` (same path to VPS as other traffic).  
  /// **false**: public DoH to Cloudflare (HTTPS not via VPS tunnel).
  bool get dnsViaTunnel => _prefs.getBool(_keyViaTunnel) ?? true;

  Future<void> setDnsViaTunnel(bool value) async {
    await _prefs.setBool(_keyViaTunnel, value);
    notifyListeners();
  }
}
