import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/stored_vpn_profile.dart';
import '../models/vless_profile.dart';
import '../widgets/acrylic_toast.dart';
import '../models/vless_types.dart';
import '../notifiers/profile_notifier.dart';
import '../widgets/app_dropdown_field.dart';

class ProfileFormScreen extends StatefulWidget {
  const ProfileFormScreen({
    super.key,
    this.profile,
    this.embedded = false,
  });

  final VlessProfile? profile;
  final bool embedded;

  @override
  State<ProfileFormScreen> createState() => ProfileFormScreenState();
}

class ProfileFormScreenState extends State<ProfileFormScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => widget.embedded;
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _uuid;
  late final TextEditingController _flow;
  late final TextEditingController _sni;
  late final TextEditingController _alpn;
  late final TextEditingController _fingerprint;
  late final TextEditingController _path;
  late final TextEditingController _hostHeader;
  late final TextEditingController _remark;
  late final TextEditingController _uriImport;
  String _security = 'none';
  VlessTransport _transport = VlessTransport.tcp;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _name = TextEditingController(text: p?.name ?? '');
    _host = TextEditingController(text: p?.host ?? '');
    _port = TextEditingController(text: p?.port.toString() ?? '');
    _uuid = TextEditingController(text: p?.uuid ?? '');
    _flow = TextEditingController(text: p?.flow ?? '');
    _sni = TextEditingController(text: p?.sni ?? '');
    _alpn = TextEditingController(text: p?.alpn.join(',') ?? '');
    _fingerprint = TextEditingController(text: p?.fingerprint ?? '');
    _path = TextEditingController(text: p?.path ?? '');
    _hostHeader = TextEditingController(text: p?.hostHeader ?? '');
    _remark = TextEditingController(text: p?.remark ?? '');
    _uriImport = TextEditingController();
    _security = p?.security ?? 'none';
    _transport = p?.transport ?? VlessTransport.tcp;
  }

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _port.dispose();
    _uuid.dispose();
    _flow.dispose();
    _sni.dispose();
    _alpn.dispose();
    _fingerprint.dispose();
    _path.dispose();
    _hostHeader.dispose();
    _remark.dispose();
    _uriImport.dispose();
    super.dispose();
  }

  static const _radius = 14.0;
  static const _padding = EdgeInsets.symmetric(horizontal: 16, vertical: 16);

  InputDecoration _fieldDecoration(
    BuildContext context, {
    required String labelText,
    IconData? prefixIcon,
    Widget? suffixIcon,
    String? hintText,
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
            ..._buildFormFields(context, theme, colorScheme, l10n),
            if (!widget.embedded) ...[
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: submit,
                  icon: const Icon(Icons.save_rounded),
                  label: Text(l10n.saveConfig),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_radius),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );

    if (widget.embedded) return formBody;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? l10n.editConfig : l10n.newConfig,
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

  List<Widget> _buildFormFields(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    return [
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
                            Icons.link_rounded,
                            color: colorScheme.primary,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            l10n.importFromUri,
                            style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _uriImport,
                        decoration: _fieldDecoration(
                          context,
                          labelText: 'VLESS URI',
                          hintText: 'vless://...',
                          prefixIcon: Icons.link_rounded,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.paste_rounded),
                            onPressed: _pasteUri,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed: _applyUri,
                          icon: const Icon(Icons.download_rounded),
                          label: Text(l10n.fillFromUri),
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
                l10n.basicParams,
                style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                decoration: _fieldDecoration(
                  context,
                  labelText: l10n.nameLabel,
                  prefixIcon: Icons.label_rounded,
                ),
                validator: (v) => (v == null || v.isEmpty)
                    ? l10n.nameRequired
                    : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _host,
                      decoration: _fieldDecoration(
                        context,
                        labelText: l10n.hostLabel,
                        prefixIcon: Icons.dns_rounded,
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? l10n.hostRequired
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _port,
                      decoration: _fieldDecoration(
                        context,
                        labelText: l10n.portLabel,
                        prefixIcon: Icons.numbers_rounded,
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final value = int.tryParse(v ?? '');
                        if (value == null) return l10n.portInvalid;
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _uuid,
                decoration: _fieldDecoration(
                  context,
                  labelText: l10n.uuidLabel,
                  prefixIcon: Icons.vpn_key_rounded,
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? l10n.uuidRequired : null,
              ),
              const SizedBox(height: 28),
              Text(
                l10n.securityTransport,
                style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              AppDropdownField<String>(
                label: l10n.securityLabel,
                prefixIcon: Icons.lock_rounded,
                value: _security,
                items: const [
                  AppDropdownItem(value: 'none', label: 'none'),
                  AppDropdownItem(value: 'tls', label: 'tls'),
                  AppDropdownItem(value: 'reality', label: 'reality'),
                ],
                onChanged: (v) => setState(() => _security = v),
              ),
              const SizedBox(height: 16),
              AppDropdownField<VlessTransport>(
                label: l10n.transportLabel,
                prefixIcon: Icons.network_check_rounded,
                value: _transport,
                items: [
                  for (final t in VlessTransport.values)
                    AppDropdownItem(
                      value: t,
                      label: transportToString(t),
                    ),
                ],
                onChanged: (v) => setState(() => _transport = v),
              ),
              const SizedBox(height: 28),
              Text(
                l10n.advancedParams,
                style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _sni,
                decoration: _fieldDecoration(
                  context,
                  labelText: 'SNI',
                  prefixIcon: Icons.domain_rounded,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _alpn,
                decoration: _fieldDecoration(
                  context,
                  labelText: 'ALPN через запятую',
                  prefixIcon: Icons.code_rounded,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fingerprint,
                decoration: _fieldDecoration(
                  context,
                  labelText: 'Fingerprint',
                  prefixIcon: Icons.fingerprint_rounded,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _flow,
                decoration: _fieldDecoration(
                  context,
                  labelText: 'Flow (например xtls-rprx-vision)',
                  prefixIcon: Icons.swap_horiz_rounded,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _path,
                decoration: _fieldDecoration(
                  context,
                  labelText: 'Path/ServiceName',
                  prefixIcon: Icons.route_rounded,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _hostHeader,
                decoration: _fieldDecoration(
                  context,
                  labelText: 'Host Header',
                  prefixIcon: Icons.http_rounded,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _remark,
                decoration: _fieldDecoration(
                  context,
                  labelText: l10n.descriptionLabel,
                  prefixIcon: Icons.description_rounded,
                ),
                maxLines: 3,
              ),
    ];
  }

  Future<void> submit() => _submit();

  Future<void> _pasteUri() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    setState(() {
      _uriImport.text = text;
    });
  }

  Future<void> _applyUri() async {
    final raw = _uriImport.text.trim();
    if (raw.isEmpty) return;
    try {
      final profile = VlessProfile.fromUri(raw);
      setState(() {
        _name.text = profile.name;
        _host.text = profile.host;
        _port.text = profile.port.toString();
        _uuid.text = profile.uuid;
        _flow.text = profile.flow ?? '';
        _sni.text = profile.sni ?? '';
        _alpn.text = profile.alpn.join(',');
        _fingerprint.text = profile.fingerprint ?? '';
        _transport = profile.transport;
        _path.text = profile.path ?? '';
        _hostHeader.text = profile.hostHeader ?? '';
        _remark.text = profile.remark ?? '';
        _security = profile.security;
      });
    } catch (e) {
      AcrylicToast.show(
        context,
        context.l10n.uriError(e),
        icon: Icons.error_outline_rounded,
        isError: true,
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final alpn = _alpn.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final notifier = context.read<ProfileNotifier>();
    final port = int.tryParse(_port.text) ?? 443;

    if (widget.profile == null) {
      await notifier.createManual(
        name: _name.text.trim(),
        host: _host.text.trim(),
        port: port,
        uuid: _uuid.text.trim(),
        security: _security,
        sni: _sni.text.trim().isEmpty ? null : _sni.text.trim(),
        alpn: alpn,
        fingerprint:
            _fingerprint.text.trim().isEmpty ? null : _fingerprint.text.trim(),
        flow: _flow.text.trim().isEmpty ? null : _flow.text.trim(),
        transport: _transport,
        path: _path.text.trim().isEmpty ? null : _path.text.trim(),
        hostHeader:
            _hostHeader.text.trim().isEmpty ? null : _hostHeader.text.trim(),
        remark: _remark.text.trim().isEmpty ? null : _remark.text.trim(),
      );
    } else {
      final updated = widget.profile!.copyWith(
        name: _name.text.trim(),
        host: _host.text.trim(),
        port: port,
        uuid: _uuid.text.trim(),
        security: _security,
        sni: _sni.text.trim().isEmpty ? null : _sni.text.trim(),
        alpn: alpn,
        fingerprint:
            _fingerprint.text.trim().isEmpty ? null : _fingerprint.text.trim(),
        flow: _flow.text.trim().isEmpty ? null : _flow.text.trim(),
        transport: _transport,
        path: _path.text.trim().isEmpty ? null : _path.text.trim(),
        hostHeader:
            _hostHeader.text.trim().isEmpty ? null : _hostHeader.text.trim(),
        remark: _remark.text.trim().isEmpty ? null : _remark.text.trim(),
      );
      await notifier.addOrUpdate(VlessStoredVpnProfile(updated));
    }

    if (mounted) {
      AcrylicToast.show(
        context,
        widget.profile == null ? context.l10n.configAdded : context.l10n.configSaved,
        icon: Icons.check_circle_rounded,
        duration: const Duration(seconds: 1),
      );
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) Navigator.of(context).pop();
    }
  }
}

