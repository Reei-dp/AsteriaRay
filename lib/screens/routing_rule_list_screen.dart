import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/routing_profile.dart';
import '../notifiers/routing_notifier.dart';

enum RouteRuleKind { proxy, direct, block }

class RoutingRuleListScreen extends StatefulWidget {
  const RoutingRuleListScreen({
    super.key,
    required this.profile,
    required this.kind,
  });

  final RoutingProfile profile;
  final RouteRuleKind kind;

  @override
  State<RoutingRuleListScreen> createState() => _RoutingRuleListScreenState();
}

class _RoutingRuleListScreenState extends State<RoutingRuleListScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _initialText());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _initialText() {
    final lines = <String>[
      ..._sites(),
      ..._ips(),
    ];
    return lines.join('\n');
  }

  List<String> _sites() {
    return switch (widget.kind) {
      RouteRuleKind.proxy => widget.profile.proxySites,
      RouteRuleKind.direct => widget.profile.directSites,
      RouteRuleKind.block => widget.profile.blockSites,
    };
  }

  List<String> _ips() {
    return switch (widget.kind) {
      RouteRuleKind.proxy => widget.profile.proxyIp,
      RouteRuleKind.direct => widget.profile.directIp,
      RouteRuleKind.block => widget.profile.blockIp,
    };
  }

  String _title(AppLocalizations l10n) {
    return switch (widget.kind) {
      RouteRuleKind.proxy => l10n.routingProxyRules,
      RouteRuleKind.direct => l10n.routingDirectRules,
      RouteRuleKind.block => l10n.routingBlockRules,
    };
  }

  RoutingProfile _buildProfile(List<String> lines) {
    final sites = <String>[];
    final ips = <String>[];
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      if (line.startsWith('geoip:') ||
          line.contains('/') ||
          RegExp(r'^\d+\.\d+\.\d+\.\d+').hasMatch(line)) {
        ips.add(line);
      } else {
        sites.add(line);
      }
    }
    return switch (widget.kind) {
      RouteRuleKind.proxy => widget.profile.copyWith(
          proxySites: sites,
          proxyIp: ips,
        ),
      RouteRuleKind.direct => widget.profile.copyWith(
          directSites: sites,
          directIp: ips,
        ),
      RouteRuleKind.block => widget.profile.copyWith(
          blockSites: sites,
          blockIp: ips,
        ),
    };
  }

  Future<void> _save() async {
    final lines = _controller.text.split(RegExp(r'\r?\n'));
    final updated = _buildProfile(lines);
    await context.read<RoutingNotifier>().updateProfile(updated);
    if (!mounted) return;
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(_title(l10n)),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(l10n.routingSaveUpper),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.routingRulesEditorHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: 'geosite:ru\ngeoip:private',
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
