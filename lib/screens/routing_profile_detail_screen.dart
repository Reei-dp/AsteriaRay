import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/routing_profile.dart';
import '../notifiers/routing_notifier.dart';
import '../services/geo_file_manager.dart';
import '../widgets/app_dropdown_field.dart';
import 'routing_rule_list_screen.dart';
import 'routing_settings_screen.dart';

class RoutingProfileDetailScreen extends StatefulWidget {
  const RoutingProfileDetailScreen({super.key, required this.profileName});

  final String profileName;

  @override
  State<RoutingProfileDetailScreen> createState() =>
      _RoutingProfileDetailScreenState();
}

class _RoutingProfileDetailScreenState extends State<RoutingProfileDetailScreen> {
  final _geo = GeoFileManager();
  String? _workDir;
  GeoFileInfo? _geositeInfo;
  GeoFileInfo? _geoipInfo;
  bool _loadingGeo = false;

  @override
  void initState() {
    super.initState();
    _loadGeoInfo();
  }

  Future<void> _loadGeoInfo() async {
    final dir = await getApplicationSupportDirectory();
    _workDir = p.join(dir.path, 'xray');
    if (!mounted) return;
    setState(() {
      _geositeInfo = null;
      _geoipInfo = null;
    });
    final geosite = await _geo.geositeInfo(_workDir!);
    final geoip = await _geo.geoipInfo(_workDir!);
    if (!mounted) return;
    setState(() {
      _geositeInfo = geosite;
      _geoipInfo = geoip;
    });
  }

  Future<void> _refreshGeo({required bool geosite, required RoutingProfile profile}) async {
    if (_workDir == null) return;
    setState(() => _loadingGeo = true);
    try {
      if (geosite) {
        await _geo.refreshGeosite(_workDir!, profile);
      } else {
        await _geo.refreshGeoip(_workDir!, profile);
      }
      await _loadGeoInfo();
    } finally {
      if (mounted) setState(() => _loadingGeo = false);
    }
  }

  Future<void> _save(RoutingProfile updated) async {
    await context.read<RoutingNotifier>().updateProfile(updated);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final profile = context.watch<RoutingNotifier>().profileByName(widget.profileName);
    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.routingRulesTitle)),
        body: Center(child: Text(l10n.routingProfileMissing)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.routingRulesTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.routingProfileNameLabel),
            trailing: Text(profile.name),
          ),
          const SizedBox(height: 12),
          _SectionTitle(l10n.routingGeoSection),
          _GeoFileTile(
            title: l10n.routingGeositeFile,
            url: profile.effectiveGeositeUrl,
            info: _geositeInfo,
            loading: _loadingGeo,
            onRefresh: () => _refreshGeo(geosite: true, profile: profile),
          ),
          const Divider(height: 1),
          _GeoFileTile(
            title: l10n.routingGeoipFile,
            url: profile.effectiveGeoipUrl,
            info: _geoipInfo,
            loading: _loadingGeo,
            onRefresh: () => _refreshGeo(geosite: false, profile: profile),
          ),
          const SizedBox(height: 12),
          _SectionTitle(l10n.routingDomainSection),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.routingFakeDns),
            value: profile.fakeDns,
            onChanged: (v) => _save(profile.copyWith(fakeDns: v)),
          ),
          AppDropdownField<String>(
            label: l10n.routingDomainStrategy,
            value: profile.domainStrategy,
            items: const [
              AppDropdownItem(value: 'AsIs', label: 'AsIs'),
              AppDropdownItem(value: 'IPIfNonMatch', label: 'IPIfNonMatch'),
              AppDropdownItem(value: 'IPOnDemand', label: 'IPOnDemand'),
            ],
            onChanged: (v) {
              if (v != null) _save(profile.copyWith(domainStrategy: v));
            },
          ),
          const SizedBox(height: 12),
          _SectionTitle(l10n.routingRemoteDnsSection),
          _DnsRow(profile: profile, isRemote: true, onChanged: _save),
          const SizedBox(height: 12),
          _SectionTitle(l10n.routingDomesticDnsSection),
          _DnsRow(profile: profile, isRemote: false, onChanged: _save),
          const SizedBox(height: 12),
          _SectionTitle(l10n.routingProxySection),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.routingGlobalProxy),
            subtitle: Text(l10n.routingGlobalProxyHint, style: theme.textTheme.bodySmall),
            value: profile.globalProxy,
            onChanged: (v) => _save(profile.copyWith(globalProxy: v)),
          ),
          const SizedBox(height: 12),
          _SectionTitle(l10n.routingRulesSection),
          _RuleNavTile(
            title: l10n.routingProxyRules,
            count: profile.proxySites.length + profile.proxyIp.length,
            onTap: () => _openRules(profile, RouteRuleKind.proxy),
          ),
          _RuleNavTile(
            title: l10n.routingDirectRules,
            count: profile.directSites.length + profile.directIp.length,
            onTap: () => _openRules(profile, RouteRuleKind.direct),
          ),
          _RuleNavTile(
            title: l10n.routingBlockRules,
            count: profile.blockSites.length + profile.blockIp.length,
            onTap: () => _openRules(profile, RouteRuleKind.block),
          ),
          const SizedBox(height: 12),
          _SectionTitle(l10n.routingOrderSection),
          AppDropdownField<RouteOrder>(
            label: l10n.routingOrderLabel,
            value: profile.routeOrder,
            items: [
              for (final o in RouteOrder.values)
                AppDropdownItem(value: o, label: o.labels(l10n)),
            ],
            onChanged: (v) {
              if (v != null) _save(profile.copyWith(routeOrder: v));
            },
          ),
          const SizedBox(height: 24),
          Center(
            child: TextButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l10n.routingDeleteProfile),
                    content: Text(l10n.routingDeleteProfileBody),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(l10n.cancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(l10n.delete),
                      ),
                    ],
                  ),
                );
                if (ok != true || !context.mounted) return;
                await context.read<RoutingNotifier>().deleteProfile(profile.name);
                if (!context.mounted) return;
                Navigator.pop(context);
              },
              child: Text(
                l10n.routingDeleteProfile,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openRules(RoutingProfile profile, RouteRuleKind kind) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RoutingRuleListScreen(profile: profile, kind: kind),
      ),
    );
  }
}

