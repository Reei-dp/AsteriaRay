// Shared AmneziaWG / WireGuard `.conf` helpers (Linux `awg-quick`, Windows `amneziawg-go` + `awg.exe`).

/// Linux netdevice names max 15 bytes (IFNAMSIZ-1); Windows Wintun uses the same short names in practice.
String awgInterfaceBaseName(String profileName, String? profileId) {
  var safe = profileName
      .trim()
      .replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  if (safe.isEmpty) safe = 'awg';
  if (safe.length <= 15) return safe;
  if (profileId != null && profileId.isNotEmpty) {
    final hex = profileId.replaceAll(RegExp(r'[^a-fA-F0-9]'), '');
    if (hex.length >= 14) {
      return 'w${hex.substring(0, 14)}'.toLowerCase();
    }
  }
  final h = profileName.hashCode.abs().toRadixString(36).replaceAll('-', 'z');
  final t = h.length > 14 ? h.substring(0, 14) : h.padLeft(14, '0');
  return 'a$t';
}

/// `awg-quick` runs `resolvconf` for `[Interface] DNS = …`; many Linux desktops have no `resolvconf`.
String stripWgQuickDnsLines(String conf) {
  final out = <String>[];
  for (final line in conf.split('\n')) {
    if (RegExp(r'^\s*DNS\s*=').hasMatch(line)) {
      continue;
    }
    out.add(line);
  }
  return out.join('\n');
}

/// Keys understood by [wg-quick](https://git.zx2c4.com/wireguard-tools/about/src/man/wg-quick.8) but **not** by
/// `wg setconf` / UAPI (`Line unrecognized: 'Address=…'` from `awg setconf` on Windows).
String confForWgUapiSetconf(String conf) {
  const uapiUnsupportedKeys = <String>{
    'address',
    'dns',
    'mtu',
    'saveconfig',
    'table',
    'preup',
    'postup',
    'predown',
    'postdown',
  };
  final out = <String>[];
  for (final line in conf.split('\n')) {
    final t = line.trimLeft();
    if (t.isEmpty || t.startsWith('#') || t.startsWith(';')) {
      out.add(line);
      continue;
    }
    final eq = t.indexOf('=');
    if (eq <= 0) {
      out.add(line);
      continue;
    }
    final key = t.substring(0, eq).trim().toLowerCase();
    if (uapiUnsupportedKeys.contains(key)) {
      continue;
    }
    out.add(line);
  }
  return out.join('\n');
}

/// Host part of the first `[Peer] Endpoint = host:port` (or `[ipv6]:port`) for split-exit policy routes.
String? peerEndpointHostForRoutes(String conf) {
  final peer = RegExp(
    r'\[Peer\]([^\[]*)',
    multiLine: true,
    caseSensitive: false,
  ).firstMatch(conf);
  if (peer == null) return null;
  final section = peer.group(1)!;
  final ep = RegExp(
    r'^\s*Endpoint\s*=\s*(\S+)',
    multiLine: true,
    caseSensitive: false,
  ).firstMatch(section);
  final raw = ep?.group(1);
  if (raw == null || raw.isEmpty) return null;

  if (raw.startsWith('[')) {
    final end = raw.indexOf(']');
    if (end > 1) return raw.substring(1, end);
    return null;
  }
  final colon = raw.lastIndexOf(':');
  if (colon <= 0) return null;
  return raw.substring(0, colon).trim();
}

/// Whether the first `[Peer]` section routes all IPv4 through the tunnel (needs split default routes on Windows).
bool awgPeerAllowsFullIpv4(String conf) {
  final peer = RegExp(
    r'\[Peer\]([^\[]*)',
    multiLine: true,
    caseSensitive: false,
  ).firstMatch(conf);
  if (peer == null) return false;
  return peer.group(1)!.contains('0.0.0.0/0');
}

final _ipv4AddrRe = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');

String? _wgInterfaceSection(String conf) {
  final m = RegExp(
    r'\[Interface\]([^\[]*)',
    multiLine: true,
    caseSensitive: false,
  ).firstMatch(conf);
  return m?.group(1);
}

bool _isIpv4CidrToken(String token) {
  final t = token.trim();
  final slash = t.indexOf('/');
  if (slash <= 0) return false;
  final ip = t.substring(0, slash).trim();
  final pl = int.tryParse(t.substring(slash + 1).trim());
  if (pl == null || pl < 0 || pl > 32) return false;
  return _ipv4AddrRe.hasMatch(ip);
}

/// `[Interface] Address = …` tokens (e.g. `10.66.66.2/32`) — for OS iface config after UAPI `setconf`.
List<String> interfaceIpv4CidrsFromConf(String conf) {
  final section = _wgInterfaceSection(conf);
  if (section == null) return const [];
  final out = <String>[];
  for (final m in RegExp(
    r'^\s*Address\s*=\s*(.+)$',
    multiLine: true,
    caseSensitive: false,
  ).allMatches(section)) {
    var raw = m.group(1)?.trim() ?? '';
    if (raw.isEmpty) continue;
    final hash = raw.indexOf('#');
    if (hash >= 0) raw = raw.substring(0, hash).trim();
    for (final part in raw.split(',')) {
      final p = part.trim();
      if (_isIpv4CidrToken(p)) out.add(p);
    }
  }
  return out;
}

String _prefixLenToIpv4Netmask(int prefix) {
  final p = prefix.clamp(0, 32);
  if (p <= 0) return '0.0.0.0';
  if (p >= 32) return '255.255.255.255';
  final mask = (0xffffffff ^ ((1 << (32 - p)) - 1)) & 0xffffffff;
  return '${(mask >> 24) & 0xff}.${(mask >> 16) & 0xff}.${(mask >> 8) & 0xff}.${mask & 0xff}';
}

/// Splits `10.66.66.2/32` into address + netmask for `netsh` / WMI.
(String ip, String mask)? ipv4CidrToIpAndNetmask(String cidr) {
  final t = cidr.trim();
  final slash = t.indexOf('/');
  if (slash <= 0) return null;
  final ip = t.substring(0, slash).trim();
  final pl = int.tryParse(t.substring(slash + 1).trim());
  if (pl == null || !_ipv4AddrRe.hasMatch(ip)) return null;
  return (ip, _prefixLenToIpv4Netmask(pl));
}

/// `[Interface] DNS = …` IPv4 resolvers only (comma-separated / repeated lines).
List<String> interfaceIpv4DnsFromConf(String conf) {
  final section = _wgInterfaceSection(conf);
  if (section == null) return const [];
  final out = <String>[];
  for (final m in RegExp(
    r'^\s*DNS\s*=\s*(.+)$',
    multiLine: true,
    caseSensitive: false,
  ).allMatches(section)) {
    var raw = m.group(1)?.trim() ?? '';
    if (raw.isEmpty) continue;
    final hash = raw.indexOf('#');
    if (hash >= 0) raw = raw.substring(0, hash).trim();
    for (final part in raw.split(',')) {
      final p = part.trim();
      if (p.isNotEmpty && _ipv4AddrRe.hasMatch(p)) out.add(p);
    }
  }
  return out;
}
