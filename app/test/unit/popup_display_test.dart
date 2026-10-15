import 'package:flutter_test/flutter_test.dart';
import 'package:ve_services/ve_services.dart';
import 'package:vegas_encoder/design/components/signal_path/signal_path_model.dart';
import 'package:vegas_encoder/features/popup/display.dart';
import 'package:vegas_encoder/features/presets/save_check.dart';
import 'package:vegas_encoder/state/editor.dart' show CoreResult;
import 'package:vegas_encoder/state/popup.dart';

/// The popup's display mapping (UI_SPEC §4) on hand-built states and the
/// native core's catalog. The differences themselves are the core's.
void main() {
  late EditSessionRequest b0;
  late ProfileCatalog catalog;
  late Preset rev6;

  setUpAll(() async {
    b0 = await FakeEditSessionService().readRequest('b0-session');
    catalog = NativeVeCore().profiles();
    rev6 = (await FakePresetLibrary().get('yt-h264'))!;
  });

  PopupState state({Origin? origin, OriginLibrary? library, Recipe? base}) => PopupState(
    request: b0,
    opened: b0.recipe,
    recipe: b0.recipe,
    origin: origin ?? b0.origin,
    base: base ?? b0.baseRecipe,
    library: library ?? OriginFound(rev6),
  );

  group('origin line, UI_SPEC §4', () {
    test('unchanged: from preset X, revision 5', () {
      final current = state(library: OriginFound(rev6.copyWith(revision: 5)));
      final line = originLine(current, local: 0);
      expect(line.state, OriginState.unchanged);
      expect(line.text, 'From preset YouTube upload, H.264, revision 5.');
      expect(line.showChanges, isFalse);
      expect(line.updateFromLibrary, isFalse);
    });

    test('local changes: “2 changes in this template”, and Show changes', () {
      final line = originLine(state(library: OriginFound(rev6.copyWith(revision: 5))), local: 2);
      expect(line.state, OriginState.localChanges);
      expect(line.text, 'From YouTube upload, H.264, revision 5. 2 changes in this template.');
      expect(line.changesSentence, '2 changes in this template');
      expect(line.showChanges, isTrue);
      expect(originLine(state(), local: 1).changesSentence, '1 change in this template');
    });

    test('library is newer: its revision, and Update from library', () {
      final line = originLine(state(), local: 2);
      expect(line.state, OriginState.libraryNewer);
      expect(line.libraryRevision, 6);
      expect(line.updateFromLibrary, isTrue);
      expect(line.showChanges, isTrue, reason: 'both at once (S3)');
    });

    test('origin deleted: the template still has all its settings', () {
      final line = originLine(state(library: const OriginMissing()));
      expect(line.state, OriginState.deleted);
      expect(
        line.text,
        'Preset YouTube upload, H.264 no longer exists in your library. This template still has all its settings.',
      );
    });

    test('no origin: made in VEGAS', () {
      final s = PopupState(
        request: b0,
        opened: b0.recipe,
        recipe: b0.recipe,
        origin: null,
        base: null,
        library: const NoOrigin(),
      );
      expect(originLine(s).state, OriginState.noOrigin);
      expect(originLine(s).text, 'Made in VEGAS.');
    });

    test('an unreadable library says why', () {
      final line = originLine(state(library: const OriginUnreadable('The library folder is locked')));
      expect(line.state, OriginState.unreadable);
      expect(line.text, endsWith('The library couldn’t be read: The library folder is locked.'));
    });

    test('Update “origin” goes from the template’s revision to the library’s next', () {
      expect(updateRevisions(state()), 'revision 5 → 7');
    });
  });

  group('differences', () {
    test('settings are named as the controls name them', () {
      expect(fieldLabel('video.quality'), 'Quality');
      expect(fieldLabel('audio[0].bitrateK'), 'Audio bitrate');
      expect(fieldLabel('extensions.vendor'), 'extensions.vendor', reason: 'unknown paths show as they are');
    });

    test('values read as the controls show them', () {
      final r = b0.recipe;
      expect(fieldValue('video.quality', 17, catalog, r), 'CRF 17');
      expect(fieldValue('video.speed', 'slower', catalog, r), 'slower');
      expect(fieldValue('audio[0].bitrateK', 320, catalog, r), '320 kb/s');
      expect(fieldValue('video.bitrateK', 12000, catalog, r), '12 Mb/s');
      expect(fieldValue('video.bitrateK', 8500, catalog, r), '8.5 Mb/s');
      expect(fieldValue('video.encoder', 'libx265', catalog, r), 'x265');
      expect(fieldValue('container.format', 'mkv', catalog, r), isNot('mkv'));
      expect(fieldValue('video.depth', 10, catalog, r), '10-bit');
      expect(fieldValue('video.gopSec', 2, catalog, r), '2 s');
      expect(fieldValue('video.tune', null, catalog, r), 'Encoder default');
      expect(fieldValue('video.extra', '', catalog, r), 'None');
      expect(fieldValue('audio[0].enabled', false, catalog, r), 'Off');
      expect(fieldValue('command.mode', 'template', catalog, r), 'Advanced');
      expect(fieldValue('audio[0].sampleRate', 'source', catalog, r), 'As the project');
    });

    test('diagram marks: a dot where the template changed, the revision where the library did', () {
      final marks = originMarks(
        local: [FieldDiff(path: 'video.quality', before: 18, after: 17)],
        since: [FieldDiff(path: 'audio[0].bitrateK', before: 256, after: 320)],
        revision: 6,
      );
      expect(marks[SignalNode.video]!.changed, isTrue);
      expect(marks[SignalNode.video]!.libraryRevision, isNull);
      expect(marks[SignalNode.audio]!.libraryRevision, 6);
      expect(marks[SignalNode.audio]!.changed, isFalse);
      expect(
        originMarks(since: [FieldDiff(path: 'video.quality')]),
        isEmpty,
        reason: 'no newer revision, no badge',
      );
    });

    test('“Take library changes, keep mine” needs both lists and no setting in both', () {
      PopupChanges changes(List<String> mine, List<String> theirs) => PopupChanges(
        local: CoreResult.ok([for (final p in mine) FieldDiff(path: p)]),
        since: CoreResult.ok([for (final p in theirs) FieldDiff(path: p)]),
      );
      expect(changes(['video.quality'], ['audio[0].bitrateK']).canMerge, isTrue);
      expect(changes(['audio[0].bitrateK'], ['audio[0].bitrateK']).canMerge, isFalse);
      expect(changes(['video.quality'], []).canMerge, isFalse, reason: 'nothing to take');
      expect(const PopupChanges().canMerge, isFalse);
    });
  });

  test('saving splits the settings’ own errors from the chosen FFmpeg’s (owner decision, 2026-10-15)', () {
    final core = NativeVeCore();
    final bad = b0.recipe.copyWith(video: b0.recipe.video.copyWith(extra: '-c:v libx265'));
    final ffmpegOnly = Issue(
      id: 'L-ENCODER-TEST',
      level: IssueLevel.error,
      field: 'video.encoder',
      message: 'Not in this FFmpeg.',
    );
    final split = saveErrors(core, bad, [ffmpegOnly]);
    expect(split.settings, isNotEmpty, reason: 'Extra arguments can’t choose the encoder');
    expect(split.ffmpeg.map((i) => i.id), ['L-ENCODER-TEST']);
    expect(saveErrors(core, bad, split.settings).ffmpeg, isEmpty, reason: 'an error in both counts once');
    expect(saveErrors(core, b0.recipe, const []).settings, isEmpty);
  });
}
