// Maps the live render status (C5) and, once the render has ended, its job
// record (C6) to what the progress window shows (UI_SPEC §12, S6). Display
// work only: labels, sentences and formatting. Every figure is one the
// engine wrote; nothing here estimates, extrapolates or parses FFmpeg output.

import 'package:flutter/foundation.dart';
import 'package:ve_services/ve_services.dart';

import '../../design/components/wire_progress.dart' show VeWireTone;
import '../../design/format.dart';
import '../history/display.dart' show ratioLabel, resultSentence;

/// What the window's bar and labels are about.
enum MonitorPhase {
  /// No live file yet.
  waiting,
  starting,
  encoding,
  finishing,
  verifying,
  done,
  failed,
  cancelled;

  static MonitorPhase of(LiveRenderStatus? s) => switch (s?.state) {
    null => waiting,
    RenderState.starting => starting,
    RenderState.encoding => encoding,
    RenderState.finishing => finishing,
    RenderState.verifying => verifying,
    RenderState.done => done,
    RenderState.failed => failed,
    RenderState.cancelled => cancelled,
  };

  bool get ended => this == done || this == failed || this == cancelled;
}

/// "Lakeside wedding final.mp4" from a Windows path.
String fileNameOf(String path) {
  final i = path.lastIndexOf(RegExp(r'[\\/]'));
  return i < 0 ? path : path.substring(i + 1);
}

/// "D:\Renders" from a Windows path; the path itself if it has no folder.
String folderOf(String path) {
  final i = path.lastIndexOf(RegExp(r'[\\/]'));
  if (i < 0) return path;
  final folder = path.substring(0, i);
  return folder.endsWith(':') ? '$folder\\' : folder;
}

/// How far the render got, 0–1, when the total frame count is known. Rounded
/// down to whole per cent so 100% means every frame went to FFmpeg.
double? progressOf(LiveRenderStatus s) {
  final total = s.framesTotal;
  if (total == null || total <= 0) return null;
  return (s.framesDone / total).clamp(0.0, 1.0);
}

/// "42%", rounded down; null when the total is unknown.
String? percentLabel(LiveRenderStatus s) {
  final p = progressOf(s);
  return p == null ? null : '${(p * 100).floor()}%';
}

/// The title bar's text.
String windowTitle(LiveRenderStatus? s) => switch (MonitorPhase.of(s)) {
  MonitorPhase.waiting => 'Waiting for the render',
  MonitorPhase.starting => 'Starting the render',
  MonitorPhase.encoding => switch (percentLabel(s!)) {
    final p? => 'Rendering, $p',
    null => 'Rendering',
  },
  MonitorPhase.finishing => 'Finishing the file',
  MonitorPhase.verifying => 'Checking the output',
  MonitorPhase.done => 'Rendered',
  MonitorPhase.failed => 'Render failed',
  MonitorPhase.cancelled => 'Render cancelled',
};

/// The large label beside the bar: the percentage while encoding, else the
/// phase in a word.
String headline(LiveRenderStatus? s) => switch (MonitorPhase.of(s)) {
  MonitorPhase.waiting => 'Waiting',
  MonitorPhase.starting => 'Starting',
  MonitorPhase.encoding => percentLabel(s!) ?? 'Rendering',
  MonitorPhase.finishing => 'Finishing',
  MonitorPhase.verifying => 'Checking',
  MonitorPhase.done => 'Done',
  MonitorPhase.failed => 'Failed',
  MonitorPhase.cancelled => 'Cancelled',
};

/// The frame count beside the large label: "Frame 9,607 of 22,873" while
/// encoding, "22,873 frames" once they are all in (finishing, checking,
/// done), "0 of 2,832 frames" when stopped.
String framesLabel(LiveRenderStatus? s) {
  if (s == null) return '';
  final done = VeFormat.count(s.framesDone);
  final total = s.framesTotal == null ? null : VeFormat.count(s.framesTotal!);
  return switch (MonitorPhase.of(s)) {
    MonitorPhase.done || MonitorPhase.finishing || MonitorPhase.verifying => '$done frames',
    MonitorPhase.failed || MonitorPhase.cancelled => total == null ? '$done frames' : '$done of $total frames',
    _ => total == null ? 'Frame $done' : 'Frame $done of $total',
  };
}

/// The bar's fill (0–1, or null for none) and colour.
({double? fraction, VeWireTone tone}) barOf(LiveRenderStatus? s) => switch (MonitorPhase.of(s)) {
  MonitorPhase.waiting => (fraction: null, tone: VeWireTone.video),
  MonitorPhase.done => (fraction: 1.0, tone: VeWireTone.success),
  MonitorPhase.failed => (fraction: progressOf(s!) ?? 0, tone: VeWireTone.error),
  MonitorPhase.cancelled => (fraction: progressOf(s!) ?? 0, tone: VeWireTone.stopped),
  _ => (fraction: progressOf(s!), tone: VeWireTone.video),
};

