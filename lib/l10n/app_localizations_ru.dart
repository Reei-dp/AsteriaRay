import 'app_localizations.dart';

final class AppLocalizationsRu extends AppLocalizations {
  @override
  String get settingsTitle => 'Настройки';

  @override
  String get interfaceSettingsTitle => 'Настройка интерфейса';

  @override
  String get tunnelSettingsTitle => 'Настройки тунеля';

  @override
  String get languageTitle => 'Язык';

  @override
  String get themeTitle => 'Тема';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get themeLight => 'Светлая';

  @override
  String get dnsViaTunnelTitle => 'DNS через VPS (туннель)';

  @override
  String get dnsViaTunnelOnSubtitle =>
      'DNS идёт через тот же зашифрованный канал до VPS (VLESS), что и остальной трафик.';

  @override
  String get dnsViaTunnelOffSubtitle =>
      'Публичный DoH к Cloudflare (1.1.1.1), отдельный HTTPS в обход туннеля до VPS.';

  @override
  String get dnsReconnectHint =>
      'Если VPN уже подключён, конфиг перезапускается автоматически.';

  @override
  String get appTitle => 'Asteria 🚀';

  @override
  String get tooltipSettings => 'Настройки';

  @override
  String get tooltipImportFile => 'Импорт из файла';

  @override
  String get tooltipShare => 'Экспорт/шаринг';

  @override
  String get tooltipAddConfig => 'Добавить конфиг';

  @override
  String get addConfigTitle => 'Добавить конфиг';

  @override
  String get addManualTitle => 'Вручную';

  @override
  String get addManualSubtitle => 'VLESS или AmneziaWG — свайп на экране';

  @override
  String get addQrTitle => 'Сканировать QR-код';

  @override
  String get addQrSubtitle => 'vless:// или AmneziaWG .conf';

  @override
  String get addClipboardTitle => 'Из буфера обмена';

  @override
  String get addClipboardSubtitle => 'Вставить ссылку или .conf';

  @override
  String get clipboardEmpty => 'Буфер обмена пуст';

  @override
  String get fileReadError => 'Не удалось прочитать файл';

  @override
  String get fileEmpty => 'Файл пуст';

  @override
  String importedCount(int count) => 'Импортировано: $count';

  @override
  String importedProfile(String name) => 'Импортировано: $name';

  @override
  String importError(Object error) => 'Ошибка импорта: $error';

  @override
  String get importFormatError =>
      'Не удалось распознать формат. Ожидается vless:// или WireGuard .conf';

  @override
  String profileDeleted(String name) => '«$name» удалён';

  @override
  String get noActiveConfig => 'Нет активного конфига';

  @override
  String switchingTo(String name) => 'Переключение на $name...';

  @override
  String connectingTo(String name) => 'Подключение к $name...';

  @override
  String get deleteConfigTitle => 'Удалить конфиг?';

  @override
  String get deleteConfigBody => 'Профиль будет удалён с этого устройства.';

  @override
  String get cancel => 'Отмена';

  @override
  String get delete => 'Удалить';

  @override
  String get noVlessConfigs => 'Нет VLESS конфигов';

  @override
  String get noAwgConfigs => 'Нет AmneziaWG конфигов';

  @override
  String get swipeToAwg => 'Свайп вправо → AmneziaWG';

  @override
  String get swipeToVless => 'Свайп влево ← VLESS';

  @override
  String get tapPlusToAdd => 'Нажмите + чтобы добавить';

  @override
  String get selectConfig => 'Выберите конфиг';

  @override
  String get connectFailed => 'Не удалось подключиться';

  @override
  String get qrScannerMobileOnly =>
      'QR-сканер доступен на Android и iOS';

  @override
  String get awgPlatformUnsupported =>
      'AmneziaWG поддерживается только на Android, Linux и Windows';

  @override
  String awgConnectTimeout(String? detail) {
    final d = (detail != null && detail.isNotEmpty) ? ' $detail' : '';
    return 'Таймаут подключения AmneziaWG (3 мин). '
        'Часто: awg setconf ждёт UAPI, или DNS при полном туннеле.$d';
  }

  @override
  String get vlessTunnelNotEstablished =>
      'Интерфейс VPN не создан (нет ключа в статус-баре).';

  @override
  String get vlessTunnelLogcatHint =>
      ' В logcat: процесс :xrayvpn, тег LibxrayVpnService — '
      '«Failed to establish VPN», «VPN permission not granted» или ошибка старта Xray.';

  @override
  String get xrayNativePrefix => 'Xray: ';

  @override
  String get connected => 'Подключено';

  @override
  String get connecting => 'Подключение…';

  @override
  String get error => 'Ошибка';

  @override
  String get disconnected => 'Отключено';

  @override
  String get edit => 'Редактировать';

  @override
  String get remove => 'Удалить';

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
  String get newConfig => 'Новый конфиг';

