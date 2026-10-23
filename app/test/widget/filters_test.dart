import 'package:flutter/material.dart' show TextField;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart';
import 'package:vegas_encoder/design/components/button.dart';
import 'package:vegas_encoder/design/components/message.dart';
import 'package:vegas_encoder/design/components/switch.dart';
import 'package:vegas_encoder/state/recipe_edit.dart';
import 'package:vegas_encoder/state/ui_state.dart';

import '../filters_helpers.dart';

void main() {
  late NativeVeCore core;
  setUpAll(() => core = NativeVeCore());

  for (final popup in [false, true]) {
    final context = popup ? 'popup' : 'desktop';
    testWidgets('$context disclosure persists without dirtying the recipe', (tester) async {
      final h = FiltersHarness(core, popup: popup);
      await h.pump(tester);
      final before = h.data(tester).recipe;
      expect(find.bySemanticsLabel('Video filters. None'), findsOneWidget);
      expect(find.text('Add filter'), findsNothing);
      await h.expand(tester);
      expect(
        h.container(tester).read(videoFiltersExpandedProvider),
        isTrue,
        reason: 'Disclosure state toggles immediately.',
      );
      expect(
        (await h.machine.read()).uiState!.videoFiltersExpanded,
        isTrue,
        reason: 'Disclosure preference is persisted.',
      );
      expect(find.text('Add filter'), findsOneWidget);
      expect(sameRecipe(before, h.data(tester).recipe), isTrue);
      expect((await h.machine.read()).uiState!.videoFiltersExpanded, isTrue);
      await h.expand(tester);
      expect((await h.machine.read()).uiState!.videoFiltersExpanded, isFalse);
      expect(sameRecipe(before, h.data(tester).recipe), isTrue);
    });

    testWidgets('$context resize draft cancel, apply, disable and remove', (tester) async {
      final h = FiltersHarness(core, popup: popup);
      await h.pump(tester, expanded: true);
      final before = h.data(tester).recipe;
      await h.add(tester);
      await h.apply(tester);
      expect(sameRecipe(before, h.data(tester).recipe), isTrue, reason: 'Same as input on a v1 recipe is a no-op.');
      expect(h.data(tester).recipe.video.toJson().containsKey('filters'), isFalse);
      await h.add(tester);
      await h.select(tester, 'Resize output resolution', '3840 × 2160 · UHD (not DCI 4K)');
      await h.select(tester, 'Resize scaling algorithm', 'Lanczos');
      expect(find.textContaining('Padding is determined from the delivered frames'), findsOneWidget);
      await h.tap(tester, find.widgetWithText(VeButton, 'Cancel'));
      expect(sameRecipe(before, h.data(tester).recipe), isTrue);

      await h.add(tester);
      await h.select(tester, 'Resize output resolution', '1280 × 720 · HD');
      await h.select(tester, 'Resize scaling algorithm', 'Lanczos');
      await h.apply(tester);
      var recipe = h.data(tester).recipe;
      expect(recipe.schema, 2);
      expect(recipe.video.filters.single.width, 1280);
      expect(recipe.video.filters.single.height, 720);
      expect(recipe.video.filters.single.algorithm, 'lanczos');
      final compiled = h.data(tester).compiled.value!;
      expect(compiled.argv, contains('-vf'));
      expect(compiled.videoGeometry!.width, 1280);
      expect(compiled.videoGeometry!.height, 720);
      expect(find.bySemanticsLabel('Video filters. Resize to 1280 × 720 · Lanczos'), findsOneWidget);

      final toggle = find.byWidgetPredicate((w) => w is VeSwitch && w.label == 'Resize / Upscale');
      await h.tap(tester, toggle);
      recipe = h.data(tester).recipe;
      expect(recipe.video.filters.single.enabled, isFalse);
      expect(recipe.video.filters.single.algorithm, 'lanczos');
      expect(h.data(tester).compiled.value!.argv, isNot(contains('-vf')));
      expect(find.bySemanticsLabel('Video filters. None · 1 disabled'), findsOneWidget);
      await h.tap(tester, toggle);
      expect(h.data(tester).compiled.value!.argv, contains('-vf'));
      await h.tap(tester, find.bySemanticsLabel('Remove resize filter'));
      expect(h.data(tester).recipe.video.filters, isEmpty);
      expect(h.data(tester).recipe.schema, 2, reason: 'Removing the last filter never downgrades the recipe.');
      expect(h.data(tester).compiled.value!.argv, isNot(contains('-vf')));
      expect(tester.takeException(), isNull);
    });

    testWidgets('$context custom validation is core-owned; Escape cancels and Reset removes', (tester) async {
      final h = FiltersHarness(core, popup: popup);
      await h.pump(tester, filter: VideoFilter(width: 1280, height: 720), expanded: true);
      await h.tap(tester, find.bySemanticsLabel('Edit resize filter'));
      await h.select(tester, 'Resize output resolution', 'Custom width and height');
      final width = find.descendant(of: find.bySemanticsLabel('Resize width'), matching: find.byType(TextField));
      await tester.enterText(width, '0');
      await tester.pumpAndSettle();
      expect(tester.widget<VeButton>(find.widgetWithText(VeButton, 'Apply')).onPressed, isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(h.data(tester).recipe.video.filters.single.width, 1280);
      await h.tap(tester, find.bySemanticsLabel('Edit resize filter'));
      await h.tap(tester, find.widgetWithText(VeButton, 'Reset resizing'));
      await h.apply(tester);
      expect(h.data(tester).recipe.video.filters, isEmpty);
      expect(h.data(tester).recipe.schema, 2);
    });

    testWidgets('$context Extra filter aliases deactivate and retain structured settings', (tester) async {
      final h = FiltersHarness(core, popup: popup);
      await h.pump(
        tester,
        filter: VideoFilter(width: 1280, height: 720),
        extra: '-filter:v:0 "scale=640:360"',
        expanded: true,
      );
      expect(h.data(tester).compiled.value!.filterControl, 'extra');
      expect(find.bySemanticsLabel('Video filters. Set in Extra arguments'), findsOneWidget);
      expect(tester.widget<VeButton>(find.widgetWithText(VeButton, 'Edit')).onPressed, isNull);
      expect(tester.widget<VeButton>(find.widgetWithText(VeButton, 'Remove')).onPressed, isNull);
      expect(
        tester
            .widget<VeSwitch>(find.byWidgetPredicate((w) => w is VeSwitch && w.label == 'Resize / Upscale'))
            .onChanged,
        isNull,
      );
      h.edit(tester, (r) => r.withVideo((v) => v.copyWith(extra: '')));
      await tester.pumpAndSettle();
      expect(h.data(tester).recipe.video.filters.single.width, 1280);
      expect(h.data(tester).compiled.value!.filterControl, 'structured');
      expect(tester.widget<VeButton>(find.widgetWithText(VeButton, 'Edit')).onPressed, isNotNull);
    });

    testWidgets('$context unknown input never borrows sample rounding or aspect errors for filters', (tester) async {
      final h = FiltersHarness(core, popup: popup);
      await h.pump(tester, filter: VideoFilter(width: 2000, height: 1000), expanded: true);
      // The command preview deliberately uses sample media, but the filter
      // section and its draft dialog have no actual source dimensions yet.
      final geometryMessage = find.byWidgetPredicate(
        (w) => w is VeMessage && (w.text.contains('rounded down') || w.text.contains('aspect ratio cannot fit')),
      );
      expect(geometryMessage, findsNothing);
      await h.tap(tester, find.bySemanticsLabel('Edit resize filter'));
      expect(geometryMessage, findsNothing);
      expect(tester.widget<VeButton>(find.widgetWithText(VeButton, 'Apply')).onPressed, isNotNull);
      await h.tap(tester, find.widgetWithText(VeButton, 'Cancel'));

      h.edit(tester, (r) => r.withVideo((v) => v.copyWith(filters: [v.filters.single.copyWith(width: 2)])));
      await tester.pumpAndSettle();
      expect(geometryMessage, findsNothing);
      await h.tap(tester, find.bySemanticsLabel('Edit resize filter'));
      expect(geometryMessage, findsNothing);
      expect(tester.widget<VeButton>(find.widgetWithText(VeButton, 'Apply')).onPressed, isNotNull);
      await h.apply(tester);
      expect(h.data(tester).paths.mediaIsSample, isTrue);
      expect(h.data(tester).issues.where((i) => i.id == 'V-FILTER-ASPECT' || i.id == 'V-FILTER-ROUNDING'), isEmpty);
      if (popup) {
        final apply = find.widgetWithText(VeButton, 'Apply to template');
        expect(tester.widget<VeButton>(apply).onPressed, isNotNull);
        await h.tap(tester, apply);
        final result = h.sessions.resultFor('filters');
        expect(result!.action, 'apply');
        expect(result.recipe!.video.filters.single.width, 2);
        expect(result.recipe!.video.filters.single.height, 1000);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('actual project aspect errors still block Apply to template', (tester) async {
    final h = FiltersHarness(core, popup: true);
    await h.pump(
      tester,
      filter: VideoFilter(width: 2, height: 1000),
      expanded: true,
      media: MediaDescription(
        video: VideoMedia(width: 1920, height: 1080, fps: [30, 1]),
        audio: AudioMedia(),
      ),
    );
    expect(h.data(tester).paths.mediaIsSample, isFalse);
    expect(h.data(tester).issues.where((i) => i.id == 'V-FILTER-ASPECT' && i.level == IssueLevel.error), isNotEmpty);
    expect(tester.widget<VeButton>(find.widgetWithText(VeButton, 'Apply to template')).onPressed, isNull);
    expect(h.sessions.resultFor('filters'), isNull);
  });

  testWidgets('actual input rounding remains visible in the filter section and editor', (tester) async {
    final h = FiltersHarness(core, popup: true);
    await h.pump(
      tester,
      filter: VideoFilter(width: 2000, height: 1000),
      expanded: true,
      media: MediaDescription(
        video: VideoMedia(width: 1920, height: 1080, fps: [30, 1]),
        audio: AudioMedia(),
      ),
    );
    final rounding = find.byWidgetPredicate((w) => w is VeMessage && w.text.contains('rounded down'));
    expect(rounding, findsOneWidget);
    await h.tap(tester, find.bySemanticsLabel('Edit resize filter'));
    expect(rounding, findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('known non-square input uses core source and padding facts in the popup', (tester) async {
    final h = FiltersHarness(core, popup: true);
    final media = MediaDescription(
      video: VideoMedia(width: 720, height: 576, fps: [25, 1], sar: '16:15'),
      audio: AudioMedia(rate: 48000, channels: 2),
    );
    await h.pump(tester, filter: VideoFilter(width: 1280, height: 720), expanded: true, media: media);
    expect(find.text('720 × 576 → 1280 × 720'), findsOneWidget);
    expect(find.text('960 × 720'), findsOneWidget);
    expect(find.text('Left 160, top 0, right 160, bottom 0 px'), findsOneWidget);
    expect(find.textContaining('Padding is determined from the delivered frames'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
