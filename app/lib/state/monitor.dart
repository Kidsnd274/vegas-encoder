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

/// How often, and how many times, [monitorJobRecordProvider] looks for the
/// record. The engine writes it as the render ends, beside the final status.
const monitorRecordAttempts = 8;
const monitorRecordInterval = Duration(milliseconds: 250);

/// The job's record (C6) once the render has ended, or null if it doesn't
/// appear within about two seconds or can't be read. The window then words
/// the result from the live file alone.
final monitorJobRecordProvider = FutureProvider.family<JobRecord?, String>((ref, jobId) async {
  final jobs = ref.watch(jobRepositoryProvider);
  for (var attempt = 1; ; attempt++) {
    try {
      final record = await jobs.get(jobId);
      if (record != null) return record;
    } on ServiceException {
      // Not complete yet, or malformed: look again, then give up.
    } on CoreException {
      return null; // the core didn't load: no record can be decoded
    }
    if (attempt >= monitorRecordAttempts || !ref.mounted) return null;
    await Future<void>.delayed(monitorRecordInterval);
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
