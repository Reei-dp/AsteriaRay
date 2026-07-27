import 'app_localizations.dart';

final class AppLocalizationsUk extends AppLocalizations {
  @override
  String get settingsTitle => 'Налаштування';

  @override
  String get interfaceSettingsTitle => 'Налаштування інтерфейсу';

  @override
  String get tunnelSettingsTitle => 'Налаштування тунелю';

  @override
  String get languageTitle => 'Мова';

  @override
  String get themeTitle => 'Тема';

  @override
  String get themeDark => 'Темна';

  @override
  String get themeLight => 'Світла';

  @override
  String get dnsViaTunnelTitle => 'DNS через VPS (тунель)';

  @override
  String get dnsViaTunnelOnSubtitle =>
      'DNS йде тим самим зашифрованим каналом до VPS (VLESS), що й інший трафік.';

  @override
  String get dnsViaTunnelOffSubtitle =>
      'Публічний DoH до Cloudflare (1.1.1.1), окремий HTTPS повз тунель до VPS.';

  @override
  String get dnsReconnectHint =>
      'Якщо VPN уже підключено, конфіг перезапуститься автоматично.';

  @override
  String get appTitle => 'Asteria 🚀';

  @override
  String get tooltipSettings => 'Налаштування';

  @override
  String get tooltipImportFile => 'Імпорт з файлу';

  @override
  String get tooltipShare => 'Експорт / поширення';

  @override
  String get tooltipAddConfig => 'Додати конфіг';

  @override
  String get addConfigTitle => 'Додати конфіг';

  @override
  String get addManualTitle => 'Вручну';

  @override
  String get addManualSubtitle => 'VLESS або AmneziaWG — свайп на екрані';

  @override
  String get addQrTitle => 'Сканувати QR-код';

  @override
  String get addQrSubtitle => 'vless:// або AmneziaWG .conf';

  @override
  String get addClipboardTitle => 'З буфера обміну';

  @override
  String get addClipboardSubtitle => 'Вставити посилання або .conf';

  @override
  String get clipboardEmpty => 'Буфер обміну порожній';

  @override
  String get fileReadError => 'Не вдалося прочитати файл';

  @override
  String get fileEmpty => 'Файл порожній';

  @override
  String importedCount(int count) => 'Імпортовано: $count';

  @override
  String importedProfile(String name) => 'Імпортовано: $name';

  @override
  String importError(Object error) => 'Помилка імпорту: $error';

  @override
  String get importFormatError =>
      'Не вдалося розпізнати формат. Очікується vless:// або WireGuard .conf';

  @override
  String profileDeleted(String name) => '«$name» видалено';

  @override
  String get noActiveConfig => 'Немає активного конфігу';

  @override
  String switchingTo(String name) => 'Перемикання на $name...';

  @override
  String connectingTo(String name) => 'Підключення до $name...';

  @override
  String get deleteConfigTitle => 'Видалити конфіг?';

  @override
  String get deleteConfigBody => 'Профіль буде видалено з цього пристрою.';

  @override
  String get cancel => 'Скасувати';

  @override
  String get delete => 'Видалити';

  @override
  String get noVlessConfigs => 'Немає VLESS конфігів';

  @override
  String get noAwgConfigs => 'Немає AmneziaWG конфігів';

  @override
  String get swipeToAwg => 'Свайп праворуч → AmneziaWG';

  @override
  String get swipeToVless => 'Свайп ліворуч ← VLESS';

  @override
  String get tapPlusToAdd => 'Натисніть +, щоб додати';

  @override
  String get selectConfig => 'Оберіть конфіг';

  @override
  String get connectFailed => 'Не вдалося підключитися';

  @override
  String get qrScannerMobileOnly =>
      'QR-сканер доступний на Android та iOS';

  @override
  String get awgPlatformUnsupported =>
      'AmneziaWG підтримується лише на Android, Linux і Windows';

  @override
  String awgConnectTimeout(String? detail) {
    final d = (detail != null && detail.isNotEmpty) ? ' $detail' : '';
    return 'Таймаут підключення AmneziaWG (3 хв). '
        'Часто: awg setconf чекає UAPI, або DNS при повному тунелі.$d';
  }

  @override
  String get vlessTunnelNotEstablished =>
      'Інтерфейс VPN не створено (немає ключа в рядку стану).';

  @override
  String get vlessTunnelLogcatHint =>
      ' У logcat: процес :xrayvpn, тег LibxrayVpnService — '
      '«Failed to establish VPN», «VPN permission not granted» або помилка старту Xray.';

  @override
  String get xrayNativePrefix => 'Xray: ';

  @override
  String get connected => 'Підключено';

  @override
  String get connecting => 'Підключення…';

  @override
  String get error => 'Помилка';

  @override
  String get disconnected => 'Відключено';

  @override
  String get edit => 'Редагувати';

  @override
  String get remove => 'Видалити';

