// Golden images of the render progress window (F6, S6, UI_SPEC §12), light
// and dark, on the platform's sample live files (C5) and fixture job records
// (C6, given this job's ID). No FFmpeg, no VEGAS.
// Regenerate with: flutter test --update-goldens test/golden/monitor_golden_test.dart
// Images: test/golden/goldens/monitor_<state>_<light|dark>.png

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart';

import '../helpers.dart';
import '../monitor_doubles.dart';

/// The window's size at 100% (windows/runner/launch_options.cpp).
const monitorView = Size(380, 340);

void main() {
  final records = <RenderState, JobRecord>{};
  setUpAll(() async {
    for (final s in [RenderState.done, RenderState.failed, RenderState.cancelled]) {
      records[s] = await recordFor(s);
    }
  });

  for (final b in themes) {
    final theme = themeName(b);

    Future<void> pump(WidgetTester tester, {LiveRenderStatus? status, JobRecord? record}) async {
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      tester.platformDispatcher.platformBrightnessTestValue = b;
      await pumpApp(
        tester,
        view: monitorView,
        overrides: monitorOverrides(status: status, record: record).overrides,
      );
    }

    testWidgets('$theme monitor_waiting', (tester) async {
      await pump(tester);
      await expectGolden('monitor_waiting_$theme');
    });

    testWidgets('$theme monitor_encoding', (tester) async {
      await pump(tester, status: liveSample(RenderState.encoding));
      await expectGolden('monitor_encoding_$theme');
    });

    testWidgets('$theme monitor_verifying', (tester) async {
      await pump(tester, status: liveSample(RenderState.verifying));
      await expectGolden('monitor_verifying_$theme');
    });

    testWidgets('$theme monitor_done', (tester) async {
      await pump(tester, status: liveSample(RenderState.done), record: records[RenderState.done]);
      await expectGolden('monitor_done_$theme');
    });

    testWidgets('$theme monitor_failed', (tester) async {
      await pump(tester, status: liveSample(RenderState.failed), record: records[RenderState.failed]);
      await expectGolden('monitor_failed_$theme');
    });

    testWidgets('$theme monitor_failed_long', (tester) async {
      final cause = 'FFmpeg could not open the output file: ${List.filled(20, 'long folder name').join(' / ')}';
      await pump(tester, status: liveSample(RenderState.failed).copyWith(message: cause));
      await expectGolden('monitor_failed_long_$theme');
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('$theme monitor_cancelled', (tester) async {
      await pump(tester, status: liveSample(RenderState.cancelled), record: records[RenderState.cancelled]);
      await expectGolden('monitor_cancelled_$theme');
    });
  }
}