/// One read-out in the figures grid. [value] null shows a dash.
@immutable
class MonitorFigure {
  const MonitorFigure(this.label, this.value, {this.prefix, this.suffix});
  final String label;
  final String? value;

  /// Small text before the value ("about").
  final String? prefix;

  /// Small text after it ("realtime", "of 6:10").
  final String? suffix;

  @override
  bool operator ==(Object other) =>
      other is MonitorFigure &&
      other.label == label &&
      other.value == value &&
      other.prefix == prefix &&
      other.suffix == suffix;

  @override
  int get hashCode => Object.hash(label, value, prefix, suffix);

  @override
  String toString() => '$label: ${[?prefix, value ?? '–', ?suffix].join(' ')}';
}

/// "61.8 fps", "142 fps".
String fpsLabel(double fps) => '${fps.toStringAsFixed(fps < 100 ? 1 : 0)} fps';

/// The six read-outs while rendering (S6). Unknown figures stay unknown.
List<MonitorFigure> figuresOf(LiveRenderStatus s) {
  final eta = s.etaSec;
  final finalBytes = s.estimatedFinalBytes;
  return [
    MonitorFigure('Encoding', s.encodeFps == null ? null : fpsLabel(s.encodeFps!)),
    MonitorFigure(
      'Speed',
      s.speed == null ? null : ratioLabel(s.speed!),
      suffix: s.speed == null ? null : 'realtime',
    ),
    MonitorFigure('Bitrate', s.bitrateKbps == null ? null : VeFormat.rate(s.bitrateKbps!)),
    MonitorFigure('Size so far', VeFormat.bytes(s.bytesWritten)),
    MonitorFigure(
      'Final size',
      finalBytes == null ? null : VeFormat.bytes(finalBytes),
      prefix: finalBytes == null ? null : 'about',
    ),
    MonitorFigure(
      'Time left',
      eta == null ? null : VeFormat.duration(eta),
      suffix: eta == null ? null : 'of ${VeFormat.duration(s.elapsedSec + eta)}',
    ),
  ];
}

/// The header's second line: the encoders while rendering or stopped, the
/// folder once the file is there.
String headerDetail(LiveRenderStatus s) =>
    MonitorPhase.of(s) == MonitorPhase.done ? folderOf(s.outputPath) : s.encoderSummary;

/// How the render ended, in one or two sentences. With the job record this is
/// History's sentence plus the output check; without it, what the live file
/// says.
String endSentence(LiveRenderStatus s, JobRecord? record) {
  final phase = MonitorPhase.of(s);
  if (phase == MonitorPhase.cancelled) {
    return 'Cancelled in VEGAS after ${VeFormat.duration(record?.elapsedSec ?? s.elapsedSec)}.';
  }
  if (record != null && record.id == s.jobId) {
    final sentence = resultSentence(record);
    if (phase != MonitorPhase.done) return sentence;
    final check = switch (record.verification.state) {
      'passed' => switch (record.verification.actualCodecs) {
        final codecs when codecs.isNotEmpty => 'Output checked: ${_and(codecs)}, as set.',
        _ => 'Output checked.',
      },
      'skipped' => 'The output wasn’t checked (Settings).',
      _ => null,
    };
    return check == null ? sentence : '$sentence $check';
  }
  final took = VeFormat.duration(s.elapsedSec);
  return switch (phase) {
    MonitorPhase.done => '${['Rendered in $took', if (s.speed != null) '${ratioLabel(s.speed!)} realtime'].join(', ')}.',
    _ => s.message.trim().isEmpty ? 'Failed after $took.' : 'Failed after $took. ${_sentence(s.message)}',
  };
}

/// The last lines FFmpeg wrote before it stopped (C6 `stderrTail`), at most
/// [lines] of them, for a failed render. Empty when there is no record or
/// FFmpeg wrote nothing.
String ffmpegLastLines(JobRecord? record, {int lines = 12}) {
  if (record == null) return '';
  final all = record.stderrTail.split(RegExp(r'\r?\n')).map((l) => l.trimRight()).where((l) => l.isNotEmpty).toList();
  return all.skip(all.length > lines ? all.length - lines : 0).join('\n');
}

String _and(List<String> items) =>
    items.length <= 1 ? items.join() : '${items.take(items.length - 1).join(', ')} and ${items.last}';

String _sentence(String text) {
  final t = text.trim();
  return t.isEmpty || '.!?'.contains(t[t.length - 1]) ? t : '$t.';
}
