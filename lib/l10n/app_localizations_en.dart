import 'app_localizations.dart';

final class AppLocalizationsEn extends AppLocalizations {
  @override
  String get settingsTitle => 'Settings';

  @override
  String get interfaceSettingsTitle => 'Interface';

  @override
  String get tunnelSettingsTitle => 'Tunnel';

  @override
  String get languageTitle => 'Language';

  @override
  String get themeTitle => 'Theme';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get dnsViaTunnelTitle => 'DNS via VPS (tunnel)';

  @override
  String get dnsViaTunnelOnSubtitle =>
      'DNS uses the same encrypted path to the VPS (VLESS) as the rest of your traffic.';

  @override
  String get dnsViaTunnelOffSubtitle =>
      'Public DoH to Cloudflare (1.1.1.1), separate HTTPS that bypasses the VPS tunnel.';

  @override
  String get dnsReconnectHint =>
      'If VPN is already connected, the config restarts automatically.';

  @override
  String get appTitle => 'Asteria 🚀';

  @override
  String get tooltipSettings => 'Settings';

  @override
  String get tooltipImportFile => 'Import from file';

  @override
  String get tooltipShare => 'Export / share';

  @override
  String get tooltipAddConfig => 'Add config';

  @override
  String get addConfigTitle => 'Add config';

  @override
  String get addManualTitle => 'Manual';

  @override
  String get addManualSubtitle => 'VLESS or AmneziaWG — swipe on the next screen';

  @override
  String get addQrTitle => 'Scan QR code';

  @override
  String get addQrSubtitle => 'vless:// or AmneziaWG .conf';

  @override
  String get addClipboardTitle => 'From clipboard';

  @override
  String get addClipboardSubtitle => 'Paste a link or .conf';

  @override
  String get clipboardEmpty => 'Clipboard is empty';

  @override
  String get fileReadError => 'Could not read file';

  @override
  String get fileEmpty => 'File is empty';

  @override
  String importedCount(int count) => 'Imported: $count';

  @override
  String importedProfile(String name) => 'Imported: $name';

  @override
  String importError(Object error) => 'Import error: $error';

  @override
  String get importFormatError =>
      'Unrecognized format. Expected vless:// or WireGuard .conf';

  @override
  String profileDeleted(String name) => '"$name" deleted';

  @override
  String get noActiveConfig => 'No active config';

  @override
  String switchingTo(String name) => 'Switching to $name...';

  @override
  String connectingTo(String name) => 'Connecting to $name...';

  @override
  String get deleteConfigTitle => 'Delete config?';

  @override
  String get deleteConfigBody => 'The profile will be removed from this device.';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get noVlessConfigs => 'No VLESS configs';

  @override
  String get noAwgConfigs => 'No AmneziaWG configs';

  @override
  String get swipeToAwg => 'Swipe right → AmneziaWG';

  @override
  String get swipeToVless => 'Swipe left ← VLESS';

  @override
  String get tapPlusToAdd => 'Tap + to add';

  @override
  String get selectConfig => 'Select a config';

  @override
  String get connectFailed => 'Could not connect';

  @override
  String get qrScannerMobileOnly => 'QR scanner is available on Android and iOS';

  @override
  String get awgPlatformUnsupported =>
      'AmneziaWG is only supported on Android, Linux, and Windows';

  @override
  String awgConnectTimeout(String? detail) {
    final tail = (detail != null && detail.isNotEmpty) ? ' $detail' : '';
    return 'AmneziaWG connection timed out (3 min). '
        'Often: awg setconf waiting for UAPI, or DNS with full tunnel.$tail';
  }

  @override
  String get vlessTunnelNotEstablished =>
      'VPN interface was not created (no key in the status bar).';

  @override
  String get vlessTunnelLogcatHint =>
      ' In logcat: process :xrayvpn, tag LibxrayVpnService — '
      '"Failed to establish VPN", "VPN permission not granted", or Xray start error.';

  @override
  String get xrayNativePrefix => 'Xray: ';

  @override
  String get connected => 'Connected';

  @override
  String get connecting => 'Connecting…';

  @override
  String get error => 'Error';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get edit => 'Edit';

  @override
  String get remove => 'Delete';

  @override
  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  String get newConfig => 'New config';

  @override
  String get save => 'Save';

  @override
  String get saveConfig => 'Save config';

  @override
  String get editConfig => 'Edit';

  @override
  String get configAdded => 'Config added';

