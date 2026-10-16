import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ve_services/ve_services.dart';

import '../../design/components/button.dart';
import '../../design/components/title_bar.dart';
import '../../design/components/wire_progress.dart';
import '../../design/icons.dart';
import '../../design/tokens.dart';
import '../../state/app_state.dart';
import '../../state/monitor.dart';
import '../../state/services.dart';
import '../../state/settings.dart';
import 'display.dart';

/// How long the window stays after a finished or cancelled render (UI_SPEC
/// §12), unless the pointer is over it.
const doneCloseDelay = 10;
const cancelledCloseDelay = 5;

/// With no new status for this long while rendering, the footer says so: the
/// render may have stopped without the exporter writing an end (VEGAS closed
/// or crashed). It never ends the render or closes the window.
const staleAfter = Duration(seconds: 30);

/// The render progress window (`--render-monitor`, S6, UI_SPEC §12). It
/// follows one live status file (C5), never takes focus, and offers no
/// cancel: rendering is cancelled in VEGAS's own dialog. Nothing in it makes
/// VEGAS wait.
class MonitorWindow extends ConsumerStatefulWidget {
  const MonitorWindow({super.key, this.launchError});

  /// A `--render-monitor` flag without its file.
  final String? launchError;

  @override
  ConsumerState<MonitorWindow> createState() => _MonitorWindowState();
}

class _MonitorWindowState extends ConsumerState<MonitorWindow> {
  Timer? _staleTimer;
  bool _stale = false;

  Timer? _closeTimer;
  int? _closeIn;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(liveRenderStatusProvider, (_, next) => _onStatus(next.value), fireImmediately: true);
  }

  @override
  void dispose() {
    _staleTimer?.cancel();
    _closeTimer?.cancel();
    super.dispose();
  }

  void _onStatus(LiveRenderStatus? status) {
    final phase = MonitorPhase.of(status);
    _staleTimer?.cancel();
    if (_stale) setState(() => _stale = false);
    if (phase == MonitorPhase.starting || phase == MonitorPhase.encoding) {
      _staleTimer = Timer(staleAfter, () {
        if (mounted) setState(() => _stale = true);
      });
    }
    if (phase != MonitorPhase.done && phase != MonitorPhase.cancelled) {
      _closeTimer?.cancel();
      _closeTimer = null;
      _closeIn = null;
    }
    if (_closeTimer == null && (phase == MonitorPhase.done || phase == MonitorPhase.cancelled)) {
      _closeIn = phase == MonitorPhase.done ? doneCloseDelay : cancelledCloseDelay;
      _closeTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  void _tick() {
    if (!mounted || _hovered) return;
    final left = (_closeIn ?? 0) - 1;
    setState(() => _closeIn = left);
    if (left <= 0) {
      _closeTimer?.cancel();
      unawaited(ref.read(windowControllerProvider).close());
    }
  }

  /// The pin applies at once and is remembered (C7 `keepOnTop`), the same
  /// setting as in Settings. A save that fails leaves the window pinned as
  /// asked; the next window starts from what was saved.
  Future<void> _setKeepOnTop(bool value) async {
    await ref.read(windowControllerProvider).setKeepOnTop(value);
    try {
      await ref.read(machineSettingsWriterProvider).update((s) => s.copyWith(keepOnTop: value));
    } on Object {
      // Not saved; nothing else depends on it.
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final window = ref.watch(windowControllerProvider);
    final keepOnTop = ref.watch(windowStateProvider.select((s) => s.keepOnTop));
    final status = widget.launchError == null ? ref.watch(liveRenderStatusProvider).value : null;
    final phase = MonitorPhase.of(status);
    final record = status != null && phase.ended ? ref.watch(monitorJobRecordProvider(status.jobId)) : null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: ColoredBox(
        color: c.surface,
        child: Column(
          children: [
            VeTitleBar(
              height: 34,
              title: Text(widget.launchError == null ? windowTitle(status) : 'Render progress'),
              onDragStart: window.startDrag,
              onClose: window.close,
              trailing: [
                VeIconButton(
                  icon: VeIcons.pin,
                  label: 'Keep on top',
                  selected: keepOnTop,
                  dimension: 34,
                  onPressed: () => unawaited(_setKeepOnTop(!keepOnTop)),
                ),
              ],
            ),
            Expanded(
              child: ClipRect(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: switch (status) {
                    _ when widget.launchError != null => _Waiting(message: widget.launchError!),
                    null => _Waiting(message: 'Waiting for the render to start.', file: ref.watch(monitorFileProvider)),
                    final s => _Body(status: s, record: record?.value, recordLoading: record?.isLoading ?? false),
                  },
                ),
              ),
            ),
            _Footer(
              children: switch (phase) {
                MonitorPhase.done => [
                  Expanded(child: _FooterText(_closeText(_closeIn ?? doneCloseDelay))),
                  VeButton(
                    label: 'Open folder',
                    size: VeButtonSize.small,
                    onPressed: () => unawaited(_reveal(status!.outputPath)),
                  ),
                  VeButton(
                    label: 'Close',
                    size: VeButtonSize.small,
                    variant: VeButtonVariant.ghost,
                    onPressed: window.close,
                  ),
                ],
                MonitorPhase.cancelled => [
                  Expanded(child: _FooterText(_closeText(_closeIn ?? cancelledCloseDelay))),
                  VeButton(
                    label: 'Close',
                    size: VeButtonSize.small,
                    variant: VeButtonVariant.ghost,
                    onPressed: window.close,
                  ),
                ],
                MonitorPhase.failed => [
                  const Spacer(),
                  _ShowInHistory(jobId: status!.jobId),
                  _ShowLog(jobId: status.jobId, enabled: record?.value != null),
                  VeButton(label: 'Close', size: VeButtonSize.small, onPressed: window.close),
                ],
                _ => [
                  Expanded(
                    child: _FooterText(
                      _stale
                          ? 'No news from the render for ${staleAfter.inSeconds} s. If VEGAS stopped, close this.'
                          : 'Cancel the render in VEGAS.',
                    ),
                  ),
                ],
              },
            ),
          ],
        ),
      ),
    );
  }

  String _closeText(int seconds) => _hovered ? 'Stays open while the pointer is here' : 'Closes in $seconds s';

  Future<void> _reveal(String path) async {
    try {
      await ref.read(fileRevealProvider).reveal(path);
    } on ServiceException {
      // The file was moved or removed since; Explorer has nothing to show.
    }
  }
}

