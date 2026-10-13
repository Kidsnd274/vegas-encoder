import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart' hide SizeEstimate;
import 'package:vegas_encoder/design/components/command_view.dart' show CommandView;
import 'package:vegas_encoder/design/components/field.dart' show VeField;
import 'package:vegas_encoder/design/components/message.dart';
import 'package:vegas_encoder/design/components/signal_path/signal_path.dart' show SignalPath;
import 'package:vegas_encoder/design/components/signal_path/signal_path_model.dart';
import 'package:vegas_encoder/design/components/size_card.dart';
import 'package:vegas_encoder/design/format.dart';
import 'package:vegas_encoder/features/presets/command_column.dart';
import 'package:vegas_encoder/features/presets/panels/extra_field.dart';
import 'package:vegas_encoder/features/shell/core_unavailable.dart';
import 'package:vegas_encoder/platform/window_channel.dart';
import 'package:vegas_encoder/state/app_state.dart';
import 'package:vegas_encoder/state/editor.dart';
import 'package:vegas_encoder/state/presets.dart';
import 'package:vegas_encoder/state/services.dart';

import '../helpers.dart';

/// The Presets screen on the native core (B2): edits now reach the C++ core
/// through `dart:ffi`, so the command, checks, signal path and estimate
/// follow them. Fake services, no FFmpeg, no VEGAS. The core's profile data is
/// B0/Linux bootstrap, not Windows-qualified, so these tests check what moves
/// and where it shows rather than the core's figures or wording.
void main() {
  late NativeVeCore core;

  setUpAll(() => core = NativeVeCore());

  Future<void> pump(WidgetTester tester) async {
    await pumpApp(
      tester,
      core: core,
      overrides: [
        windowControllerProvider.overrideWithValue(FakeWindowController()),
        presetLibraryProvider.overrideWithValue(FakePresetLibrary(now: () => '2026-10-14T02:00:00Z')),
      ],
    );
  }

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(CommandColumn)));
  EditorData editor(WidgetTester tester) => container(tester).read(editorProvider)!;

  String command(WidgetTester tester) => tester
      .widget<RichText>(find.descendant(of: find.byType(CommandView), matching: find.byType(RichText)))
      .text
      .toPlainText()
      .replaceAll(RegExp(r'\s*\^\n\s*'), ' ');
  SignalPathModel diagram(WidgetTester tester) => tester.widget<SignalPath>(find.byType(SignalPath)).model;
  Finder inCommand(Finder f) => find.descendant(of: find.byType(CommandColumn), matching: f);

  /// The messages under the control labelled [label].
  List<VeMessage> messagesAt(WidgetTester tester, String label) {
    final field = find.ancestor(of: find.text(label), matching: find.byType(VeField)).first;
    return tester.widgetList<VeMessage>(find.descendant(of: field, matching: find.byType(VeMessage))).toList();
  }

  Finder fieldWith(String text) =>
      find.byWidgetPredicate((w) => w is TextField && w.controller?.text == text, description: 'field "$text"');

  /// The open panel's Extra arguments.
  Finder extraField() => find.descendant(of: find.byType(ExtraArgumentsField), matching: find.byType(TextField));
  Finder setInExtra() => find.text('Set in Extra arguments.');

  Future<void> type(WidgetTester tester, Finder field, String text) async {
    await tester.enterText(field, text);
    await tester.pumpAndSettle();
  }

  Future<void> openNode(WidgetTester tester, String text) async {
    await tester.tap(find.text(text).first);
    await tester.pumpAndSettle();
  }

  testWidgets('the app runs on the native core', (tester) async {
    await pump(tester);
    final version = core.version;
    expect(version.isFake, isFalse);
    expect(container(tester).read(veCoreProvider), isA<NativeVeCore>());
    expect(container(tester).read(coreLoadErrorProvider), isNull);
    expect(editor(tester).compiled.ok, isTrue);
  });

  testWidgets('a quality edit rebuilds the command, the node and the estimate', (tester) async {
    await pump(tester);
    expect(command(tester), contains('-c:v libx264 -preset slow -crf 18'));
    await openNode(tester, 'Sample project.mp4');
    final before = editor(tester).total!.value!.totalBytes;

    await openNode(tester, 'CRF 18, slow');
    await type(tester, fieldWith('18'), '26');
    expect(command(tester), contains('-crf 26'));
    expect(command(tester), isNot(contains('-crf 18')));
    expect(inCommand(find.textContaining('preview core')), findsNothing, reason: 'no fake-core notice');
    expect(find.text('CRF 26, slow'), findsOneWidget, reason: 'the node shows the core\'s summary');

    await openNode(tester, 'Sample project.mp4');
    final after = editor(tester).total!.value!;
    expect(after.totalBytes, isNot(before), reason: 'a higher CRF changes the core\'s estimate');
    expect(find.text('About ${VeFormat.bytes(after.totalBytes!)}', findRichText: true), findsOneWidget);
  });

  testWidgets('bit depth moves the checks, the signal path and the pixel format', (tester) async {
    await pump(tester);
    expect(diagram(tester).video!.outputBits, 8);
    expect(diagram(tester).video!.conversion, isNotNull);
    expect(messagesAt(tester, 'Bit depth').where((m) => m.level == VeLevel.warning), isEmpty);
    final checksBefore = editor(tester).issues.map((i) => i.id).toSet();

    final depthField = find.ancestor(of: find.text('Bit depth'), matching: find.byType(VeField)).first;
    await tester.tap(find.descendant(of: depthField, matching: find.text('10-bit')));
    await tester.pumpAndSettle();
    expect(command(tester), contains('-pix_fmt yuv420p10le'));
    expect(diagram(tester).video!.outputBits, 10, reason: 'the wire stays thick');
    final issues = editor(tester).issues;
    expect(issues.map((i) => i.id).toSet(), isNot(checksBefore), reason: 'the checks follow the edit');
    final depthIssues = issues.where((i) => i.field == 'video.depth').toList();
    expect(depthIssues, isNotEmpty);
    expect(
      messagesAt(tester, 'Bit depth').map((m) => m.text),
      containsAll(depthIssues.map((i) => i.message)),
      reason: 'the core\'s issue shows at its field',
    );
    for (final i in depthIssues) {
      expect(inCommand(find.text(i.message)), findsOneWidget, reason: 'and in Checks');
    }
  });

  testWidgets('Extra arguments say which controls they replace', (tester) async {
    await pump(tester);
    expect(find.text('2 s (60 frames at 29.97 fps)', findRichText: true), findsOneWidget);
    expect(setInExtra(), findsNothing);

    await type(tester, extraField(), '-preset fast -g 120');
    expect(editor(tester).overriddenFields, unorderedEquals(['video.speed', 'video.gopSec']));
    expect(command(tester), contains('-preset fast'));
    expect(command(tester), isNot(contains('-preset slow')));
    expect(messagesAt(tester, 'Encoder speed').first.text, 'Set in Extra arguments.');
    expect(messagesAt(tester, 'Keyframes every').first.text, 'Set in Extra arguments.');
    expect(setInExtra(), findsNWidgets(2), reason: 'only the replaced controls say so');
    expect(
      find.text('120 frames at 29.97 fps', findRichText: true),
      findsOneWidget,
      reason: 'the core\'s final -g, without the seconds Extra replaced',
    );

    await type(tester, extraField(), '');
    expect(setInExtra(), findsNothing, reason: 'clearing Extra arguments gives the controls back');

    await openNode(tester, '320 kb/s');
    await type(tester, extraField(), '-b:a 192k');
    expect(editor(tester).overriddenFields, ['audio[0].bitrateK']);
    expect(command(tester), contains('-b:a 192k'));
    expect(command(tester), isNot(contains('-b:a 320k')));
    expect(setInExtra(), findsOneWidget);
  });

  testWidgets('keyframes read out the core\'s frame count for the typed seconds', (tester) async {
    await pump(tester);
    await type(tester, fieldWith('2'), '4');
    expect(editor(tester).compiled.value!.resolved!.gopFrames, 120);
    expect(find.text('4 s (120 frames at 29.97 fps)', findRichText: true), findsOneWidget);
    expect(command(tester), contains('-g 120'));

    await type(tester, fieldWith('4'), '');
    expect(editor(tester).compiled.value!.resolved!.gopFrames, isNull, reason: 'encoder default: no -g');
    expect(find.textContaining('frames at', findRichText: true), findsNothing);
  });

  testWidgets('a typed length gets the core\'s total and its range', (tester) async {
    await pump(tester);
    await openNode(tester, 'Sample project.mp4');
    await type(tester, fieldWith('10:00'), '25:00');
    final total = editor(tester).total!.value!;
    expect(total.minTotalBytes, isNotNull);
    expect(
      find.text(
        'About ${VeFormat.bytes(editor(tester).perMinute.value!.bytesPerMinute)} per minute. '
        'Typically ${VeFormat.bytes(total.minTotalBytes!)} to ${VeFormat.bytes(total.maxTotalBytes!)} '
        'for 25:00.',
      ),
      findsOneWidget,
    );
    expect(find.text('Total not available yet', findRichText: true), findsNothing);
  });

  testWidgets('no estimate: the File node gives the core\'s reason', (tester) async {
    await pump(tester);
    await type(tester, extraField(), '-vf scale=1280:720');
    await openNode(tester, 'Sample project.mp4');
    final estimate = editor(tester).perMinute.value!;
    expect(estimate.available, isFalse);
    expect(find.byType(SizeQualityCard), findsNothing);
    expect(find.text(estimate.explanation), findsOneWidget);
  });

  testWidgets('a native failure stays a failure, with the core\'s message', (tester) async {
    await pump(tester);
    // More than the 1 MiB transport limit, in a field the editor doesn't show.
    container(tester).read(presetsControllerProvider.notifier).edit((r) => r.copyWith(notes: 'x' * (1 << 20)));
    await tester.pumpAndSettle();
    final error = editor(tester).compiled.error!;
    expect(error.code, 'JSON-LIMIT');
    expect(editor(tester).compiled.notInPreviewCore, isFalse);
    expect(inCommand(find.text('The core couldn’t build the command: ${error.message}')), findsOneWidget);
    expect(inCommand(find.textContaining('preview core')), findsNothing);

    await openNode(tester, 'Sample project.mp4');
    expect(find.text('The core couldn’t work out an estimate: ${error.message}'), findsOneWidget);
  });

  testWidgets('a core that didn\'t load is said in place of the screens', (tester) async {
    const error = CoreException('NATIVE-LOAD', 'Cannot load the product core: ve_core.dll not found');
    await pumpApp(
      tester,
      core: const UnavailableCore(error),
      overrides: [windowControllerProvider.overrideWithValue(FakeWindowController())],
    );
    expect(find.byType(CoreUnavailable), findsOneWidget);
    expect(find.text('Vegas Encoder couldn’t load its core'), findsOneWidget);
    expect(find.text('NATIVE-LOAD: ${error.message}'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(CoreUnavailable), findsOneWidget, reason: 'every screen needs the core');
    expect(tester.takeException(), isNull);
  });
}