  @override
  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes Б';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} КБ';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} МБ';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} ГБ';
  }

  @override
  String get newConfig => 'Новий конфіг';

  @override
  String get save => 'Зберегти';

  @override
  String get saveConfig => 'Зберегти конфіг';

  @override
  String get editConfig => 'Редагувати';

  @override
  String get configAdded => 'Конфіг додано';

  @override
  String get configSaved => 'Конфіг збережено';

  @override
  String get importFromUri => 'Імпорт з URI';

  @override
  String get fillFromUri => 'Заповнити з URI';

  @override
  String get basicParams => 'Основні параметри';

  @override
  String get nameLabel => 'Назва';

  @override
  String get nameRequired => 'Введіть назву';

  @override
  String get hostLabel => 'Хост';

  @override
  String get hostRequired => 'Хост обов\'язковий';

  @override
  String get portLabel => 'Порт';

  @override
  String get portInvalid => 'Невірний порт';

  @override
  String get uuidLabel => 'UUID';

  @override
  String get uuidRequired => 'UUID обов\'язковий';

  @override
  String get securityTransport => 'Безпека та транспорт';

  @override
  String get securityLabel => 'Безпека';

  @override
  String get transportLabel => 'Транспорт';

  @override
  String get advancedParams => 'Додаткові параметри';

  @override
  String get descriptionLabel => 'Опис';

  @override
  String uriError(Object error) => 'Помилка URI: $error';

  @override
  String get editAwg => 'Редагувати AmneziaWG';

  @override
  String get newAwg => 'Новий AmneziaWG';

  @override
  String get pasteConfTitle => 'Вставити .conf';

  @override
  String get pasteConfHint =>
      'Скопіюйте конфіг з AmneziaVPN або вставте експортований .conf';

  @override
  String get pasteFromClipboard => 'Вставити з буфера';

  @override
  String get params => 'Параметри';

  @override
  String get confLabel => 'Конфіг (.conf)';

  @override
  String get confRequired => 'Вставте .conf';

  @override
  String get confInvalid =>
      'Потрібен WireGuard/AmneziaWG .conf з [Interface] та [Peer]';

  @override
  String get awgConfHelper =>
      '[Interface] + [Peer]; параметри Amnezia (Jc, S1…) зберігаються як є';

  @override
  String get scanQrTitle => 'Сканувати QR-код';

  @override
  String get scanQrHint =>
      'Наведіть камеру на QR з vless:// або AmneziaWG .conf';

  @override
  String get cameraPermissionHint =>
      'Дозвольте доступ до камери, щоб сканувати QR-код';

  @override
  String get cameraOpenFailed => 'Не вдалося відкрити камеру';

  @override
  String get allowAccess => 'Дозволити доступ';

  @override
  String get retry => 'Повторити';

  @override
  String get openAppSettings => 'Відкрити налаштування застосунку';

  @override
  String get flashlight => 'Ліхтарик';

  @override
  String get switchCamera => 'Перемкнути камеру';

  @override
  String get trayShow => 'Показати AsteriaRay';

  @override
  String get trayQuit => 'Вихід';

  @override
  String get addSubscriptionTitle => 'VLESS підписка';

  @override
  String get addSubscriptionHint =>
      'Вставте посилання виду https://…/api/sub/… — як у Happ або з бота Asteria.';

  @override
  String get addSubscriptionAction => 'Додати підписку';

  @override
  String get subscriptionUrlLabel => 'URL підписки';

  @override
  String get subscriptionUrlHint => 'https://sub.asteriamirror.cloud/api/sub/…';

  @override
  String get subscriptionUrlRequired => 'Введіть URL';

  @override
  String get subscriptionInvalidUrl => 'Некоректний URL підписки';

  @override
  String get subscriptionAdded => 'Підписку додано';

  @override
  String subscriptionAddFailed(Object error) => 'Помилка: $error';

  @override
  String get subscriptionRefresh => 'Оновити';

  @override
  String get subscriptionRefreshed => 'Підписку оновлено';

  @override
  String subscriptionRefreshFailed(Object error) => 'Не вдалося оновити: $error';

  @override
  String get subscriptionPingAll => 'Перевірити пінг';

  @override
  String get subscriptionPingNa => 'н/д';

  @override
  String subscriptionPingMs(int ms) => '${ms}мс';

  @override
  String subscriptionAutoUpdate(int hours) => 'Авто · $hours год';

  @override
  String subscriptionExpires(String date) => 'Закінчується: $date';

  @override
  String get subscriptionUnlimited => '∞';

  @override
  String get subscriptionManualSection => 'Ручні конфіги';

  @override
  String get subscriptionEmptyTitle => 'Немає VLESS підписки';

  @override
  String get subscriptionEmptyHint =>
      'Натисніть + → «З буфера обміну» і вставте посилання підписки.';

  @override
  String get subscriptionRemove => 'Видалити підписку';

  @override
  String get subscriptionRemoveBody =>
      'Усі сервери з цієї підписки будуть видалені з пристрою.';

  @override
  String get subscriptionRemoved => 'Підписку видалено';

  @override
  String get addSubscriptionMenuTitle => 'Підписка';

  @override
  String get addSubscriptionMenuSubtitle => 'VLESS за посиланням (Happ / Asteria)';

  @override
  String get addFileTitle => 'З файлу';

  @override
  String get addFileSubtitle => 'vless://, .conf або список посилань';

  @override
  String get subscriptionMenuRefresh => 'Оновити підписку';

  @override
  String get subscriptionMenuPing => 'Пінг';

  @override
  String get subscriptionMenuEdit => 'Редагувати';

  @override
  String get subscriptionMenuPin => 'Закріпити';

  @override
  String get subscriptionMenuUnpin => 'Відкріпити';

  @override
  String get subscriptionEditTitle => 'Редагування підписки';

  @override
  String get subscriptionEditOptions => 'Опції';

  @override
  String get subscriptionOptHideServers => 'Приховувати налаштування серверів';

  @override
  String get subscriptionOptEncrypted => 'Зашифрована підписка';

  @override
  String get subscriptionOptAllowInsecure => 'Дозволяти небезпечні';

  @override
  String get subscriptionOptSendHwid => 'Надсилати HWID у Cookie';

  @override
  String get subscriptionEditHeaderUrl => 'Заголовок і URL';

  @override
  String get subscriptionEditNameLabel => 'Назва';

  @override
  String get subscriptionEditNameRequired => 'Введіть назву';

  @override
  String get subscriptionSave => 'Зберегти';

  @override
  String get subscriptionSaved => 'Підписку збережено';

  @override
  String subscriptionSaveFailed(Object error) => 'Не вдалося зберегти: $error';

  @override
  String get routingTitle => 'Маршрутизація';

  @override
  String get routingDisabled => 'Вимк.';

  @override
  String get routingUseSection => 'Використовувати маршрутизацію';

  @override
  String get routingEnable => 'Увімкнути маршрутизацію';

  @override
  String get routingUserAgent => 'User-Agent';

  @override
  String get routingHint =>
      'Правила маршрутизації керують трафіком: Proxy, Direct і Block. Профіль може приходити з підпискою.';

  @override
  String get routingProfilesSection => 'Профілі';

  @override
  String get routingProfilesEmpty => 'Оновіть підписку — профіль маршрутизації підтягнеться автоматично.';

  @override
  String get routingEditActive => 'Правила активного профілю';

  @override
  String get routingRulesTitle => 'Правила маршрутизації';

  @override
  String get routingProfileMissing => 'Профіль не знайдено';

  @override
  String get routingProfileNameLabel => 'Заголовок';

  @override
  String get routingGeoSection => 'Гео файли';

  @override
  String get routingGeositeFile => 'Файл Гео-сайтів';

  @override
  String get routingGeoipFile => 'Файл Гео-айпі';

  @override
  String get routingGeoNotDownloaded => 'Не завантажено';

  @override
  String routingGeoUpdated(String date, String size) =>
      'Останнє оновлення: $date, розмір: $size';

  @override
  String get routingDomainSection => 'Налаштування доменів';

  @override
  String get routingFakeDns => 'Використовувати підроблену DNS';

  @override
  String get routingDomainStrategy => 'Налаштування доменів';

  @override
  String get routingRemoteDnsSection => 'Віддалений DNS';

  @override
  String get routingDomesticDnsSection => 'Домашній DNS';

  @override
  String get routingRemoteDnsType => 'Тип віддаленого DNS';

  @override
  String get routingDomesticDnsType => 'Тип домашнього DNS';

  @override
  String get routingRemoteIp => 'Віддалений IP';

  @override
  String get routingDomesticIp => 'Домашній IP';

  @override
  String get routingDnsDomain => 'DoH URL';

  @override
  String get routingProxySection => 'Налаштування проксі';

  @override
  String get routingGlobalProxy => 'Глобальний проксі';

  @override
  String get routingGlobalProxyHint =>
      'Якщо вимкнено — весь трафік йде напряму, окрім правил маршруту.';

  @override
  String get routingRulesSection => 'Налаштування маршрутизації';

  @override
  String get routingProxyRules => 'Проксі';

  @override
  String get routingDirectRules => 'Напряму';

  @override
  String get routingBlockRules => 'Заблокувати';

  @override
  String get routingOrderSection => 'Порядок маршрутизації';

  @override
  String get routingOrderLabel => 'Порядок';

  @override
  String get routingOrderBlock => 'block';

  @override
  String get routingOrderDirect => 'direct';

  @override
  String get routingOrderProxy => 'proxy';

  @override
  String get routingDeleteProfile => 'Видалити конфігурацію';

  @override
  String get routingDeleteProfileBody => 'Профіль маршрутизації буде видалено з пристрою.';

  @override
  String get routingSaveUpper => 'ЗБЕРЕГТИ';

  @override
  String get routingRulesEditorHint => 'По одному правилу на рядок: geosite:ru, geoip:private, domain:example.com';
}
