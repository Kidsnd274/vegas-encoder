import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart';
import 'package:vegas_encoder/platform/window_channel.dart';
import 'package:vegas_encoder/state/popup_placement.dart';
import 'package:vegas_encoder/state/services.dart';
import 'package:vegas_encoder/state/settings.dart';
import 'package:vegas_encoder/state/ui_state.dart';

import '../helpers.dart';

void main() {
  test('popup placement reads only saved physical size, with no desktop position', () async {
    final machine = FakeMachineSettingsRepository(
      settings: MachineSettings(
        uiState: AppUiState(
          desktopWindowBounds: DesktopWindowBounds(x: -1000, y: 20, width: 1400, height: 900),
          popupWindowSize: PopupWindowSize(width: 1250, height: 800),
        ),
      ),
    );
    addTearDown(machine.dispose);
    final container = testContainer(overrides: [machineSettingsRepositoryProvider.overrideWithValue(machine)]);
    addTearDown(container.dispose);
    expect(await popupPlacement(container), (width: 1250, height: 800));
    final current = await machine.read();
    await machine.save(current.copyWith(uiState: null), expectedRevision: current.revision);
    expect(await popupPlacement(container), isNull, reason: 'older settings use the default size');
  });

  test('saving size retries conflict, preserving concurrent preferences and unknown fields', () async {
    final machine = _ConflictingSettings(
      settings: MachineSettings(
        uiState: AppUiState.fromJson({
          'desktopWindowBounds': {'x': -500, 'y': 30, 'width': 1440, 'height': 900},
          'desktopMaximized': true,
          'lastSizeLengthText': '12:34',
          'futureUi': 'keep',
          'popupWindowSize': {'width': 1120, 'height': 740, 'futureSize': 42},
        }),
      ),
    );
    addTearDown(machine.dispose);
    final writer = UiStateWriter(MachineSettingsWriter(machine));
    addTearDown(writer.dispose);
    final window = FakeWindowController(const WindowState(), (
      bounds: (x: 800, y: -200, width: 1300, height: 820),
      maximized: false,
    ));
    await rememberPopupSize(window, writer);
    final saved = await machine.read();
    expect(saved.keepOnTop, isTrue, reason: 'the concurrent write survives');
    expect(saved.uiState!.popupWindowSize!.toJson(), {'width': 1300, 'height': 820, 'futureSize': 42});
    expect(saved.uiState!.desktopWindowBounds!.x, -500);
    expect(saved.uiState!.desktopMaximized, isTrue);
    expect(saved.uiState!.lastSizeLengthText, '12:34');
    expect(saved.uiState!.data['futureUi'], 'keep');
    expect(saved.uiState!.popupWindowSize!.data.containsKey('x'), isFalse);
  });

  test('unavailable bounds/settings do not prevent closing', () async {
    final machine = _UnreadableSettings();
    addTearDown(machine.dispose);
    final container = testContainer(overrides: [machineSettingsRepositoryProvider.overrideWithValue(machine)]);
    addTearDown(container.dispose);
    expect(await popupPlacement(container), isNull);
    final writer = UiStateWriter(MachineSettingsWriter(machine));
    addTearDown(writer.dispose);
    await rememberPopupSize(FakeWindowController(), writer);
    await rememberPopupSize(
      FakeWindowController(const WindowState(), (bounds: (x: 0, y: 0, width: 1200, height: 800), maximized: false)),
      writer,
    );
  });
}

class _ConflictingSettings extends FakeMachineSettingsRepository {
  _ConflictingSettings({required super.settings});
  bool _conflict = true;

  @override
  Future<MachineSettings> save(MachineSettings settings, {required int expectedRevision}) async {
    if (_conflict) {
      _conflict = false;
      await super.save((await read()).copyWith(keepOnTop: true), expectedRevision: expectedRevision);
    }
    return super.save(settings, expectedRevision: expectedRevision);
  }
}

class _UnreadableSettings extends FakeMachineSettingsRepository {
  @override
  Future<MachineSettings> read() async => throw const ServiceException('READ-FAILED', 'Cannot read settings.');
}
