/// Result of sniffing pasted or imported text (clipboard, file).
enum ConfigImportKind {
  /// A `vless://…` URI line.
  vlessUri,

  /// WireGuard / AmneziaWG-style `.conf` (`[Interface]` + `[Peer]`).
  wireGuardConf,

  /// Unrecognized (sing-box JSON, OpenVPN, etc. — extend later).
  unknown,
}

abstract final class ConfigImportDetector {
  ConfigImportDetector._();

  static ConfigImportKind detect(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return ConfigImportKind.unknown;

    final lower = t.toLowerCase();
    if (t.startsWith('vless://')) {
      return ConfigImportKind.vlessUri;
    }

    if (_looksLikeWireGuard(lower)) {
      return ConfigImportKind.wireGuardConf;
    }

    return ConfigImportKind.unknown;
  }

  static bool _looksLikeWireGuard(String lower) {
    if (!lower.contains('[interface]') || !lower.contains('[peer]')) {
      return false;
    }
    if (lower.contains('privatekey') || lower.contains('private_key')) {
      return true;
    }
    return lower.contains('publickey') || lower.contains('public_key');
  }
}
