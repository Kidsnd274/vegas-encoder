// Golden images of the design system and the window shells, light and dark.
// Regenerate with: flutter test --update-goldens test/golden
// Images: test/golden/goldens/<name>_<light|dark>.png

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vegas_encoder/app/launch.dart';
import 'package:vegas_encoder/design/components/select.dart';
import 'package:vegas_encoder/design/components/signal_path/signal_path.dart';
import 'package:vegas_encoder/features/gallery/gallery_sections.dart';
import 'package:vegas_encoder/features/gallery/samples.dart';
import 'package:vegas_encoder/platform/window_channel.dart';
import 'package:vegas_encoder/state/app_state.dart';

import '../helpers.dart';

void main() {
  final sections = <String, Widget Function()>{
    'tokens': () => const TokensSection(),
    'buttons': () => const ButtonsSection(),
    'inputs': () => const InputsSection(),
    'choices': () => const ChoicesSection(),
    'pickers': () => const PickersSection(),
    'quality_and_speed': () => const SlidersSection(),
    'messages': () => const MessagesSection(),
    'signal_path_full': () => const SignalPathSection(),
    'signal_path_hevc_master': () =>
        const SignalPathSection(model: Samples.hevcMaster, title: 'No conversion, failed hardware encoder'),
    'signal_path_audio_off_bad_mux': () => const SignalPathSection(
      model: Samples.audioOffBadMux,
      title: 'Audio off, container can’t hold the codec',
      initial: SignalNode.container,
    ),
    'signal_path_advanced': () => const SignalPathSection(model: Samples.fromCommand, title: 'Advanced mode'),
    'signal_path_strip': () => const StripSection(),
    'size_and_command': () => const FileAndCommandSection(),
  };

  for (final brightness in themes) {
    final theme = themeName(brightness);

    group(theme, () {
      sections.forEach((name, build) {
        testWidgets(name, (tester) async {
          await pumpThemed(tester, build(), brightness: brightness);
          await expectGolden('${name}_$theme');
        });
      });

      testWidgets('encoder_picker_open', (tester) async {
        await pumpThemed(
          tester,
          SizedBox(
            width: 420,
            child: VeEncoderPicker(
              groups: Samples.videoEncoders,
              selectedId: 'libx264',
              kindLabel: 'Video',
              installationLabel: 'FFmpeg 8.1 full',
              onChanged: (_) {},
            ),
          ),
          brightness: brightness,
          width: 420,
          view: const Size(480, 640),
          wholeView: true,
        );
        await tester.tap(find.text('x264'));
        await tester.pumpAndSettle();
        await expectGolden('encoder_picker_open_$theme');
      });

      testWidgets('window_desktop', (tester) async {
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        await pumpApp(tester, overrides: [windowControllerProvider.overrideWithValue(FakeWindowController())]);
        await expectGolden('window_desktop_$theme');
      });

      // The popup for a session the fakes don't have: the request can't be
      // read (F5), so it says so and closing it changes nothing.
      testWidgets('window_popup', (tester) async {
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        await pumpApp(
          tester,
          view: const Size(1120, 740),
          overrides: [
            launchModeProvider.overrideWithValue(
              const EditSessionLaunch(r'C:\Users\me\AppData\Local\VegasEncoder\sessions\3f2a'),
            ),
            windowControllerProvider.overrideWithValue(FakeWindowController()),
          ],
        );
        await expectGolden('window_popup_$theme');
      });

      testWidgets('window_progress', (tester) async {
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        await pumpApp(
          tester,
          view: const Size(380, 340),
          overrides: [
            launchModeProvider.overrideWithValue(
              const RenderMonitorLaunch(r'C:\Users\me\AppData\Local\VegasEncoder\jobs\7.live.json'),
            ),
            windowControllerProvider.overrideWithValue(FakeWindowController()),
            initialWindowStateProvider.overrideWithValue(const WindowState(keepOnTop: true)),
          ],
        );
        await expectGolden('window_progress_$theme');
      });
    });
  }
}
