// Maps a "Test this preset" run (C3 `PresetTestProgress`) to what its panel
// shows. Display work only: labels and sentences. Whether the test passed,
// how far it got and what the file holds are the service's results.

import 'package:flutter/foundation.dart';

import '../../design/format.dart';
import '../../state/preset_test.dart';

enum PresetTestOutcome { running, passed, failed, stopped }

/// The panel's status: a headline, a sentence, progress and the output check.
@immutable
class PresetTestView {
  const PresetTestView({
    required this.outcome,
    required this.headline,
    this.detail,
    this.fraction,
    this.facts = const [],
    this.sample = false,
  });

  final PresetTestOutcome outcome;

  /// "Encoding: frame 30 of 60", "Passed".
  final String headline;

  /// What happened, in a sentence.
  final String? detail;

  /// How far the encode is, while it runs.
  final double? fraction;

  /// The output check: expected and found codecs.
  final List<(String, String)> facts;

  /// The platform's fake service answered (tests); nothing ran.
  final bool sample;
}

PresetTestView presetTestView(PresetTestState s) {
  final p = s.latest;
  final sample = p?.isFixture ?? false;
  final v = p?.verification;
  final facts = [
    if (v != null && v.expectedCodecs.isNotEmpty) ('Expected', v.expectedCodecs.join(', ')),
    if (v != null && v.actualCodecs.isNotEmpty) ('Found', v.actualCodecs.join(', ')),
  ];
  if (s.error case final error?) {
    return PresetTestView(
      outcome: PresetTestOutcome.failed,
      headline: 'The test couldn’t run',
      detail: _sentence(error),
      sample: sample,
    );
  }
  if (s.stopped) {
    return PresetTestView(
      outcome: PresetTestOutcome.stopped,
      headline: 'Stopped',
      detail: 'The test was stopped before it finished.',
      sample: sample,
    );
  }
  switch (p?.phase) {
    case null:
      return const PresetTestView(outcome: PresetTestOutcome.running, headline: 'Starting the test…');
    case 'preparing':
      return PresetTestView(outcome: PresetTestOutcome.running, headline: 'Making the test frames…', sample: sample);
    case 'encoding':
      final total = p!.framesTotal;
      return PresetTestView(
        outcome: PresetTestOutcome.running,
        headline: total > 0
            ? 'Encoding: frame ${VeFormat.count(p.framesDone)} of ${VeFormat.count(total)}'
            : 'Encoding: frame ${VeFormat.count(p.framesDone)}',
        fraction: total > 0 ? (p.framesDone / total).clamp(0.0, 1.0) : null,
        sample: sample,
      );
    case 'verifying':
      return PresetTestView(
        outcome: PresetTestOutcome.running,
        headline: 'Checking the file…',
        fraction: 1,
        sample: sample,
      );
    case 'done':
      final codecs = v?.actualCodecs ?? const <String>[];
      return PresetTestView(
        outcome: PresetTestOutcome.passed,
        headline: 'Passed',
        detail: codecs.isEmpty
            ? 'FFmpeg encoded the test frames and the file checked out.'
            : 'FFmpeg encoded the test frames and the file checked out: ${_and(codecs)}.',
        facts: facts,
        sample: sample,
      );
    case 'failed':
      final why = p!.message.trim().isNotEmpty ? p.message : (v?.message ?? '');
      return PresetTestView(
        outcome: PresetTestOutcome.failed,
        headline: 'Failed',
        detail: why.trim().isEmpty ? 'The test failed. FFmpeg’s output below may say why.' : _sentence(why),
        facts: facts,
        sample: sample,
      );
    case 'cancelled':
      return PresetTestView(
        outcome: PresetTestOutcome.stopped,
        headline: 'Stopped',
        detail: 'The test was cancelled before it finished.',
        sample: sample,
      );
    default:
      if (!s.running) {
        return PresetTestView(
          outcome: PresetTestOutcome.failed,
          headline: 'Ended without a result',
          detail: 'The test service stopped reporting before the test finished.',
          sample: sample,
        );
      }
      return PresetTestView(outcome: PresetTestOutcome.running, headline: 'Testing…', sample: sample);
  }
}

/// "1,204 lines from FFmpeg." or "The last 400 of 1,204 lines from FFmpeg."
String presetTestLogSummary(PresetTestState s, String shownText) {
  if (s.logLines == 0 && shownText.trim().isEmpty) return 'Nothing from FFmpeg yet.';
  final shown = '\n'.allMatches(shownText.trimRight()).length + 1;
  final total = s.logLines < shown ? shown : s.logLines;
  if (shown < total) return 'The last ${VeFormat.count(shown)} of ${VeFormat.count(total)} lines from FFmpeg.';
  return '${VeFormat.count(total)} ${total == 1 ? 'line' : 'lines'} from FFmpeg.';
}

String _and(List<String> items) =>
    items.length < 2 ? items.join() : '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';

String _sentence(String text) {
  final t = text.trim();
  return t.isEmpty || '.!?'.contains(t[t.length - 1]) ? t : '$t.';
}
