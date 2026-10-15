import 'package:ve_services/ve_services.dart';

/// The B0 job records with the fields B4's engine adds (C6): the encoder
/// summary, the realtime figure, FFmpeg's error tokens, and a log file for
/// some. The B0 fixtures predate them, so their index lines leave the
/// summaries unknown. Illustrative values, not a real render.
Future<List<JobRecord>> summarisedRecords() async {
  final repo = FakeJobRepository();
  final out = <JobRecord>[];
  for (final e in await repo.list()) {
    final r = (await repo.get(e.id))!;
    out.add(switch (r.id) {
      'j-1042' => r.copyWith(
        encoderSummary: 'x264 CRF 18, slow / AAC 320 kb/s',
        realtime: 0.51,
        logFile: 'j-1042.ffmpeg.log',
      ),
      'j-1041' => r.copyWith(encoderSummary: 'x264 CRF 18, slow / AAC 320 kb/s'),
      'j-1040' => r.copyWith(encoderSummary: 'NVENC HEVC CQ 21 / AAC 256 kb/s', realtime: 2.31),
      'j-1039' => r.copyWith(
        encoderSummary: 'SVT-AV1 CRF 32, preset 14 / Opus 160 kb/s',
        errorTokenIndices: _presetValue(r.argv),
        logFile: 'j-1039.ffmpeg.log',
      ),
      'j-1038' => r.copyWith(encoderSummary: 'ProRes 422 HQ / PCM 24-bit', realtime: 1.14),
      _ => r,
    });
  }
  return out;
}

/// `-preset 14` in the failed AV1 job's argv: both indexes, as the engine
/// records them (zero-based, executable excluded).
List<int> _presetValue(List<String> argv) {
  final at = argv.indexOf('-preset');
  return [at, at + 1];
}

/// FFmpeg's log for the failed AV1 render, as the engine keeps it.
const failedLog = '''
ffmpeg version 8.0 Copyright (c) 2000-2025 the FFmpeg developers
  built with gcc 14.2.0 (Rev2, Built by MSYS2 project)
Input #0, rawvideo, from '\\\\.\\pipe\\vegas-encoder-j-1039-video':
  Duration: N/A, start: 0.000000, bitrate: 7962624 kb/s
  Stream #0:0: Video: rawvideo (P010 / 0x30313050), p010le, 3840x2160, 29.97 tbr
Input #1, f32le, from '\\\\.\\pipe\\vegas-encoder-j-1039-audio':
  Stream #1:0: Audio: pcm_f32le, 48000 Hz, stereo, flt, 3072 kb/s
Stream mapping:
  Stream #0:0 -> #0:0 (rawvideo (native) -> av1 (libsvtav1))
  Stream #1:0 -> #0:1 (pcm_f32le (native) -> opus (libopus))
[libsvtav1 @ 0000020f] Error setting preset 14: must be between -2 and 13
[vost#0:0/libsvtav1] Error while opening encoder - maybe incorrect parameters such as bit_rate, rate, width or height.
Conversion failed!
''';

/// A finished render's log, one line per progress report.
final longLog = [
  'ffmpeg version 8.1 Copyright (c) 2000-2026 the FFmpeg developers',
  for (var i = 1; i <= 1500; i++)
    'frame=${i * 15} fps=31 q=23.0 size=${i * 6400}KiB time=00:00:${(i % 60).toString().padLeft(2, '0')}.00 speed=0.51x',
  'video:9384000KiB audio:29800KiB subtitle:0KiB other streams:0KiB global headers:0KiB muxing overhead: 0.0213%',
].join('\n');

/// The summarised records with their logs, for History's tests and goldens.
Future<FakeJobRepository> summarisedJobs() async =>
    FakeJobRepository(records: await summarisedRecords(), logs: {'j-1039': failedLog, 'j-1042': longLog});
