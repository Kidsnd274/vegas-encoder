import 'package:ve_core/ve_core.dart';

/// The desktop app has no VEGAS project, so the editor previews against the
/// documented sample (CONTRACTS C2: "desktop uses the documented sample") and
/// labels it as a sample. A real render uses the project's own size and rate.
///
/// Built from JSON, as the fixtures have it: tests run on FakeVeCore, which
/// matches its fixtures on exact JSON (since B2 it ignores empty `extensions`).
abstract final class SamplePreview {
  static final MediaDescription media = MediaDescription.fromJson({
    'video': {
      'width': 1920,
      'height': 1080,
      'fps': [30000, 1001],
      'pixfmt': 'p010le',
      'sar': '1:1',
    },
    'audio': {'rate': 48000, 'channels': 2, 'sampleFmt': 'f32le'},
    'durationSec': null,
  });

  static const String project = 'Sample project';
  static const String _folder = r'D:\Renders';

  /// Where a render of the sample project would go, with the container's
  /// extension from the profile catalog (".mp4"); [extension] null adds none.
  static String outputPath(String? extension) => '$_folder\\$project${extension ?? ''}';

  static CompilePaths paths(String? extension) => CompilePaths.fromJson({
    'ffmpeg': 'ffmpeg',
    'videoPipe': r'\\.\pipe\vegas-encoder-0000-video',
    'audioPipe': r'\\.\pipe\vegas-encoder-0000-audio',
    'project': project,
    'output': outputPath(extension),
  });
}
