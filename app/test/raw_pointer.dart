import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter_test/flutter_test.dart';

/// A mouse sending raw pointer data, as the engine hands it to the
/// framework: the path `guardStrayPresses` wraps (`tester.tap` skips it).
class RawMouse {
  RawMouse(this.tester, Offset at) {
    send(ui.PointerChange.add, at);
  }

  final WidgetTester tester;
  var _next = 100;

  void send(ui.PointerChange change, Offset at, {int? pointer, int buttons = 0}) {
    final view = tester.view;
    final ratio = view.devicePixelRatio;
    tester.binding.platformDispatcher.onPointerDataPacket!(
      ui.PointerDataPacket(
        data: [
          ui.PointerData(
            viewId: view.viewId,
            change: change,
            kind: ui.PointerDeviceKind.mouse,
            device: 7,
            pointerIdentifier: pointer ?? _next,
            physicalX: at.dx * ratio,
            physicalY: at.dy * ratio,
            buttons: buttons,
          ),
        ],
      ),
    );
  }

  /// A press with no release: what closing the Open dialog by double-clicking
  /// leaves in the Flutter view (two of them).
  void strayPress(Offset at) => send(ui.PointerChange.down, at, pointer: ++_next, buttons: kPrimaryButton);

  Future<void> click(Offset at) async {
    final id = ++_next;
    send(ui.PointerChange.down, at, pointer: id, buttons: kPrimaryButton);
    await tester.pump(const Duration(milliseconds: 60));
    send(ui.PointerChange.up, at, pointer: id);
    await tester.pump();
  }
}
