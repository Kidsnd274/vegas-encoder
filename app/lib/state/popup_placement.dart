import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ve_services/ve_services.dart';

import '../platform/window_channel.dart';
import 'services.dart';
import 'ui_state.dart';

/// Read before the first popup frame. The runner centres this physical outer
/// size on the current owner and clamps it to that monitor's DPI/work area.
Future<WindowSize?> popupPlacement(ProviderContainer container) async {
  try {
    final size = (await container.read(machineSettingsRepositoryProvider).read()).uiState?.popupWindowSize;
    return size == null ? null : (width: size.width, height: size.height);
  } on Object {
    return null; // Missing/unreadable settings keep the default popup size.
  }
}

/// Best-effort UI persistence on Apply/Cancel/window close. Copy the latest
/// settings on each revision retry, retaining desktop fields and unknown keys.
Future<void> rememberPopupSize(WindowController window, UiStateWriter writer) async {
  try {
    final placed = await window.restoredBounds();
    if (placed == null) return;
    final b = placed.bounds;
    if (b.width <= 0 || b.height <= 0 || b.width > 32768 || b.height > 32768) return;
    await writer.update(
      (ui) => ui.copyWith(
        popupWindowSize:
            ui.popupWindowSize?.copyWith(width: b.width, height: b.height) ??
            PopupWindowSize(width: b.width, height: b.height),
      ),
    );
  } on Object {
    // A UI-state read/write failure must not prevent returning to VEGAS.
  }
}
