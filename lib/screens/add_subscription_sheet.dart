import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../notifiers/subscription_notifier.dart';
import '../widgets/acrylic_toast.dart';

class AddSubscriptionSheet extends StatefulWidget {
  const AddSubscriptionSheet({super.key, this.initialUrl});

  final String? initialUrl;

  static Future<void> show(BuildContext context, {String? initialUrl}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AddSubscriptionSheet(initialUrl: initialUrl),
    );
  }

  @override
  State<AddSubscriptionSheet> createState() => _AddSubscriptionSheetState();
}

class _AddSubscriptionSheetState extends State<AddSubscriptionSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _url;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: widget.initialUrl ?? '');
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final l10n = context.l10n;
    try {
      await context.read<SubscriptionNotifier>().addFromUrl(_url.text.trim());
      if (!mounted) return;
      Navigator.pop(context);
      AcrylicToast.show(
        context,
        l10n.subscriptionAdded,
        icon: Icons.check_circle_rounded,
      );
    } catch (e) {
      if (!mounted) return;
      AcrylicToast.show(
        context,
        l10n.subscriptionAddFailed(e),
        icon: Icons.error_outline_rounded,
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.addSubscriptionTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.addSubscriptionHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.55),
                  ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _url,
              autofocus: true,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l10n.subscriptionUrlLabel,
                hintText: l10n.subscriptionUrlHint,
                prefixIcon: const Icon(Icons.link_rounded),
              ),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return l10n.subscriptionUrlRequired;
                if (!t.startsWith('http')) return l10n.subscriptionInvalidUrl;
                return null;
              },
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loading ? null : _submit,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_download_rounded),
              label: Text(l10n.addSubscriptionAction),
            ),
          ],
        ),
      ),
    );
  }
}
