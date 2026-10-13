import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vegas_encoder/design/components/button.dart';
import 'package:vegas_encoder/design/components/field.dart';
import 'package:vegas_encoder/design/components/message.dart';
import 'package:vegas_encoder/design/components/popover.dart';
import 'package:vegas_encoder/design/components/segmented.dart';
import 'package:vegas_encoder/design/components/select.dart';
import 'package:vegas_encoder/design/components/slider.dart';
import 'package:vegas_encoder/design/components/status.dart';
import 'package:vegas_encoder/design/components/switch.dart';
import 'package:vegas_encoder/design/components/text_field.dart';
import 'package:vegas_encoder/design/icons.dart';
import 'package:vegas_encoder/features/gallery/samples.dart';

import '../helpers.dart';

void main() {
  group('VeButton', () {
    testWidgets('click, Enter and Space activate; disabled does nothing', (tester) async {
      var saves = 0;
      var other = 0;
      await pumpThemed(
        tester,
        Row(
          children: [
            VeButton(label: 'Save preset', icon: VeIcons.save, onPressed: () => saves++),
            VeButton(label: 'Disabled', onPressed: null, tooltip: 'Nothing changed yet.'),
            VeButton(label: 'Other', onPressed: () => other++),
          ],
        ),
      );
      await tester.tap(find.text('Save preset'));
      expect(saves, 1);
      await tester.tap(find.text('Disabled'), warnIfMissed: false);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(saves, 3);
      // Disabled buttons are skipped by Tab.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(other, 1);
    });

    testWidgets('exposes a button with its label', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(tester, VeButton(label: 'Apply to template', onPressed: () {}));
      expect(
        tester.getSemantics(find.byType(VeButton)),
        matchesSemantics(
          label: 'Apply to template',
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      handle.dispose();
    });
  });

  group('VeSegmented', () {
    testWidgets('click and arrow keys choose', (tester) async {
      String? picked;
      await pumpThemed(
        tester,
        StatefulBuilder(
          builder: (context, setState) => VeSegmented<String>(
            semanticLabel: 'Editing mode',
            segments: const [VeSegment('basic', 'Basic'), VeSegment('advanced', 'Advanced')],
            selected: picked ?? 'basic',
            onChanged: (v) => setState(() => picked = v),
          ),
        ),
      );
      await tester.tap(find.text('Advanced'));
      await tester.pump();
      expect(picked, 'advanced');
      await tester.tap(find.text('Basic'));
      await tester.pump();
      expect(picked, 'basic');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(picked, 'advanced');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(picked, 'basic');
    });
  });

  testWidgets('VeSwitch toggles and reports its state', (tester) async {
    final handle = tester.ensureSemantics();
    var on = true;
    await pumpThemed(
      tester,
      StatefulBuilder(
        builder: (context, setState) => VeSwitch(value: on, label: 'Audio', onChanged: (v) => setState(() => on = v)),
      ),
    );
    expect(
      tester.getSemantics(find.byType(VeSwitch)),
      matchesSemantics(
        label: 'Audio',
        hasToggledState: true,
        isToggled: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
        hasEnabledState: true,
        isEnabled: true,
      ),
    );
    await tester.tap(find.text('Audio'));
    await tester.pump();
    expect(on, isFalse);
    handle.dispose();
  });

  group('VeSlider', () {
    Future<List<double>> drive(
      WidgetTester tester, {
      required bool reversed,
      required List<LogicalKeyboardKey> keys,
    }) async {
      var value = 18.0;
      final seen = <double>[];
      await pumpThemed(
        tester,
        SizedBox(
          width: 300,
          child: StatefulBuilder(
            builder: (context, setState) => VeSlider(
              value: value,
              min: 0,
              max: 51,
              reversed: reversed,
              semanticLabel: 'Quality',
              onChanged: (v) => setState(() {
                value = v;
                seen.add(v);
              }),
            ),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      for (final k in keys) {
        await tester.sendKeyEvent(k);
        await tester.pump();
      }
      return seen;
    }

    testWidgets('reversed scale: right is higher quality (lower CRF)', (tester) async {
      final seen = await drive(
        tester,
        reversed: true,
        keys: [
          LogicalKeyboardKey.arrowRight, // 17
          LogicalKeyboardKey.arrowLeft, // 18
          LogicalKeyboardKey.arrowLeft, // 19
          LogicalKeyboardKey.pageUp, // 14
          LogicalKeyboardKey.pageDown, // 19
          LogicalKeyboardKey.home, // 51, left end
          LogicalKeyboardKey.end, // 0, right end
        ],
      );
      expect(seen, [17, 18, 19, 14, 19, 51, 0]);
    });

    testWidgets('normal scale steps up to the right', (tester) async {
      final seen = await drive(
        tester,
        reversed: false,
        keys: [LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.pageDown, LogicalKeyboardKey.end],
      );
      expect(seen, [19, 14, 51]);
    });

    testWidgets('a click on the right end of a reversed slider picks the lowest value', (tester) async {
      double? value;
      await pumpThemed(
        tester,
        SizedBox(
          width: 300,
          child: VeSlider(
            value: 18,
            min: 0,
            max: 51,
            reversed: true,
            semanticLabel: 'Quality',
            onChanged: (v) => value = v,
          ),
        ),
      );
      final box = tester.getRect(find.byType(VeSlider));
      await tester.tapAt(Offset(box.right - 2, box.center.dy));
      expect(value, 0);
      await tester.tapAt(Offset(box.left + 2, box.center.dy));
      expect(value, 51);
    });
  });

  group('VeQualityControl', () {
    testWidgets('read-out names the nearest mark; the field sets the value', (tester) async {
      var crf = 18;
      await pumpThemed(
        tester,
        SizedBox(
          width: 420,
          child: StatefulBuilder(
            builder: (context, setState) =>
                VeQualityControl(scale: Samples.crf, value: crf, onChanged: (v) => setState(() => crf = v)),
          ),
        ),
      );
      expect(find.text('CRF 18, visually lossless', findRichText: true), findsOneWidget);
      await tester.enterText(find.byType(TextField), '17');
      await tester.pump();
      expect(crf, 17);
      expect(find.text('CRF 17, near visually lossless', findRichText: true), findsOneWidget);
      await tester.enterText(find.byType(TextField), '99');
      await tester.pump();
      expect(crf, 17, reason: 'out of range values are ignored');
    });

    test('describe uses the closest mark', () {
      expect(Samples.crf.describe(23), (value: 'CRF 23', meaning: ', ffmpeg default'));
      expect(Samples.crf.describe(30), (value: 'CRF 30', meaning: ', near small, visible loss'));
    });
  });

  group('VeSelect and VeListbox', () {
    testWidgets('opens, moves with arrows, picks with Enter, Esc closes', (tester) async {
      var value = 'high';
      await pumpThemed(
        tester,
        SizedBox(
          width: 200,
          child: StatefulBuilder(
            builder: (context, setState) => VeSelect<String>(
              semanticLabel: 'Profile',
              value: value,
              options: [
                for (final v in const ['main', 'high', 'high10']) VeOption(v, v),
              ],
              onChanged: (v) => setState(() => value = v),
            ),
          ),
        ),
      );
      await tester.tap(find.text('high'));
      await tester.pumpAndSettle();
      expect(find.byType(VeListbox<String>), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(value, 'high10');
      expect(find.byType(VeListbox<String>), findsNothing);

      await tester.tap(find.text('high10'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(VeListbox<String>), findsNothing);
      expect(value, 'high10');
    });

    testWidgets('a click outside closes without choosing', (tester) async {
      var changed = false;
      await pumpThemed(
        tester,
        SizedBox(
          width: 200,
          child: VeSelect<String>(
            semanticLabel: 'Tune',
            value: 'film',
            options: const [VeOption('film', 'film'), VeOption('grain', 'grain')],
            onChanged: (_) => changed = true,
          ),
        ),
      );
      await tester.tap(find.text('film'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(900, 900));
      await tester.pumpAndSettle();
      expect(find.byType(VeListbox<String>), findsNothing);
      expect(changed, isFalse);
    });
  });

  group('VeEncoderPicker', () {
    testWidgets('groups by codec, shows availability, and still lets a missing encoder be chosen', (tester) async {
      var id = 'libx264';
      await pumpThemed(
        tester,
        SizedBox(
          width: 420,
          child: StatefulBuilder(
            builder: (context, setState) => VeEncoderPicker(
              groups: Samples.videoEncoders,
              selectedId: id,
              kindLabel: 'Video',
              installationLabel: 'FFmpeg 8.1 full',
              onChanged: (v) => setState(() => id = v),
            ),
          ),
        ),
      );
      expect(find.text('H.264, CPU, 10-bit'), findsOneWidget);
      await tester.tap(find.text('x264'));
      await tester.pumpAndSettle();
      expect(find.text('HEVC'), findsOneWidget);
      expect(find.text('Availability in FFmpeg 8.1 full.'), findsOneWidget);
      expect(find.text('Not in this FFmpeg'), findsOneWidget);
      expect(find.text('Failed test on this PC'), findsOneWidget);
      await tester.tap(find.text('QSV HEVC'));
      await tester.pumpAndSettle();
      expect(id, 'hevc_qsv');
      // The closed picker carries the problem.
      expect(find.text('Not in this FFmpeg'), findsOneWidget);
    });
  });

  group('messages', () {
    testWidgets('a message names its level for screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(
        tester,
        const VeMessage(level: VeLevel.warning, text: '-foo isn’t an option of x264.', fix: 'Check the spelling.'),
      );
      expect(find.bySemanticsLabel('Warning. -foo isn’t an option of x264. Check the spelling.'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the check list puts errors first and says when all is well', (tester) async {
      await pumpThemed(
        tester,
        const Column(
          children: [
            VeCheckList(
              emptyText: 'No problems.',
              checks: [
                VeCheck(level: VeLevel.info, text: 'note'),
                VeCheck(level: VeLevel.error, text: 'error'),
                VeCheck(level: VeLevel.warning, text: 'warning'),
              ],
            ),
            VeCheckList(emptyText: 'No problems with FFmpeg 8.1 full.', checks: []),
          ],
        ),
      );
      final ys = ['error', 'warning', 'note'].map((s) => tester.getTopLeft(find.text(s)).dy).toList();
      expect(ys[0], lessThan(ys[1]));
      expect(ys[1], lessThan(ys[2]));
      expect(find.text('No problems with FFmpeg 8.1 full.'), findsOneWidget);
    });

    testWidgets('status tags use the brief’s words', (tester) async {
      await pumpThemed(tester, Row(children: [for (final s in VeAvailability.values) VeStatusTag(s)]));
      for (final s in ['Ready', 'Not in this FFmpeg', 'Failed test on this PC', 'Testing…', 'Not checked yet']) {
        expect(find.text(s), findsOneWidget);
      }
    });
  });

  group('fields and inputs', () {
    testWidgets('number field reports numbers and empty, ignores letters', (tester) async {
      final seen = <num?>[];
      await pumpThemed(tester, VeNumberField(value: 8000, unit: 'kb/s', semanticLabel: 'Bitrate', onChanged: seen.add));
      expect(find.text('kb/s'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '12000');
      await tester.enterText(find.byType(TextField), '');
      expect(seen, [12000, null]);
    });

    testWidgets('field shows its read-out, blurb and messages', (tester) async {
      await pumpThemed(
        tester,
        const SizedBox(
          width: 400,
          child: VeField(
            label: 'Bit depth',
            readout: VeReadout(value: 'yuv420p', meaning: ', 8-bit 4:2:0', mono: true),
            blurb: Text('Explains the setting.'),
            modified: true,
            messages: [VeMessage(level: VeLevel.info, text: 'VEGAS delivers 10-bit frames.')],
            child: VeTextField(semanticLabel: 'x'),
          ),
        ),
      );
      expect(find.text('Bit depth'), findsOneWidget);
      expect(find.text('yuv420p, 8-bit 4:2:0', findRichText: true), findsOneWidget);
      expect(find.text('Explains the setting.'), findsOneWidget);
      expect(find.text('VEGAS delivers 10-bit frames.'), findsOneWidget);
      expect(find.bySemanticsLabel('Changed'), findsOneWidget);
    });
  });
}
