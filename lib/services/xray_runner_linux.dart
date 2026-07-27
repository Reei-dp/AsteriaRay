import '../models/routing_profile.dart';
import '../models/vless_profile.dart';
import 'xray_core_client_config.dart';
import 'xray_runner_base.dart';

/// Linux VLESS: тот же Xray-core JSON, что и на Android (`tun` + VLESS outbound).
final class XrayRunnerLinux extends XrayRunnerBase {
  @override
  Map<String, dynamic> buildConfig(
    VlessProfile profile,
    bool useDoh, {
    RoutingProfile? routing,
  }) {
    return buildXrayCoreClientConfig(profile, useDoh, routing: routing);
  }
}
