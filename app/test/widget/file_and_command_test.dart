import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vegas_encoder/design/components/command_view.dart';
import 'package:vegas_encoder/design/components/size_card.dart';
import 'package:vegas_encoder/features/gallery/samples.dart';

import '../helpers.dart';

String _plain(WidgetTester tester) => tester
    .widget<RichText>(find.descendant(of: find.byType(CommandView), matching: find.byType(RichText)))
    .text
    .toPlainText();

/// Centre of the first occurrence of [text] inside the command.
Offset _offsetOf(WidgetTester tester, String text) {
  final finder = find.descendant(of: find.byType(CommandView), matching: find.byType(RichText));
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  final start = _plain(tester).indexOf(text);
  expect(start, greaterThanOrEqualTo(0), reason: text);
  final boxes = paragraph.getBoxesForSelection(TextSelection(baseOffset: start, extentOffset: start + text.length));
  return paragraph.localToGlobal(boxes.first.toRect().center);
}

void main() {
  group('SizeQualityCard', () {
    testWidgets('quality mode: the core\'s total, the per-minute rate and its typical range', (tester) async {
      int? length = 600;
      await pumpThemed(
        tester,
        SizedBox(
          width: 340,
          child: StatefulBuilder(
            builder: (context, setState) => SizeQualityCard(
              estimate: Samples.estimateFor(length),
              lengthSeconds: length,
              onLengthChanged: (v) => setState(() => length = v),
            ),
          ),
        ),
      );
      expect(find.text('About 537\u00A0MB', findRichText: true), findsOneWidget);
      expect(find.text('About 53.7\u00A0MB per minute, typically 32.2\u00A0MB to 85.9\u00A0MB.'), findsOneWidget);
      expect(find.text('Video 6.8\u00A0Mb/s', findRichText: true), findsOneWidget);
      expect(find.text('Audio 320\u00A0kb/s', findRichText: true), findsOneWidget);
      await tester.enterText(find.byType(TextField), '20:00');
      await tester.pump();
      expect(length, 1200);
      expect(find.text('About 1.07\u00A0GB', findRichText: true), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'soon');
      await tester.pump();
      expect(length, isNull);
      expect(find.text('Type a length', findRichText: true), findsOneWidget);
      expect(
        find.text('About 53.7\u00A0MB per minute, typically 32.2\u00A0MB to 85.9\u00A0MB.'),
        findsOneWidget,
        reason: 'the rate needs no length',
      );
    });

    testWidgets('bitrate mode with audio off: exact figure, no audio share', (tester) async {
      await pumpThemed(
        tester,
        const SizedBox(
          width: 340,
          child: SizeQualityCard(
            estimate: SizeEstimate(
              videoKbps: 8000,
              audioKbps: null,
              approximate: false,
              bytesPerMinute: 60e6,
              totalBytes: 120e6,
              consequences: ['No audio: the file has video only.'],
            ),
            lengthSeconds: 120,
            onLengthChanged: _ignore,
            compact: true,
          ),
        ),
      );
      expect(find.text('120\u00A0MB', findRichText: true), findsOneWidget);
      expect(find.text('60.0\u00A0MB per minute, set by the bitrate.'), findsOneWidget);
      expect(find.text('Audio off', findRichText: true), findsOneWidget);
      expect(find.text('No audio: the file has video only.'), findsOneWidget);
    });

    testWidgets('a typed length without a total from the core says so', (tester) async {
      await pumpThemed(
        tester,
        SizedBox(
          width: 340,
          child: SizeQualityCard(
            estimate: SizeEstimate(
              videoKbps: 6840,
              audioKbps: 320,
              approximate: true,
              bytesPerMinute: Samples.estimateFor(null).bytesPerMinute,
              totalNote: 'Total not available yet',
            ),
            lengthSeconds: 600,
            onLengthChanged: (_) {},
          ),
        ),
      );
      expect(find.text('Total not available yet', findRichText: true), findsOneWidget);
      expect(find.text('About 53.7\u00A0MB per minute.'), findsOneWidget);
    });

    testWidgets('a typed length gets the core\'s range for that length', (tester) async {
      int? length = 600;
      await pumpThemed(
        tester,
        SizedBox(
          width: 340,
          child: StatefulBuilder(
            builder: (context, setState) => SizeQualityCard(
              estimate: SizeEstimate(
                videoKbps: 6840,
                audioKbps: 320,
                approximate: true,
                bytesPerMinute: 53670329.67,
                totalBytes: length == null ? null : 536703296.7,
                minBytesPerMinute: 32202197.8,
                maxBytesPerMinute: 85872527.47,
                minTotalBytes: length == null ? null : 322021978.0,
                maxTotalBytes: length == null ? null : 858725274.7,
              ),
              lengthSeconds: length,
              onLengthChanged: (v) => setState(() => length = v),
            ),
          ),
        ),
      );
      expect(find.text('About 537\u00A0MB', findRichText: true), findsOneWidget);
      expect(
        find.text('About 53.7\u00A0MB per minute. Typically 322\u00A0MB to 859\u00A0MB for 10:00.'),
        findsOneWidget,
      );
      expect(find.textContaining('typically'), findsNothing, reason: 'the per-minute range gives way');

      await tester.enterText(find.byType(TextField), 'soon');
      await tester.pump();
      expect(length, isNull);
      expect(find.text('Type a length', findRichText: true), findsOneWidget);
      expect(
        find.text('About 53.7\u00A0MB per minute, typically 32.2\u00A0MB to 85.9\u00A0MB.'),
        findsOneWidget,
        reason: 'without a length, the per-minute range',
      );
      expect(find.textContaining('Typically'), findsNothing);
    });

    testWidgets('the split bar shows video and audio shares', (tester) async {
      await pumpThemed(
        tester,
        SizedBox(
          width: 340,
          child: SizeQualityCard(estimate: Samples.estimateFor(600), lengthSeconds: 600, onLengthChanged: (_) {}),
        ),
      );
      final bars = find.descendant(of: find.byType(ClipRRect), matching: find.byType(DecoratedBox));
      expect(bars, findsNWidgets(2));
      final video = tester.getSize(bars.at(0)), audio = tester.getSize(bars.at(1));
      expect(video.height, 8);
      expect(video.width / (video.width + audio.width), closeTo(6840 / 7160, 0.02));
    });
  });

  group('CommandView', () {
    testWidgets('inputs collapse into a chip that expands on click', (tester) async {
      await pumpThemed(tester, const SizedBox(width: 640, child: CommandView(command: Samples.command)));
      expect(_plain(tester), contains('VEGAS video + audio'));
      expect(_plain(tester), isNot(contains('rawvideo')));
      expect(_plain(tester), contains('-c:v libx264 -preset slow -crf 18'));
      expect(_plain(tester), contains(' ^\n  -c:a aac -b:a 320k ^\n'));
      await tester.tapAt(_offsetOf(tester, 'VEGAS video + audio'));
      await tester.pump();
      expect(
        _plain(tester),
        contains(r'-f rawvideo -pix_fmt p010le -s 1920x1080 -r 30000/1001 -i \\.\pipe\vegas-encoder-0000-video'),
      );
    });

    testWidgets('clicking a token reports the field that made it', (tester) async {
      final tapped = <String?>[];
      await pumpThemed(
        tester,
        SizedBox(
          width: 640,
          child: CommandView(command: Samples.command, onTokenTap: (t) => tapped.add(t.field)),
        ),
      );
      await tester.tapAt(_offsetOf(tester, '-crf'));
      await tester.tapAt(_offsetOf(tester, '320k'));
      expect(tapped, ['video.quality', 'audio.bitrate']);
    });

    testWidgets('single-line layout has no continuation carets', (tester) async {
      await pumpThemed(
        tester,
        const SizedBox(width: 640, child: CommandView(command: Samples.command, multiline: false)),
      );
      expect(_plain(tester), isNot(contains('^')));
    });

    testWidgets('Copy puts the full command on the clipboard', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await pumpThemed(
        tester,
        SizedBox(width: 640, child: CommandHeader(onCopy: () => copyCommand(Samples.command.copyText))),
      );
      await tester.tap(find.text('Copy'));
      await tester.pump();
      expect(copied, Samples.command.copyText);
      expect(copied, contains(r'\\.\pipe\vegas-encoder-0000-video'));
    });

    test('flags are told apart from values', () {
      expect(const CommandToken('-crf').isFlag, isTrue);
      expect(const CommandToken('-1').isFlag, isFalse);
      expect(const CommandToken('+faststart').isFlag, isFalse);
      expect(const CommandToken('"D:\\x.mp4"').isFlag, isFalse);
    });
  });
}

void _ignore(int? _) {}