  @override
  String get configSaved => 'Config saved';

  @override
  String get importFromUri => 'Import from URI';

  @override
  String get fillFromUri => 'Fill from URI';

  @override
  String get basicParams => 'Basic parameters';

  @override
  String get nameLabel => 'Name';

  @override
  String get nameRequired => 'Enter a name';

  @override
  String get hostLabel => 'Host';

  @override
  String get hostRequired => 'Host is required';

  @override
  String get portLabel => 'Port';

  @override
  String get portInvalid => 'Invalid port';

  @override
  String get uuidLabel => 'UUID';

  @override
  String get uuidRequired => 'UUID is required';

  @override
  String get securityTransport => 'Security & transport';

  @override
  String get securityLabel => 'Security';

  @override
  String get transportLabel => 'Transport';

  @override
  String get advancedParams => 'Advanced parameters';

  @override
  String get descriptionLabel => 'Description';

  @override
  String uriError(Object error) => 'URI error: $error';

  @override
  String get editAwg => 'Edit AmneziaWG';

  @override
  String get newAwg => 'New AmneziaWG';

  @override
  String get pasteConfTitle => 'Paste .conf';

  @override
  String get pasteConfHint =>
      'Copy a config from AmneziaVPN or paste an exported .conf file';

  @override
  String get pasteFromClipboard => 'Paste from clipboard';

  @override
  String get params => 'Parameters';

  @override
  String get confLabel => 'Config (.conf)';

  @override
  String get confRequired => 'Paste a .conf';

  @override
  String get confInvalid =>
      'WireGuard/AmneziaWG .conf with [Interface] and [Peer] required';

  @override
  String get awgConfHelper =>
      '[Interface] + [Peer]; Amnezia params (Jc, S1…) are kept as-is';

  @override
  String get scanQrTitle => 'Scan QR code';

  @override
  String get scanQrHint => 'Point the camera at a QR with vless:// or AmneziaWG .conf';

  @override
  String get cameraPermissionHint =>
      'Allow camera access to scan QR codes';

  @override
  String get cameraOpenFailed => 'Could not open camera';

  @override
  String get allowAccess => 'Allow access';

  @override
  String get retry => 'Retry';

  @override
  String get openAppSettings => 'Open app settings';

  @override
  String get flashlight => 'Flashlight';

  @override
  String get switchCamera => 'Switch camera';

  @override
  String get trayShow => 'Show AsteriaRay';

  @override
  String get trayQuit => 'Quit';

  @override
  String get addSubscriptionTitle => 'VLESS subscription';

  @override
  String get addSubscriptionHint =>
      'Paste a link like https://…/api/sub/… from Happ or the Asteria bot.';

  @override
  String get addSubscriptionAction => 'Add subscription';

  @override
  String get subscriptionUrlLabel => 'Subscription URL';

  @override
  String get subscriptionUrlHint => 'https://sub.asteriamirror.cloud/api/sub/…';

  @override
  String get subscriptionUrlRequired => 'Enter a URL';

  @override
  String get subscriptionInvalidUrl => 'Invalid subscription URL';

  @override
  String get subscriptionAdded => 'Subscription added';

  @override
  String subscriptionAddFailed(Object error) => 'Error: $error';

  @override
  String get subscriptionRefresh => 'Refresh';

  @override
  String get subscriptionRefreshed => 'Subscription updated';

  @override
  String subscriptionRefreshFailed(Object error) => 'Refresh failed: $error';

  @override
  String get subscriptionPingAll => 'Ping all';

  @override
  String get subscriptionPingNa => 'N/A';

  @override
  String subscriptionPingMs(int ms) => '${ms}ms';

  @override
  String subscriptionAutoUpdate(int hours) => 'Auto · ${hours}h';

  @override
  String subscriptionExpires(String date) => 'Expires: $date';

  @override
  String get subscriptionUnlimited => '∞';

  @override
  String get subscriptionManualSection => 'Manual configs';

  @override
  String get subscriptionEmptyTitle => 'No VLESS subscription';

  @override
  String get subscriptionEmptyHint =>
      'Tap + → «From clipboard» and paste your subscription link.';

  @override
  String get subscriptionRemove => 'Remove subscription';

  @override
  String get subscriptionRemoveBody =>
      'All servers from this subscription will be removed from the device.';

  @override
  String get subscriptionRemoved => 'Subscription removed';

  @override
  String get addSubscriptionMenuTitle => 'Subscription';

