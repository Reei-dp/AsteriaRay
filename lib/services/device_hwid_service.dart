import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Stable device id for subscription HWID cookie (Happ-style panels).
abstract final class DeviceHwidService {
  DeviceHwidService._();

  static const _key = 'device_hwid_v1';
  static const _uuid = Uuid();

  static Future<String> getOrCreate() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_key);
    if (existing != null && existing.trim().isNotEmpty) {
      return existing.trim();
    }
    final id = _uuid.v4();
    await prefs.setString(_key, id);
    return id;
  }
}
