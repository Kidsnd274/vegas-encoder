// Maps discovery, probe and hardware-test results to the FFmpeg screen's
// display models (UI_SPEC §5). Display work only: labels, grouping, filtering
// and sentences. Whether an encoder works comes from the services: the
// installation's availability, this session's probe and test results.

import 'package:flutter/foundation.dart';
import 'package:ve_services/ve_services.dart';

import '../../design/components/status.dart';
import '../../design/format.dart';
import '../../state/ffmpeg.dart';
import '../presets/display.dart';
import '../presets/library_model.dart';

// ------------------------------------------------------------ encoder status

/// An encoder's state in one installation.
@immutable
class EncoderStatus {
  const EncoderStatus(this.state, {this.reason, this.detail, this.note, this.test});

  final VeAvailability state;

  /// Why it isn't ready ("No Intel graphics device on this PC.").
  final String? reason;

  /// What FFmpeg said (the stderr line), shown on expand.
  final String? detail;

  /// The device a hardware encoder ran on ("NVIDIA GeForce RTX 4070").
  final String? note;

  /// This session's test result, when there is one.
  final HardwareTestResult? test;
}

String? _text(Object? value) => value is String && value.isNotEmpty ? value : null;

/// The newest fact wins: a test running now, then this session's test result,
/// then this session's probe, then the installation's recorded availability.
/// An encoder none of them lists is not in this FFmpeg, unless the
/// installation was never checked, when nothing is known yet.
EncoderStatus encoderStatus(
  FFmpegInstallation installation,
  String encoder, {
  FFmpegCapabilities? probed,
  HardwareTestResult? test,
  bool testing = false,
}) {
  if (testing) return const EncoderStatus(VeAvailability.testing);
  if (test != null) {
    return EncoderStatus(
      _state(test.state),
      reason: _text(test.reason),
      detail: _text(test.stderr),
      note: _text(
        installation.availability[encoder] is Map ? (installation.availability[encoder] as Map)['note'] : null,
      ),
      test: test,
    );
  }
  final fromProbe = probed?.encoders[encoder];
  final raw = fromProbe is Map ? fromProbe['availability'] : installation.availability[encoder];
  if (raw is Map) {
    return EncoderStatus(
      _state(raw['state']),
      reason: _text(raw['reason']),
      detail: _text(raw['detail']),
      note: _text(raw['note']),
    );
  }
  if (probed == null && installation.probedAt == null) return const EncoderStatus(VeAvailability.unknown);
  return EncoderStatus(VeAvailability.missing, reason: 'Not in ${installation.label}.');
}

VeAvailability _state(Object? state) => switch (state) {
  'ok' => VeAvailability.ready,
  'missing' => VeAvailability.missing,
  'failed' => VeAvailability.failed,
  _ => VeAvailability.unknown,
};

/// The installation's status lookup with this session's results applied.
EncoderStatus Function(String encoder) statusLookup(FFmpegInstallation installation, FFmpegState state) =>
    (encoder) => encoderStatus(
      installation,
      encoder,
      probed: state.probed[installation.id],
      test: state.testResults[installation.id]?[encoder],
      testing: state.isTesting(installation.id, encoder),
    );

/// "Driver or runtime missing" for a test's failure class.
String? failureClassLabel(String? failureClass) => switch (failureClass) {
  'runtime-missing' => 'Driver or runtime missing',
  'no-device' => 'No matching device',
  'unsupported-format' => 'Format not supported by this device',
  'timeout' => 'The test encode timed out',
  'unknown' => 'Failed for an unknown reason',
  _ => null,
};

// ------------------------------------------------------------ installation cards

/// Where discovery found an installation.
String sourceLabel(String source) => switch (source) {
  'ini' => 'From the old Vegas Encoder settings',
  'path' => 'Found on PATH',
  'winget' => 'Installed with winget',
  'scoop' => 'Installed with Scoop',
  'chocolatey' => 'Installed with Chocolatey',
  'manual' => 'Added by hand',
  _ => source,
};

/// "Reading encoders" for a probe phase.
String probePhaseLabel(String phase) => switch (phase) {
  'identity' => 'Reading the version',
  'lists' => 'Reading encoder lists',
  'details' => 'Reading encoders',
  'hardware' => 'Testing hardware encoders',
  'done' => 'Finishing',
  'failed' => 'The check failed',
  'cancelled' => 'The check was cancelled',
  _ => 'Checking',
};