  @override
  String get save => 'Сохранить';

  @override
  String get saveConfig => 'Сохранить конфиг';

  @override
  String get editConfig => 'Редактировать';

  @override
  String get configAdded => 'Конфиг добавлен';

  @override
  String get configSaved => 'Конфиг сохранён';

  @override
  String get importFromUri => 'Импорт из URI';

  @override
  String get fillFromUri => 'Заполнить из URI';

  @override
  String get basicParams => 'Основные параметры';

  @override
  String get nameLabel => 'Название';

  @override
  String get nameRequired => 'Введите название';

  @override
  String get hostLabel => 'Хост';

  @override
  String get hostRequired => 'Хост обязателен';

  @override
  String get portLabel => 'Порт';

  @override
  String get portInvalid => 'Неверный порт';

  @override
  String get uuidLabel => 'UUID';

  @override
  String get uuidRequired => 'UUID обязателен';

  @override
  String get securityTransport => 'Безопасность и транспорт';

  @override
  String get securityLabel => 'Безопасность';

  @override
  String get transportLabel => 'Транспорт';

  @override
  String get advancedParams => 'Дополнительные параметры';

  @override
  String get descriptionLabel => 'Описание';

  @override
  String uriError(Object error) => 'Ошибка URI: $error';

  @override
  String get editAwg => 'Редактировать AmneziaWG';

  @override
  String get newAwg => 'Новый AmneziaWG';

  @override
  String get pasteConfTitle => 'Вставить .conf';

  @override
  String get pasteConfHint =>
      'Скопируйте конфиг из AmneziaVPN или вставьте экспортированный .conf';

  @override
  String get pasteFromClipboard => 'Вставить из буфера';

  @override
  String get params => 'Параметры';

  @override
  String get confLabel => 'Конфиг (.conf)';

  @override
  String get confRequired => 'Вставьте .conf';

  @override
  String get confInvalid =>
      'Нужен WireGuard/AmneziaWG .conf с [Interface] и [Peer]';

  @override
  String get awgConfHelper =>
      '[Interface] + [Peer], Amnezia-параметры (Jc, S1…) сохраняются как есть';

  @override
  String get scanQrTitle => 'Сканировать QR-код';

  @override
  String get scanQrHint =>
      'Наведите камеру на QR с vless:// или AmneziaWG .conf';

  @override
  String get cameraPermissionHint =>
      'Разрешите доступ к камере, чтобы сканировать QR-код';

  @override
  String get cameraOpenFailed => 'Не удалось открыть камеру';

  @override
  String get allowAccess => 'Разрешить доступ';

  @override
  String get retry => 'Повторить';

  @override
  String get openAppSettings => 'Открыть настройки приложения';

  @override
  String get flashlight => 'Фонарик';

  @override
  String get switchCamera => 'Переключить камеру';

  @override
  String get trayShow => 'Показать AsteriaRay';

  @override
  String get trayQuit => 'Выход';

  @override
  String get addSubscriptionTitle => 'Подписка VLESS';

  @override
  String get addSubscriptionHint =>
      'Вставьте ссылку вида https://…/api/sub/… — как в Happ или из бота Asteria.';

  @override
  String get addSubscriptionAction => 'Добавить подписку';

  @override
  String get subscriptionUrlLabel => 'URL подписки';

  @override
  String get subscriptionUrlHint => 'https://sub.asteriamirror.cloud/api/sub/…';

  @override
  String get subscriptionUrlRequired => 'Введите URL';

  @override
  String get subscriptionInvalidUrl => 'Некорректный URL подписки';

  @override
  String get subscriptionAdded => 'Подписка добавлена';

  @override
  String subscriptionAddFailed(Object error) => 'Ошибка: $error';

  @override
  String get subscriptionRefresh => 'Обновить';

  @override
  String get subscriptionRefreshed => 'Подписка обновлена';

  @override
  String subscriptionRefreshFailed(Object error) => 'Не удалось обновить: $error';

  @override
  String get subscriptionPingAll => 'Проверить пинг';

  @override
  String get subscriptionPingNa => 'н/д';

  @override
  String subscriptionPingMs(int ms) => '${ms}мс';

  @override
  String subscriptionAutoUpdate(int hours) => 'Авто · $hours ч';

  @override
  String subscriptionExpires(String date) => 'Истекает: $date';

  @override
  String get subscriptionUnlimited => '∞';

  @override
  String get subscriptionManualSection => 'Ручные конфиги';

  @override
  String get subscriptionEmptyTitle => 'Нет подписки VLESS';

  @override
  String get subscriptionEmptyHint =>
      'Нажмите + → «Из буфера обмена» и вставьте ссылку подписки.';

  @override
  String get subscriptionRemove => 'Удалить подписку';

  @override
  String get subscriptionRemoveBody =>
      'Удалятся все серверы из этой подписки на устройстве.';

  @override
  String get subscriptionRemoved => 'Подписка удалена';

