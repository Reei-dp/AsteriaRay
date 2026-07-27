import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/amnezia_wg_profile.dart';
import '../notifiers/profile_notifier.dart';
import '../services/config_import_detector.dart';
import '../widgets/acrylic_toast.dart';

class AmneziaWgFormScreen extends StatefulWidget {
  const AmneziaWgFormScreen({
    super.key,
    this.profile,
    this.embedded = false,
  });

  final AmneziaWgProfile? profile;
  final bool embedded;

  @override
  State<AmneziaWgFormScreen> createState() => AmneziaWgFormScreenState();
}

class AmneziaWgFormScreenState extends State<AmneziaWgFormScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => widget.embedded;
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _conf;

  static const _radius = 14.0;
  static const _padding = EdgeInsets.symmetric(horizontal: 16, vertical: 16);

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _name = TextEditingController(text: p?.name ?? '');
    _conf = TextEditingController(text: p?.conf ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _conf.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(
    BuildContext context, {
    required String labelText,
    IconData? prefixIcon,
    Widget? suffixIcon,
    String? hintText,
    String? helperText,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(_radius),
      borderSide: BorderSide(
        color: colorScheme.outline.withOpacity(0.35),
        width: 1,
      ),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(_radius),
      borderSide: BorderSide(
        color: colorScheme.primary.withOpacity(0.7),
        width: 1.5,
      ),
    );
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      helperText: helperText,
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, size: 22, color: colorScheme.onSurface.withOpacity(0.6))
          : null,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
      contentPadding: _padding,
      border: border,
      enabledBorder: border,
      focusedBorder: focusedBorder,
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: BorderSide(color: colorScheme.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: BorderSide(color: colorScheme.error, width: 1.5),
      ),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
    );
  }

  String? _validateConf(String? value, AppLocalizations l10n) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return l10n.confRequired;
    }
    if (ConfigImportDetector.detect(text) != ConfigImportKind.wireGuardConf) {
      return l10n.confInvalid;
    }
    return null;
  }

  Future<void> _pasteConf() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      if (mounted) {
        AcrylicToast.show(
          context,
          context.l10n.clipboardEmpty,
          icon: Icons.content_paste_rounded,
        );
      }
      return;
    }
    setState(() {
      _conf.text = text;
      if (_name.text.trim().isEmpty) {
        final derived = AmneziaWgProfile.fromConf(
          text,
          id: 'draft',
          fallbackName: null,
        );
        _name.text = derived.name;
      }
    });
  }

  Future<void> submit() => _submit();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final conf = _conf.text.trim();
    final name = _name.text.trim();
    final notifier = context.read<ProfileNotifier>();

    await notifier.saveManualAwg(
      conf: conf,
      name: name,
      existingId: widget.profile?.id,
    );

    if (!mounted) return;
    AcrylicToast.show(
      context,
      widget.profile == null ? context.l10n.configAdded : context.l10n.configSaved,
      icon: Icons.check_circle_rounded,
      duration: const Duration(seconds: 1),
    );
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEditing = widget.profile != null;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;

    final formBody = SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.content_paste_rounded,
                          color: colorScheme.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          l10n.pasteConfTitle,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.pasteConfHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.65),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: _pasteConf,
                        icon: const Icon(Icons.paste_rounded),
                        label: Text(l10n.pasteFromClipboard),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(_radius),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              l10n.params,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: _fieldDecoration(
                context,
                labelText: l10n.nameLabel,
                prefixIcon: Icons.label_outline_rounded,
                hintText: 'NL Mock, Home AWG…',
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _conf,
              decoration: _fieldDecoration(
                context,
                labelText: l10n.confLabel,
                prefixIcon: Icons.description_outlined,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.paste_rounded),
                  onPressed: _pasteConf,
                ),
                helperText: l10n.awgConfHelper,
              ),
              validator: (v) => _validateConf(v, l10n),
              minLines: 14,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.embedded) return formBody;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? l10n.editAwg : l10n.newAwg,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton.icon(
            onPressed: submit,
            icon: const Icon(Icons.check_rounded),
            label: Text(l10n.save),
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.primary,
            ),
          ),
        ],
      ),
      body: formBody,
    );
  }
}
