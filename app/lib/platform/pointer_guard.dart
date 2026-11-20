import 'dart:ui';

/// Cancels a press that never got its release, before the device's next press.
///
/// Closing the native Open dialog by double-clicking hands the Flutter view
/// two presses and no release (FIX_PLAN_0.2.1 C1). The control under the
/// pointer then waits for a release that never comes and ignores every
/// later click until it is rebuilt. A device can't press again without
/// releasing, so a second press first cancels the one still open, and the
/// next real click lands. Returns a callback that removes the guard.
VoidCallback guardStrayPresses(PlatformDispatcher dispatcher) {
  final forward = dispatcher.onPointerDataPacket;
  final open = <int, PointerData>{};
  dispatcher.onPointerDataPacket = (packet) {
    List<PointerData>? fixed;
    for (final (i, data) in packet.data.indexed) {
      switch (data.change) {
        case PointerChange.down:
          if (open[data.device] case final stale?) {
            (fixed ??= packet.data.sublist(0, i)).add(
              PointerData(
                viewId: stale.viewId,
                timeStamp: data.timeStamp,
                change: PointerChange.cancel,
                kind: stale.kind,
                device: stale.device,
                pointerIdentifier: stale.pointerIdentifier,
                physicalX: stale.physicalX,
                physicalY: stale.physicalY,
                synthesized: true,
              ),
            );
          }
          open[data.device] = data;
        case PointerChange.up || PointerChange.cancel:
          open.remove(data.device);
        default:
      }
      fixed?.add(data);
    }
    forward?.call(fixed == null ? packet : PointerDataPacket(data: fixed));
  };
  return () => dispatcher.onPointerDataPacket = forward;
}
