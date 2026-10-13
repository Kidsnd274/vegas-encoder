import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart';
import 'package:vegas_encoder/features/presets/display.dart';
import 'package:vegas_encoder/state/editor.dart';

/// How the app maps the core's results (B2): the keyframes read-out from
/// `ResolvedSettings.gopFrames`, and `CoreResult` keeping native failures.
void main() {
  MediaDescription media(List<int> fps) => MediaDescription.fromJson({
    'video': {'width': 1920, 'height': 1080, 'fps': fps, 'pixfmt': 'p010le', 'sar': '1:1'},
    'audio': {'rate': 48000, 'channels': 2, 'sampleFmt': 'f32le'},
    'durationSec': null,
  });
  final ntsc = media([30000, 1001]);

  group('keyframesReadout', () {
    test('typed seconds: the seconds, then the core\'s frames at the delivered rate', () {
      final r = keyframesReadout(gopFrames: 60, gopSec: 2, overridden: false, media: ntsc);
      expect(r, isNotNull);
      expect(r!.value, '2 s');
      expect(r.meaning, ' (60 frames at 29.97 fps)');
    });

    test('Extra arguments set the interval: frames only, the typed seconds left out', () {
      final r = keyframesReadout(gopFrames: 120, gopSec: 2, overridden: true, media: ntsc)!;
      expect(r.value, '120 frames');
      expect(r.meaning, ' at 29.97 fps');
    });

    test('no seconds typed: frames only', () {
      final r = keyframesReadout(gopFrames: 250, gopSec: null, overridden: false, media: ntsc)!;
      expect(r.value, '250 frames');
      expect(r.meaning, ' at 29.97 fps');
    });

    test('one frame is singular; large counts get separators', () {
      expect(keyframesReadout(gopFrames: 1, gopSec: null, overridden: false, media: ntsc)!.value, '1 frame');
      expect(keyframesReadout(gopFrames: 1200, gopSec: null, overridden: true, media: ntsc)!.value, '1,200 frames');
    });

    test('no interval from the core: no read-out', () {
      expect(keyframesReadout(gopFrames: null, gopSec: 2, overridden: false, media: ntsc), isNull);
      expect(keyframesReadout(gopFrames: null, gopSec: null, overridden: true, media: ntsc), isNull);
    });

    test('a whole frame rate reads without decimals', () {
      final r = keyframesReadout(gopFrames: 50, gopSec: 2, overridden: false, media: media([25, 1]))!;
      expect(r.value, '2 s');
      expect(r.meaning, ' (50 frames at 25 fps)');
      expect(
        keyframesReadout(gopFrames: 50, gopSec: null, overridden: false, media: media([25, 1]))!.meaning,
        ' at 25 fps',
      );
    });

    test('decimal seconds keep their fraction', () {
      final r = keyframesReadout(gopFrames: 15, gopSec: 0.5, overridden: false, media: ntsc)!;
      expect(r.value, '0.5 s');
      expect(r.meaning, ' (15 frames at 29.97 fps)');
    });
  });

  group('CoreResult', () {
    test('a result is kept', () {
      final r = CoreResult.run(() => 42);
      expect(r.ok, isTrue);
      expect(r.value, 42);
      expect(r.error, isNull);
      expect(r.notInPreviewCore, isFalse);
    });

    test('the fake core\'s missing fixture gets its own notice', () {
      const e = CoreException('B0-FIXTURE-MISSING', 'No fixture for this recipe.');
      final r = CoreResult.run<int>(() => throw e);
      expect(r.ok, isFalse);
      expect(r.value, isNull);
      expect(r.error, same(e));
      expect(r.notInPreviewCore, isTrue);
    });

    test('a native failure stays a failure, with its code and message', () {
      for (final code in ['JSON-LIMIT', 'NATIVE-LOAD', 'ABI-MISMATCH']) {
        final e = CoreException(code, 'The request is larger than 1 MiB.');
        final r = CoreResult.run<int>(() => throw e);
        expect(r.ok, isFalse, reason: code);
        expect(r.value, isNull, reason: code);
        expect(r.error, same(e), reason: code);
        expect(r.error!.code, code);
        expect(r.error!.message, 'The request is larger than 1 MiB.');
        expect(r.notInPreviewCore, isFalse, reason: '$code is not the preview core\'s gap');
      }
    });

    test('other exceptions are not swallowed', () {
      expect(() => CoreResult.run<int>(() => throw StateError('bug')), throwsStateError);
    });
  });
}
