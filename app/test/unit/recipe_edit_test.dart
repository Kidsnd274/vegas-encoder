import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart';
import 'package:vegas_encoder/state/presets.dart';
import 'package:vegas_encoder/state/recipe_edit.dart';

void main() {
  final core = FakeVeCore();
  final catalog = core.profiles();
  final yt = core.fixtures.firstWhere((f) => f.recipe.id == 'yt-h264').recipe;
  EncoderProfile video(String id) => catalog.video.firstWhere((e) => e.id == id);
  EncoderProfile audio(String id) => catalog.audio.firstWhere((e) => e.id == id);

  group('canonical comparison', () {
    test('key order, whole doubles and null entries do not count as changes', () {
      expect(canonicalJson({'b': 1, 'a': 18.0}), canonicalJson({'a': 18, 'b': 1}));
      expect(canonicalJson({'a': 1, 'tune': null}), canonicalJson({'a': 1}));
      expect(canonicalJson({'a': 17.5}), isNot(canonicalJson({'a': 17})));
    });

    test('editing a value back makes the recipe the same again', () {
      final edited = yt.withVideo((v) => v.copyWith(quality: 17));
      expect(sameRecipe(edited, yt), isFalse);
      expect(sameRecipe(edited.withVideo((v) => v.copyWith(quality: 18.0)), yt), isTrue);
    });

    test('jsonNumber writes whole numbers as integers', () {
      expect(jsonNumber(2.0), isA<int>());
      expect(jsonNumber(2.5), 2.5);
    });
  });

  group('encoder changes', () {
    test('a new video encoder starts from its defaults and keeps a mode it has', () {
      final nvenc = yt.withVideoEncoder('hevc_nvenc', video('hevc_nvenc')).video;
      expect(nvenc.encoder, 'hevc_nvenc');
      expect(nvenc.mode, isNull, reason: 'NVENC has cq, not crf: the core resolves its default');
      expect(nvenc.quality, isNull);
      expect(nvenc.speed, isNull);
      expect(nvenc.profile, isNull);
      expect(nvenc.depth, 8, reason: 'NVENC HEVC has 8-bit, so the depth stays');
      expect(nvenc.gopSec, 2);
      expect(nvenc.color, 'bt709');

      final x265 = yt.withVideoEncoder('libx265', video('libx265')).video;
      expect(x265.mode, 'crf', reason: 'x265 has crf');
      final prores = yt.withVideoEncoder('prores_ks', video('prores_ks')).video;
      expect(prores.depth, isNull, reason: 'ProRes has no 8-bit');
    });

    test('a new audio encoder keeps a bitrate and sample rate it offers', () {
      final withRate = yt.withAudio((a) => a.copyWith(sampleRate: 44100));
      final opus = withRate.withAudioEncoder('libopus', audio('libopus')).audioTrack;
      expect(opus.bitrateK, 320, reason: 'Opus offers 320');
      expect(opus.sampleRate, 'source', reason: 'Opus offers only 48 kHz');
      final flac = yt.withAudioEncoder('flac', audio('flac')).audioTrack;
      expect(flac.mode, isNull);
      expect(flac.bitrateK, isNull);
    });
  });

  group('field paths', () {
    test('read, compare and reset by the core\'s field paths', () {
      final edited = yt.withAudio((a) => a.copyWith(bitrateK: 256)).withVideo((v) => v.copyWith(tune: 'film'));
      expect(readPath(edited.toJson(), 'audio[0].bitrateK').value, 256);
      expect(readPath(edited.toJson(), 'video.nothing').present, isFalse);
      expect(fieldDiffers(edited, yt, 'audio[0].bitrateK'), isTrue);
      expect(fieldDiffers(edited, yt, 'video.quality'), isFalse);

      final back = resetField(resetField(edited, yt, 'audio[0].bitrateK'), yt, 'video.tune');
      expect(sameRecipe(back, yt), isTrue);
      expect(back.toJson()['video'], isNot(contains('multipass')), reason: 'absent keys stay absent');
    });
  });

  group('names and IDs for new presets', () {
    test('copies get a unique name and a valid, unique ID', () {
      expect(copyName('YouTube upload, H.264', {}), 'YouTube upload, H.264 (copy)');
      expect(copyName('YouTube upload, H.264', {'YouTube upload, H.264 (copy)'}), 'YouTube upload, H.264 (copy 2)');
      expect(uniqueId('YouTube upload, H.264 (copy)', {}), 'youtube-upload-h-264-copy');
      expect(uniqueId('YouTube upload, H.264 (copy)', {'youtube-upload-h-264-copy'}), 'youtube-upload-h-264-copy-2');
      expect(uniqueId('!!!', {}), 'preset');
      expect(RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(uniqueId('  Ünïcode préset  ', {})), isTrue);
    });
  });
}
