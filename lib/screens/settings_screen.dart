import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/stored_vpn_profile.dart';
import '../notifiers/app_settings_notifier.dart';
import '../notifiers/profile_notifier.dart';
import '../notifiers/vpn_notifier.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsNotifier>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Настройки',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: SwitchListTile(
              secondary: Icon(
                Icons.dns_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('DNS через VPS (туннель)'),
              subtitle: Text(
                settings.dnsViaTunnel
                    ? 'DNS идёт через тот же зашифрованный канал до VPS (VLESS), что и остальной трафик.'
                    : 'Публичный DoH к Cloudflare (1.1.1.1), отдельный HTTPS в обход туннеля до VPS.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              value: settings.dnsViaTunnel,
              onChanged: (v) => _applyTunnelAndMaybeReconnect(context, settings, v),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Если VPN уже подключён, конфиг перезапускается автоматически.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
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
