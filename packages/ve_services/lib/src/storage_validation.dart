import 'package:ve_core/ve_core.dart';
import 'api.dart';
import 'models.dart';
import 'storage.dart';

void choice(JsonMap data, String key, List<String> choices) {
  if (!choices.contains(data[key])) invalid('Unsupported $key value.');
}

void validateInstallation(JsonMap data) {
  validateExtensions(data);
  for (final key in [
    'id',
    'label',
    'path',
    'ffprobePath',
    'source',
    'version',
  ]) {
    stringField(data, key);
  }
  for (final key in ['build', 'license']) {
    stringField(data, key, required: false);
  }
  boolField(data, 'isFixture');
  if (data.containsKey('health'))
    choice(data, 'health', [
      'unknown',
      'unchanged',
      'changed',
      'missing',
      'ffprobe-missing',
    ]);
  stringField(data, 'healthMessage', required: false);
  final identity = objectField(data, 'identity');
  validateExtensions(identity);
  for (final key in ['sha256', 'key']) {
    stringField(identity, key);
  }
  intField(identity, 'size', required: false);
  stringField(identity, 'mtime', required: false);
  if (identity.containsKey('libraries')) {
    final libraries = objectField(identity, 'libraries');
    if (libraries.values.any((v) => v is! String))
      invalid('Library hashes must be text.');
  }
  if (data['probedAt'] != null) timestamp(data, 'probedAt');
  intField(data, 'probeMs', required: false, nullable: true);
  if (data.containsKey('counts')) {
    final counts = objectField(data, 'counts');
    for (final key in ['video', 'audio', 'muxers']) {
      intField(counts, key, required: false);
    }
  }
  if (data.containsKey('availability'))
    validateAvailability(objectField(data, 'availability'));
}

void validateAvailability(JsonMap data) {
  for (final value in data.values) {
    if (value is! Map) invalid('Encoder availability must be an object.');
    final entry = jsonMap(value);
    validateExtensions(entry);
    choice(entry, 'state', ['ok', 'missing', 'failed', 'unknown']);
    for (final key in ['reason', 'detail', 'note']) {
      stringField(entry, key, required: false);
    }
  }
}

MachineSettings decodeMachine(JsonMap data) {
  major(data, 'machine');
  intField(data, 'revision');
  for (final key in ['progressWindow', 'keepOnTop', 'verifyOutput']) {
    boolField(data, key);
  }
  if (data.containsKey('theme'))
    choice(data, 'theme', ['system', 'light', 'dark']);
  stringField(data, 'defaultFFmpegId', required: false, nullable: true);
  final ids = <String>{};
  final foldedIds = <String>{};
  if (data.containsKey('installations')) {
    for (final value in arrayField(data, 'installations')) {
      if (value is! Map) invalid('Installation must be an object.');
      final entry = jsonMap(value);
      validateInstallation(entry);
      ids.add(entry['id'] as String);
      if (!foldedIds.add((entry['id'] as String).toLowerCase()))
        invalid('Duplicate installation ID.');
    }
  }
  final selected = data['defaultFFmpegId'] as String?;
  if (selected != null && !ids.contains(selected)) {
    throw const ServiceException(
      'DEFAULT-NOT-FOUND',
      'Default FFmpeg must name a registered installation.',
    );
  }
  if (data['uiState'] != null) {
    final state = objectField(data, 'uiState');
    validateExtensions(state);
    boolField(state, 'desktopMaximized');
    stringField(state, 'lastSizeLengthText', required: false, nullable: true);
    if (state['desktopWindowBounds'] != null) {
      final bounds = objectField(state, 'desktopWindowBounds');
      validateExtensions(bounds);
      for (final key in ['x', 'y']) {
        intField(bounds, key, min: -2147483648);
      }
      for (final key in ['width', 'height']) {
        intField(bounds, key, min: 1);
      }
    }
  }
  return MachineSettings.fromJson(data);
}

Recipe decodeRecipe(JsonMap data, VeCore core) {
  major(data, 'schema');
  final normalized = core.normalize(data);
  final errors = normalized.issues
      .where((v) => v.level == IssueLevel.error)
      .toList();
  if (errors.isNotEmpty)
    throw ServiceException(
      'RECIPE-INVALID',
      errors.map((v) => v.message).join(' '),
    );
  safeId(normalized.recipe.id);
  return normalized.recipe;
}

