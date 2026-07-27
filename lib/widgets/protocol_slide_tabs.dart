import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Sliding pill tabs: VLESS (0) ↔ AmneziaWG (1), synced with [page] offset.
class ProtocolSlideTabs extends StatelessWidget {
  const ProtocolSlideTabs({
    super.key,
    required this.page,
    required this.onSelect,
    this.padding = const EdgeInsets.fromLTRB(12, 8, 12, 4),
  });

  /// Fractional page offset: 0 = VLESS, 1 = AmneziaWG.
  final double page;
  final ValueChanged<int> onSelect;
  final EdgeInsets padding;

  static const vlessActive = Color(0xFF00D9FF);
  static const amneziaActive = Color(0xFFFFB754);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inactive = theme.colorScheme.onSurface.withOpacity(0.45);
    final vlessWeight = (1 - page).clamp(0.0, 1.0);
    final awgWeight = page.clamp(0.0, 1.0);

    return Padding(
      padding: padding,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.35),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tabWidth = constraints.maxWidth / 2;
              return Stack(
                children: [
                  Positioned(
                    left: page * tabWidth,
                    top: 0,
                    bottom: 0,
                    width: tabWidth,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withOpacity(0.78),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _ProtocolSlideTab(
                          onTap: () => onSelect(0),
                          icon: SvgPicture.asset(
                            'assets/protocols/vless-logo-dark.svg',
                            width: 16,
                            height: 16,
                            colorFilter: ColorFilter.mode(
                              Color.lerp(inactive, vlessActive, vlessWeight)!,
                              BlendMode.srcIn,
                            ),
                          ),
                          label: 'VLESS',
                          labelColor:
                              Color.lerp(inactive, vlessActive, vlessWeight)!,
                        ),
                      ),
                      Expanded(
                        child: _ProtocolSlideTab(
                          onTap: () => onSelect(1),
                          icon: SvgPicture.asset(
                            'assets/protocols/amnezia-logo.svg',
                            width: 16,
                            height: 16,
                            colorFilter: ColorFilter.mode(
                              Color.lerp(inactive, amneziaActive, awgWeight)!,
                              BlendMode.srcIn,
                            ),
                          ),
                          label: 'AmneziaWG',
                          labelColor:
                              Color.lerp(inactive, amneziaActive, awgWeight)!,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProtocolSlideTab extends StatelessWidget {
  const _ProtocolSlideTab({
    required this.onTap,
    required this.icon,
    required this.label,
    required this.labelColor,
  });

  final VoidCallback onTap;
  final Widget icon;
  final String label;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: labelColor,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
