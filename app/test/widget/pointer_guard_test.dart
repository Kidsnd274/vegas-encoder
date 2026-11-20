import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vegas_encoder/platform/pointer_guard.dart';

import '../raw_pointer.dart';

void main() {
  Future<(Offset, int Function(), int Function())> target(WidgetTester tester) async {
    var taps = 0;
    var cancels = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => taps++,
            onTapCancel: () => cancels++,
            child: const SizedBox(width: 200, height: 100),
          ),
        ),
      ),
    );
    return (tester.getCenter(find.byType(SizedBox)), () => taps, () => cancels);
  }

  testWidgets('a press left open by a native dialog no longer swallows the next click (C1)', (tester) async {
    addTearDown(guardStrayPresses(tester.binding.platformDispatcher));
    final (at, taps, _) = await target(tester);
    final mouse = RawMouse(tester, at)
      // The dialog's double-click: two presses, no release.
      ..strayPress(at)
      ..strayPress(at);
    await tester.pump(const Duration(milliseconds: 200));
    expect(taps(), 0, reason: 'a press without a release is not a click');

    await mouse.click(at);
    expect(taps(), 1, reason: 'the next real click lands');
    await mouse.click(at);
    expect(taps(), 2);
  });

  testWidgets('ordinary clicks pass through unchanged', (tester) async {
    addTearDown(guardStrayPresses(tester.binding.platformDispatcher));
    final (at, taps, cancels) = await target(tester);
    final mouse = RawMouse(tester, at);
    await mouse.click(at);
    await mouse.click(at);
    expect((taps(), cancels()), (2, 0));
  });

  testWidgets('removing the guard restores the previous handler', (tester) async {
    final before = tester.binding.platformDispatcher.onPointerDataPacket;
    guardStrayPresses(tester.binding.platformDispatcher)();
    expect(tester.binding.platformDispatcher.onPointerDataPacket, same(before));
  });
}
