import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ve_services/ve_services.dart';

import '../../design/components/button.dart';
import '../../design/components/interactive.dart';
import '../../design/components/status.dart';
import '../../design/icons.dart';
import '../../design/tokens.dart';
import '../../state/app_state.dart';
import '../../state/ffmpeg.dart';
import '../../state/services.dart';
import '../../state/setup_wizard.dart';
import 'display.dart';

/// The first-run setup (UI_SPEC §5a), modal over the desktop window. Returns
/// the installation made the default, or null when skipped or cancelled.
/// A click outside does nothing; Esc is Skip for now (Cancel once a default
/// exists).
Future<FFmpegInstallation?> showSetupWizard(BuildContext context) {
  final t = VeTokens.of(context);
  return showGeneralDialog<FFmpegInstallation>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Set up Vegas Encoder',
    barrierColor: t.shadow(t.brightness == Brightness.dark ? 0.5 : 0.28),
    transitionDuration: VeTokens.motion(context, VeDurations.short),
    pageBuilder: (_, _, _) => const SetupWizard(),
    transitionBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
  );
}

class SetupWizard extends ConsumerStatefulWidget {
  const SetupWizard({super.key});

  @override
  ConsumerState<SetupWizard> createState() => _SetupWizardState();
}

class _SetupWizardState extends ConsumerState<SetupWizard> {
  SetupWizardController get _controller => ref.read(setupWizardProvider.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_scan());
    });
  }

  Future<void> _scan() => _controller.start(
    untested: (i) => untestedHardware(i, ref.read(ffmpegControllerProvider), ref.read(profilesProvider)),
  );

  Future<void> _add() async {
    final path = await ref
        .read(windowControllerProvider)
        .pickFile(title: 'Choose ffmpeg.exe', filterName: 'FFmpeg', filterPattern: 'ffmpeg.exe');
    if (path == null || !mounted) return;
    await _controller.add(path);
  }

  bool get _hasDefault => ref.read(machineSettingsProvider).value?.defaultFFmpegId != null;

  /// Skip for now remembers the choice; Cancel (a default exists) doesn't
  /// need to.
  Future<void> _close() async {
    if (!_hasDefault) await _controller.skip();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _finish(FFmpegInstallation installation) async {
    if (await _controller.finish(installation) && mounted) Navigator.of(context).pop(installation);
  }

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final wizard = ref.watch(setupWizardProvider);
    final ffmpeg = ref.watch(ffmpegControllerProvider);
    final catalog = ref.watch(profilesProvider);
    final installations = ref.watch(discoveredInstallationsProvider).value ?? const <FFmpegInstallation>[];
    final defaultId = ref.watch(machineSettingsProvider.select((s) => s.value?.defaultFFmpegId));
    final candidates = [
      for (final i in installations) setupCandidate(i, isDefault: i.id == defaultId, state: ffmpeg, catalog: catalog),
    ];
    final recommended = recommendedCandidate(candidates);
    final selectedId = selectedCandidate(candidates, chosenId: wizard.chosenId);
    final selected = installations.where((i) => i.id == selectedId).firstOrNull;
    final busy = wizard.finding || wizard.saving;
    final height = MediaQuery.sizeOf(context).height;

    final Widget body = switch (wizard.step) {
      SetupStep.find => _FindStep(
        finding: wizard.finding,
        error: wizard.error,
        onAdd: busy ? null : _add,
        onScan: busy ? null : _scan,
      ),
      SetupStep.check || SetupStep.choose => _CandidateList(
        candidates: candidates,
        choosing: wizard.step == SetupStep.choose,
        selectedId: selectedId,
        recommendedId: recommended,
        onSelect: _controller.choose,
      ),
    };

    return Center(
      child: Shortcuts(
        shortcuts: const {SingleActivator(LogicalKeyboardKey.escape): DismissIntent()},
        child: Actions(
          actions: {
            DismissIntent: CallbackAction<DismissIntent>(onInvoke: (_) => wizard.saving ? null : unawaited(_close())),
          },
          child: FocusScope(
            autofocus: true,
            child: Semantics(
              scopesRoute: true,
              namesRoute: true,
              explicitChildNodes: true,
              label: 'Set up Vegas Encoder',
              child: Container(
                width: 660,
                constraints: BoxConstraints(maxHeight: (height - 64).clamp(320.0, 720.0)),
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border.all(color: c.line2),
                  borderRadius: BorderRadius.circular(VeRadius.xl),
                  boxShadow: t.toastShadow,
                ),
                child: DefaultTextStyle(
                  style: t.text.body,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Set up Vegas Encoder', style: t.text.popupTitle),
                            const SizedBox(height: 6),
                            Text(
                              'Vegas Encoder renders with an FFmpeg on this PC. It finds the ones installed, checks '
                              'which encoders work here, then you choose the one renders use.',
                              style: t.text.body.copyWith(color: c.text2),
                            ),
                            const SizedBox(height: 16),
                            _Steps(current: wizard.step),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(height: 1, color: c.line),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              body,
                              if (wizard.step != SetupStep.find && wizard.error != null) ...[
                                const SizedBox(height: 12),
                                _Note(icon: VeIcons.error, color: c.error, text: wizard.error!),
                              ],
                              if (wizard.step == SetupStep.choose) ...[
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: VeButton(
                                    label: 'Add FFmpeg…',
                                    icon: VeIcons.plus,
                                    size: VeButtonSize.small,
                                    variant: VeButtonVariant.ghost,
                                    onPressed: busy ? null : _add,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      Container(height: 1, color: c.line),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 12, 22, 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'You can change this any time on the FFmpeg page.',
                                style: t.text.small.copyWith(color: c.muted),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Wrap(
                              spacing: 8,
                              children: [
                                VeButton(
                                  label: defaultId == null ? 'Skip for now' : 'Cancel',
                                  variant: VeButtonVariant.ghost,
                                  onPressed: wizard.saving ? null : _close,
                                ),
                                if (wizard.step == SetupStep.check)
                                  VeButton(label: 'Choose without waiting', onPressed: _controller.skipWaiting),
                                if (wizard.step == SetupStep.choose)
                                  VeButton(
                                    label: wizard.saving ? 'Saving…' : 'Use this FFmpeg',
                                    variant: VeButtonVariant.primary,
                                    autofocus: true,
                                    tooltip: selected == null ? 'Choose an FFmpeg that is on this PC.' : null,
                                    onPressed: selected == null || busy ? null : () => _finish(selected),
                                  ),
                              ],
                            ),
                          ],
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
    );
  }
}

/// "1 Find FFmpeg · 2 Check this PC · 3 Choose the default".
class _Steps extends StatelessWidget {
  const _Steps({required this.current});
  final SetupStep current;

  static const _labels = {
    SetupStep.find: 'Find FFmpeg',
    SetupStep.check: 'Check this PC',
    SetupStep.choose: 'Choose the default',
  };

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    return Row(
      children: [
        for (final step in SetupStep.values) ...[
          if (step.index > 0)
            Expanded(
              child: Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: step.index <= current.index ? c.ink2 : c.line2,
              ),
            ),
          Semantics(
            label: 'Step ${step.index + 1} of 3, ${_labels[step]}${step == current ? ', current' : ''}',
            excludeSemantics: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: step.index <= current.index ? c.ink : null,
                    border: step.index <= current.index ? null : Border.all(color: c.line2),
                  ),
                  child: step.index < current.index
                      ? VeIcon(VeIcons.check, color: c.onInk, size: 12)
                      : Text(
                          '${step.index + 1}',
                          style: t.text.micro.copyWith(
                            color: step == current ? c.onInk : c.muted,
                            fontWeight: const FontWeight(650),
                          ),
                        ),
                ),
                const SizedBox(width: 7),
                Text(
                  _labels[step]!,
                  style: (step == current ? t.text.smallStrong : t.text.small).copyWith(
                    color: step.index <= current.index ? null : c.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Looking, nothing found, or the scan failed.
class _FindStep extends StatelessWidget {
  const _FindStep({required this.finding, required this.error, required this.onAdd, required this.onScan});
  final bool finding;
  final String? error;
  final VoidCallback? onAdd;
  final VoidCallback? onScan;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    if (finding) {
      return const _Progress(label: 'Looking on PATH and in winget, Scoop and Chocolatey…', fraction: null);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null)
          _Note(icon: VeIcons.error, color: c.error, text: 'Couldn’t look for FFmpeg: $error')
        else
          Text(
            'No FFmpeg found on this PC. Vegas Encoder needs ffmpeg.exe with ffprobe.exe beside it. Choose '
            'Add FFmpeg… if it is somewhere Scan again doesn’t look.',
            style: t.text.body.copyWith(color: c.text2),
          ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          children: [
            VeButton(label: 'Add FFmpeg…', icon: VeIcons.plus, variant: VeButtonVariant.primary, onPressed: onAdd),
            VeButton(label: error != null ? 'Try again' : 'Scan again', icon: VeIcons.refresh, onPressed: onScan),
          ],
        ),
      ],
    );
  }
}

/// The installations: checking them, then choosing one.
class _CandidateList extends StatelessWidget {
  const _CandidateList({
    required this.candidates,
    required this.choosing,
    required this.selectedId,
    required this.recommendedId,
    required this.onSelect,
  });
  final List<SetupCandidate> candidates;
  final bool choosing;
  final String? selectedId;
  final String? recommendedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          choosing
              ? 'Choose the FFmpeg every render uses.'
              : 'Checking each FFmpeg: its encoders, then a short test encode for each hardware encoder.',
          style: t.text.body.copyWith(color: t.colors.text2),
        ),
        for (final candidate in candidates) ...[
          const SizedBox(height: 10),
          _CandidateRow(
            key: ValueKey(candidate.id),
            model: candidate,
            choosing: choosing,
            selected: choosing && candidate.id == selectedId,
            recommended: candidate.id == recommendedId,
            onSelect: () => onSelect(candidate.id),
          ),
        ],
      ],
    );
  }
}

class _CandidateRow extends StatelessWidget {
  const _CandidateRow({
    super.key,
    required this.model,
    required this.choosing,
    required this.selected,
    required this.recommended,
    required this.onSelect,
  });
  final SetupCandidate model;
  final bool choosing;
  final bool selected;
  final bool recommended;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final m = model;
    final enabled = choosing && m.selectable;
    final muted = t.text.small.copyWith(color: c.muted);
    return Semantics(
      inMutuallyExclusiveGroup: choosing,
      checked: choosing ? selected : null,
      enabled: !choosing || m.selectable,
      label: [
        m.title,
        if (recommended) 'recommended',
        if (m.isDefault) 'current default',
        m.hardware,
        if (m.health case final h?) h.text,
      ].join(', '),
      child: VeInteractive(
        onTap: enabled ? onSelect : null,
        enabled: enabled,
        canRequestFocus: enabled,
        excludeChildSemantics: true,
        builder: (context, s) => VeFocusRing(
          visible: s.focused,
          radius: VeRadius.xl,
          child: AnimatedContainer(
            duration: VeTokens.motion(context, VeDurations.short),
            padding: EdgeInsets.all(selected ? 11 : 12),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(VeRadius.xl),
              border: Border.all(
                color: selected ? c.ink : (s.hovered && enabled ? c.lineHover : c.line2),
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (choosing) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: _RadioDot(on: selected, enabled: enabled),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              m.title,
                              style: t.text.panelTitle.copyWith(color: m.selectable ? null : c.muted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (recommended) ...[
                            const SizedBox(width: 8),
                            const VeStatusTag(VeAvailability.ready, label: 'Recommended'),
                          ],
                          if (m.isDefault) ...[
                            const SizedBox(width: 8),
                            Text('Current default', style: t.text.caption.copyWith(color: c.muted)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(m.line, style: muted, maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(
                        m.path,
                        style: t.text.monoSmall.copyWith(color: c.ink2),
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      if (m.progress case final p?)
                        _Progress(label: p.label, fraction: p.fraction)
                      else
                        _Note(
                          icon: VeStatusTag.iconOf(m.hardwareState),
                          color: VeStatusTag.colorOf(c, m.hardwareState),
                          text: m.hardware,
                        ),
                      if (m.health case final h?) ...[
                        const SizedBox(height: 6),
                        _Note(
                          icon: h.error ? VeIcons.error : VeIcons.warning,
                          color: h.error ? c.error : c.warning,
                          text: h.text,
                        ),
                      ],
                      if (m.failure case final f?) ...[
                        const SizedBox(height: 6),
                        _Note(icon: VeIcons.error, color: c.error, text: f),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.on, required this.enabled});
  final bool on;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = VeTokens.of(context).colors;
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: on ? c.ink : (enabled ? c.line2 : c.faint), width: on ? 5 : 1.5),
      ),
    );
  }
}

/// A probe or scan running now: its label and a thin video-wire bar.
class _Progress extends StatelessWidget {
  const _Progress({required this.label, required this.fraction});
  final String label;
  final double? fraction;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    return Semantics(
      liveRegion: true,
      label: label,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: t.text.small.copyWith(color: c.text2), maxLines: 1),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 4,
              child: Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: c.track)),
                  FractionallySizedBox(
                    widthFactor: (fraction ?? 0.15).clamp(0.0, 1.0),
                    heightFactor: 1,
                    child: ColoredBox(color: c.videoWire),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.color, required this.text});
  final VeIconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: VeIcon(icon, color: color),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: t.text.small.copyWith(color: t.colors.text2)),
        ),
      ],
    );
  }
}
