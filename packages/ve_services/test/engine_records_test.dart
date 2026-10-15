import 'dart:convert';
import 'dart:io';
import 'package:ve_services/ve_services.dart';

int checks = 0;
void check(bool ok, String message) {
  checks++;
  if (!ok) throw StateError(message);
}

Future<void> main(List<String> args) async {
  if (args.first == '--identify') {
    final root = Directory(args[1]).absolute.path;
    final paths = ServicePaths(roaming: '$root/roaming', local: '$root/local');
    final services = WindowsServices(core: NativeVeCore(), paths: paths);
    final installations = <Map<String, Object?>>[];
    for (final path in args.skip(2)) {
      final installation = await services.discovery.add(path);
      installations.add(installation.data);
    }
    await File(
      '$root/installations.json',
    ).writeAsString(jsonEncode(installations));
    stdout.writeln(
      'B4 snapshots: ${installations.length} exact B3 installations.',
    );
    return;
  }
  final root = Directory(args.single).absolute.path;
  final paths = ServicePaths(roaming: '$root/unused-roaming', local: root);
  final core = NativeVeCore();
  final repository = FileJobRepository(core: core, paths: paths);
  final live = FileLiveRenderStatusReader();
  final index = await repository.list();
  final ids = <String>{};
  check(index.isNotEmpty, 'Native engine wrote History index.');
  for (final entry in index) {
    check(ids.add(entry.id), 'One complete index entry per job.');
    final record = await repository.get(entry.id);
    check(record != null, 'Index refers to a complete validated C6 record.');
    check(record!.status == entry.status, 'Index status matches record.');
    check(record.commandLine != null, 'Core commandLine is recorded.');
    check(record.encoderSummary != null, 'Core encoder summary is recorded.');
    check(
      record.recipeSha256.length == 64,
      'Canonical recipe SHA-256 is recorded.',
    );
    final status = await live.read('${paths.jobs}/${entry.id}.live.json');
    check(
      status != null && status.jobId == entry.id,
      'C5 native writer is readable.',
    );
    check(
      status!.state.name ==
          (entry.status == 'succeeded' ? 'done' : entry.status),
      'C5 terminal matches C6.',
    );
    check(
      status.sequence > 0 && status.hostHwnd == '123456',
      'C5 sequence and host placement facts.',
    );
    final liveJson =
        jsonDecode(
              await File('${paths.jobs}/${entry.id}.live.json').readAsString(),
            )
            as Map<String, dynamic>;
    check(
      liveJson.containsKey('outputBitDepth') &&
          liveJson.containsKey('pixelFormatConversionReducesPrecision') &&
          status.outputBitDepth == liveJson['outputBitDepth'] &&
          status.pixelFormatConversionReducesPrecision ==
              liveJson['pixelFormatConversionReducesPrecision'],
      'C5 nullable native video facts survive the validated Dart reader.',
    );
    if (record.templateName.startsWith('h264-build')) {
      check(
        status.outputBitDepth == 8 &&
            status.pixelFormatConversionReducesPrecision == true,
        'C5 native H.264 test records the P010 to 8-bit precision reduction.',
      );
    } else if ([
      'lossless-build',
      'video-only-build',
      'advanced-build',
    ].any(record.templateName.startsWith)) {
      check(
        status.outputBitDepth == 10 &&
            status.pixelFormatConversionReducesPrecision == false,
        'C5 native lossless and seeded Advanced tests preserve 10-bit precision.',
      );
    }
    if (record.logFile != null &&
        await repository.logLocation(entry.id) != null) {
      final log = await repository.readLog(entry.id).join();
      check(
        log.contains('Input #') || log.isEmpty || log.contains('Unrecognized'),
        'Native log streams through B3.',
      );
    }
    final json =
        jsonDecode(await File('${paths.jobs}/${entry.id}.json').readAsString())
            as Map<String, dynamic>;
    check(
      (json['errorTokenIndices'] as List).every(
        (i) => i is int && i >= 0 && i < record.argv.length,
      ),
      'Error indexes refer to actual argv.',
    );
    if (entry.status == 'succeeded') {
      check(
        record.published && record.ffmpegExitCode == 0 && record.sizeBytes > 0,
        'History success means publication.',
      );
    } else {
      check(
        !record.published && record.sizeBytes == 0,
        'Stopped history job has no published bytes.',
      );
    }
  }
  // Explicit recovery must take the same native byte lock and preserve records.
  await repository.rebuildIndex();
  check(
    (await repository.list()).length == index.length,
    'B3 index reconstruction sees every native job.',
  );
  stdout.writeln(
    'B4 engine records PASS: $checks checks, ${index.length} jobs.',
  );
}
