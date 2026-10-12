import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/launch.dart';
import 'platform/window_channel.dart';
import 'state/app_state.dart';

/// Mode dispatch: desktop, `--edit-session <dir>` or `--render-monitor <file>`.
Future<void> main(List<String> args) async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  final mode = LaunchMode.fromArguments(args);
  final window = MethodChannelWindowController();
  unawaited(window.trace('dart_main'));

  // The runner shows the window on the first frame, so placement (owner,
  // keep on top) happens before runApp and the window never jumps. Keep on top
  // is off by default (owner decision); F6 reads the remembered pin from C7
  // `keepOnTop` here.
  await window.configure(
    ownerHwnd: mode is EditSessionLaunch ? mode.ownerHwnd : null,
    keepOnTop: mode is RenderMonitorLaunch ? false : null,
  );
  final initial = await window.state();
  binding.addPostFrameCallback((_) => unawaited(window.trace('dart_first_frame')));

  runApp(
    ProviderScope(
      overrides: [
        launchModeProvider.overrideWithValue(mode),
        windowControllerProvider.overrideWithValue(window),
        initialWindowStateProvider.overrideWithValue(initial),
      ],
      child: const VeApp(),
    ),
  );
}
