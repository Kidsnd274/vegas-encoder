import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ve_services/ve_services.dart';

import '../../design/components/button.dart';
import '../../design/icons.dart';
import '../../design/tokens.dart';
import '../../state/services.dart';
import 'display.dart';
import 'job_list.dart' show JobStatus;

/// The selected render (`.capd` on panel): how it went, the file, the FFmpeg
/// and command that ran, what FFmpeg said and the output check.
class JobDetail extends ConsumerWidget {
  const JobDetail({
    super.key,
    required this.entry,
    required this.onCopy,
    required this.onCopyCommand,
    required this.onOpenAsPreset,
  });

  final JobIndexEntry? entry;

  /// Copies text and confirms with the given toast.
  final void Function(String text, String toast) onCopy;
  final ValueChanged<JobRecord> onCopyCommand;
  final ValueChanged<JobRecord> onOpenAsPreset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final e = entry;
    final Widget content;
    if (e == null) {
      content = const SizedBox.shrink();
    } else {
      final record = ref.watch(jobRecordProvider(e.id));
      // hasError rather than AsyncError: a retried read keeps its error.
      content = switch (record) {
        AsyncValue(value: final r?) => _Record(
          record: r,
          onCopy: onCopy,
          onCopyCommand: onCopyCommand,
          onOpenAsPreset: onOpenAsPreset,
        ),
        AsyncValue(hasError: true, :final error) => _Problem(e, 'This render’s record couldn’t be read: $error'),
        AsyncData() => _Problem(e, 'This render’s record is missing. Only its line in the history index is left.'),
        _ => const SizedBox.shrink(),
      };
    }
    return ColoredBox(
      color: c.panel,
      child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(22, 18, 22, 24), child: content),
    );
  }
}

class _Problem extends StatelessWidget {
  const _Problem(this.entry, this.text);
  final JobIndexEntry entry;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(entry.templateName, style: t.text.popupTitle)),
        const SizedBox(height: 10),
        JobStatus(JobOutcome.of(entry.status)),
        const SizedBox(height: 8),
        Text(text, style: t.text.body.copyWith(color: t.colors.error)),
      ],
    );
  }
}

class _Record extends StatelessWidget {
  const _Record({
    required this.record,
    required this.onCopy,
    required this.onCopyCommand,
    required this.onOpenAsPreset,
  });

  final JobRecord record;
  final void Function(String text, String toast) onCopy;
  final ValueChanged<JobRecord> onCopyCommand;
  final ValueChanged<JobRecord> onOpenAsPreset;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final r = record;
    final outcome = JobOutcome.of(r.status);
    final v = r.verification;
    final ffmpeg = r.ffmpeg;
    final p = t.text.small.copyWith(color: c.text2, height: 1.5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(r.templateName, style: t.text.popupTitle)),
        const SizedBox(height: 2),
        Text(
          [if (r.project.isNotEmpty) r.project, jobTime(r.startedAt, year: true)].join(' · '),
          style: t.text.small.copyWith(color: c.muted),
        ),
        const SizedBox(height: 12),
        JobStatus(outcome),
        const SizedBox(height: 6),
        Text(resultSentence(r), style: t.text.body),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            VeButton(
              label: 'Open settings as new preset',
              icon: VeIcons.layers,
              size: VeButtonSize.small,
              onPressed: () => onOpenAsPreset(r),
            ),
            VeButton(
              label: 'Copy command',
              icon: VeIcons.copy,
              size: VeButtonSize.small,
              tooltip: 'Ctrl+Shift+C',
              onPressed: () => onCopyCommand(r),
            ),
            const VeButton(
              label: 'Open folder',
              icon: VeIcons.folder,
              size: VeButtonSize.small,
              onPressed: null,
              tooltip: 'Opening the folder needs the platform’s reveal service; the app doesn’t open Explorer itself.',
            ),
          ],
        ),
        // What went wrong comes first; the long command last but one.
        if (r.stderrTail.trim().isNotEmpty) ...[
          const _Heading('FFmpeg said'),
          _Log(r.stderrTail.trimRight()),
          const SizedBox(height: 6),
          Text(
            'The last lines of FFmpeg’s log, as the render recorded them.',
            style: t.text.caption.copyWith(color: c.muted),
          ),
        ],
        if (outcome != JobOutcome.succeeded) ...[
          const _Heading('How it stopped'),
          _Facts([
            ('FFmpeg exit code', r.ffmpegExitCode?.toString() ?? 'None: FFmpeg didn’t exit on its own'),
            if (r.hresult.isNotEmpty) ('Result code', r.hresult),
          ]),
        ],
        const _Heading('Output'),
        _PathBox(r.outputPath, label: 'Output file', onCopy: () => onCopy(r.outputPath, 'Path copied')),
        if (r.retainedPartialPath case final partial?) ...[
          const SizedBox(height: 8),
          Text('The unfinished file was kept for checking:', style: p),
          const SizedBox(height: 4),
          _PathBox(partial, label: 'Unfinished file', onCopy: () => onCopy(partial, 'Path copied')),
        ],
        const _Heading('FFmpeg'),
        _Facts(
          [
            ('Installation', ffmpeg.label),
            ('Build', ffmpegSummary(ffmpeg)),
            ('SHA-256', shortHash(ffmpeg.identity.sha256)),
          ],
          tooltips: {'SHA-256': ffmpeg.identity.sha256},
        ),
        const SizedBox(height: 8),
        _PathBox(ffmpeg.path, label: 'FFmpeg', onCopy: () => onCopy(ffmpeg.path, 'Path copied')),
        const _Heading('Output check'),
        _Facts([
          ('Result', v.message.isEmpty ? verificationLabel(v) : '${verificationLabel(v)}. ${v.message}'),
          if (v.expectedCodecs.isNotEmpty) ('Expected', v.expectedCodecs.join(', ')),
          if (v.actualCodecs.isNotEmpty) ('Found', v.actualCodecs.join(', ')),
          if (v.ffprobeVersion case final probe?) ('ffprobe', probe),
        ]),
        const _Heading('Command'),
        _CommandBlock(r),
      ],
    );
  }
}

