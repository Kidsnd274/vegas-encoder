/*
 * Vegas Encoder design mockups: shared content and behaviour.
 *
 * Every design direction loads this file so the mockups show the same real
 * content and the same live FFmpeg command. It is a *prototype* of the product
 * rules in docs/product/SETTINGS_AND_COMMANDS.md (recipe schema, command
 * compilation, validation, template linting). The product implementation lives
 * in the shared C++ core; this file is review material, not production code.
 *
 * Option names/ranges come from FFmpeg 8.1.3 help text (see avoptions.js).
 * Machine state (installations, GPUs, failures, history) is illustrative.
 *
 * Usage: <script src="../shared/avoptions.js"></script>
 *        <script src="../shared/model.js"></script>   -> window.VE
 */
(function (root) {
  'use strict';

  // ---------------------------------------------------------------- context
  /** What VEGAS tells the editor about the project (popup) or a sample (desktop). */
  const vegas = {
    host: 'VEGAS Pro 2026 (build 189)',
    project: 'Lakeside wedding final.veg',
    templateName: 'YouTube 4K upload (Lakeside)',
    output: 'D:\\Renders\\Lakeside wedding final.mp4',
    durationSec: 763.2,
    video: { width: 3840, height: 2160, fps: [30000, 1001], pixfmt: 'p010le', sar: '1:1' },
    audio: { rate: 48000, channels: 2, sampleFmt: 'f32le' },
    pipeId: '7f3a',
  };

  /** Sample context used in the desktop app when no VEGAS project is attached. */
  const sampleContext = {
    label: 'Preview with: 1920×1080, 29.97 fps, 48 kHz stereo, 10 minutes',
    durationSec: 600,
    video: { width: 1920, height: 1080, fps: [30000, 1001], pixfmt: 'p010le', sar: '1:1' },
    audio: { rate: 48000, channels: 2, sampleFmt: 'f32le' },
    output: 'D:\\Renders\\Sample project.mp4',
    pipeId: '0000',
  };

  // ---------------------------------------------------------- installations
  const ok = (note) => ({ state: 'ok', note });
  const failed = (reason, detail) => ({ state: 'failed', reason, detail });
  const missing = (reason) => ({ state: 'missing', reason });

  const gpu = 'NVIDIA GeForce RTX 4070';
  const qsvFail = failed('No Intel graphics device on this PC.',
    '[hevc_qsv @ 000001d4] Error creating a MFX session: -9.');
  const amfFail = failed('AMD encoder runtime not found.',
    '[h264_amf @ 000001c8] DLL amfrt64.dll failed to open');
  const fdkMissing = missing('Not in this build. libfdk_aac is non-free and is left out of redistributable FFmpeg builds.');

  const fullAvail = {
    libx264: ok(), libx265: ok(), libsvtav1: ok(), 'libvpx-vp9': ok(),
    h264_nvenc: ok(gpu), hevc_nvenc: ok(gpu), av1_nvenc: ok(gpu),
    h264_qsv: qsvFail, hevc_qsv: qsvFail, h264_amf: amfFail, hevc_amf: amfFail,
    prores_ks: ok(), dnxhd: ok(), ffv1: ok(),
    aac: ok(), libfdk_aac: fdkMissing, libopus: ok(), flac: ok(), alac: ok(),
    pcm_s16le: ok(), pcm_s24le: ok(), pcm_f32le: ok(), ac3: ok(), eac3: ok(), libmp3lame: ok(),
  };

  const installations = [
    {
      id: 'gyan-8.1', label: 'FFmpeg 8.1 full', version: '8.1', build: 'gyan.dev full build',
      source: 'winget', license: 'GPL v3', isDefault: true,
      path: 'C:\\Users\\editor\\AppData\\Local\\Microsoft\\WinGet\\Packages\\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\\ffmpeg-8.1-full_build\\bin\\ffmpeg.exe',
      sha256: '5f1c0d3e…b29a2e', probedAt: 'Today, 09:12', probeMs: 2140,
      counts: { video: 142, audio: 91, muxers: 181 },
      availability: fullAvail,
    },
    {
      id: 'manual-7.1', label: 'FFmpeg 7.1.1', version: '7.1.1', build: 'gyan.dev essentials build',
      source: 'Added manually', license: 'GPL v3', isDefault: false,
      path: 'C:\\ffmpeg\\bin\\ffmpeg.exe',
      sha256: 'a90b77c2…4e01d3', probedAt: '3 days ago', probeMs: 1890,
      counts: { video: 98, audio: 74, muxers: 176 },
      availability: Object.assign({}, fullAvail, {
        av1_nvenc: ok(gpu),
        ffv1: ok(),
      }),
    },
    {
      id: 'btbn-lgpl-8.0', label: 'FFmpeg 8.0 LGPL', version: '8.0', build: 'BtbN win64 LGPL shared',
      source: 'Found on PATH', license: 'LGPL v2.1', isDefault: false,
      path: 'D:\\Tools\\ffmpeg-n8.0-latest-win64-lgpl-shared\\bin\\ffmpeg.exe',
      sha256: '3c4d9e10…77f0b8', probedAt: 'Last week', probeMs: 2410,
      counts: { video: 120, audio: 88, muxers: 180 },
      availability: Object.assign({}, fullAvail, {
        libx264: missing('Not in this build. LGPL builds leave out GPL encoders such as x264 and x265.'),
        libx265: missing('Not in this build. LGPL builds leave out GPL encoders such as x264 and x265.'),
      }),
    },
  ];

  // ------------------------------------------------------------- containers
  const containers = {
    mp4: { id: 'mp4', label: 'MP4', muxer: 'mp4', ext: '.mp4', blurb: 'Plays almost everywhere. Best for uploads and sharing.' },
    mkv: { id: 'mkv', label: 'Matroska (MKV)', muxer: 'matroska', ext: '.mkv', blurb: 'Accepts nearly every codec and survives interrupted writes.' },
    mov: { id: 'mov', label: 'QuickTime (MOV)', muxer: 'mov', ext: '.mov', blurb: 'The usual home for ProRes and DNxHR intermediates.' },
    webm: { id: 'webm', label: 'WebM', muxer: 'webm', ext: '.webm', blurb: 'Web delivery with VP9 or AV1 and Opus.' },
    mxf: { id: 'mxf', label: 'MXF', muxer: 'mxf', ext: '.mxf', blurb: 'Broadcast and Avid workflows with DNxHR.' },
  };
  // Note: VEGAS currently lists the class-wide *.mkv extension (F-050). Per-template
  // extensions are an open adapter question; see docs/product/TECH_ARCHITECTURE.md.

  /**
   * Codec/container compatibility used for validation messages.
   * 'ok' | 'warn' (muxes, but limited player support or needs flags) | 'no' (muxer refuses).
   * From 226 real test muxes with FFmpeg 8.1.3 (p010le/f32le raw input, like the pipes):
   * evidence/2026-10-11-product-design/container-matrix. 'warn' marks combinations that
   * mux but that few players open. MPEG-TS is deliberately absent: it exits 0 while
   * writing VP9/AV1/ProRes/FFV1/FLAC/PCM as opaque data streams. MXF needs the video
   * stream first and accepts only 16/24-bit PCM audio.
   */
  const compat = {
    video: {
      h264: { mp4: 'ok', mkv: 'ok', mov: 'ok', webm: 'no', mxf: 'warn' },
      hevc: { mp4: 'ok', mkv: 'ok', mov: 'ok', webm: 'no', mxf: 'no' },
      av1: { mp4: 'ok', mkv: 'ok', mov: 'no', webm: 'ok', mxf: 'no' },
      vp9: { mp4: 'warn', mkv: 'ok', mov: 'no', webm: 'ok', mxf: 'no' },
      prores: { mp4: 'no', mkv: 'ok', mov: 'ok', webm: 'no', mxf: 'ok' },
      dnxhr: { mp4: 'no', mkv: 'ok', mov: 'ok', webm: 'no', mxf: 'ok' },
      ffv1: { mp4: 'warn', mkv: 'ok', mov: 'warn', webm: 'no', mxf: 'warn' },
    },
    audio: {
      aac: { mp4: 'ok', mkv: 'ok', mov: 'ok', webm: 'no', mxf: 'no' },
      opus: { mp4: 'ok', mkv: 'ok', mov: 'no', webm: 'ok', mxf: 'no' },
      flac: { mp4: 'warn', mkv: 'ok', mov: 'no', webm: 'no', mxf: 'no' },
      alac: { mp4: 'ok', mkv: 'ok', mov: 'ok', webm: 'no', mxf: 'no' },
      pcm: { mp4: 'warn', mkv: 'ok', mov: 'ok', webm: 'no', mxf: 'ok' },
      pcmf: { mp4: 'warn', mkv: 'ok', mov: 'ok', webm: 'no', mxf: 'no' },
      ac3: { mp4: 'ok', mkv: 'ok', mov: 'ok', webm: 'no', mxf: 'no' },
      mp3: { mp4: 'ok', mkv: 'ok', mov: 'ok', webm: 'no', mxf: 'no' },
    },
  };

  // --------------------------------------------------------- rate controls
  /** Rate-control modes, named for what the user gets rather than the flag. */
  const rateModes = {
    crf: { id: 'crf', label: 'Constant quality', short: 'Quality', blurb: 'Every scene gets the same visual quality; file size varies with content.' },
    cq: { id: 'cq', label: 'Constant quality', short: 'Quality', blurb: 'GPU constant-quality mode; file size varies with content.' },
    abr: { id: 'abr', label: 'Target bitrate', short: 'Bitrate', blurb: 'Aims for an average bitrate, so file size is predictable.' },
    cbr: { id: 'cbr', label: 'Constant bitrate', short: 'CBR', blurb: 'Fixed bitrate for streaming and strict delivery specs. Wastes bits on easy scenes.' },
    cqp: { id: 'cqp', label: 'Fixed quantizer', short: 'QP', blurb: 'Same quantizer for every frame. Mostly for testing and special cases.' },
    profile: { id: 'profile', label: 'Set by profile', short: 'Profile', blurb: 'The codec profile fixes the data rate; there is no quality dial.' },
    lossless: { id: 'lossless', label: 'Lossless', short: 'Lossless', blurb: 'Decodes to exactly the pixels VEGAS delivered.' },
  };

  const x26xPresets = ['ultrafast', 'superfast', 'veryfast', 'faster', 'fast', 'medium', 'slow', 'slower', 'veryslow', 'placebo'];
  const nvPresets = ['p1', 'p2', 'p3', 'p4', 'p5', 'p6', 'p7'];
  const nvPresetNames = { p1: 'Fastest', p2: 'Faster', p3: 'Fast', p4: 'Medium', p5: 'Slow', p6: 'Slower', p7: 'Slowest' };

  // ---------------------------------------------------------- video encoders
  /**
   * Curated encoder profiles: the fields the structured editor shows.
   * speed.values run fastest-first unless speed.slowFirst is set.
   * Everything else stays reachable through "All options" (parsed AVOptions)
   * and "Extra arguments".
   */
  const videoEncoders = {
    libx264: {
      id: 'libx264', label: 'x264', codec: 'H.264', family: 'h264', hw: null,
      blurb: 'Plays everywhere. Excellent quality for its size; runs on the CPU.',
      modes: ['crf', 'abr', 'cbr', 'cqp'],
      quality: { flag: '-crf', min: 0, max: 51, step: 1, def: 18, lowerIsBetter: true,
        marks: [[0, 'Lossless'], [12, 'Overkill'], [18, 'Visually lossless'], [23, 'FFmpeg default'], [28, 'Small, visible loss'], [35, 'Rough']] },
      qp: { flag: '-qp', min: 0, max: 51, def: 20 },
      speed: { flag: '-preset', values: x26xPresets, def: 'medium', slowLabel: 'Smaller file', fastLabel: 'Faster encode' },
      tune: { flag: '-tune', values: ['film', 'animation', 'grain', 'stillimage', 'fastdecode', 'zerolatency'] },
      profile: { flag: '-profile:v', values: ['baseline', 'main', 'high', 'high10', 'high422', 'high444'], def: 'high' },
      depths: { 8: 'yuv420p', 10: 'yuv420p10le' }, depthDef: 8,
      paramsFlag: '-x264-params',
    },
    libx265: {
      id: 'libx265', label: 'x265', codec: 'HEVC', family: 'hevc', hw: null,
      blurb: 'About 30–50% smaller than H.264 at the same quality. Slow on the CPU.',
      modes: ['crf', 'abr', 'cbr', 'cqp'],
      quality: { flag: '-crf', min: 0, max: 51, step: 1, def: 20, lowerIsBetter: true,
        marks: [[0, 'Near lossless'], [16, 'Visually lossless'], [20, 'High'], [28, 'FFmpeg default'], [32, 'Small']] },
      qp: { flag: '-qp', min: 0, max: 51, def: 22 },
      speed: { flag: '-preset', values: x26xPresets, def: 'medium', slowLabel: 'Smaller file', fastLabel: 'Faster encode' },
      tune: { flag: '-tune', values: ['grain', 'animation', 'fastdecode', 'zerolatency', 'psnr', 'ssim'] },
      profile: { flag: '-profile:v', values: ['main', 'main10', 'main444-8', 'main444-10'], def: 'main10' },
      depths: { 8: 'yuv420p', 10: 'yuv420p10le' }, depthDef: 10,
      paramsFlag: '-x265-params', appleTag: 'hvc1',
    },
    libsvtav1: {
      id: 'libsvtav1', label: 'SVT-AV1', codec: 'AV1', family: 'av1', hw: null,
      blurb: 'Smallest files for web delivery. Newer devices decode it in hardware.',
      modes: ['crf', 'abr', 'cqp'],
      quality: { flag: '-crf', min: 0, max: 63, step: 1, def: 30, lowerIsBetter: true,
        marks: [[10, 'Overkill'], [20, 'Visually lossless'], [30, 'High'], [35, 'FFmpeg default'], [45, 'Small']] },
      qp: { flag: '-qp', min: 0, max: 63, def: 30 },
      speed: { flag: '-preset', values: ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13'], def: '6', slowFirst: true, slowLabel: 'Smaller file', fastLabel: 'Faster encode' },
      tune: null,
      profile: null,
      depths: { 8: 'yuv420p', 10: 'yuv420p10le' }, depthDef: 10,
      paramsFlag: '-svtav1-params',
    },
    'libvpx-vp9': {
      id: 'libvpx-vp9', label: 'libvpx VP9', codec: 'VP9', family: 'vp9', hw: null,
      blurb: 'Royalty-free web codec. Slow; mostly replaced by AV1.',
      modes: ['crf', 'abr', 'cbr'],
      quality: { flag: '-crf', min: 0, max: 63, step: 1, def: 31, lowerIsBetter: true,
        marks: [[15, 'Visually lossless'], [31, 'Recommended for 1080p'], [40, 'Small']] },
      speed: { flag: '-cpu-used', values: ['0', '1', '2', '3', '4', '5'], def: '2', slowFirst: true, slowLabel: 'Smaller file', fastLabel: 'Faster encode' },
      tune: null, profile: null,
      depths: { 8: 'yuv420p', 10: 'yuv420p10le' }, depthDef: 8,
    },
    h264_nvenc: {
      id: 'h264_nvenc', label: 'NVENC H.264', codec: 'H.264', family: 'h264', hw: 'NVIDIA',
      blurb: 'Very fast GPU encoding with H.264 compatibility. Larger than x264 at equal quality.',
      modes: ['cq', 'abr', 'cbr', 'cqp'],
      quality: { flag: '-cq', min: 1, max: 51, step: 1, def: 21, lowerIsBetter: true,
        marks: [[16, 'Visually lossless'], [21, 'High'], [26, 'Medium'], [32, 'Small']] },
      qp: { flag: '-qp', min: 0, max: 51, def: 20 },
      speed: { flag: '-preset', values: nvPresets, def: 'p5', names: nvPresetNames, slowLabel: 'Better quality', fastLabel: 'Faster encode' },
      tune: { flag: '-tune', values: ['hq', 'll', 'ull', 'lossless'], def: 'hq' },
      profile: { flag: '-profile:v', values: ['baseline', 'main', 'high', 'high444p'], def: 'high' },
      depths: { 8: 'yuv420p' }, depthDef: 8,
      multipass: { flag: '-multipass', values: ['disabled', 'qres', 'fullres'], def: 'disabled' },
    },
    hevc_nvenc: {
      id: 'hevc_nvenc', label: 'NVENC HEVC', codec: 'HEVC', family: 'hevc', hw: 'NVIDIA',
      blurb: 'Fast GPU HEVC with 10-bit support. Takes VEGAS’s P010 frames without conversion.',
      modes: ['cq', 'abr', 'cbr', 'cqp'],
      quality: { flag: '-cq', min: 1, max: 51, step: 1, def: 20, lowerIsBetter: true,
        marks: [[15, 'Visually lossless'], [20, 'High'], [25, 'Medium'], [30, 'Small']] },
      qp: { flag: '-qp', min: 0, max: 51, def: 20 },
      speed: { flag: '-preset', values: nvPresets, def: 'p5', names: nvPresetNames, slowLabel: 'Better quality', fastLabel: 'Faster encode' },
      tune: { flag: '-tune', values: ['hq', 'uhq', 'll', 'ull', 'lossless'], def: 'hq' },
      profile: { flag: '-profile:v', values: ['main', 'main10', 'rext'], def: 'main10' },
      depths: { 8: 'yuv420p', 10: 'p010le' }, depthDef: 10,
      multipass: { flag: '-multipass', values: ['disabled', 'qres', 'fullres'], def: 'disabled' },
      appleTag: 'hvc1',
    },
    av1_nvenc: {
      id: 'av1_nvenc', label: 'NVENC AV1', codec: 'AV1', family: 'av1', hw: 'NVIDIA',
      blurb: 'GPU AV1 on RTX 40-series and newer. Small files at GPU speed.',
      modes: ['cq', 'abr', 'cbr', 'cqp'],
      quality: { flag: '-cq', min: 1, max: 63, step: 1, def: 30, lowerIsBetter: true,
        marks: [[20, 'Visually lossless'], [30, 'High'], [38, 'Medium'], [45, 'Small']] },
      qp: { flag: '-qp', min: 0, max: 255, def: 80 },
      speed: { flag: '-preset', values: nvPresets, def: 'p5', names: nvPresetNames, slowLabel: 'Better quality', fastLabel: 'Faster encode' },
      tune: { flag: '-tune', values: ['hq', 'uhq', 'll', 'ull', 'lossless'], def: 'hq' },
      profile: null,
      depths: { 8: 'yuv420p', 10: 'p010le' }, depthDef: 10,
      multipass: { flag: '-multipass', values: ['disabled', 'qres', 'fullres'], def: 'disabled' },
    },
    hevc_qsv: {
      id: 'hevc_qsv', label: 'Quick Sync HEVC', codec: 'HEVC', family: 'hevc', hw: 'Intel',
      blurb: 'Intel GPU encoding. Needs an Intel iGPU or Arc card.',
      modes: ['cq', 'abr', 'cbr'],
      quality: { flag: '-global_quality', min: 1, max: 51, step: 1, def: 22, lowerIsBetter: true,
        marks: [[18, 'Visually lossless'], [22, 'High'], [28, 'Small']] },
      speed: { flag: '-preset', values: ['veryslow', 'slower', 'slow', 'medium', 'fast', 'faster', 'veryfast'], def: 'medium', slowFirst: true, slowLabel: 'Better quality', fastLabel: 'Faster encode' },
      tune: null, profile: { flag: '-profile:v', values: ['main', 'main10'], def: 'main10' },
      depths: { 8: 'nv12', 10: 'p010le' }, depthDef: 10,
    },
    h264_amf: {
      id: 'h264_amf', label: 'AMF H.264', codec: 'H.264', family: 'h264', hw: 'AMD',
      blurb: 'AMD GPU encoding. Needs a Radeon GPU and the AMD driver.',
      modes: ['cq', 'abr', 'cbr', 'cqp'],
      quality: { flag: '-qp_i', min: 0, max: 51, step: 1, def: 20, lowerIsBetter: true, marks: [[18, 'High'], [26, 'Small']] },
      speed: { flag: '-quality', values: ['quality', 'balanced', 'speed'], def: 'balanced', slowFirst: true, slowLabel: 'Better quality', fastLabel: 'Faster encode' },
      tune: null, profile: null, depths: { 8: 'nv12' }, depthDef: 8,
    },
    prores_ks: {
      id: 'prores_ks', label: 'prores_ks', codec: 'ProRes', family: 'prores', hw: null,
      blurb: 'Editing intermediate. Large files that scrub smoothly in any editor.',
      modes: ['profile'],
      profileQuality: { flag: '-profile:v', values: ['proxy', 'lt', 'standard', 'hq', '4444', '4444xq'], def: 'hq',
        names: { proxy: 'Proxy', lt: 'LT', standard: '422', hq: '422 HQ', '4444': '4444', '4444xq': '4444 XQ' },
        // Approximate data rates at 1920x1080 29.97 (Apple ProRes white paper ballpark).
        mbps1080: { proxy: 45, lt: 102, standard: 147, hq: 220, '4444': 330, '4444xq': 500 } },
      speed: null, tune: null, profile: null,
      depths: { 10: 'yuv422p10le' }, depthDef: 10, chroma: '4:2:2',
      vendor: 'apl0',
    },
    dnxhd: {
      id: 'dnxhd', label: 'dnxhd', codec: 'DNxHR', family: 'dnxhr', hw: null,
      blurb: 'Avid’s editing intermediate. Common for MXF and broadcast handoff.',
      modes: ['profile'],
      profileQuality: { flag: '-profile:v', values: ['dnxhr_lb', 'dnxhr_sq', 'dnxhr_hq', 'dnxhr_hqx', 'dnxhr_444'], def: 'dnxhr_hq',
        names: { dnxhr_lb: 'LB', dnxhr_sq: 'SQ', dnxhr_hq: 'HQ', dnxhr_hqx: 'HQX (10-bit)', dnxhr_444: '444 (10-bit)' },
        mbps1080: { dnxhr_lb: 45, dnxhr_sq: 145, dnxhr_hq: 220, dnxhr_hqx: 220, dnxhr_444: 440 },
        pixfmt: { dnxhr_lb: 'yuv422p', dnxhr_sq: 'yuv422p', dnxhr_hq: 'yuv422p', dnxhr_hqx: 'yuv422p10le', dnxhr_444: 'yuv444p10le' } },
      speed: null, tune: null, profile: null,
      depths: { 8: 'yuv422p', 10: 'yuv422p10le' }, depthDef: 8, chroma: '4:2:2',
    },
    ffv1: {
      id: 'ffv1', label: 'FFV1', codec: 'FFV1', family: 'ffv1', hw: null,
      blurb: 'Mathematically lossless archive. The profile Vegas Encoder ships with today.',
      modes: ['lossless'],
      speed: null, tune: null, profile: null,
      depths: { 10: 'yuv420p10le' }, depthDef: 10,
      fixedArgs: ['-level', '3', '-g', '1', '-slices', '16', '-slicecrc', '1'],
      // Rough: lossless 10-bit 4:2:0 typically lands near 40-60% of raw size.
      mbpsPerMpix: 95,
    },
  };

  const videoOrder = [
    { group: 'H.264', ids: ['libx264', 'h264_nvenc', 'h264_amf'] },
    { group: 'HEVC', ids: ['libx265', 'hevc_nvenc', 'hevc_qsv'] },
    { group: 'AV1', ids: ['libsvtav1', 'av1_nvenc'] },
    { group: 'VP9', ids: ['libvpx-vp9'] },
    { group: 'Editing intermediates', ids: ['prores_ks', 'dnxhd'] },
    { group: 'Lossless', ids: ['ffv1'] },
  ];

  // ---------------------------------------------------------- audio encoders
  const audioEncoders = {
    aac: { id: 'aac', label: 'AAC', codec: 'AAC', family: 'aac', blurb: 'The default for MP4 and every upload site.',
      modes: ['bitrate'], bitrate: { values: [96, 128, 160, 192, 256, 320, 384, 512], def: 320 }, rates: [44100, 48000, 96000] },
    libfdk_aac: { id: 'libfdk_aac', label: 'Fraunhofer AAC', codec: 'AAC', family: 'aac', blurb: 'Higher-quality AAC encoder; only in self-built FFmpeg.',
      modes: ['bitrate', 'vbr'], bitrate: { values: [96, 128, 192, 256, 320], def: 256 }, vbr: { flag: '-vbr', min: 1, max: 5, def: 5 }, rates: [44100, 48000] },
    libopus: { id: 'libopus', label: 'Opus', codec: 'Opus', family: 'opus', blurb: 'Best quality per bit. Native to WebM and MKV.',
      modes: ['bitrate'], bitrate: { values: [64, 96, 128, 160, 192, 256, 320, 510], def: 160 }, rates: [48000], vbrMode: 'on' },
    flac: { id: 'flac', label: 'FLAC', codec: 'FLAC', family: 'flac', blurb: 'Lossless and about half the size of PCM.',
      modes: ['lossless'], level: { flag: '-compression_level', min: 0, max: 12, def: 8 }, rates: [44100, 48000, 96000] },
    alac: { id: 'alac', label: 'Apple Lossless', codec: 'ALAC', family: 'alac', blurb: 'Lossless audio for Apple workflows.',
      modes: ['lossless'], rates: [44100, 48000, 96000] },
    pcm_s16le: { id: 'pcm_s16le', label: 'PCM 16-bit', codec: 'PCM', family: 'pcm', blurb: 'Uncompressed 16-bit. Universal in MOV and MXF.',
      modes: ['lossless'], rates: [44100, 48000, 96000], bits: 16 },
    pcm_s24le: { id: 'pcm_s24le', label: 'PCM 24-bit', codec: 'PCM', family: 'pcm', blurb: 'Uncompressed 24-bit for mastering and handoff.',
      modes: ['lossless'], rates: [44100, 48000, 96000], bits: 24 },
    pcm_f32le: { id: 'pcm_f32le', label: 'PCM 32-bit float', codec: 'PCM', family: 'pcmf', blurb: 'Exactly what VEGAS delivers. Current lossless baseline.',
      modes: ['lossless'], rates: [48000], bits: 32 },
    ac3: { id: 'ac3', label: 'Dolby Digital (AC-3)', codec: 'AC-3', family: 'ac3', blurb: 'Disc and broadcast compatibility.',
      modes: ['bitrate'], bitrate: { values: [192, 256, 384, 448, 640], def: 448 }, rates: [48000] },
    eac3: { id: 'eac3', label: 'Dolby Digital Plus (E-AC-3)', codec: 'E-AC-3', family: 'ac3', blurb: 'Streaming-service deliverables.',
      modes: ['bitrate'], bitrate: { values: [192, 256, 384, 640, 1024], def: 384 }, rates: [48000] },
    libmp3lame: { id: 'libmp3lame', label: 'MP3 (LAME)', codec: 'MP3', family: 'mp3', blurb: 'Legacy compatibility.',
      modes: ['bitrate', 'vbr'], bitrate: { values: [128, 192, 256, 320], def: 320 }, vbr: { flag: '-q:a', min: 0, max: 9, def: 0, lowerIsBetter: true }, rates: [44100, 48000] },
  };

  const audioOrder = [
    { group: 'Lossy', ids: ['aac', 'libopus', 'libfdk_aac', 'ac3', 'eac3', 'libmp3lame'] },
    { group: 'Lossless', ids: ['flac', 'alac', 'pcm_s16le', 'pcm_s24le', 'pcm_f32le'] },
  ];

  // ----------------------------------------------------------------- recipes
  /**
   * Recipe = portable encoding settings (schema v1 prototype).
   * See docs/product/SETTINGS_AND_COMMANDS.md for the authoritative description.
   */
  function recipe(o) {
    const r = {
      schema: 1,
      id: o.id, name: o.name, notes: o.notes || '', tags: o.tags || [], category: o.category || 'custom',
      revision: o.revision || 1, updated: o.updated || 'Today', builtin: !!o.builtin, favorite: !!o.favorite,
      container: Object.assign({ format: 'mp4', faststart: true }, o.container),
      video: Object.assign({
        enabled: true, encoder: 'libx264', mode: 'crf', quality: null, bitrateK: 12000, maxrateK: null,
        qp: null, speed: null, tune: null, profile: null, depth: null, gopSec: 2,
        color: 'bt709', options: {}, extra: '',
      }, o.video),
      audio: Object.assign({
        enabled: true, encoder: 'aac', mode: 'bitrate', bitrateK: 320, vbr: null, level: null,
        sampleRate: 'source', channels: 'source', options: {}, extra: '',
      }, o.audio),
      command: Object.assign({ mode: 'structured', template: '' }, o.command),
      vegas: Object.assign({ frame: 'project', inputFormat: 'p010' }, o.vegas),
    };
    return r;
  }

  const library = [
    recipe({ id: 'yt-h264', name: 'YouTube upload, H.264', builtin: true, category: 'web', revision: 6, updated: '2 days ago', favorite: true,
      tags: ['YouTube', 'Upload'], notes: 'High-quality H.264 that YouTube re-encodes well. Use for anything up to 4K.',
      video: { encoder: 'libx264', mode: 'crf', quality: 18, speed: 'slow', profile: 'high', depth: 8 },
      audio: { encoder: 'aac', bitrateK: 320 } }),
    recipe({ id: 'yt-hevc-nv', name: 'YouTube upload, HEVC on GPU', builtin: true, category: 'web', revision: 3, updated: 'Last week',
      tags: ['YouTube', 'NVIDIA', 'HDR-ready'], notes: '10-bit HEVC on NVIDIA. Several times faster than x264 for long timelines.',
      video: { encoder: 'hevc_nvenc', mode: 'cq', quality: 20, speed: 'p5', tune: 'hq', profile: 'main10', depth: 10 },
      audio: { encoder: 'aac', bitrateK: 320 } }),
    recipe({ id: 'av1-small', name: 'Small web file, AV1', builtin: true, category: 'web', revision: 2, updated: 'Last month',
      tags: ['Web', 'Small'], container: { format: 'mkv', faststart: false },
      video: { encoder: 'libsvtav1', mode: 'crf', quality: 32, speed: '6', depth: 10 },
      audio: { encoder: 'libopus', bitrateK: 160 } }),
    recipe({ id: 'prores-hq', name: 'ProRes 422 HQ for editing', builtin: true, category: 'edit', revision: 1, updated: 'Last month',
      tags: ['Intermediate', 'Resolve', 'Premiere'], container: { format: 'mov', faststart: false },
      video: { encoder: 'prores_ks', mode: 'profile', profile: 'hq', depth: 10, gopSec: null },
      audio: { encoder: 'pcm_s24le', mode: 'lossless' } }),
    recipe({ id: 'dnxhr-hq', name: 'DNxHR HQ for Avid', builtin: true, category: 'edit', revision: 1, updated: 'Last month',
      tags: ['Intermediate', 'Avid', 'MXF'], container: { format: 'mxf', faststart: false },
      video: { encoder: 'dnxhd', mode: 'profile', profile: 'dnxhr_hq', depth: 8, gopSec: null },
      audio: { encoder: 'pcm_s16le', mode: 'lossless' } }),
    recipe({ id: 'ffv1-master', name: 'Lossless master, FFV1', builtin: true, category: 'master', revision: 1, updated: 'Oct 10',
      tags: ['Archive', 'Lossless'], notes: 'The fixed profile from the current adapter baseline: FFV1 10-bit and float PCM in MKV.',
      container: { format: 'mkv', faststart: false },
      video: { encoder: 'ffv1', mode: 'lossless', depth: 10, gopSec: null },
      audio: { encoder: 'pcm_f32le', mode: 'lossless' } }),
    recipe({ id: 'client-review', name: 'Client review, 1080p 8 Mbps', category: 'review', revision: 4, updated: 'Yesterday', favorite: true,
      tags: ['Review', 'Frame.io'], notes: 'Predictable size for review links. VEGAS renders at 1080p.',
      video: { encoder: 'h264_nvenc', mode: 'abr', bitrateK: 8000, maxrateK: 12000, speed: 'p6', tune: 'hq', profile: 'high', depth: 8 },
      audio: { encoder: 'aac', bitrateK: 192 }, vegas: { frame: '1920x1080' } }),
    recipe({ id: 'twitch-vod', name: 'Twitch highlight, 6 Mbps CBR', category: 'social', revision: 2, updated: '3 weeks ago',
      tags: ['Twitch'], video: { encoder: 'h264_nvenc', mode: 'cbr', bitrateK: 6000, speed: 'p5', tune: 'hq', profile: 'high', depth: 8 },
      audio: { encoder: 'aac', bitrateK: 160 } }),
    recipe({ id: 'reels', name: 'Instagram Reels, vertical', category: 'social', revision: 1, updated: '2 months ago',
      tags: ['Instagram', 'Vertical'], notes: 'Set the VEGAS project to 1080×1920 first.',
      video: { encoder: 'libx264', mode: 'abr', bitrateK: 10000, maxrateK: 15000, speed: 'slow', profile: 'high', depth: 8 },
      audio: { encoder: 'aac', bitrateK: 256 } }),
    recipe({ id: 'x265-master', name: '4K HEVC master, 10-bit', category: 'master', revision: 7, updated: 'Today', favorite: true,
      tags: ['Master', '4K'], container: { format: 'mkv', faststart: false },
      video: { encoder: 'libx265', mode: 'crf', quality: 16, speed: 'slower', profile: 'main10', depth: 10,
        options: { 'x265-params': 'aq-mode=3:psy-rd=1.5' } },
      audio: { encoder: 'flac', mode: 'lossless', level: 8 } }),
    recipe({ id: 'hdr-template', name: 'HDR10 HEVC (command)', category: 'custom', revision: 3, updated: '5 days ago',
      tags: ['HDR', 'Command'], notes: 'Hand-written command with HDR10 mastering metadata. Grade must already be PQ in VEGAS.',
      container: { format: 'mkv', faststart: false },
      video: { encoder: 'libx265', mode: 'crf', quality: 18, speed: 'slow', profile: 'main10', depth: 10 },
      audio: { encoder: 'aac', bitrateK: 320 },
      command: { mode: 'template', template:
        'ffmpeg -hide_banner {inputs}\n' +
        '  -map {v} -map {a}\n' +
        '  -c:v libx265 -preset slow -crf 18 -pix_fmt yuv420p10le\n' +
        '  -x265-params "hdr10=1:repeat-headers=1:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc:master-display=G(13250,34500)B(7500,3000)R(34000,16000)WP(15635,16450)L(10000000,1):max-cll=1000,400"\n' +
        '  -c:a aac -b:a 320k\n' +
        '  {output}' } }),
  ];

  const categories = {
    web: { label: 'Web upload' }, edit: { label: 'Editing intermediate' }, master: { label: 'Master and archive' },
    review: { label: 'Review' }, social: { label: 'Social' }, custom: { label: 'Custom command' },
  };

  /** The VEGAS template being edited in the popup: a snapshot copied from a library preset, then edited. */
  function templateSession() {
    const current = clone(library.find((p) => p.id === 'yt-h264'));  // library revision 6
    const base = clone(current);                                       // revision 5, when the template was made
    base.revision = 5;
    base.audio.bitrateK = 256;
    const edited = clone(base);                                        // local edits made in VEGAS
    edited.name = vegas.templateName;
    edited.video.quality = 17;
    edited.video.speed = 'slower';
    return {
      templateName: vegas.templateName,
      origin: { id: base.id, name: base.name, revision: base.revision },
      libraryRevision: current.revision,
      recipe: edited,      // what the template holds and renders with
      base,                // origin revision as copied (local edits = diff(base, recipe))
      library: current,    // what "Update from library" would bring in (diff(recipe, library))
    };
  }

  // ----------------------------------------------------------------- history
  const history = [
    { id: 'j-1042', when: 'Today 14:22', project: 'Lakeside wedding final.veg', template: 'YouTube 4K upload (Lakeside)',
      output: 'D:\\Renders\\Lakeside wedding final.mp4', status: 'succeeded', encoder: 'libx264 + aac', container: 'MP4',
      durationSec: 763.2, elapsedSec: 1486, sizeBytes: 9.84e9, avgFps: 15.4, ffmpeg: 'FFmpeg 8.1 full', exit: 0 },
    { id: 'j-1041', when: 'Today 13:58', project: 'Lakeside wedding final.veg', template: 'YouTube 4K upload (Lakeside)',
      output: 'D:\\Renders\\Lakeside wedding final.mp4', status: 'cancelled', encoder: 'libx264 + aac', container: 'MP4',
      durationSec: 763.2, elapsedSec: 212, sizeBytes: 0, avgFps: 15.1, ffmpeg: 'FFmpeg 8.1 full', exit: null,
      note: 'Cancelled in VEGAS at 14%. Partial file removed.' },
    { id: 'j-1040', when: 'Yesterday 21:05', project: 'Channel trailer v2.veg', template: 'YouTube upload, HEVC on GPU',
      output: 'D:\\Renders\\Channel trailer v2.mp4', status: 'succeeded', encoder: 'hevc_nvenc + aac', container: 'MP4',
      durationSec: 94.5, elapsedSec: 41, sizeBytes: 3.1e8, avgFps: 69.2, ffmpeg: 'FFmpeg 8.1 full', exit: 0 },
    { id: 'j-1039', when: 'Yesterday 20:51', project: 'Channel trailer v2.veg', template: 'Small web file, AV1',
      output: 'D:\\Renders\\Channel trailer v2.mkv', status: 'failed', encoder: 'libsvtav1 + libopus', container: 'MKV',
      durationSec: 94.5, elapsedSec: 3, sizeBytes: 0, avgFps: 0, ffmpeg: 'FFmpeg 8.1 full', exit: 1,
      note: 'FFmpeg exited with code 1 before reading any frames.',
      log: '[libsvtav1 @ 0000020f] Error setting preset 14: must be between -2 and 13\n[vost#0:0/libsvtav1] Error while opening encoder\nConversion failed!' },
    { id: 'j-1038', when: 'Oct 9, 18:30', project: 'Product demo.veg', template: 'ProRes 422 HQ for editing',
      output: 'E:\\Handoff\\Product demo.mov', status: 'succeeded', encoder: 'prores_ks + pcm_s24le', container: 'MOV',
      durationSec: 182, elapsedSec: 160, sizeBytes: 5.02e9, avgFps: 34.1, ffmpeg: 'FFmpeg 8.1 full', exit: 0 },
  ];

  // ------------------------------------------------------------------ macros
  const macros = [
    { name: '{inputs}', required: true, desc: 'VEGAS video and audio pipes, with their format, size and rate. Added by Vegas Encoder.' },
    { name: '{output}', required: true, desc: 'The file name chosen in Render As. Vegas Encoder writes to a temporary name and publishes on success.' },
    { name: '{v}', desc: 'The VEGAS video stream (0:v:0), for -map and filter graphs.' },
    { name: '{a}', desc: 'The VEGAS audio stream (1:a:0), when the render has audio.' },
    { name: '{width}', desc: 'Delivered frame width in pixels.' },
    { name: '{height}', desc: 'Delivered frame height in pixels.' },
    { name: '{fps}', desc: 'Delivered frame rate as a fraction, such as 30000/1001.' },
    { name: '{gop:2s}', desc: 'Frames in the given number of seconds at the delivered rate, such as 60.' },
    { name: '{sample_rate}', desc: 'Delivered audio sample rate.' },
    { name: '{project}', desc: 'VEGAS project file name without extension.' },
  ];

  /** Options valid for every encoder (AVCodecContext / ffmpeg tool), which `-h encoder=` does not list. */
  const genericOptions = {
    '-c': 'Codec for a stream', '-codec': 'Codec for a stream', '-b': 'Bitrate', '-maxrate': 'Maximum bitrate',
    '-minrate': 'Minimum bitrate', '-bufsize': 'Rate-control buffer size', '-g': 'Keyframe interval in frames',
    '-bf': 'Maximum B-frames', '-refs': 'Reference frames', '-pix_fmt': 'Output pixel format', '-profile': 'Codec profile',
    '-level': 'Codec level', '-r': 'Output frame rate', '-s': 'Output frame size', '-vf': 'Video filter graph',
    '-af': 'Audio filter graph', '-filter_complex': 'Complex filter graph', '-ar': 'Audio sample rate', '-ac': 'Audio channels',
    '-map': 'Select a stream for the output', '-metadata': 'Set container or stream metadata', '-movflags': 'MP4/MOV muxer flags',
    '-tag': 'Codec tag (FourCC)', '-color_primaries': 'Color primaries tag', '-color_trc': 'Transfer characteristics tag',
    '-colorspace': 'Matrix coefficients tag', '-color_range': 'Color range tag', '-threads': 'Encoder threads',
    '-f': 'Container format', '-t': 'Stop after duration', '-shortest': 'Stop with the shortest stream', '-q': 'Fixed quality scale',
    '-qscale': 'Fixed quality scale', '-compression_level': 'Compression level', '-vn': 'No video', '-an': 'No audio',
    '-map_metadata': 'Copy metadata', '-fps_mode': 'Frame timing mode', '-strict': 'Allow experimental features',
    '-hide_banner': 'Hide the banner', '-loglevel': 'Log level', '-stats': 'Print progress', '-progress': 'Machine-readable progress',
    '-nostdin': 'Ignore console input', '-y': 'Overwrite output', '-n': 'Never overwrite', '-x264-params': 'x264 key=value list',
    '-x265-params': 'x265 key=value list', '-svtav1-params': 'SVT-AV1 key=value list', '-aspect': 'Display aspect ratio',
    '-sample_fmt': 'Audio sample format', '-channel_layout': 'Audio channel layout', '-disposition': 'Stream disposition',
    '-max_muxing_queue_size': 'Muxer queue size', '-write_tmcd': 'Write timecode track', '-timecode': 'Start timecode',
    '-vtag': 'Video codec tag', '-atag': 'Audio codec tag', '-crf': 'Constant rate factor', '-qp': 'Quantizer',
  };

  // ----------------------------------------------------------------- helpers
  function clone(x) { return JSON.parse(JSON.stringify(x)); }
  function fpsValue(f) { return f[0] / f[1]; }
  function fpsLabel(f) {
    const v = fpsValue(f);
    return (Math.abs(v - Math.round(v)) < 1e-6 ? String(Math.round(v)) : v.toFixed(3).replace(/0+$/, '')) + ' fps';
  }
  function fmtBytes(b) {
    if (!b) return '0 B';
    const u = ['B', 'KB', 'MB', 'GB', 'TB']; let i = 0;
    while (b >= 1000 && i < u.length - 1) { b /= 1000; i++; }
    return (b >= 100 ? b.toFixed(0) : b >= 10 ? b.toFixed(1) : b.toFixed(2)) + ' ' + u[i];
  }
  function fmtDuration(s) {
    s = Math.round(s); const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), x = s % 60;
    return (h ? h + ':' + String(m).padStart(2, '0') : String(m)) + ':' + String(x).padStart(2, '0');
  }
  function fmtRate(k) { return k >= 1000 ? (k / 1000).toFixed(k % 1000 ? 1 : 0) + ' Mb/s' : k + ' kb/s'; }
  function quoteArg(a) { return /[\s"]/.test(a) ? '"' + a.replace(/"/g, '\\"') + '"' : a; }
  function installation(id) { return installations.find((i) => i.id === id) || installations[0]; }
  function availability(encoderId, installationId) {
    const inst = installation(installationId);
    return inst.availability[encoderId] || { state: 'missing', reason: 'Not listed by this FFmpeg.' };
  }

  /** Resolve unset values to encoder defaults (structured mode). */
  function resolved(r) {
    const v = r.video, enc = videoEncoders[v.encoder];
    const a = r.audio, aenc = audioEncoders[a.encoder];
    const mode = enc.modes.includes(v.mode) ? v.mode : enc.modes[0];
    const depth = v.depth && enc.depths[v.depth] ? v.depth : enc.depthDef;
    let pixfmt = enc.depths[depth];
    if (enc.profileQuality && enc.profileQuality.pixfmt) pixfmt = enc.profileQuality.pixfmt[v.profile || enc.profileQuality.def];
    if (enc.id === 'prores_ks' && /^4444/.test(v.profile || '')) pixfmt = 'yuv444p10le';
    return {
      enc, aenc, mode, depth, pixfmt,
      quality: v.quality != null && enc.quality && v.quality >= enc.quality.min && v.quality <= enc.quality.max ? v.quality : enc.quality && enc.quality.def,
      speed: enc.speed && enc.speed.values.includes(v.speed) ? v.speed : enc.speed && enc.speed.def,
      tune: enc.tune && enc.tune.values.includes(v.tune) ? v.tune : null,
      profile: (enc.profile && enc.profile.values.includes(v.profile)) || (enc.profileQuality && enc.profileQuality.values.includes(v.profile)) ? v.profile
        : (enc.profile && enc.profile.def) || (enc.profileQuality && enc.profileQuality.def),
      options: Object.fromEntries(Object.entries(v.options || {}).filter(([k]) => {
        const known = root.VE_AVOPTIONS && root.VE_AVOPTIONS.encoders[enc.id];
        return !known || known.options.some((o) => o.name === k);
      })),
      amode: aenc.modes.includes(a.mode) ? a.mode : aenc.modes[0],
    };
  }

  // ----------------------------------------------------------------- compile
  /**
   * Compile a recipe into FFmpeg argv tokens for a delivered media context.
   * Each token: { text, role } with role one of
   *   exe | global | input | map | video | audio | mux | output | extra | macro
   * Input tokens are owned by Vegas Encoder and are never user-editable.
   */
  function compile(r, ctx) {
    ctx = ctx || sampleContext;
    const t = [];
    const push = (role, ...args) => args.forEach((text) => t.push({ text: String(text), role }));
    const fps = ctx.video.fps;
    const v = r.video, a = r.audio, c = containers[r.container.format];
    const res = resolved(r);

    push('exe', 'ffmpeg');
    push('global', '-hide_banner', '-nostdin', '-loglevel', 'info', '-stats_period', '0.5', '-progress', 'pipe:1');
    const inputs = inputTokens(ctx, a.enabled);
    if (r.command.mode === 'template') {
      return { tokens: t.concat(expandTemplate(r.command.template, ctx, inputs, r)), resolved: res };
    }
    inputs.forEach((x) => t.push(x));

    push('map', '-map', '0:v:0');
    if (a.enabled) push('map', '-map', '1:a:0');

    // Video. Tokens are collected per stream so Extra arguments can override them.
    const enc = res.enc;
    const streamStart = t.length;
    push('video', '-c:v', enc.id);
    if (enc.speed && res.speed) push('video', enc.speed.flag, res.speed);
    if (enc.id === 'libvpx-vp9') push('video', '-deadline', 'good', '-row-mt', '1');
    if (enc.tune && res.tune) push('video', enc.tune.flag, res.tune);
    switch (res.mode) {
      case 'crf':
        push('video', enc.quality.flag, res.quality);
        if (enc.id === 'libvpx-vp9') push('video', '-b:v', '0');
        break;
      case 'cq':
        if (enc.hw === 'NVIDIA') push('video', '-rc', 'vbr', '-cq', res.quality, '-b:v', '0');
        else push('video', enc.quality.flag, res.quality);
        break;
      case 'abr':
        if (enc.hw === 'NVIDIA') push('video', '-rc', 'vbr');
        push('video', '-b:v', v.bitrateK + 'k');
        if (v.maxrateK) push('video', '-maxrate', v.maxrateK + 'k', '-bufsize', (v.maxrateK * 2) + 'k');
        break;
      case 'cbr':
        if (enc.hw === 'NVIDIA') push('video', '-rc', 'cbr');
        push('video', '-b:v', v.bitrateK + 'k', '-minrate', v.bitrateK + 'k', '-maxrate', v.bitrateK + 'k', '-bufsize', (v.bitrateK * 2) + 'k');
        break;
      case 'cqp':
        if (enc.hw === 'NVIDIA') push('video', '-rc', 'constqp');
        push('video', '-qp', v.qp != null ? v.qp : enc.qp.def);
        break;
      case 'profile':
        push('video', '-profile:v', res.profile);
        if (enc.vendor) push('video', '-vendor', enc.vendor);
        break;
      case 'lossless':
        if (enc.fixedArgs) push('video', ...enc.fixedArgs);
        break;
    }
    if (enc.multipass && enc.multipass.values.includes(v.multipass)) push('video', enc.multipass.flag, v.multipass);
    if (enc.profile && res.profile && res.mode !== 'profile') push('video', enc.profile.flag, res.profile);
    push('video', '-pix_fmt', res.pixfmt);
    if (v.gopSec && !['profile', 'lossless'].includes(res.mode)) push('video', '-g', Math.round(v.gopSec * fpsValue(fps)));
    if (v.color === 'bt709') push('video', '-color_primaries', 'bt709', '-color_trc', 'bt709', '-colorspace', 'bt709', '-color_range', 'tv');
    if (enc.appleTag && (c.id === 'mp4' || c.id === 'mov')) push('video', '-tag:v', enc.appleTag);
    Object.entries(res.options).forEach(([k, val]) => push('video', '-' + k, val));
    if (v.extra) applyExtra(t, streamStart, tokenize(v.extra));

    // Audio
    if (a.enabled) {
      const aenc = res.aenc;
      const audioStart = t.length;
      push('audio', '-c:a', aenc.id);
      if (res.amode === 'bitrate') {
        push('audio', '-b:a', a.bitrateK + 'k');
        if (aenc.vbrMode) push('audio', '-vbr', aenc.vbrMode);
      } else if (res.amode === 'vbr') {
        push('audio', aenc.vbr.flag, a.vbr != null ? a.vbr : aenc.vbr.def);
      }
      if (aenc.level) push('audio', aenc.level.flag, a.level != null ? a.level : aenc.level.def);
      if (a.sampleRate !== 'source') push('audio', '-ar', a.sampleRate);
      if (a.channels !== 'source') push('audio', '-ac', a.channels === 'mono' ? 1 : 2);
      Object.entries(a.options || {}).forEach(([k, val]) => push('audio', '-' + k, val));
      if (a.extra) applyExtra(t, audioStart, tokenize(a.extra));
    }

    // Container and output
    if (c.id === 'mp4' && r.container.faststart) push('mux', '-movflags', '+faststart');
    push('mux', '-f', c.muxer);
    push('output', outputPath(r, ctx));
    return { tokens: t, resolved: res };
  }

  const isOption = (x) => /^-[A-Za-z_]/.test(x);

  /**
   * Extra arguments override generated options of the same name in the same stream
   * (StaxRip's "Custom" rule) instead of duplicating them: `-preset slower` typed as
   * an extra replaces the generated `-preset slow`. Overridden tokens are removed and
   * the user's tokens appended with role 'extra'.
   */
  function applyExtra(t, start, extra) {
    const names = new Set(extra.filter(isOption));
    names.delete('-c:v'); names.delete('-c:a');  // the encoder itself is chosen by the picker
    for (let i = start; i < t.length; i++) {
      if (!names.has(t[i].text)) continue;
      const hasValue = i + 1 < t.length && !isOption(t[i + 1].text);
      t.splice(i, hasValue ? 2 : 1);
      i--;
    }
    extra.forEach((x) => t.push({ text: x, role: 'extra' }));
  }

  /** Split a user-typed argument string like a Windows shell would (quotes group). */
  function tokenize(s) {
    const out = []; let cur = ''; let q = false; let any = false;
    for (let i = 0; i < s.length; i++) {
      const ch = s[i];
      if (ch === '"') { q = !q; any = true; continue; }
      if (!q && /\s/.test(ch)) { if (any || cur) out.push(cur); cur = ''; any = false; continue; }
      cur += ch; any = true;
    }
    if (any || cur) out.push(cur);
    return out;
  }

  /** Same as tokenize, but keeps source offsets for highlighting and lint ranges. */
  function tokenizeWithRanges(s) {
    const out = []; let i = 0;
    while (i < s.length) {
      while (i < s.length && /\s/.test(s[i])) i++;
      if (i >= s.length) break;
      const start = i; let text = ''; let q = false;
      while (i < s.length && (q || !/\s/.test(s[i]))) {
        if (s[i] === '"') q = !q; else text += s[i];
        i++;
      }
      out.push({ text, start, end: i });
    }
    return out;
  }

  /** The product-owned pipe inputs: never user-editable, always generated. */
  function inputTokens(ctx, withAudio) {
    const fps = ctx.video.fps, t = [];
    const add = (...args) => args.forEach((text) => t.push({ text: String(text), role: 'input' }));
    add('-f', 'rawvideo', '-pix_fmt', ctx.video.pixfmt, '-s', `${ctx.video.width}x${ctx.video.height}`,
      '-r', `${fps[0]}/${fps[1]}`, '-thread_queue_size', '64', '-i', `\\\\.\\pipe\\vegas-encoder-${ctx.pipeId}-video`);
    if (withAudio) add('-f', ctx.audio.sampleFmt, '-ar', ctx.audio.rate, '-ac', ctx.audio.channels,
      '-thread_queue_size', '64', '-i', `\\\\.\\pipe\\vegas-encoder-${ctx.pipeId}-audio`);
    return t;
  }

  const productGlobals = ['-hide_banner', '-nostdin'];

  /** VEGAS chooses the file name; the extension follows the recipe's container. */
  function outputPath(r, ctx) {
    const p = ctx.output || vegas.output;
    return p.replace(/\.[A-Za-z0-9]+$/, containers[r.container.format].ext);
  }

  function expandTemplate(tpl, ctx, inputs, r) {
    const fps = ctx.video.fps;
    const toks = tokenize(tpl.replace(/\s*\\\n/g, ' '));
    const out = [];
    toks.forEach((tok, idx) => {
      if (idx === 0 && /ffmpeg(\.exe)?$/i.test(tok)) return;  // the executable comes from machine settings
      if (tok === '{inputs}') { inputs.forEach((x) => out.push(x)); return; }
      if (tok === '{output}') { out.push({ text: outputPath(r, ctx), role: 'output' }); return; }
      if (productGlobals.includes(tok)) return;  // already supplied by Vegas Encoder
      let text = tok
        .replace(/\{v\}/g, '0:v:0').replace(/\{a\}/g, '1:a:0')
        .replace(/\{width\}/g, ctx.video.width).replace(/\{height\}/g, ctx.video.height)
        .replace(/\{fps\}/g, `${fps[0]}/${fps[1]}`).replace(/\{sample_rate\}/g, ctx.audio.rate)
        .replace(/\{gop:(\d+(?:\.\d+)?)s\}/g, (_, s) => Math.round(parseFloat(s) * fpsValue(fps)))
        .replace(/\{project\}/g, (vegas.project || '').replace(/\.veg$/, ''));
      out.push({ text, role: 'extra' });
    });
    return out;
  }

  /** Command as display text. `multiline` puts each logical group on its own line. */
  function commandText(tokens, opts) {
    opts = opts || {};
    if (!opts.multiline) return tokens.map((x) => quoteArg(x.text)).join(' ');
    const breakBefore = ['-c:v', '-c:a', '-codec:v', '-codec:a', '-vcodec', '-acodec', '-filter_complex', '-vf', '-af',
      '-x264-params', '-x265-params', '-svtav1-params', '-movflags', '-metadata'];
    const lines = []; let line = []; let role = null; let prevText = '';
    tokens.forEach((x, i) => {
      const newGroup = i > 0 && x.role !== role && !(x.role === 'extra' && role !== 'input' && role !== 'global');
      const newInput = x.role === 'input' && x.text === '-f' && line.length && role === 'input';
      const firstMap = x.text === '-map' && prevText !== '-map' && !(line.length && line[0] === '-map');
      const keyword = breakBefore.includes(x.text) || firstMap || (x.role === 'output' && i > 0) || (x.role === 'mux' && role !== 'mux');
      if ((newGroup || newInput || keyword) && line.length) { lines.push(line); line = []; }
      line.push(quoteArg(x.text)); role = x.role; prevText = x.text;
    });
    if (line.length) lines.push(line);
    const cont = opts.continuation === undefined ? ' ^' : opts.continuation;
    return lines.map((l, i) => (i ? '  ' : '') + l.join(' ')).join(cont + '\n');
  }

  // ---------------------------------------------------------------- validate
  /**
   * Validation messages for the structured editor.
   * level: 'error' blocks Apply; 'warn' allows it; 'info' explains a consequence.
   * field: which control the message belongs to.
   */
  function validate(r, installationId, ctx) {
    ctx = ctx || sampleContext;
    const out = [];
    const msg = (level, field, text, fix) => out.push({ level, field, text, fix });
    const res = resolved(r);
    const v = r.video, a = r.audio, c = containers[r.container.format];
    const inst = installation(installationId);

    if (!v.enabled && !a.enabled) msg('error', 'streams', 'Turn on video, audio, or both.');
    if (!v.enabled && a.enabled) msg('error', 'video', 'Audio-only renders aren’t supported yet. Turn video back on.');

    if (r.command.mode === 'template') return out.concat(lint(r.command.template, inst.id).filter((d) => d.level !== 'hint'));

    if (v.enabled) {
      const av = availability(v.encoder, inst.id);
      if (av.state === 'missing') msg('error', 'video.encoder', `${res.enc.label} isn’t in ${inst.label}. ${av.reason}`, 'Choose another encoder, or switch FFmpeg on the FFmpeg page.');
      if (av.state === 'failed') msg('error', 'video.encoder', `${res.enc.label} is listed by ${inst.label} but failed its test encode on this PC. ${av.reason}`, 'Choose another encoder, or re-test after fixing the driver.');
      const cv = compat.video[res.enc.family][c.id];
      if (cv === 'no') msg('error', 'container', `${c.label} can’t hold ${res.enc.codec} video.`, `Use ${Object.keys(compat.video[res.enc.family]).filter((k) => compat.video[res.enc.family][k] === 'ok').map((k) => containers[k].label).join(' or ')}.`);
      if (cv === 'warn') msg('warn', 'container', `${res.enc.codec} in ${c.label} works in FFmpeg but many players won’t open it.`);
      const inDepth = /10|16/.test(ctx.video.pixfmt) ? 10 : 8;
      if (res.depth < inDepth) msg('info', 'video.depth', 'VEGAS delivers 10-bit frames. This encode stores 8-bit, which can show banding in smooth gradients.');
      if (res.enc.chroma === '4:2:2' || /444/.test(res.pixfmt)) msg('info', 'video.depth', `${res.enc.codec} stores ${/444/.test(res.pixfmt) ? '4:4:4' : '4:2:2'} color. VEGAS delivers 4:2:0, so the extra color resolution is interpolated, not recovered.`);
      if (res.enc.id === 'libx264' && res.depth === 10) msg('warn', 'video.depth', '10-bit H.264 doesn’t play on most phones, browsers or TVs.');
      if (res.mode === 'cbr' && c.id === 'mp4' && res.enc.id === 'libx264') msg('info', 'video.mode', 'x264 can’t write strict CBR signalling into MP4. The bitrate is still held constant.');
      if (v.gopSec && v.gopSec > 10) msg('warn', 'video.gop', 'Keyframes more than 10 seconds apart make seeking slow.');
      if (res.enc.hw && av.state === 'ok') msg('info', 'video.encoder', `Runs on ${av.note || res.enc.hw}.`);
    }
    if (a.enabled) {
      const av = availability(a.encoder, inst.id);
      if (av.state !== 'ok') msg('error', 'audio.encoder', `${res.aenc.label} isn’t usable with ${inst.label}. ${av.reason}`, 'Choose AAC or Opus instead.');
      const ca = compat.audio[res.aenc.family][c.id];
      if (ca === 'no') msg('error', 'container', `${c.label} can’t hold ${res.aenc.codec} audio.`);
      if (ca === 'warn') msg('warn', 'audio.encoder', `${res.aenc.codec} audio in ${c.label} muxes, but many players won’t play it. AAC is the safe choice for ${c.label}.`);
      const rate = a.sampleRate === 'source' ? ctx.audio.rate : a.sampleRate;
      if (res.aenc.rates && !res.aenc.rates.includes(rate)) msg('error', 'audio.sampleRate', `${res.aenc.label} doesn’t support ${rate / 1000} kHz. Use ${res.aenc.rates.map((x) => x / 1000 + ' kHz').join(' or ')}.`);
    }
    if (c.id === 'mp4' && r.container.faststart) msg('info', 'container', 'Fast start rewrites the file once encoding ends so playback can begin before download finishes. Large renders take a little longer to finish.');
    return out;
  }

  // -------------------------------------------------------------------- lint
  /**
   * Lint an advanced-mode command template.
   * Returns diagnostics: { level: 'error'|'warn'|'hint', start, end, text }.
   * With an installation id, encoders are also checked against that FFmpeg.
   */
  function lint(tpl, installationId) {
    const d = [];
    const toks = tokenizeWithRanges(tpl);
    const has = (m) => toks.some((x) => x.text === m);
    if (!has('{inputs}')) d.push({ level: 'error', start: 0, end: 0, text: 'Add {inputs}. Vegas Encoder needs it to connect the VEGAS video and audio pipes.' });
    if (!has('{output}')) d.push({ level: 'error', start: tpl.length, end: tpl.length, text: 'Add {output} where the output file goes, usually at the end.' });
    const encoders = {};
    toks.forEach((x, i) => {
      const next = toks[i + 1];
      if (/^-(c|codec):v$|^-vcodec$/.test(x.text) && next) encoders.v = next.text;
      if (/^-(c|codec):a$|^-acodec$/.test(x.text) && next) encoders.a = next.text;
    });
    const av = root.VE_AVOPTIONS ? root.VE_AVOPTIONS.encoders : {};
    const known = (name) => {
      const base = name.replace(/^-/, '').split(':')[0];
      if (genericOptions['-' + base]) return true;
      return ['v', 'a'].some((k) => encoders[k] && av[encoders[k]] && av[encoders[k]].options.some((o) => o.name === base));
    };
    toks.forEach((x, i) => {
      const next = toks[i + 1];
      if (x.text === '-i') d.push({ level: 'warn', start: x.start, end: (next || x).end, text: 'Extra inputs are allowed, but VEGAS media always comes from {inputs}. Inputs you add here start at index 2.' });
      if (productGlobals.includes(x.text)) d.push({ level: 'hint', start: x.start, end: x.end, text: `${x.text} is always added by Vegas Encoder.` });
      if (x.text === '-y' || x.text === '-n') d.push({ level: 'hint', start: x.start, end: x.end, text: 'Not needed. Vegas Encoder writes to a temporary file and handles overwrite itself.' });
      if (/^-/.test(x.text) && !/^-?\d/.test(x.text) && x.text.length > 1 && !known(x.text) && x.text !== '-i')
        d.push({ level: 'warn', start: x.start, end: x.end, text: `${x.text} isn’t a known option for ${encoders.v || 'the selected encoders'} in FFmpeg 8.1.` });
      if (/^-(c|codec):[va]$/.test(x.text) && next) {
        if (installationId) {
          const state = availability(next.text, installationId);
          const label = installation(installationId).label;
          if (state.state === 'missing') d.push({ level: 'error', start: next.start, end: next.end, text: `${next.text} isn’t in ${label}. ${state.reason}` });
          else if (state.state === 'failed') d.push({ level: 'error', start: next.start, end: next.end, text: `${next.text} failed its test encode on this PC. ${state.reason}` });
        } else if (!videoEncoders[next.text] && !audioEncoders[next.text] && !av[next.text]) {
          d.push({ level: 'warn', start: next.start, end: next.end, text: `${next.text} isn’t in the selected FFmpeg’s encoder list.` });
        }
      }
      const paramsOwner = { '-x264-params': 'libx264', '-x265-params': 'libx265', '-svtav1-params': 'libsvtav1' }[x.text];
      if (paramsOwner && encoders.v && encoders.v !== paramsOwner)
        d.push({ level: 'warn', start: x.start, end: x.end, text: `${x.text} only applies to ${paramsOwner}; this command encodes with ${encoders.v}.` });
      if (x.text === '-preset' && next && encoders.v) {
        const enc = videoEncoders[encoders.v];
        if (enc && enc.speed && !enc.speed.values.includes(next.text))
          d.push({ level: 'error', start: next.start, end: next.end, text: `${next.text} isn’t a preset for ${encoders.v}. Use ${enc.speed.values[0]}–${enc.speed.values[enc.speed.values.length - 1]}.` });
      }
    });
    return d;
  }

  /** Autocomplete suggestions for the advanced editor: options or values. */
  function complete(tpl, caret) {
    const before = tpl.slice(0, caret);
    const toks = tokenize(before);
    const endsWithSpace = /\s$/.test(before);
    const prev = endsWithSpace ? toks[toks.length - 1] : toks[toks.length - 2];
    const partial = endsWithSpace ? '' : (toks[toks.length - 1] || '');
    const encV = (before.match(/-c(?:odec)?:v\s+(\S+)/) || [])[1];
    const av = root.VE_AVOPTIONS ? root.VE_AVOPTIONS.encoders : {};
    if (prev && /^-/.test(prev) && !partial.startsWith('-')) {
      const name = prev.replace(/^-/, '').split(':')[0];
      if (/^(c|codec)$/.test(name)) {
        const list = Object.values(videoEncoders).map((e) => ({ value: e.id, desc: `${e.codec}${e.hw ? ', ' + e.hw + ' GPU' : ''}` }))
          .concat(Object.values(audioEncoders).map((e) => ({ value: e.id, desc: e.codec + ' audio' })));
        return { kind: 'value', of: prev, items: list.filter((x) => x.value.startsWith(partial)) };
      }
      const enc = encV && videoEncoders[encV];
      if (name === 'preset' && enc && enc.speed) return { kind: 'value', of: prev, items: enc.speed.values.map((x) => ({ value: x, desc: enc.speed.names ? enc.speed.names[x] : '' })).filter((x) => x.value.startsWith(partial)) };
      const curated = enc && ({ tune: enc.tune, profile: enc.profile || enc.profileQuality, multipass: enc.multipass })[name];
      const o = encV && av[encV] && av[encV].options.find((x) => x.name === name);
      if ((!o || !o.consts) && curated && curated.values)
        return { kind: 'value', of: prev, items: curated.values.map((x) => ({ value: x, desc: curated.names ? curated.names[x] : '' })).filter((x) => x.value.startsWith(partial)) };
      if (o && o.consts) return { kind: 'value', of: prev, items: o.consts.map((cst) => ({ value: cst.name, desc: cst.desc })).filter((x) => x.value.startsWith(partial)) };
      return { kind: 'none', items: [] };
    }
    const opts = (encV && av[encV] ? av[encV].options.map((o) => ({ value: '-' + o.name, desc: o.desc, type: o.type, def: o.default, source: encV })) : [])
      .concat(Object.entries(genericOptions).map(([k, desc]) => ({ value: k, desc, source: 'FFmpeg' })));
    return { kind: 'option', items: opts.filter((x) => x.value.startsWith(partial || '-')).slice(0, 40) };
  }

  // ---------------------------------------------------------------- estimate
  /**
   * Size estimate. Exact-ish for bitrate modes; a rough guide for quality modes.
   * Returns { videoKbps, audioKbps, bytes, approx, label }.
   */
  function estimate(r, ctx) {
    ctx = ctx || sampleContext;
    if (r.command.mode === 'template')
      return { videoKbps: 0, audioKbps: 0, bytes: 0, approx: true, custom: true, label: 'No size estimate for a custom command' };
    const res = resolved(r);
    const mpix = (ctx.video.width * ctx.video.height) / 1e6;
    const fps = fpsValue(ctx.video.fps);
    let vk = 0, approx = false;
    if (r.video.enabled) {
      if (res.mode === 'abr' || res.mode === 'cbr') vk = r.video.bitrateK;
      else if (res.mode === 'profile') {
        const pq = res.enc.profileQuality; vk = pq.mbps1080[res.profile] * 1000 * (mpix / 2.0736) * (fps / 29.97); approx = true;
      } else if (res.mode === 'lossless') { vk = res.enc.mbpsPerMpix * 1000 * mpix * (fps / 29.97); approx = true; }
      else {
        // Rough bits-per-pixel model: each 6 quality steps roughly halves the rate.
        const enc = res.enc;
        const q = res.mode === 'cqp' ? (r.video.qp != null ? r.video.qp : enc.qp ? enc.qp.def : res.quality) : res.quality;
        const efficiency = { h264: 1, hevc: 0.62, av1: 0.5, vp9: 0.6 }[enc.family] || 1;
        const hwPenalty = enc.hw ? 1.25 : 1;
        const pivot = enc.quality.max > 51 ? q * 51 / 63 : q;
        const bpp = 0.11 * Math.pow(2, (18 - pivot) / 6) * efficiency * hwPenalty;
        vk = bpp * mpix * 1e6 * fps / 1000; approx = true;
      }
    }
    let ak = 0;
    if (r.audio.enabled) {
      const ae = res.aenc;
      if (res.amode === 'bitrate') ak = r.audio.bitrateK;
      else if (ae.family === 'pcm' || ae.family === 'pcmf') ak = (ae.bits || 24) * ctx.audio.rate * ctx.audio.channels / 1000;
      else { ak = 0.55 * 24 * ctx.audio.rate * ctx.audio.channels / 1000; approx = true; }
    }
    const bytes = (vk + ak) * 1000 / 8 * ctx.durationSec;
    return { videoKbps: Math.round(vk), audioKbps: Math.round(ak), bytes, approx,
      label: (approx ? 'About ' : '') + fmtBytes(bytes) + ' for ' + fmtDuration(ctx.durationSec) };
  }

  /** Short human summary fields (designs decide how to join them). */
  function summary(r) {
    const res = resolved(r);
    const v = r.video, a = r.audio;
    const qName = { '-crf': 'CRF', '-cq': 'CQ', '-global_quality': 'ICQ', '-qp_i': 'QP' }[res.enc.quality && res.enc.quality.flag] || 'Quality';
    const vq = res.mode === 'crf' || res.mode === 'cq' ? `${qName} ${res.quality}`
      : res.mode === 'abr' ? fmtRate(v.bitrateK) + ' average'
      : res.mode === 'cbr' ? fmtRate(v.bitrateK) + ' constant'
      : res.mode === 'cqp' ? 'QP ' + (v.qp != null ? v.qp : res.enc.qp.def)
      : res.mode === 'profile' ? res.enc.profileQuality.names[res.profile]
      : 'Lossless';
    const aq = !a.enabled ? 'No audio' : res.amode === 'bitrate' ? fmtRate(a.bitrateK) : res.amode === 'vbr' ? 'VBR ' + (a.vbr ?? res.aenc.vbr.def) : 'Lossless';
    return {
      container: containers[r.container.format].label,
      video: v.enabled ? res.enc.codec : 'No video',
      videoEncoder: v.enabled ? res.enc.label : null,
      videoQuality: vq,
      speed: res.enc.speed ? (res.enc.speed.names ? res.enc.speed.names[res.speed] : res.speed) : null,
      depth: res.depth + '-bit',
      audio: a.enabled ? res.aenc.label : 'No audio',
      audioQuality: aq,
      mode: rateModes[res.mode].label,
      command: r.command.mode === 'template',
    };
  }

  /** Field-level differences between two recipes (for "Update from library"). */
  function diff(a, b) {
    const out = [];
    const walk = (x, y, path) => {
      const keys = new Set(Object.keys(x || {}).concat(Object.keys(y || {})));
      keys.forEach((k) => {
        if (['id', 'revision', 'updated', 'builtin', 'favorite', 'name', 'tags', 'notes', 'category'].includes(k) && !path) return;
        const p = path ? path + '.' + k : k;
        const xv = x ? x[k] : undefined, yv = y ? y[k] : undefined;
        if (xv && typeof xv === 'object' && !Array.isArray(xv)) walk(xv, yv, p);
        else if (JSON.stringify(xv) !== JSON.stringify(yv)) out.push({ path: p, from: xv, to: yv });
      });
    };
    walk(a, b, '');
    return out;
  }

  /**
   * "Update from library" preview, three-way on field paths:
   * library = what changed in the preset since the template's origin revision,
   * mine = edits made in this template, conflicts = paths in both lists.
   */
  function updatePreview(session) {
    const library = diff(session.base, session.library);
    const mine = diff(session.base, session.recipe);
    const minePaths = new Set(mine.map((d) => d.path));
    const conflicts = library.filter((d) => minePaths.has(d.path)).map((d) => d.path);
    return { library, mine, conflicts, canMerge: conflicts.length === 0 };
  }

  const fieldLabels = {
    'video.encoder': 'Video encoder', 'video.mode': 'Rate control', 'video.quality': 'Quality', 'video.bitrateK': 'Bitrate',
    'video.maxrateK': 'Peak bitrate', 'video.speed': 'Encoder speed', 'video.tune': 'Tune', 'video.profile': 'Profile',
    'video.depth': 'Bit depth', 'video.gopSec': 'Keyframe interval', 'video.color': 'Color tags', 'video.extra': 'Extra video arguments',
    'audio.encoder': 'Audio encoder', 'audio.bitrateK': 'Audio bitrate', 'audio.sampleRate': 'Sample rate', 'audio.channels': 'Channels',
    'container.format': 'Container', 'container.faststart': 'Fast start', 'command.mode': 'Editing mode', 'command.template': 'Command',
  };

  root.VE = {
    vegas, sampleContext, installations, containers, compat, rateModes, videoEncoders, videoOrder,
    audioEncoders, audioOrder, library, categories, history, macros, genericOptions, fieldLabels,
    templateSession, clone, resolved, compile, inputTokens, commandText, tokenize, tokenizeWithRanges, validate, lint, complete,
    estimate, summary, diff, updatePreview, availability, installation, outputPath,
    fmt: { bytes: fmtBytes, duration: fmtDuration, rate: fmtRate, fps: fpsLabel },
  };
})(typeof window !== 'undefined' ? window : globalThis);
