import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart';
import 'package:vegas_encoder/app/launch.dart';
import 'package:vegas_encoder/features/setup/setup_wizard.dart';
import 'package:vegas_encoder/platform/desktop_channel.dart';
import 'package:vegas_encoder/platform/window_channel.dart';
import 'package:vegas_encoder/state/app_state.dart';
import 'package:vegas_encoder/state/desktop_routes.dart';
import 'package:vegas_encoder/state/services.dart';
import 'package:vegas_encoder/state/setup_wizard.dart';

import '../ffmpeg_doubles.dart';
import '../helpers.dart';

/// Discovery whose next scans fail, to show the wizard's Try again.
class FailingDiscovery extends FakeFFmpegDiscovery {
  FailingDiscovery({this.failures = 1});
  int failures;

  @override
  Future<List<FFmpegInstallation>> scan() async {
    if (failures-- > 0) throw const ServiceException('SCAN-FAILED', 'The winget folder couldn’t be read.');
    return super.scan();
  }
}

/// Discovery still looking.
class LookingDiscovery extends FakeFFmpegDiscovery {
  LookingDiscovery() : super(installations: const []);
  @override
  Future<List<FFmpegInstallation>> scan() => Completer<List<FFmpegInstallation>>().future;
}

class _Routes implements DesktopRouteSource {
  final controller = StreamController<DesktopRoute>.broadcast();
  @override
  Stream<DesktopRoute> get changes => controller.stream;
  @override
  Future<List<DesktopRoute>> start() async => const [];
  @override
  void dispose() => unawaited(controller.close());
}

