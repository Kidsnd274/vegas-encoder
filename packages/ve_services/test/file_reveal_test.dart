import 'dart:io';
import 'package:ve_services/ve_services.dart';
import 'package:ve_services/src/storage.dart';

int checks = 0;
void check(bool condition, String message) {
  checks++;
  if (!condition) throw StateError(message);
}

Future<void> rejects(Future<void> Function() action, String code) async {
  try {
    await action();
  } on ServiceException catch (e) {
    check(e.code == code, 'Expected $code, got $e');
    return;
  }
  throw StateError('Expected $code.');
}

Future<void> main() async {
  if (!Platform.isWindows) throw StateError('Windows-only tests.');
  final build = Directory('../../build/test-results').absolute;
  await build.create(recursive: true);
  final root = await build.createTemp('file reveal ');
  final output = File(joinPath(root.path, 'render, output 雪 & detail.mkv'));
  await output.writeAsString('isolated reveal fixture');
  final launches = <({String executable, List<String> arguments})>[];
  final reveal = WindowsFileReveal(
    launch: (executable, arguments) async {
      launches.add((executable: executable, arguments: List.of(arguments)));
    },
  );
  try {
    check(launches.isEmpty, 'construction never launches Explorer');
    await reveal.reveal(output.path);
    check(launches.length == 1, 'an explicit reveal launches once');
    check(
      launches.single.executable ==
          joinPath(Platform.environment['WINDIR']!, 'explorer.exe'),
      'uses the Windows Explorer executable by absolute path',
    );
    check(
      launches.single.arguments.length == 2 &&
          launches.single.arguments.first == '/select,' &&
          launches.single.arguments.last == output.path,
      'file switch is separate from the unchanged space/comma/Unicode path',
    );
    await reveal.reveal(root.path);
    check(
      launches.length == 2 &&
          launches.last.arguments.length == 1 &&
          launches.last.arguments.single == root.path,
      'a folder opens directly',
    );
    await rejects(() => reveal.reveal('relative.mkv'), 'INVALID-PATH');
    await rejects(() => reveal.reveal(r'C:relative.mkv'), 'INVALID-PATH');
    await rejects(() => reveal.reveal('${output.path}\u0000'), 'INVALID-PATH');
    await rejects(
      () => reveal.reveal(joinPath(root.path, 'missing.mkv')),
      'NOT-FOUND',
    );
    check(launches.length == 2, 'invalid/missing paths never launch Explorer');
    final failed = WindowsFileReveal(
      launch: (executable, arguments) async {
        throw ProcessException(executable, arguments, 'fixture launch failure');
      },
    );
    await rejects(() => failed.reveal(output.path), 'REVEAL-FAILED');
    check(await output.exists(), 'reveal never modifies its target');
    print('File reveal: $checks checks passed (captured process launches).');
  } finally {
    // This directory was created by this test under the ignored test root.
    final allowed = '${build.path}${Platform.pathSeparator}';
    if (!root.path.startsWith(allowed)) {
      throw StateError('Unexpected test cleanup path: ${root.path}');
    }
    await root.delete(recursive: true);
  }
}
