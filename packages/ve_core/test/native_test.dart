import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:ve_core/ve_core.dart';
import 'b1_argv.dart';

int checks = 0;
void check(bool condition, String message) {
  checks++;
  if (!condition) throw StateError(message);
}

void rejects(void Function() action, String code) {
  try {
    action();
  } on CoreException catch (e) {
    check(e.code == code, 'expected $code, received ${e.code}');
    return;
  }
  throw StateError('Expected $code');
}

bool errors(List<Issue> issues) =>
    issues.any((i) => i.level == IssueLevel.error);
String after(List<String> args, String flag) =>
    args[args.lastIndexOf(flag) + 1];

Future<void> main(List<String> args) async {
  final core = args.isEmpty ? NativeVeCore() : NativeVeCore.open(args.first);
  final fake = FakeVeCore();
  check(!core.version.isFake && core.version.abi == 1, 'real native version');
  check(
    core.profiles().video.length == 12 && core.profiles().audio.length == 11,
    'native curated catalog with measured Windows provenance',
  );
  check(
    core.profiles().provenance.contains('B1 measured Windows x64') &&
        core.profiles().provenance.contains('not VEGAS qualification'),
    'Windows facts retain native-host qualification limits',
  );
  for (final entry in fake.fixtures.asMap().entries) {
    final f = entry.value;
    final result = core.compile(f.recipe, media: f.media, paths: f.paths);
    check(
      !errors(result.issues),
      'built-in compile has no errors: ${f.recipe.id}: ${result.issues.map((i) => i.toJson()).toList()}',
    );
    check(
      result.argv.join('\n') == b1CoreArgv[entry.key].join('\n'),
      'B1 real-core argv parity ${f.recipe.id}',
    );
    check(
      result.argv.last == f.paths.output &&
          result.argv.contains(f.paths.videoPipe),
      'supplied paths preserved',
    );
    check(
      result.display.skip(1).map((t) => t.text).join('\n') ==
          result.argv.join('\n'),
      'display/argv parity',
    );
    final seeded = core.compile(
      f.recipe.copyWith(
        command: f.recipe.command.copyWith(
          mode: 'template',
          template: result.advancedTemplate,
        ),
      ),
      media: f.media,
      paths: f.paths,
    );
    check(
      seeded.argv.join('\n') == result.argv.join('\n'),
      'Basic seed preserves input metadata and argv in Advanced',
    );
    check(
      result.display
          .where((t) => t.role == TokenRole.input || t.role == TokenRole.map)
          .every((t) => t.field == null),
      'owned input/maps are not recipe controls',
    );
    check(
      result.issues
          .expand((i) => i.tokenIndices)
          .every((i) => i >= 0 && i < result.display.length),
      'native token bounds',
    );
    check(
      result.signalPath!.source!.video.bits == 10 &&
          result.signalPath!.source!.audio!.bits == 32,
      'source facts',
    );
    check(
      result.signalPath!.audio.single.outputBits != null,
      'audio precision',
    );
    check(
      core.normalize(f.recipe.toJson()).recipe.toJson().toString() ==
          f.recipe.toJson().toString(),
      'normalize preserves recipe shape and key order',
    );
    check(
      !errors(core.validate(f.recipe, media: f.media)),
      'standalone validate',
    );
    final per = core.estimate(f.recipe, media: f.media);
    final total = core.estimate(f.recipe, media: f.media, durationSec: 600);
    check(
      per.totalBytes == null && per.minTotalBytes == null,
      'length is not media duration',
    );
    check(
      total.totalBytes! > 0 &&
          (total.totalBytes! - per.bytesPerMinute * 10).abs() < .01,
      'typed duration total',
    );
    check(
      total.minTotalBytes! < total.totalBytes! &&
          total.maxTotalBytes! > total.totalBytes!,
      'typed duration range',
    );
    final snapshot = TemplateSnapshot(
      recipe: f.recipe,
      vegasPrefs: f.recipe.vegas,
      writtenBy: 'native-test',
    );
    final payload = core.encodePayload(snapshot);
    final decoded = core.decodePayload(payload);
    check(
      decoded.snapshot != null && decoded.issues.isEmpty && !decoded.migrated,
      'native payload round trip',
    );
    check(
      jsonEncode(decoded.snapshot!.recipe.toJson()) ==
          jsonEncode(jsonDecode(jsonEncode(decoded.snapshot!.recipe.toJson()))),
      'decoded JSON copy',
    );
  }
  final f = fake.fixtures.first;
  final edited = f.recipe.copyWith(
    video: f.recipe.video.copyWith(quality: 17.0),
  );
  final editedResult = core.compile(edited, media: f.media, paths: f.paths);
  check(
    editedResult.inputStreams?.join(',') == 'video,audio',
    'typed native input pipe facts',
  );
  check(
    editedResult.copyWith().inputStreams?.join(',') == 'video,audio',
    'input facts survive typed result copies',
  );
  check(
    editedResult.expectedStreams
            ?.map((s) => '${s.kind}:${s.codec}')
            .join(',') ==
        'video:h264,audio:aac',
    'typed native output verification facts',
  );
  check(
    editedResult.copyWith().expectedStreams?.first.encoder == 'libx264',
    'verification facts survive typed result copies',
  );
  check(
    core.normalize(f.recipe.toJson()).requiredEncoders?.join(',') ==
        'libx264,aac',
    'typed normalization requirements come from native core',
  );
  check(
    after(editedResult.argv, '-crf') == '17' &&
        editedResult.resolved!.quality == 17,
    'live CRF edit reaches native compile',
  );
  check(
    editedResult.resolved!.gopFrames == 60,
    '2 seconds resolves to 60 frames at 30000/1001',
  );
  final bad = core.compile(
    f.recipe.copyWith(video: f.recipe.video.copyWith(quality: 100.0)),
    media: f.media,
    paths: f.paths,
  );
  check(
    errors(bad.issues) &&
        bad.issues.any(
          (i) => i.field == 'video.quality' && i.tokenIndices.length == 2,
        ),
    'invalid quality and exact token references',
  );
  final override = core.compile(
    f.recipe.copyWith(
      video: f.recipe.video.copyWith(extra: '-preset slower -crf 16'),
    ),
    media: f.media,
    paths: f.paths,
  );
  check(
    override.argv.where((a) => a == '-preset').length == 1 &&
        after(override.argv, '-preset') == 'slower',
    'extra replaces speed',
  );
  check(
    override.resolved!.quality == 16 && override.resolved!.speed == 'slower',
    'facts reflect extra overrides',
  );
  check(
    override.display.where((t) => t.text == '-crf').single.field ==
        'video.extra',
    'override provenance',
  );
  check(
    override.overriddenFields.toSet().containsAll([
      'video.speed',
      'video.quality',
    ]),
    'core identifies overridden settings without app option parsing',
  );
  check(
    override.display
            .where((t) => t.text == '-crf' || t.text == '16')
            .every((t) => t.replacedField == 'video.quality') &&
        override.display
            .where((t) => t.text == '-preset' || t.text == 'slower')
            .every((t) => t.replacedField == 'video.speed'),
    'extra option and value retain their replaced control',
  );
  final incompatibleProfile = f.recipe.copyWith(
    video: f.recipe.video.copyWith(depth: 10, profile: 'high'),
  );
  for (final extra in ['-profile:v high10', '-pix_fmt yuv420p']) {
    final replaced = incompatibleProfile.copyWith(
      video: incompatibleProfile.video.copyWith(extra: extra),
    );
    final result = core.compile(replaced, media: f.media, paths: f.paths);
    check(
      !errors(core.validate(replaced, media: f.media)) &&
          !errors(result.issues),
      'final Extra profile/pixel replacement permits a valid command',
    );
    check(
      extra == '-profile:v high10'
          ? result.resolved!.profile == 'high10' && result.resolved!.depth == 10
          : result.resolved!.profile == 'high' && result.resolved!.depth == 8,
      'resolved profile/depth uses the Extra replacement',
    );
  }
  final introducedMismatch = f.recipe.copyWith(
    video: f.recipe.video.copyWith(
      depth: 8,
      profile: 'high',
      extra: '-pix_fmt yuv420p10le',
    ),
  );
  check(
    errors(core.validate(introducedMismatch, media: f.media)) &&
        errors(
          core
              .compile(introducedMismatch, media: f.media, paths: f.paths)
              .issues,
        ),
    'Extra pixel override can introduce an incompatible final H.264 profile',
  );
  final exactFormatCaps = CoreCapabilities(
    installationId: 'exact-format',
    encoders: {
      'libx264': {
        'kind': 'video',
        'options': [],
        'pixelFormats': ['yuv420p', 'yuv420p10le'],
      },
      'aac': {'kind': 'audio', 'options': []},
    },
  );
  final exactFormatRecipe = f.recipe.copyWith(
    video: f.recipe.video.copyWith(
      profile: 'high10',
      extra: '-vf scale=320:180,format=yuv420p10le -pix_fmt +yuv420p10le',
    ),
  );
  final exactFormat = core.compile(
    exactFormatRecipe,
    media: f.media,
    paths: f.paths,
    capabilities: exactFormatCaps,
  );
  check(
    !errors(
          core.validate(
            exactFormatRecipe,
            media: f.media,
            capabilities: exactFormatCaps,
          ),
        ) &&
        !errors(exactFormat.issues),
    'exact pixel-format modifier is accepted with build capabilities',
  );
  check(
    after(exactFormat.argv, '-pix_fmt') == '+yuv420p10le' &&
        exactFormat.resolved!.pixfmt == 'yuv420p10le' &&
        exactFormat.signalPath!.video!.outputBits == 10,
    'literal plus syntax is preserved while format facts use the name',
  );
  for (final format in ['+', '+ve_unknown_format']) {
    final recipe = exactFormatRecipe.copyWith(
      video: exactFormatRecipe.video.copyWith(extra: '-pix_fmt $format'),
    );
    final result = core.compile(recipe, media: f.media, paths: f.paths);
    check(
      !errors(core.validate(recipe, media: f.media)) &&
          result.resolved == null &&
          result.signalPath!.video!.outputBits == null,
      'automatic or unmodeled exact pixel format remains unknown',
    );
  }
  final tags = core.compile(
    f.recipe.copyWith(
      video: f.recipe.video.copyWith(extra: '-colorspace smpte170m'),
    ),
    media: f.media,
    paths: f.paths,
  );
  check(
    tags.display.where((t) => t.text == '-colorspace').length == 2 &&
        tags.argv
            .asMap()
            .entries
            .where((e) => e.value == '-colorspace')
            .every((e) => tags.argv[e.key + 1] == 'smpte170m'),
    'Extra color tags remain metadata on raw input and output',
  );
  final badExtra = core.compile(
    f.recipe.copyWith(video: f.recipe.video.copyWith(extra: '-c:v ffv1')),
    media: f.media,
    paths: f.paths,
  );
  check(errors(badExtra.issues), 'extra cannot override the selected encoder');
  check(
    after(badExtra.argv, '-c:v') == 'libx264',
    'forbidden extra encoder is not emitted',
  );
  final badNumbers = core.compile(
    f.recipe.copyWith(
      video: f.recipe.video.copyWith(extra: '-g abc -b:v nonsense'),
    ),
    media: f.media,
    paths: f.paths,
  );
  check(
    badNumbers.issues.where((i) => i.id == 'L-VALUE').length == 2 &&
        badNumbers.resolved!.gopFrames == null,
    'invalid numeric extra values do not invent frames',
  );
  final unknownPixel = core.compile(
    f.recipe.copyWith(
      video: f.recipe.video.copyWith(extra: '-pix_fmt future_pixel'),
    ),
    media: f.media,
    paths: f.paths,
  );
  check(
    unknownPixel.signalPath!.video!.outputBits == null &&
        unknownPixel.resolved == null,
    'unknown pixel facts do not claim Basic depth',
  );
  final extraIssues = core.compile(
    f.recipe.copyWith(
      video: f.recipe.video.copyWith(extra: '-preset p9 -crf 16'),
    ),
    media: f.media,
    paths: f.paths,
  );
  check(
    extraIssues.issues
            .firstWhere((i) => i.id == 'L-VALUE')
            .tokenIndices
            .map((i) => extraIssues.display[i].text)
            .join(' ') ==
        'p9',
    'extra issue points only at its invalid value',
  );
  final off = core.compile(
    f.recipe.copyWith(audio: [f.recipe.audio.single.copyWith(enabled: false)]),
    media: f.media.copyWith(audio: null),
    paths: f.paths.copyWith(audioPipe: null),
  );
  check(
    !errors(off.issues) &&
        !off.argv.contains('-c:a') &&
        !off.argv.contains('1:a:0') &&
        off.signalPath!.audio.isEmpty,
    'audio off needs no pipe',
  );
  final missingAudio = core.compile(
    f.recipe,
    media: f.media.copyWith(audio: null),
    paths: f.paths.copyWith(audioPipe: null),
  );
  check(
    missingAudio.issues.any((i) => i.id == 'V-AUDIO-INPUT'),
    'enabled audio without source blocked',
  );
  final noMux = core.compile(
    f.recipe.copyWith(container: ContainerSettings(format: 'webm')),
    media: f.media,
    paths: f.paths.copyWith(output: 'out.webm'),
  );
  check(
    noMux.signalPath!.video!.containerSupport == 'no' &&
        noMux.signalPath!.audio.single.containerSupport == 'no',
    'broken video and audio mux facts',
  );
  check(
    noMux.issues
        .where((i) => i.id.startsWith('V-CONTAINER-'))
        .every((i) => i.tokenIndices.length >= 4),
    'mux issue points at muxer and encoder',
  );
  final prores = fake.fixtures.firstWhere((f) => f.recipe.id == 'prores-hq');
  final pr = core.compile(
    prores.recipe,
    media: prores.media,
    paths: prores.paths,
  );
  check(
    pr.signalPath!.audio.single.outputFormat == 's32' &&
        pr.signalPath!.audio.single.outputBits == 24,
    'PCM useful precision is 24, carrier 32',
  );
  check(
    pr.signalPath!.video!.conversionNote!.contains('interpolated'),
    'conversion note is structured fallback copy',
  );
  final nativePixels = fake.fixtures.firstWhere(
    (f) => f.recipe.id == 'yt-hevc-nv',
  );
  check(
    core
            .compile(
              nativePixels.recipe,
              media: nativePixels.media,
              paths: nativePixels.paths,
            )
            .signalPath!
            .video!
            .conversion ==
        false,
    'direct P010 path',
  );
  final profiles = core.profiles();
  final pcmRecipe = f.recipe.copyWith(
    audio: [
      f.recipe.audio.first.copyWith(encoder: 'pcm_s24le', mode: 'lossless'),
    ],
  );
  final buildCaps = CoreCapabilities(
    installationId: 'b1',
    libavformatMajor: 59,
    encoders: {
      'libx264': {'kind': 'video', 'options': []},
      'pcm_s24le': {'kind': 'audio', 'options': []},
    },
  );
  final oldPcm = core.compile(
    pcmRecipe,
    media: f.media,
    paths: f.paths,
    capabilities: buildCaps,
  );
  final newPcm = core.compile(
    pcmRecipe,
    media: f.media,
    paths: f.paths,
    capabilities: buildCaps.copyWith(libavformatMajor: 63),
  );
  check(
    errors(oldPcm.issues) &&
        oldPcm.signalPath!.audio.single.containerSupport == 'no',
    'old build MP4 PCM rejection reaches FFI',
  );
  check(
    !errors(newPcm.issues) &&
        newPcm.signalPath!.audio.single.containerSupport == 'warn',
    'new build MP4 PCM playback caveat reaches FFI',
  );
  final caps = CoreCapabilities(
    installationId: 'test',
    encoders: {
      'libx264': {
        'kind': 'video',
        'availability': {'state': 'missing'},
        'options': [],
      },
      'aac': {
        'kind': 'audio',
        'availability': {'state': 'ok'},
        'options': [],
      },
    },
  );
  final unavailable = core.compile(
    f.recipe,
    media: f.media,
    paths: f.paths,
    capabilities: caps,
  );
  check(
    unavailable.issues.any(
      (i) => i.id == 'V-ENC-MISSING' && i.tokenIndices.length == 2,
    ),
    'supplied capability availability honored',
  );
  check(profiles.containers.length == 5, 'native containers');
  final avr = core.compile(
    f.recipe.copyWith(
      command: CommandSettings(
        mode: 'template',
        template:
            'ffmpeg -hide_banner {inputs} -map {v} -map {a} -c:v libx265 -crf 18 -pix_fmt yuv420p10le -g {gop:2s} -c:a aac -f matroska {output}',
      ),
    ),
    media: f.media,
    paths: f.paths.copyWith(
      output: r'C:\出力\movie name.mkv',
      project: '🧪 Project',
    ),
  );
  check(!errors(avr.issues), 'advanced macro compile');
  check(
    avr.argv.last == r'C:\出力\movie name.mkv' && after(avr.argv, '-g') == '60',
    'advanced delivered macros and Unicode path',
  );
  check(
    avr.resolved == null &&
        avr.signalPath!.video!.outputFormat == 'yuv420p10le',
    'advanced reads active command, not Basic',
  );
  check(
    avr.argv.where((a) => a == '-hide_banner').length == 1 &&
        avr.argv.where((a) => a == '-nostdin').length == 1,
    'globals deduplicated',
  );
  final unspecified = core.compile(
    f.recipe.copyWith(
      command: CommandSettings(mode: 'template', template: '{inputs} {output}'),
    ),
    media: f.media,
    paths: f.paths,
  );
  check(
    unspecified.signalPath!.video!.outputBits == null &&
        unspecified.signalPath!.video!.containerSupport == 'unknown',
    'unknown advanced facts stay unknown',
  );
  final otherInput = core.compile(
    f.recipe.copyWith(
      command: CommandSettings(
        mode: 'template',
        template:
            '{inputs} -i logo.png -map 2:v -c:v libx264 -pix_fmt yuv420p {output}',
      ),
    ),
    media: f.media,
    paths: f.paths,
  );
  check(
    otherInput.signalPath!.source!.video.bits == 10 &&
        otherInput.signalPath!.video!.inputBits == null &&
        otherInput.signalPath!.video!.outputBits == null,
    'extra input selection is not presented as known VEGAS stream facts',
  );
  final multiOutput = core.compile(
    f.recipe.copyWith(
      command: CommandSettings(
        mode: 'template',
        template:
            '{inputs} -c:v libx265 -pix_fmt yuv420p10le {output} -c:v libx264 -pix_fmt yuv420p another.mp4',
      ),
    ),
    media: f.media,
    paths: f.paths,
  );
  check(
    multiOutput.signalPath!.video!.outputBits == null &&
        multiOutput.issues.any((i) => i.id == 'L-OUTPUTS'),
    'multiple outputs have unknown primary stream facts',
  );
  final inactiveAudio = core.compile(
    f.recipe.copyWith(
      audio: [
        f.recipe.audio.single.copyWith(sampleRate: 96000, channels: 'mono'),
      ],
      command: CommandSettings(
        mode: 'template',
        template: '{inputs} -c:v libx264 -c:a pcm_f32le -f matroska {output}',
      ),
    ),
    media: f.media,
    paths: f.paths,
  );
  check(
    inactiveAudio.signalPath!.audio.single.conversion == false,
    'Advanced audio facts ignore inactive Basic rate/channel controls',
  );
  const lintText = '🧪 {inputs} -c:v libx264 -preset p9 {output}';
  final diagnostics = core.lint(lintText);
  check(
    diagnostics.any(
      (d) =>
          d.id == 'L-VALUE' &&
          d.start == lintText.indexOf('p9') &&
          d.end == lintText.indexOf('p9') + 2,
    ),
    'UTF-16 astral offsets',
  );
  check(
    core.lint('').where((d) => d.level == IssueLevel.error).length == 2,
    'missing macro lint',
  );
  check(
    core.lint('{inputs} {inputs} {output}').any((d) => d.id == 'L-MACRO-COUNT'),
    'duplicate owned inputs blocked',
  );
  check(
    core
        .lint('-i logo.png {inputs} {output}')
        .any((d) => d.id == 'L-INPUT-ORDER'),
    'extra inputs cannot renumber the owned VEGAS inputs',
  );
  final continued = core.compile(
    f.recipe.copyWith(
      command: CommandSettings(
        mode: 'template',
        template: '{inputs}\n-c:v libx264 -crf 18\\\n -c:a aac {output}',
      ),
    ),
    media: f.media,
    paths: f.paths,
  );
  check(
    after(continued.argv, '-crf') == '18',
    'pasted trailing continuation removed',
  );
  final literalPath = r'C:\Renders\literal {project}.mp4';
  final literal = core.compile(
    f.recipe.copyWith(
      command: CommandSettings(
        mode: 'template',
        template: '{inputs} -metadata title={project} {output}',
      ),
    ),
    media: f.media,
    paths: f.paths.copyWith(output: literalPath, project: 'literal {v}'),
  );
  check(
    literal.argv.last == literalPath &&
        after(literal.argv, '-metadata') == 'title=literal {v}',
    'macro values and caller paths are never recursively expanded',
  );
  rejects(
    () => core.compile(
      f.recipe.copyWith(
        command: CommandSettings(
          mode: 'template',
          template: '{inputs} -metadata title={project}{project} {output}',
        ),
      ),
      media: f.media,
      paths: f.paths.copyWith(project: 'x' * 600000),
    ),
    'COMMAND-LIMIT',
  );
  rejects(
    () => core.compile(
      f.recipe,
      media: f.media.copyWith(video: f.media.video.copyWith(width: 0)),
      paths: f.paths,
    ),
    'MEDIA',
  );
  check(
    core
        .lint('{inputs} -c:v libx264 -future_opt abc {output}')
        .any((d) => d.id == 'L-OPTION' && d.level == IssueLevel.warn),
    'unknown private option warns',
  );
  final completionText = '{inputs} -c:v libx264 -preset sl';
  final complete = core.complete(completionText, completionText.length);
  check(
    complete.kind == 'value' &&
        complete.items.any((i) => i.value == 'slow') &&
        complete.start == completionText.length - 2,
    'live value completion replacement span',
  );
  rejects(() => core.complete('🧪', 1), 'CARET-BOUNDARY');
  rejects(() => core.complete('x', 2), 'CARET-BOUNDARY');
  rejects(
    () => core.estimate(f.recipe, media: f.media, durationSec: -1),
    'DURATION',
  );
  final bitrate = f.recipe.copyWith(
    video: f.recipe.video.copyWith(mode: 'abr', bitrateK: 8000),
  );
  final size = core.estimate(bitrate, media: f.media, durationSec: 600);
  check(
    !size.approx && size.totalBytes == 624000000 && size.minTotalBytes == null,
    'bitrate size uses decimal kilobits, no fictional range',
  );
  check(
    !core
        .estimate(
          bitrate.copyWith(video: bitrate.video.copyWith(extra: '-crf 18')),
          media: f.media,
          durationSec: 600,
        )
        .available,
    'conflicting extra rate control has no formula estimate',
  );
  final nullDefaults = f.recipe.copyWith(
    video: f.recipe.video.copyWith(
      quality: null,
      speed: null,
      profile: null,
      depth: null,
    ),
  );
  check(
    core
            .compile(nullDefaults, media: f.media, paths: f.paths)
            .resolved!
            .quality ==
        18,
    'null resolves at compile',
  );
  check(
    core.normalize(nullDefaults.toJson()).recipe.video.quality == null,
    'normalize does not save defaults',
  );
  final preservedJson = f.recipe.toJson();
  preservedJson['future'] = {
    'nested': [1, '🧪'],
  };
  (preservedJson['audio'] as List).first['future'] = {'keep': true};
  final preserved = Recipe.fromJson(preservedJson);
  final delta = core.diff(
    preserved,
    preserved.copyWith(audio: [preserved.audio.single.copyWith(bitrateK: 256)]),
  );
  check(
    delta.length == 1 &&
        delta.single.path == 'audio[0].bitrateK' &&
        delta.single.before == 320 &&
        delta.single.after == 256,
    'audio row diff paths',
  );
  check(
    core
        .diff(f.recipe, f.recipe.copyWith(name: 'renamed', notes: 'notes'))
        .isEmpty,
    'diff excludes library metadata',
  );
  final snapshot = TemplateSnapshot(
    recipe: preserved,
    vegasPrefs: preserved.vegas,
    origin: Origin(presetId: 'yt-h264', revision: 6, name: 'Original'),
    writtenBy: 'native',
  );
  final bytes = core.encodePayload(snapshot);
  final original = Uint8List.fromList(bytes);
  final read = core.decodePayload(bytes);
  check(
    (read.snapshot!.recipe.data['future'] as Map)['nested'].toString().contains(
      '🧪',
    ),
    'unknown nested payload data',
  );
  bytes[12] ^= 1;
  check(
    core.decodePayload(bytes).issues.any((i) => i.id == 'P-CRC'),
    'payload CRC failure',
  );
  check(
    core.decodePayload(original).snapshot!.origin!.revision == 6,
    'payload source/output copies independent',
  );
  for (final length in [0, 4, 31, 32, original.length - 1])
    check(
      core
              .decodePayload(Uint8List.fromList(original.take(length).toList()))
              .snapshot ==
          null,
      'truncated payload $length',
    );
  final future = Uint8List.fromList(original)..[4] = 2;
  check(
    core.decodePayload(future).issues.single.id == 'P-VERSION',
    'future payload rejected without migration',
  );
  final proof = Uint8List.fromList(original)..[0] = 0;
  check(
    core.decodePayload(proof).issues.single.id == 'P-LEGACY',
    'proof payload rejected',
  );
  final oversized = preserved.copyWith(notes: 'x' * 20000);
  rejects(
    () => core.encodePayload(
      TemplateSnapshot(recipe: oversized, vegasPrefs: oversized.vegas),
    ),
    'PAYLOAD-LIMIT',
  );
  final request = jsonMap(
    jsonDecode(
      File('../../schema/fixtures/b0/request.json').readAsStringSync(),
    ),
  );
  check(
    jsonMaps(core.validateSessionRequest(request)['issues']).isEmpty,
    'pure C4 request checks',
  );
  final cancel = {'protocol': 1, 'sessionId': 'test', 'action': 'cancel'};
  check(
    jsonMaps(core.validateSessionResult(cancel)['issues']).isEmpty,
    'pure cancel serialization',
  );
  check(
    jsonMaps(
      core.validateSessionResult({
        ...cancel,
        'recipe': f.recipe.toJson(),
      })['issues'],
    ).any((i) => i['id'] == 'S-CANCEL'),
    'cancel cannot serialize a draft',
  );
  final concurrent = await Future.wait(
    List.generate(
      4,
      (_) => Isolate.run(() {
        final worker = NativeVeCore();
        final f = FakeVeCore().fixtures.first;
        return worker
            .compile(
              f.recipe.copyWith(video: f.recipe.video.copyWith(quality: 19.0)),
              media: f.media,
              paths: f.paths,
            )
            .resolved!
            .quality;
      }),
    ),
  );
  check(
    concurrent.every((q) => q == 19),
    'isolate-local native consumers share only immutable core data',
  );
  final watch = Stopwatch()..start();
  for (var i = 0; i < 500; i++)
    core.compile(edited, media: f.media, paths: f.paths);
  watch.stop();
  print(
    'Native core: $checks checks passed; warm end-to-end FFI compile mean ${(watch.elapsedMicroseconds / 500 / 1000).toStringAsFixed(3)} ms (500 calls). No VEGAS or encoder process.',
  );
}
