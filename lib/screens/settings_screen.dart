import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_language.dart';
import '../l10n/app_localizations.dart';
import '../models/stored_vpn_profile.dart';
import '../notifiers/app_settings_notifier.dart';
import '../notifiers/profile_notifier.dart';
import '../notifiers/routing_notifier.dart';
import '../notifiers/vpn_notifier.dart';
import '../theme/app_theme.dart';
import '../widgets/app_dropdown_field.dart';
import 'routing_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsNotifier>();
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.settingsTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsSection(
            title: l10n.interfaceSettingsTitle,
            children: [
              AppDropdownField<AppLanguage>(
                label: l10n.languageTitle,
                prefixIcon: Icons.translate_rounded,
                value: settings.language,
                items: [
                  for (final lang in AppLanguage.values)
                    AppDropdownItem(
                      value: lang,
                      label: lang.nativeLabel,
                      leading: Icon(
                        lang == AppLanguage.en
                            ? Icons.language_outlined
                            : Icons.flag_circle_outlined,
                        size: 22,
                        color: theme.colorScheme.onSurface.withOpacity(0.65),
                      ),
                    ),
                ],
                onChanged: settings.setLanguage,
              ),
              const SizedBox(height: 16),
              AppDropdownField<AppTheme>(
                label: l10n.themeTitle,
                prefixIcon: Icons.palette_outlined,
                value: settings.appTheme,
                items: [
                  AppDropdownItem(
                    value: AppTheme.dark,
                    label: l10n.themeDark,
                    leading: Icon(
                      Icons.dark_mode_rounded,
                      size: 22,
                      color: theme.colorScheme.onSurface.withOpacity(0.65),
                    ),
                  ),
                  AppDropdownItem(
                    value: AppTheme.light,
                    label: l10n.themeLight,
                    leading: Icon(
                      Icons.light_mode_rounded,
                      size: 22,
                      color: theme.colorScheme.onSurface.withOpacity(0.65),
                    ),
                  ),
                ],
                onChanged: settings.setAppTheme,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SettingsSection(
            title: l10n.tunnelSettingsTitle,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.alt_route_rounded,
                  color: theme.colorScheme.primary,
                ),
                title: Text(l10n.routingTitle),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.watch<RoutingNotifier>().activeProfile?.name ??
                          l10n.routingDisabled,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.65),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const RoutingSettingsScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 20),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(
                  Icons.dns_rounded,
                  color: theme.colorScheme.primary,
                ),
                title: Text(l10n.dnsViaTunnelTitle),
                subtitle: Text(
                  settings.dnsViaTunnel
                      ? l10n.dnsViaTunnelOnSubtitle
                      : l10n.dnsViaTunnelOffSubtitle,
                  style: theme.textTheme.bodySmall,
                ),
                value: settings.dnsViaTunnel,
                onChanged: (v) =>
                    _applyTunnelAndMaybeReconnect(context, settings, v),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.dnsReconnectHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Future<void> _applyTunnelAndMaybeReconnect(
    BuildContext context,
    AppSettingsNotifier settings,
    bool value,
  ) async {
    final vpn = context.read<VpnNotifier>();
    final profiles = context.read<ProfileNotifier>();
    final active = profiles.activeProfile;

    await settings.setDnsViaTunnel(value);
    if (!context.mounted) return;

    if (active is VlessStoredVpnProfile &&
        (vpn.status == VpnStatus.connected ||
            vpn.status == VpnStatus.connecting)) {
      await vpn.disconnect();
      if (!context.mounted) return;
      await vpn.connect(active);
    }
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface.withOpacity(0.72),
              letterSpacing: 0.2,
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}