/// What the card offers for an installation's health.
enum HealthAction {
  /// Scan again: discovery identifies the files again, then a check runs.
  scanAgain('Scan again'),

  /// Locate…: the Open dialog, to add ffmpeg.exe where it is now.
  locate('Locate…');

  const HealthAction(this.label);
  final String label;
}

/// An installation whose files aren't as they were checked (C3 `health`):
/// what it means for renders and what to do.
@immutable
class InstallationHealth {
  const InstallationHealth({required this.error, required this.text, required this.action, this.detail});

  /// Renders with it fail (missing); otherwise a warning.
  final bool error;
  final String text;
  final HealthAction action;

  /// Discovery's own words (`healthMessage`), for the tooltip.
  final String? detail;
}

/// The card's health note, or null when the files are as checked or their
/// health isn't known yet (C3 `unchanged`, `unknown`).
InstallationHealth? installationHealth(FFmpegInstallation i, {required bool isDefault}) {
  final detail = i.healthMessage.trim().isEmpty ? null : i.healthMessage.trim();
  return switch (i.health) {
    'changed' => InstallationHealth(
      error: false,
      text: 'This FFmpeg changed since it was checked. Scan again to check it before the next render.',
      action: HealthAction.scanAgain,
      detail: detail,
    ),
    'missing' => InstallationHealth(
      error: true,
      text:
          '${i.path} isn’t there any more, or can’t be read. '
          '${isDefault ? 'Renders fail until you locate it or choose another default.' : 'Locate it, or remove it from the list.'}',
      action: HealthAction.locate,
      detail: detail,
    ),
    'ffprobe-missing' => InstallationHealth(
      error: false,
      text:
          'ffprobe.exe must be next to ffmpeg.exe so renders can be checked. '
          'Put it in ${_folder(i.path)}, then scan again.',
      action: HealthAction.scanAgain,
      detail: detail,
    ),
    _ => null,
  };
}

/// The folder of a Windows path, as written ("C:\ffmpeg\bin").
String _folder(String path) {
  final at = path.lastIndexOf(RegExp(r'[\\/]'));
  return at <= 0 ? path : path.substring(0, at);
}

/// One installation card (`.ic`).
@immutable
class InstallationCardModel {
  const InstallationCardModel({
    required this.id,
    required this.title,
    required this.isDefault,
    required this.line,
    required this.path,
    required this.ffprobePath,
    required this.checked,
    this.counts,
    this.progress,
    this.failure,
    this.blocked = const [],
    this.blockedNeeds = const [],
    this.health,
  });

  final String id;
  final String title;
  final bool isDefault;

  /// "gyan.dev full build, GPL v3. Installed with winget."
  final String line;
  final String path;
  final String ffprobePath;

  /// "Checked 12 Oct 2026 in 2.14 s", or "Not checked yet".
  final String checked;

  /// Video encoders, audio encoders, muxers; null if never counted.
  final ({int video, int audio, int muxers})? counts;

  /// A probe running now: "Reading encoders… 18 of 25" and how far it is.
  final ({String label, double? fraction})? progress;

  /// Why this session's check failed.
  final String? failure;

  /// Presets that can't render with this FFmpeg, by name.
  final List<String> blocked;

  /// The encoders those presets need and this FFmpeg can't run ("x264").
  final List<String> blockedNeeds;

  /// Changed on disk, missing, or no ffprobe; null when as checked.
  final InstallationHealth? health;
}

