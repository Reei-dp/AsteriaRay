import 'dart:convert';

class VpnSubscription {
  const VpnSubscription({
    required this.id,
    required this.url,
    required this.title,
    this.uploadBytes = 0,
    this.downloadBytes = 0,
    this.totalBytes = 0,
    this.expiresAt,
    this.updateIntervalHours = 3,
    this.supportUrl,
    this.webPageUrl,
    this.announce,
    this.lastUpdatedAt,
    this.hideServerSettings = false,
    this.encryptedSubscription = false,
    this.allowInsecure = false,
    this.sendHwidInCookie = false,
    this.pinned = false,
  });

  final String id;
  final String url;
  final String title;
  final int uploadBytes;
  final int downloadBytes;
  final int totalBytes;
  final DateTime? expiresAt;
  final int updateIntervalHours;
  final String? supportUrl;
  final String? webPageUrl;
  final String? announce;
  final DateTime? lastUpdatedAt;
  final bool hideServerSettings;
  final bool encryptedSubscription;
  final bool allowInsecure;
  final bool sendHwidInCookie;
  final bool pinned;

  bool get isExpired {
    final exp = expiresAt;
    if (exp == null) return false;
    return exp.isBefore(DateTime.now());
  }

  VpnSubscription copyWith({
    String? id,
    String? url,
    String? title,
    int? uploadBytes,
    int? downloadBytes,
    int? totalBytes,
    DateTime? expiresAt,
    int? updateIntervalHours,
    String? supportUrl,
    String? webPageUrl,
    String? announce,
    DateTime? lastUpdatedAt,
    bool? hideServerSettings,
    bool? encryptedSubscription,
    bool? allowInsecure,
    bool? sendHwidInCookie,
    bool? pinned,
  }) {
    return VpnSubscription(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      uploadBytes: uploadBytes ?? this.uploadBytes,
      downloadBytes: downloadBytes ?? this.downloadBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      expiresAt: expiresAt ?? this.expiresAt,
      updateIntervalHours: updateIntervalHours ?? this.updateIntervalHours,
      supportUrl: supportUrl ?? this.supportUrl,
      webPageUrl: webPageUrl ?? this.webPageUrl,
      announce: announce ?? this.announce,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      hideServerSettings: hideServerSettings ?? this.hideServerSettings,
      encryptedSubscription:
          encryptedSubscription ?? this.encryptedSubscription,
      allowInsecure: allowInsecure ?? this.allowInsecure,
      sendHwidInCookie: sendHwidInCookie ?? this.sendHwidInCookie,
      pinned: pinned ?? this.pinned,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'url': url,
        'title': title,
        'uploadBytes': uploadBytes,
        'downloadBytes': downloadBytes,
        'totalBytes': totalBytes,
        if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
        'updateIntervalHours': updateIntervalHours,
        if (supportUrl != null) 'supportUrl': supportUrl,
        if (webPageUrl != null) 'webPageUrl': webPageUrl,
        if (announce != null) 'announce': announce,
        if (lastUpdatedAt != null)
          'lastUpdatedAt': lastUpdatedAt!.toIso8601String(),
        'hideServerSettings': hideServerSettings,
        'encryptedSubscription': encryptedSubscription,
        'allowInsecure': allowInsecure,
        'sendHwidInCookie': sendHwidInCookie,
        'pinned': pinned,
      };

  factory VpnSubscription.fromMap(Map<String, dynamic> map) {
    return VpnSubscription(
      id: map['id'] as String,
      url: map['url'] as String,
      title: (map['title'] as String?) ?? 'Asteria',
      uploadBytes: (map['uploadBytes'] as num?)?.toInt() ?? 0,
      downloadBytes: (map['downloadBytes'] as num?)?.toInt() ?? 0,
      totalBytes: (map['totalBytes'] as num?)?.toInt() ?? 0,
      expiresAt: map['expiresAt'] != null
          ? DateTime.tryParse(map['expiresAt'] as String)
          : null,
      updateIntervalHours:
          (map['updateIntervalHours'] as num?)?.toInt() ?? 3,
      supportUrl: map['supportUrl'] as String?,
      webPageUrl: map['webPageUrl'] as String?,
      announce: map['announce'] as String?,
      lastUpdatedAt: map['lastUpdatedAt'] != null
          ? DateTime.tryParse(map['lastUpdatedAt'] as String)
          : null,
      hideServerSettings: map['hideServerSettings'] as bool? ?? false,
      encryptedSubscription: map['encryptedSubscription'] as bool? ?? false,
      allowInsecure: map['allowInsecure'] as bool? ?? false,
      sendHwidInCookie: map['sendHwidInCookie'] as bool? ?? false,
      pinned: map['pinned'] as bool? ?? false,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory VpnSubscription.fromJson(String source) =>
      VpnSubscription.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

class SubscriptionFetchOptions {
  const SubscriptionFetchOptions({
    this.sendHwidInCookie = false,
    this.encryptedSubscription = false,
    this.hwid,
    this.userAgent,
  });

  final bool sendHwidInCookie;
  final bool encryptedSubscription;
  final String? hwid;
  final String? userAgent;
}
