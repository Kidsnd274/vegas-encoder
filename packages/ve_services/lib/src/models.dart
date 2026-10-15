import 'package:ve_core/ve_core.dart';

enum RenderState {
  starting,
  encoding,
  finishing,
  verifying,
  done,
  failed,
  cancelled,
}

class BinaryIdentity extends JsonModel {
  BinaryIdentity({
    required String sha256,
    required String key,
    int size = 0,
    String mtime = '',
    JsonMap libraries = const {},
    JsonMap extensions = const {},
  }) : super({
         'sha256': sha256,
         'key': key,
         'size': size,
         'mtime': mtime,
         'libraries': libraries,
         'extensions': extensions,
       });
  BinaryIdentity.fromJson(super.json);
  String get sha256 => data['sha256'] as String;
  String get key => data['key'] as String;
  int get size => data['size'] as int? ?? 0;
  String get mtime => data['mtime'] as String? ?? '';
  JsonMap get libraries => jsonMap(data['libraries'] ?? <String, Object?>{});
  BinaryIdentity copyWith({
    Object? sha256 = absent,
    Object? key = absent,
    Object? size = absent,
    Object? mtime = absent,
    Object? libraries = absent,
    Object? extensions = absent,
  }) => BinaryIdentity.fromJson(
    changed({
      if (!identical(sha256, absent)) 'sha256': sha256,
      if (!identical(key, absent)) 'key': key,
      if (!identical(size, absent)) 'size': size,
      if (!identical(mtime, absent)) 'mtime': mtime,
      if (!identical(libraries, absent)) 'libraries': libraries,
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class EncoderAvailability extends JsonModel {
  EncoderAvailability({
    String state = 'unknown',
    String reason = '',
    String detail = '',
    String note = '',
    JsonMap extensions = const {},
  }) : super({
         'state': state,
         'reason': reason,
         'detail': detail,
         'note': note,
         'extensions': extensions,
       });
  EncoderAvailability.fromJson(super.json);
  String get state => data['state'] as String? ?? 'unknown';
  String get reason => data['reason'] as String? ?? '';
  String get detail => data['detail'] as String? ?? '';
  String get note => data['note'] as String? ?? '';
  EncoderAvailability copyWith({
    Object? state = absent,
    Object? reason = absent,
    Object? detail = absent,
    Object? note = absent,
    Object? extensions = absent,
  }) => EncoderAvailability.fromJson(
    changed({
      if (!identical(state, absent)) 'state': state,
      if (!identical(reason, absent)) 'reason': reason,
      if (!identical(detail, absent)) 'detail': detail,
      if (!identical(note, absent)) 'note': note,
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class FFmpegInstallation extends JsonModel {
  FFmpegInstallation({
    required String id,
    required String label,
    required String path,
    required String ffprobePath,
    required String source,
    required String version,
    String build = '',
    String license = '',
    required BinaryIdentity identity,
    String? probedAt = null,
    int? probeMs = null,
    JsonMap counts = const {},
    JsonMap availability = const {},
    bool isFixture = false,
    String health = 'unknown',
    String healthMessage = '',
    JsonMap extensions = const {},
  }) : super({
         'id': id,
         'label': label,
         'path': path,
         'ffprobePath': ffprobePath,
         'source': source,
         'version': version,
         'build': build,
         'license': license,
         'identity': identity.toJson(),
         'probedAt': probedAt,
         'probeMs': probeMs,
         'counts': counts,
         'availability': availability,
         'isFixture': isFixture,
         'health': health,
         'healthMessage': healthMessage,
         'extensions': extensions,
       });
  FFmpegInstallation.fromJson(super.json);
  String get id => data['id'] as String;
  String get label => data['label'] as String;
  String get path => data['path'] as String;
  String get ffprobePath => data['ffprobePath'] as String;
  String get source => data['source'] as String;
  String get version => data['version'] as String;
  String get build => data['build'] as String? ?? '';
  String get license => data['license'] as String? ?? '';
  BinaryIdentity get identity =>
      BinaryIdentity.fromJson(jsonMap(data['identity']));
  String? get probedAt => data['probedAt'] as String?;
  int? get probeMs => data['probeMs'] as int?;
  JsonMap get counts => jsonMap(data['counts'] ?? <String, Object?>{});
  JsonMap get availability =>
      jsonMap(data['availability'] ?? <String, Object?>{});
  bool get isFixture => data['isFixture'] as bool? ?? false;
  String get health => data['health'] as String? ?? 'unknown';
  String get healthMessage => data['healthMessage'] as String? ?? '';
  FFmpegInstallation copyWith({
    Object? id = absent,
    Object? label = absent,
    Object? path = absent,
    Object? ffprobePath = absent,
    Object? source = absent,
    Object? version = absent,
    Object? build = absent,
    Object? license = absent,
    Object? identity = absent,
    Object? probedAt = absent,
    Object? probeMs = absent,
    Object? counts = absent,
    Object? availability = absent,
    Object? isFixture = absent,
    Object? health = absent,
    Object? healthMessage = absent,
    Object? extensions = absent,
  }) => FFmpegInstallation.fromJson(
    changed({
      if (!identical(id, absent)) 'id': id,
      if (!identical(label, absent)) 'label': label,
      if (!identical(path, absent)) 'path': path,
      if (!identical(ffprobePath, absent)) 'ffprobePath': ffprobePath,
      if (!identical(source, absent)) 'source': source,
      if (!identical(version, absent)) 'version': version,
      if (!identical(build, absent)) 'build': build,
      if (!identical(license, absent)) 'license': license,
      if (!identical(identity, absent))
        'identity': (identity as BinaryIdentity).toJson(),
      if (!identical(probedAt, absent)) 'probedAt': probedAt,
      if (!identical(probeMs, absent)) 'probeMs': probeMs,
      if (!identical(counts, absent)) 'counts': counts,
      if (!identical(availability, absent)) 'availability': availability,
      if (!identical(isFixture, absent)) 'isFixture': isFixture,
      if (!identical(health, absent)) 'health': health,
      if (!identical(healthMessage, absent)) 'healthMessage': healthMessage,
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class OptionConstant extends JsonModel {
  OptionConstant({
    required String name,
    String? value = null,
    String description = '',
    JsonMap extensions = const {},
  }) : super({
         'name': name,
         'value': value,
         'description': description,
         'extensions': extensions,
       });
  OptionConstant.fromJson(super.json);
  String get name => data['name'] as String;
  String? get value => data['value'] as String?;
  String get description => data['description'] as String? ?? '';
  OptionConstant copyWith({
    Object? name = absent,
    Object? value = absent,
    Object? description = absent,
    Object? extensions = absent,
  }) => OptionConstant.fromJson(
    changed({
      if (!identical(name, absent)) 'name': name,
      if (!identical(value, absent)) 'value': value,
      if (!identical(description, absent)) 'description': description,
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class EncoderOption extends JsonModel {
  EncoderOption({
    required String name,
    List<String> aliases = const [],
    String type = '',
    String description = '',
    String? min = null,
    String? max = null,
    String? defaultValue = null,
    List<OptionConstant> constants = const [],
    JsonMap extensions = const {},
  }) : super({
         'name': name,
         'aliases': aliases,
         'type': type,
         'description': description,
         'min': min,
         'max': max,
         'defaultValue': defaultValue,
         'constants': constants.map((v) => v.toJson()).toList(),
         'extensions': extensions,
       });
  EncoderOption.fromJson(super.json);
  String get name => data['name'] as String;
  List<String> get aliases => List<String>.unmodifiable(
    (data['aliases'] as List? ?? []).cast<String>(),
  );
  String get type => data['type'] as String? ?? '';
  String get description => data['description'] as String? ?? '';
  String? get min => data['min'] as String?;
  String? get max => data['max'] as String?;
  String? get defaultValue => data['defaultValue'] as String?;
  List<OptionConstant> get constants => List<OptionConstant>.unmodifiable(
    jsonMaps(data['constants'] ?? []).map(OptionConstant.fromJson),
  );
  EncoderOption copyWith({
    Object? name = absent,
    Object? aliases = absent,
    Object? type = absent,
    Object? description = absent,
    Object? min = absent,
    Object? max = absent,
    Object? defaultValue = absent,
    Object? constants = absent,
    Object? extensions = absent,
  }) => EncoderOption.fromJson(
    changed({
      if (!identical(name, absent)) 'name': name,
      if (!identical(aliases, absent)) 'aliases': aliases,
      if (!identical(type, absent)) 'type': type,
      if (!identical(description, absent)) 'description': description,
      if (!identical(min, absent)) 'min': min,
      if (!identical(max, absent)) 'max': max,
      if (!identical(defaultValue, absent)) 'defaultValue': defaultValue,
      if (!identical(constants, absent))
        'constants': (constants as List<OptionConstant>)
            .map((v) => v.toJson())
            .toList(),
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class EncoderDetails extends JsonModel {
  EncoderDetails({
    required String name,
    required String kind,
    List<String> pixelFormats = const [],
    List<String> sampleFormats = const [],
    List<int> sampleRates = const [],
    List<EncoderOption> options = const [],
    JsonMap extensions = const {},
  }) : super({
         'name': name,
         'kind': kind,
         'pixelFormats': pixelFormats,
         'sampleFormats': sampleFormats,
         'sampleRates': sampleRates,
         'options': options.map((v) => v.toJson()).toList(),
         'extensions': extensions,
       });
  EncoderDetails.fromJson(super.json);
  String get name => data['name'] as String;
  String get kind => data['kind'] as String;
  List<String> get pixelFormats => List<String>.unmodifiable(
    (data['pixelFormats'] as List? ?? []).cast<String>(),
  );
  List<String> get sampleFormats => List<String>.unmodifiable(
    (data['sampleFormats'] as List? ?? []).cast<String>(),
  );
  List<int> get sampleRates =>
      List<int>.unmodifiable((data['sampleRates'] as List? ?? []).cast<int>());
  List<EncoderOption> get options => List<EncoderOption>.unmodifiable(
    jsonMaps(data['options'] ?? []).map(EncoderOption.fromJson),
  );
  EncoderDetails copyWith({
    Object? name = absent,
    Object? kind = absent,
    Object? pixelFormats = absent,
    Object? sampleFormats = absent,
    Object? sampleRates = absent,
    Object? options = absent,
    Object? extensions = absent,
  }) => EncoderDetails.fromJson(
    changed({
      if (!identical(name, absent)) 'name': name,
      if (!identical(kind, absent)) 'kind': kind,
      if (!identical(pixelFormats, absent)) 'pixelFormats': pixelFormats,
      if (!identical(sampleFormats, absent)) 'sampleFormats': sampleFormats,
      if (!identical(sampleRates, absent)) 'sampleRates': sampleRates,
      if (!identical(options, absent))
        'options': (options as List<EncoderOption>)
            .map((v) => v.toJson())
            .toList(),
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class FFmpegCapabilities extends JsonModel {
  FFmpegCapabilities({
    required String installationId,
    required String identityKey,
    int parser = 1,
    required String version,
    int? libavformatMajor = null,
    JsonMap encoders = const {},
    JsonMap muxers = const {},
    JsonMap hardware = const {},
    String gpuFingerprint = '',
    required String probedAt,
    JsonMap extensions = const {},
  }) : super({
         'installationId': installationId,
         'identityKey': identityKey,
         'parser': parser,
         'version': version,
         'libavformatMajor': libavformatMajor,
         'encoders': encoders,
         'muxers': muxers,
         'hardware': hardware,
         'gpuFingerprint': gpuFingerprint,
         'probedAt': probedAt,
         'extensions': extensions,
       });
  FFmpegCapabilities.fromJson(super.json);
  String get installationId => data['installationId'] as String;
  String get identityKey => data['identityKey'] as String;
  int get parser => data['parser'] as int? ?? 1;
  String get version => data['version'] as String;
  int? get libavformatMajor => data['libavformatMajor'] as int?;
  JsonMap get encoders => jsonMap(data['encoders'] ?? <String, Object?>{});
  JsonMap get muxers => jsonMap(data['muxers'] ?? <String, Object?>{});
  JsonMap get hardware => jsonMap(data['hardware'] ?? <String, Object?>{});
  String get gpuFingerprint => data['gpuFingerprint'] as String? ?? '';
  String get probedAt => data['probedAt'] as String;
  FFmpegCapabilities copyWith({
    Object? installationId = absent,
    Object? identityKey = absent,
    Object? parser = absent,
    Object? version = absent,
    Object? libavformatMajor = absent,
    Object? encoders = absent,
    Object? muxers = absent,
    Object? hardware = absent,
    Object? gpuFingerprint = absent,
    Object? probedAt = absent,
    Object? extensions = absent,
  }) => FFmpegCapabilities.fromJson(
    changed({
      if (!identical(installationId, absent)) 'installationId': installationId,
      if (!identical(identityKey, absent)) 'identityKey': identityKey,
      if (!identical(parser, absent)) 'parser': parser,
      if (!identical(version, absent)) 'version': version,
      if (!identical(libavformatMajor, absent))
        'libavformatMajor': libavformatMajor,
      if (!identical(encoders, absent)) 'encoders': encoders,
      if (!identical(muxers, absent)) 'muxers': muxers,
      if (!identical(hardware, absent)) 'hardware': hardware,
      if (!identical(gpuFingerprint, absent)) 'gpuFingerprint': gpuFingerprint,
      if (!identical(probedAt, absent)) 'probedAt': probedAt,
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class ProbeProgress extends JsonModel {
  ProbeProgress({
    required String installationId,
    required String phase,
    int completed = 0,
    int total = 0,
    String message = '',
    FFmpegCapabilities? capabilities = null,
    JsonMap extensions = const {},
  }) : super({
         'installationId': installationId,
         'phase': phase,
         'completed': completed,
         'total': total,
         'message': message,
         'capabilities': capabilities?.toJson(),
         'extensions': extensions,
       });
  ProbeProgress.fromJson(super.json);
  String get installationId => data['installationId'] as String;
  String get phase => data['phase'] as String;
  int get completed => data['completed'] as int? ?? 0;
  int get total => data['total'] as int? ?? 0;
  String get message => data['message'] as String? ?? '';
  FFmpegCapabilities? get capabilities => data['capabilities'] == null
      ? null
      : FFmpegCapabilities.fromJson(jsonMap(data['capabilities']));
  ProbeProgress copyWith({
    Object? installationId = absent,
    Object? phase = absent,
    Object? completed = absent,
    Object? total = absent,
    Object? message = absent,
    Object? capabilities = absent,
    Object? extensions = absent,
  }) => ProbeProgress.fromJson(
    changed({
      if (!identical(installationId, absent)) 'installationId': installationId,
      if (!identical(phase, absent)) 'phase': phase,
      if (!identical(completed, absent)) 'completed': completed,
      if (!identical(total, absent)) 'total': total,
      if (!identical(message, absent)) 'message': message,
      if (!identical(capabilities, absent))
        'capabilities': (capabilities as FFmpegCapabilities?)?.toJson(),
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class HardwareTestResult extends JsonModel {
  HardwareTestResult({
    required String encoder,
    required String state,
    bool tenBit = false,
    String? failureClass = null,
    String reason = '',
    String stderr = '',
    required String testedAt,
    required String identityKey,
    required String gpuFingerprint,
    JsonMap extensions = const {},
  }) : super({
         'encoder': encoder,
         'state': state,
         'tenBit': tenBit,
         'failureClass': failureClass,
         'reason': reason,
         'stderr': stderr,
         'testedAt': testedAt,
         'identityKey': identityKey,
         'gpuFingerprint': gpuFingerprint,
         'extensions': extensions,
       });
  HardwareTestResult.fromJson(super.json);
  String get encoder => data['encoder'] as String;
  String get state => data['state'] as String;
  bool get tenBit => data['tenBit'] as bool? ?? false;
  String? get failureClass => data['failureClass'] as String?;
  String get reason => data['reason'] as String? ?? '';
  String get stderr => data['stderr'] as String? ?? '';
  String get testedAt => data['testedAt'] as String;
  String get identityKey => data['identityKey'] as String;
  String get gpuFingerprint => data['gpuFingerprint'] as String;
  HardwareTestResult copyWith({
    Object? encoder = absent,
    Object? state = absent,
    Object? tenBit = absent,
    Object? failureClass = absent,
    Object? reason = absent,
    Object? stderr = absent,
    Object? testedAt = absent,
    Object? identityKey = absent,
    Object? gpuFingerprint = absent,
    Object? extensions = absent,
  }) => HardwareTestResult.fromJson(
    changed({
      if (!identical(encoder, absent)) 'encoder': encoder,
      if (!identical(state, absent)) 'state': state,
      if (!identical(tenBit, absent)) 'tenBit': tenBit,
      if (!identical(failureClass, absent)) 'failureClass': failureClass,
      if (!identical(reason, absent)) 'reason': reason,
      if (!identical(stderr, absent)) 'stderr': stderr,
      if (!identical(testedAt, absent)) 'testedAt': testedAt,
      if (!identical(identityKey, absent)) 'identityKey': identityKey,
      if (!identical(gpuFingerprint, absent)) 'gpuFingerprint': gpuFingerprint,
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class PresetTestProgress extends JsonModel {
  PresetTestProgress({
    required String testId,
    required String phase,
    String log = '',
    String message = '',
    int framesDone = 0,
    int framesTotal = 60,
    String? commandLine = null,
    String? logPath = null,
    String? outputPath = null,
    VerificationResult? verification = null,
    bool isFixture = false,
  }) : super({
         'testId': testId,
         'phase': phase,
         'log': log,
         'message': message,
         'framesDone': framesDone,
         'framesTotal': framesTotal,
         'commandLine': commandLine,
         'logPath': logPath,
         'outputPath': outputPath,
         'verification': verification?.data,
         'isFixture': isFixture,
       });
  PresetTestProgress.fromJson(super.json);
  String get testId => data['testId'] as String;
  String get phase => data['phase'] as String;
  String get log => data['log'] as String? ?? '';
  String get message => data['message'] as String? ?? '';
  int get framesDone => data['framesDone'] as int? ?? 0;
  int get framesTotal => data['framesTotal'] as int? ?? 60;
  String? get commandLine => data['commandLine'] as String?;
  String? get logPath => data['logPath'] as String?;
  String? get outputPath => data['outputPath'] as String?;
  VerificationResult? get verification => data['verification'] == null
      ? null
      : VerificationResult.fromJson(jsonMap(data['verification']));
  bool get isFixture => data['isFixture'] as bool? ?? false;
}

class PresetRequirements extends JsonModel {
  PresetRequirements({
    List<String> encoders = const [],
    String? minFFmpegVersion = null,
    bool known = true,
    JsonMap extensions = const {},
  }) : super({
         'encoders': encoders,
         'minFFmpegVersion': minFFmpegVersion,
         'known': known,
         'extensions': extensions,
       });
  PresetRequirements.fromJson(super.json);
  List<String> get encoders => List<String>.unmodifiable(
    (data['encoders'] as List? ?? []).cast<String>(),
  );
  String? get minFFmpegVersion => data['minFFmpegVersion'] as String?;
  bool get known => data['known'] as bool? ?? true;
  PresetRequirements copyWith({
    Object? encoders = absent,
    Object? minFFmpegVersion = absent,
    Object? known = absent,
    Object? extensions = absent,
  }) => PresetRequirements.fromJson(
    changed({
      if (!identical(encoders, absent)) 'encoders': encoders,
      if (!identical(minFFmpegVersion, absent))
        'minFFmpegVersion': minFFmpegVersion,
      if (!identical(known, absent)) 'known': known,
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class Preset extends JsonModel {
  Preset({
    int vepreset = 1,
    int revision = 1,
    bool favorite = false,
    bool pinned = false,
    bool builtin = false,
    required String updatedAt,
    String? origin = null,
    required PresetRequirements requires,
    required Recipe recipe,
    JsonMap extensions = const {},
  }) : super({
         'vepreset': vepreset,
         'revision': revision,
         'favorite': favorite,
         'pinned': pinned,
         'builtin': builtin,
         'updatedAt': updatedAt,
         'origin': origin,
         'requires': requires.toJson(),
         'recipe': recipe.toJson(),
         'extensions': extensions,
       });
  Preset.fromJson(super.json);
  int get vepreset => data['vepreset'] as int? ?? 1;
  int get revision => data['revision'] as int? ?? 1;
  bool get favorite => data['favorite'] as bool? ?? false;
  bool get pinned => data['pinned'] as bool? ?? false;
  bool get builtin => data['builtin'] as bool? ?? false;
  String get updatedAt => data['updatedAt'] as String;
  String? get origin => data['origin'] as String?;
  PresetRequirements get requires =>
      PresetRequirements.fromJson(jsonMap(data['requires']));
  Recipe get recipe => Recipe.fromJson(jsonMap(data['recipe']));
  Preset copyWith({
    Object? vepreset = absent,
    Object? revision = absent,
    Object? favorite = absent,
    Object? pinned = absent,
    Object? builtin = absent,
    Object? updatedAt = absent,
    Object? origin = absent,
    Object? requires = absent,
    Object? recipe = absent,
    Object? extensions = absent,
  }) => Preset.fromJson(
    changed({
      if (!identical(vepreset, absent)) 'vepreset': vepreset,
      if (!identical(revision, absent)) 'revision': revision,
      if (!identical(favorite, absent)) 'favorite': favorite,
      if (!identical(pinned, absent)) 'pinned': pinned,
      if (!identical(builtin, absent)) 'builtin': builtin,
      if (!identical(updatedAt, absent)) 'updatedAt': updatedAt,
      if (!identical(origin, absent)) 'origin': origin,
      if (!identical(requires, absent))
        'requires': (requires as PresetRequirements).toJson(),
      if (!identical(recipe, absent)) 'recipe': (recipe as Recipe).toJson(),
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class DesktopWindowBounds extends JsonModel {
  DesktopWindowBounds({
    required int x,
    required int y,
    required int width,
    required int height,
    JsonMap extensions = const {},
  }) : super({
         'x': x,
         'y': y,
         'width': width,
         'height': height,
         'extensions': extensions,
       });
  DesktopWindowBounds.fromJson(super.json);
  int get x => data['x'] as int;
  int get y => data['y'] as int;
  int get width => data['width'] as int;
  int get height => data['height'] as int;
  DesktopWindowBounds copyWith({
    Object? x = absent,
    Object? y = absent,
    Object? width = absent,
    Object? height = absent,
    Object? extensions = absent,
  }) => DesktopWindowBounds.fromJson(
    changed({
      if (!identical(x, absent)) 'x': x,
      if (!identical(y, absent)) 'y': y,
      if (!identical(width, absent)) 'width': width,
      if (!identical(height, absent)) 'height': height,
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

/// Physical outer-window size; position is intentionally not persisted.
class PopupWindowSize extends JsonModel {
  PopupWindowSize({
    required int width,
    required int height,
    JsonMap extensions = const {},
  }) : super({'width': width, 'height': height, 'extensions': extensions});
  PopupWindowSize.fromJson(super.json);
  int get width => data['width'] as int;
  int get height => data['height'] as int;
  PopupWindowSize copyWith({
    Object? width = absent,
    Object? height = absent,
    Object? extensions = absent,
  }) => PopupWindowSize.fromJson(
    changed({
      if (!identical(width, absent)) 'width': width,
      if (!identical(height, absent)) 'height': height,
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class AppUiState extends JsonModel {
  AppUiState({
    DesktopWindowBounds? desktopWindowBounds = null,
    PopupWindowSize? popupWindowSize,
    bool desktopMaximized = false,
    String? lastSizeLengthText = null,
    JsonMap extensions = const {},
  }) : super({
         'desktopWindowBounds': desktopWindowBounds?.toJson(),
         'popupWindowSize': popupWindowSize?.toJson(),
         'desktopMaximized': desktopMaximized,
         'lastSizeLengthText': lastSizeLengthText,
         'extensions': extensions,
       });
  AppUiState.fromJson(super.json);
  DesktopWindowBounds? get desktopWindowBounds =>
      data['desktopWindowBounds'] == null
      ? null
      : DesktopWindowBounds.fromJson(jsonMap(data['desktopWindowBounds']));
  PopupWindowSize? get popupWindowSize => data['popupWindowSize'] == null
      ? null
      : PopupWindowSize.fromJson(jsonMap(data['popupWindowSize']));
  bool get desktopMaximized => data['desktopMaximized'] as bool? ?? false;
  String? get lastSizeLengthText => data['lastSizeLengthText'] as String?;
  AppUiState copyWith({
    Object? desktopWindowBounds = absent,
    Object? popupWindowSize = absent,
    Object? desktopMaximized = absent,
    Object? lastSizeLengthText = absent,
    Object? extensions = absent,
  }) => AppUiState.fromJson(
    changed({
      if (!identical(desktopWindowBounds, absent))
        'desktopWindowBounds': (desktopWindowBounds as DesktopWindowBounds?)
            ?.toJson(),
      if (!identical(popupWindowSize, absent))
        'popupWindowSize': (popupWindowSize as PopupWindowSize?)?.toJson(),
      if (!identical(desktopMaximized, absent))
        'desktopMaximized': desktopMaximized,
      if (!identical(lastSizeLengthText, absent))
        'lastSizeLengthText': lastSizeLengthText,
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class MachineSettings extends JsonModel {
  MachineSettings({
    int machine = 1,
    int revision = 0,
    List<FFmpegInstallation> installations = const [],
    String? defaultFFmpegId = null,
    bool progressWindow = true,
    bool keepOnTop = false,
    bool verifyOutput = true,
    String theme = 'system',
    AppUiState? uiState = null,
    JsonMap extensions = const {},
  }) : super({
         'machine': machine,
         'revision': revision,
         'installations': installations.map((v) => v.toJson()).toList(),
         'defaultFFmpegId': defaultFFmpegId,
         'progressWindow': progressWindow,
         'keepOnTop': keepOnTop,
         'verifyOutput': verifyOutput,
         'theme': theme,
         'uiState': uiState?.toJson(),
         'extensions': extensions,
       });
  MachineSettings.fromJson(super.json);
  int get machine => data['machine'] as int? ?? 1;
  int get revision => data['revision'] as int? ?? 0;
  List<FFmpegInstallation> get installations =>
      List<FFmpegInstallation>.unmodifiable(
        jsonMaps(data['installations'] ?? []).map(FFmpegInstallation.fromJson),
      );
  String? get defaultFFmpegId => data['defaultFFmpegId'] as String?;
  bool get progressWindow => data['progressWindow'] as bool? ?? true;
  bool get keepOnTop => data['keepOnTop'] as bool? ?? false;
  bool get verifyOutput => data['verifyOutput'] as bool? ?? true;
  String get theme => data['theme'] as String? ?? 'system';
  AppUiState? get uiState => data['uiState'] == null
      ? null
      : AppUiState.fromJson(jsonMap(data['uiState']));
  MachineSettings copyWith({
    Object? machine = absent,
    Object? revision = absent,
    Object? installations = absent,
    Object? defaultFFmpegId = absent,
    Object? progressWindow = absent,
    Object? keepOnTop = absent,
    Object? verifyOutput = absent,
    Object? theme = absent,
    Object? uiState = absent,
    Object? extensions = absent,
  }) => MachineSettings.fromJson(
    changed({
      if (!identical(machine, absent)) 'machine': machine,
      if (!identical(revision, absent)) 'revision': revision,
      if (!identical(installations, absent))
        'installations': (installations as List<FFmpegInstallation>)
            .map((v) => v.toJson())
            .toList(),
      if (!identical(defaultFFmpegId, absent))
        'defaultFFmpegId': defaultFFmpegId,
      if (!identical(progressWindow, absent)) 'progressWindow': progressWindow,
      if (!identical(keepOnTop, absent)) 'keepOnTop': keepOnTop,
      if (!identical(verifyOutput, absent)) 'verifyOutput': verifyOutput,
      if (!identical(theme, absent)) 'theme': theme,
      if (!identical(uiState, absent))
        'uiState': (uiState as AppUiState?)?.toJson(),
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class EditContext extends JsonModel {
  EditContext({
    String? hostVersion = null,
    String? project = null,
    MediaDescription? media = null,
    JsonMap extensions = const {},
  }) : super({
         'hostVersion': hostVersion,
         'project': project,
         'media': media?.toJson(),
         'extensions': extensions,
       });
  EditContext.fromJson(super.json);
  String? get hostVersion => data['hostVersion'] as String?;
  String? get project => data['project'] as String?;
  MediaDescription? get media => data['media'] == null
      ? null
      : MediaDescription.fromJson(jsonMap(data['media']));
  EditContext copyWith({
    Object? hostVersion = absent,
    Object? project = absent,
    Object? media = absent,
    Object? extensions = absent,
  }) => EditContext.fromJson(
    changed({
      if (!identical(hostVersion, absent)) 'hostVersion': hostVersion,
      if (!identical(project, absent)) 'project': project,
      if (!identical(media, absent))
        'media': (media as MediaDescription?)?.toJson(),
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class EditSessionRequest extends JsonModel {
  EditSessionRequest({
    int protocol = 1,
    required String sessionId,
    required String templateName,
    required Recipe recipe,
    Origin? origin = null,
    Recipe? baseRecipe = null,
    required EditContext context,
    required String ownerHwnd,
    required String dllVersion,
    required String coreVersion,
    JsonMap extensions = const {},
  }) : super({
         'protocol': protocol,
         'sessionId': sessionId,
         'templateName': templateName,
         'recipe': recipe.toJson(),
         'origin': origin?.toJson(),
         'baseRecipe': baseRecipe?.toJson(),
         'context': context.toJson(),
         'ownerHwnd': ownerHwnd,
         'dllVersion': dllVersion,
         'coreVersion': coreVersion,
         'extensions': extensions,
       });
  EditSessionRequest.fromJson(super.json);
  int get protocol => data['protocol'] as int? ?? 1;
  String get sessionId => data['sessionId'] as String;
  String get templateName => data['templateName'] as String;
  Recipe get recipe => Recipe.fromJson(jsonMap(data['recipe']));
  Origin? get origin =>
      data['origin'] == null ? null : Origin.fromJson(jsonMap(data['origin']));
  Recipe? get baseRecipe => data['baseRecipe'] == null
      ? null
      : Recipe.fromJson(jsonMap(data['baseRecipe']));
  EditContext get context => EditContext.fromJson(jsonMap(data['context']));
  String get ownerHwnd => data['ownerHwnd'] as String;
  String get dllVersion => data['dllVersion'] as String;
  String get coreVersion => data['coreVersion'] as String;
  EditSessionRequest copyWith({
    Object? protocol = absent,
    Object? sessionId = absent,
    Object? templateName = absent,
    Object? recipe = absent,
    Object? origin = absent,
    Object? baseRecipe = absent,
    Object? context = absent,
    Object? ownerHwnd = absent,
    Object? dllVersion = absent,
    Object? coreVersion = absent,
    Object? extensions = absent,
  }) => EditSessionRequest.fromJson(
    changed({
      if (!identical(protocol, absent)) 'protocol': protocol,
      if (!identical(sessionId, absent)) 'sessionId': sessionId,
      if (!identical(templateName, absent)) 'templateName': templateName,
      if (!identical(recipe, absent)) 'recipe': (recipe as Recipe).toJson(),
      if (!identical(origin, absent)) 'origin': (origin as Origin?)?.toJson(),
      if (!identical(baseRecipe, absent))
        'baseRecipe': (baseRecipe as Recipe?)?.toJson(),
      if (!identical(context, absent))
        'context': (context as EditContext).toJson(),
      if (!identical(ownerHwnd, absent)) 'ownerHwnd': ownerHwnd,
      if (!identical(dllVersion, absent)) 'dllVersion': dllVersion,
      if (!identical(coreVersion, absent)) 'coreVersion': coreVersion,
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class EditSessionResult extends JsonModel {
  EditSessionResult({
    int protocol = 1,
    required String sessionId,
    required String action,
    Recipe? recipe = null,
    Origin? origin = null,
    JsonMap extensions = const {},
  }) : super({
         'protocol': protocol,
         'sessionId': sessionId,
         'action': action,
         'recipe': recipe?.toJson(),
         'origin': origin?.toJson(),
         'extensions': extensions,
       });
  EditSessionResult.fromJson(super.json);
  int get protocol => data['protocol'] as int? ?? 1;
  String get sessionId => data['sessionId'] as String;
  String get action => data['action'] as String;
  Recipe? get recipe =>
      data['recipe'] == null ? null : Recipe.fromJson(jsonMap(data['recipe']));
  Origin? get origin =>
      data['origin'] == null ? null : Origin.fromJson(jsonMap(data['origin']));
  EditSessionResult copyWith({
    Object? protocol = absent,
    Object? sessionId = absent,
    Object? action = absent,
    Object? recipe = absent,
    Object? origin = absent,
    Object? extensions = absent,
  }) => EditSessionResult.fromJson(
    changed({
      if (!identical(protocol, absent)) 'protocol': protocol,
      if (!identical(sessionId, absent)) 'sessionId': sessionId,
      if (!identical(action, absent)) 'action': action,
      if (!identical(recipe, absent)) 'recipe': (recipe as Recipe?)?.toJson(),
      if (!identical(origin, absent)) 'origin': (origin as Origin?)?.toJson(),
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class LiveRenderStatus extends JsonModel {
  LiveRenderStatus({
    int live = 1,
    required String jobId,
    String? hostHwnd = null,
    int sequence = 0,
    required String updatedAt,
    RenderState state = RenderState.starting,
    int framesDone = 0,
    int? framesTotal = null,
    double? encodeFps = null,
    double? speed = null,
    double? bitrateKbps = null,
    int bytesWritten = 0,
    double elapsedSec = 0,
    double? etaSec = null,
    int? estimatedFinalBytes = null,
    required String outputPath,
    required String templateName,
    required String encoderSummary,
    String message = '',
    int? ffmpegExitCode = null,
    JsonMap extensions = const {},
  }) : super({
         'live': live,
         'jobId': jobId,
         'hostHwnd': hostHwnd,
         'sequence': sequence,
         'updatedAt': updatedAt,
         'state': state.name,
         'framesDone': framesDone,
         'framesTotal': framesTotal,
         'encodeFps': encodeFps,
         'speed': speed,
         'bitrateKbps': bitrateKbps,
         'bytesWritten': bytesWritten,
         'elapsedSec': elapsedSec,
         'etaSec': etaSec,
         'estimatedFinalBytes': estimatedFinalBytes,
         'outputPath': outputPath,
         'templateName': templateName,
         'encoderSummary': encoderSummary,
         'message': message,
         'ffmpegExitCode': ffmpegExitCode,
         'extensions': extensions,
       });
  LiveRenderStatus.fromJson(super.json);
  int get live => data['live'] as int? ?? 1;
  String get jobId => data['jobId'] as String;
  String? get hostHwnd => data['hostHwnd'] as String?;
  int get sequence => data['sequence'] as int? ?? 0;
  String get updatedAt => data['updatedAt'] as String;
  RenderState get state =>
      RenderState.values.byName(data['state'] as String? ?? 'starting');
  int get framesDone => data['framesDone'] as int? ?? 0;
  int? get framesTotal => data['framesTotal'] as int?;
  double? get encodeFps => (data['encodeFps'] as num?)?.toDouble();
  double? get speed => (data['speed'] as num?)?.toDouble();
  double? get bitrateKbps => (data['bitrateKbps'] as num?)?.toDouble();
  int get bytesWritten => data['bytesWritten'] as int? ?? 0;
  double get elapsedSec => (data['elapsedSec'] as num?)?.toDouble() ?? 0;
  double? get etaSec => (data['etaSec'] as num?)?.toDouble();
  int? get estimatedFinalBytes => data['estimatedFinalBytes'] as int?;
  String get outputPath => data['outputPath'] as String;
  String get templateName => data['templateName'] as String;
  String get encoderSummary => data['encoderSummary'] as String;
  String get message => data['message'] as String? ?? '';
  int? get ffmpegExitCode => data['ffmpegExitCode'] as int?;
  LiveRenderStatus copyWith({
    Object? live = absent,
    Object? jobId = absent,
    Object? hostHwnd = absent,
    Object? sequence = absent,
    Object? updatedAt = absent,
    Object? state = absent,
    Object? framesDone = absent,
    Object? framesTotal = absent,
    Object? encodeFps = absent,
    Object? speed = absent,
    Object? bitrateKbps = absent,
    Object? bytesWritten = absent,
    Object? elapsedSec = absent,
    Object? etaSec = absent,
    Object? estimatedFinalBytes = absent,
    Object? outputPath = absent,
    Object? templateName = absent,
    Object? encoderSummary = absent,
    Object? message = absent,
    Object? ffmpegExitCode = absent,
    Object? extensions = absent,
  }) => LiveRenderStatus.fromJson(
    changed({
      if (!identical(live, absent)) 'live': live,
      if (!identical(jobId, absent)) 'jobId': jobId,
      if (!identical(hostHwnd, absent)) 'hostHwnd': hostHwnd,
      if (!identical(sequence, absent)) 'sequence': sequence,
      if (!identical(updatedAt, absent)) 'updatedAt': updatedAt,
      if (!identical(state, absent)) 'state': (state as RenderState).name,
      if (!identical(framesDone, absent)) 'framesDone': framesDone,
      if (!identical(framesTotal, absent)) 'framesTotal': framesTotal,
      if (!identical(encodeFps, absent)) 'encodeFps': encodeFps,
      if (!identical(speed, absent)) 'speed': speed,
      if (!identical(bitrateKbps, absent)) 'bitrateKbps': bitrateKbps,
      if (!identical(bytesWritten, absent)) 'bytesWritten': bytesWritten,
      if (!identical(elapsedSec, absent)) 'elapsedSec': elapsedSec,
      if (!identical(etaSec, absent)) 'etaSec': etaSec,
      if (!identical(estimatedFinalBytes, absent))
        'estimatedFinalBytes': estimatedFinalBytes,
      if (!identical(outputPath, absent)) 'outputPath': outputPath,
      if (!identical(templateName, absent)) 'templateName': templateName,
      if (!identical(encoderSummary, absent)) 'encoderSummary': encoderSummary,
      if (!identical(message, absent)) 'message': message,
      if (!identical(ffmpegExitCode, absent)) 'ffmpegExitCode': ffmpegExitCode,
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class VerificationResult extends JsonModel {
  VerificationResult({
    String state = 'skipped',
    String message = '',
    List<String> expectedCodecs = const [],
    List<String> actualCodecs = const [],
    String? ffprobeVersion = null,
    JsonMap extensions = const {},
  }) : super({
         'state': state,
         'message': message,
         'expectedCodecs': expectedCodecs,
         'actualCodecs': actualCodecs,
         'ffprobeVersion': ffprobeVersion,
         'extensions': extensions,
       });
  VerificationResult.fromJson(super.json);
  String get state => data['state'] as String? ?? 'skipped';
  String get message => data['message'] as String? ?? '';
  List<String> get expectedCodecs => List<String>.unmodifiable(
    (data['expectedCodecs'] as List? ?? []).cast<String>(),
  );
  List<String> get actualCodecs => List<String>.unmodifiable(
    (data['actualCodecs'] as List? ?? []).cast<String>(),
  );
  String? get ffprobeVersion => data['ffprobeVersion'] as String?;
  VerificationResult copyWith({
    Object? state = absent,
    Object? message = absent,
    Object? expectedCodecs = absent,
    Object? actualCodecs = absent,
    Object? ffprobeVersion = absent,
    Object? extensions = absent,
  }) => VerificationResult.fromJson(
    changed({
      if (!identical(state, absent)) 'state': state,
      if (!identical(message, absent)) 'message': message,
      if (!identical(expectedCodecs, absent)) 'expectedCodecs': expectedCodecs,
      if (!identical(actualCodecs, absent)) 'actualCodecs': actualCodecs,
      if (!identical(ffprobeVersion, absent)) 'ffprobeVersion': ffprobeVersion,
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class JobRecord extends JsonModel {
  JobRecord({
    int job = 1,
    required String id,
    required String startedAt,
    required String endedAt,
    String project = '',
    required String templateName,
    required String outputPath,
    required String status,
    required Recipe recipe,
    Origin? origin = null,
    required String recipeSha256,
    required MediaDescription media,
    required FFmpegInstallation ffmpeg,
    List<String> argv = const [],
    double elapsedSec = 0,
    int sizeBytes = 0,
    double? avgFps = null,
    int? ffmpegExitCode = null,
    String hresult = '',
    String message = '',
    String stderrTail = '',
    required VerificationResult verification,
    JsonMap timings = const {},
    bool published = false,
    String? retainedPartialPath = null,
    String? commandLine = null,
    String? encoderSummary = null,
    String? logFile = null,
    double? durationSec = null,
    double? realtime = null,
    List<int> errorTokenIndices = const [],
    JsonMap extensions = const {},
  }) : super({
         'job': job,
         'id': id,
         'startedAt': startedAt,
         'endedAt': endedAt,
         'project': project,
         'templateName': templateName,
         'outputPath': outputPath,
         'status': status,
         'recipe': recipe.toJson(),
         'origin': origin?.toJson(),
         'recipeSha256': recipeSha256,
         'media': media.toJson(),
         'ffmpeg': ffmpeg.toJson(),
         'argv': argv,
         'elapsedSec': elapsedSec,
         'sizeBytes': sizeBytes,
         'avgFps': avgFps,
         'ffmpegExitCode': ffmpegExitCode,
         'hresult': hresult,
         'message': message,
         'stderrTail': stderrTail,
         'verification': verification.toJson(),
         'timings': timings,
         'published': published,
         'retainedPartialPath': retainedPartialPath,
         'commandLine': commandLine,
         'encoderSummary': encoderSummary,
         'logFile': logFile,
         'durationSec': durationSec,
         'realtime': realtime,
         'errorTokenIndices': errorTokenIndices,
         'extensions': extensions,
       });
  JobRecord.fromJson(super.json);
  int get job => data['job'] as int? ?? 1;
  String get id => data['id'] as String;
  String get startedAt => data['startedAt'] as String;
  String get endedAt => data['endedAt'] as String;
  String get project => data['project'] as String? ?? '';
  String get templateName => data['templateName'] as String;
  String get outputPath => data['outputPath'] as String;
  String get status => data['status'] as String;
  Recipe get recipe => Recipe.fromJson(jsonMap(data['recipe']));
  Origin? get origin =>
      data['origin'] == null ? null : Origin.fromJson(jsonMap(data['origin']));
  String get recipeSha256 => data['recipeSha256'] as String;
  MediaDescription get media =>
      MediaDescription.fromJson(jsonMap(data['media']));
  FFmpegInstallation get ffmpeg =>
      FFmpegInstallation.fromJson(jsonMap(data['ffmpeg']));
  List<String> get argv =>
      List<String>.unmodifiable((data['argv'] as List? ?? []).cast<String>());
  double get elapsedSec => (data['elapsedSec'] as num?)?.toDouble() ?? 0;
  int get sizeBytes => data['sizeBytes'] as int? ?? 0;
  double? get avgFps => (data['avgFps'] as num?)?.toDouble();
  int? get ffmpegExitCode => data['ffmpegExitCode'] as int?;
  String get hresult => data['hresult'] as String? ?? '';
  String get message => data['message'] as String? ?? '';
  String get stderrTail => data['stderrTail'] as String? ?? '';
  VerificationResult get verification =>
      VerificationResult.fromJson(jsonMap(data['verification']));
  JsonMap get timings => jsonMap(data['timings'] ?? <String, Object?>{});
  bool get published => data['published'] as bool? ?? false;
  String? get retainedPartialPath => data['retainedPartialPath'] as String?;
  String? get commandLine => data['commandLine'] as String?;
  String? get encoderSummary => data['encoderSummary'] as String?;
  String? get logFile => data['logFile'] as String?;
  double? get durationSec => (data['durationSec'] as num?)?.toDouble();
  double? get realtime => (data['realtime'] as num?)?.toDouble();
  List<int> get errorTokenIndices => List<int>.unmodifiable(
    (data['errorTokenIndices'] as List? ?? []).cast<int>(),
  );
  JobRecord copyWith({
    Object? job = absent,
    Object? id = absent,
    Object? startedAt = absent,
    Object? endedAt = absent,
    Object? project = absent,
    Object? templateName = absent,
    Object? outputPath = absent,
    Object? status = absent,
    Object? recipe = absent,
    Object? origin = absent,
    Object? recipeSha256 = absent,
    Object? media = absent,
    Object? ffmpeg = absent,
    Object? argv = absent,
    Object? elapsedSec = absent,
    Object? sizeBytes = absent,
    Object? avgFps = absent,
    Object? ffmpegExitCode = absent,
    Object? hresult = absent,
    Object? message = absent,
    Object? stderrTail = absent,
    Object? verification = absent,
    Object? timings = absent,
    Object? published = absent,
    Object? retainedPartialPath = absent,
    Object? commandLine = absent,
    Object? encoderSummary = absent,
    Object? logFile = absent,
    Object? durationSec = absent,
    Object? realtime = absent,
    Object? errorTokenIndices = absent,
    Object? extensions = absent,
  }) => JobRecord.fromJson(
    changed({
      if (!identical(job, absent)) 'job': job,
      if (!identical(id, absent)) 'id': id,
      if (!identical(startedAt, absent)) 'startedAt': startedAt,
      if (!identical(endedAt, absent)) 'endedAt': endedAt,
      if (!identical(project, absent)) 'project': project,
      if (!identical(templateName, absent)) 'templateName': templateName,
      if (!identical(outputPath, absent)) 'outputPath': outputPath,
      if (!identical(status, absent)) 'status': status,
      if (!identical(recipe, absent)) 'recipe': (recipe as Recipe).toJson(),
      if (!identical(origin, absent)) 'origin': (origin as Origin?)?.toJson(),
      if (!identical(recipeSha256, absent)) 'recipeSha256': recipeSha256,
      if (!identical(media, absent))
        'media': (media as MediaDescription).toJson(),
      if (!identical(ffmpeg, absent))
        'ffmpeg': (ffmpeg as FFmpegInstallation).toJson(),
      if (!identical(argv, absent)) 'argv': argv,
      if (!identical(elapsedSec, absent)) 'elapsedSec': elapsedSec,
      if (!identical(sizeBytes, absent)) 'sizeBytes': sizeBytes,
      if (!identical(avgFps, absent)) 'avgFps': avgFps,
      if (!identical(ffmpegExitCode, absent)) 'ffmpegExitCode': ffmpegExitCode,
      if (!identical(hresult, absent)) 'hresult': hresult,
      if (!identical(message, absent)) 'message': message,
      if (!identical(stderrTail, absent)) 'stderrTail': stderrTail,
      if (!identical(verification, absent))
        'verification': (verification as VerificationResult).toJson(),
      if (!identical(timings, absent)) 'timings': timings,
      if (!identical(published, absent)) 'published': published,
      if (!identical(retainedPartialPath, absent))
        'retainedPartialPath': retainedPartialPath,
      if (!identical(commandLine, absent)) 'commandLine': commandLine,
      if (!identical(encoderSummary, absent)) 'encoderSummary': encoderSummary,
      if (!identical(logFile, absent)) 'logFile': logFile,
      if (!identical(durationSec, absent)) 'durationSec': durationSec,
      if (!identical(realtime, absent)) 'realtime': realtime,
      if (!identical(errorTokenIndices, absent))
        'errorTokenIndices': errorTokenIndices,
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class JobIndexEntry extends JsonModel {
  JobIndexEntry({
    int index = 1,
    required String id,
    required String recordFile,
    required String startedAt,
    required String status,
    required String templateName,
    required String outputPath,
    String? encoderSummary = null,
    String? project = null,
    double? durationSec = null,
    double? elapsedSec = null,
    int? sizeBytes = null,
    JsonMap extensions = const {},
  }) : super({
         'index': index,
         'id': id,
         'recordFile': recordFile,
         'startedAt': startedAt,
         'status': status,
         'templateName': templateName,
         'outputPath': outputPath,
         'encoderSummary': encoderSummary,
         'project': project,
         'durationSec': durationSec,
         'elapsedSec': elapsedSec,
         'sizeBytes': sizeBytes,
         'extensions': extensions,
       });
  JobIndexEntry.fromJson(super.json);
  int get index => data['index'] as int? ?? 1;
  String get id => data['id'] as String;
  String get recordFile => data['recordFile'] as String;
  String get startedAt => data['startedAt'] as String;
  String get status => data['status'] as String;
  String get templateName => data['templateName'] as String;
  String get outputPath => data['outputPath'] as String;
  String? get encoderSummary => data['encoderSummary'] as String?;
  String? get project => data['project'] as String?;
  double? get durationSec => (data['durationSec'] as num?)?.toDouble();
  double? get elapsedSec => (data['elapsedSec'] as num?)?.toDouble();
  int? get sizeBytes => data['sizeBytes'] as int?;
  JobIndexEntry copyWith({
    Object? index = absent,
    Object? id = absent,
    Object? recordFile = absent,
    Object? startedAt = absent,
    Object? status = absent,
    Object? templateName = absent,
    Object? outputPath = absent,
    Object? encoderSummary = absent,
    Object? project = absent,
    Object? durationSec = absent,
    Object? elapsedSec = absent,
    Object? sizeBytes = absent,
    Object? extensions = absent,
  }) => JobIndexEntry.fromJson(
    changed({
      if (!identical(index, absent)) 'index': index,
      if (!identical(id, absent)) 'id': id,
      if (!identical(recordFile, absent)) 'recordFile': recordFile,
      if (!identical(startedAt, absent)) 'startedAt': startedAt,
      if (!identical(status, absent)) 'status': status,
      if (!identical(templateName, absent)) 'templateName': templateName,
      if (!identical(outputPath, absent)) 'outputPath': outputPath,
      if (!identical(encoderSummary, absent)) 'encoderSummary': encoderSummary,
      if (!identical(project, absent)) 'project': project,
      if (!identical(durationSec, absent)) 'durationSec': durationSec,
      if (!identical(elapsedSec, absent)) 'elapsedSec': elapsedSec,
      if (!identical(sizeBytes, absent)) 'sizeBytes': sizeBytes,
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}
