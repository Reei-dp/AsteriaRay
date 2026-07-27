/// Display helpers for subscription node rows (Happ-style names from URI fragment).
import '../models/vless_profile.dart';
import '../models/vless_types.dart';

class SubscriptionNodeDisplay {
  const SubscriptionNodeDisplay({required this.flag, required this.title});

  final String flag;
  final String title;
}

/// Happ-style: cascade icon = entry country (🇷🇺); direct = that country's flag.
SubscriptionNodeDisplay subscriptionNodeDisplay(String rawName) {
  final trimmed = rawName.trim();
  if (trimmed.isEmpty) {
    return const SubscriptionNodeDisplay(flag: '🌐', title: '');
  }

  final flags = _extractFlagPairs(trimmed);
  final hasRoute = _hasRouteArrow(trimmed);

  final String flag;
  if (flags.isEmpty) {
    flag = _flagFromCountryWords(trimmed, entryCountry: hasRoute);
  } else {
    flag = flags.first;
  }

  var title = trimmed;
  if (hasRoute && flags.isNotEmpty) {
    title = _stripLeadingFlagPair(trimmed);
  } else {
    title = _stripAllFlagPairs(trimmed);
  }
  title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (title.isEmpty) title = trimmed;

  return SubscriptionNodeDisplay(flag: flag, title: title);
}

bool _hasRouteArrow(String text) {
  return text.contains('→') ||
      text.contains('->') ||
      text.contains('—>') ||
      text.contains('=>');
}

List<String> _extractFlagPairs(String text) {
  final runes = text.runes.toList();
  final flags = <String>[];
  for (var i = 0; i < runes.length; i++) {
    final r = runes[i];
    if (r >= 0x1F1E6 && r <= 0x1F1FF && i + 1 < runes.length) {
      final r2 = runes[i + 1];
      if (r2 >= 0x1F1E6 && r2 <= 0x1F1FF) {
        flags.add(String.fromCharCodes([r, r2]));
        i++;
      }
    }
  }
  return flags;
}

String _stripLeadingFlagPair(String text) {
  final runes = text.runes.toList();
  if (runes.length >= 2 &&
      runes[0] >= 0x1F1E6 &&
      runes[0] <= 0x1F1FF &&
      runes[1] >= 0x1F1E6 &&
      runes[1] <= 0x1F1FF) {
    var start = 2;
    while (start < runes.length && runes[start] == 0x20) {
      start++;
    }
    return String.fromCharCodes(runes.sublist(start));
  }
  return text;
}

String _stripAllFlagPairs(String text) {
  final runes = text.runes.toList();
  final out = <int>[];
  for (var i = 0; i < runes.length; i++) {
    final r = runes[i];
    if (r >= 0x1F1E6 && r <= 0x1F1FF && i + 1 < runes.length) {
      final r2 = runes[i + 1];
      if (r2 >= 0x1F1E6 && r2 <= 0x1F1FF) {
        i++;
        continue;
      }
    }
    out.add(r);
  }
  return String.fromCharCodes(out).trim();
}

String _flagFromCountryWords(String name, {bool entryCountry = false}) {
  final parts = name.split(RegExp(r'→|->|—>|=>'));
  final target = (entryCountry && parts.length > 1 ? parts.first : parts.length > 1 ? parts.last : name)
      .toLowerCase();
  if (target.contains('germany') || target.contains('герман')) return '🇩🇪';
  if (target.contains('netherlands') ||
      target.contains('нидерланд') ||
      target.contains('нідерланд')) {
    return '🇳🇱';
  }
  if (target.contains('france') || target.contains('франц')) return '🇫🇷';
  if (target.contains('russia') ||
      target.contains('росси') ||
      target.contains('росі')) {
    return '🇷🇺';
  }
  return '🌐';
}

String flagEmojiFromName(String name) =>
    subscriptionNodeDisplay(name).flag;

String vlessProtocolLabel(VlessProfile profile) {
  final parts = <String>['VLESS'];
  parts.add(transportToString(profile.transport).toUpperCase());
  if (profile.security.isNotEmpty && profile.security != 'none') {
    parts.add(profile.security.toUpperCase());
  }
  return parts.join(' / ');
}

String formatTrafficBytes(int bytes, {required bool useEnglish}) {
  if (bytes < 1024) return '$bytes ${useEnglish ? 'B' : 'Б'}';
  if (bytes < 1024 * 1024) {
    final v = (bytes / 1024).toStringAsFixed(bytes < 10 * 1024 ? 1 : 0);
    return '$v ${useEnglish ? 'KB' : 'КБ'}';
  }
  if (bytes < 1024 * 1024 * 1024) {
    final v = (bytes / (1024 * 1024)).toStringAsFixed(1);
    return '$v ${useEnglish ? 'MB' : 'МБ'}';
  }
  final v = (bytes / (1024 * 1024 * 1024)).toStringAsFixed(2);
  return '$v ${useEnglish ? 'GB' : 'ГБ'}';
}