/// `.capd h3`.
class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Semantics(
        header: true,
        child: Text(text, style: t.text.bodyStrong.copyWith(fontWeight: const FontWeight(650))),
      ),
    );
  }
}

/// Label and value pairs.
class _Facts extends StatelessWidget {
  const _Facts(this.rows, {this.tooltips = const {}});
  final List<(String, String)> rows;

  /// Full values for shortened ones, by label.
  final Map<String, String> tooltips;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 118,
                  child: Text(label, style: t.text.small.copyWith(color: c.muted)),
                ),
                Expanded(
                  child: tooltips[label] == null
                      ? Text(value, style: t.text.small.copyWith(color: c.ink))
                      : VeTooltip(
                          message: tooltips[label]!,
                          child: Text(value, style: t.text.monoSmall.copyWith(color: c.ink)),
                        ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// `.ic .p`: a path in mono on paper, cut visually with the full path in
/// the tooltip, and a copy button.
class _PathBox extends StatelessWidget {
  const _PathBox(this.path, {required this.label, required this.onCopy});
  final String path;
  final String label;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    return Row(
      children: [
        Expanded(
          child: VeTooltip(
            message: path,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: c.paper, borderRadius: BorderRadius.circular(VeRadius.sm)),
              child: Text(
                path,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                semanticsLabel: '$label: $path',
                style: t.text.monoSmall.copyWith(color: c.ink2),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        VeIconButton(icon: VeIcons.copy, label: 'Copy ${label.toLowerCase()} path', dimension: 28, onPressed: onCopy),
      ],
    );
  }
}

/// The command that ran, wrapped, executable first.
class _CommandBlock extends StatelessWidget {
  const _CommandBlock(this.record);
  final JobRecord record;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    final style = t.text.monoSmall.copyWith(color: c.ink2);
    final args = record.argv.map(quoteArgument).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: c.paper,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(VeRadius.lg),
      ),
      child: Text.rich(
        TextSpan(
          style: style,
          children: [
            TextSpan(
              text: quoteArgument(record.ffmpeg.path),
              style: style.copyWith(color: c.ink, fontWeight: const FontWeight(600)),
            ),
            for (final a in args) TextSpan(text: ' $a'),
          ],
        ),
        semanticsLabel: 'Command: ${commandLine(record)}',
      ),
    );
  }
}

/// `.log`: FFmpeg's own words, in the error colours.
class _Log extends StatelessWidget {
  const _Log(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = VeTokens.of(context);
    final c = t.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: c.errorBackground,
        border: Border.all(color: c.errorLine),
        borderRadius: BorderRadius.circular(VeRadius.lg),
      ),
      child: Text(text, style: t.text.monoSmall.copyWith(color: c.errorText)),
    );
  }
}
