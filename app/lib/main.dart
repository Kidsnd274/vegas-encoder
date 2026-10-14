import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ve_services/ve_services.dart' show MachineSettingsRepository;

import 'app/app.dart';
import 'app/launch.dart';
import 'platform/window_channel.dart';
import 'state/app_state.dart';
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
  // and the window never jumps. Keep on top is off by default (owner
  // decision); F6 reads the remembered pin from C7 `keepOnTop` here.
  // Only the desktop window restores bounds, so only it reads settings first.
  final remembered = mode is DesktopLaunch ? await _rememberedBounds(container) : null;
  await window.configure(
    ownerHwnd: mode is EditSessionLaunch ? mode.ownerHwnd : null,
    keepOnTop: mode is RenderMonitorLaunch ? false : null,
    bounds: remembered?.bounds,
    maximized: remembered?.maximized,
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
