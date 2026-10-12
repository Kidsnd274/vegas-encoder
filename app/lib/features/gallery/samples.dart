// Local sample data for the design system gallery and its tests. It mirrors the
// states shown in docs/product/design/signal-flow.html (S1, S1 File node, S3)
// and stands in for FakeVeCore results until platform milestone B0 lands. No
// screen outside the gallery may use it.

import '../../design/components/command_view.dart';
import '../../design/components/select.dart';
import '../../design/components/signal_path/signal_path.dart';
import '../../design/components/size_card.dart';
import '../../design/components/slider.dart';
import '../../design/components/status.dart';

abstract final class Samples {
  static const source1080 = SignalSource(
    frameSize: '1920×1080',
    frameRate: '29.97 fps',
    pixelFormat: 'P010, 10-bit 4:2:0',
    audio: '48 kHz float stereo',
    stripVideo: '29.97 fps, 10-bit',
    stripAudio: '48 kHz float',
    depth: 10,
    spokenSummary: '1920 by 1080, 29.97 fps',
  );

  static const source4k = SignalSource(
    frameSize: '3840×2160',
    frameRate: '29.97 fps',
    pixelFormat: 'P010, 10-bit 4:2:0',
    audio: '48 kHz float stereo',
    stripVideo: '29.97 fps, 10-bit',
    stripAudio: '48 kHz float',
    depth: 10,
    spokenSummary: '3840 by 2160, 29.97 fps',
  );

  static const x264 = SignalStream(
    encoder: 'x264',
    detail: 'CRF 18, slow',
    codec: 'H.264',
    inputBits: 10,
    outputBits: 8,
    availability: VeAvailability.ready,
    runsOn: 'CPU',
    conversion: SignalConversion(label: 'p010le to yuv420p', shortLabel: '10 to 8-bit', note: '4:2:0, precision lost'),
    inputLabel: '10-bit',
    outputLabel: '8-bit',
  );

  static const aac = SignalStream(
    encoder: 'AAC',
    detail: '320 kb/s',
    codec: 'AAC',
    inputBits: 32,
    outputBits: 32,
    availability: VeAvailability.ready,
    formatLabel: '32-bit float',
  );

  static const mp4 = SignalContainer(label: 'MP4', detail: 'Fast start');

  /// S1: YouTube upload, H.264.
  static const youtube = SignalPathModel(
    source: source1080,
    video: x264,
    audio: aac,
    container: mp4,
    fileName: 'Sample project.mp4',
    contextLabel: 'Preview with: 1920×1080, 29.97 fps, 48 kHz stereo, 10 minutes',
  );

  /// 4K HEVC master, 10-bit: no conversion, FLAC with a float-to-integer pip,
  /// and NVENC failing its test on this PC.
  static const hevcMaster = SignalPathModel(
    source: source4k,
    video: SignalStream(
      encoder: 'NVENC HEVC',
      detail: 'CQ 20, p6',
      codec: 'HEVC',
      inputBits: 10,
      outputBits: 10,
      availability: VeAvailability.failed,
      runsOn: 'NVIDIA GPU',
      formatLabel: '10-bit 4:2:0',
    ),
    audio: SignalStream(
      encoder: 'FLAC',
      detail: 'Lossless, level 5',
      codec: 'FLAC',
      inputBits: 32,
      outputBits: 24,
      availability: VeAvailability.ready,
      conversion: SignalConversion(label: 'f32le to s32', shortLabel: 'Float to 24-bit', note: '24-bit integer'),
    ),
    container: SignalContainer(label: 'MKV', detail: '.mkv'),
    fileName: 'Master 4K.mkv',
    contextLabel: 'Preview with: 3840×2160, 29.97 fps, 48 kHz stereo, 10 minutes',
  );

  /// Audio off, and a container that can't hold the codec.
  static const audioOffBadMux = SignalPathModel(
    source: source1080,
    video: SignalStream(
      encoder: 'ProRes',
      detail: '422 HQ',
      codec: 'ProRes',
      inputBits: 10,
      outputBits: 10,
      availability: VeAvailability.ready,
      runsOn: 'CPU',
      conversion: SignalConversion(
        label: 'p010le to yuv422p10le',
        shortLabel: '4:2:0 to 4:2:2',
        note: '4:2:0 to 4:2:2, interpolated',
      ),
      inputLabel: '10-bit',
      outputLabel: '10-bit',
      muxProblem: true,
    ),
    container: SignalContainer(label: 'WebM', detail: '.webm'),
    fileName: 'Edit proxy.webm',
    contextLabel: 'Preview with: 1920×1080, 29.97 fps, 48 kHz stereo, 10 minutes',
  );

