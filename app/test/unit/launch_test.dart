import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart' show DesktopRoute;
import 'package:vegas_encoder/app/launch.dart';

void main() {
  group('LaunchMode.fromArguments', () {
    test('no mode flag runs the desktop app', () {
      expect(LaunchMode.fromArguments([]), const DesktopLaunch());
      expect(LaunchMode.fromArguments(['--unknown', 'x']), const DesktopLaunch());
    });

    test('desktop destinations are bounded IDs; popup modes still win', () {
      expect(
        LaunchMode.fromArguments(['--open-preset', 'yt-h264']),
        const DesktopLaunch(route: DesktopRoute.preset('yt-h264')),
      );
      expect(
        LaunchMode.fromArguments(['--open-job', 'j-1042']),
        const DesktopLaunch(route: DesktopRoute.job('j-1042')),
      );
      expect((LaunchMode.fromArguments(['--open-preset', '../bad']) as DesktopLaunch).error, isNotNull);
      expect((LaunchMode.fromArguments(['--open-job']) as DesktopLaunch).error, isNotNull);
      expect(
        LaunchMode.fromArguments(['--open-job', 'j-1042', '--edit-session', 'dir']),
        const EditSessionLaunch('dir'),
      );
    });

    test('--edit-session takes the session directory', () {
      final mode = LaunchMode.fromArguments([r'--edit-session', r'C:\Users\me\AppData\Local\VegasEncoder\sessions\a1']);
      expect(mode, const EditSessionLaunch(r'C:\Users\me\AppData\Local\VegasEncoder\sessions\a1'));
      expect(mode.window, LaunchWindow.editSession);
    });

    test('the owner comes from the request (C4), not the command line', () {
      final mode = LaunchMode.fromArguments(['--edit-session', 'dir', '--owner', '263568']);
      expect(mode, const EditSessionLaunch('dir'), reason: 'the provisional --owner is gone');
    });

    test('--render-monitor takes the live status file', () {
      final mode = LaunchMode.fromArguments(['--render-monitor', r'D:\jobs\7.live.json']);
      expect(mode, const RenderMonitorLaunch(r'D:\jobs\7.live.json'));
      expect(mode.window, LaunchWindow.renderMonitor);
    });

    test('the first mode flag wins, matching the runner', () {
      expect(
        LaunchMode.fromArguments(['--render-monitor', 'f', '--edit-session', 'd']),
        const RenderMonitorLaunch('f'),
      );
      expect(LaunchMode.fromArguments(['--edit-session', 'd', '--render-monitor', 'f']), const EditSessionLaunch('d'));
    });

    test('a mode flag without its path is an error in that window', () {
      final missing = LaunchMode.fromArguments(['--edit-session']);
      expect(missing, isA<LaunchError>());
      expect(missing.window, LaunchWindow.editSession);
      final flag = LaunchMode.fromArguments(['--render-monitor', '--owner', '1']);
      expect(flag, isA<LaunchError>());
      expect(flag.window, LaunchWindow.renderMonitor);
      expect((flag as LaunchError).message, '--render-monitor needs a path after it.');
    });
  });
}
