import 'dart:convert';

/// AmneziaWG / WireGuard profile: full `.conf` text for the native tunnel.
class AmneziaWgProfile {
  AmneziaWgProfile({
    required this.id,
    required this.name,
    required this.conf,
  });

  final String id;
  final String name;
  final String conf;

  /// Short subtitle for the list (`Endpoint` from `[Peer]`, or fallback label).
  String get endpointHint {
    final ep = _endpointFromConf(conf);
    return ep ?? 'AmneziaWG';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'conf': conf,
      };

  factory AmneziaWgProfile.fromMap(Map<String, dynamic> map) {
    return AmneziaWgProfile(
      id: map['id'] as String,
      name: map['name'] as String,
      conf: map['conf'] as String,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory AmneziaWgProfile.fromJson(String source) =>
      AmneziaWgProfile.fromMap(jsonDecode(source) as Map<String, dynamic>);

  /// Name from `# Name = …` comment, else from [Endpoint], else default label.
  factory AmneziaWgProfile.fromConf(
    String raw, {
    required String id,
    String? fallbackName,
  }) {
    final conf = raw.trim();
    final name = fallbackName ??
        _nameFromConf(conf) ??
        _endpointFromConf(conf) ??
        'AmneziaWG';
    return AmneziaWgProfile(id: id, name: name, conf: conf);
  }
}

String? _endpointFromConf(String conf) {
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
  return ep?.group(1);
}

String? _nameFromConf(String conf) {
  final m = RegExp(
    r'^\s*#\s*Name\s*=\s*(.+)$',
    multiLine: true,
    caseSensitive: false,
  ).firstMatch(conf);
  if (m != null) return m.group(1)?.trim();
  final m2 = RegExp(
    r'^\s*Name\s*=\s*(.+)$',
    multiLine: true,
    caseSensitive: false,
  ).firstMatch(conf);
  return m2?.group(1)?.trim();
}