  @override
  String get addSubscriptionMenuSubtitle => 'VLESS via link (Happ / Asteria)';

  @override
  String get addFileTitle => 'From file';

  @override
  String get addFileSubtitle => 'vless://, .conf, or a list of links';

  @override
  String get subscriptionMenuRefresh => 'Update subscription';

  @override
  String get subscriptionMenuPing => 'Ping';

  @override
  String get subscriptionMenuEdit => 'Edit';

  @override
  String get subscriptionMenuPin => 'Pin';

  @override
  String get subscriptionMenuUnpin => 'Unpin';

  @override
  String get subscriptionEditTitle => 'Edit subscription';

  @override
  String get subscriptionEditOptions => 'Options';

  @override
  String get subscriptionOptHideServers => 'Hide server settings';

  @override
  String get subscriptionOptEncrypted => 'Encrypted subscription';

  @override
  String get subscriptionOptAllowInsecure => 'Allow insecure';

  @override
  String get subscriptionOptSendHwid => 'Send HWID in Cookie';

  @override
  String get subscriptionEditHeaderUrl => 'Title and URL';

  @override
  String get subscriptionEditNameLabel => 'Name';

  @override
  String get subscriptionEditNameRequired => 'Enter a name';

  @override
  String get subscriptionSave => 'Save';

  @override
  String get subscriptionSaved => 'Subscription saved';

  @override
  String subscriptionSaveFailed(Object error) => 'Could not save: $error';

  @override
  String get routingTitle => 'Routing';

  @override
  String get routingDisabled => 'Off';

  @override
  String get routingUseSection => 'Use routing';

  @override
  String get routingEnable => 'Enable routing';

  @override
  String get routingUserAgent => 'User-Agent';

  @override
  String get routingHint =>
      'Routing rules control traffic via Proxy, Direct, and Block. Profiles can arrive with a subscription.';

  @override
  String get routingProfilesSection => 'Profiles';

  @override
  String get routingProfilesEmpty => 'Refresh the subscription to import a routing profile automatically.';

  @override
  String get routingEditActive => 'Active profile rules';

  @override
  String get routingRulesTitle => 'Routing rules';

  @override
  String get routingProfileMissing => 'Profile not found';

  @override
  String get routingProfileNameLabel => 'Title';

  @override
  String get routingGeoSection => 'Geo files';

  @override
  String get routingGeositeFile => 'Geosite file';

  @override
  String get routingGeoipFile => 'GeoIP file';

  @override
  String get routingGeoNotDownloaded => 'Not downloaded';

  @override
  String routingGeoUpdated(String date, String size) => 'Last updated: $date, size: $size';

  @override
  String get routingDomainSection => 'Domain settings';

  @override
  String get routingFakeDns => 'Use fake DNS';

  @override
  String get routingDomainStrategy => 'Domain strategy';

  @override
  String get routingRemoteDnsSection => 'Remote DNS';

  @override
  String get routingDomesticDnsSection => 'Home DNS';

  @override
  String get routingRemoteDnsType => 'Remote DNS type';

  @override
  String get routingDomesticDnsType => 'Home DNS type';

  @override
  String get routingRemoteIp => 'Remote IP';

  @override
  String get routingDomesticIp => 'Home IP';

  @override
  String get routingDnsDomain => 'DoH URL';

  @override
  String get routingProxySection => 'Proxy settings';

  @override
  String get routingGlobalProxy => 'Global proxy';

  @override
  String get routingGlobalProxyHint =>
      'When off, all traffic goes direct except matched route rules.';

  @override
  String get routingRulesSection => 'Routing rules';

  @override
  String get routingProxyRules => 'Proxy';

  @override
  String get routingDirectRules => 'Direct';

  @override
  String get routingBlockRules => 'Block';

  @override
  String get routingOrderSection => 'Routing order';

  @override
  String get routingOrderLabel => 'Order';

  @override
  String get routingOrderBlock => 'block';

  @override
  String get routingOrderDirect => 'direct';

  @override
  String get routingOrderProxy => 'proxy';

  @override
  String get routingDeleteProfile => 'Delete configuration';

  @override
  String get routingDeleteProfileBody => 'This routing profile will be removed from the device.';

  @override
  String get routingSaveUpper => 'SAVE';

  @override
  String get routingRulesEditorHint => 'One rule per line: geosite:ru, geoip:private, domain:example.com';
}