/// The first-run setup (UI_SPEC §5a) on the platform fakes: no FFmpeg runs.
void main() {
  const addedPath = r'E:\Tools\ffmpeg-7.1\bin\ffmpeg.exe';
  late FakeWindowController window;
  late FakeMachineSettingsRepository machine;

  /// The fixture settings with no default FFmpeg, as on a first start.
  Future<MachineSettings> firstStart({bool dismissed = false}) async {
    final s = (await FakeMachineSettingsRepository().read()).copyWith(defaultFFmpegId: null);
    return dismissed ? s.copyWith(uiState: s.uiState!.copyWith(setupDismissed: true)) : s;
  }

  Future<void> start(
    WidgetTester tester, {
    MachineSettings? settings,
    FFmpegDiscovery? discovery,
    List<Override> overrides = const [],
  }) async {
    final initial = settings ?? await tester.runAsync(firstStart);
    window = FakeWindowController();
    machine = FakeMachineSettingsRepository(settings: initial);
    await pumpApp(
      tester,
      overrides: [
        windowControllerProvider.overrideWithValue(window),
        machineSettingsRepositoryProvider.overrideWithValue(machine),
        if (discovery != null) ffmpegDiscoveryProvider.overrideWithValue(discovery),
        ...overrides,
      ],
    );
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final inWizard = find.descendant(of: find.byType(SetupWizard), matching: find.text(text));
    await tester.tap(inWizard.evaluate().isEmpty ? find.text(text) : inWizard);
    await tester.pumpAndSettle();
  }

  testWidgets('a first start finds FFmpeg, checks it and makes the chosen one the default', (tester) async {
    await start(tester);
    expect(find.byType(SetupWizard), findsOneWidget);
    expect(find.text('Set up Vegas Encoder'), findsOneWidget);
    expect(find.text('Choose the FFmpeg every render uses.'), findsOneWidget, reason: 'the checks finished');
    expect(find.text('Recommended'), findsOneWidget);
    expect(
      find.text('Hardware ready: NVENC H.264, NVENC HEVC, NVENC AV1. 2 failed their test on this PC.'),
      findsNWidgets(3),
    );
    expect(find.bySemanticsLabel(RegExp('^FFmpeg 8.1 full, recommended')), findsOneWidget);
    await tapText(tester, 'FFmpeg 7.1.1');
    await tapText(tester, 'Use this FFmpeg');
    expect(find.byType(SetupWizard), findsNothing);
    final saved = await machine.read();
    expect(saved.defaultFFmpegId, 'manual-7.1');
    expect(tester.container().read(shouldOfferSetupProvider), isFalse);
  });

  testWidgets('Skip for now is remembered', (tester) async {
    await start(tester);
    await tapText(tester, 'Skip for now');
    expect(find.byType(SetupWizard), findsNothing);
    expect((await machine.read()).uiState?.setupDismissed, isTrue);
    expect((await machine.read()).defaultFFmpegId, isNull);
    expect(tester.container().read(shouldOfferSetupProvider), isFalse);
  });

  testWidgets('Esc is Skip for now', (tester) async {
    await start(tester);
    expect(find.byType(SetupWizard), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(SetupWizard), findsNothing);
    expect((await machine.read()).uiState?.setupDismissed, isTrue);
  });

  testWidgets('not offered with a default, after a skip, outside the desktop window or without the core', (
    tester,
  ) async {
    await start(tester, settings: await tester.runAsync(() => FakeMachineSettingsRepository().read()));
    expect(find.byType(SetupWizard), findsNothing, reason: 'a default exists');

    final settings = (await tester.runAsync(firstStart))!;
    Future<bool> offered(List<Override> overrides) async {
      final container = testContainer(
        overrides: [
          machineSettingsRepositoryProvider.overrideWithValue(FakeMachineSettingsRepository(settings: settings)),
          ...overrides,
        ],
      );
      addTearDown(container.dispose);
      container.listen(machineSettingsProvider, (_, _) {});
      await container.read(machineSettingsProvider.future);
      return container.read(shouldOfferSetupProvider);
    }

    expect(await tester.runAsync(() => offered(const [])), isTrue);
    expect(
      await tester.runAsync(() => offered([launchModeProvider.overrideWithValue(const EditSessionLaunch('s'))])),
      isFalse,
    );
    expect(
      await tester.runAsync(() => offered([launchModeProvider.overrideWithValue(const RenderMonitorLaunch('m'))])),
      isFalse,
    );
    expect(
      await tester.runAsync(
        () => offered([coreLoadErrorProvider.overrideWithValue(const CoreException('LOAD', 'missing DLL'))]),
      ),
      isFalse,
    );
  });

  testWidgets('Skip for now works while it is still looking', (tester) async {
    await start(tester, discovery: LookingDiscovery());
    expect(find.text('Looking on PATH and in winget, Scoop and Chocolatey…'), findsOneWidget);
    await tapText(tester, 'Skip for now');
    expect(find.byType(SetupWizard), findsNothing);
    expect((await machine.read()).uiState?.setupDismissed, isTrue);
  });

  testWidgets('not offered again once skipped', (tester) async {
    await start(tester, settings: await tester.runAsync(() => firstStart(dismissed: true)));
    expect(find.byType(SetupWizard), findsNothing);
  });

  testWidgets('nothing found: Add FFmpeg… checks the one chosen and offers it', (tester) async {
    final manual = (await tester.runAsync(FakeFFmpegDiscovery().list))!.singleWhere((i) => i.id == 'manual-7.1');
    await start(
      tester,
      discovery: FakeFFmpegDiscovery(installations: const [], additions: {addedPath: manual}),
    );
    expect(find.textContaining('No FFmpeg found on this PC.'), findsOneWidget);
    expect(find.text('Use this FFmpeg'), findsNothing);
    window.pickedFile = addedPath;
    await tapText(tester, 'Add FFmpeg…');
    expect(window.calls, contains('pickFile(ffmpeg.exe)'));
    expect(find.text('Choose the FFmpeg every render uses.'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^FFmpeg 7.1.1, recommended')), findsOneWidget);
    await tapText(tester, 'Use this FFmpeg');
    expect((await machine.read()).defaultFFmpegId, 'manual-7.1');
  });

  testWidgets('a scan that fails says why; Try again finds them', (tester) async {
    await start(tester, discovery: FailingDiscovery());
    expect(find.text('Couldn’t look for FFmpeg: The winget folder couldn’t be read.'), findsOneWidget);
    await tapText(tester, 'Try again');
    expect(find.text('Choose the FFmpeg every render uses.'), findsOneWidget);
  });

  testWidgets('Choose without waiting while a check is still running', (tester) async {
    final probe = StalledProbe();
    await start(tester, overrides: [ffmpegProbeProvider.overrideWithValue(probe)]);
    expect(find.text('Reading encoders… 18 of 25'), findsOneWidget);
    expect(find.text('Use this FFmpeg'), findsNothing);
    await tapText(tester, 'Choose without waiting');
    expect(find.text('Use this FFmpeg'), findsOneWidget);
    expect(find.text('Reading encoders… 18 of 25'), findsOneWidget, reason: 'the check goes on');
    await tapText(tester, 'Use this FFmpeg');
    expect((await machine.read()).defaultFFmpegId, 'gyan-8.1');
    expect(probe.cancelled, isEmpty, reason: 'closing the wizard leaves the FFmpeg page’s check running');
  });

  testWidgets('Run setup… on the FFmpeg page opens it again with the current default', (tester) async {
    await start(tester, settings: await tester.runAsync(() => FakeMachineSettingsRepository().read()));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    await tapText(tester, 'Run setup…');
    expect(find.byType(SetupWizard), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget, reason: 'a default exists, so nothing to skip');
    expect(find.bySemanticsLabel(RegExp('^FFmpeg 8.1 full, recommended, current default')), findsOneWidget);
    await tapText(tester, 'Cancel');
    expect(find.byType(SetupWizard), findsNothing);
    expect((await machine.read()).uiState?.setupDismissed, isNot(isTrue));

    await tapText(tester, 'Run setup…');
    await tapText(tester, 'FFmpeg 8.0 LGPL');
    await tapText(tester, 'Use this FFmpeg');
    expect((await machine.read()).defaultFFmpegId, 'btbn-lgpl-8.0');
    expect(find.text('FFmpeg 8.0 LGPL is now the default. The next render uses it.'), findsOneWidget);
  });

  testWidgets('a requested History job waits until setup closes', (tester) async {
    final routes = _Routes();
    addTearDown(routes.dispose);
    await start(tester, overrides: [desktopRouteSourceProvider.overrideWithValue(routes)]);
    expect(find.byType(SetupWizard), findsOneWidget);
    routes.controller.add(const DesktopRoute.job('j-1042'));
    await tester.pumpAndSettle();
    expect(tester.container().read(desktopSectionProvider), DesktopSection.presets, reason: 'the wizard is open');
    await tapText(tester, 'Skip for now');
    expect(tester.container().read(desktopSectionProvider), DesktopSection.history);
  });
}
