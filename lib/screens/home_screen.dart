import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/stored_vpn_profile.dart';
import '../models/vless_profile.dart';
import '../models/vpn_protocol.dart';
import '../services/config_import_detector.dart';
import '../notifiers/profile_notifier.dart';
import '../notifiers/vpn_notifier.dart';
import '../widgets/acrylic_toast.dart';
import 'profile_form_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profileNotifier = context.watch<ProfileNotifier>();
    final vpn = context.watch<VpnNotifier>();
    final profiles = profileNotifier.profiles;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Asteria 🚀',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        actions: [
          IconButton(
            tooltip: 'Настройки',
            icon: const Icon(Icons.settings_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Импорт из буфера',
            icon: const Icon(Icons.content_paste),
            onPressed: () => _importFromClipboard(context),
          ),
          IconButton(
            tooltip: 'Импорт из файла',
            icon: const Icon(Icons.file_open),
            onPressed: () => _importFromFile(context),
          ),
          IconButton(
            tooltip: 'Экспорт/шаринг',
            icon: const Icon(Icons.share),
            onPressed: () => _shareActive(context),
          ),
          IconButton(
            tooltip: 'Новый конфиг',
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _openEditor(context),
          ),
        ],
      ),
      body: profileNotifier.initialized
          ? Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                  child: profiles.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.vpn_key_rounded,
                                size: 64,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Конфиги не добавлены',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Нажмите кнопку ниже, чтобы добавить',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                                    ),
                              ),
                            ],
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          children: [
                            for (var i = 0; i < profiles.length; i++) ...[
                              if (i == 0 || profiles[i].protocol != profiles[i - 1].protocol)
                                Padding(
                                  padding: EdgeInsets.only(
                                    top: i == 0 ? 0 : 20,
                                    bottom: 10,
                                    left: 2,
                                    right: 2,
                                  ),
                                  child: _ProtocolSectionHeader(protocol: profiles[i].protocol),
                                ),
                              _ProfileCard(
                                profile: profiles[i],
                                isActive: profileNotifier.activeId == profiles[i].id,
                                onTap: () => _switchProfile(
                                  context,
                                  profiles[i],
                                  profileNotifier.activeId == profiles[i].id,
                                ),
                                onEdit: () {
                                  final p = profiles[i];
                                  if (p is VlessStoredVpnProfile) {
                                    _openEditor(context, profile: p.profile);
                                  } else {
                                    AcrylicToast.show(
                                      context,
                                      'Редактор AmneziaWG будет позже',
                                      icon: Icons.edit_outlined,
                                    );
                                  }
                                },
                                onDelete: () => _confirmDelete(context, profiles[i].id),
                              ),
                            ],
                          ],
                        ),
                    ),
                    _ConnectionBottomBar(
                      vpnStatus: vpn.status,
                      active: profileNotifier.activeProfile,
                      uploadBytes: vpn.uploadBytes,
                      downloadBytes: vpn.downloadBytes,
                      onStart: () => _startVpn(context),
                      onDisconnect: () => vpn.disconnect(),
                    ),
                  ],
                ),
                if (profileNotifier.activeProfile != null &&
                    vpn.status != VpnStatus.connected &&
                    vpn.status != VpnStatus.connecting)
                  Positioned(
                    bottom: 61,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Material(
                        elevation: 8,
                        shape: const CircleBorder(),
                        color: Colors.white,
                        child: InkWell(
                          onTap: () => _startVpn(context),
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                else if (vpn.status == VpnStatus.connected)
                  Positioned(
                    bottom: 61,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Material(
                        elevation: 8,
                        shape: const CircleBorder(),
                        color: Colors.white,
                        child: InkWell(
                          onTap: () => vpn.disconnect(),
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.stop_rounded,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Future<void> _importFromClipboard(BuildContext context) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!context.mounted) return;
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      AcrylicToast.show(context, 'Буфер обмена пуст', icon: Icons.content_paste_rounded);
      return;
    }
    await _importPayload(context, text);
  }

  Future<void> _importFromFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'conf', 'json'],
    );
    if (!context.mounted) return;
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final path = file.path;
    if (path == null) {
      AcrylicToast.show(context, 'Не удалось прочитать файл', icon: Icons.error_outline_rounded, isError: true);
      return;
    }
    final content = await File(path).readAsString();
    if (!context.mounted) return;
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      AcrylicToast.show(context, 'Файл пуст', icon: Icons.description_rounded);
      return;
    }
    if (ConfigImportDetector.detect(trimmed) == ConfigImportKind.wireGuardConf) {
      await _importPayload(context, trimmed);
      return;
    }
    final lines = content
        .split(RegExp(r'\r?\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    var imported = 0;
    for (final line in lines) {
      try {
        await _importUriLine(context, line, silent: true);
        imported++;
      } catch (_) {}
    }
    if (!context.mounted) return;
    AcrylicToast.show(context, 'Импортировано: $imported', icon: Icons.check_circle_rounded);
  }

  Future<void> _importPayload(BuildContext context, String text,
      {bool silent = false}) async {
    try {
      final profile =
          await context.read<ProfileNotifier>().importFromClipboard(text);
      if (!context.mounted) return;
      if (!silent) {
        AcrylicToast.show(context, 'Импортировано: ${profile.name}', icon: Icons.check_circle_rounded);
      }
    } catch (e) {
      if (!context.mounted) return;
      AcrylicToast.show(context, 'Ошибка импорта: $e', icon: Icons.error_outline_rounded, isError: true);
    }
  }

  /// One file line: VLESS URI only (multi-line `.conf` is handled in [_importFromFile]).
  Future<void> _importUriLine(BuildContext context, String uri,
      {bool silent = false}) async {
    try {
      final profile =
          await context.read<ProfileNotifier>().importUri(uri.trim());
      if (!context.mounted) return;
      if (!silent) {
        AcrylicToast.show(context, 'Импортировано: ${profile.name}', icon: Icons.check_circle_rounded);
      }
    } catch (e) {
      if (!context.mounted) return;
      AcrylicToast.show(context, 'Ошибка импорта: $e', icon: Icons.error_outline_rounded, isError: true);
    }
  }

  Future<void> _shareActive(BuildContext context) async {
    final active = context.read<ProfileNotifier>().activeProfile;
    if (active == null) {
      AcrylicToast.show(context, 'Нет активного конфига', icon: Icons.vpn_key_rounded);
      return;
    }
    switch (active) {
      case VlessStoredVpnProfile(:final profile):
        await Share.share(profile.toUri(), subject: profile.name);
      case AmneziaWgStoredVpnProfile(:final profile):
        await Share.share(profile.conf, subject: profile.name);
    }
  }

  Future<void> _switchProfile(
    BuildContext context,
    StoredVpnProfile profile,
    bool isCurrentlyActive,
  ) async {
    if (isCurrentlyActive) return; // Already active, do nothing

    final profileNotifier = context.read<ProfileNotifier>();
    final vpnNotifier = context.read<VpnNotifier>();
    final wasConnected = vpnNotifier.status == VpnStatus.connected;
    final wasConnecting = vpnNotifier.status == VpnStatus.connecting;

    // Show switching indicator
    if (wasConnected || wasConnecting) {
      AcrylicToast.show(context, 'Переключение на ${profile.name}...', duration: const Duration(seconds: 1), icon: Icons.swap_horiz_rounded);
    }

    // If VPN is connected or connecting, disconnect first
    if (wasConnected || wasConnecting) {
      await vpnNotifier.disconnect();
      // Small delay for smooth transition
      await Future.delayed(const Duration(milliseconds: 300));
    }

    await profileNotifier.setActive(profile.id);

    if (wasConnected) {
      await Future.delayed(const Duration(milliseconds: 200));
      await vpnNotifier.connect(profile);
      if (context.mounted) {
        AcrylicToast.show(
          context,
          'Подключение к ${profile.name}...',
          duration: const Duration(seconds: 1),
          icon: Icons.vpn_lock_rounded,
        );
      }
    }
  }

  Future<void> _startVpn(BuildContext context) async {
    final profileNotifier = context.read<ProfileNotifier>();
    final vpnNotifier = context.read<VpnNotifier>();
    final activeProfile = profileNotifier.activeProfile;
    if (activeProfile == null) {
      AcrylicToast.show(context, 'Выберите конфиг', icon: Icons.vpn_key_rounded);
      return;
    }
    final ok = await vpnNotifier.connect(activeProfile);
    if (!context.mounted) return;
    if (!ok) {
      final err = vpnNotifier.lastError;
      AcrylicToast.show(
        context,
        err != null && err.isNotEmpty ? err : 'Не удалось подключиться',
        icon: Icons.error_outline_rounded,
        isError: true,
      );
    }
  }

  void _openEditor(BuildContext context, {VlessProfile? profile}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileFormScreen(profile: profile),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(
              Icons.warning_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 12),
            const Text('Удалить конфиг?'),
          ],
        ),
        content: const Text('Действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<ProfileNotifier>().delete(id);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

}

