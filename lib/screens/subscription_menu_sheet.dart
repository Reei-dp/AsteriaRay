import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/vpn_subscription.dart';

class SubscriptionMenuSheet extends StatelessWidget {
  const SubscriptionMenuSheet({
    super.key,
    required this.subscription,
    required this.isRefreshing,
    required this.isPinging,
    required this.onRefresh,
    required this.onPing,
    required this.onEdit,
    required this.onTogglePin,
    required this.onDelete,
  });

  final VpnSubscription subscription;
  final bool isRefreshing;
  final bool isPinging;
  final VoidCallback onRefresh;
  final VoidCallback onPing;
  final VoidCallback onEdit;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;

  static Future<void> show(
    BuildContext context, {
    required VpnSubscription subscription,
    required bool isRefreshing,
    required bool isPinging,
    required VoidCallback onRefresh,
    required VoidCallback onPing,
    required VoidCallback onEdit,
    required VoidCallback onTogglePin,
    required VoidCallback onDelete,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SubscriptionMenuSheet(
        subscription: subscription,
        isRefreshing: isRefreshing,
        isPinging: isPinging,
        onRefresh: onRefresh,
        onPing: onPing,
        onEdit: onEdit,
        onTogglePin: onTogglePin,
        onDelete: onDelete,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.sync_rounded),
            title: Text(l10n.subscriptionMenuRefresh),
            enabled: !isRefreshing,
            onTap: () {
              Navigator.pop(context);
              onRefresh();
            },
          ),
          ListTile(
            leading: const Icon(Icons.speed_rounded),
            title: Text(l10n.subscriptionMenuPing),
            enabled: !isPinging,
            onTap: () {
              Navigator.pop(context);
              onPing();
            },
          ),
          ListTile(
            leading: const Icon(Icons.tune_rounded),
            title: Text(l10n.subscriptionMenuEdit),
            onTap: () {
              Navigator.pop(context);
              onEdit();
            },
          ),
          ListTile(
            leading: Icon(
              subscription.pinned
                  ? Icons.push_pin_rounded
                  : Icons.push_pin_outlined,
            ),
            title: Text(
              subscription.pinned
                  ? l10n.subscriptionMenuUnpin
                  : l10n.subscriptionMenuPin,
            ),
            onTap: () {
              Navigator.pop(context);
              onTogglePin();
            },
          ),
          ListTile(
            leading: Icon(
              Icons.delete_outline_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              l10n.subscriptionRemove,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () {
              Navigator.pop(context);
              onDelete();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
