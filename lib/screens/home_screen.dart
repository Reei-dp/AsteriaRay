import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../models/amnezia_wg_profile.dart';
import '../models/stored_vpn_profile.dart';
import '../models/vless_profile.dart';
import '../models/vpn_protocol.dart';
import '../services/config_import_detector.dart';
import '../services/subscription_service.dart';
import '../notifiers/profile_notifier.dart';
import '../notifiers/subscription_notifier.dart';
import '../notifiers/vpn_notifier.dart';
import '../widgets/acrylic_toast.dart';
import '../widgets/protocol_slide_tabs.dart';
import 'amnezia_wg_form_screen.dart';
import 'manual_profile_screen.dart';
import 'profile_form_screen.dart';
import 'qr_scan_screen.dart';
import 'settings_screen.dart';
import 'vless_home_page.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profileNotifier = context.watch<ProfileNotifier>();
    final subscriptionNotifier = context.watch<SubscriptionNotifier>();
    final profiles = profileNotifier.profiles;
    final l10n = context.l10n;
    final ready =
        profileNotifier.initialized && subscriptionNotifier.initialized;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.appTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        actions: [
          IconButton(
            tooltip: l10n.tooltipSettings,
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
            tooltip: l10n.tooltipShare,
            icon: const Icon(Icons.share),
            onPressed: () => _shareActive(context),
          ),
          IconButton(
            tooltip: l10n.tooltipAddConfig,
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showAddProfileMenu(context),
          ),
        ],
      ),
      body: ready
          ? Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: _HomeProfileSlides(
                        profiles: profiles,
                        activeId: profileNotifier.activeId,
                        onTap: (profile, isActive) => _switchProfile(
                          context,
                          profile,
                          isActive,
                        ),
                        onEdit: (profile) {
                          if (profile is VlessStoredVpnProfile) {
                            _openVlessEditor(context, profile: profile.profile);
                          } else if (profile is AmneziaWgStoredVpnProfile) {
                            _openAwgEditor(context, profile: profile.profile);
                          }
                        },
                        onDelete: (profile) => _confirmDeleteProfile(context, profile),
                      ),
                    ),
                    const _VpnConnectionBottomBar(),
                  ],
                ),
                const _VpnFloatingActionButton(),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  void _showAddProfileMenu(BuildContext context) {
    final l10n = context.l10n;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  l10n.addConfigTitle,
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(l10n.addManualTitle),
                subtitle: Text(l10n.addManualSubtitle),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openManualEditor(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.file_open_rounded),
                title: Text(l10n.addFileTitle),
                subtitle: Text(l10n.addFileSubtitle),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _importFromFile(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.qr_code_scanner_rounded),
                title: Text(l10n.addQrTitle),
                subtitle: Text(l10n.addQrSubtitle),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _importFromQr(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.content_paste_rounded),
                title: Text(l10n.addClipboardTitle),
                subtitle: Text(l10n.addClipboardSubtitle),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _importFromClipboard(context);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  bool get _supportsQrScan =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> _importFromQr(BuildContext context) async {
    if (!_supportsQrScan) {
      AcrylicToast.show(
        context,
        context.l10n.qrScannerMobileOnly,
        icon: Icons.qr_code_scanner_rounded,
      );
      return;
    }

    final payload = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (!context.mounted || payload == null || payload.trim().isEmpty) return;
    await _importPayload(context, payload.trim());
  }

  Future<void> _importFromClipboard(BuildContext context) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!context.mounted) return;
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      AcrylicToast.show(context, context.l10n.clipboardEmpty, icon: Icons.content_paste_rounded);
      return;
    }
    if (SubscriptionService.looksLikeSubscriptionUrl(text)) {
      await _addSubscriptionFromClipboard(context, text);
      return;
    }
    await _importPayload(context, text);
  }

  Future<void> _addSubscriptionFromClipboard(
    BuildContext context,
    String url,
  ) async {
    final l10n = context.l10n;
    try {
      await context.read<SubscriptionNotifier>().addFromUrl(url);
      if (!context.mounted) return;
      AcrylicToast.show(
        context,
        l10n.subscriptionAdded,
        icon: Icons.check_circle_rounded,
      );
    } catch (e) {
      if (!context.mounted) return;
      AcrylicToast.show(
        context,
        l10n.subscriptionAddFailed(e),
        icon: Icons.error_outline_rounded,
        isError: true,
      );
    }
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
      AcrylicToast.show(context, context.l10n.fileReadError, icon: Icons.error_outline_rounded, isError: true);
      return;
    }
    final content = await File(path).readAsString();
    if (!context.mounted) return;
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      AcrylicToast.show(context, context.l10n.fileEmpty, icon: Icons.description_rounded);
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
    AcrylicToast.show(context, context.l10n.importedCount(imported), icon: Icons.check_circle_rounded);
  }

  Future<void> _importPayload(BuildContext context, String text,
      {bool silent = false}) async {
    try {
      final profile =
          await context.read<ProfileNotifier>().importFromClipboard(text);
      if (!context.mounted) return;
      if (!silent) {
        AcrylicToast.show(context, context.l10n.importedProfile(profile.name), icon: Icons.check_circle_rounded);
      }
    } catch (e) {
      if (!context.mounted) return;
      AcrylicToast.show(
        context,
        e is FormatException ? context.l10n.importFormatError : context.l10n.importError(e),
        icon: Icons.error_outline_rounded,
        isError: true,
      );
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
        AcrylicToast.show(context, context.l10n.importedProfile(profile.name), icon: Icons.check_circle_rounded);
      }
    } catch (e) {
      if (!context.mounted) return;
      AcrylicToast.show(
        context,
        e is FormatException ? context.l10n.importFormatError : context.l10n.importError(e),
        icon: Icons.error_outline_rounded,
        isError: true,
      );
    }
  }

  Future<void> _shareActive(BuildContext context) async {
    final active = context.read<ProfileNotifier>().activeProfile;
    if (active == null) {
      AcrylicToast.show(context, context.l10n.noActiveConfig, icon: Icons.vpn_key_rounded);
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
      AcrylicToast.show(context, context.l10n.switchingTo(profile.name), duration: const Duration(seconds: 1), icon: Icons.swap_horiz_rounded);
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
          context.l10n.connectingTo(profile.name),
          duration: const Duration(seconds: 1),
          icon: Icons.vpn_lock_rounded,
        );
      }
    }
  }

  Future<void> _startVpn(BuildContext context) => _homeStartVpn(context);

  void _openManualEditor(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ManualProfileScreen(),
      ),
    );
  }

  void _openVlessEditor(BuildContext context, {VlessProfile? profile}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileFormScreen(profile: profile),
      ),
    );
  }

  void _openAwgEditor(BuildContext context, {AmneziaWgProfile? profile}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AmneziaWgFormScreen(profile: profile),
      ),
    );
  }

  Future<bool> _confirmDeleteProfile(
    BuildContext context,
    StoredVpnProfile profile,
  ) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final scheme = theme.colorScheme;
        final l10n = sheetContext.l10n;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.deleteConfigTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.deleteConfigBody,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withOpacity(0.65),
                  ),
                ),
                const SizedBox(height: 16),
                _DeleteProfilePreview(profile: profile),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext, false),
                        child: Text(l10n.cancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(sheetContext, true),
                        icon: const Icon(Icons.delete_outline_rounded, size: 20),
                        label: Text(l10n.delete),
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.error,
                          foregroundColor: scheme.onError,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true || !context.mounted) return false;

    await context.read<ProfileNotifier>().delete(profile.id);
    if (!context.mounted) return true;

    AcrylicToast.show(
      context,
      context.l10n.profileDeleted(profile.name),
      icon: Icons.check_circle_rounded,
    );
    return true;
  }

}

