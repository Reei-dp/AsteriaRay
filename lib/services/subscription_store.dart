import 'package:shared_preferences/shared_preferences.dart';

import '../models/vpn_subscription.dart';

class SubscriptionStore {
  SubscriptionStore(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'vpn_subscriptions_v1';

  static Future<SubscriptionStore> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SubscriptionStore(prefs);
  }

  Future<List<VpnSubscription>> load() async {
    final raw = _prefs.getStringList(_key);
    if (raw == null || raw.isEmpty) return [];
    final out = <VpnSubscription>[];
    for (final line in raw) {
      try {
        out.add(VpnSubscription.fromJson(line));
      } catch (_) {}
    }
    return out;
  }

  Future<void> save(List<VpnSubscription> subscriptions) async {
    final encoded = subscriptions.map((s) => s.toJson()).toList();
    await _prefs.setStringList(_key, encoded);
  }
}
