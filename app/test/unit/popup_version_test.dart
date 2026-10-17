import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart';
import 'package:vegas_encoder/app/launch.dart';
import 'package:vegas_encoder/platform/window_channel.dart';
import 'package:vegas_encoder/state/app_state.dart';
import 'package:vegas_encoder/state/popup_version.dart';
import 'package:vegas_encoder/state/services.dart';

import '../helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  PopupVersionStatus status({
    String dll = '0.1.7-recipe-proof',
    String? app = '0.1.7+1',
    String core = '0.2.0-b2',
    String? appCore = '0.2.0-b2',
  }) => PopupVersionStatus(dllVersion: dll, coreVersion: core, appVersion: app, appCoreVersion: appCore);

  test('release triplets pair intentional suffixes, build numbers and independent core versions', () {
    expect(status().match, PopupVersionMatch.matching);
    expect(status(app: '0.1.7+23').match, PopupVersionMatch.matching);
    expect(status(dll: '0.1.0-b0-fixture', app: '0.1.0+1').match, PopupVersionMatch.matching);
    for (final app in ['0.1.8+1', '0.2.7+1', '1.1.7+1']) {
      expect(status(app: app).match, PopupVersionMatch.mismatched);
    }
    expect(status(appCore: '0.2.0-b3').match, PopupVersionMatch.mismatched);
  });

  test('unreadable or malformed stamps are unverified and cannot hide a known mismatch', () {
    for (final app in [null, '', 'unknown', '0.1', '0.1.7garbage', '0.1.7+']) {
      expect(status(app: app).match, PopupVersionMatch.unknown);
    }
    expect(status(dll: 'unknown').match, PopupVersionMatch.unknown);
    expect(status(appCore: null).match, PopupVersionMatch.unknown);
    expect(status(core: '').match, PopupVersionMatch.unknown);
    expect(status(app: null, appCore: 'different-core').match, PopupVersionMatch.mismatched);
  });

  test('provider compares the actual runner and loaded core with the C4 request', () async {
    final request = await FakeEditSessionService().readRequest('b0-session');
    final window = FakeWindowController()..buildVersion = '0.1.0+1';
    final c = testContainer(
      overrides: [
        launchModeProvider.overrideWithValue(const EditSessionLaunch('session')),
        windowControllerProvider.overrideWithValue(window),
        editSessionServiceProvider.overrideWithValue(FakeEditSessionService(requests: {'session': request})),
      ],
    );
    addTearDown(c.dispose);
    final value = await c.read(popupVersionsProvider.future);
    expect(value.dllVersion, request.dllVersion);
    expect(value.appVersion, '0.1.0+1');
    expect(value.appCoreVersion, c.read(veCoreProvider).version.core);
    expect(value.match, PopupVersionMatch.matching);
  });

  test('window channel reads the runner build stamp without substituting an app constant', () async {
    const channel = MethodChannel('vegas_encoder/window');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'appVersion');
      return '0.1.7+19';
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    expect(await MethodChannelWindowController().appVersion(), '0.1.7+19');
  });
}
