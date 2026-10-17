import 'dart:io';

import 'api.dart';

/// The desktop destinations accepted by the executable and its instance handoff.
/// IDs use the same local-file-safe alphabet as presets and job records.
class DesktopRoute {
  const DesktopRoute.preset(this.id) : kind = 'preset';
  const DesktopRoute.job(this.id) : kind = 'job';

  final String kind;
  final String id;

  static bool validId(String id) =>
      id.length <= 128 &&
      RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(id) &&
      !id.endsWith('.') &&
      !RegExp(
        r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)',
        caseSensitive: false,
      ).hasMatch(id);

  bool get valid => (kind == 'preset' || kind == 'job') && validId(id);
  List<String> get arguments => ['--open-$kind', id];

  @override
  bool operator ==(Object other) =>
      other is DesktopRoute && other.kind == kind && other.id == id;
  @override
  int get hashCode => Object.hash(kind, id);
}

abstract interface class DesktopAppLauncher {
  Future<void> openPreset(String presetId);
  Future<void> openJob(String jobId);
}

/// Launches this matching app binary. The runner hands a route to the desktop
/// instance in the same data profile, or starts one. Detached launch lets the
/// desktop outlive a popup/monitor. No library, core or machine settings read.
class WindowsDesktopAppLauncher implements DesktopAppLauncher {
  WindowsDesktopAppLauncher({
    String? executable,
    Future<void> Function(String, List<String>)? launch,
  }) : _executable = executable ?? Platform.resolvedExecutable,
       _launch = launch ?? _start;

  final String _executable;
  final Future<void> Function(String, List<String>) _launch;

  static Future<void> _start(String executable, List<String> arguments) async {
    await Process.start(
      executable,
      arguments,
      mode: ProcessStartMode.detached,
      runInShell: false,
      // Preserve isolated development/trial profiles through the child and
      // runner's profile-scoped instance lock. Do not redirect to user data.
      includeParentEnvironment: true,
    );
  }

  Future<void> _open(DesktopRoute route) async {
    if (!route.valid) {
      throw const ServiceException(
        'INVALID-ID',
        'The desktop destination ID is invalid.',
      );
    }
    try {
      await _launch(_executable, route.arguments);
    } on ProcessException catch (e) {
      throw ServiceException(
        'DESKTOP-LAUNCH',
        'Couldn’t start Vegas Encoder: ${e.message}',
      );
    }
  }

  @override
  Future<void> openPreset(String presetId) =>
      _open(DesktopRoute.preset(presetId));
  @override
  Future<void> openJob(String jobId) => _open(DesktopRoute.job(jobId));
}
