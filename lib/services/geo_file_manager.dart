import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../models/routing_profile.dart';

/// Default geo sources (Happ / v2ray-rules-dat).
const kDefaultGeositeUrl =
    'https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat';
const kDefaultGeoipUrl =
    'https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat';

extension RoutingProfileGeoUrls on RoutingProfile {
  String get effectiveGeositeUrl {
    final u = geositeUrl?.trim();
    return (u != null && u.isNotEmpty) ? u : kDefaultGeositeUrl;
  }

  String get effectiveGeoipUrl {
    final u = geoipUrl?.trim();
    return (u != null && u.isNotEmpty) ? u : kDefaultGeoipUrl;
  }
}

class GeoFileInfo {
  const GeoFileInfo({
    required this.path,
    this.updatedAt,
    this.sizeBytes = 0,
  });

  final String path;
  final DateTime? updatedAt;
  final int sizeBytes;
}

class GeoFileManager {
  GeoFileManager({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<GeoFileInfo> geoipInfo(String workDir) async =>
      _info(p.join(workDir, 'geoip.dat'));

  Future<GeoFileInfo> geositeInfo(String workDir) async =>
      _info(p.join(workDir, 'geosite.dat'));

  Future<void> ensureForProfile(String workDir, RoutingProfile profile) async {
    final geoip = profile.geoipUrl?.trim();
    if (geoip != null && geoip.isNotEmpty) {
      await _download(geoip, p.join(workDir, 'geoip.dat'));
    }
    final geosite = profile.geositeUrl?.trim();
    if (geosite != null && geosite.isNotEmpty) {
      await _download(geosite, p.join(workDir, 'geosite.dat'));
    }
  }

  Future<void> refreshGeoip(String workDir, RoutingProfile profile) async {
    await _download(profile.effectiveGeoipUrl, p.join(workDir, 'geoip.dat'));
  }

  Future<void> refreshGeosite(String workDir, RoutingProfile profile) async {
    await _download(profile.effectiveGeositeUrl, p.join(workDir, 'geosite.dat'));
  }

  Future<GeoFileInfo> _info(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return GeoFileInfo(path: path);
    }
    final stat = await file.stat();
    return GeoFileInfo(
      path: path,
      updatedAt: stat.modified,
      sizeBytes: stat.size,
    );
  }

  Future<void> _download(String url, String destPath) async {
    final response = await _client
        .get(Uri.parse(url))
        .timeout(const Duration(minutes: 3));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GeoFileException('HTTP ${response.statusCode}');
    }
    final file = File(destPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(response.bodyBytes, flush: true);
  }
}

class GeoFileException implements Exception {
  GeoFileException(this.message);
  final String message;
  @override
  String toString() => message;
}