  /// S2: Advanced mode, read back from the command.
  static const fromCommand = SignalPathModel(
    source: source1080,
    video: SignalStream(
      encoder: 'x265',
      detail: 'preset slow, CRF 16',
      codec: 'HEVC',
      inputBits: 10,
      outputBits: 10,
      availability: VeAvailability.ready,
      runsOn: 'CPU',
      formatLabel: '10-bit 4:2:0',
    ),
    audio: SignalStream(
      encoder: 'FLAC',
      detail: 'From your command',
      codec: 'FLAC',
      inputBits: 32,
      outputBits: 24,
      availability: VeAvailability.ready,
      conversion: SignalConversion(label: 'f32le to s32', shortLabel: 'Float to 24-bit', note: '24-bit integer'),
    ),
    container: SignalContainer(label: 'MKV', detail: '.mkv'),
    fileName: 'Sample project.mkv',
    fromCommand: true,
  );

  /// S3 popup strip: two local changes and a newer library revision.
  static const popupStrip = SignalPathModel(
    source: source4k,
    video: SignalStream(
      encoder: 'x264',
      detail: 'CRF 17, slower',
      codec: 'H.264',
      inputBits: 10,
      outputBits: 8,
      availability: VeAvailability.ready,
      runsOn: 'CPU',
      conversion: SignalConversion(
        label: 'p010le to yuv420p',
        shortLabel: '10 to 8-bit',
        note: '4:2:0, precision lost',
      ),
    ),
    audio: SignalStream(
      encoder: 'AAC',
      detail: '256 kb/s',
      codec: 'AAC',
      inputBits: 32,
      outputBits: 32,
      availability: VeAvailability.ready,
    ),
    container: mp4,
    fileName: 'Lakeside wedding final.mp4',
    marks: {SignalNode.video: SignalMarks(changed: true), SignalNode.audio: SignalMarks(libraryRevision: 6)},
  );

  static const crf = VeQualityScale(
    unit: 'CRF',
    min: 0,
    max: 51,
    lowerIsBetter: true,
    marks: [
      VeQualityMark(0, 'Lossless'),
      VeQualityMark(12, 'Overkill'),
      VeQualityMark(18, 'Visually lossless'),
      VeQualityMark(23, 'FFmpeg default'),
      VeQualityMark(28, 'Small, visible loss'),
      VeQualityMark(35, 'Rough'),
    ],
    recommended: (start: 18, end: 23),
  );

  static const x264Speeds = [
    'placebo',
    'veryslow',
    'slower',
    'slow',
    'medium',
    'fast',
    'faster',
    'veryfast',
    'superfast',
    'ultrafast',
  ];

  static const videoEncoders = [
    VeEncoderGroup('H.264', [
      VeEncoderChoice(id: 'libx264', label: 'x264', detail: 'H.264, CPU, 10-bit', availability: VeAvailability.ready),
      VeEncoderChoice(
        id: 'h264_nvenc',
        label: 'NVENC H.264',
        detail: 'H.264, NVIDIA GPU, 8-bit only',
        availability: VeAvailability.ready,
      ),
      VeEncoderChoice(
        id: 'h264_amf',
        label: 'AMF H.264',
        detail: 'H.264, AMD GPU, 8-bit only',
        availability: VeAvailability.failed,
      ),
    ]),
    VeEncoderGroup('HEVC', [
      VeEncoderChoice(id: 'libx265', label: 'x265', detail: 'HEVC, CPU, 10-bit', availability: VeAvailability.ready),
      VeEncoderChoice(
        id: 'hevc_nvenc',
        label: 'NVENC HEVC',
        detail: 'HEVC, NVIDIA GPU, 10-bit',
        availability: VeAvailability.ready,
      ),
      VeEncoderChoice(
        id: 'hevc_qsv',
        label: 'QSV HEVC',
        detail: 'HEVC, Intel GPU, 10-bit',
        availability: VeAvailability.missing,
      ),
    ]),
    VeEncoderGroup('AV1', [
      VeEncoderChoice(
        id: 'libsvtav1',
        label: 'SVT-AV1',
        detail: 'AV1, CPU, 10-bit',
        availability: VeAvailability.ready,
      ),
      VeEncoderChoice(
        id: 'av1_nvenc',
        label: 'NVENC AV1',
        detail: 'AV1, NVIDIA GPU, 10-bit',
        availability: VeAvailability.testing,
      ),
    ]),
    VeEncoderGroup('Intermediate', [
      VeEncoderChoice(
        id: 'prores_ks',
        label: 'ProRes',
        detail: 'ProRes, CPU, 10-bit',
        availability: VeAvailability.ready,
      ),
      VeEncoderChoice(id: 'dnxhd', label: 'DNxHR', detail: 'DNxHR, CPU, 10-bit', availability: VeAvailability.ready),
    ]),
  ];

