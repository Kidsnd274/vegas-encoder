// Maps discovery, probe and hardware-test results to the setup wizard's rows
// (UI_SPEC §5a). Display work only: whether an encoder works comes from the
// services, through the FFmpeg screen's status lookup.

import 'package:flutter/foundation.dart';
import 'package:ve_services/ve_services.dart';

import '../../design/components/status.dart';
import '../../state/ffmpeg.dart';
import '../ffmpeg/display.dart';

/// One installation in the wizard's Check and Choose steps.
@immutable
class SetupCandidate {
  const SetupCandidate({
    required this.id,
    required this.title,
    required this.line,
    required this.path,
    required this.isDefault,
    required this.hardware,
    required this.hardwareState,
    required this.readyVideo,
    this.progress,
    this.failure,
    this.health,
  });

  final String id;
  final String title;

  /// "gyan.dev full build, GPL v3. Installed with winget."
  final String line;
  final String path;
  final bool isDefault;

  /// What its hardware encoders do on this PC, in a sentence.
  final String hardware;

  /// The icon and colour for [hardware].
  final VeAvailability hardwareState;

  /// Video encoders ready on this PC, software and hardware.
  final int readyVideo;

  /// A probe running now.
  final ({String label, double? fraction})? progress;

  /// Why this session's check failed.
  final String? failure;

  /// Changed on disk, missing, or no ffprobe.
  final InstallationHealth? health;

  /// A missing ffmpeg.exe can't render, so it can't be the default.
  bool get selectable => !(health?.error ?? false);
}

SetupCandidate setupCandidate(
  FFmpegInstallation installation, {
  required bool isDefault,
  required FFmpegState state,
  required ProfileCatalog catalog,
}) {
  final card = installationCard(installation, isDefault: isDefault, state: state, presets: const [], catalog: catalog);
  final status = statusLookup(installation, state);
  final hardware = {for (final id in hardwareEncoderIds(catalog)) id: status(id).state};
  final ready = [
    for (final e in hardware.entries)
      if (e.value == VeAvailability.ready) encoderLabel(catalog, e.key),
  ];
  int count(VeAvailability s) => hardware.values.where((v) => v == s).length;
  final failed = count(VeAvailability.failed), unknown = count(VeAvailability.unknown);
  final String text;
  final VeAvailability icon;
  if (card.progress != null || count(VeAvailability.testing) > 0) {
    (text, icon) = ('Testing hardware encoders on this PC…', VeAvailability.testing);
  } else if (ready.isNotEmpty) {
    final rest = [
      if (failed > 0) '$failed failed their test on this PC.',
      if (unknown > 0) '$unknown not checked yet.',
    ];
    (text, icon) = (['Hardware ready: ${ready.join(', ')}.', ...rest].join(' '), VeAvailability.ready);
  } else if (failed > 0) {
    (text, icon) = ('No hardware encoder works on this PC: $failed failed their test.', VeAvailability.failed);
  } else if (unknown > 0) {
    (text, icon) = ('Hardware encoders not checked yet.', VeAvailability.unknown);
  } else {
    (text, icon) = ('No hardware encoders in this FFmpeg. Software encoders still work.', VeAvailability.missing);
  }
  return SetupCandidate(
    id: installation.id,
    title: card.title,
    line: card.line,
    path: installation.path,
    isDefault: isDefault,
    hardware: text,
    hardwareState: icon,
    readyVideo: [for (final p in catalog.video) status(p.id).state].where((s) => s == VeAvailability.ready).length,
    progress: card.progress,
    failure: card.failure,
    health: card.health,
  );
}

/// The hardware encoders of [installation] whose result on this PC isn't
/// known: listed by this FFmpeg, but never tested here or the record expired.
List<String> untestedHardware(FFmpegInstallation installation, FFmpegState state, ProfileCatalog catalog) {
  final status = statusLookup(installation, state);
  return [
    for (final id in hardwareEncoderIds(catalog))
      if (status(id).state == VeAvailability.unknown && installation.availability.containsKey(id)) id,
  ];
}

/// The one the wizard suggests: a selectable installation whose files are as
/// checked, with the most video encoders ready on this PC; ties keep
/// discovery's order. Null when none can be the default.
String? recommendedCandidate(List<SetupCandidate> candidates) {
  SetupCandidate? best;
  for (final healthy in [true, false]) {
    for (final c in candidates) {
      if (!c.selectable || (healthy && c.health != null)) continue;
      if (best == null || c.readyVideo > best.readyVideo) best = c;
    }
    if (best != null) return best.id;
  }
  return null;
}

/// The row the wizard has selected: the user's pick, else the current
/// default, else the recommendation, whichever can be the default.
String? selectedCandidate(List<SetupCandidate> candidates, {String? chosenId}) {
  bool ok(String? id) => id != null && candidates.any((c) => c.id == id && c.selectable);
  if (ok(chosenId)) return chosenId;
  final current = candidates.where((c) => c.isDefault).firstOrNull?.id;
  if (ok(current)) return current;
  return recommendedCandidate(candidates);
}
