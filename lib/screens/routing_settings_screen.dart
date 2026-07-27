import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/routing_profile.dart';
import '../notifiers/routing_notifier.dart';
import '../widgets/app_dropdown_field.dart';
import 'routing_profile_detail_screen.dart';

const _userAgents = [
  'chrome-android',
  'chrome-win',
  'safari-ios',
  'safari-mac',
  'firefox-win',
];

class RoutingSettingsScreen extends StatelessWidget {
  const RoutingSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final routing = context.watch<RoutingNotifier>();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final active = routing.activeProfile;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.routingTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(
            title: l10n.routingUseSection,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.routingEnable),
                value: routing.enabled,
                onChanged: routing.setEnabled,
              ),
              const SizedBox(height: 8),
              AppDropdownField<String>(
                label: l10n.routingUserAgent,
                value: routing.userAgent,
                items: [
                  for (final ua in _userAgents)
                    AppDropdownItem(value: ua, label: ua),
                ],
                onChanged: (v) {
                  if (v != null) routing.setUserAgent(v);
                },
              ),
              const SizedBox(height: 8),
              Text(
                l10n.routingHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _Section(
            title: l10n.routingProfilesSection,
            children: [
              if (routing.profiles.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    l10n.routingProfilesEmpty,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.55),
                    ),
                  ),
                )
              else
                for (final profile in routing.profiles)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Radio<String>(
                      value: profile.name,
                      groupValue: routing.activeProfileName,
                      onChanged: (v) {
                        if (v != null) routing.setActiveProfile(v);
                      },
                    ),
                    title: Text(profile.name),
                    trailing: IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              RoutingProfileDetailScreen(profileName: profile.name),
                        ),
                      ),
                    ),
                    onTap: () => routing.setActiveProfile(profile.name),
                  ),
            ],
          ),
          if (active != null) ...[
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.routingEditActive),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      RoutingProfileDetailScreen(profileName: active.name),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

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
              color: theme.colorScheme.primary.withOpacity(0.85),
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

String formatGeoFileMeta(DateTime? updated, int sizeBytes, AppLocalizations l10n) {
  if (updated == null && sizeBytes == 0) return l10n.routingGeoNotDownloaded;
  final date = updated != null ? DateFormat('dd.MM.yyyy HH:mm').format(updated) : '—';
  final mb = sizeBytes / (1024 * 1024);
  final size = mb >= 0.1 ? '${mb.toStringAsFixed(1)} MB' : '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
  return l10n.routingGeoUpdated(date, size);
}

extension RouteOrderL10n on RouteOrder {
  String labels(AppLocalizations l10n) =>
      displayLabel(l10n.routingOrderBlock, l10n.routingOrderDirect, l10n.routingOrderProxy);
}
