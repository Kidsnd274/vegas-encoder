// Maps job records (C6) to what History shows. Display work only: labels,
// sentences and formatting. Every figure comes from the record the engine
// wrote. Records from before B4 lack the realtime figure and the core's
// command line; their speed stays unknown and the command is quoted here.

import 'package:ve_services/ve_services.dart' as core;

import '../../design/format.dart';
import '../presets/display.dart' show CatalogLookup;

/// How a render ended (C6 `status`).
enum JobOutcome {
  succeeded('Succeeded'),
  failed('Failed'),
  cancelled('Cancelled'),
  other('Unknown');

  const JobOutcome(this.label);
  final String label;

  static JobOutcome of(String status) => switch (status) {
    'succeeded' => succeeded,
    'failed' => failed,
    'cancelled' => cancelled,
    _ => other,
  };
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "12 Oct, 14:00" in local time; [year] adds the year ("12 Oct 2026, 14:00").
/// An unreadable timestamp shows as written.
String jobTime(String utc, {bool year = false}) {
  final parsed = DateTime.tryParse(utc);
  if (parsed == null) return utc;
  final d = parsed.toLocal();
  final hm = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  return '${d.day} ${_months[d.month - 1]}${year ? ' ${d.year}' : ''}, $hm';
}

/// The recorded realtime figure (C6 `realtime`): "0.51×". Only for a
/// finished render. Older records leave it unknown; length/time is not
/// FFmpeg's recorded encoding speed.
double? realtimeRatio(core.JobRecord r) => r.status == 'succeeded' ? r.realtime : null;

/// "0.51×", "2.31×", "12.4×".
String ratioLabel(double ratio) => '${ratio.toStringAsFixed(ratio < 10 ? 2 : 1)}×';

/// The encoder that ran, as the catalog names it ("x264"). An Advanced
/// command shows as such: its Basic settings were not what ran. Video off
/// names the audio encoder.
String encoderLabel(core.JobRecord r, core.ProfileCatalog catalog) {
  final recipe = r.recipe;
  if (recipe.command.mode == 'template') return 'Advanced command';
  if (!recipe.video.enabled) {
    final audio = recipe.audio.first.encoder;
    return catalog.audioEncoder(audio)?.label ?? audio;
  }
  final video = recipe.video.encoder;
  return catalog.videoEncoder(video)?.label ?? video;
}

/// The file's size when the render published it, else why there is none.
String sizeLabel(core.JobRecord r) => r.published ? VeFormat.bytes(r.sizeBytes) : 'No file';

// ------------------------------------------------------------ the list (index)
//
// The list reads only the index (C6 `jobs.jsonl`), never a record per row.
// Its summary fields are optional: an entry written before they existed
// leaves them null, and an unknown figure stays a dash.

/// The encoders as the engine summarised them ("x264 CRF 18 / AAC 320 kb/s");
/// null when the index doesn't say.
String? indexEncoder(core.JobIndexEntry e) {
  final s = e.encoderSummary?.trim();
  return s == null || s.isEmpty ? null : s;
}

/// The project ("Lakeside wedding final.veg"); null when the index doesn't say.
String? indexProject(core.JobIndexEntry e) {
  final p = e.project?.trim();
  return p == null || p.isEmpty ? null : p;
}

/// The file's size, "No file" when the render published none (C6 records
/// zero then), or null when the index doesn't say.
String? indexSize(core.JobIndexEntry e) => switch (e.sizeBytes) {
  null => null,
  0 => 'No file',
  final n => VeFormat.bytes(n),
};

/// A recorded length in seconds as "12:43"; null stays unknown.
String? indexDuration(double? seconds) => seconds == null ? null : VeFormat.duration(seconds);

/// FFmpeg's recorded realtime multiplier, including a partial render's last
/// known speed. An older index without this fact stays unknown.
String? indexSpeed(core.JobIndexEntry e) => e.realtime == null ? null : ratioLabel(e.realtime!);

// ------------------------------------------------------------ the detail

/// The command that ran as display parts: the executable, then each argument
/// quoted as [commandLine] quotes it, marked when FFmpeg named it (C6
/// `errorTokenIndices`: zero-based indexes into `argv`, the executable not
/// counted). Indexes outside `argv` are ignored.
List<({String text, bool error})> commandParts(core.JobRecord r) {
  final marked = r.errorTokenIndices.toSet();
  return [
    (text: quoteArgument(r.ffmpeg.path), error: false),
    for (var i = 0; i < r.argv.length; i++) (text: quoteArgument(r.argv[i]), error: marked.contains(i)),
  ];
}

/// The marked arguments, for the note under the command: "-preset 14".
String? markedArguments(core.JobRecord r) {
  final marked = [
    for (final i in r.errorTokenIndices.toSet().toList()..sort())
      if (i >= 0 && i < r.argv.length) r.argv[i],
  ];
  return marked.isEmpty ? null : marked.join(' ');
}

/// "1,204 lines." or "The last 1,000 of 12,345 lines." while it reads,
/// "Reading… 3,200 lines so far."
String logSummary({required int totalLines, required int shownLines, required bool complete}) {
  final total = VeFormat.count(totalLines);
  if (!complete) return 'Reading the log… $total ${totalLines == 1 ? 'line' : 'lines'} so far.';
  if (shownLines < totalLines) return 'The last ${VeFormat.count(shownLines)} of $total lines.';
  return '$total ${totalLines == 1 ? 'line' : 'lines'}.';
}

/// One sentence for how the render went:
/// "Rendered 12:43 in 24:46, 0.51× realtime, 9.84 GB."
/// "Failed after 0:03. FFmpeg exited with code 1 before reading any frames."
String resultSentence(core.JobRecord r) {
  final took = VeFormat.duration(r.elapsedSec);
  String withMessage(String lead) => r.message.isEmpty ? '$lead.' : '$lead. ${_sentence(r.message)}';
  switch (JobOutcome.of(r.status)) {
    case JobOutcome.succeeded:
      final length = r.media.durationSec;
      final ratio = realtimeRatio(r);
      final parts = [
        length == null ? 'Rendered in $took' : 'Rendered ${VeFormat.duration(length)} in $took',
        if (ratio != null) '${ratioLabel(ratio)} realtime',
        if (r.published) VeFormat.bytes(r.sizeBytes),
      ];
      return '${parts.join(', ')}.';
    case JobOutcome.failed:
      return withMessage('Failed after $took');
    case JobOutcome.cancelled:
      return withMessage('Cancelled after $took');
    case JobOutcome.other:
      return withMessage('Ended after $took (status “${r.status}”)');
  }
}

String _sentence(String text) {
  final t = text.trim();
  return t.isEmpty || '.!?'.contains(t[t.length - 1]) ? t : '$t.';
}

/// What the output check found (C6 `verification`).
String verificationLabel(core.VerificationResult v) => switch (v.state) {
  'passed' => 'Passed',
  'failed' => 'Failed',
  'skipped' => 'Not checked',
  _ => v.state,
};

/// "1111…1111" for a long hash; the full value is in the tooltip and copy.
String shortHash(String hash) =>
    hash.length <= 16 ? hash : '${hash.substring(0, 8)}…${hash.substring(hash.length - 8)}';

/// The command that ran, as the core wrote it into the record (C6
/// `commandLine`). An older record without it: the executable, then its
/// arguments, each quoted the way the Windows C runtime reads them back, so a
/// copied command can be pasted into a terminal.
String commandLine(core.JobRecord r) => r.commandLine ?? [r.ffmpeg.path, ...r.argv].map(quoteArgument).join(' ');

/// Quotes one argument for the Windows C runtime's parser: an argument with
/// no space, tab, newline or quote stays as it is; otherwise it goes in double
/// quotes, a quote inside becomes \", and backslashes before a quote (or
/// before the closing quote) are doubled.
String quoteArgument(String arg) {
  if (arg.isNotEmpty && !arg.contains(RegExp(r'[ \t\n\v"]'))) return arg;
  final out = StringBuffer('"');
  var slashes = 0;
  for (final ch in arg.split('')) {
    if (ch == r'\') {
      slashes++;
      continue;
    }
    if (ch == '"') {
      out.write(r'\' * (slashes * 2 + 1));
      out.write('"');
    } else {
      out.write(r'\' * slashes);
      out.write(ch);
    }
    slashes = 0;
  }
  out.write(r'\' * (slashes * 2));
  out.write('"');
  return out.toString();
}

/// "8.1, gyan.dev full build, GPL v3"
String ffmpegSummary(core.FFmpegInstallation i) =>
    [i.version, if (i.build.isNotEmpty) i.build, if (i.license.isNotEmpty) i.license].join(', ');
