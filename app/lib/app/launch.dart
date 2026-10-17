import 'package:flutter/foundation.dart';
import 'package:ve_services/ve_services.dart' show DesktopRoute;

/// How VegasEncoder.exe was started (TECH_ARCHITECTURE §9.2). The Windows
/// runner applies the same rule to choose the window (launch_options.cpp).
@immutable
sealed class LaunchMode {
  const LaunchMode();

  /// Parses the process arguments. The first of `--edit-session` or
  /// `--render-monitor` decides the mode; without either, the desktop app runs.
  factory LaunchMode.fromArguments(List<String> args) {
    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      if (arg == '--edit-session' || arg == '--render-monitor') {
        final value = i + 1 < args.length ? args[i + 1] : null;
        if (value == null || value.isEmpty || value.startsWith('--')) {
          return LaunchError(arg, '$arg needs a path after it.');
        }
        return arg == '--edit-session' ? EditSessionLaunch(value) : RenderMonitorLaunch(value);
      }
    }
    for (var i = 0; i < args.length; i++) {
      final flag = args[i];
      if (flag != '--open-preset' && flag != '--open-job') continue;
      final id = i + 1 < args.length ? args[i + 1] : '';
      if (!DesktopRoute.validId(id)) {
        return const DesktopLaunch(error: 'The requested preset or History destination is invalid.');
      }
      return DesktopLaunch(route: flag == '--open-preset' ? DesktopRoute.preset(id) : DesktopRoute.job(id));
    }
    return const DesktopLaunch();
  }

  /// The window kind the runner created for these arguments.
  LaunchWindow get window;
}

enum LaunchWindow { desktop, editSession, renderMonitor }

final class DesktopLaunch extends LaunchMode {
  const DesktopLaunch({this.route, this.error});
  final DesktopRoute? route;
  final String? error;
  @override
  LaunchWindow get window => LaunchWindow.desktop;
  @override
  bool operator ==(Object other) => other is DesktopLaunch && other.route == route && other.error == error;
  @override
  int get hashCode => Object.hash(route, error);
}

/// `--edit-session <dir>`: the VEGAS popup for one session directory. The
/// owner window comes from the session's request (C4 `ownerHwnd`).
final class EditSessionLaunch extends LaunchMode {
  const EditSessionLaunch(this.sessionDir);
  final String sessionDir;
  @override
  LaunchWindow get window => LaunchWindow.editSession;
  @override
  bool operator ==(Object other) => other is EditSessionLaunch && other.sessionDir == sessionDir;
  @override
  int get hashCode => sessionDir.hashCode;
}

/// `--render-monitor <file>`: the progress window for one live status file.
final class RenderMonitorLaunch extends LaunchMode {
  const RenderMonitorLaunch(this.liveFile);
  final String liveFile;
  @override
  LaunchWindow get window => LaunchWindow.renderMonitor;
  @override
  bool operator ==(Object other) => other is RenderMonitorLaunch && other.liveFile == liveFile;
  @override
  int get hashCode => liveFile.hashCode;
}

/// A mode flag without its path. The runner still made that kind of window,
/// so the app shows the problem there instead of exiting silently.
final class LaunchError extends LaunchMode {
  const LaunchError(this.flag, this.message);
  final String flag;
  final String message;
  @override
  LaunchWindow get window => flag == '--edit-session' ? LaunchWindow.editSession : LaunchWindow.renderMonitor;
  @override
  bool operator ==(Object other) => other is LaunchError && other.flag == flag && other.message == message;
  @override
  int get hashCode => Object.hash(flag, message);
}
