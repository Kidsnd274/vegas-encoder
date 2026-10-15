import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart';
import 'package:vegas_encoder/design/components/wire_progress.dart';
import 'package:vegas_encoder/features/monitor/display.dart';
import 'package:vegas_encoder/state/monitor.dart';

import '../monitor_doubles.dart';

/// F6: how the progress window words the live status (C5) and the job
/// record (C6). Display only: every figure is one the engine wrote.
void main() {
  final encoding = liveSample(RenderState.encoding);

  group('paths', () {
    test('file name and folder from a Windows path', () {
      expect(fileNameOf(r'D:\Renders\Lakeside wedding final.mp4'), 'Lakeside wedding final.mp4');
      expect(folderOf(r'D:\Renders\Lakeside wedding final.mp4'), r'D:\Renders');
      expect(folderOf(r'D:\clip.mp4'), r'D:\', reason: 'a drive root keeps its backslash');
      expect(folderOf(r'\\nas\share\out.mov'), r'\\nas\share');
      expect(fileNameOf('out.mp4'), 'out.mp4');
    });
  });

  group('progress', () {
    test('rounds down, so 100% means every frame went to FFmpeg', () {
      expect(percentLabel(encoding), '32%', reason: '7,400 of 22,873');
      expect(percentLabel(encoding.copyWith(framesDone: 22872)), '99%');
      expect(percentLabel(encoding.copyWith(framesDone: 22873)), '100%');
    });

    test('an unknown total shows no percentage and no fill', () {
      final unknown = encoding.copyWith(framesTotal: null);
      expect(percentLabel(unknown), isNull);
      expect(headline(unknown), 'Rendering');
      expect(windowTitle(unknown), 'Rendering');
      expect(framesLabel(unknown), 'Frame 7,400');
      expect(barOf(unknown).fraction, isNull);
    });

    test('titles, headlines and frames per state', () {
      String row(RenderState s) {
        final v = liveSample(s);
        return '${windowTitle(v)} | ${headline(v)} | ${framesLabel(v)}';
      }

      expect(windowTitle(null), 'Waiting for the render');
      expect(row(RenderState.starting), startsWith('Starting the render | Starting | Frame 0 of 22,873'));
      expect(row(RenderState.encoding), 'Rendering, 32% | 32% | Frame 7,400 of 22,873');
      expect(row(RenderState.finishing), 'Finishing the file | Finishing | 22,873 frames');
      expect(row(RenderState.verifying), 'Checking the output | Checking | 22,873 frames');
      expect(row(RenderState.done), 'Rendered | Done | 22,873 frames');
      expect(row(RenderState.failed), 'Render failed | Failed | 22,873 of 22,873 frames');
      expect(row(RenderState.cancelled), startsWith('Render cancelled | Cancelled | '));
    });

    test('the bar: video while rendering, then the outcome', () {
      expect(barOf(null), (fraction: null, tone: VeWireTone.video));
      expect(barOf(encoding).tone, VeWireTone.video);
      expect(barOf(liveSample(RenderState.done)), (fraction: 1.0, tone: VeWireTone.success));
      expect(barOf(liveSample(RenderState.failed)).tone, VeWireTone.error);
      expect(barOf(liveSample(RenderState.cancelled)).tone, VeWireTone.stopped);
      expect(
        barOf(liveSample(RenderState.failed).copyWith(framesTotal: null)).fraction,
        0,
        reason: 'a stopped render with no total shows the head at the start',
      );
    });
  });

  group('figures', () {
    test('the six read-outs (S6)', () {
      expect(figuresOf(encoding).map((f) => f.toString()), [
        'Encoding: 61.8 fps',
        'Speed: 2.06× realtime',
        'Bitrate: 30.7 Mb/s',
        'Size so far: 1.23 GB',
        'Final size: about 2.93 GB',
        'Time left: 4:10 of 8:14',
      ]);
    });

    test('unknown figures stay unknown, with no unit or "about"', () {
      final early = encoding.copyWith(
        encodeFps: null,
        speed: null,
        bitrateKbps: null,
        bytesWritten: 0,
        etaSec: null,
        estimatedFinalBytes: null,
      );
      expect(figuresOf(early).map((f) => f.toString()), [
        'Encoding: –',
        'Speed: –',
        'Bitrate: –',
        'Size so far: 0 B',
        'Final size: –',
        'Time left: –',
      ]);
    });

    test('fast encodes drop the decimal', () => expect(fpsLabel(142.4), '142 fps'));

    test('the header names the encoders, then the folder once the file is there', () {
      expect(headerDetail(encoding), 'libx264 + aac');
      expect(headerDetail(liveSample(RenderState.done)), r'D:\Renders');
      expect(headerDetail(liveSample(RenderState.failed)), 'libx264 + aac');
    });
  });

  group('how it ended', () {
    late JobRecord done, failed, cancelled;
    setUpAll(() async {
      done = await recordFor(RenderState.done);
      failed = await recordFor(RenderState.failed);
      cancelled = await recordFor(RenderState.cancelled);
    });

    test('done: History\'s sentence and the output check', () {
      expect(
        endSentence(liveSample(RenderState.done), done),
        'Rendered 12:43 in 4:07, 3.09× realtime, 2.93 GB. Output checked: h264 and aac, as set.',
      );
      final unchecked = JobRecord.fromJson({
        ...done.toJson(),
        'verification': {'state': 'skipped', 'message': '', 'expectedCodecs': [], 'actualCodecs': []},
      });
      expect(endSentence(liveSample(RenderState.done), unchecked), endsWith('2.93 GB. The output wasn’t checked (Settings).'));
    });

    test('done without its record: what the live file says', () {
      expect(endSentence(liveSample(RenderState.done), null), 'Rendered in 4:07, 2.06× realtime.');
    });

    test('a record for another job is not used', () {
      final other = JobRecord.fromJson({...done.toJson(), 'id': 'j-1'});
      expect(endSentence(liveSample(RenderState.done), other), 'Rendered in 4:07, 2.06× realtime.');
    });

    test('failed: the reason, with or without the record', () {
      expect(
        endSentence(liveSample(RenderState.failed), failed),
        'Failed after 4:08. FFmpeg exited with code 1. Partial file removed.',
      );
      expect(
        endSentence(liveSample(RenderState.failed), null),
        'Failed after 4:08. FFmpeg exited with code 1. Partial file removed.',
      );
      expect(endSentence(liveSample(RenderState.failed).copyWith(message: ''), null), 'Failed after 4:08.');
    });

    test('cancelled: in VEGAS, after how long', () {
      expect(endSentence(liveSample(RenderState.cancelled), cancelled), 'Cancelled in VEGAS after 1:12.');
    });

    test('FFmpeg\'s last lines, without blank ones', () {
      expect(
        ffmpegLastLines(failed, lines: 2),
        '[vost#0:0/libsvtav1] Error while opening encoder\nConversion failed!',
      );
      expect(ffmpegLastLines(failed).split('\n'), hasLength(3));
      expect(ffmpegLastLines(null), '');
      expect(ffmpegLastLines(done), '', reason: 'nothing on stderr');
    });
  });

  group('host window', () {
    test('a decimal handle, or nothing', () {
      expect(hostHwndOf(encoding), 123456);
      expect(hostHwndOf(encoding.copyWith(hostHwnd: null)), isNull);
      expect(hostHwndOf(encoding.copyWith(hostHwnd: '0')), isNull);
      expect(hostHwndOf(encoding.copyWith(hostHwnd: '18446744073709551615')), -1, reason: 'all 64 bits, as signed');
      expect(hostHwndOf(encoding.copyWith(hostHwnd: '18446744073709551616')), isNull, reason: 'more than 64 bits');
      expect(hostHwndOf(encoding.copyWith(hostHwnd: '-5')), isNull);
      expect(hostHwndOf(encoding.copyWith(hostHwnd: '0x1F')), isNull);
      expect(hostHwndOf(null), isNull);
    });
  });
}