/// Visual block header when the protocol changes in the profile list.
class _ProtocolSectionHeader extends StatelessWidget {
  const _ProtocolSectionHeader({required this.protocol});

  final VpnProtocol protocol;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (Color accent, IconData icon, String title) = switch (protocol) {
      VpnProtocol.vless => (
          const Color(0xFF00D9FF),
          Icons.dns_rounded,
          'VLESS',
        ),
      VpnProtocol.amneziaWg => (
          const Color(0xFF00D9A0),
          Icons.shield_rounded,
          'AmneziaWG',
        ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 22,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Icon(icon, size: 20, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.isActive,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final StoredVpnProfile profile;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = switch (profile) {
      VlessStoredVpnProfile() => const Color(0xFF00D9FF),
      AmneziaWgStoredVpnProfile() => const Color(0xFF00D9A0),
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: isActive ? 4 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isActive ? accent.withOpacity(0.45) : Colors.transparent,
            width: 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isActive ? accent.withOpacity(0.2) : scheme.surface.withOpacity(0.5),
                    shape: BoxShape.circle,
                    border: isActive
                        ? Border.all(
                            color: accent.withOpacity(0.55),
                            width: 2,
                          )
                        : null,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(
                        scale: animation,
                        child: child,
                      );
                    },
                    child: Icon(
                      isActive ? Icons.check_circle_rounded : Icons.circle_outlined,
                      key: ValueKey(isActive),
                      color: isActive ? accent : scheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [
                                FontFeature.enable('liga'),
                              ],
                            ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            profile is VlessStoredVpnProfile ? Icons.dns_rounded : Icons.shield_outlined,
                            size: 14,
                            color: scheme.onSurface.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              switch (profile) {
                                VlessStoredVpnProfile(:final profile) =>
                                  '${profile.host}:${profile.port}',
                                AmneziaWgStoredVpnProfile(:final profile) =>
                                  profile.endpointHint,
                              },
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurface.withOpacity(0.6),
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _ProfileActions(
                  profile: profile,
                  onEdit: onEdit,
                  onDelete: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionBottomBar extends StatelessWidget {
  const _ConnectionBottomBar({
    required this.vpnStatus,
    required this.active,
    required this.uploadBytes,
    required this.downloadBytes,
    required this.onStart,
    required this.onDisconnect,
  });

  final VpnStatus vpnStatus;
  final StoredVpnProfile? active;
  final int uploadBytes;
  final int downloadBytes;
  final VoidCallback onStart;
  final VoidCallback onDisconnect;

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes Б';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} КБ';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} МБ';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} ГБ';
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusText = switch (vpnStatus) {
      VpnStatus.connected => 'Подключено',
      VpnStatus.connecting => 'Подключение…',
      VpnStatus.error => 'Ошибка',
      VpnStatus.disconnected => 'Отключено',
    };
    final statusColor = switch (vpnStatus) {
      VpnStatus.connected => switch (active) {
          VlessStoredVpnProfile() => const Color(0xFF00D9FF),
          AmneziaWgStoredVpnProfile() => const Color(0xFF00D9A0),
          null => const Color(0xFF00D9FF),
        },
      VpnStatus.connecting => const Color(0xFFFFB800),
      VpnStatus.error => const Color(0xFFFF4444),
      VpnStatus.disconnected => Colors.white.withOpacity(0.6),
    };
    
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF000000),
            border: Border(
              top: BorderSide(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '▲ ${_formatBytes(uploadBytes)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                      ),
                      Text(
                        '▼ ${_formatBytes(downloadBytes)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 80),
                Flexible(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        statusText,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      if (active != null)
                        Text(
                          active!.name,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white.withOpacity(0.8),
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileActions extends StatelessWidget {
  const _ProfileActions({
    required this.profile,
    required this.onEdit,
    required this.onDelete,
  });

  final StoredVpnProfile profile;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'edit':
            onEdit();
            break;
          case 'delete':
            onDelete();
            break;
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'edit', child: Text('Редактировать')),
        const PopupMenuItem(value: 'delete', child: Text('Удалить')),
      ],
    );
  }
}

