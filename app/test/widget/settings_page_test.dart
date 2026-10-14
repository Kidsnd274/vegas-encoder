// The Settings screen on the platform fakes: every control saves through
// MachineSettingsRepository.save(expectedRevision), changes made elsewhere
// show live, and a conflicting write is reapplied without losing the other.

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart';
import 'package:vegas_encoder/features/ffmpeg/ffmpeg_page.dart';
import 'package:vegas_encoder/features/settings/display.dart';
import 'package:vegas_encoder/features/settings/settings_page.dart';
import 'package:vegas_encoder/platform/window_channel.dart';
import 'package:vegas_encoder/state/app_state.dart';
import 'package:vegas_encoder/state/services.dart';

import '../helpers.dart';

/// Saves another window's change just before this window's first save, so
/// that save meets a revision conflict.
class _ConflictOnce implements MachineSettingsRepository {
  _ConflictOnce(this.inner, this.otherWindow);
  final FakeMachineSettingsRepository inner;
  final MachineSettings Function(MachineSettings s) otherWindow;
  int saves = 0;

  @override
  Future<MachineSettings> read() => inner.read();

  @override
  Stream<MachineSettings> watch() => inner.watch();

  @override
  Future<MachineSettings> save(MachineSettings settings, {required int expectedRevision}) async {
    saves++;
    if (saves == 1) {
      final current = await inner.read();
      await inner.save(otherWindow(current), expectedRevision: current.revision);
    }
    return inner.save(settings, expectedRevision: expectedRevision);
  }
}

/// Every save fails, as a read-only or locked file would.
class _Failing implements MachineSettingsRepository {
  _Failing(this.inner);
  final FakeMachineSettingsRepository inner;

  @override
  Future<MachineSettings> read() => inner.read();

  @override
  Stream<MachineSettings> watch() => inner.watch();

  @override
  Future<MachineSettings> save(MachineSettings settings, {required int expectedRevision}) async =>
      throw const ServiceException('WRITE-FAILED', 'The settings file is read-only.');
}

