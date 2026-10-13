// Display mapping for the Settings screen: labels from machine settings (C7)
// and the core's version. Nothing here decides which FFmpeg renders.

import 'package:ve_services/ve_services.dart';

/// Whether renders have a default FFmpeg to use.
enum DefaultFFmpegState {
  ok,

  /// No installation is registered yet.
  noInstallations,

  /// Installations exist, but none is the default.
  notChosen,

  /// The default names an installation that isn't registered (a file written
  /// elsewhere). Renders don't switch to another one by themselves (C7).
  unregistered,
}

DefaultFFmpegState defaultFFmpegState(MachineSettings s) {
  final id = s.defaultFFmpegId;
  if (s.installations.isEmpty) {
    return id == null ? DefaultFFmpegState.noInstallations : DefaultFFmpegState.unregistered;
  }
  if (id == null) return DefaultFFmpegState.notChosen;
  return s.installations.any((i) => i.id == id) ? DefaultFFmpegState.ok : DefaultFFmpegState.unregistered;
}

/// "Version 8.1, gyan.dev full build, GPL v3" for the default FFmpeg list.
String installationDetail(FFmpegInstallation i) =>
    ['Version ${i.version}', if (i.build.isNotEmpty) i.build, if (i.license.isNotEmpty) i.license].join(', ');

/// "0.2.0" or "0.1.0-b0-fake, preview core (fake)".
String coreVersionLabel(CoreVersion v) => v.isFake ? '${v.core}, preview core (fake)' : v.core;
