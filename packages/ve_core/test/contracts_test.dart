import 'dart:convert';
import 'dart:typed_data';
import 'package:ve_core/ve_core.dart';

int checks = 0;
void check(bool condition, String message) {
  checks++;
  if (!condition) throw StateError(message);
}

void throwsCode(void Function() action, String code) {
  try {
    action();
  } on CoreException catch (e) {
    check(e.code == code, 'wrong core error');
    return;
  }
  throw StateError('Expected $code');
}

void main() {
  final core = FakeVeCore();
  check(core.version.isFake && core.version.abi == 1, 'fake version');
  check(jsonMaps(b0Fixtures()['fixtures']).length == 6, 'six built-ins');
  check(
    core.profiles().video.length == 12 && core.profiles().audio.length == 11,
    'profile catalog',
  );
  for (final fixture in core.fixtures) {
    final recipe = fixture.recipe;
    check(recipe.audio.length == 1, 'one audio row');
    final result = core.compile(
      recipe,
      media: fixture.media,
      paths: fixture.paths,
    );
    check(result.argv.contains(fixture.paths.videoPipe), 'pipe/path agreement');
    check(result.argv.last == fixture.paths.output, 'output/path agreement');
    check(
      result.display.first.role == TokenRole.exe,
      'executable display role',
    );
    check(
      !result.argv.contains(result.executable),
      'executable excluded from argv',
    );
    check(
      core.validate(recipe).any((v) => v.id == 'V-UNTESTED'),
      'qualification notice',
    );
    check(
      jsonEncode(core.normalize(recipe.toJson()).recipe.toJson()) ==
          jsonEncode(recipe.toJson()),
      'fixture round trip',
    );
    check(
      core.estimate(recipe, media: fixture.media).totalBytes == null,
      'unknown duration',
    );
    check(
      core.estimate(recipe, media: fixture.media).bytesPerMinute > 0,
      'per-minute estimate',
    );
    check(
      core
          .lint(result.advancedTemplate)
          .every(
            (d) => d.start >= 0 && d.end <= result.advancedTemplate.length,
          ),
      'UTF-16 diagnostic bounds',
    );
  }
  final f = core.fixtures.first;
  throwsCode(
    () => core.compile(
      f.recipe.copyWith(video: f.recipe.video.copyWith(quality: 19.0)),
      media: f.media,
      paths: f.paths,
    ),
    'B0-FIXTURE-MISSING',
  );
  throwsCode(
    () => core.compile(
      f.recipe,
      media: f.media,
      paths: f.paths.copyWith(output: 'different.mp4'),
    ),
    'B0-FIXTURE-MISSING',
  );
  throwsCode(
    () => core.estimate(f.recipe, media: f.media, durationSec: 600),
    'B0-FIXTURE-MISSING',
  );
  check(
    core
        .validate(
          f.recipe,
          capabilities: CoreCapabilities(installationId: 'btbn-lgpl-8.0'),
        )
        .any((i) => i.id == 'V-ENC-MISSING'),
    'LGPL missing x264 fixture',
  );
  check(
    core.lint('').where((i) => i.level == IssueLevel.error).length == 2,
    'missing macros fixture',
  );
  final text = 'ffmpeg {inputs} -c:v libx264 -preset ';
  check(
    core.complete(text, text.length).items.any((i) => i.value == 'slow'),
    'completion fixture',
  );
  try {
    core.complete(text, text.length + 1);
    throw StateError('bad caret accepted');
  } on RangeError {
    checks++;
  }

  final json = f.recipe.toJson();
  json['future'] = <String, Object?>{
    'items': <Object?>[1, '🧪'],
  };
  (json['video'] as Map)['futureOption'] = {'nested': true};
  final preserved = Recipe.fromJson(json);
  (json['future'] as Map)['items'] = [];
  final edited = preserved.copyWith(
    name: 'Renamed',
    video: preserved.video.copyWith(quality: null),
  );
  check(
    jsonEncode(edited.toJson()['future']).contains('🧪'),
    'deep copy at construction',
  );
  check(
    (edited.toJson()['video'] as Map)['futureOption'] != null,
    'nested unknown survives editing',
  );
  check(edited.video.quality == null, 'explicit null clears quality');
  check(preserved.video.quality == 18, 'source unaffected');
  final copy = edited.toJson();
  (copy['future'] as Map).clear();
  check((edited.toJson()['future'] as Map).isNotEmpty, 'toJson deep copy');
  final sparse = VideoSettings.fromJson({
    'encoder': 'libx264',
    'future': 'keep',
  });
  check(
    sparse.quality == null && !sparse.toJson().containsKey('quality'),
    'reading default preserves absent',
  );
  check(
    sparse.enabled && !sparse.toJson().containsKey('enabled'),
    'reading structural default preserves absent',
  );
  try {
    f.recipe.tags.add('bad');
    throw StateError('mutable tags');
  } on UnsupportedError {
    checks++;
  }
  try {
    JsonMap bad = {'bad': double.nan};
    Recipe.fromJson(bad);
    throw StateError('NaN accepted');
  } on FormatException {
    checks++;
  }

  final snapshot = TemplateSnapshot(
    recipe: f.recipe,
    vegasPrefs: f.recipe.vegas,
  );
  final bytes = Uint8List.fromList([1, 2, 3, 4]);
  final payload = PayloadResult(snapshot: snapshot);
  final injected = FakeVeCore(
    encodedPayloadFixtures: {FakeVeCore.snapshotKey(snapshot): bytes},
    decodedPayloadFixtures: {base64Encode(bytes): payload},
  );
  bytes[0] = 9;
  final returned = injected.encodePayload(snapshot);
  check(returned[0] == 1, 'payload input copied');
  returned[0] = 8;
  check(injected.encodePayload(snapshot)[0] == 1, 'payload output copied');
  check(
    injected
            .decodePayload(Uint8List.fromList([1, 2, 3, 4]))
            .snapshot!
            .recipe
            .id ==
        f.recipe.id,
    'injected decode',
  );
  check(
    core.encodePayload(snapshot).sublist(0, 4).join(',') == '86,69,110,99',
    'payload envelope fixture marker',
  );
  check(
    core.decodePayload(core.encodePayload(snapshot)).snapshot!.recipe.id ==
        f.recipe.id,
    'default payload fixture',
  );
  check(core.diff(f.recipe, f.recipe).isEmpty, 'identical recipe diff fixture');
  print('ve_core: $checks contract checks passed (fixtures only).');
}
