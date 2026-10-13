import 'package:flutter/material.dart' show Scrollable, TextField;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart';
import 'package:vegas_encoder/app/app.dart';
import 'package:vegas_encoder/features/ffmpeg/capability_table.dart';
import 'package:vegas_encoder/features/ffmpeg/encoder_detail.dart';
import 'package:vegas_encoder/features/ffmpeg/installation_card.dart';
import 'package:vegas_encoder/features/presets/presets_page.dart';
import 'package:vegas_encoder/platform/window_channel.dart';
import 'package:vegas_encoder/state/app_state.dart';
import 'package:vegas_encoder/state/presets.dart';
import 'package:vegas_encoder/state/services.dart';

import '../ffmpeg_doubles.dart';
import '../helpers.dart';

/// The FFmpeg screen (S4) on the platform fakes. No FFmpeg runs: discovery,
/// probes and hardware tests are B0 fixtures, and the Open dialog is faked.
void main() {
  const addedPath = r'E:\Tools\ffmpeg-8.1\bin\ffmpeg.exe';
  late FakeWindowController window;
  late FakeMachineSettingsRepository machine;
  late FakeFFmpegDiscovery discovery;

  Future<FFmpegInstallation> fixture(String id) async =>
      (await FakeFFmpegDiscovery().list()).singleWhere((i) => i.id == id);

  Future<void> open(
    WidgetTester tester, {
    List<Override> overrides = const [],
    Size? view,
    FakeFFmpegDiscovery? withDiscovery,
  }) async {
    final manual = await tester.runAsync(() => fixture('manual-7.1'));
    final extra = FFmpegInstallation.fromJson({
      ...manual!.toJson(),
      'id': 'manual-8.1',
      'label': 'FFmpeg 8.1 portable',
      'path': addedPath,
      'identity': {...manual.identity.toJson(), 'key': 'b0-fixture-manual-8.1'},
    });
    window = FakeWindowController();
    machine = FakeMachineSettingsRepository();
    discovery = withDiscovery ?? FakeFFmpegDiscovery(additions: {addedPath: extra});
    await pumpApp(
      tester,
      view: view ?? const Size(1440, 900),
      overrides: [
        windowControllerProvider.overrideWithValue(window),
        machineSettingsRepositoryProvider.overrideWithValue(machine),
        ffmpegDiscoveryProvider.overrideWithValue(discovery),
        ...overrides,
      ],
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  Finder card(String label) => find.ancestor(of: find.text(label), matching: find.byType(InstallationCard));
  Finder inCard(String label, String text) => find.descendant(of: card(label), matching: find.text(text));
  Finder detailTitle(String text) => find.descendant(of: find.byType(EncoderDetail), matching: find.text(text));
  Finder row(String ffmpegName) => find.descendant(of: find.byType(CapabilityTable), matching: find.text(ffmpegName));

  ProviderContainer container(WidgetTester tester) => ProviderScope.containerOf(tester.element(find.byType(VeApp)));

  testWidgets('shows each installation, the default, and the default’s encoders', (tester) async {
    await open(tester);
    expect(find.byType(InstallationCard), findsNWidgets(3));
    expect(inCard('FFmpeg 8.1 full', 'Default'), findsOneWidget);
    expect(inCard('FFmpeg 7.1.1', 'Default'), findsNothing);
    expect(inCard('FFmpeg 8.1 full', 'Set as default'), findsNothing, reason: 'it already is');
    expect(find.textContaining('Can’t render 1 preset: needs x264'), findsOneWidget);
    expect(find.text('FFmpeg 8.1 full: 2 video and 1 audio encoders not ready'), findsOneWidget);
    expect(detailTitle('x264'), findsOneWidget);
  });

  testWidgets('choosing a row shows why it isn’t ready; arrow keys move', (tester) async {
    await open(tester);
    await tester.tap(row('hevc_qsv'));
    await tester.pumpAndSettle();
    expect(detailTitle('Quick Sync HEVC'), findsOneWidget);
    expect(find.text('[hevc_qsv @ 000001d4] Error creating a MFX session: -9.'), findsOneWidget);
    expect(find.text('Used by 0 presets'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(detailTitle('SVT-AV1'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(detailTitle('Quick Sync HEVC'), findsOneWidget);
  });

  testWidgets('another installation, audio, only problems, search', (tester) async {
    await open(tester);
    await tester.tap(find.text('FFmpeg 8.0 LGPL'));
    await tester.pumpAndSettle();
    expect(find.text('FFmpeg 8.0 LGPL: 4 video and 1 audio encoders not ready'), findsOneWidget);
    await tester.tap(find.text('Only problems'));
    await tester.pumpAndSettle();
    expect(row('libx264'), findsOneWidget);
    expect(row('libsvtav1'), findsNothing);

    await tester.tap(find.text('Audio encoders'));
    await tester.pumpAndSettle();
    expect(row('libfdk_aac'), findsOneWidget);
    expect(find.text('Hardware'), findsNothing, reason: 'no hardware audio encoders');

    await tester.tap(find.text('All'));
    await tester.tap(find.text('Video encoders'));
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'nvenc');
    await tester.pumpAndSettle();
    expect(row('h264_nvenc'), findsOneWidget);
    expect(row('libx264'), findsNothing);
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No encoders match “zzz”.'), findsOneWidget);
  });

  testWidgets('Set as default saves machine settings; the Default mark moves', (tester) async {
    await open(tester);
    await tester.tap(inCard('FFmpeg 7.1.1', 'Set as default'));
    await tester.pumpAndSettle();
    final saved = await tester.runAsync(machine.read);
    expect(saved!.defaultFFmpegId, 'manual-7.1');
    expect(saved.revision, 1);
    expect(inCard('FFmpeg 7.1.1', 'Default'), findsOneWidget);
    expect(inCard('FFmpeg 8.1 full', 'Default'), findsNothing);
    expect(find.text('FFmpeg 7.1.1 is now the default. The next render uses it.'), findsOneWidget);
  });

  testWidgets('Add FFmpeg… opens the Open dialog, adds and checks what was chosen', (tester) async {
    await open(tester);
    window.pickedFile = null;
    await tester.tap(find.text('Add FFmpeg…'));
    await tester.pumpAndSettle();
    expect(window.calls, contains('pickFile(ffmpeg.exe)'));
    expect(find.byType(InstallationCard), findsNWidgets(3), reason: 'cancelled');

    window.pickedFile = addedPath;
    await tester.tap(find.text('Add FFmpeg…'));
    await tester.pumpAndSettle();
    expect(find.byType(InstallationCard), findsNWidgets(4));
    expect(find.text('Added FFmpeg 8.1 portable'), findsOneWidget);
    expect(find.text('FFmpeg 8.1 portable: 2 video and 1 audio encoders not ready'), findsOneWidget);
    final saved = await tester.runAsync(machine.read);
    expect(saved!.installations.map((i) => i.id), contains('manual-8.1'));
  });

  testWidgets('Add FFmpeg… says why discovery refused a file', (tester) async {
    await open(tester);
    window.pickedFile = r'C:\Windows\notepad.exe';
    await tester.tap(find.text('Add FFmpeg…'));
    await tester.pumpAndSettle();
    expect(find.textContaining(r'Couldn’t add C:\Windows\notepad.exe: '), findsOneWidget);
    expect(find.byType(InstallationCard), findsNWidgets(3));
  });

  testWidgets('Remove… asks first, then forgets the installation', (tester) async {
    await open(tester);
    await tester.tap(inCard('FFmpeg 7.1.1', 'Remove…'));
    await tester.pumpAndSettle();
    expect(find.text('Remove FFmpeg 7.1.1?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(InstallationCard), findsNWidgets(3));

    await tester.tap(inCard('FFmpeg 7.1.1', 'Remove…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.byType(InstallationCard), findsNWidgets(2));
    expect(card('FFmpeg 7.1.1'), findsNothing);
  });

  testWidgets('Copy path puts the exact path on the clipboard', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await open(tester);
    await tester.tap(inCard('FFmpeg 7.1.1', 'Copy path'));
    await tester.pumpAndSettle();
    expect(copied, r'C:\ffmpeg\bin\ffmpeg.exe');
    expect(find.text('Path copied'), findsOneWidget);
  });

  testWidgets('Test hardware encoders: Testing… while it runs', (tester) async {
    await open(tester, overrides: [hardwareTestsProvider.overrideWithValue(StalledHardwareTests())]);
    await tester.tap(find.text('Test hardware encoders'));
    await tester.pump();
    expect(find.text('Testing…'), findsWidgets);
    expect(find.text('Running a short test encode'), findsWidgets);
  });

  testWidgets('Test hardware encoders: results replace the states, and a toast sums up', (tester) async {
    await open(tester);
    await tester.tap(find.text('Test hardware encoders'));
    await tester.pumpAndSettle();
    expect(find.text('Hardware tests finished: 3 ready, 2 failed'), findsOneWidget);
    await tester.tap(row('hevc_qsv'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No matching device'), findsOneWidget, reason: 'the test’s failure class');
    await tester.scrollUntilVisible(
      find.text('Test Quick Sync HEVC again'),
      200,
      scrollable: find.descendant(of: find.byType(EncoderDetail), matching: find.byType(Scrollable)),
    );
    await tester.tap(find.text('Test Quick Sync HEVC again'));
    await tester.pumpAndSettle();
    expect(find.text('Quick Sync HEVC: the test encode failed'), findsOneWidget);
  });

  testWidgets('Scan again: progress on the card while a check runs', (tester) async {
    final probe = StalledProbe();
    await open(tester, overrides: [ffmpegProbeProvider.overrideWithValue(probe)]);
    await tester.tap(find.text('Scan again'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Scanning…'), findsOneWidget);
    expect(find.text('Reading encoders… 18 of 25'), findsOneWidget);
    await tester.runAsync(probe.finish);
    await tester.pumpAndSettle();
    expect(find.text('ffmpeg.exe stopped responding.'), findsWidgets);
  });

  testWidgets('Scan again reports what it found', (tester) async {
    await open(tester);
    await tester.tap(find.text('Scan again'));
    await tester.pumpAndSettle();
    expect(find.text('Scanned again. Found 3 installations.'), findsOneWidget);
  });

  testWidgets('a preset that uses the encoder opens in Presets', (tester) async {
    await open(tester);
    await tester.tap(find.descendant(of: find.byType(EncoderDetail), matching: find.text('YouTube upload, H.264')));
    await tester.pumpAndSettle();
    expect(find.byType(PresetsPage), findsOneWidget);
    final c = container(tester);
    expect(c.read(desktopSectionProvider), DesktopSection.presets);
    expect(c.read(presetsControllerProvider).selectedId, 'yt-h264');
  });

  testWidgets('no installations: says what to do', (tester) async {
    await open(tester, withDiscovery: FakeFFmpegDiscovery(installations: []));
    expect(find.textContaining('No FFmpeg found on this PC.'), findsOneWidget);
    expect(find.byType(CapabilityTable), findsNothing);
  });

  testWidgets('the minimum window drops the name and reason columns', (tester) async {
    await open(tester, view: const Size(1100, 700));
    expect(find.text('FFmpeg name'), findsNothing);
    expect(find.text('Reason'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
