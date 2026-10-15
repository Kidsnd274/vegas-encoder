import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart';
import 'package:vegas_encoder/app/app.dart';
import 'package:vegas_encoder/design/theme.dart';
import 'package:vegas_encoder/design/tokens.dart';
import 'package:vegas_encoder/platform/window_channel.dart';
import 'package:vegas_encoder/state/app_state.dart';
import 'package:vegas_encoder/state/services.dart';

const goldenKey = ValueKey('golden');

/// Both themes, for golden and widget tests.
const themes = [Brightness.light, Brightness.dark];

String themeName(Brightness b) => b == Brightness.dark ? 'dark' : 'light';

/// The core for a test: the platform's fake unless a test passes another.
/// The app itself runs on the native core (B2); widget and golden tests stay
/// on the fake's fixtures so their results don't move with the core's data.
/// Tests that show live edits pass `NativeVeCore()` (test/widget/native_core_test.dart).
Override coreOverride([VeCore? core]) => veCoreProvider.overrideWithValue(core ?? FakeVeCore());

/// The platform's fakes for every service (C3), so no test reads or writes
/// the user's library or settings. The app's own `servicesProvider` refuses
/// to build the real ones under `flutter test`. A test that needs a
/// particular fake still overrides that service's provider on top.
class FakeAppServices implements AppServices {
  @override
  final FakePresetLibrary library = FakePresetLibrary();
  @override
  final FakeMachineSettingsRepository machineSettings = FakeMachineSettingsRepository();
  @override
  final FakeFFmpegDiscovery discovery = FakeFFmpegDiscovery();
  @override
  final FakeFFmpegProbe probe = FakeFFmpegProbe();
  @override
  final FakeHardwareTests hardwareTests = FakeHardwareTests();
  @override
  final FakeCapabilityCache capabilityCache = FakeCapabilityCache();
  @override
  final FakeJobRepository jobs = FakeJobRepository();
  @override
  FakeJobRepository get jobLogs => jobs;
  @override
  final FakeLiveRenderStatusReader liveStatus = FakeLiveRenderStatusReader();
  @override
  final FakeEditSessionService editSessions = FakeEditSessionService();
  @override
  final FakeFileReveal fileReveal = FakeFileReveal();
  @override
  ServicePaths? get paths => null;

  @override
  Future<void> dispose() async {
    await library.dispose();
    await machineSettings.dispose();
    await discovery.dispose();
    await jobs.dispose();
    await liveStatus.dispose();
  }
}

Override servicesOverride() => servicesProvider.overrideWith((ref) {
  final services = FakeAppServices();
  ref.onDispose(services.dispose);
  return services;
});

/// A container on the fake core and fake services, plus [overrides].
ProviderContainer testContainer({List<Override> overrides = const [], VeCore? core}) =>
    ProviderContainer(overrides: [coreOverride(core), servicesOverride(), ...overrides]);

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
  VeCore? core,
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
    overrides: [
      coreOverride(core),
      servicesOverride(),
      windowControllerProvider.overrideWithValue(window ?? FakeWindowController()),
    ],
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

/// Pumps the whole app root ([VeApp]) for a launch mode, with a fake window,
/// and the fake core and fake services unless [core] or [services] say
/// otherwise.
Future<void> pumpApp(
  WidgetTester tester, {
  required List<Override> overrides,
  Size view = const Size(1440, 900),
  VeCore? core,
  AppServices? services,
}) async {
  tester.view.physicalSize = view;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    RepaintBoundary(
      key: goldenKey,
      child: ProviderScope(
        overrides: [
          coreOverride(core),
          services == null ? servicesOverride() : servicesProvider.overrideWithValue(services),
          ...overrides,
        ],
        child: const VeApp(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> expectGolden(String name) => expectLater(find.byKey(goldenKey), matchesGoldenFile('goldens/$name.png'));
