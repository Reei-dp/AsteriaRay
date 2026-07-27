import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/vpn_subscription.dart';
import '../notifiers/subscription_notifier.dart';
import '../widgets/acrylic_toast.dart';

class EditSubscriptionSheet extends StatefulWidget {
  const EditSubscriptionSheet({super.key, required this.subscription});

  final VpnSubscription subscription;

  static Future<void> show(
    BuildContext context,
    VpnSubscription subscription,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => EditSubscriptionSheet(subscription: subscription),
    );
  }

  @override
  State<EditSubscriptionSheet> createState() => _EditSubscriptionSheetState();
}

class _EditSubscriptionSheetState extends State<EditSubscriptionSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _url;
  late bool _hideServerSettings;
  late bool _encryptedSubscription;
  late bool _allowInsecure;
  late bool _sendHwidInCookie;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.subscription;
    _title = TextEditingController(text: s.title);
    _url = TextEditingController(text: s.url);
    _hideServerSettings = s.hideServerSettings;
    _encryptedSubscription = s.encryptedSubscription;
    _allowInsecure = s.allowInsecure;
    _sendHwidInCookie = s.sendHwidInCookie;
  }

  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final l10n = context.l10n;
    final urlChanged = _url.text.trim() != widget.subscription.url;
    final updated = widget.subscription.copyWith(
      title: _title.text.trim(),
      url: _url.text.trim(),
      hideServerSettings: _hideServerSettings,
      encryptedSubscription: _encryptedSubscription,
      allowInsecure: _allowInsecure,
      sendHwidInCookie: _sendHwidInCookie,
    );
    try {
      await context.read<SubscriptionNotifier>().updateSubscription(
            updated,
            refreshAfterChange: urlChanged,
          );
      if (!mounted) return;
      Navigator.pop(context);
      AcrylicToast.show(
        context,
        l10n.subscriptionSaved,
        icon: Icons.check_circle_rounded,
      );
    } catch (e) {
      if (!mounted) return;
      AcrylicToast.show(
        context,
        l10n.subscriptionSaveFailed(e),
        icon: Icons.error_outline_rounded,
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    const accent = Color(0xFF00D9FF);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.subscriptionEditTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Text(
                l10n.subscriptionEditOptions,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withOpacity(0.65),
                ),
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.subscriptionOptHideServers),
                value: _hideServerSettings,
                activeColor: accent,
                onChanged: (v) => setState(() => _hideServerSettings = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.subscriptionOptEncrypted),
                value: _encryptedSubscription,
                activeColor: accent,
                onChanged: (v) => setState(() => _encryptedSubscription = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.subscriptionOptAllowInsecure),
                value: _allowInsecure,
                activeColor: accent,
                onChanged: (v) => setState(() => _allowInsecure = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.subscriptionOptSendHwid),
                value: _sendHwidInCookie,
                activeColor: accent,
                onChanged: (v) => setState(() => _sendHwidInCookie = v),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.subscriptionEditHeaderUrl,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withOpacity(0.65),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _title,
                maxLength: 25,
                decoration: InputDecoration(
                  labelText: l10n.subscriptionEditNameLabel,
                  counterText: '${_title.text.length} / 25',
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return l10n.subscriptionEditNameRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _url,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l10n.subscriptionUrlLabel,
                  hintText: l10n.subscriptionUrlHint,
                ),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return l10n.subscriptionUrlRequired;
                  if (!t.startsWith('http')) return l10n.subscriptionInvalidUrl;
                  return null;
                },
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.subscriptionSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
