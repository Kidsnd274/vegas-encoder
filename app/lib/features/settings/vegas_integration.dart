import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ve_services/ve_services.dart';

import '../../design/components/button.dart';
import '../../design/components/message.dart';
import '../../design/tokens.dart';
import '../../state/services.dart';
import '../presets/panels/panel_kit.dart';

class VegasIntegrationCard extends ConsumerWidget {
  const VegasIntegrationCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = VeTokens.of(context);
    final status = ref.watch(vegasInstallationStatusProvider);
    final value = status.value;
    return Container(
      key: const ValueKey('vegas-integration'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: t.colors.surface,
        border: Border.all(color: t.colors.line2),
        borderRadius: BorderRadius.circular(VeRadius.xl),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(header: true, child: Text('VEGAS integration', style: t.text.panelTitle)),
              ),
              VeButton(
                label: 'Refresh',
                semanticLabel: 'Refresh VEGAS installations',
                size: VeButtonSize.small,
                onPressed: status.isLoading ? null : () => ref.invalidate(vegasInstallationStatusProvider),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const PanelBlurb(
            'VEGAS versions and exporter status on this PC. Use the installer to add or update Vegas Encoder.',
          ),
          const SizedBox(height: 12),
          if (status.isLoading)
            const VeMessage(level: VeLevel.info, text: 'Checking VEGAS installations…')
          else if (status.hasError)
            VeMessage(
              level: VeLevel.error,
              text: 'Could not check VEGAS installations.',
              fix: status.error is ServiceException ? (status.error! as ServiceException).message : '${status.error}',
            )
          else if (value != null)
            _HostList(snapshot: value),
          const SizedBox(height: 12),
          const PanelBlurb(
            'Verification covers recorded exporter, INI and discovery files only. Shared app/runtime integrity and host compatibility are separate checks.',
          ),
        ],
      ),
    );
  }
}

class _HostList extends StatelessWidget {
  const _HostList({required this.snapshot});

  final VegasInstallationSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final hostsByRelease = <int?, List<VegasHostStatus>>{
      2026: [],
      for (var major = 23; major >= 13; major--) major: [],
    };
    for (final host in snapshot.hosts) {
      hostsByRelease.putIfAbsent(host.releaseMajor, () => []).add(host);
    }
    final releases = hostsByRelease.keys.toList()..sort((a, b) => (b ?? 0).compareTo(a ?? 0));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        for (final release in releases)
          if (hostsByRelease[release]!.isEmpty)
            _UndetectedHost(release: release!)
          else
            for (final host in hostsByRelease[release]!) _HostStatus(key: ValueKey(host.executable), host: host),
        if (snapshot.errors.isNotEmpty) _DiscoveryDetails(errors: snapshot.errors),
      ],
    );
  }
}

class _UndetectedHost extends StatelessWidget {
  const _UndetectedHost({required this.release});

  final int release;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: t.colors.line2),
        borderRadius: BorderRadius.circular(VeRadius.md),
      ),
      child: MergeSemantics(
        child: Row(
          children: [
            Expanded(child: Text('VEGAS Pro $release', style: t.text.small)),
            Text('Not detected', style: t.text.small.copyWith(color: t.colors.muted)),
          ],
        ),
      ),
    );
  }
}

class _DiscoveryDetails extends StatefulWidget {
  const _DiscoveryDetails({required this.errors});

  final List<String> errors;

  @override
  State<_DiscoveryDetails> createState() => _DiscoveryDetailsState();
}

class _DiscoveryDetailsState extends State<_DiscoveryDetails> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        const VeMessage(level: VeLevel.warning, text: 'Some locations could not be checked.'),
        VeLinkButton(
          label: expanded ? 'Hide discovery details' : 'Show discovery details',
          onPressed: () => setState(() => expanded = !expanded),
        ),
        if (expanded)
          for (final error in widget.errors) SelectableText(error, style: t.text.small),
      ],
    );
  }
}

class _HostStatus extends StatefulWidget {
  const _HostStatus({super.key, required this.host});
  final VegasHostStatus host;
  @override
  State<_HostStatus> createState() => _HostStatusState();
}

class _HostStatusState extends State<_HostStatus> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final host = widget.host;
    final t = VeTokens.of(context);
    final (label, level) = switch (host.state) {
      VegasInstallationState.notInstalled => ('Integration not installed', VeLevel.info),
      VegasInstallationState.verified => ('Installed, verified', VeLevel.ok),
      VegasInstallationState.unverified => ('Installed, unverified', VeLevel.warning),
      VegasInstallationState.changed => ('Files missing or changed', VeLevel.warning),
      VegasInstallationState.unreadable => ('Could not check', VeLevel.error),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: t.colors.line2),
        borderRadius: BorderRadius.circular(VeRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${host.name} · ${host.version}${host.x64 ? ' · x64' : ''}', style: t.text.body),
          const SizedBox(height: 6),
          VeMessage(level: level, text: label),
          const SizedBox(height: 6),
          PanelBlurb('Exporter version: ${host.exporterVersion ?? 'Unknown / unavailable'}'),
          const SizedBox(height: 6),
          PanelBlurb(
            host.selectedHostVersion
                ? 'Recorded trial host version. Qualification of the current build is still pending.'
                : 'Detected only. This host is not qualified for Vegas Encoder.',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: VeLinkButton(
              label: expanded ? 'Hide paths and details' : 'Show paths and details',
              onPressed: () => setState(() => expanded = !expanded),
            ),
          ),
          if (expanded) ...[
            for (final (label, path) in [
              ('Host executable', host.executable),
              ('Exporter', host.exporterPath),
              ('Discovery', host.discoveryPath),
              ('Installed manifest', host.manifestPath),
            ]) ...[
              const SizedBox(height: 8),
              Text(label, style: t.text.small.copyWith(color: t.colors.muted)),
              SelectableText(path, style: t.text.monoSmall),
            ],
            for (final detail in host.details) ...[const SizedBox(height: 8), VeMessage(level: level, text: detail)],
          ],
        ],
      ),
    );
  }
}
