import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/stored_vpn_profile.dart';
import '../models/vpn_subscription.dart';
import '../notifiers/profile_notifier.dart';
import '../notifiers/subscription_notifier.dart';
import '../utils/vless_display.dart';

/// Header + server list in one grouped card (Happ-style).
class SubscriptionBlock extends StatelessWidget {
  const SubscriptionBlock({
    super.key,
    required this.subscription,
    required this.activeId,
    required this.isRefreshing,
    required this.isPinging,
    required this.onRefresh,
    required this.onPingAll,
    required this.onOpenMenu,
    required this.onNodeTap,
  });

  final VpnSubscription subscription;
  final String? activeId;
  final bool isRefreshing;
  final bool isPinging;
  final VoidCallback onRefresh;
  final VoidCallback onPingAll;
  final VoidCallback onOpenMenu;
  final void Function(VlessStoredVpnProfile profile, bool isActive) onNodeTap;

  static const _accent = Color(0xFF00D9FF);
  static const _radius = 16.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nodes = context
        .watch<ProfileNotifier>()
        .profilesForSubscription(subscription.id);
    final subsNotifier = context.watch<SubscriptionNotifier>();
    final pings = subsNotifier.pings;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(color: _accent.withOpacity(0.2)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_radius),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SubscriptionHeader(
                subscription: subscription,
                isRefreshing: isRefreshing,
                isPinging: isPinging,
                onRefresh: onRefresh,
                onPingAll: onPingAll,
                onOpenMenu: onOpenMenu,
              ),
              if (!subscription.hideServerSettings && nodes.isNotEmpty)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: theme.colorScheme.onSurface.withOpacity(0.07),
                ),
              for (var i = 0; i < nodes.length; i++)
                _SubscriptionNodeRow(
                  profile: nodes[i],
                  isActive: activeId == nodes[i].id,
                  pingMs: pings[nodes[i].id],
                  isPinging: subsNotifier.isPingingProfile(nodes[i].id),
                  isLast: i == nodes.length - 1,
                  onTap: () =>
                      onNodeTap(nodes[i], activeId == nodes[i].id),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubscriptionHeader extends StatelessWidget {
  const _SubscriptionHeader({
    required this.subscription,
    required this.isRefreshing,
    required this.isPinging,
    required this.onRefresh,
    required this.onPingAll,
    required this.onOpenMenu,
  });

  final VpnSubscription subscription;
  final bool isRefreshing;
  final bool isPinging;
  final VoidCallback onRefresh;
  final VoidCallback onPingAll;
  final VoidCallback onOpenMenu;

  static const _accent = Color(0xFF00D9FF);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final useEn = locale == 'en';
    final used = subscription.uploadBytes + subscription.downloadBytes;
    final total = subscription.totalBytes;
    final hasCap = total > 0;
    final progress = hasCap ? (used / total).clamp(0.0, 1.0) : 0.0;
    final updated = subscription.lastUpdatedAt;
    final dateFmt = DateFormat('dd.MM.yyyy HH:mm');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            subscription.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        if (subscription.pinned) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.push_pin_rounded,
                            size: 16,
                            color: _accent.withOpacity(0.75),
                          ),
                        ],
                      ],
                    ),
                    if (updated != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${dateFmt.format(updated)} · ${l10n.subscriptionAutoUpdate(subscription.updateIntervalHours)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10.5,
                          height: 1.2,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.subscriptionRefresh,
                onPressed: isRefreshing ? null : onRefresh,
                icon: isRefreshing
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _accent.withOpacity(0.85),
                        ),
                      )
                    : Icon(Icons.refresh_rounded,
                        color: _accent.withOpacity(0.9)),
              ),
              IconButton(
                tooltip: l10n.subscriptionPingAll,
                onPressed: isPinging ? null : onPingAll,
                icon: Icon(
                  Icons.speed_rounded,
                  color: isPinging
                      ? theme.colorScheme.onSurface.withOpacity(0.35)
                      : _accent.withOpacity(0.9),
                ),
              ),
              IconButton(
                tooltip: l10n.subscriptionMenuEdit,
                onPressed: onOpenMenu,
                icon: Icon(
                  Icons.more_horiz_rounded,
                  color: theme.colorScheme.onSurface.withOpacity(0.55),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 15,
                      color: theme.colorScheme.onSurface.withOpacity(0.45),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: _TrafficBar(
                          progress: progress,
                          hasCap: hasCap,
                          accent: _accent,
                          trackColor:
                              theme.colorScheme.onSurface.withOpacity(0.08),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      hasCap
                          ? '${formatTrafficBytes(used, useEnglish: useEn)}/${formatTrafficBytes(total, useEnglish: useEn)}'
                          : '${formatTrafficBytes(used, useEnglish: useEn)}/${l10n.subscriptionUnlimited}',
                      maxLines: 1,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withOpacity(0.75),
                      ),
                    ),
                  ],
                ),
              ),
              if (subscription.expiresAt != null) ...[
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    l10n.subscriptionExpires(
                      DateFormat('dd.MM.yyyy').format(subscription.expiresAt!),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 10.5,
                      color: subscription.isExpired
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurface.withOpacity(0.55),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (subscription.announce != null &&
              subscription.announce!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                subscription.announce!.trim(),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  height: 1.45,
                  color: theme.colorScheme.onSurface.withOpacity(0.72),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Static traffic bar — no indeterminate shimmer when quota is unlimited.
class _TrafficBar extends StatelessWidget {
  const _TrafficBar({
    required this.progress,
    required this.hasCap,
    required this.accent,
    required this.trackColor,
  });

  final double progress;
  final bool hasCap;
  final Color accent;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    final fill = hasCap ? progress : 0.0;
    return SizedBox(
      height: 8,
      child: ColoredBox(
        color: trackColor,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: fill.clamp(0.0, 1.0),
            child: ColoredBox(color: accent.withOpacity(0.75)),
          ),
        ),
      ),
    );
  }
}

