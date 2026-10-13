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

  // The runner shows the window on the first frame, so placement (owner,
  // keep on top, the desktop window's remembered bounds) happens before runApp
  // and the window never jumps. Keep on top is off by default (owner
  // decision); F6 reads the remembered pin from C7 `keepOnTop` here.
  // Only the desktop window restores bounds, so only it reads settings first.
  final machine = mode is DesktopLaunch ? createMachineSettingsRepository() : null;
  final remembered = machine == null ? null : await _rememberedBounds(machine);
  await window.configure(
    ownerHwnd: mode is EditSessionLaunch ? mode.ownerHwnd : null,
    keepOnTop: mode is RenderMonitorLaunch ? false : null,
    bounds: remembered?.bounds,
    maximized: remembered?.maximized,
  );
  final initial = await window.state();
  binding.addPostFrameCallback((_) => unawaited(window.trace('dart_first_frame')));

  runApp(
    ProviderScope(
      overrides: [
        launchModeProvider.overrideWithValue(mode),
        windowControllerProvider.overrideWithValue(window),
        initialWindowStateProvider.overrideWithValue(initial),
        if (machine != null) machineSettingsRepositoryProvider.overrideWithValue(machine),
      ],
      child: const VeApp(),
    ),
  );
}

/// The desktop window's last restored bounds from C7 `uiState`, if any. An
/// unreadable settings file just means the default placement.
Future<({WindowBounds bounds, bool maximized})?> _rememberedBounds(MachineSettingsRepository machine) async {
  try {
    final ui = (await machine.read()).uiState;
    final b = ui?.desktopWindowBounds;
    if (ui == null || b == null) return null;
    return (bounds: (x: b.x, y: b.y, width: b.width, height: b.height), maximized: ui.desktopMaximized);
  } on Object {
    return null;
  }
}
