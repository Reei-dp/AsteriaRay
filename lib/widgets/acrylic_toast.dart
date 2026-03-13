import 'dart:ui';

import 'package:flutter/material.dart';

/// Полупрозрачный акриловый тост (glassmorphism) поверх контента.
class AcrylicToast {
  static OverlayEntry? _currentEntry;

  /// Показывает тост с размытием фона и полупрозрачным фоном.
  static void show(
    BuildContext context,
    String message, {
    Duration? duration,
    IconData? icon,
    bool isError = false,
  }) {
    final overlay = Overlay.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final duration_ = duration ?? const Duration(seconds: 2);

    _currentEntry?.remove();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _AcrylicToastOverlay(
        message: message,
        icon: icon,
        isError: isError,
        isDark: isDark,
        onRemove: () {
          entry.remove();
          if (_currentEntry == entry) _currentEntry = null;
        },
      ),
    );
    _currentEntry = entry;
    overlay.insert(entry);

    Future.delayed(duration_, () {
      if (entry.mounted) {
        entry.remove();
        if (_currentEntry == entry) _currentEntry = null;
      }
    });
  }
}

class _AcrylicToastOverlay extends StatefulWidget {
  const _AcrylicToastOverlay({
    required this.message,
    required this.onRemove,
    this.icon,
    this.isError = false,
    this.isDark = true,
  });

  final String message;
  final VoidCallback onRemove;
  final IconData? icon;
  final bool isError;
  final bool isDark;

  @override
  State<_AcrylicToastOverlay> createState() => _AcrylicToastOverlayState();
}

class _AcrylicToastOverlayState extends State<_AcrylicToastOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final surfaceColor = widget.isDark
        ? colorScheme.surface.withOpacity(0.45)
        : colorScheme.surface.withOpacity(0.65);
    final borderColor = widget.isDark
        ? Colors.white.withOpacity(0.12)
        : Colors.black.withOpacity(0.08);
    final textColor = colorScheme.onSurface;
    final iconColor = widget.isError ? colorScheme.error : colorScheme.primary;

    return IgnorePointer(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SlideTransition(
              position: _slide,
              child: FadeTransition(
                opacity: _opacity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: borderColor,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(
                              widget.icon,
                              size: 22,
                              color: iconColor,
                            ),
                            const SizedBox(width: 12),
                          ],
                          Flexible(
                            child: Text(
                              widget.message,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: textColor,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
