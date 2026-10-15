// Golden images of the FFmpeg screen (S4) on the platform fakes, light and
// dark. Regenerate with: flutter test --update-goldens test/golden/ffmpeg_golden_test.dart
// Images: test/golden/goldens/ffmpeg_<state>_<light|dark>.png

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart';
import 'package:vegas_encoder/features/ffmpeg/capability_table.dart';
import 'package:vegas_encoder/platform/window_channel.dart';
import 'package:vegas_encoder/state/app_state.dart';
import 'package:vegas_encoder/state/services.dart';

import '../ffmpeg_doubles.dart';
import '../helpers.dart';

/// Opens the FFmpeg screen (Ctrl+2).
Future<void> openFFmpeg(WidgetTester tester, {List<Override> overrides = const [], Size? view}) async {
  await pumpApp(
    tester,
    view: view ?? const Size(1440, 900),
    overrides: [windowControllerProvider.overrideWithValue(FakeWindowController()), ...overrides],
  );
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

late List<FFmpegInstallation> _unhealthy;

void main() {
  setUpAll(() async => _unhealthy = await unhealthyInstallations());

  Future<void> tapRow(WidgetTester tester, String ffmpegName) async {
    await tester.tap(find.descendant(of: find.byType(CapabilityTable), matching: find.text(ffmpegName)));
    await tester.pumpAndSettle();
  }

  final states = <String, ({List<Override> overrides, Future<void> Function(WidgetTester) act})>{
    // The default FFmpeg, its video encoders, x264's details.
    'default': (overrides: const [], act: (tester) async {}),
    // A hardware encoder that failed its test: reason, test encode, FFmpeg's line.
    'failed': (overrides: const [], act: (tester) => tapRow(tester, 'hevc_qsv')),
    // The LGPL build, only problems: x264 and x265 missing, presets it can't render.
    'lgpl': (
      overrides: const [],
      act: (tester) async {
        await tester.tap(find.text('FFmpeg 8.0 LGPL'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Only problems'));
        await tester.pumpAndSettle();
      },
    ),
    // Audio encoders.
    'audio': (
      overrides: const [],
      act: (tester) async {
        await tester.tap(find.text('Audio encoders'));
        await tester.pumpAndSettle();
      },
    ),
    // Installation health: the default changed on disk, 7.1.1 missing, the
    // LGPL build without ffprobe; each card says what to do.
    'health': (
      overrides: [ffmpegDiscoveryProvider.overrideWith((ref) => FakeFFmpegDiscovery(installations: _unhealthy))],
      act: (tester) async {},
    ),
    // Scan again while a check is still running: progress on the card.
    'probing': (
      overrides: [ffmpegProbeProvider.overrideWithValue(StalledProbe())],
      act: (tester) async {
        await tester.tap(find.text('Scan again'));
        await tester.pump();
        await tester.pump();
      },
    ),
  };

  for (final brightness in themes) {
    final theme = themeName(brightness);
    group(theme, () {
      states.forEach((name, s) {
        testWidgets('ffmpeg_$name', (tester) async {
          addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          await openFFmpeg(tester, overrides: s.overrides);
          await s.act(tester);
          await expectGolden('ffmpeg_${name}_$theme');
        });
      });

      // The minimum window.
      testWidgets('ffmpeg_narrow', (tester) async {
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        await openFFmpeg(tester, view: const Size(1100, 700));
        await expectGolden('ffmpeg_narrow_$theme');
      });
    });
  }
}
