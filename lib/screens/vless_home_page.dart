import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/stored_vpn_profile.dart';
import '../notifiers/profile_notifier.dart';
import '../notifiers/subscription_notifier.dart';
import '../widgets/acrylic_toast.dart';
import '../widgets/subscription_block.dart';
import 'edit_subscription_sheet.dart';
import 'subscription_menu_sheet.dart';

/// VLESS tab: subscription feed (Happ-style) + optional manual profiles.
class VlessHomePage extends StatelessWidget {
  const VlessHomePage({
    super.key,
    required this.activeId,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final String? activeId;
  final void Function(StoredVpnProfile profile, bool isActive) onTap;
  final void Function(StoredVpnProfile profile) onEdit;
  final Future<bool> Function(StoredVpnProfile profile) onDelete;

  @override
  Widget build(BuildContext context) {
    final subs = context.watch<SubscriptionNotifier>();
    final profiles = context.watch<ProfileNotifier>();
    final manual = profiles.manualVlessProfiles;
    final l10n = context.l10n;

    if (!subs.initialized) {
      return const Center(child: CircularProgressIndicator());
    }

    if (subs.subscriptions.isEmpty && manual.isEmpty) {
      return const _VlessEmptyWithSubscriptionPrompt();
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        for (final subscription in subs.subscriptions)
          SubscriptionBlock(
            subscription: subscription,
            activeId: activeId,
            isRefreshing:
                subs.isRefreshing && subs.refreshingId == subscription.id,
            isPinging: subs.isPinging,
            onRefresh: () => _refresh(context, subscription.id),
            onPingAll: () => subs.pingSubscriptionNodes(subscription.id),
            onOpenMenu: () => _openMenu(context, subscription.id),
            onNodeTap: onTap,
          ),
        if (manual.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Text(
              l10n.subscriptionManualSection,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.55),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          for (final profile in manual)
            _ManualVlessCard(
              profile: profile,
              isActive: activeId == profile.id,
              onTap: () => onTap(profile, activeId == profile.id),
              onEdit: () => onEdit(profile),
              onDelete: () => onDelete(profile),
            ),
        ],
      ],
    );
  }

  void _openMenu(BuildContext context, String subscriptionId) {
    final subs = context.read<SubscriptionNotifier>();
    final subscription = subs.subscriptionById(subscriptionId);
    if (subscription == null) return;

    SubscriptionMenuSheet.show(
      context,
      subscription: subscription,
      isRefreshing:
          subs.isRefreshing && subs.refreshingId == subscriptionId,
      isPinging: subs.isPinging,
      onRefresh: () => _refresh(context, subscriptionId),
      onPing: () => subs.pingSubscriptionNodes(subscriptionId),
      onEdit: () => EditSubscriptionSheet.show(context, subscription),
      onTogglePin: () => subs.togglePin(subscriptionId),
      onDelete: () => _confirmRemove(context, subscriptionId),
    );
  }

  Future<void> _refresh(BuildContext context, String id) async {
    final l10n = context.l10n;
    try {
      await context.read<SubscriptionNotifier>().refresh(id);
      if (!context.mounted) return;
      AcrylicToast.show(
        context,
        l10n.subscriptionRefreshed,
        icon: Icons.refresh_rounded,
        duration: const Duration(seconds: 1),
      );
    } catch (e) {
      if (!context.mounted) return;
      AcrylicToast.show(
        context,
        l10n.subscriptionRefreshFailed(e),
        icon: Icons.error_outline_rounded,
        isError: true,
      );
    }
  }

  Future<void> _confirmRemove(BuildContext context, String id) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.subscriptionRemove),
        content: Text(l10n.subscriptionRemoveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await context.read<SubscriptionNotifier>().remove(id);
    if (!context.mounted) return;
    AcrylicToast.show(
      context,
      l10n.subscriptionRemoved,
      icon: Icons.check_circle_rounded,
    );
  }
}

class _VlessEmptyWithSubscriptionPrompt extends StatelessWidget {
  const _VlessEmptyWithSubscriptionPrompt();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    const accent = Color(0xFF00D9FF);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_queue_rounded,
              size: 56,
              color: accent.withOpacity(0.35),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.subscriptionEmptyTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.subscriptionEmptyHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.swipeToAwg,
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

class _ManualVlessCard extends StatelessWidget {
  const _ManualVlessCard({
    required this.profile,
    required this.isActive,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final VlessStoredVpnProfile profile;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final Future<bool> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(profile.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => onDelete(),
      background: const _DeleteSwipeBackground(),
      child: SubscriptionNodeCard(
        profile: profile,
        isActive: isActive,
        onTap: onTap,
      ),
    );
  }
}

class _DeleteSwipeBackground extends StatelessWidget {
  const _DeleteSwipeBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
    );
  }
}
