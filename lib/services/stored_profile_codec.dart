import 'dart:convert';

import '../models/amnezia_wg_profile.dart';
import '../models/stored_vpn_profile.dart';
import '../models/vless_profile.dart';

/// JSON string for SharedPreferences: one list entry = one profile.
abstract final class StoredProfileCodec {
  StoredProfileCodec._();

  static String encode(StoredVpnProfile p) {
    final map = switch (p) {
      VlessStoredVpnProfile(:final profile) => {
          'v': 2,
          'protocol': 'vless',
          'data': profile.toMap(),
        },
      AmneziaWgStoredVpnProfile(:final profile) => {
          'v': 2,
          'protocol': 'amnezia_wg',
          'data': profile.toMap(),
        },
    };
    return jsonEncode(map);
  }

  static StoredVpnProfile? decode(String source) {
    try {
      final map = jsonDecode(source) as Map<String, dynamic>;
      final protocol = map['protocol'] as String?;
      final data = map['data'];
      if (protocol == null || data is! Map) return _tryLegacyVless(source);

      switch (protocol) {
        case 'vless':
          return VlessStoredVpnProfile(
            VlessProfile.fromMap(Map<String, dynamic>.from(data)),
          );
        case 'amnezia_wg':
          return AmneziaWgStoredVpnProfile(
            AmneziaWgProfile.fromMap(Map<String, dynamic>.from(data)),
          );
        default:
          return null;
      }
    } catch (_) {
      return _tryLegacyVless(source);
    }
  }

  /// Legacy format: raw `VlessProfile` JSON without a protocol wrapper.
  static StoredVpnProfile? _tryLegacyVless(String source) {
    try {
      final profile = VlessProfile.fromJson(source);
      return VlessStoredVpnProfile(profile);
    } catch (_) {
      return null;
    }
  }
}
