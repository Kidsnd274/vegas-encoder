import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ve_services/ve_services.dart';

import '../app/launch.dart';
import 'app_state.dart';
import 'services.dart';

// The render progress window (`--render-monitor`, F6, UI_SPEC §12). While
// VEGAS renders it reads only its live status file (C5) and keep on top (C7):
// no core, no library. Once the render has ended it reads that job's record
// (C6) for the result; decoding a record loads the core, which by then can't
// slow the render. Nothing here writes to the live file or waits on VEGAS.

/// The live status file this window follows; null outside `--render-monitor`.
final monitorFileProvider = Provider<String?>(
  (ref) => switch (ref.watch(launchModeProvider)) {
    RenderMonitorLaunch(:final liveFile) => liveFile,
    _ => null,
  },
);

/// The render's latest status: null until the file first appears. The
/// reader keeps the last good snapshot through a malformed or missing
/// replacement, so a stale file never reads as the end of the render.
final liveRenderStatusProvider = StreamProvider<LiveRenderStatus?>((ref) {
  final file = ref.watch(monitorFileProvider);
  if (file == null) return Stream.value(null);
  return ref.watch(liveStatusReaderProvider).watch(file);
});

/// VEGAS's main window from the live file (C5 `hostHwnd`), for placing the
/// window on VEGAS's monitor; null when absent or not a handle. C5 writes the
/// handle as an unsigned 64-bit decimal; the runner takes the same 64 bits as
/// a signed integer, so a handle above 2^63 arrives negative and intact.
int? hostHwndOf(LiveRenderStatus? status) {
  final text = status?.hostHwnd;
  if (text == null || !RegExp(r'^[0-9]{1,20}$').hasMatch(text)) return null;
  final value = BigInt.parse(text);
  if (value == BigInt.zero || value.bitLength > 64) return null;
  return value.toSigned(64).toInt();
}

/// Where the progress window goes before its first frame: VEGAS's main
/// window from the live file (C5) and the remembered pin (C7). Neither read
/// loads the core. A file that can't be read, or isn't there yet, leaves the
/// runner's placement and the pin off.
Future<({int? host, bool keepOnTop})> monitorPlacement(ProviderContainer container, String liveFile) async {
  Future<int?> host() async {
    try {
      return hostHwndOf(await container.read(liveStatusReaderProvider).read(liveFile));
    } on Object {
      return null;
    }
  }

  Future<bool> keepOnTop() async {
    try {
      return (await container.read(machineSettingsRepositoryProvider).read()).keepOnTop;
    } on Object {
      return false;
    }
  }

  final (h, k) = await (host(), keepOnTop()).wait;
  return (host: h, keepOnTop: k);
}

/// How often [monitorJobRecordProvider] looks for a late record after the
/// render ends. No record/index polling is started during an active render.
const monitorRecordInterval = Duration(seconds: 1);

/// The job's record (C6) once the render has ended. The window initially
/// words the result from C5, then adopts the record whenever it arrives.
/// One timer/read at a time; disposal cancels the delay and further reads.
final monitorJobRecordProvider = StreamProvider.autoDispose.family<JobRecord?, String>((ref, jobId) async* {
  final jobs = ref.watch(jobRepositoryProvider);
  Timer? timer;
  Completer<void>? waiting;
  ref.onDispose(() {
    timer?.cancel();
    if (waiting case final pending? when !pending.isCompleted) pending.complete();
  });
  while (ref.mounted) {
    JobRecord? record;
    try {
      record = await jobs.get(jobId);
    } on ServiceException {
      // Missing, not complete yet, or malformed: keep the live result.
    } on CoreException {
      if (ref.mounted) yield null;
      return; // the core didn't load: no record can be decoded
    }
    if (!ref.mounted) return;
    yield record;
    if (record != null || !ref.mounted) return;
    final pending = Completer<void>();
    waiting = pending;
    timer = Timer(monitorRecordInterval, pending.complete);
    await pending.future;
    timer = null;
    waiting = null;
  }
}, retry: (_, _) => null);

/// Where the job's FFmpeg log is (C6 `logFile`), or null when there is none
/// (FFmpeg never started, or the log was removed).
final monitorLogProvider = FutureProvider.family<String?, String>((ref, jobId) async {
  try {
    return await ref.watch(jobLogsProvider).logLocation(jobId);
  } on ServiceException {
    return null;
  } on CoreException {
    return null;
  }
}, retry: (_, _) => null);
