import 'dart:convert';

class SubscriptionUserInfo {
  const SubscriptionUserInfo({
    this.upload = 0,
    this.download = 0,
    this.total = 0,
    this.expireUnix,
  });

  final int upload;
  final int download;
  final int total;
  final int? expireUnix;

  DateTime? get expiresAt {
    final exp = expireUnix;
    if (exp == null || exp <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true).toLocal();
  }
}

SubscriptionUserInfo parseSubscriptionUserInfo(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return const SubscriptionUserInfo();
  }
  var upload = 0;
  var download = 0;
  var total = 0;
  int? expire;
  for (final part in raw.split(';')) {
    final kv = part.trim().split('=');
    if (kv.length != 2) continue;
    final key = kv[0].trim().toLowerCase();
    final val = int.tryParse(kv[1].trim());
    if (val == null) continue;
    switch (key) {
      case 'upload':
        upload = val;
      case 'download':
        download = val;
      case 'total':
        total = val;
      case 'expire':
        expire = val;
    }
  }
  return SubscriptionUserInfo(
    upload: upload,
    download: download,
    total: total,
    expireUnix: expire,
  );
}

String? decodeAnnounceHeader(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  var payload = raw.trim();
  if (payload.startsWith('base64:')) {
    payload = payload.substring('base64:'.length);
  }
  try {
    return utf8.decode(base64.decode(payload));
  } catch (_) {
    return null;
  }
}