Preset decodePreset(JsonMap data, VeCore core) {
  major(data, 'vepreset');
  intField(data, 'revision', min: 1);
  timestamp(data, 'updatedAt');
  for (final key in ['builtin', 'favorite', 'pinned']) {
    boolField(data, key);
  }
  stringField(data, 'origin', required: false, nullable: true);
  final requirements = objectField(data, 'requires');
  validateExtensions(requirements);
  strings(requirements, 'encoders');
  boolField(requirements, 'known');
  stringField(
    requirements,
    'minFFmpegVersion',
    required: false,
    nullable: true,
  );
  decodeRecipe(objectField(data, 'recipe'), core);
  return Preset.fromJson(data);
}

FFmpegCapabilities decodeCapabilities(JsonMap data) {
  validateExtensions(data);
  for (final key in ['installationId', 'identityKey', 'version']) {
    stringField(data, key);
  }
  intField(data, 'parser', min: 1);
  intField(data, 'libavformatMajor', required: false, min: 1, nullable: true);
  timestamp(data, 'probedAt');
  stringField(data, 'gpuFingerprint', required: false);
  for (final key in ['encoders', 'muxers']) {
    final entries = objectField(data, key);
    for (final entry in entries.entries) {
      if (entry.value is! Map) invalid('$key entries must be objects.');
      final value = jsonMap(entry.value);
      validateExtensions(value);
      if (key == 'encoders') {
        choice(value, 'kind', ['video', 'audio', 'subtitle']);
        for (final field in ['pixelFormats', 'sampleFormats']) {
          if (value.containsKey(field)) strings(value, field);
        }
        if (value.containsKey('sampleRates') &&
            arrayField(value, 'sampleRates').any((v) => v is! int || v <= 0)) {
          invalid('sampleRates must contain positive integers.');
        }
        if (value.containsKey('options')) {
          for (final option in arrayField(value, 'options')) {
            if (option is! Map) invalid('Encoder option must be an object.');
            final o = jsonMap(option);
            validateExtensions(o);
            stringField(o, 'name');
            for (final field in ['type', 'description']) {
              stringField(o, field, required: false);
            }
            for (final field in ['min', 'max', 'defaultValue']) {
              stringField(o, field, required: false, nullable: true);
            }
            if (o.containsKey('aliases')) strings(o, 'aliases');
            if (o.containsKey('constants')) {
              for (final constant in arrayField(o, 'constants')) {
                if (constant is! Map)
                  invalid('Option constant must be an object.');
                final c = jsonMap(constant);
                validateExtensions(c);
                stringField(c, 'name');
                stringField(c, 'value', required: false, nullable: true);
                stringField(c, 'description', required: false);
              }
            }
          }
        }
      }
      for (final field in ['flags', 'description']) {
        stringField(value, field, required: false);
      }
    }
  }
  validateAvailability(objectField(data, 'hardware'));
  return FFmpegCapabilities.fromJson(data);
}

LiveRenderStatus decodeLive(JsonMap data) {
  major(data, 'live');
  for (final key in ['jobId', 'outputPath', 'templateName', 'encoderSummary']) {
    stringField(data, key);
  }
  if ((data['jobId'] as String).isEmpty) invalid('jobId is empty.');
  timestamp(data, 'updatedAt');
  intField(data, 'sequence');
  choice(data, 'state', RenderState.values.map((v) => v.name).toList());
  for (final key in ['framesDone', 'bytesWritten', 'estimatedFinalBytes']) {
    intField(
      data,
      key,
      required: false,
      nullable: key == 'estimatedFinalBytes',
    );
  }
  intField(data, 'framesTotal', required: false, nullable: true, min: 1);
  for (final key in [
    'encodeFps',
    'speed',
    'bitrateKbps',
    'etaSec',
    'elapsedSec',
  ]) {
    numberField(data, key, nullable: key != 'elapsedSec');
  }
  stringField(data, 'message', required: false);
  intField(
    data,
    'ffmpegExitCode',
    required: false,
    nullable: true,
    min: -2147483648,
  );
  if (data['hostHwnd'] != null) {
    stringField(data, 'hostHwnd');
    final handle = BigInt.tryParse(data['hostHwnd'] as String);
    if (!RegExp(r'^\d+$').hasMatch(data['hostHwnd'] as String) ||
        handle == null ||
        handle <= BigInt.zero ||
        handle > BigInt.parse('18446744073709551615'))
      invalid('Invalid host HWND.');
  }
  return LiveRenderStatus.fromJson(data);
}

