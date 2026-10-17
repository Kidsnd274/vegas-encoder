import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:ve_services/ve_services.dart';
import 'package:vegas_encoder/app/launch.dart';
import 'package:vegas_encoder/platform/window_channel.dart';
import 'package:vegas_encoder/state/app_state.dart';
import 'package:vegas_encoder/state/services.dart';

/// The live file the progress window follows in tests.
const liveFile = r'C:\Users\Owner\AppData\Local\VegasEncoder\jobs\b0-render.live.json';

/// The platform's sample status for [state] (job `b0-render`, CONTRACTS C5:
/// one file per state, not one legal sequence).
LiveRenderStatus liveSample(RenderState state) =>
    FakeLiveRenderStatusReader.samples().firstWhere((s) => s.state == state);

/// [liveSample] at a later [sequence], for publishing after another sample.
LiveRenderStatus liveAt(RenderState state, int sequence) => liveSample(state).copyWith(sequence: sequence);

/// The record the engine writes when `b0-render` ends (C6), made from the
/// platform's fixture records with this job's ID and figures.
Future<JobRecord> recordFor(RenderState state) async {
  final jobs = FakeJobRepository();
  Future<Map<String, Object?>> fixture(String id) async => (await jobs.get(id))!.toJson();
  return switch (state) {
    RenderState.done => JobRecord.fromJson({
      ...await fixture('j-1042'),
      'id': 'b0-render',
      'elapsedSec': 247,
      'sizeBytes': 2930000000,
      'realtime': 3.09,
      'verification': {
        'state': 'passed',
        'message': '',
        'expectedCodecs': ['h264', 'aac'],
        'actualCodecs': ['h264', 'aac'],
        'ffprobeVersion': '8.1',
      },
    }),
    RenderState.failed => JobRecord.fromJson({
      ...await fixture('j-1039'),
      'id': 'b0-render',
      'elapsedSec': 248,
      'message': "FFmpeg: No such filter: 'vegas_encoder_deliberate_failure'",
      'stderrTail':
          "[AVFilterGraph] No such filter: 'vegas_encoder_deliberate_failure'\n"
          'Error reinitializing filters!\n'
          'Thread message queue blocking; consider raising thread_queue_size\n'
          'Conversion failed!\n',
      'logFile': 'b0-render.ffmpeg.log',
    }),
    RenderState.cancelled => JobRecord.fromJson({...await fixture('j-1041'), 'id': 'b0-render', 'elapsedSec': 72}),
    _ => throw ArgumentError('No record while rendering: $state'),
  };
}

/// A progress window on [status] (none: the file isn't there yet), with
/// [record] in the job repository and its log when it names one.
({List<Override> overrides, FakeLiveRenderStatusReader live, FakeJobRepository jobs, FakeFileReveal reveal})
monitorOverrides({
  LiveRenderStatus? status,
  JobRecord? record,
  FakeJobRepository? repository,
  FakeWindowController? window,
  DesktopAppLauncher? launcher,
}) {
  final live = FakeLiveRenderStatusReader(initial: {liveFile: status});
  final jobs =
      repository ??
      FakeJobRepository(
        records: [?record],
        logs: {if (record?.logFile != null) record!.id: '[libsvtav1] Error setting preset 14\n'},
      );
  final reveal = FakeFileReveal();
  return (
    overrides: [
      launchModeProvider.overrideWithValue(const RenderMonitorLaunch(liveFile)),
      windowControllerProvider.overrideWithValue(window ?? FakeWindowController()),
      liveStatusReaderProvider.overrideWithValue(live),
      jobRepositoryProvider.overrideWithValue(jobs),
      jobLogsProvider.overrideWithValue(jobs),
      fileRevealProvider.overrideWithValue(reveal),
      if (launcher != null) desktopAppLauncherProvider.overrideWithValue(launcher),
    ],
    live: live,
    jobs: jobs,
    reveal: reveal,
  );
}
