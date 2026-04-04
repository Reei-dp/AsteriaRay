/// Tunnel type in the app (one profile list, different native stacks).
enum VpnProtocol {
  vless,
  /// WireGuard-compatible config (AmneziaWG, etc.) stored as `.conf` text.
  amneziaWg,
  // openvpn,
  // l2tp,
}
