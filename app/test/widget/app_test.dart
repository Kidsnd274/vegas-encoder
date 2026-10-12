import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vegas_encoder/app/launch.dart';
import 'package:vegas_encoder/design/components/title_bar.dart';
import 'package:vegas_encoder/design/tokens.dart';
import 'package:vegas_encoder/features/gallery/gallery_page.dart';
import 'package:vegas_encoder/platform/window_channel.dart';
import 'package:vegas_encoder/state/app_state.dart';

import '../helpers.dart';

Brightness _tokensBrightness(WidgetTester tester) => VeTokens.of(tester.element(find.byType(VeTitleBar))).brightness;

void main() {
  group('theme', () {
    testWidgets('follows the Windows app theme live', (tester) async {
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await pumpApp(tester, overrides: [windowControllerProvider.overrideWithValue(FakeWindowController())]);
      expect(_tokensBrightness(tester), Brightness.light);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(_tokensBrightness(tester), Brightness.dark);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(_tokensBrightness(tester), Brightness.light);
    });

    testWidgets('Light or Dark in Settings overrides Windows', (tester) async {
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await pumpApp(tester, overrides: [windowControllerProvider.overrideWithValue(FakeWindowController())]);
      expect(_tokensBrightness(tester), Brightness.dark);
      final container = tester.container();
      container.read(themePreferenceProvider.notifier).set(ThemePreference.light);
      await tester.pumpAndSettle();
      expect(_tokensBrightness(tester), Brightness.light);
      container.read(themePreferenceProvider.notifier).set(ThemePreference.followWindows);
      await tester.pumpAndSettle();
      expect(_tokensBrightness(tester), Brightness.dark);
    });

    testWidgets('Windows "Animation effects" off disables animations app-wide, live', (tester) async {
      final window = FakeWindowController();
      await pumpApp(tester, overrides: [windowControllerProvider.overrideWithValue(window)]);
      final context = tester.element(find.byType(GalleryPage));
      expect(MediaQuery.disableAnimationsOf(context), isFalse);
      expect(VeTokens.motion(context, VeDurations.wire), VeDurations.wire);
      window.emit(const WindowState(reducedMotion: true));
      await tester.pumpAndSettle();
      final after = tester.element(find.byType(GalleryPage));
      expect(MediaQuery.disableAnimationsOf(after), isTrue);
      expect(VeTokens.motion(after, VeDurations.wire), Duration.zero);
    });
  });

  group('desktop window', () {
    testWidgets('title bar sections, Ctrl+1–4 and window buttons', (tester) async {
      final window = FakeWindowController();
      await pumpApp(tester, overrides: [windowControllerProvider.overrideWithValue(window)]);
      expect(find.text('Design system'), findsOneWidget);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.text('This screen is built in milestone F3.'), findsOneWidget);
      await tester.tap(find.text('Presets'));
      await tester.pumpAndSettle();
      expect(find.text('Design system'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Minimize'));
      await tester.tap(find.bySemanticsLabel('Maximize'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Restore'), findsOneWidget, reason: 'the button follows the window state');
      await tester.tap(find.bySemanticsLabel('Close'));
      expect(window.calls, ['minimize', 'toggleMaximize', 'close']);
    });

    testWidgets('dragging the title bar moves the window; double-click maximizes', (tester) async {
      final window = FakeWindowController();
      await pumpApp(tester, overrides: [windowControllerProvider.overrideWithValue(window)]);
      final empty = tester.getTopLeft(find.byType(VeTitleBar)) + const Offset(900, 20);
      await tester.dragFrom(empty, const Offset(40, 10));
      await tester.pumpAndSettle();
      expect(window.calls, contains('startDrag'));
      window.calls.clear();
      await tester.tapAt(empty);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(empty);
      await tester.pumpAndSettle();
      expect(window.calls, ['toggleMaximize']);
    });
  });

  group('popup and progress window shells', () {
    testWidgets('popup: owned editor shell; × behaves as Cancel', (tester) async {
      final window = FakeWindowController();
      await pumpApp(
        tester,
        view: const Size(1120, 740),
        overrides: [
          launchModeProvider.overrideWithValue(const EditSessionLaunch(r'C:\sessions\a1', ownerHwnd: 42)),
          windowControllerProvider.overrideWithValue(window),
        ],
      );
      expect(find.text('Vegas Encoder, editing a VEGAS render template'), findsOneWidget);
      expect(find.text(r'Session: C:\sessions\a1'), findsOneWidget);
      expect(
        find.text('Apply updates this render template. Save it in VEGAS to keep it for next time.'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Minimize'), findsNothing);
      await tester.tap(find.bySemanticsLabel('Cancel').first);
      expect(window.calls, ['close']);
    });

    testWidgets('progress window: keep-on-top pin toggles', (tester) async {
      final window = FakeWindowController(const WindowState(keepOnTop: true));
      await pumpApp(
        tester,
        view: const Size(380, 250),
        overrides: [
          launchModeProvider.overrideWithValue(const RenderMonitorLaunch(r'D:\jobs\7.live.json')),
          windowControllerProvider.overrideWithValue(window),
          initialWindowStateProvider.overrideWithValue(const WindowState(keepOnTop: true)),
        ],
      );
      expect(find.text('Cancel the render in VEGAS.'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Keep on top'));
      await tester.pumpAndSettle();
      expect(window.calls, ['setKeepOnTop(false)']);
    });

    testWidgets('a mode flag without its path is shown, not swallowed', (tester) async {
      await pumpApp(
        tester,
        view: const Size(380, 250),
        overrides: [
          launchModeProvider.overrideWithValue(
            const LaunchError('--render-monitor', '--render-monitor needs a path after it.'),
          ),
          windowControllerProvider.overrideWithValue(FakeWindowController()),
        ],
      );
      expect(find.text('--render-monitor needs a path after it.'), findsOneWidget);
    });
  });
}