/// No status yet (the exporter writes the file before it starts this
/// window, so this is brief), or a launch without a file.
class _Waiting extends StatelessWidget {
  const _Waiting({required this.message, this.file});
  final String message;
  final String? file;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message, style: t.text.panelTitle),
        if (file != null) ...[
          const SizedBox(height: 4),
          Text(
            file!,
            style: t.text.caption.copyWith(color: t.colors.muted),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.status, required this.record, required this.recordLoading});
  final LiveRenderStatus status;
  final JobRecord? record;

  /// The record is still being looked for: the end sentence waits a moment
  /// rather than changing under the reader.
  final bool recordLoading;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final phase = MonitorPhase.of(status);
    final bar = barOf(status);
    final muted = t.text.small.copyWith(color: c.muted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(fileNameOf(status.outputPath), style: t.text.panelTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(headerDetail(status), style: muted, maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 14),
        VeWireProgress(fraction: bar.fraction, tone: bar.tone, semanticLabel: 'Render progress'),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Semantics(
              liveRegion: phase != MonitorPhase.encoding,
              child: Text(headline(status), style: t.text.figure),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                framesLabel(status),
                style: muted,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (!phase.ended)
          _Figures(figures: figuresOf(status))
        else if (phase == MonitorPhase.failed) ...[
          const SizedBox(height: 12),
          Expanded(
            child: _Failure(status: status, record: record),
          ),
        ] else if (!recordLoading) ...[
          const SizedBox(height: 12),
          _Result(status: status, record: record),
        ],
      ],
    );
  }
}

