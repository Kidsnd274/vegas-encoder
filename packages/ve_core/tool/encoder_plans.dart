// Offline B2 checks only: generate plans through the same NativeVeCore API.
import 'dart:convert';
import 'dart:io';
import 'package:ve_core/ve_core.dart';

void main(List<String> args) {
  if (args.length != 2)
    throw ArgumentError('Pass output directory and FFmpeg executable.');
  final directory = Directory(args[0]).absolute;
  directory.createSync(recursive: true);
  final core = NativeVeCore();
  final fixtures = FakeVeCore().fixtures;
  final media = MediaDescription(
    video: VideoMedia(width: 256, height: 144, fps: [30000, 1001]),
    audio: AudioMedia(),
    durationSec: 2.002,
  );
  for (final id in ['ffv1-master', 'yt-h264']) {
    final recipe = fixtures.firstWhere((f) => f.recipe.id == id).recipe;
    final ext = id == 'ffv1-master' ? 'mkv' : 'mp4';
    final paths = CompilePaths(
      ffmpeg: args[1],
      videoPipe: '${directory.path}/input-video.raw',
      audioPipe: '${directory.path}/input-audio.raw',
      output: '${directory.path}/$id.$ext',
    );
    final result = core.compile(recipe, media: media, paths: paths);
    if (result.issues.any((i) => i.level == IssueLevel.error))
      throw StateError('Recipe compile failed.');
    File(
      '${directory.path}/$id.plan.json',
    ).writeAsStringSync(jsonEncode(result.toJson()));
  }
}
