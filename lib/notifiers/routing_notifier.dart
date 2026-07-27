import 'package:flutter/foundation.dart';

import '../models/routing_profile.dart';
import '../services/routing_profile_parser.dart';
import '../services/routing_profile_store.dart';
import '../services/geo_file_manager.dart';

class RoutingNotifier extends ChangeNotifier {
  RoutingNotifier(this._store);

  final RoutingProfileStore _store;

  bool _initialized = false;
  bool _enabled = true;
  String? _activeProfileName;
  String _userAgent = 'chrome-android';
  List<RoutingProfile> _profiles = [];

  bool get initialized => _initialized;
  bool get enabled => _enabled;
  String? get activeProfileName => _activeProfileName;
  String get userAgent => _userAgent;
  List<RoutingProfile> get profiles => List.unmodifiable(_profiles);

  RoutingProfile? get activeProfile {
    final name = _activeProfileName;
    if (name == null) return null;
    for (final p in _profiles) {
      if (p.name == name) return p;
    }
    return _profiles.isNotEmpty ? _profiles.first : null;
  }

  RoutingProfile? profileByName(String name) {
    for (final p in _profiles) {
      if (p.name == name) return p;
    }
    return null;
  }

  Future<void> init() async {
    _enabled = _store.enabled;
    _activeProfileName = _store.activeProfileName;
    _userAgent = _store.userAgent;
    final loaded = await _store.loadProfiles();
    final patched = loaded.map(_ensureGeoUrls).toList();
    var needsGeoSave = false;
    for (var i = 0; i < loaded.length; i++) {
      if (loaded[i].geositeUrl != patched[i].geositeUrl ||
          loaded[i].geoipUrl != patched[i].geoipUrl) {
        needsGeoSave = true;
        break;
      }
    }
    _profiles = patched;
    if (needsGeoSave) {
      await _store.saveProfiles(_profiles);
    }
    if (_profiles.isEmpty) {
      const defaultProfile = RoutingProfile(
        name: 'Asteria DNS',
        globalProxy: true,
        directSites: ['geosite:private'],
        directIp: ['geoip:private'],
        remoteDnsType: DnsType.dou,
        remoteDnsIp: '1.1.1.1',
        domesticDnsType: DnsType.dou,
        domesticDnsIp: '1.0.0.1',
        geoipUrl: kDefaultGeoipUrl,
        geositeUrl: kDefaultGeositeUrl,
      );
      _profiles = [defaultProfile];
      _activeProfileName = defaultProfile.name;
      await _store.saveProfiles(_profiles);
      await _store.saveActiveProfileName(_activeProfileName);
    }
    if (_activeProfileName == null && _profiles.isNotEmpty) {
      _activeProfileName = _profiles.first.name;
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await _store.saveEnabled(value);
    notifyListeners();
  }

  Future<void> setActiveProfile(String name) async {
    _activeProfileName = name;
    await _store.saveActiveProfileName(name);
    notifyListeners();
  }

  Future<void> setUserAgent(String value) async {
    _userAgent = value;
    await _store.saveUserAgent(value);
    notifyListeners();
  }

  Future<void> upsertProfile(RoutingProfile profile, {bool activate = false}) async {
    final idx = _profiles.indexWhere((p) => p.name == profile.name);
    if (idx >= 0) {
      _profiles[idx] = profile;
    } else {
      _profiles = [..._profiles, profile];
    }
    if (activate) {
      _activeProfileName = profile.name;
      await _store.saveActiveProfileName(profile.name);
    }
    await _store.saveProfiles(_profiles);
    notifyListeners();
  }

  Future<void> updateProfile(RoutingProfile profile) async {
    final idx = _profiles.indexWhere((p) => p.name == profile.name);
    if (idx < 0) return;
    _profiles[idx] = profile;
    await _store.saveProfiles(_profiles);
    notifyListeners();
  }

  Future<void> deleteProfile(String name) async {
    _profiles = _profiles.where((p) => p.name != name).toList();
    if (_activeProfileName == name) {
      _activeProfileName = _profiles.isNotEmpty ? _profiles.first.name : null;
      await _store.saveActiveProfileName(_activeProfileName);
    }
    await _store.saveProfiles(_profiles);
    notifyListeners();
  }

  Future<void> applyImports(
    Iterable<HappRoutingImport> imports, {
    String? subscriptionId,
    bool? routingEnable,
  }) async {
    if (routingEnable == false) {
      await setEnabled(false);
    } else if (routingEnable == true) {
      await setEnabled(true);
    }

    for (final imp in imports) {
      if (imp.disableRouting) {
        await setEnabled(false);
        continue;
      }
      final p = imp.profile;
      if (p == null) continue;
      await upsertProfile(
        p.copyWith(subscriptionId: subscriptionId ?? p.subscriptionId),
        activate: imp.activate,
      );
      if (imp.activate) {
        await setEnabled(true);
      }
    }
  }

  Future<void> applyHeader(String? routingHeader, {String? subscriptionId}) async {
    final imp = RoutingProfileParser.parseHeader(routingHeader);
    if (imp == null) return;
    await applyImports([imp], subscriptionId: subscriptionId);
  }

  Future<void> applyBodyLines(String body, {String? subscriptionId}) async {
    final imports = RoutingProfileParser.parseBodyLines(body);
    if (imports.isEmpty) return;
    await applyImports(imports, subscriptionId: subscriptionId);
  }

  static RoutingProfile _ensureGeoUrls(RoutingProfile p) {
    final geosite = p.geositeUrl?.trim();
    final geoip = p.geoipUrl?.trim();
    if ((geosite != null && geosite.isNotEmpty) &&
        (geoip != null && geoip.isNotEmpty)) {
      return p;
    }
    return p.copyWith(
      geositeUrl: (geosite != null && geosite.isNotEmpty)
          ? geosite
          : kDefaultGeositeUrl,
      geoipUrl:
          (geoip != null && geoip.isNotEmpty) ? geoip : kDefaultGeoipUrl,
    );
  }
}
