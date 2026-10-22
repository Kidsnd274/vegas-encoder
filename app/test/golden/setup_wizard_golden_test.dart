// Golden images of the first-run setup (UI_SPEC §5a) over the desktop window,
// on the platform fakes, light and dark. Regenerate with:
// flutter test --update-goldens test/golden/setup_wizard_golden_test.dart
// Images: test/golden/goldens/setup_<state>_<light|dark>.png

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart';
import 'package:vegas_encoder/platform/window_channel.dart';
import 'package:vegas_encoder/state/app_state.dart';
import 'package:vegas_encoder/state/services.dart';

import '../ffmpeg_doubles.dart';
import '../helpers.dart';

/// Discovery still looking, so the image shows the Find step's progress.
class _LookingDiscovery extends FakeFFmpegDiscovery {
  _LookingDiscovery() : super(installations: const []);
  @override
  Future<List<FFmpegInstallation>> scan() => Completer<List<FFmpegInstallation>>().future;
}

void main() {
  late MachineSettings firstStart;
  late List<FFmpegInstallation> unhealthy;
  setUpAll(() async {
    firstStart = (await FakeMachineSettingsRepository().read()).copyWith(defaultFFmpegId: null);
    unhealthy = await unhealthyInstallations();
  });

  final states = <String, List<Override> Function()>{
    // Looking on PATH and in the package managers.
    'finding': () => [ffmpegDiscoveryProvider.overrideWithValue(_LookingDiscovery())],
    // Nothing found: Add FFmpeg… and Scan again.
    'none': () => [ffmpegDiscoveryProvider.overrideWithValue(FakeFFmpegDiscovery(installations: const []))],
    // The first check still running; the others show what is recorded.
    'checking': () => [ffmpegProbeProvider.overrideWithValue(StalledProbe())],
    // Checks done: the recommended one selected.
    'choose': () => const [],
    // The default changed on disk, 7.1.1 missing (can't be chosen), the LGPL build without ffprobe.
    'health': () => [ffmpegDiscoveryProvider.overrideWithValue(FakeFFmpegDiscovery(installations: unhealthy))],
  };

  for (final brightness in themes) {
    final theme = themeName(brightness);
    group(theme, () {
      states.forEach((name, overrides) {
        testWidgets('setup_$name', (tester) async {
          addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          await pumpApp(
            tester,
            view: const Size(1280, 860),
            overrides: [
              windowControllerProvider.overrideWithValue(FakeWindowController()),
              machineSettingsRepositoryProvider.overrideWithValue(FakeMachineSettingsRepository(settings: firstStart)),
              ...overrides(),
            ],
          );
          await expectGolden('setup_${name}_$theme');
        });
      });
    });
  }
}