InstallationCardModel installationCard(
  FFmpegInstallation installation, {
  required bool isDefault,
  required FFmpegState state,
  required List<Preset> presets,
  required ProfileCatalog catalog,
}) {
  final progress = state.probes[installation.id];
  final probed = state.probed[installation.id];
  final status = statusLookup(installation, state);
  final blocked = <String>[];
  final needs = <String>{};
  for (final p in presets) {
    final missing = [
      for (final id in encodersNeeded(p, p.recipe))
        if (status(id).state.isProblem) id,
    ];
    if (missing.isEmpty) continue;
    blocked.add(p.recipe.name);
    needs.addAll(missing.map((id) => encoderLabel(catalog, id)));
  }
  final counts = installation.counts;
  final video = counts['video'], audio = counts['audio'], muxers = counts['muxers'];
  final probedAt = probed?.probedAt ?? installation.probedAt;
  final when = probedAt == null ? null : DateTime.tryParse(probedAt);
  return InstallationCardModel(
    id: installation.id,
    title: installation.label,
    isDefault: isDefault,
    line:
        '${[
          [installation.build, installation.license].where((s) => s.isNotEmpty).join(', '),
          sourceLabel(installation.source),
        ].where((s) => s.isNotEmpty).join('. ')}.',
    path: installation.path,
    ffprobePath: installation.ffprobePath,
    // The recorded check's duration; a check this session has none to show.
    checked: when == null
        ? 'Not checked yet'
        : 'Checked ${VeFormat.date(when)}'
              '${probed != null || installation.probeMs == null ? '' : ' in ${(installation.probeMs! / 1000).toStringAsFixed(2)} s'}',
    counts: video is int && audio is int && muxers is int ? (video: video, audio: audio, muxers: muxers) : null,
    progress: progress == null
        ? null
        : (
            label:
                '${probePhaseLabel(progress.phase)}…'
                '${progress.total > 0 ? ' ${progress.completed} of ${progress.total}' : ''}',
            fraction: progress.total > 0 ? progress.completed / progress.total : null,
          ),
    failure: state.probeFailures[installation.id],
    blocked: blocked,
    blockedNeeds: needs.toList(),
    health: installationHealth(installation, isDefault: isDefault),
  );
}

String encoderLabel(ProfileCatalog catalog, String id) =>
    catalog.videoEncoder(id)?.label ?? catalog.audioEncoder(id)?.label ?? id;

// ------------------------------------------------------------ capability list

/// One row of the capability table (`.ctab tr`).
@immutable
class CapabilityRow {
  const CapabilityRow({
    required this.id,
    required this.label,
    required this.depth,
    required this.runsOn,
    required this.status,
    required this.hardware,
  });

  final String id;
  final String label;

  /// "8 or 10-bit", "10-bit", "8-bit"; empty for audio.
  final String depth;

  /// "CPU", "NVIDIA GPU", or the device a passed test ran on.
  final String runsOn;
  final EncoderStatus status;
  final bool hardware;

  /// The reason column: what's running, or why it isn't ready.
  String get why => switch (status.state) {
    VeAvailability.ready => '',
    VeAvailability.testing => 'Running a short test encode',
    VeAvailability.unknown => hardware ? 'Not tested on this PC yet' : '',
    _ => status.reason ?? '',
  };
}

/// Rows under a codec heading ("H.264", "AAC audio").
typedef CapabilityGroup = ({String name, List<CapabilityRow> rows});

/// The encoders of [kind] the catalog knows, grouped by codec in catalog
/// order, after the filter and search.
List<CapabilityGroup> capabilityGroups(
  ProfileCatalog catalog, {
  required EncoderKind kind,
  required EncoderStatus Function(String encoder) statusOf,
  CapabilityFilter filter = CapabilityFilter.all,
  String query = '',
}) {
  final video = kind == EncoderKind.video;
  final order = jsonMap(video ? catalog.videoOrder : catalog.audioOrder);
  final words = query.trim().toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  return [
    for (final g in (order['groups'] as List? ?? const []).cast<Map>())
      if (_groupRows(g, catalog, video: video, statusOf: statusOf, filter: filter, words: words) case final rows
          when rows.isNotEmpty)
        (name: video ? g['group'] as String : '${g['group']} audio', rows: rows),
  ];
}

List<CapabilityRow> _groupRows(
  Map g,
  ProfileCatalog catalog, {
  required bool video,
  required EncoderStatus Function(String) statusOf,
  required CapabilityFilter filter,
  required List<String> words,
}) => [
  for (final id in (g['ids'] as List).cast<String>())
    if ((video ? catalog.videoEncoder(id) : catalog.audioEncoder(id)) case final p?)
      if (_row(p, statusOf(id), video: video) case final row
          when switch (filter) {
                CapabilityFilter.all => true,
                CapabilityFilter.problems => row.status.state.isProblem,
                CapabilityFilter.hardware => row.hardware,
              } &&
              words.every(
                [p.label, p.id, p.codec, g['group'], p.hw ?? 'cpu', row.runsOn].join(' ').toLowerCase().contains,
              ))
        row,
];