  @override
  String get addSubscriptionMenuTitle => 'Подписка';

  @override
  String get addSubscriptionMenuSubtitle => 'VLESS по ссылке (Happ / Asteria)';

  @override
  String get addFileTitle => 'Из файла';

  @override
  String get addFileSubtitle => 'vless://, .conf или список ссылок';

  @override
  String get subscriptionMenuRefresh => 'Обновить подписку';

  @override
  String get subscriptionMenuPing => 'Пинг';

  @override
  String get subscriptionMenuEdit => 'Редактировать';

  @override
  String get subscriptionMenuPin => 'Закрепить';

  @override
  String get subscriptionMenuUnpin => 'Открепить';

  @override
  String get subscriptionEditTitle => 'Редактирование подписки';

  @override
  String get subscriptionEditOptions => 'Опции';

  @override
  String get subscriptionOptHideServers => 'Скрывать настройки серверов';

  @override
  String get subscriptionOptEncrypted => 'Зашифрованная подписка';

  @override
  String get subscriptionOptAllowInsecure => 'Разрешать небезопасные';

  @override
  String get subscriptionOptSendHwid => 'Отправлять HWID в Cookie';

  @override
  String get subscriptionEditHeaderUrl => 'Заголовок и URL';

  @override
  String get subscriptionEditNameLabel => 'Название';

  @override
  String get subscriptionEditNameRequired => 'Введите название';

  @override
  String get subscriptionSave => 'Сохранить';

  @override
  String get subscriptionSaved => 'Подписка сохранена';

  @override
  String subscriptionSaveFailed(Object error) => 'Не удалось сохранить: $error';

  @override
  String get routingTitle => 'Маршрутизация';

  @override
  String get routingDisabled => 'Выкл.';

  @override
  String get routingUseSection => 'Использовать маршрутизацию';

  @override
  String get routingEnable => 'Включить маршрутизацию';

  @override
  String get routingUserAgent => 'User-Agent';

  @override
  String get routingHint =>
      'Правила маршрутизации управляют трафиком: Proxy, Direct и Block. Профиль может приходить с подпиской.';

  @override
  String get routingProfilesSection => 'Профили';

  @override
  String get routingProfilesEmpty => 'Обновите подписку — профиль маршрутизации подтянется автоматически.';

  @override
  String get routingEditActive => 'Правила активного профиля';

  @override
  String get routingRulesTitle => 'Правила маршрутизации';

  @override
  String get routingProfileMissing => 'Профиль не найден';

  @override
  String get routingProfileNameLabel => 'Заголовок';

  @override
  String get routingGeoSection => 'Гео файлы';

  @override
  String get routingGeositeFile => 'Файл Гео-сайтов';

  @override
  String get routingGeoipFile => 'Файл Гео-айпи';

  @override
  String get routingGeoNotDownloaded => 'Не загружен';

  @override
  String routingGeoUpdated(String date, String size) =>
      'Последнее обновление: $date, размер: $size';

  @override
  String get routingDomainSection => 'Настройки доменов';

  @override
  String get routingFakeDns => 'Использовать поддельную DNS';

  @override
  String get routingDomainStrategy => 'Настройки доменов';

  @override
  String get routingRemoteDnsSection => 'Удалённый DNS';

  @override
  String get routingDomesticDnsSection => 'Домашний DNS';

  @override
  String get routingRemoteDnsType => 'Тип удалённого DNS';

  @override
  String get routingDomesticDnsType => 'Тип домашнего DNS';

  @override
  String get routingRemoteIp => 'Удалённый IP';

  @override
  String get routingDomesticIp => 'Домашний IP';

  @override
  String get routingDnsDomain => 'DoH URL';

  @override
  String get routingProxySection => 'Настройки прокси';

  @override
  String get routingGlobalProxy => 'Глобальный прокси';

  @override
  String get routingGlobalProxyHint =>
      'Если выключено — весь трафик идёт напрямую, кроме правил маршрута.';

  @override
  String get routingRulesSection => 'Настройки маршрутизации';

  @override
  String get routingProxyRules => 'Прокси';

  @override
  String get routingDirectRules => 'Напрямую';

  @override
  String get routingBlockRules => 'Заблокировать';

  @override
  String get routingOrderSection => 'Порядок маршрутизации';

  @override
  String get routingOrderLabel => 'Порядок';

  @override
  String get routingOrderBlock => 'block';

  @override
  String get routingOrderDirect => 'direct';

  @override
  String get routingOrderProxy => 'proxy';

  @override
  String get routingDeleteProfile => 'Удалить конфигурацию';

  @override
  String get routingDeleteProfileBody => 'Профиль маршрутизации будет удалён с устройства.';

  @override
  String get routingSaveUpper => 'СОХРАНИТЬ';

  @override
  String get routingRulesEditorHint => 'По одному правилу на строку: geosite:ru, geoip:private, domain:example.com';
}
