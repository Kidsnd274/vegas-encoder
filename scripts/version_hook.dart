import 'dart:io';

// Build-time only: never imported by the running application.
Future<void> checkVersionInputs(
  Uri packageRoot,
  void Function(Uri) dependency,
) async {
  final root = packageRoot.resolve('../../');
  for (final path in [
    'version.json',
    'scripts/Generate-Versions.py',
    'src/version.generated.h',
    'packages/ve_core/lib/src/version.g.dart',
    'setup/version.generated.iss',
    'app/pubspec.yaml',
    'packages/ve_core/pubspec.yaml',
    'packages/ve_services/pubspec.yaml',
  ]) {
    dependency(root.resolve(path));
  }
  final python = Platform.environment['VEGAS_ENCODER_PYTHON'] ?? 'python';
  final result = await Process.run(python, [
    '-I',
    root.resolve('scripts/Generate-Versions.py').toFilePath(),
    '--check',
  ]);
  if (result.exitCode != 0) {
    throw StateError('Version inputs are stale or invalid. ${result.stderr}');
  }
}