/// Swipeable home: VLESS (page 0) → AmneziaWG (page 1).
class _HomeProfileSlides extends StatefulWidget {
  const _HomeProfileSlides({
    required this.profiles,
    required this.activeId,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final List<StoredVpnProfile> profiles;
  final String? activeId;
  final void Function(StoredVpnProfile profile, bool isActive) onTap;
  final void Function(StoredVpnProfile profile) onEdit;
  final Future<bool> Function(StoredVpnProfile profile) onDelete;

  @override
  State<_HomeProfileSlides> createState() => _HomeProfileSlidesState();
}

class _HomeProfileSlidesState extends State<_HomeProfileSlides> {
  static const _pages = [VpnProtocol.vless, VpnProtocol.amneziaWg];

  PageController? _pageController;
  bool _pageSynced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pageSynced) return;
    final active = context.read<ProfileNotifier>().activeProfile;
    final initial = active?.protocol == VpnProtocol.amneziaWg ? 1 : 0;
    _pageController = PageController(initialPage: initial);
    _pageSynced = true;
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  List<StoredVpnProfile> _forProtocol(VpnProtocol protocol) {
    return widget.profiles.where((p) => p.protocol == protocol).toList();
  }

  void _goToPage(int index) {
    final controller = _pageController;
    if (controller == null || !controller.hasClients) return;
    final current = controller.page?.round() ?? controller.initialPage;
    if (current == index) return;
    controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _pageController;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final page = controller.hasClients
                  ? (controller.page ?? controller.initialPage.toDouble())
                  : controller.initialPage.toDouble();
            return ProtocolSlideTabs(
              page: page.clamp(0.0, 1.0),
              onSelect: _goToPage,
            );
            },
          ),
        ),
        Expanded(
          child: PageView(
            controller: controller,
            physics: const PageScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            children: [
              RepaintBoundary(
                child: VlessHomePage(
                  key: const PageStorageKey<String>('home_vless'),
                  activeId: widget.activeId,
                  onTap: widget.onTap,
                  onEdit: widget.onEdit,
                  onDelete: widget.onDelete,
                ),
              ),
              RepaintBoundary(
                child: _ProtocolProfilePage(
                  key: const PageStorageKey<String>('home_amnezia'),
                  protocol: VpnProtocol.amneziaWg,
                  profiles: _forProtocol(VpnProtocol.amneziaWg),
                  activeId: widget.activeId,
                  onTap: widget.onTap,
                  onEdit: widget.onEdit,
                  onDelete: widget.onDelete,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProtocolProfilePage extends StatefulWidget {
  const _ProtocolProfilePage({
    super.key,
    required this.protocol,
    required this.profiles,
    required this.activeId,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final VpnProtocol protocol;
  final List<StoredVpnProfile> profiles;
  final String? activeId;
  final void Function(StoredVpnProfile profile, bool isActive) onTap;
  final void Function(StoredVpnProfile profile) onEdit;
  final Future<bool> Function(StoredVpnProfile profile) onDelete;

  @override
  State<_ProtocolProfilePage> createState() => _ProtocolProfilePageState();
}

class _ProtocolProfilePageState extends State<_ProtocolProfilePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.profiles.isEmpty) {
      return _ProtocolEmptyState(protocol: widget.protocol);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: [
        for (final profile in widget.profiles)
          _ProfileCard(
            profile: profile,
            isActive: widget.activeId == profile.id,
            onTap: () => widget.onTap(profile, widget.activeId == profile.id),
            onEdit: () => widget.onEdit(profile),
            onDelete: () => widget.onDelete(profile),
          ),
      ],
    );
  }
}

class _ProtocolEmptyState extends StatelessWidget {
  const _ProtocolEmptyState({required this.protocol});

  final VpnProtocol protocol;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isVless = protocol == VpnProtocol.vless;
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isVless)
              SvgPicture.asset(
                'assets/protocols/vless-logo-dark.svg',
                width: 56,
                height: 56,
                colorFilter: ColorFilter.mode(
                  theme.colorScheme.onSurface.withOpacity(0.25),
                  BlendMode.srcIn,
                ),
              )
            else
              Opacity(
                opacity: 0.25,
                child: SvgPicture.asset(
                  'assets/protocols/amnezia-logo.svg',
                  width: 56,
                  height: 56,
                ),
              ),
            const SizedBox(height: 16),
            Text(
              isVless ? l10n.noVlessConfigs : l10n.noAwgConfigs,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isVless ? l10n.swipeToAwg : l10n.swipeToVless,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.tapPlusToAdd,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Amnezia brand: blue → orange (from amnezia-client logo palette).
abstract final class _AmneziaBrand {
  _AmneziaBrand._();

  static const blue = Color(0xFF87ADD4);
  static const orange = Color(0xFFFFB754);

  static const gradient = LinearGradient(
    colors: [blue, orange],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static Widget gradientMask(Widget child) {
    return ShaderMask(
      shaderCallback: (bounds) => gradient.createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: child,
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
  final Future<bool> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isAmnezia = profile is AmneziaWgStoredVpnProfile;
    const vlessAccent = Color(0xFF00D9FF);

    final cardBody = Material(
      color: Theme.of(context).cardColor,
      elevation: isActive ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isActive
            ? BorderSide(
                color: isAmnezia
                    ? _AmneziaBrand.orange.withOpacity(0.42)
                    : vlessAccent.withOpacity(0.45),
                width: 1,
              )
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _ProfileSelectBadge(
                isActive: isActive,
                isAmnezia: isAmnezia,
                accent: vlessAccent,
                inactiveSurface: scheme.surface,
                onSurface: scheme.onSurface,
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
                        if (isAmnezia)
                          _AmneziaBrand.gradientMask(
                            SvgPicture.asset(
                              'assets/protocols/amnezia-logo.svg',
                              width: 14,
                              height: 14,
                            ),
                          )
                        else
                          SvgPicture.asset(
                            'assets/protocols/vless-logo-dark.svg',
                            width: 14,
                            height: 14,
                            colorFilter: ColorFilter.mode(
                              isActive
                                  ? vlessAccent
                                  : vlessAccent.withOpacity(0.55),
                              BlendMode.srcIn,
                            ),
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
                onEdit: onEdit,
                onDelete: onDelete,
              ),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: ValueKey(profile.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => onDelete(),
        background: const _DeleteSwipeBackground(),
        child: cardBody,
      ),
    );
  }
}

class _ProfileSelectBadge extends StatelessWidget {
  const _ProfileSelectBadge({
    required this.isActive,
    required this.isAmnezia,
    required this.accent,
    required this.inactiveSurface,
    required this.onSurface,
  });

  final bool isActive;
  final bool isAmnezia;
  final Color accent;
  final Color inactiveSurface;
  final Color onSurface;

  @override
  Widget build(BuildContext context) {
    const size = 48.0;

    final icon = Icon(
      isActive ? Icons.check_circle_rounded : Icons.circle_outlined,
      key: ValueKey(isActive),
      color: isActive
          ? (isAmnezia ? _AmneziaBrand.orange : accent)
          : onSurface.withOpacity(0.5),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: !isActive
            ? inactiveSurface.withOpacity(0.5)
            : (isAmnezia ? _AmneziaBrand.orange.withOpacity(0.14) : accent.withOpacity(0.2)),
        border: isActive
            ? Border.all(
                color: isAmnezia
                    ? _AmneziaBrand.orange.withOpacity(0.55)
                    : accent.withOpacity(0.55),
                width: 2,
              )
            : null,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) {
          return ScaleTransition(scale: animation, child: child);
        },
        child: icon,
      ),
    );
  }
}

Future<void> _homeStartVpn(BuildContext context) async {
  final profileNotifier = context.read<ProfileNotifier>();
  final vpnNotifier = context.read<VpnNotifier>();
  final activeProfile = profileNotifier.activeProfile;
  if (activeProfile == null) {
    AcrylicToast.show(context, context.l10n.selectConfig, icon: Icons.vpn_key_rounded);
    return;
  }
  final ok = await vpnNotifier.connect(activeProfile);
  if (!context.mounted) return;
  if (!ok) {
    final err = vpnNotifier.lastErrorBrief ?? vpnNotifier.lastError;
    AcrylicToast.show(
      context,
      err != null && err.isNotEmpty ? err : context.l10n.connectFailed,
      icon: Icons.error_outline_rounded,
      isError: true,
      duration: const Duration(seconds: 6),
    );
  }
}

class _VpnBarSnapshot {
  const _VpnBarSnapshot({
    required this.active,
    required this.status,
    required this.uploadBytes,
    required this.downloadBytes,
  });

  final StoredVpnProfile? active;
  final VpnStatus status;
  final int uploadBytes;
  final int downloadBytes;

  @override
  bool operator ==(Object other) {
    return other is _VpnBarSnapshot &&
        other.active?.id == active?.id &&
        other.status == status &&
        other.uploadBytes == uploadBytes &&
        other.downloadBytes == downloadBytes;
  }

  @override
  int get hashCode => Object.hash(active?.id, status, uploadBytes, downloadBytes);
}

/// Rebuilds only the bottom bar — not the profile [PageView] — when VPN stats tick.
class _VpnConnectionBottomBar extends StatelessWidget {
  const _VpnConnectionBottomBar();

  @override
  Widget build(BuildContext context) {
    return Selector2<ProfileNotifier, VpnNotifier, _VpnBarSnapshot>(
      selector: (_, profiles, vpn) => _VpnBarSnapshot(
        active: profiles.activeProfile,
        status: vpn.status,
        uploadBytes: vpn.uploadBytes,
        downloadBytes: vpn.downloadBytes,
      ),
      builder: (context, snap, _) {
        return _ConnectionBottomBar(
          vpnStatus: snap.status,
          active: snap.active,
          uploadBytes: snap.uploadBytes,
          downloadBytes: snap.downloadBytes,
          onStart: () => _homeStartVpn(context),
          onDisconnect: () => context.read<VpnNotifier>().disconnect(),
        );
      },
    );
  }
}

class _VpnFabSnapshot {
  const _VpnFabSnapshot({required this.hasActive, required this.status});

  final bool hasActive;
  final VpnStatus status;

  @override
  bool operator ==(Object other) {
    return other is _VpnFabSnapshot &&
        other.hasActive == hasActive &&
        other.status == status;
  }

  @override
  int get hashCode => Object.hash(hasActive, status);
}

class _VpnFloatingActionButton extends StatelessWidget {
  const _VpnFloatingActionButton();

  @override
  Widget build(BuildContext context) {
    return Selector2<ProfileNotifier, VpnNotifier, _VpnFabSnapshot>(
      selector: (_, profiles, vpn) => _VpnFabSnapshot(
        hasActive: profiles.activeProfile != null,
        status: vpn.status,
      ),
      builder: (context, snap, _) {
        if (!snap.hasActive || snap.status == VpnStatus.connecting) {
          return const SizedBox.shrink();
        }

        final isConnected = snap.status == VpnStatus.connected;
        return Positioned(
          bottom: 61,
          left: 0,
          right: 0,
          child: Center(
            child: Material(
              elevation: 8,
              shape: const CircleBorder(),
              color: Colors.white,
              child: InkWell(
                onTap: isConnected
                    ? () => context.read<VpnNotifier>().disconnect()
                    : () => _homeStartVpn(context),
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: Icon(
                    isConnected ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
        );
      },
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

  String _formatBytes(BuildContext context, int bytes) =>
      context.l10n.formatBytes(bytes);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final statusText = switch (vpnStatus) {
      VpnStatus.connected => l10n.connected,
      VpnStatus.connecting => l10n.connecting,
      VpnStatus.error => l10n.error,
      VpnStatus.disconnected => l10n.disconnected,
    };
    final statusColor = switch (vpnStatus) {
      VpnStatus.connected => switch (active) {
          VlessStoredVpnProfile() => const Color(0xFF00D9FF),
          AmneziaWgStoredVpnProfile() => _AmneziaBrand.orange,
          null => const Color(0xFF00D9FF),
        },
      VpnStatus.connecting => const Color(0xFFFFB800),
      VpnStatus.error => const Color(0xFFFF4444),
      VpnStatus.disconnected => Colors.white.withOpacity(0.6),
    };
    final statusStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        );
    final amneziaConnected =
        vpnStatus == VpnStatus.connected && active is AmneziaWgStoredVpnProfile;
    final statusLabel = amneziaConnected
        ? _AmneziaBrand.gradientMask(
            Text(
              statusText,
              style: statusStyle?.copyWith(color: Colors.white),
            ),
          )
        : Text(
            statusText,
            style: statusStyle?.copyWith(color: statusColor),
          );
    
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
                        '▲ ${_formatBytes(context, uploadBytes)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                      ),
                      Text(
                        '▼ ${_formatBytes(context, downloadBytes)}',
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
                      statusLabel,
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

class _DeleteSwipeBackground extends StatelessWidget {
  const _DeleteSwipeBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.error.withOpacity(0.15),
            Theme.of(context).colorScheme.error.withOpacity(0.82),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Icon(
        Icons.delete_outline_rounded,
        color: Theme.of(context).colorScheme.onError.withOpacity(0.95),
        size: 26,
      ),
    );
  }
}

class _DeleteProfilePreview extends StatelessWidget {
  const _DeleteProfilePreview({required this.profile});

  final StoredVpnProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isAmnezia = profile is AmneziaWgStoredVpnProfile;
    final subtitle = switch (profile) {
      VlessStoredVpnProfile(:final profile) => '${profile.host}:${profile.port}',
      AmneziaWgStoredVpnProfile(:final profile) => profile.endpointHint,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withOpacity(0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surface.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: isAmnezia
                    ? SvgPicture.asset(
                        'assets/protocols/amnezia-logo.svg',
                        width: 22,
                        height: 22,
                        colorFilter: ColorFilter.mode(
                          _AmneziaBrand.orange,
                          BlendMode.srcIn,
                        ),
                      )
                    : SvgPicture.asset(
                        'assets/protocols/vless-logo-dark.svg',
                        width: 22,
                        height: 22,
                        colorFilter: const ColorFilter.mode(
                          Color(0xFF00D9FF),
                          BlendMode.srcIn,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withOpacity(0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.error.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isAmnezia ? 'AWG' : 'VLESS',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.error,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileActions extends StatelessWidget {
  const _ProfileActions({
    required this.onEdit,
    required this.onDelete,
  });

  final VoidCallback onEdit;
  final Future<bool> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: context.l10n.edit,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          onPressed: onEdit,
          icon: Icon(
            Icons.edit_outlined,
            size: 20,
            color: scheme.onSurface.withOpacity(0.55),
          ),
        ),
        IconButton(
          tooltip: context.l10n.remove,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          onPressed: () => onDelete(),
          icon: Icon(
            Icons.delete_outline_rounded,
            size: 20,
            color: scheme.error.withOpacity(0.82),
          ),
        ),
      ],
    );
  }
}

