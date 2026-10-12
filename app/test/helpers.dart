import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:vegas_encoder/app/app.dart';
import 'package:vegas_encoder/design/theme.dart';
import 'package:vegas_encoder/design/tokens.dart';
import 'package:vegas_encoder/platform/window_channel.dart';
import 'package:vegas_encoder/state/app_state.dart';

const goldenKey = ValueKey('golden');

/// Both themes, for golden and widget tests.
const themes = [Brightness.light, Brightness.dark];

String themeName(Brightness b) => b == Brightness.dark ? 'dark' : 'light';

/// Pumps [child] in the app's theme for [brightness], at 1:1 pixels, on paper.
/// The golden boundary wraps the child at [width] with a 16 px margin.
Future<void> pumpThemed(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
  double width = 1200,
  Size view = const Size(1400, 1100),
  FakeWindowController? window,
  bool settle = true,
  bool wholeView = false,
}) async {
  tester.view.physicalSize = view;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final tokens = VeTokens.forBrightness(brightness);
  final content = Container(
    color: tokens.colors.paper,
    width: width + 32,
    padding: const EdgeInsets.all(16),
    child: child,
  );
  final app = ProviderScope(
    overrides: [windowControllerProvider.overrideWithValue(window ?? FakeWindowController())],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildVeTheme(tokens),
      home: VeSurface(
        child: ColoredBox(
          color: tokens.colors.paper,
          child: Align(
            alignment: Alignment.topLeft,
            child: wholeView ? content : RepaintBoundary(key: goldenKey, child: content),
          ),
        ),
      ),
    ),
  );
  // wholeView captures overlays (open popovers) too.
  await tester.pumpWidget(wholeView ? RepaintBoundary(key: goldenKey, child: app) : app);
  if (settle) await tester.pumpAndSettle();
}

/// Pumps the whole app root ([VeApp]) for a launch mode, with a fake window.
Future<void> pumpApp(
  WidgetTester tester, {
  required List<Override> overrides,
  Size view = const Size(1440, 900),
}) async {
  tester.view.physicalSize = view;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    RepaintBoundary(
      key: goldenKey,
      child: ProviderScope(overrides: overrides, child: const VeApp()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> expectGolden(String name) => expectLater(find.byKey(goldenKey), matchesGoldenFile('goldens/$name.png'));
