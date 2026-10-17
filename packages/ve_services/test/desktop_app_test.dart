import 'dart:io';

import 'package:ve_services/ve_services.dart';

Future<void> main() async {
  var checks = 0;
  void check(bool condition, String message) {
    checks++;
    if (!condition) throw StateError(message);
  }

  final launches = <({String executable, List<String> arguments})>[];
  final launcher = WindowsDesktopAppLauncher(
    executable: r'L:\app with spaces\VegasEncoder.exe',
    launch: (executable, arguments) async {
      launches.add((executable: executable, arguments: List.of(arguments)));
    },
  );
  check(launches.isEmpty, 'constructing a launcher does no work');
  await launcher.openPreset('yt-h264');
  await launcher.openJob('job_12.3');
  check(
    launches.every(
      (call) => call.executable == r'L:\app with spaces\VegasEncoder.exe',
    ),
    'matching binary path',
  );
  check(
    launches[0].arguments.join('|') == '--open-preset|yt-h264',
    'preset arguments',
  );
  check(
    launches[1].arguments.join('|') == '--open-job|job_12.3',
    'job arguments',
  );
  for (final id in [
    '',
    '../other',
    '--open-job',
    'two words',
    'bad\u0000id',
    'CON',
    'LPT1.log',
    'tail.',
    'a' * 129,
  ]) {
    try {
      await launcher.openPreset(id);
      throw StateError('accepted invalid ID');
    } on ServiceException catch (e) {
      check(e.code == 'INVALID-ID', 'invalid ID rejected before launch');
    }
  }
  check(launches.length == 2, 'no invalid requests launched');
  final failing = WindowsDesktopAppLauncher(
    launch: (exe, args) async {
      throw ProcessException(exe, args, 'fixture failure');
    },
  );
  try {
    await failing.openJob('job-1');
    throw StateError('missing launch failure');
  } on ServiceException catch (e) {
    check(
      e.code == 'DESKTOP-LAUNCH' && e.message.contains('fixture failure'),
      'actionable process failure',
    );
  }
  print('Desktop launcher: $checks checks passed (captured process launches).');
}
