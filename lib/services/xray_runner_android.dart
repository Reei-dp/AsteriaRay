import '../models/routing_profile.dart';
import '../models/vless_profile.dart';
import 'xray_core_client_config.dart';
import 'xray_runner_base.dart';

/// Xray-core JSON for Android ([AndroidLibXrayLite] + VPN fd). Native XHTTP (`network: xhttp`) is supported.
final class XrayRunnerAndroid extends XrayRunnerBase {
  @override
  Map<String, dynamic> buildConfig(
    VlessProfile profile,
    bool useDoh, {
    RoutingProfile? routing,
  }) {
    return buildXrayCoreClientConfig(profile, useDoh, routing: routing);
  }
}