class _SubscriptionNodeRow extends StatelessWidget {
  const _SubscriptionNodeRow({
    required this.profile,
    required this.isActive,
    required this.isLast,
    required this.onTap,
    this.pingMs,
    this.isPinging = false,
  });

  final VlessStoredVpnProfile profile;
  final bool isActive;
  final bool isLast;
  final VoidCallback onTap;
  final int? pingMs;
  final bool isPinging;

  static const _accent = Color(0xFF00D9FF);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final p = profile.profile;
    final display = subscriptionNodeDisplay(p.name);
    final subtitle = vlessProtocolLabel(p);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: isActive
              ? _accent.withOpacity(0.07)
              : Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: 72,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 4,
                      decoration: BoxDecoration(
                        color: isActive ? _accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                      child: Row(
                        children: [
                          Text(display.flag, style: const TextStyle(fontSize: 26)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  display.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  subtitle,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.5),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isPinging)
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _accent.withOpacity(0.75),
                              ),
                            )
                          else
                            Text(
                              pingMs != null
                                  ? l10n.subscriptionPingMs(pingMs!)
                                  : l10n.subscriptionPingNa,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: pingMs != null
                                    ? _accent.withOpacity(0.9)
                                    : theme.colorScheme.onSurface
                                        .withOpacity(0.4),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: theme.colorScheme.onSurface
                                .withOpacity(0.35),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            thickness: 1,
            indent: 4,
            color: theme.colorScheme.onSurface.withOpacity(0.07),
          ),
      ],
    );
  }
}

/// Standalone node card for manual (non-subscription) profiles.
class SubscriptionNodeCard extends StatelessWidget {
  const SubscriptionNodeCard({
    super.key,
    required this.profile,
    required this.isActive,
    required this.onTap,
    this.pingMs,
  });

  final VlessStoredVpnProfile profile;
  final bool isActive;
  final VoidCallback onTap;
  final int? pingMs;

  static const _accent = Color(0xFF00D9FF);
  static const _radius = 14.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final p = profile.profile;
    final display = subscriptionNodeDisplay(p.name);
    final subtitle = vlessProtocolLabel(p);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: Material(
          color: isActive
              ? _accent.withOpacity(0.08)
              : theme.cardColor,
          elevation: isActive ? 2 : 1,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: 72,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 4,
                      decoration: BoxDecoration(
                        color: isActive ? _accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                      child: Row(
                        children: [
                          Text(display.flag, style: const TextStyle(fontSize: 26)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  display.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  subtitle,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (pingMs != null)
                            Text(
                              l10n.subscriptionPingMs(pingMs!),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: _accent.withOpacity(0.9),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: theme.colorScheme.onSurface
                                .withOpacity(0.35),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
