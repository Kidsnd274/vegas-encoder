import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ve_services/ve_services.dart' show MachineSettingsRepository;

import 'app/app.dart';
import 'app/launch.dart';
import 'platform/window_channel.dart';
import 'state/app_state.dart';
import 'state/monitor.dart';
import 'state/popup.dart';
import 'state/popup_placement.dart';
import 'state/services.dart';

/// Mode dispatch: desktop, `--edit-session <dir>` or `--render-monitor <file>`.
Future<void> main(List<String> args) async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  final mode = LaunchMode.fromArguments(args);
  final window = MethodChannelWindowController();
  unawaited(window.trace('dart_main'));

  // One container for the process, made before runApp so that what main
  // reads (the desktop's remembered bounds) comes from the same services the
  // app then uses. Services are built on first use: the progress window never
  // loads the core or the library.
  late final WindowState initial;
  final container = ProviderContainer(
    overrides: [
      launchModeProvider.overrideWithValue(mode),
      windowControllerProvider.overrideWithValue(window),
      // Read first by the widgets, after `initial` is set below.
      initialWindowStateProvider.overrideWith((ref) => initial),
    ],
  );

  // The runner shows the window on the first frame, so placement (owner,
  // keep on top, the desktop window's remembered bounds) happens before runApp
  // and the window never jumps. Popups restore only size, never position.
  final remembered = mode is DesktopLaunch ? await _rememberedBounds(container) : null;
  final popupSize = mode is EditSessionLaunch ? await popupPlacement(container) : null;
  // The popup is owned by the VEGAS dialog its request names (C4).
  final owner = mode is EditSessionLaunch ? await _owner(container) : null;
  // The progress window goes on VEGAS's monitor (C5 `hostHwnd`) with the
  // remembered pin (C7 `keepOnTop`, off by default).
  final monitor = mode is RenderMonitorLaunch ? await monitorPlacement(container, mode.liveFile) : null;
  await window.configure(
    ownerHwnd: owner,
    hostHwnd: monitor?.host,
    keepOnTop: monitor?.keepOnTop,
    bounds: remembered?.bounds,
    maximized: remembered?.maximized,
    popupSize: popupSize,
  );
  initial = await window.state();
  binding.addPostFrameCallback((_) => unawaited(window.trace('dart_first_frame')));

  runApp(UncontrolledProviderScope(container: container, child: const VeApp()));
}

/// The desktop window's last restored bounds from C7 `uiState`, if any. An
/// unreadable settings file (or no services) just means the default placement.
Future<({WindowBounds bounds, bool maximized})?> _rememberedBounds(ProviderContainer container) async {
  try {
    final MachineSettingsRepository machine = container.read(machineSettingsRepositoryProvider);
    final ui = (await machine.read()).uiState;
    final b = ui?.desktopWindowBounds;
    if (ui == null || b == null) return null;
    return (bounds: (x: b.x, y: b.y, width: b.width, height: b.height), maximized: ui.desktopMaximized);
  } on Object {
    return null;
  }
}

/// The owner window from the session's request; the popup reads the same
/// request. A request that can't be read leaves the window unowned, and the
/// popup shows the problem.
Future<int?> _owner(ProviderContainer container) async {
  try {
    return ownerHwndOf(await container.read(editSessionRequestProvider.future));
  } on Object {
    return null;
  }
}
