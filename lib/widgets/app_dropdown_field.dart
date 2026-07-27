import 'package:flutter/material.dart';

/// Styled select field: tap opens a bottom sheet instead of the default [DropdownButton].
class AppDropdownField<T> extends StatelessWidget {
  const AppDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.prefixIcon,
    this.enabled = true,
  });

  final String label;
  final T value;
  final List<AppDropdownItem<T>> items;
  final ValueChanged<T> onChanged;
  final IconData? prefixIcon;
  final bool enabled;

  static const _radius = 14.0;

  AppDropdownItem<T>? get _selected {
    for (final item in items) {
      if (item.value == value) return item;
    }
    return items.isEmpty ? null : items.first;
  }

  Future<void> _openPicker(BuildContext context) async {
    if (!enabled || items.isEmpty) return;

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final picked = await showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final selected = item.value == value;
                    return Material(
                      color: selected
                          ? scheme.primary.withOpacity(0.12)
                          : scheme.surfaceContainerHighest.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () =>
                            Navigator.pop(sheetContext, item.value),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              if (item.leading != null) ...[
                                item.leading!,
                                const SizedBox(width: 12),
                              ],
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.label,
                                      style:
                                          theme.textTheme.bodyLarge?.copyWith(
                                        fontWeight: selected
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        color: selected
                                            ? scheme.primary
                                            : scheme.onSurface,
                                      ),
                                    ),
                                    if (item.subtitle != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        item.subtitle!,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                          color: scheme.onSurface
                                              .withOpacity(0.55),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (selected)
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: scheme.primary,
                                  size: 22,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (picked != null) {
      onChanged(picked);
    }
  }

  InputDecoration _decoration(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(_radius),
      borderSide: BorderSide(
        color: scheme.outline.withOpacity(0.35),
        width: 1,
      ),
    );
    return InputDecoration(
      labelText: label,
      prefixIcon: prefixIcon != null
          ? Icon(
              prefixIcon,
              size: 22,
              color: enabled
                  ? scheme.onSurface.withOpacity(0.6)
                  : scheme.onSurface.withOpacity(0.3),
            )
          : null,
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withOpacity(0.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border,
      enabledBorder: border,
      disabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: BorderSide(
          color: scheme.primary.withOpacity(0.7),
          width: 1.5,
        ),
      ),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selected = _selected;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? () => _openPicker(context) : null,
        borderRadius: BorderRadius.circular(_radius),
        child: InputDecorator(
          decoration: _decoration(context),
          isEmpty: selected == null,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selected?.label ?? '—',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: enabled
                        ? scheme.onSurface
                        : scheme.onSurface.withOpacity(0.45),
                  ),
                ),
              ),
              Icon(
                Icons.expand_more_rounded,
                color: scheme.onSurface.withOpacity(enabled ? 0.55 : 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppDropdownItem<T> {
  const AppDropdownItem({
    required this.value,
    required this.label,
    this.subtitle,
    this.leading,
  });

  final T value;
  final String label;
  final String? subtitle;
  final Widget? leading;
}
