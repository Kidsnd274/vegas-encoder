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
      result.display
          .where(
            (t) => [
              TokenRole.exe,
              TokenRole.global,
              TokenRole.input,
              TokenRole.map,
              TokenRole.output,
            ].contains(t.role),
          )
          .every((t) => t.field == null),
      'product-owned tokens have no editable field',
    );
    check(
      result.display
          .where(
            (t) =>
                t.role == TokenRole.video ||
                t.role == TokenRole.audio ||
                t.role == TokenRole.mux,
          )
          .every((t) => t.field != null),
      'all generated settings have provenance',
    );
    check(
      result.issues
          .expand((i) => i.tokenIndices)
          .every((i) => i >= 0 && i < result.display.length),
      'compile issue display bounds',
    );
    check(
      core.validate(recipe).every((i) => i.tokenIndices.isEmpty),
      'standalone validation has no display indexes',
    );
    final signal = result.signalPath!;
    check(
      signal.video!.inputBits == 10 && signal.audio.single.inputBits == 32,
      'core supplies source precision without app format parsing',
    );
    check(
      signal.video!.outputFormat == result.resolved!.pixfmt &&
          signal.video!.outputBits == result.resolved!.depth,
      'resolved video facts agree',
    );
    check(
      signal.audio.single.outputFormat != null &&
          signal.audio.single.outputBits != null,
      'audio output format and useful bits',
    );
    check(
      signal.video!.containerSupport == 'ok' &&
          signal.audio.single.containerSupport == 'ok',
      'built-in mux facts',
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
  final constructedMedia = MediaDescription(
    video: VideoMedia(
      width: f.media.video.width,
      height: f.media.video.height,
      fps: f.media.video.fps,
      pixfmt: f.media.video.pixfmt,
      sar: f.media.video.sar,
    ),
    audio: AudioMedia(
      rate: f.media.audio!.rate,
      channels: f.media.audio!.channels,
      sampleFmt: f.media.audio!.sampleFmt,
    ),
    durationSec: f.media.durationSec,
  );
  final constructedPaths = CompilePaths(
    ffmpeg: f.paths.ffmpeg,
    videoPipe: f.paths.videoPipe,
    audioPipe: f.paths.audioPipe,
    output: f.paths.output,
    project: f.paths.project,
  );
  check(
    core
            .compile(f.recipe, media: constructedMedia, paths: constructedPaths)
            .argv
            .last ==
        f.paths.output,
    'empty extensions and absent extensions match across nested media/path constructors',
  );
  check(
    constructedMedia.video.toJson().containsKey('extensions'),
    'fake matching does not mutate model serialization',
  );
  throwsCode(
    () => core.compile(
      f.recipe,
      media: constructedMedia.copyWith(extensions: {'realChange': true}),
      paths: constructedPaths,
    ),
    'B0-FIXTURE-MISSING',
  );
  final missingEncoder = core.compile(
    f.recipe,
    media: f.media,
    paths: f.paths,
    capabilities: CoreCapabilities(installationId: 'btbn-lgpl-8.0'),
  );
  final pointed = missingEncoder.issues.firstWhere(
    (i) => i.id == 'V-ENC-MISSING',
  );
  check(
    pointed.tokenIndices.length == 2 &&
        pointed.tokenIndices
                .map((i) => missingEncoder.display[i].text)
                .join(' ') ==
            '-c:v libx264',
    'capability-specific error points to emitted encoder pair',
  );
  final qualityTokens = f.compiled.display.where(
    (t) => t.field == 'video.quality',
  );
  check(
    qualityTokens.map((t) => t.text).join(' ') == '-crf 18',
    'click-to-field points at flag and value',
  );
  final nv = core.fixtures.firstWhere((f) => f.recipe.id == 'yt-hevc-nv');
  final opus = core.fixtures.firstWhere((f) => f.recipe.id == 'av1-small');
  check(
    opus.compiled.display
            .where((t) => t.field == 'audio[0].mode')
            .map((t) => t.text)
            .join(' ') ==
        '-vbr on',
    'profile-generated bitrate-mode constant points to mode, not inactive VBR control',
  );
  check(
    nv.compiled.signalPath!.video!.conversion == false,
    'native P010 path explicitly has no conversion',
  );
  final prores = core.fixtures.firstWhere((f) => f.recipe.id == 'prores-hq');
  check(
    prores.compiled.signalPath!.video!.chromaChanged == true &&
        prores.compiled.signalPath!.video!.outputChroma == '4:2:2',
    'chroma change is data',
  );
  check(
    prores.compiled.signalPath!.audio.single.outputFormat == 's32' &&
        prores.compiled.signalPath!.audio.single.outputBits == 24,
    '24-bit PCM precision differs from its carrier width',
  );
  final floatPcm = core.fixtures.firstWhere(
    (f) => f.recipe.id == 'ffv1-master',
  );
  check(
    floatPcm.compiled.signalPath!.audio.single.conversion == false,
    'raw f32le and canonical flt are the same sample representation',
  );

  final sparseToken = CommandToken.fromJson({'text': 'ffmpeg', 'role': 'exe'});
  final sparseIssue = Issue.fromJson({'id': 'future', 'message': 'future'});
  final sparseCompile = CompileResult.fromJson({
    'executable': 'ffmpeg',
    'argv': [],
  });
  final sparseFacts = StreamSignalFacts.fromJson({});
  check(
    sparseToken.field == null && !sparseToken.toJson().containsKey('field'),
    'old tokens preserve missing provenance',
  );
  check(
    sparseIssue.tokenIndices.isEmpty &&
        !sparseIssue.toJson().containsKey('tokenIndices'),
    'old issues preserve missing references',
  );
  check(
    sparseCompile.signalPath == null &&
        !sparseCompile.toJson().containsKey('signalPath'),
    'old compile facts are unavailable, not inferred',
  );
  check(
    sparseFacts.conversion == null &&
        sparseFacts.chromaChanged == null &&
        sparseFacts.containerSupport == 'unknown',
    'unknown is not false or supported',
  );
  check(
    CommandToken(
          text: '18',
          field: 'video.quality',
        ).copyWith(field: null).field ==
        null,
    'explicit null clears provenance',
  );
  final tokenList = <int>[2, 3];
  final ownedIssue = Issue(
    id: 'test',
    message: 'test',
    tokenIndices: tokenList,
  );
  tokenList.clear();
  check(ownedIssue.tokenIndices.join(',') == '2,3', 'token references copied');
  try {
    ownedIssue.tokenIndices.add(4);
    throw StateError('mutable token indexes');
  } on UnsupportedError {
    checks++;
  }
  final factsJson = f.compiled.signalPath!.toJson();
  (factsJson['video'] as Map)['future'] = {
    'nested': [1],
  };
  final ownedFacts = SignalPathFacts.fromJson(factsJson);
  ((factsJson['video'] as Map)['future'] as Map).clear();
  final blockedFacts = ownedFacts.copyWith(
    video: ownedFacts.video!.copyWith(containerSupport: 'no'),
    audio: [ownedFacts.audio.single.copyWith(containerSupport: 'warn')],
  );
  check(
    (blockedFacts.video!.toJson()['future'] as Map).isNotEmpty,
    'nested unknown signal facts survive immutable editing',
  );
  final injectedFacts = FakeVeCore(
    fixtures: [
      CoreFixture(
        recipe: f.recipe,
        media: f.media,
        paths: f.paths,
        normalized: f.normalized,
        compiled: f.compiled.copyWith(
          signalPath: blockedFacts,
          issues: [
            Issue(
              id: 'test',
              message: 'Untranslated message',
              tokenIndices: [1],
            ),
          ],
        ),
        estimate: f.estimate,
        validations: f.validations,
      ),
    ],
  );
  final injectedResult = injectedFacts.compile(
    f.recipe,
    media: f.media,
    paths: f.paths,
  );
  check(
    injectedResult.signalPath!.video!.containerSupport == 'no' &&
        injectedResult.signalPath!.audio.single.containerSupport == 'warn',
    'injected per-stream mux facts do not depend on issue text',
  );
  check(
    injectedResult.copyWith(signalPath: null).signalPath == null,
    'explicit null clears signal path',
  );
  check(
    ownedFacts.copyWith(video: null, audio: <StreamSignalFacts>[]).video ==
            null &&
        ownedFacts.copyWith(audio: <StreamSignalFacts>[]).audio.isEmpty,
    'disabled streams have no facts',
  );
  try {
    ownedFacts.audio.clear();
    throw StateError('mutable signal audio');
  } on UnsupportedError {
    checks++;
  }
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