class _GeoFileTile extends StatelessWidget {
  const _GeoFileTile({
    required this.title,
    required this.url,
    required this.info,
    required this.loading,
    required this.onRefresh,
  });

  final String title;
  final String url;
  final GeoFileInfo? info;
  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            url,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.55),
            ),
          ),
          if (info != null) ...[
            const SizedBox(height: 6),
            Text(
              formatGeoFileMeta(info!.updatedAt, info!.sizeBytes, l10n),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.72),
              ),
            ),
          ],
        ],
      ),
      trailing: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: onRefresh,
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.85),
            ),
      ),
    );
  }
}

class _RuleNavTile extends StatelessWidget {
  const _RuleNavTile({
    required this.title,
    required this.count,
    required this.onTap,
  });

  final String title;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (count > 0)
            Text('$count', style: Theme.of(context).textTheme.bodySmall),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _DnsRow extends StatefulWidget {
  const _DnsRow({
    required this.profile,
    required this.isRemote,
    required this.onChanged,
  });

  final RoutingProfile profile;
  final bool isRemote;
  final ValueChanged<RoutingProfile> onChanged;

  @override
  State<_DnsRow> createState() => _DnsRowState();
}

class _DnsRowState extends State<_DnsRow> {
  late final TextEditingController _ip;
  late final TextEditingController _domain;

  @override
  void initState() {
    super.initState();
    _ip = TextEditingController(
      text: widget.isRemote ? widget.profile.remoteDnsIp : widget.profile.domesticDnsIp,
    );
    _domain = TextEditingController(
      text: widget.isRemote
          ? widget.profile.remoteDnsDomain
          : widget.profile.domesticDnsDomain,
    );
  }

  @override
  void dispose() {
    _ip.dispose();
    _domain.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = widget.isRemote ? widget.profile.remoteDnsType : widget.profile.domesticDnsType;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppDropdownField<DnsType>(
          label: widget.isRemote ? l10n.routingRemoteDnsType : l10n.routingDomesticDnsType,
          value: type,
          items: const [
            AppDropdownItem(value: DnsType.dou, label: 'DoU'),
            AppDropdownItem(value: DnsType.doh, label: 'DoH'),
          ],
          onChanged: (v) {
            if (v == null) return;
            widget.onChanged(widget.isRemote
                ? widget.profile.copyWith(remoteDnsType: v)
                : widget.profile.copyWith(domesticDnsType: v));
          },
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _ip,
          decoration: InputDecoration(
            labelText: widget.isRemote ? l10n.routingRemoteIp : l10n.routingDomesticIp,
          ),
          onSubmitted: (v) => widget.onChanged(widget.isRemote
              ? widget.profile.copyWith(remoteDnsIp: v.trim())
              : widget.profile.copyWith(domesticDnsIp: v.trim())),
        ),
        if (type == DnsType.doh) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _domain,
            decoration: InputDecoration(labelText: l10n.routingDnsDomain),
            onSubmitted: (v) => widget.onChanged(widget.isRemote
                ? widget.profile.copyWith(remoteDnsDomain: v.trim())
                : widget.profile.copyWith(domesticDnsDomain: v.trim())),
          ),
        ],
      ],
    );
  }
}
