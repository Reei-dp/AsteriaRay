import 'package:flutter/material.dart';

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_uk.dart';

export 'app_language.dart';

abstract class AppLocalizations {
  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('ru'),
    Locale('uk'),
    Locale('en'),
  ];

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static AppLocalizations forLocale(Locale locale) {
    switch (locale.languageCode) {
      case 'ru':
        return AppLocalizationsRu();
      case 'uk':
        return AppLocalizationsUk();
      case 'en':
        return AppLocalizationsEn();
      default:
        return AppLocalizationsRu();
    }
  }

  // Settings
  String get settingsTitle;
  String get interfaceSettingsTitle;
  String get tunnelSettingsTitle;
  String get languageTitle;
  String get themeTitle;
  String get themeDark;
  String get themeLight;
  String get dnsViaTunnelTitle;
  String get dnsViaTunnelOnSubtitle;
  String get dnsViaTunnelOffSubtitle;
  String get dnsReconnectHint;

  // Home
  String get appTitle;
  String get tooltipSettings;
  String get tooltipImportFile;
  String get tooltipShare;
  String get tooltipAddConfig;
  String get addConfigTitle;
  String get addManualTitle;
  String get addManualSubtitle;
  String get addQrTitle;
  String get addQrSubtitle;
  String get addClipboardTitle;
  String get addClipboardSubtitle;
  String get clipboardEmpty;
  String get fileReadError;
  String get fileEmpty;
  String importedCount(int count);
  String importedProfile(String name);
  String importError(Object error);
  String get importFormatError;
  String profileDeleted(String name);
  String get noActiveConfig;
  String switchingTo(String name);
  String connectingTo(String name);
  String get deleteConfigTitle;
  String get deleteConfigBody;
  String get cancel;
  String get delete;
  String get noVlessConfigs;
  String get noAwgConfigs;
  String get swipeToAwg;
  String get swipeToVless;
  String get tapPlusToAdd;
  String get selectConfig;
  String get connectFailed;
  String get qrScannerMobileOnly;
  String get awgPlatformUnsupported;
  String awgConnectTimeout(String? detail);
  String get vlessTunnelNotEstablished;
  String get vlessTunnelLogcatHint;
  String get xrayNativePrefix;
  String get connected;
  String get connecting;
  String get error;
  String get disconnected;
  String get edit;
  String get remove;
  String formatBytes(int bytes);

  // Manual / forms
  String get newConfig;
  String get save;
  String get saveConfig;
  String get editConfig;
  String get configAdded;
  String get configSaved;
  String get importFromUri;
  String get fillFromUri;
  String get basicParams;
  String get nameLabel;
  String get nameRequired;
  String get hostLabel;
  String get hostRequired;
  String get portLabel;
  String get portInvalid;
  String get uuidLabel;
  String get uuidRequired;
  String get securityTransport;
  String get securityLabel;
  String get transportLabel;
  String get advancedParams;
  String get descriptionLabel;
  String uriError(Object error);

  // Amnezia form
  String get editAwg;
  String get newAwg;
  String get pasteConfTitle;
  String get pasteConfHint;
  String get pasteFromClipboard;
  String get params;
  String get confLabel;
  String get confRequired;
  String get confInvalid;
  String get awgConfHelper;

  // QR
  String get scanQrTitle;
  String get scanQrHint;
  String get cameraPermissionHint;
  String get cameraOpenFailed;
  String get allowAccess;
  String get retry;
  String get openAppSettings;
  String get flashlight;
  String get switchCamera;

  // Tray
  String get trayShow;
  String get trayQuit;

  // Subscription
  String get addSubscriptionTitle;
  String get addSubscriptionHint;
  String get addSubscriptionAction;
  String get subscriptionUrlLabel;
  String get subscriptionUrlHint;
  String get subscriptionUrlRequired;
  String get subscriptionInvalidUrl;
  String get subscriptionAdded;
  String subscriptionAddFailed(Object error);
  String get subscriptionRefresh;
  String get subscriptionRefreshed;
  String subscriptionRefreshFailed(Object error);
  String get subscriptionPingAll;
  String get subscriptionPingNa;
  String subscriptionPingMs(int ms);
  String subscriptionAutoUpdate(int hours);
  String subscriptionExpires(String date);
  String get subscriptionUnlimited;
  String get subscriptionManualSection;
  String get subscriptionEmptyTitle;
  String get subscriptionEmptyHint;
  String get subscriptionRemove;
  String get subscriptionRemoveBody;
  String get subscriptionRemoved;
  String get addSubscriptionMenuTitle;
  String get addSubscriptionMenuSubtitle;
  String get addFileTitle;
  String get addFileSubtitle;
  String get subscriptionMenuRefresh;
  String get subscriptionMenuPing;
  String get subscriptionMenuEdit;
  String get subscriptionMenuPin;
  String get subscriptionMenuUnpin;
  String get subscriptionEditTitle;
  String get subscriptionEditOptions;
  String get subscriptionOptHideServers;
  String get subscriptionOptEncrypted;
  String get subscriptionOptAllowInsecure;
  String get subscriptionOptSendHwid;
  String get subscriptionEditHeaderUrl;
  String get subscriptionEditNameLabel;
  String get subscriptionEditNameRequired;
  String get subscriptionSave;
  String get subscriptionSaved;
  String subscriptionSaveFailed(Object error);

  // Routing
  String get routingTitle;
  String get routingDisabled;
  String get routingUseSection;
  String get routingEnable;
  String get routingUserAgent;
  String get routingHint;
  String get routingProfilesSection;
  String get routingProfilesEmpty;
  String get routingEditActive;
  String get routingRulesTitle;
  String get routingProfileMissing;
  String get routingProfileNameLabel;
  String get routingGeoSection;
  String get routingGeositeFile;
  String get routingGeoipFile;
  String get routingGeoNotDownloaded;
  String routingGeoUpdated(String date, String size);
  String get routingDomainSection;
  String get routingFakeDns;
  String get routingDomainStrategy;
  String get routingRemoteDnsSection;
  String get routingDomesticDnsSection;
  String get routingRemoteDnsType;
  String get routingDomesticDnsType;
  String get routingRemoteIp;
  String get routingDomesticIp;
  String get routingDnsDomain;
  String get routingProxySection;
  String get routingGlobalProxy;
  String get routingGlobalProxyHint;
  String get routingRulesSection;
  String get routingProxyRules;
  String get routingDirectRules;
  String get routingBlockRules;
  String get routingOrderSection;
  String get routingOrderLabel;
  String get routingOrderBlock;
  String get routingOrderDirect;
  String get routingOrderProxy;
  String get routingDeleteProfile;
  String get routingDeleteProfileBody;
  String get routingSaveUpper;
  String get routingRulesEditorHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'ru' ||
      locale.languageCode == 'uk' ||
      locale.languageCode == 'en';

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations.forLocale(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
