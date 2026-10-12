import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart';
import 'package:vegas_encoder/design/components/command_view.dart' show CommandRole;
import 'package:vegas_encoder/design/components/message.dart';
import 'package:vegas_encoder/design/components/signal_path/signal_path_model.dart';
import 'package:vegas_encoder/design/components/status.dart';
import 'package:vegas_encoder/features/presets/display.dart';
import 'package:vegas_encoder/features/presets/library_model.dart';
import 'package:vegas_encoder/state/presets.dart';
import 'package:vegas_encoder/state/recipe_edit.dart';

void main() {
  final core = FakeVeCore();
  final catalog = core.profiles();
  CoreFixture fixture(String id) => core.fixtures.firstWhere((f) => f.recipe.id == id);
  final installations = FakeMachineSettingsRepository();
  late List<FFmpegInstallation> inst;
  setUpAll(() async => inst = (await installations.read()).installations);
  FFmpegInstallation installation(String id) => inst.firstWhere((i) => i.id == id);

  group('command', () {
    test('groups the core\'s tokens: inputs chip, -map on the program line, one line per stage', () {
      final f = fixture('yt-h264');
      final d = commandDisplay(f.compiled, audio: true);
      expect(d.program, 'ffmpeg');
      expect(d.inputsLabel, 'VEGAS video + audio');
      expect(d.inputs.map((t) => t.text), containsAllInOrder(['-hide_banner', '-f', 'rawvideo', '-i']));
      expect(d.lines.map((l) => l.role), [
        CommandRole.inputs,
        CommandRole.video,
        CommandRole.audio,
        CommandRole.mux,
        CommandRole.output,
      ]);
      expect(d.lines.first.tokens.map((t) => t.text), ['-map', '0:v:0', '-map', '1:a:0']);
      expect(d.lines.last.tokens.single.text, r'"D:\Renders\Sample project.mp4"', reason: 'quoted for display');
      expect(d.copyText, f.compiled.commandLine, reason: 'Copy is the core\'s command line');
    });
  });

  group('signal path', () {
    test('built from the compile result: conversion, depths, labels and readiness', () {
      final f = fixture('yt-h264');
      final m = signalPathModel(
        recipe: f.recipe,
        catalog: catalog,
        media: f.media,
        compiled: f.compiled,
        installation: installation('gyan-8.1'),
        lengthSec: 600,
      );
      expect(m.source.frameSize, '1920×1080');
      expect(m.source.frameRate, '29.97 fps');
      expect(m.source.pixelFormat, 'P010, 10-bit 4:2:0');
      expect(m.source.depth, 10);
      expect(m.video!.encoder, 'x264');
      expect(m.video!.detail, 'CRF 18, slow');
      expect(m.video!.outputBits, 8);
      expect(m.video!.conversion!.label, 'p010le to yuv420p');
      expect(m.video!.conversion!.note, 'Precision lost', reason: 'from the core\'s V-DEPTH-DOWN issue');
      expect(m.video!.availability, VeAvailability.ready);
      expect(m.audio!.detail, '320 kb/s');
      expect(m.container.label, 'MP4');
      expect(m.container.detail, 'Fast start');
      expect(m.fileName, 'Sample project.mp4');
      expect(m.contextLabel, 'Preview with: 1920×1080, 29.97 fps, 48 kHz stereo, 10 minutes');
    });

    test('a 10-bit encode that keeps the pixel format has no pip', () {
      final f = fixture('yt-hevc-nv');
      final m = signalPathModel(recipe: f.recipe, catalog: catalog, media: f.media, compiled: f.compiled);
      expect(m.video!.conversion, isNull);
      expect(m.video!.outputBits, 10);
      expect(m.video!.runsOn, 'NVIDIA GPU');
    });

    test('without a compile result the recipe and catalog still draw the path', () {
      final f = fixture('yt-h264');
      final edited = f.recipe.withVideo((v) => v.copyWith(quality: 17));
      final m = signalPathModel(recipe: edited, catalog: catalog, media: f.media);
      expect(m.video!.detail, 'CRF 17, slow');
      expect(m.video!.conversion, isNull, reason: 'conversions come only from the core');
      expect(m.audio!.detail, '320 kb/s');
    });

    test('an encoder missing from the chosen FFmpeg turns its node red', () {
      final f = fixture('yt-h264');
      final m = signalPathModel(
        recipe: f.recipe,
        catalog: catalog,
        media: f.media,
        compiled: f.compiled,
        installation: installation('btbn-lgpl-8.0'),
      );
      expect(m.video!.availability, VeAvailability.missing);
    });

    test('the codec-to-container table marks a stream the container cannot hold', () {
      final f = fixture('yt-h264');
      final webm = f.recipe.withContainer((c) => c.copyWith(format: 'webm'));
      final m = signalPathModel(recipe: webm, catalog: catalog, media: f.media);
      expect(m.video!.muxProblem, isTrue);
      expect(m.audio!.muxProblem, isTrue);
      expect(m.containerProblem, isTrue);
    });
  });

  group('checks and vocabulary', () {
    test('issue levels and the node that holds a field', () {
      expect(levelOf(IssueLevel.warn), VeLevel.warning);
      expect(nodeForField('video.depth'), SignalNode.video);
      expect(nodeForField('audio[0].bitrateK'), SignalNode.audio);
      expect(nodeForField('container'), SignalNode.container);
      expect(nodeForField(''), isNull);
      expect(categoryLabel('edit'), 'Editing intermediate');
      expect(categoryLabel('unknown'), 'Other');
    });

    test('encoder pickers follow the catalog\'s order and the installation\'s availability', () {
      final groups = encoderGroups(catalog, video: true, installation: installation('btbn-lgpl-8.0'));
      expect(groups.map((g) => g.name).first, 'H.264');
      final x264 = groups.first.encoders.first;
      expect(x264.label, 'x264');
      expect(x264.detail, 'H.264, CPU, 10-bit');
      expect(x264.availability, VeAvailability.missing);
      expect(x264.reason, contains('LGPL'));
      final audio = encoderGroups(catalog, video: false);
      expect(audio.first.name, 'Lossy audio');
    });
  });

  group('library', () {
    late List<Preset> presets;
    setUpAll(() async => presets = await FakePresetLibrary().list());

    List<LibraryEntry> entries({FFmpegInstallation? on}) => [
      for (final p in presets)
        libraryEntry(
          p,
          recipe: p.recipe,
          favorite: p.favorite,
          dirty: false,
          compiled: fixture(p.recipe.id).compiled,
          catalog: catalog,
          installation: on,
        ),
    ];

    test('rows read the core\'s summary and output depth', () {
      final e = entries().firstWhere((e) => e.id == 'yt-h264');
      expect(e.line, 'x264 CRF 18, AAC');
      expect(e.depth, 8);
      expect(e.problem, isNull);
    });

    test('a preset whose encoder is missing says what it needs', () {
      final e = entries(on: installation('btbn-lgpl-8.0')).firstWhere((e) => e.id == 'yt-h264');
      expect(e.line, 'Needs x264: not in this FFmpeg');
      expect(e.problemDetail, contains('LGPL'));
    });

    test('Built-in then Mine; favorites first, then categories in order, then names', () {
      final groups = groupLibrary(entries());
      expect(groups.map((g) => g.title), ['Built-in']);
      expect(groups.first.subgroups.map((s) => s.title), [
        'Favorites',
        'Web upload',
        'Editing intermediate',
        'Master and archive',
      ]);
      expect(groups.first.subgroups[1].entries.map((e) => e.name), [
        'Small web file, AV1',
        'YouTube upload, HEVC on GPU',
      ]);
    });

    test('search matches names, tags and encoders; filters narrow the list', () {
      String names(List<LibraryGroup> g) =>
          g.expand((g) => g.subgroups).expand((s) => s.entries).map((e) => e.id).join(',');
      expect(names(groupLibrary(entries(), query: 'nvenc')), 'yt-hevc-nv');
      expect(names(groupLibrary(entries(), query: 'resolve')), 'prores-hq', reason: 'tag');
      expect(names(groupLibrary(entries(), query: 'pcm_s16le')), 'dnxhr-hq', reason: 'audio encoder');
      expect(groupLibrary(entries(), filter: LibraryFilter.mine), isEmpty);
      expect(names(groupLibrary(entries(), favoritesOnly: true)), 'yt-h264');
    });
  });
}
