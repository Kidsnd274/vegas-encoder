import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart';
import 'package:vegas_encoder/design/components/button.dart';
import 'package:vegas_encoder/state/recipe_edit.dart';

import '../filters_helpers.dart';
import '../helpers.dart';

void main() {
  late NativeVeCore core;
  setUpAll(() => core = NativeVeCore());

  for (final popup in [false, true]) {
    for (final brightness in themes) {
      final name = 'filters_${popup ? 'popup' : 'desktop'}_${themeName(brightness)}';
      testWidgets(name, (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        final h = FiltersHarness(core, popup: popup);
        await h.pump(tester, filter: VideoFilter(width: 1280, height: 720, algorithm: 'lanczos'));
        await expectGolden('${name}_collapsed');
        await h.expand(tester);
        await tester.ensureVisible(find.textContaining('Padding is determined from the delivered frames'));
        await tester.pumpAndSettle();
        await expectGolden('${name}_enabled_unknown');
        h.edit(tester, (r) => r.withVideo((v) => v.copyWith(filters: [v.filters.single.copyWith(enabled: false)])));
        await tester.pumpAndSettle();
        await expectGolden('${name}_disabled');
        h.edit(tester, (r) => r.withVideo((v) => v.copyWith(extra: '-vf "scale=640:360"')));
        await tester.pumpAndSettle();
        await expectGolden('${name}_extra');
        h.edit(
          tester,
          (r) => r.withVideo((v) => v.copyWith(extra: '', filters: [v.filters.single.copyWith(enabled: true)])),
        );
        await tester.pumpAndSettle();
        await h.tap(tester, find.bySemanticsLabel('Edit resize filter'));
        await expectGolden('${name}_editor_unknown');
        await h.select(tester, 'Resize output resolution', 'Custom width and height');
        await expectGolden('${name}_editor_custom');
        await h.tap(tester, find.widgetWithText(VeButton, 'Cancel'));
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final brightness in themes) {
    testWidgets('filters popup known input ${themeName(brightness)}', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final h = FiltersHarness(core, popup: true);
      await h.pump(
        tester,
        filter: VideoFilter(width: 1280, height: 720),
        expanded: true,
        media: MediaDescription(
          video: VideoMedia(width: 720, height: 576, fps: [25, 1], sar: '16:15'),
          audio: AudioMedia(),
        ),
      );
      await h.tap(tester, find.bySemanticsLabel('Edit resize filter'));
      await expectGolden('filters_popup_${themeName(brightness)}_editor_known');
      expect(tester.takeException(), isNull);
    });
  }
}