  static const command = CommandDisplay(
    inputs: [
      CommandToken('-hide_banner'),
      CommandToken('-nostdin'),
      CommandToken('-f'),
      CommandToken('rawvideo'),
      CommandToken('-pix_fmt'),
      CommandToken('p010le'),
      CommandToken('-s'),
      CommandToken('1920x1080'),
      CommandToken('-r'),
      CommandToken('30000/1001'),
      CommandToken('-i'),
      CommandToken(r'\\.\pipe\vegas-encoder-0000-video'),
      CommandToken('-f'),
      CommandToken('f32le'),
      CommandToken('-ar'),
      CommandToken('48000'),
      CommandToken('-ac'),
      CommandToken('2'),
      CommandToken('-i'),
      CommandToken(r'\\.\pipe\vegas-encoder-0000-audio'),
    ],
    lines: [
      CommandLine(CommandRole.inputs, [
        CommandToken('-map'),
        CommandToken('0:v:0'),
        CommandToken('-map'),
        CommandToken('1:a:0'),
      ]),
      CommandLine(CommandRole.video, [
        CommandToken('-c:v', field: 'video.encoder'),
        CommandToken('libx264', field: 'video.encoder'),
        CommandToken('-preset', field: 'video.speed'),
        CommandToken('slow', field: 'video.speed'),
        CommandToken('-crf', field: 'video.quality'),
        CommandToken('18', field: 'video.quality'),
        CommandToken('-profile:v', field: 'video.profile'),
        CommandToken('high', field: 'video.profile'),
        CommandToken('-pix_fmt', field: 'video.depth'),
        CommandToken('yuv420p', field: 'video.depth'),
        CommandToken('-g', field: 'video.gop'),
        CommandToken('60', field: 'video.gop'),
        CommandToken('-color_primaries', field: 'video.color'),
        CommandToken('bt709', field: 'video.color'),
        CommandToken('-color_trc', field: 'video.color'),
        CommandToken('bt709', field: 'video.color'),
        CommandToken('-colorspace', field: 'video.color'),
        CommandToken('bt709', field: 'video.color'),
        CommandToken('-color_range', field: 'video.color'),
        CommandToken('tv', field: 'video.color'),
        CommandToken('-bf', extra: true, field: 'video.extra'),
        CommandToken('3', extra: true, field: 'video.extra'),
      ]),
      CommandLine(CommandRole.audio, [
        CommandToken('-c:a', field: 'audio.encoder'),
        CommandToken('aac', field: 'audio.encoder'),
        CommandToken('-b:a', field: 'audio.bitrate'),
        CommandToken('320k', field: 'audio.bitrate'),
      ]),
      CommandLine(CommandRole.mux, [
        CommandToken('-movflags', field: 'container.faststart'),
        CommandToken('+faststart', field: 'container.faststart'),
        CommandToken('-f', field: 'container'),
        CommandToken('mp4', field: 'container'),
      ]),
      CommandLine(CommandRole.output, [CommandToken(r'"D:\Renders\Sample project.mp4"', field: 'output')]),
    ],
    copyText:
        'ffmpeg -hide_banner -nostdin -f rawvideo -pix_fmt p010le -s 1920x1080 -r 30000/1001 '
        r'-i \\.\pipe\vegas-encoder-0000-video -f f32le -ar 48000 -ac 2 -i \\.\pipe\vegas-encoder-0000-audio ^'
        '\n  -map 0:v:0 -map 1:a:0 ^\n  -c:v libx264 -preset slow -crf 18 -profile:v high -pix_fmt yuv420p -g 60 '
        '-color_primaries bt709 -color_trc bt709 -colorspace bt709 -color_range tv -bf 3 ^\n  -c:a aac -b:a 320k ^'
        '\n  -movflags +faststart -f mp4 ^\n  '
        r'"D:\Renders\Sample project.mp4"',
  );

  static const estimate = SizeEstimate(
    videoKbps: 6840,
    audioKbps: 320,
    approximate: true,
    spread: (low: 0.6, high: 1.6),
    consequences: [
      'Constant quality: the size depends on how busy the footage is.',
      '8-bit: VEGAS’s 10-bit frames are reduced once, so smooth gradients can band.',
    ],
  );

  static const estimateBitrate = SizeEstimate(
    videoKbps: 8000,
    audioKbps: null,
    approximate: false,
    consequences: [
      'Target bitrate: the size is predictable. Busy scenes get no extra bits, so they can soften.',
      'No audio: the file has video only.',
    ],
  );
}