void main() {
  late FakeMachineSettingsRepository repository;

  setUp(() => repository = FakeMachineSettingsRepository());

  Future<ProviderContainer> openSettings(WidgetTester tester, {MachineSettingsRepository? repo}) async {
    await pumpApp(
      tester,
      overrides: [
        windowControllerProvider.overrideWithValue(FakeWindowController()),
        machineSettingsRepositoryProvider.overrideWithValue(repo ?? repository),
      ],
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    return ProviderScope.containerOf(tester.element(find.byType(SettingsPage)));
  }

  Future<void> tapSwitch(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  group('saves through the repository', () {
    testWidgets('progress window, keep on top and checking files', (tester) async {
      await openSettings(tester);
      final start = await repository.read();
      expect(start.progressWindow, isTrue);
      expect(start.keepOnTop, isFalse);
      expect(start.verifyOutput, isTrue);

      await tapSwitch(tester, 'Keep the progress window on top');
      var saved = await repository.read();
      expect(saved.keepOnTop, isTrue);
      expect(saved.revision, start.revision + 1);

      await tapSwitch(tester, 'Check each file after rendering');
      saved = await repository.read();
      expect(saved.verifyOutput, isFalse);
      expect(saved.revision, start.revision + 2);
      expect(find.textContaining('without the ffprobe check'), findsOneWidget);

      await tapSwitch(tester, 'Show a progress window during renders');
      saved = await repository.read();
      expect(saved.progressWindow, isFalse);
      expect(saved.revision, start.revision + 3);
      expect(saved.keepOnTop, isTrue, reason: 'turning the window off keeps the pin as it was');
    });

    testWidgets('keep on top waits for the progress window', (tester) async {
      await repository.save(
        (await repository.read()).copyWith(progressWindow: false),
        expectedRevision: (await repository.read()).revision,
      );
      await openSettings(tester);
      expect(find.text('Turn on the progress window to choose this.'), findsOneWidget);
      final before = await repository.read();
      await tapSwitch(tester, 'Keep the progress window on top');
      final after = await repository.read();
      expect(after.keepOnTop, isFalse);
      expect(after.revision, before.revision, reason: 'a disabled switch saves nothing');
    });

    testWidgets('default FFmpeg', (tester) async {
      await openSettings(tester);
      final start = await repository.read();
      expect(start.defaultFFmpegId, 'gyan-8.1');
      await tester.tap(find.bySemanticsLabel('Default FFmpeg'));
      await tester.pumpAndSettle();
      expect(find.text('Version 7.1.1, gyan.dev essentials build, GPL v3'), findsOneWidget);
      await tester.tap(find.text('FFmpeg 7.1.1').last);
      await tester.pumpAndSettle();
      final saved = await repository.read();
      expect(saved.defaultFFmpegId, 'manual-7.1');
      expect(saved.revision, start.revision + 1);
      expect(find.text(r'C:\ffmpeg\bin\ffmpeg.exe'), findsOneWidget);
    });

    testWidgets('theme', (tester) async {
      final container = await openSettings(tester);
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(container.read(themePreferenceProvider), ThemePreference.dark);
      expect((await repository.read()).theme, 'dark');
      await tester.tap(find.text('Follow Windows'));
      await tester.pumpAndSettle();
      expect((await repository.read()).theme, 'system');
    });
  });

  testWidgets('a change saved elsewhere shows at once', (tester) async {
    await openSettings(tester);
    final current = await repository.read();
    await repository.save(
      current.copyWith(verifyOutput: false, defaultFFmpegId: 'btbn-lgpl-8.0'),
      expectedRevision: current.revision,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('without the ffprobe check'), findsOneWidget);
    expect(find.text(r'D:\Tools\ffmpeg-n8.0-latest-win64-lgpl-shared\bin\ffmpeg.exe'), findsOneWidget);
  });

  testWidgets('a conflicting save is reapplied and keeps the other window’s change', (tester) async {
    final conflicted = _ConflictOnce(repository, (s) => s.copyWith(defaultFFmpegId: 'manual-7.1'));
    await openSettings(tester, repo: conflicted);
    final start = await repository.read();
    await tapSwitch(tester, 'Keep the progress window on top');
    final saved = await repository.read();
    expect(conflicted.saves, 2, reason: 'the first save lost, the writer read again and retried');
    expect(saved.keepOnTop, isTrue);
    expect(saved.defaultFFmpegId, 'manual-7.1');
    expect(saved.revision, start.revision + 2);
    expect(find.textContaining('Couldn’t save'), findsNothing);
  });

  testWidgets('no installations: renders need a default FFmpeg', (tester) async {
    await openSettings(tester);
    final current = await repository.read();
    await repository.save(
      current.copyWith(installations: const <FFmpegInstallation>[], defaultFFmpegId: null),
      expectedRevision: current.revision,
    );
    await tester.pumpAndSettle();
    expect(find.text('Renders need a default FFmpeg, and none is set up yet.'), findsOneWidget);
    expect(find.bySemanticsLabel('Default FFmpeg'), findsNothing, reason: 'nothing to choose from');
    await tester.tap(find.text('Open the FFmpeg page'));
    await tester.pumpAndSettle();
    expect(find.byType(FFmpegPage), findsOneWidget);
  });

  testWidgets('a default that isn’t registered any more is an error, not a quiet switch', (tester) async {
    final settings = await FakeMachineSettingsRepository().read();
    // A file written elsewhere; the fake repository itself refuses to save this.
    repository = FakeMachineSettingsRepository(settings: settings.copyWith(defaultFFmpegId: 'gone'));
    await openSettings(tester);
    expect(find.text('The default FFmpeg “gone” isn’t one of the installations any more.'), findsOneWidget);
    expect(find.text('Renders stop until you choose one.'), findsOneWidget);
  });

  testWidgets('a failed save says so and leaves the stored value', (tester) async {
    await openSettings(tester, repo: _Failing(repository));
    final before = await repository.read();
    await tapSwitch(tester, 'Check each file after rendering');
    expect(find.text('Couldn’t save: The settings file is read-only.'), findsOneWidget);
    expect((await repository.read()).verifyOutput, before.verifyOutput);
    expect(find.textContaining('without the ffprobe check'), findsNothing);
  });

  testWidgets('Manage installations opens the FFmpeg screen', (tester) async {
    final container = await openSettings(tester);
    await tester.tap(find.text('Manage installations'));
    await tester.pumpAndSettle();
    expect(container.read(desktopSectionProvider), DesktopSection.ffmpeg);
    expect(find.byType(FFmpegPage), findsOneWidget);
  });

  testWidgets('About names the core and says the services are samples', (tester) async {
    await openSettings(tester);
    expect(find.text('0.1.0-b0-fake, preview core (fake)'), findsOneWidget);
    expect(find.text('Sample data from the platform’s fakes. Settings last until the app closes.'), findsOneWidget);
  });

  testWidgets('About says where this PC\'s services keep their files', (tester) async {
    final services = _OnThisPc();
    addTearDown(services.dispose);
    await pumpApp(
      tester,
      services: services,
      overrides: [windowControllerProvider.overrideWithValue(FakeWindowController())],
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'This PC. Settings and presets are in "C:\\Users\\Ana\\AppData\\Roaming\\VegasEncoder"; FFmpeg checks and '
        'render records in "C:\\Users\\Ana\\AppData\\Local\\VegasEncoder".',
      ),
      findsOneWidget,
    );
  });

  group('default FFmpeg state', () {
    test('says when renders have no FFmpeg to use', () async {
      final settings = await FakeMachineSettingsRepository().read();
      expect(defaultFFmpegState(settings), DefaultFFmpegState.ok);
      expect(defaultFFmpegState(settings.copyWith(defaultFFmpegId: null)), DefaultFFmpegState.notChosen);
      expect(defaultFFmpegState(settings.copyWith(defaultFFmpegId: 'gone')), DefaultFFmpegState.unregistered);
      expect(defaultFFmpegState(MachineSettings()), DefaultFFmpegState.noInstallations);
      expect(defaultFFmpegState(MachineSettings(defaultFFmpegId: 'gone')), DefaultFFmpegState.unregistered);
    });
  });
}

/// The fakes, reporting the folders the Windows services would use.
class _OnThisPc extends FakeAppServices {
  @override
  ServicePaths get paths => ServicePaths(
    roaming: r'C:\Users\Ana\AppData\Roaming\VegasEncoder',
    local: r'C:\Users\Ana\AppData\Local\VegasEncoder',
  );
}
