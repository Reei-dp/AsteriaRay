import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/stored_vpn_profile.dart';
import '../models/vless_profile.dart';
import '../models/vpn_subscription.dart';
import '../services/device_hwid_service.dart';
import '../services/subscription_service.dart';
import '../services/subscription_store.dart';
import '../services/vless_latency_service.dart';
import '../services/vpn_platform.dart';
import '../services/xray_runner.dart';
import 'app_settings_notifier.dart';
import 'profile_notifier.dart';
import 'routing_notifier.dart';

class SubscriptionNotifier extends ChangeNotifier {
  SubscriptionNotifier(
    this._store,
    this._profiles, {
    required XrayRunnerBase runner,
    required VpnPlatform platform,
    AppSettingsNotifier? appSettings,
    RoutingNotifier? routing,
  })  : _runner = runner,
        _platform = platform,
        _appSettings = appSettings,
        _routing = routing;

  final SubscriptionStore _store;
  final ProfileNotifier _profiles;
  final XrayRunnerBase _runner;
  final VpnPlatform _platform;
  final AppSettingsNotifier? _appSettings;
  final RoutingNotifier? _routing;
  final _uuid = const Uuid();

  List<VpnSubscription> _subscriptions = [];
  bool _initialized = false;
  bool _refreshing = false;
  String? _refreshingId;
  final Map<String, int?> _pings = {};
  final Set<String> _pingingProfileIds = {};
  bool _pinging = false;
  Timer? _autoRefreshTimer;

  List<VpnSubscription> get subscriptions => List.unmodifiable(_subscriptions);
  bool get initialized => _initialized;
  bool get isRefreshing => _refreshing;
  String? get refreshingId => _refreshingId;
  bool get isPinging => _pinging;
  Map<String, int?> get pings => Map.unmodifiable(_pings);

  int? pingForProfile(String profileId) => _pings[profileId];

  bool isPingingProfile(String profileId) =>
      _pingingProfileIds.contains(profileId);

