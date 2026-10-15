import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ve_services/ve_services.dart';

import '../../design/components/button.dart';
import '../../design/components/dialog.dart';
import '../../design/components/wire_progress.dart';
import '../../design/icons.dart';
import '../../design/tokens.dart';
import '../../state/editor.dart';
import '../../state/preset_test.dart';
import '../../state/services.dart';
import 'test_display.dart';

/// "Test this preset" (UI_SPEC §2): the chosen FFmpeg encodes synthetic
/// frames and a tone with [recipe], then the file is checked as a render's
/// is (C3 `PresetTests`). The panel shows how far it got, the result and
/// FFmpeg's output as it streams. Closing stops a test that is still running.
Future<void> showPresetTest(
  BuildContext context, {
  required String name,
  required Recipe recipe,
  required FFmpegInstallation installation,
}) => showVeDialog<void>(
  context,
  title: 'Test “$name”',
  width: 600,
  content: PresetTestPanel(recipe: recipe, installation: installation),
  actions: const [VeDialogAction('Close', null)],
);

/// Why "Test this preset" can't run for what the editor shows, or null when
/// it can: it needs an FFmpeg, and a command the core built without errors
/// (the service compiles the same settings and refuses errors itself).
String? presetTestBlocked(EditorData data) {
  if (data.installation == null) return 'Add an FFmpeg on the FFmpeg page to test presets.';
  if (!data.compiled.ok) return 'The test needs the command, which the core couldn’t build.';
  final lintErrors = data.lint?.value?.any((d) => d.level == IssueLevel.error) ?? false;
  if (data.hasErrors || lintErrors) return 'Fix the errors first: FFmpeg would stop at them.';
  return null;
}

class PresetTestPanel extends ConsumerStatefulWidget {
  const PresetTestPanel({super.key, required this.recipe, required this.installation});
  final Recipe recipe;
  final FFmpegInstallation installation;

  @override
  ConsumerState<PresetTestPanel> createState() => _PresetTestPanelState();
}

class _PresetTestPanelState extends ConsumerState<PresetTestPanel> {
  late PresetTestRequest _request = PresetTestRequest(widget.recipe, widget.installation);

  Future<void> _reveal(String path) async {
    try {
      await ref.read(fileRevealProvider).reveal(path);
    } on ServiceException {
      // Removed since; Explorer has nothing to show.
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final state = ref.watch(presetTestProvider(_request));
    final view = presetTestView(state);
    final p = state.latest;
    final quiet = t.text.small.copyWith(color: c.muted);

    final (icon, color) = switch (view.outcome) {
      PresetTestOutcome.passed => (VeIcons.check, c.success),
      PresetTestOutcome.failed => (VeIcons.error, c.error),
      PresetTestOutcome.stopped => (VeIcons.dash, c.muted),
      PresetTestOutcome.running => (VeIcons.flask, c.ink),
    };
    final tone = switch (view.outcome) {
      PresetTestOutcome.passed => VeWireTone.success,
      PresetTestOutcome.failed => VeWireTone.error,
      PresetTestOutcome.stopped => VeWireTone.stopped,
      PresetTestOutcome.running => VeWireTone.video,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${widget.installation.label} encodes a few seconds of test pattern and tone with these settings, then '
          'the file is checked the way a render’s is. VEGAS isn’t involved.',
          style: t.text.body.copyWith(color: c.text2),
        ),
        const SizedBox(height: 14),
        Semantics(
          liveRegion: true,
          container: true,
          child: Row(
            children: [
              VeIcon(icon, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(view.headline, style: t.text.bodyStrong.copyWith(color: color)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        VeWireProgress(
          fraction: view.outcome == PresetTestOutcome.running ? view.fraction : (view.fraction ?? 1),
          tone: tone,
          semanticLabel: 'Test progress',
        ),
        if (view.detail case final detail?) ...[const SizedBox(height: 8), Text(detail, style: t.text.body)],
        if (view.facts.isNotEmpty) ...[
          const SizedBox(height: 6),
          for (final (label, value) in view.facts)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  SizedBox(width: 80, child: Text(label, style: quiet)),
                  Expanded(
                    child: Text(value, style: t.text.small.copyWith(color: c.ink)),
                  ),
                ],
              ),
            ),
        ],
        if (view.sample) ...[
          const SizedBox(height: 6),
          Text('Sample result from the platform’s test service: nothing ran.', style: quiet),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                presetTestLogSummary(state, state.log),
                style: quiet,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (p?.logPath case final log?)
              VeButton(
                label: 'Show log',
                icon: VeIcons.folder,
                size: VeButtonSize.small,
                variant: VeButtonVariant.ghost,
                tooltip: 'Show the test’s FFmpeg log in Explorer',
                onPressed: () => unawaited(_reveal(log)),
              ),
            if (!state.running && p?.outputPath != null)
              VeButton(
                label: 'Show file',
                icon: VeIcons.folder,
                size: VeButtonSize.small,
                variant: VeButtonVariant.ghost,
                tooltip: 'Show the test file in Explorer',
                onPressed: () => unawaited(_reveal(p!.outputPath!)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        _TestLog(state.log),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: state.running
              ? VeButton(
                  label: 'Stop test',
                  size: VeButtonSize.small,
                  onPressed: () => unawaited(ref.read(presetTestProvider(_request).notifier).stop()),
                )
              : VeButton(
                  label: 'Test again',
                  icon: VeIcons.refresh,
                  size: VeButtonSize.small,
                  onPressed: () => setState(() => _request = PresetTestRequest(widget.recipe, widget.installation)),
                ),
        ),
      ],
    );
  }
}

/// FFmpeg's output in mono on paper, at most 180 px tall, kept at its end.
class _TestLog extends StatelessWidget {
  const _TestLog(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    return Container(
      constraints: const BoxConstraints(minHeight: 40, maxHeight: 180),
      decoration: BoxDecoration(
        color: c.paper,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(VeRadius.lg),
      ),
      child: SingleChildScrollView(
        reverse: true,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        child: SizedBox(
          width: double.infinity,
          child: Text(text.trimRight(), style: t.text.monoSmall.copyWith(color: c.ink2)),
        ),
      ),
    );
  }
}