CapabilityRow _row(EncoderProfile p, EncoderStatus status, {required bool video}) {
  final depths = video ? (p.depths.keys.map(int.tryParse).whereType<int>().toSet()) : const <int>{};
  return CapabilityRow(
    id: p.id,
    label: p.label,
    depth: !video
        ? ''
        : depths.contains(10)
        ? (depths.contains(8) ? '8 or 10-bit' : '10-bit')
        : '8-bit',
    runsOn: p.hw == null
        ? 'CPU'
        : status.state == VeAvailability.ready && status.note != null
        ? status.note!
        : '${p.hw} GPU',
    status: status,
    hardware: p.hw != null,
  );
}

/// "FFmpeg 8.1 full: 4 video and 1 audio encoders not ready".
String problemSummary(
  ProfileCatalog catalog,
  String installationLabel,
  EncoderStatus Function(String encoder) statusOf,
) {
  int count(List<EncoderProfile> list) => list.where((p) => statusOf(p.id).state.isProblem).length;
  final v = count(catalog.video), a = count(catalog.audio);
  if (v == 0 && a == 0) return '$installationLabel: every encoder is ready';
  return '$installationLabel: $v video and $a audio ${a == 1 && v <= 1 ? 'encoder' : 'encoders'} not ready';
}

/// The hardware encoders the catalog knows, for "Test hardware encoders".
List<String> hardwareEncoderIds(ProfileCatalog catalog) => [
  for (final p in catalog.video)
    if (p.hw != null) p.id,
];

// ------------------------------------------------------------ encoder detail

/// The detail panel for one encoder (`.capd`).
@immutable
class EncoderDetailModel {
  const EncoderDetailModel({
    required this.id,
    required this.label,
    required this.installationLabel,
    required this.video,
    required this.hardware,
    required this.status,
    required this.meaning,
    this.advice,
    this.testFacts = const [],
    this.usedBy = const [],
  });

  final String id;
  final String label;
  final String installationLabel;
  final bool video;
  final bool hardware;
  final EncoderStatus status;

  /// "What this means": the first paragraph, then what to do.
  final String meaning;
  final String? advice;

  /// From this session's test: "Driver or runtime missing", "10-bit works",
  /// "Tested 12 Oct 2026".
  final List<String> testFacts;

  /// Presets that use this encoder: ID, name, built-in.
  final List<({String id, String name, bool builtin})> usedBy;

  /// The test-encode diagram shows for hardware encoders and for problems.
  bool get showsTestEncode => hardware || status.state.isProblem;
}

EncoderDetailModel encoderDetail(
  ProfileCatalog catalog,
  String id, {
  required FFmpegInstallation installation,
  required EncoderStatus status,
  required List<Preset> presets,
}) {
  final profile = catalog.videoEncoder(id) ?? catalog.audioEncoder(id);
  final video = catalog.videoEncoder(id) != null;
  final hw = profile?.hw;
  final label = profile?.label ?? id;
  final inst = installation.label;
  final (meaning, advice) = switch (status.state) {
    VeAvailability.ready => (
      '$inst lists $id${hw == null ? '' : ' and a test encode passed on ${status.note ?? '$hw hardware'}'}. '
          'Presets that use it render normally.',
      null,
    ),
    VeAvailability.missing => (
      status.reason ?? '$inst doesn’t include $id.',
      'To use $label, add an FFmpeg build that includes it, such as a full GPL build, and make it the default.',
    ),
    VeAvailability.failed => (
      '$inst lists $id, but the test encode on this PC failed.${status.reason == null ? '' : ' ${status.reason}'}',
      'Choose another encoder in presets that use it, or test again after installing the driver.',
    ),
    VeAvailability.testing => ('Running a short test encode. Results appear here.', null),
    VeAvailability.unknown => (
      '$inst lists $id, but it hasn’t been tested on this PC yet.',
      hw == null ? null : 'Test it to find out whether it works here.',
    ),
  };
  final test = status.test;
  final tested = test == null ? null : DateTime.tryParse(test.testedAt);
  return EncoderDetailModel(
    id: id,
    label: label,
    installationLabel: inst,
    video: video,
    hardware: hw != null,
    status: status,
    meaning: meaning,
    advice: advice,
    testFacts: [
      ?failureClassLabel(test?.failureClass),
      if (test != null && test.state == 'ok' && video) test.tenBit ? '10-bit works' : '8-bit only on this PC',
      if (tested != null) 'Tested ${VeFormat.date(tested)}',
    ],
    usedBy: [
      for (final p in presets)
        if (encodersNeeded(p, p.recipe).contains(id)) (id: p.recipe.id, name: p.recipe.name, builtin: p.builtin),
    ],
  );
}