  VpnSubscription? subscriptionById(String id) {
    for (final s in _subscriptions) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<void> init() async {
    _subscriptions = await _store.load();
    _sortSubscriptions();
    _initialized = true;
    notifyListeners();
    _scheduleAutoRefresh();
    unawaited(_refreshStaleIfNeeded());
  }

  Future<void> addFromUrl(String url) async {
    final trimmed = url.trim();
    if (!SubscriptionService.looksLikeSubscriptionUrl(trimmed)) {
      throw const SubscriptionFetchException('Invalid subscription URL');
    }
    final fetchOptions = await _defaultFetchOptions(
      const SubscriptionFetchOptions(),
    );
    final result = await SubscriptionService.fetch(trimmed, options: fetchOptions);
    final id =
        SubscriptionService.extractSubscriptionId(trimmed) ?? _uuid.v4();
    final existingIdx = _subscriptions.indexWhere((s) => s.id == id);
    final base = existingIdx >= 0
        ? _subscriptions[existingIdx]
        : VpnSubscription(id: id, url: trimmed, title: result.title);
    final updated = SubscriptionService.mergeIntoSubscription(
      existing: base,
      result: result,
    );
    if (existingIdx >= 0) {
      _subscriptions[existingIdx] = updated;
    } else {
      _subscriptions = [..._subscriptions, updated];
    }
    await _syncProfiles(updated, result.profiles);
    await _applyRouting(result, id);
    _sortSubscriptions();
    await _store.save(_subscriptions);
    _scheduleAutoRefresh();
    notifyListeners();
  }

  Future<void> refresh(String subscriptionId) async {
    final idx = _subscriptions.indexWhere((s) => s.id == subscriptionId);
    if (idx < 0) return;
    final sub = _subscriptions[idx];
    _refreshing = true;
    _refreshingId = subscriptionId;
    notifyListeners();
    try {
      final fetchOptions = await _fetchOptionsFor(sub);
      final result = await SubscriptionService.fetch(sub.url, options: fetchOptions);
      _subscriptions[idx] = SubscriptionService.mergeIntoSubscription(
        existing: sub,
        result: result,
      );
      await _syncProfiles(_subscriptions[idx], result.profiles);
      await _applyRouting(result, subscriptionId);
      await _store.save(_subscriptions);
    } finally {
      _refreshing = false;
      _refreshingId = null;
      notifyListeners();
    }
  }

  Future<void> updateSubscription(
    VpnSubscription updated, {
    bool refreshAfterChange = false,
  }) async {
    final idx = _subscriptions.indexWhere((s) => s.id == updated.id);
    if (idx < 0) return;
    final prev = _subscriptions[idx];
    _subscriptions[idx] = updated;
    await _store.save(_subscriptions);
    notifyListeners();

    final allowInsecureChanged = prev.allowInsecure != updated.allowInsecure;
    if (allowInsecureChanged) {
      await _reapplyAllowInsecure(updated.id, updated.allowInsecure);
    }
    if (refreshAfterChange) {
      await refresh(updated.id);
    }
  }

  Future<void> togglePin(String subscriptionId) async {
    final idx = _subscriptions.indexWhere((s) => s.id == subscriptionId);
    if (idx < 0) return;
    _subscriptions[idx] = _subscriptions[idx].copyWith(
      pinned: !_subscriptions[idx].pinned,
    );
    _sortSubscriptions();
    await _store.save(_subscriptions);
    notifyListeners();
  }

  Future<void> refreshAll() async {
    for (final sub in List.of(_subscriptions)) {
      await refresh(sub.id);
    }
  }

  Future<void> remove(String subscriptionId) async {
    _subscriptions =
        _subscriptions.where((s) => s.id != subscriptionId).toList();
    await _profiles.removeSubscriptionProfiles(subscriptionId);
    await _store.save(_subscriptions);
    notifyListeners();
  }

  Future<void> pingSubscriptionNodes(String subscriptionId) async {
    final nodes = _profiles
        .profilesForSubscription(subscriptionId)
        .whereType<VlessStoredVpnProfile>()
        .map((p) => (id: p.id, profile: p.profile))
        .toList();
    if (nodes.isEmpty) return;
    _pinging = true;
    for (final node in nodes) {
      _pingingProfileIds.add(node.id);
      _pings.remove(node.id);
    }
    notifyListeners();
    try {
      final useDoh = !(_appSettings?.dnsViaTunnel ?? true);
      final routing = _routing?.enabled == true ? _routing!.activeProfile : null;
      await VlessLatencyService.measureProfiles(
        nodes,
        runner: _runner,
        platform: _platform,
        useDoh: routing == null ? useDoh : false,
        onResult: (id, ms) {
          _pings[id] = ms;
          _pingingProfileIds.remove(id);
          notifyListeners();
        },
      );
    } finally {
      _pinging = false;
      _pingingProfileIds.clear();
      notifyListeners();
    }
  }

  Future<void> _refreshStaleIfNeeded() async {
    for (final sub in List.of(_subscriptions)) {
      final last = sub.lastUpdatedAt;
      final due = last == null ||
          DateTime.now().difference(last) >
              Duration(hours: sub.updateIntervalHours);
      if (due) {
        try {
          await refresh(sub.id);
        } catch (_) {}
      }
    }
  }

  Future<SubscriptionFetchOptions> _fetchOptionsFor(
    VpnSubscription sub,
  ) async {
    return _defaultFetchOptions(
      SubscriptionFetchOptions(
        sendHwidInCookie: sub.sendHwidInCookie,
        encryptedSubscription: sub.encryptedSubscription,
        userAgent: _routing?.userAgent,
      ),
    );
  }

  Future<SubscriptionFetchOptions> _defaultFetchOptions(
    SubscriptionFetchOptions base,
  ) async {
    if (!base.sendHwidInCookie) return base;
    final hwid = await DeviceHwidService.getOrCreate();
    return SubscriptionFetchOptions(
      sendHwidInCookie: true,
      encryptedSubscription: base.encryptedSubscription,
      hwid: hwid,
      userAgent: base.userAgent,
    );
  }

  Future<void> _syncProfiles(
    VpnSubscription sub,
    List<VlessProfile> profiles,
  ) async {
    await _profiles.syncSubscriptionProfiles(
      sub.id,
      profiles,
      allowInsecure: sub.allowInsecure,
    );
  }

  Future<void> _reapplyAllowInsecure(String subscriptionId, bool value) async {
    final nodes = _profiles.profilesForSubscription(subscriptionId);
    for (final node in nodes) {
      final updated = node.profile.copyWith(allowInsecure: value);
      await _profiles.updateVlessProfile(node.id, updated);
    }
  }

  Future<void> _applyRouting(SubscriptionFetchResult result, String subId) async {
    final routing = _routing;
    if (routing == null) return;
    if (result.routingImports.isEmpty && result.routingEnable == null) return;
    await routing.applyImports(
      result.routingImports,
      subscriptionId: subId,
      routingEnable: result.routingEnable,
    );
  }

  void _sortSubscriptions() {
    _subscriptions.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return 0;
    });
  }

  void _scheduleAutoRefresh() {
    _autoRefreshTimer?.cancel();
    if (_subscriptions.isEmpty) return;
    _autoRefreshTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      unawaited(_refreshStaleIfNeeded());
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }
}
