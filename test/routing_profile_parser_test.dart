import 'dart:convert';

import 'package:asteriaray/models/routing_profile.dart';
import 'package:asteriaray/services/routing_profile_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parse Asteria DNS happ link', () {
    const jsonMap = {
      'Name': 'Asteria DNS',
      'GlobalProxy': 'true',
      'RemoteDNSType': 'DoU',
      'RemoteDNSIP': '1.1.1.1',
      'DomesticDNSType': 'DoU',
      'DomesticDNSIP': '1.0.0.1',
      'DomainStrategy': 'IPIfNonMatch',
      'DirectSites': ['geosite:private'],
      'DirectIp': ['geoip:private'],
      'FakeDNS': 'false',
    };
    final b64 = base64Encode(utf8.encode(jsonEncode(jsonMap)));
    final link = 'happ://routing/onadd/$b64';
    final imp = RoutingProfileParser.parseHappLink(link);
    expect(imp, isNotNull);
    expect(imp!.activate, isTrue);
    expect(imp.profile!.name, 'Asteria DNS');
    expect(imp.profile!.remoteDnsIp, '1.1.1.1');
    expect(imp.profile!.directSites, ['geosite:private']);
  });

  test('parse routing off', () {
    final imp = RoutingProfileParser.parseHappLink('happ://routing/off');
    expect(imp?.disableRouting, isTrue);
  });
}