/// The six read-outs (`.mstats`): three columns, two rows, a rule above.
class _Figures extends StatelessWidget {
  const _Figures({required this.figures});
  final List<MonitorFigure> figures;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final value = t.text.body.copyWith(fontSize: 14, fontWeight: const FontWeight(650));
    final small = t.text.caption.copyWith(color: c.muted, fontWeight: const FontWeight(500));
    Widget cell(MonitorFigure f) => Semantics(
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(f.label, style: t.text.caption.copyWith(color: c.muted)),
          const SizedBox(height: 1),
          Text.rich(
            TextSpan(
              children: [
                if (f.prefix != null) TextSpan(text: '${f.prefix} ', style: small),
                TextSpan(
                  text: f.value ?? '–',
                  style: f.value == null ? value.copyWith(color: c.faintText) : value,
                ),
                if (f.suffix != null) TextSpan(text: ' ${f.suffix}', style: small),
              ],
            ),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.fade,
          ),
        ],
      ),
    );
    Widget row(Iterable<MonitorFigure> items) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, f) in items.indexed) ...[if (i > 0) const SizedBox(width: 12), Expanded(child: cell(f))],
      ],
    );
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: Column(children: [row(figures.take(3)), const SizedBox(height: 10), row(figures.skip(3))]),
    );
  }
}

/// How a successful or cancelled render ended.
class _Result extends StatelessWidget {
  const _Result({required this.status, required this.record});
  final LiveRenderStatus status;
  final JobRecord? record;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final phase = MonitorPhase.of(status);
    final sentence = Text(
      endSentence(status, record),
      style: t.text.body.copyWith(height: 1.45),
      maxLines: phase == MonitorPhase.done ? 3 : 2,
      overflow: TextOverflow.ellipsis,
    );
    if (phase == MonitorPhase.done) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: VeIcon(VeIcons.check, color: c.success),
          ),
          const SizedBox(width: 8),
          Expanded(child: sentence),
        ],
      );
    }
    return sentence;
  }
}

/// The engine's causal error, visible immediately from C5 and refined by C6.
/// Trailing stderr warnings belong in the full log, not in the primary panel.
class _Failure extends StatelessWidget {
  const _Failure({required this.status, required this.record});
  final LiveRenderStatus status;
  final JobRecord? record;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(
            key: const ValueKey('monitor-failure-cause'),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: c.errorBackground,
              border: Border.all(color: c.errorLine),
              borderRadius: BorderRadius.circular(6),
            ),
            child: SingleChildScrollView(
              child: Semantics(
                liveRegion: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        VeIcon(VeIcons.error, color: c.errorText),
                        const SizedBox(width: 7),
                        Text('Why it failed', style: t.text.panelTitle.copyWith(color: c.errorText)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(failureReason(status, record), style: t.text.body.copyWith(color: c.errorText, height: 1.4)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text('Stays open until you close it.', style: t.text.caption.copyWith(color: c.muted)),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = VeTokens.of(context).colors;
    return Container(
      height: 46,
      padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
      decoration: BoxDecoration(
        color: c.panel,
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          for (final (i, w) in children.indexed) ...[if (i > 0 && w is! Expanded) const SizedBox(width: 8), w],
        ],
      ),
    );
  }
}

class _FooterText extends StatelessWidget {
  const _FooterText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    return Text(
      text,
      style: t.text.caption.copyWith(color: t.colors.muted),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Opens the desktop app on this job in History. No C3 service starts the
/// desktop app yet, so it says why it can't (workstreams/app.md, Needs).
class _ShowInHistory extends ConsumerWidget {
  const _ShowInHistory({required this.jobId});
  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final launcher = ref.watch(desktopAppLauncherProvider);
    return VeButton(
      label: 'Show in History',
      size: VeButtonSize.small,
      tooltip: launcher == null ? 'Open Vegas Encoder and look in History: this window can’t open it yet.' : null,
      onPressed: launcher == null ? null : () => unawaited(launcher.openJob(jobId)),
    );
  }
}

/// Shows FFmpeg's full log for this job in Explorer, once the job record is
/// read and names one.
class _ShowLog extends ConsumerWidget {
  const _ShowLog({required this.jobId, required this.enabled});
  final String jobId;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = enabled ? ref.watch(monitorLogProvider(jobId)).value : null;
    return VeButton(
      label: 'Show log',
      size: VeButtonSize.small,
      variant: VeButtonVariant.ghost,
      tooltip: location == null ? 'FFmpeg left no log for this render.' : 'Show FFmpeg’s log file in its folder',
      onPressed: location == null
          ? null
          : () async {
              try {
                await ref.read(fileRevealProvider).reveal(location);
              } on ServiceException {
                // Removed since; nothing to show.
              }
            },
    );
  }
}