JobIndexEntry decodeIndex(JsonMap data) {
  major(data, 'index');
  for (final key in ['id', 'recordFile', 'templateName', 'outputPath']) {
    stringField(data, key);
  }
  safeId(data['id'] as String);
  if (data['recordFile'] != '${data['id']}.json')
    invalid('Job recordFile must be its ID basename.');
  timestamp(data, 'startedAt');
  choice(data, 'status', ['succeeded', 'failed', 'cancelled']);
  for (final key in ['encoderSummary', 'project']) {
    stringField(data, key, required: false, nullable: true);
  }
  for (final key in ['durationSec', 'elapsedSec']) {
    numberField(data, key, nullable: true);
  }
  intField(data, 'sizeBytes', required: false, nullable: true);
  return JobIndexEntry.fromJson(data);
}

JobRecord decodeJob(JsonMap data, VeCore core) {
  major(data, 'job');
  for (final key in ['id', 'templateName', 'outputPath', 'recipeSha256']) {
    stringField(data, key);
  }
  safeId(data['id'] as String);
  for (final key in ['startedAt', 'endedAt']) {
    timestamp(data, key);
  }
  choice(data, 'status', ['succeeded', 'failed', 'cancelled']);
  decodeRecipe(objectField(data, 'recipe'), core);
  validateInstallation(objectField(data, 'ffmpeg'));
  // The native core checks media; no domain rules are duplicated in services.
  final recipe = Recipe.fromJson(objectField(data, 'recipe'));
  final mediaData = objectField(data, 'media');
  validateExtensions(mediaData);
  validateExtensions(objectField(mediaData, 'video'));
  if (mediaData['audio'] != null)
    validateExtensions(objectField(mediaData, 'audio'));
  numberField(mediaData, 'durationSec', nullable: true);
  final media = MediaDescription.fromJson(mediaData);
  try {
    // Historical failed recipes may have domain errors. Ignore those returned
    // issues; malformed delivered media is a contained native MEDIA failure.
    core.validate(recipe, media: media);
  } on CoreException catch (e) {
    if (e.code != 'MEDIA') rethrow;
    invalid('Invalid recorded media: ${e.message}');
  }
  if (data['origin'] != null) {
    final origin = objectField(data, 'origin');
    validateExtensions(origin);
    for (final key in ['presetId', 'name']) {
      stringField(origin, key);
    }
    intField(origin, 'revision', min: 1);
  }
  if (data.containsKey('argv')) strings(data, 'argv');
  for (final key in [
    'project',
    'hresult',
    'message',
    'stderrTail',
    'commandLine',
    'encoderSummary',
    'logFile',
  ]) {
    stringField(
      data,
      key,
      required: false,
      nullable:
          key == 'logFile' || key == 'commandLine' || key == 'encoderSummary',
    );
  }
  for (final key in ['elapsedSec', 'avgFps', 'durationSec', 'realtime']) {
    numberField(data, key, nullable: key != 'elapsedSec');
  }
  intField(data, 'sizeBytes', required: false);
  intField(
    data,
    'ffmpegExitCode',
    required: false,
    min: -2147483648,
    nullable: true,
  );
  boolField(data, 'published');
  if (data['logFile'] != null && data['logFile'] != '${data['id']}.ffmpeg.log')
    invalid('logFile must be the job FFmpeg log basename.');
  stringField(data, 'retainedPartialPath', required: false, nullable: true);
  if (data.containsKey('timings')) {
    final timings = objectField(data, 'timings');
    for (final key in timings.keys) {
      numberField(timings, key, required: true);
    }
  }
  if (data.containsKey('errorTokenIndices') &&
      arrayField(data, 'errorTokenIndices').any(
        (v) => v is! int || v < 0 || v >= (data['argv'] as List? ?? []).length,
      ))
    invalid('Invalid error argv index.');
  final verification = objectField(data, 'verification');
  validateExtensions(verification);
  choice(verification, 'state', ['passed', 'failed', 'skipped']);
  stringField(verification, 'message', required: false);
  for (final key in ['expectedCodecs', 'actualCodecs']) {
    if (verification.containsKey(key)) strings(verification, key);
  }
  stringField(verification, 'ffprobeVersion', required: false, nullable: true);
  if (DateTime.parse(
    data['endedAt'] as String,
  ).isBefore(DateTime.parse(data['startedAt'] as String)))
    invalid('Job ended before it started.');
  if (data['published'] != true && (data['sizeBytes'] as int? ?? 0) != 0)
    invalid('Unpublished job cannot report a published file size.');
  if (data['status'] == 'succeeded' &&
      (data['published'] != true ||
          data['ffmpegExitCode'] != 0 ||
          verification['state'] == 'failed'))
    invalid('Succeeded job requires zero exit, output check and publication.');
  if (data['status'] != 'succeeded' && data['published'] == true)
    invalid('Stopped job cannot report publication.');
  return JobRecord.fromJson(data);
}
