import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vegas_encoder/design/components/signal_path/signal_path.dart';
import 'package:vegas_encoder/features/gallery/samples.dart';

import '../helpers.dart';

Widget _path(SignalPathModel model, {SignalPathLayout layout = SignalPathLayout.full, double width = 1180}) {
  return StatefulBuilder(
    builder: (context, setState) {
      return SizedBox(
        width: width,
        child: _Selectable(model: model, layout: layout),
      );
    },
  );
}

class _Selectable extends StatefulWidget {
  const _Selectable({required this.model, required this.layout});
  final SignalPathModel model;
  final SignalPathLayout layout;
  static final List<SignalNode> picked = [];

  @override
  State<_Selectable> createState() => _SelectableState();
}

class _SelectableState extends State<_Selectable> {
  SignalNode _selected = SignalNode.video;

  @override
  Widget build(BuildContext context) => SignalPath(
    model: widget.model,
    layout: widget.layout,
    selected: _selected,
    onSelect: (n) => setState(() {
      _selected = n;
      _Selectable.picked.add(n);
    }),
  );
}

void main() {
  setUp(_Selectable.picked.clear);

  testWidgets('full diagram shows every node, the conversion and the legend', (tester) async {
    await pumpThemed(tester, _path(Samples.youtube));
    for (final text in [
      'From VEGAS',
      '1920×1080',
      'P010, 10-bit 4:2:0',
      'x264',
      'CRF 18, slow',
      'AAC',
      '320 kb/s',
      'MP4',
      'Fast start',
      'Sample project.mp4',
      'Size and quality',
      'p010le to yuv420p',
      '4:2:0, precision lost',
      '10-bit',
      '8-bit',
      '32-bit float',
      'H.264',
      'Pixel format conversion',
      'CPU',
    ]) {
      expect(find.text(text), findsWidgets, reason: text);
    }
    expect(find.text('Preview with: 1920×1080, 29.97 fps, 48 kHz stereo, 10 minutes'), findsOneWidget);
  });

  testWidgets('clicking a node selects it; arrow keys move and wrap', (tester) async {
    await pumpThemed(tester, _path(Samples.youtube));
    await tester.tap(find.text('MP4'));
    await tester.pump();
    expect(_Selectable.picked.last, SignalNode.container);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(_Selectable.picked.last, SignalNode.file);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(_Selectable.picked.last, SignalNode.source, reason: 'wraps around');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(_Selectable.picked.last, SignalNode.file);
  });

  testWidgets('with audio off the audio node is a dashed note and is skipped', (tester) async {
    await pumpThemed(tester, _path(Samples.audioOffBadMux));
    expect(find.text('Audio is off. The file has video only.'), findsOneWidget);
    expect(find.text('Can’t mux'), findsOneWidget);
    await tester.tap(find.text('ProRes'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(_Selectable.picked.last, SignalNode.container);
  });

  testWidgets('a failed hardware encoder says so on its node', (tester) async {
    await pumpThemed(tester, _path(Samples.hevcMaster));
    expect(find.text('Failed test on this PC'), findsOneWidget);
    expect(find.text('No conversion'), findsOneWidget);
    expect(find.text('f32le to s32'), findsOneWidget);
  });

  testWidgets('Advanced mode reads back from the command', (tester) async {
    await pumpThemed(tester, _path(Samples.fromCommand));
    expect(find.text('Read from your command'), findsOneWidget);
    expect(find.text('Dashed nodes show what the command sets.'), findsOneWidget);
    expect(find.text('Name from Render As'), findsOneWidget);
    expect(find.text('Size and quality'), findsNothing);
  });

  testWidgets('the strip has short labels, marks and no legend', (tester) async {
    await pumpThemed(tester, _path(Samples.popupStrip, layout: SignalPathLayout.strip, width: 752));
    expect(tester.getSize(find.byType(SignalPath)).height, SignalPath.stripHeight);
    expect(find.text('10 to 8-bit'), findsOneWidget);
    expect(find.text('Rev. 6'), findsOneWidget);
    expect(find.text('Pixel format conversion'), findsNothing);
    expect(find.text('H.264'), findsNothing, reason: 'no codec labels in the strip');
    expect(find.text('3840×2160'), findsOneWidget);
    expect(find.text('29.97 fps, 10-bit'), findsOneWidget);
  });

  testWidgets('nodes have spoken names (UI_SPEC §9)', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpThemed(tester, _path(Samples.youtube));
    expect(find.bySemanticsLabel('From VEGAS. 1920 by 1080, 29.97 fps. Show details'), findsOneWidget);
    expect(find.bySemanticsLabel('Video encoder x264, CRF 18, slow. Ready'), findsOneWidget);
    expect(find.bySemanticsLabel('File Sample project.mp4. Show size and quality'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Container MP4')),
      isSemantics(isButton: true, hasTapAction: true),
    );
    handle.dispose();
  });

  testWidgets('wire thickness animates, and reduced motion makes it instant', (tester) async {
    Widget host(SignalPathModel m, {bool reduced = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduced, size: const Size(1400, 1100)),
      child: _path(m),
    );
    await pumpThemed(tester, host(Samples.youtube));
    await tester.pumpWidget(Container()); // reset
    await pumpThemed(tester, host(Samples.youtube, reduced: true), settle: false);
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });
}
