// Prepare only a fresh, explicitly selected trial data root through production C3.
import 'dart:io';
import 'package:ve_services/ve_services.dart';

Future<void> main(List<String> args) async {
  if (args.length != 3) {
    throw ArgumentError(
      'Pass fresh trial root, FFmpeg executable and core DLL.',
    );
  }
  final root = Directory(args[0]).absolute.path;
  final paths = ServicePaths(roaming: '$root\\Roaming', local: '$root\\Local');
  if (await File(paths.machine).exists()) {
    throw StateError(
      'Trial settings already exist; preserve them or choose a fresh root.',
    );
  }
  final services = WindowsServices(
    core: NativeVeCore.open(args[2]),
    paths: paths,
  );
  final installation = await services.discovery.add(args[1]);
  final current = await services.machineSettings.read();
  await services.machineSettings.save(
    current.copyWith(defaultFFmpegId: installation.id),
    expectedRevision: current.revision,
  );
  stdout.writeln('Prepared isolated C7 settings: ${paths.machine}');
  stdout.writeln('Default FFmpeg: ${installation.path} (${installation.id})');
  stdout.writeln('No capability/hardware qualification was inferred.');
}
