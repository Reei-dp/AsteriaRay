import '../models/vless_profile.dart';
import 'xray_core_client_config.dart';

/// Local SOCKS inbound for latency probe (desktop: `xray run` + curl; Android uses libv2ray in-process).
const kXrayProbeSocksPort = 10853;

/// Per-node ping budget; slow/dead nodes are skipped (shown as n/a).
const kXrayLatencyProbeTimeout = Duration(seconds: 5);

/// Parallel probes (each worker uses `kXrayProbeSocksPort + workerIndex` on desktop).
const kXrayLatencyProbeConcurrency = 3;

/// Xray JSON for delay test: VLESS outbound + local SOCKS inbound (no TUN).
Map<String, dynamic> buildXrayLatencyProbeConfig(
  VlessProfile profile,
  bool useDoh, {
  int socksPort = kXrayProbeSocksPort,
}) {
  final base = buildXrayCoreClientConfig(profile, useDoh);
  base['log'] = {'loglevel': 'warning'};
  // VPN policy uses 1s uplink/downlink caps — kills probe HTTP mid-flight.
  base.remove('policy');
  base.remove('stats');
  base['inbounds'] = [
    {
      'tag': 'probe-socks',
      'listen': '127.0.0.1',
      'port': socksPort,
      'protocol': 'socks',
      'settings': {
        'auth': 'noauth',
        'udp': false,
      },
    },
  ];
  base['routing'] = {
    'domainStrategy': 'IPIfNonMatch',
    'rules': [
      {
        'type': 'field',
        'inboundTag': ['probe-socks'],
        'outboundTag': 'proxy',
      },
      {
        'type': 'field',
        'network': 'tcp,udp',
        'outboundTag': 'proxy',
      },
    ],
  };
  return base;
}

const kXrayLatencyTestUrl = 'https://www.google.com/generate_204';
