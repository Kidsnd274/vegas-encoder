import 'json_model.dart';

enum IssueLevel { error, warn, info, hint }

enum TokenRole {
  exe,
  global,
  input,
  map,
  video,
  audio,
  mux,
  output,
  extra,
  macro,
}

class ContainerSettings extends JsonModel {
  ContainerSettings({
    required String format,
    bool faststart = false,
    JsonMap extensions = const {},
  }) : super({
         'format': format,
         'faststart': faststart,
         'extensions': extensions,
       });
  ContainerSettings.fromJson(super.json);
  String get format => data['format'] as String;
  bool get faststart => data['faststart'] as bool? ?? false;
  ContainerSettings copyWith({
    Object? format = absent,
    Object? faststart = absent,
    Object? extensions = absent,
  }) => ContainerSettings.fromJson(
    changed({
      if (!identical(format, absent)) 'format': format,
      if (!identical(faststart, absent)) 'faststart': faststart,
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class VideoSettings extends JsonModel {
  VideoSettings({
    bool enabled = true,
    required String encoder,
    String? mode = null,
    double? quality = null,
    int? bitrateK = null,
    int? maxrateK = null,
    double? qp = null,
    String? speed = null,
    String? tune = null,
    String? profile = null,
    String? multipass = null,
    int? depth = null,
    double? gopSec = null,
    String color = 'bt709',
    String extra = '',
    JsonMap extensions = const {},
  }) : super({
         'enabled': enabled,
         'encoder': encoder,
         'mode': mode,
         'quality': quality,
         'bitrateK': bitrateK,
         'maxrateK': maxrateK,
         'qp': qp,
         'speed': speed,
         'tune': tune,
         'profile': profile,
         'multipass': multipass,
         'depth': depth,
         'gopSec': gopSec,
         'color': color,
         'extra': extra,
         'extensions': extensions,
       });
  VideoSettings.fromJson(super.json);
  bool get enabled => data['enabled'] as bool? ?? true;
  String get encoder => data['encoder'] as String;
  String? get mode => data['mode'] as String?;
  double? get quality => (data['quality'] as num?)?.toDouble();
  int? get bitrateK => data['bitrateK'] as int?;
  int? get maxrateK => data['maxrateK'] as int?;
  double? get qp => (data['qp'] as num?)?.toDouble();
  String? get speed => data['speed'] as String?;
  String? get tune => data['tune'] as String?;
  String? get profile => data['profile'] as String?;
  String? get multipass => data['multipass'] as String?;
  int? get depth => data['depth'] as int?;
  double? get gopSec => (data['gopSec'] as num?)?.toDouble();
  String get color => data['color'] as String? ?? 'bt709';
  String get extra => data['extra'] as String? ?? '';
  VideoSettings copyWith({
    Object? enabled = absent,
    Object? encoder = absent,
    Object? mode = absent,
    Object? quality = absent,
    Object? bitrateK = absent,
    Object? maxrateK = absent,
    Object? qp = absent,
    Object? speed = absent,
    Object? tune = absent,
    Object? profile = absent,
    Object? multipass = absent,
    Object? depth = absent,
    Object? gopSec = absent,
    Object? color = absent,
    Object? extra = absent,
    Object? extensions = absent,
  }) => VideoSettings.fromJson(
    changed({
      if (!identical(enabled, absent)) 'enabled': enabled,
      if (!identical(encoder, absent)) 'encoder': encoder,
      if (!identical(mode, absent)) 'mode': mode,
      if (!identical(quality, absent)) 'quality': quality,
      if (!identical(bitrateK, absent)) 'bitrateK': bitrateK,
      if (!identical(maxrateK, absent)) 'maxrateK': maxrateK,
      if (!identical(qp, absent)) 'qp': qp,
      if (!identical(speed, absent)) 'speed': speed,
      if (!identical(tune, absent)) 'tune': tune,
      if (!identical(profile, absent)) 'profile': profile,
      if (!identical(multipass, absent)) 'multipass': multipass,
      if (!identical(depth, absent)) 'depth': depth,
      if (!identical(gopSec, absent)) 'gopSec': gopSec,
      if (!identical(color, absent)) 'color': color,
      if (!identical(extra, absent)) 'extra': extra,
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class AudioSettings extends JsonModel {
  AudioSettings({
    bool enabled = true,
    required String encoder,
    String? mode = null,
    int? bitrateK = null,
    double? vbr = null,
    int? level = null,
    Object sampleRate = 'source',
    String channels = 'source',
    String extra = '',
    JsonMap extensions = const {},
  }) : super({
         'enabled': enabled,
         'encoder': encoder,
         'mode': mode,
         'bitrateK': bitrateK,
         'vbr': vbr,
         'level': level,
         'sampleRate': sampleRate,
         'channels': channels,
         'extra': extra,
         'extensions': extensions,
       });
  AudioSettings.fromJson(super.json);
  bool get enabled => data['enabled'] as bool? ?? true;
  String get encoder => data['encoder'] as String;
  String? get mode => data['mode'] as String?;
  int? get bitrateK => data['bitrateK'] as int?;
  double? get vbr => (data['vbr'] as num?)?.toDouble();
  int? get level => data['level'] as int?;
  Object get sampleRate => data['sampleRate'] ?? 'source';
  String get channels => data['channels'] as String? ?? 'source';
  String get extra => data['extra'] as String? ?? '';
  AudioSettings copyWith({
    Object? enabled = absent,
    Object? encoder = absent,
    Object? mode = absent,
    Object? bitrateK = absent,
    Object? vbr = absent,
    Object? level = absent,
    Object? sampleRate = absent,
    Object? channels = absent,
    Object? extra = absent,
    Object? extensions = absent,
  }) => AudioSettings.fromJson(
    changed({
      if (!identical(enabled, absent)) 'enabled': enabled,
      if (!identical(encoder, absent)) 'encoder': encoder,
      if (!identical(mode, absent)) 'mode': mode,
      if (!identical(bitrateK, absent)) 'bitrateK': bitrateK,
      if (!identical(vbr, absent)) 'vbr': vbr,
      if (!identical(level, absent)) 'level': level,
      if (!identical(sampleRate, absent)) 'sampleRate': sampleRate,
      if (!identical(channels, absent)) 'channels': channels,
      if (!identical(extra, absent)) 'extra': extra,
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class CommandSettings extends JsonModel {
  CommandSettings({
    String mode = 'structured',
    String template = '',
    JsonMap extensions = const {},
  }) : super({'mode': mode, 'template': template, 'extensions': extensions});
  CommandSettings.fromJson(super.json);
  String get mode => data['mode'] as String? ?? 'structured';
  String get template => data['template'] as String? ?? '';
  CommandSettings copyWith({
    Object? mode = absent,
    Object? template = absent,
    Object? extensions = absent,
  }) => CommandSettings.fromJson(
    changed({
      if (!identical(mode, absent)) 'mode': mode,
      if (!identical(template, absent)) 'template': template,
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class VegasPreferences extends JsonModel {
  VegasPreferences({
    String frame = 'project',
    String inputFormat = 'p010',
    JsonMap extensions = const {},
  }) : super({
         'frame': frame,
         'inputFormat': inputFormat,
         'extensions': extensions,
       });
  VegasPreferences.fromJson(super.json);
  String get frame => data['frame'] as String? ?? 'project';
  String get inputFormat => data['inputFormat'] as String? ?? 'p010';
  VegasPreferences copyWith({
    Object? frame = absent,
    Object? inputFormat = absent,
    Object? extensions = absent,
  }) => VegasPreferences.fromJson(
    changed({
      if (!identical(frame, absent)) 'frame': frame,
      if (!identical(inputFormat, absent)) 'inputFormat': inputFormat,
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class Recipe extends JsonModel {
  Recipe({
    int schema = 1,
    required String id,
    required String name,
    String notes = '',
    List<String> tags = const [],
    String category = 'custom',
    required ContainerSettings container,
    required VideoSettings video,
    required List<AudioSettings> audio,
    required CommandSettings command,
    required VegasPreferences vegas,
    JsonMap extensions = const {},
  }) : super({
         'schema': schema,
         'id': id,
         'name': name,
         'notes': notes,
         'tags': tags,
         'category': category,
         'container': container.toJson(),
         'video': video.toJson(),
         'audio': audio.map((v) => v.toJson()).toList(),
         'command': command.toJson(),
         'vegas': vegas.toJson(),
         'extensions': extensions,
       });
  Recipe.fromJson(super.json);
  int get schema => data['schema'] as int? ?? 1;
  String get id => data['id'] as String;
  String get name => data['name'] as String;
  String get notes => data['notes'] as String? ?? '';
  List<String> get tags =>
      List<String>.unmodifiable((data['tags'] as List? ?? []).cast<String>());
  String get category => data['category'] as String? ?? 'custom';
  ContainerSettings get container =>
      ContainerSettings.fromJson(jsonMap(data['container']));
  VideoSettings get video => VideoSettings.fromJson(jsonMap(data['video']));
  List<AudioSettings> get audio => List<AudioSettings>.unmodifiable(
    jsonMaps(data['audio'] ?? []).map(AudioSettings.fromJson),
  );
  CommandSettings get command =>
      CommandSettings.fromJson(jsonMap(data['command']));
  VegasPreferences get vegas =>
      VegasPreferences.fromJson(jsonMap(data['vegas']));
  Recipe copyWith({
    Object? schema = absent,
    Object? id = absent,
    Object? name = absent,
    Object? notes = absent,
    Object? tags = absent,
    Object? category = absent,
    Object? container = absent,
    Object? video = absent,
    Object? audio = absent,
    Object? command = absent,
    Object? vegas = absent,
    Object? extensions = absent,
  }) => Recipe.fromJson(
    changed({
      if (!identical(schema, absent)) 'schema': schema,
      if (!identical(id, absent)) 'id': id,
      if (!identical(name, absent)) 'name': name,
      if (!identical(notes, absent)) 'notes': notes,
      if (!identical(tags, absent)) 'tags': tags,
      if (!identical(category, absent)) 'category': category,
      if (!identical(container, absent))
        'container': (container as ContainerSettings).toJson(),
      if (!identical(video, absent)) 'video': (video as VideoSettings).toJson(),
      if (!identical(audio, absent))
        'audio': (audio as List<AudioSettings>).map((v) => v.toJson()).toList(),
      if (!identical(command, absent))
        'command': (command as CommandSettings).toJson(),
      if (!identical(vegas, absent))
        'vegas': (vegas as VegasPreferences).toJson(),
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class Origin extends JsonModel {
  Origin({
    required String presetId,
    required int revision,
    required String name,
    JsonMap extensions = const {},
  }) : super({
         'presetId': presetId,
         'revision': revision,
         'name': name,
         'extensions': extensions,
       });
  Origin.fromJson(super.json);
  String get presetId => data['presetId'] as String;
  int get revision => data['revision'] as int;
  String get name => data['name'] as String;
  Origin copyWith({
    Object? presetId = absent,
    Object? revision = absent,
    Object? name = absent,
    Object? extensions = absent,
  }) => Origin.fromJson(
    changed({
      if (!identical(presetId, absent)) 'presetId': presetId,
      if (!identical(revision, absent)) 'revision': revision,
      if (!identical(name, absent)) 'name': name,
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class VideoMedia extends JsonModel {
  VideoMedia({
    required int width,
    required int height,
    required List<int> fps,
    String pixfmt = 'p010le',
    String sar = '1:1',
    JsonMap extensions = const {},
  }) : super({
         'width': width,
         'height': height,
         'fps': fps,
         'pixfmt': pixfmt,
         'sar': sar,
         'extensions': extensions,
       });
  VideoMedia.fromJson(super.json);
  int get width => data['width'] as int;
  int get height => data['height'] as int;
  List<int> get fps =>
      List<int>.unmodifiable((data['fps'] as List? ?? []).cast<int>());
  String get pixfmt => data['pixfmt'] as String? ?? 'p010le';
  String get sar => data['sar'] as String? ?? '1:1';
  VideoMedia copyWith({
    Object? width = absent,
    Object? height = absent,
    Object? fps = absent,
    Object? pixfmt = absent,
    Object? sar = absent,
    Object? extensions = absent,
  }) => VideoMedia.fromJson(
    changed({
      if (!identical(width, absent)) 'width': width,
      if (!identical(height, absent)) 'height': height,
      if (!identical(fps, absent)) 'fps': fps,
      if (!identical(pixfmt, absent)) 'pixfmt': pixfmt,
      if (!identical(sar, absent)) 'sar': sar,
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class AudioMedia extends JsonModel {
  AudioMedia({
    int rate = 48000,
    int channels = 2,
    String sampleFmt = 'f32le',
    JsonMap extensions = const {},
  }) : super({
         'rate': rate,
         'channels': channels,
         'sampleFmt': sampleFmt,
         'extensions': extensions,
       });
  AudioMedia.fromJson(super.json);
  int get rate => data['rate'] as int? ?? 48000;
  int get channels => data['channels'] as int? ?? 2;
  String get sampleFmt => data['sampleFmt'] as String? ?? 'f32le';
  AudioMedia copyWith({
    Object? rate = absent,
    Object? channels = absent,
    Object? sampleFmt = absent,
    Object? extensions = absent,
  }) => AudioMedia.fromJson(
    changed({
      if (!identical(rate, absent)) 'rate': rate,
      if (!identical(channels, absent)) 'channels': channels,
      if (!identical(sampleFmt, absent)) 'sampleFmt': sampleFmt,
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class MediaDescription extends JsonModel {
  MediaDescription({
    required VideoMedia video,
    AudioMedia? audio = null,
    double? durationSec = null,
    JsonMap extensions = const {},
  }) : super({
         'video': video.toJson(),
         'audio': audio?.toJson(),
         'durationSec': durationSec,
         'extensions': extensions,
       });
  MediaDescription.fromJson(super.json);
  VideoMedia get video => VideoMedia.fromJson(jsonMap(data['video']));
  AudioMedia? get audio => data['audio'] == null
      ? null
      : AudioMedia.fromJson(jsonMap(data['audio']));
  double? get durationSec => (data['durationSec'] as num?)?.toDouble();
  MediaDescription copyWith({
    Object? video = absent,
    Object? audio = absent,
    Object? durationSec = absent,
    Object? extensions = absent,
  }) => MediaDescription.fromJson(
    changed({
      if (!identical(video, absent)) 'video': (video as VideoMedia).toJson(),
      if (!identical(audio, absent)) 'audio': (audio as AudioMedia?)?.toJson(),
      if (!identical(durationSec, absent)) 'durationSec': durationSec,
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class CompilePaths extends JsonModel {
  CompilePaths({
    String ffmpeg = 'ffmpeg',
    required String videoPipe,
    String? audioPipe = null,
    required String output,
    String project = '',
    JsonMap? target,
    JsonMap extensions = const {},
  }) : super({
         'ffmpeg': ffmpeg,
         'videoPipe': videoPipe,
         'audioPipe': audioPipe,
         'output': output,
         'project': project,
         if (target != null) 'target': target,
         'extensions': extensions,
       });
  CompilePaths.fromJson(super.json);
  String get ffmpeg => data['ffmpeg'] as String? ?? 'ffmpeg';
  String get videoPipe => data['videoPipe'] as String;
  String? get audioPipe => data['audioPipe'] as String?;
  String get output => data['output'] as String;
  String get project => data['project'] as String? ?? '';
  JsonMap? get target => data['target'] == null ? null : jsonMap(data['target']);
  CompilePaths copyWith({
    Object? ffmpeg = absent,
    Object? videoPipe = absent,
    Object? audioPipe = absent,
    Object? output = absent,
    Object? project = absent,
    Object? target = absent,
    Object? extensions = absent,
  }) => CompilePaths.fromJson(
    changed({
      if (!identical(ffmpeg, absent)) 'ffmpeg': ffmpeg,
      if (!identical(videoPipe, absent)) 'videoPipe': videoPipe,
      if (!identical(audioPipe, absent)) 'audioPipe': audioPipe,
      if (!identical(output, absent)) 'output': output,
      if (!identical(project, absent)) 'project': project,
      if (!identical(target, absent)) 'target': target,
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class Issue extends JsonModel {
  Issue({
    required String id,
    IssueLevel level = IssueLevel.info,
    String field = '',
    required String message,
    JsonMap params = const {},
    String? fix = null,
    List<int> tokenIndices = const [],
    JsonMap extensions = const {},
  }) : super({
         'id': id,
         'level': level.name,
         'field': field,
         'message': message,
         'params': params,
         'fix': fix,
         'tokenIndices': tokenIndices,
         'extensions': extensions,
       });
  Issue.fromJson(super.json);
  String get id => data['id'] as String;
  IssueLevel get level =>
      IssueLevel.values.byName(data['level'] as String? ?? 'info');
  String get field => data['field'] as String? ?? '';
  String get message => data['message'] as String;
  JsonMap get params => jsonMap(data['params'] ?? <String, Object?>{});
  String? get fix => data['fix'] as String?;
  List<int> get tokenIndices =>
      List<int>.unmodifiable((data['tokenIndices'] as List? ?? []).cast<int>());
  Issue copyWith({
    Object? id = absent,
    Object? level = absent,
    Object? field = absent,
    Object? message = absent,
    Object? params = absent,
    Object? fix = absent,
    Object? tokenIndices = absent,
    Object? extensions = absent,
  }) => Issue.fromJson(
    changed({
      if (!identical(id, absent)) 'id': id,
      if (!identical(level, absent)) 'level': (level as IssueLevel).name,
      if (!identical(field, absent)) 'field': field,
      if (!identical(message, absent)) 'message': message,
      if (!identical(params, absent)) 'params': params,
      if (!identical(fix, absent)) 'fix': fix,
      if (!identical(tokenIndices, absent)) 'tokenIndices': tokenIndices,
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class Diagnostic extends JsonModel {
  Diagnostic({
    required String id,
    IssueLevel level = IssueLevel.warn,
    int start = 0,
    int end = 0,
    required String message,
    JsonMap params = const {},
    String? fix = null,
    JsonMap extensions = const {},
  }) : super({
         'id': id,
         'level': level.name,
         'start': start,
         'end': end,
         'message': message,
         'params': params,
         'fix': fix,
         'extensions': extensions,
       });
  Diagnostic.fromJson(super.json);
  String get id => data['id'] as String;
  IssueLevel get level =>
      IssueLevel.values.byName(data['level'] as String? ?? 'warn');
  int get start => data['start'] as int? ?? 0;
  int get end => data['end'] as int? ?? 0;
  String get message => data['message'] as String;
  JsonMap get params => jsonMap(data['params'] ?? <String, Object?>{});
  String? get fix => data['fix'] as String?;
  Diagnostic copyWith({
    Object? id = absent,
    Object? level = absent,
    Object? start = absent,
    Object? end = absent,
    Object? message = absent,
    Object? params = absent,
    Object? fix = absent,
    Object? extensions = absent,
  }) => Diagnostic.fromJson(
    changed({
      if (!identical(id, absent)) 'id': id,
      if (!identical(level, absent)) 'level': (level as IssueLevel).name,
      if (!identical(start, absent)) 'start': start,
      if (!identical(end, absent)) 'end': end,
      if (!identical(message, absent)) 'message': message,
      if (!identical(params, absent)) 'params': params,
      if (!identical(fix, absent)) 'fix': fix,
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class CommandToken extends JsonModel {
  CommandToken({
    required String text,
    TokenRole role = TokenRole.extra,
    String? field = null,
    String? replacedField = null,
    String? stage,
    bool? isOption,
    List<String> macros = const [],
    int? sourceStart,
    int? sourceEnd,
    JsonMap extensions = const {},
  }) : super({
         'text': text,
         'role': role.name,
         'field': field,
         'replacedField': replacedField,
         'stage': stage,
         'isOption': isOption,
         'macros': macros,
         'sourceStart': sourceStart,
         'sourceEnd': sourceEnd,
         'extensions': extensions,
       });
  CommandToken.fromJson(super.json);
  String get text => data['text'] as String;
  TokenRole get role =>
      TokenRole.values.byName(data['role'] as String? ?? 'extra');
  String? get field => data['field'] as String?;
  String? get replacedField => data['replacedField'] as String?;
  String? get stage => data['stage'] as String?;
  bool? get isOption => data['isOption'] as bool?;
  List<String> get macros =>
      List<String>.unmodifiable((data['macros'] as List? ?? []).cast<String>());
  int? get sourceStart => data['sourceStart'] as int?;
  int? get sourceEnd => data['sourceEnd'] as int?;
  CommandToken copyWith({
    Object? text = absent,
    Object? role = absent,
    Object? field = absent,
    Object? replacedField = absent,
    Object? stage = absent,
    Object? isOption = absent,
    Object? macros = absent,
    Object? sourceStart = absent,
    Object? sourceEnd = absent,
    Object? extensions = absent,
  }) => CommandToken.fromJson(
    changed({
      if (!identical(text, absent)) 'text': text,
      if (!identical(role, absent)) 'role': (role as TokenRole).name,
      if (!identical(field, absent)) 'field': field,
      if (!identical(replacedField, absent)) 'replacedField': replacedField,
      if (!identical(stage, absent)) 'stage': stage,
      if (!identical(isOption, absent)) 'isOption': isOption,
      if (!identical(macros, absent)) 'macros': macros,
      if (!identical(sourceStart, absent)) 'sourceStart': sourceStart,
      if (!identical(sourceEnd, absent)) 'sourceEnd': sourceEnd,
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class ResolvedSettings extends JsonModel {
  ResolvedSettings({
    required String videoEncoder,
    String? audioEncoder = null,
    required String videoMode,
    String? audioMode = null,
    double? quality = null,
    String? speed = null,
    String? profile = null,
    required int depth,
    required String pixfmt,
    int? gopFrames = null,
    JsonMap extensions = const {},
  }) : super({
         'videoEncoder': videoEncoder,
         'audioEncoder': audioEncoder,
         'videoMode': videoMode,
         'audioMode': audioMode,
         'quality': quality,
         'speed': speed,
         'profile': profile,
         'depth': depth,
         'pixfmt': pixfmt,
         'gopFrames': gopFrames,
         'extensions': extensions,
       });
  ResolvedSettings.fromJson(super.json);
  String get videoEncoder => data['videoEncoder'] as String;
  String? get audioEncoder => data['audioEncoder'] as String?;
  String get videoMode => data['videoMode'] as String;
  String? get audioMode => data['audioMode'] as String?;
  double? get quality => (data['quality'] as num?)?.toDouble();
  String? get speed => data['speed'] as String?;
  String? get profile => data['profile'] as String?;
  int get depth => data['depth'] as int;
  String get pixfmt => data['pixfmt'] as String;
  int? get gopFrames => data['gopFrames'] as int?;
  ResolvedSettings copyWith({
    Object? videoEncoder = absent,
    Object? audioEncoder = absent,
    Object? videoMode = absent,
    Object? audioMode = absent,
    Object? quality = absent,
    Object? speed = absent,
    Object? profile = absent,
    Object? depth = absent,
    Object? pixfmt = absent,
    Object? gopFrames = absent,
    Object? extensions = absent,
  }) => ResolvedSettings.fromJson(
    changed({
      if (!identical(videoEncoder, absent)) 'videoEncoder': videoEncoder,
      if (!identical(audioEncoder, absent)) 'audioEncoder': audioEncoder,
      if (!identical(videoMode, absent)) 'videoMode': videoMode,
      if (!identical(audioMode, absent)) 'audioMode': audioMode,
      if (!identical(quality, absent)) 'quality': quality,
      if (!identical(speed, absent)) 'speed': speed,
      if (!identical(profile, absent)) 'profile': profile,
      if (!identical(depth, absent)) 'depth': depth,
      if (!identical(pixfmt, absent)) 'pixfmt': pixfmt,
      if (!identical(gopFrames, absent)) 'gopFrames': gopFrames,
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

/// Core facts at a stream's encoder input, before codec compression.
class StreamSignalFacts extends JsonModel {
  StreamSignalFacts({
    String? inputFormat = null,
    String? outputFormat = null,
    int? inputBits = null,
    int? outputBits = null,
    String? inputChroma = null,
    String? outputChroma = null,
    bool? chromaChanged = null,
    bool? conversion = null,
    String containerSupport = 'unknown',
    String? inputLabel = null,
    String? outputLabel = null,
    String? conversionNote = null,
    JsonMap extensions = const {},
  }) : super({
         'inputFormat': inputFormat,
         'outputFormat': outputFormat,
         'inputBits': inputBits,
         'outputBits': outputBits,
         'inputChroma': inputChroma,
         'outputChroma': outputChroma,
         'chromaChanged': chromaChanged,
         'conversion': conversion,
         'containerSupport': containerSupport,
         'inputLabel': inputLabel,
         'outputLabel': outputLabel,
         'conversionNote': conversionNote,
         'extensions': extensions,
       });
  StreamSignalFacts.fromJson(super.json);
  String? get inputFormat => data['inputFormat'] as String?;
  String? get outputFormat => data['outputFormat'] as String?;
  int? get inputBits => data['inputBits'] as int?;
  int? get outputBits => data['outputBits'] as int?;
  String? get inputChroma => data['inputChroma'] as String?;
  String? get outputChroma => data['outputChroma'] as String?;
  bool? get chromaChanged => data['chromaChanged'] as bool?;
  bool? get conversion => data['conversion'] as bool?;
  String get containerSupport =>
      data['containerSupport'] as String? ?? 'unknown';
  String? get inputLabel => data['inputLabel'] as String?;
  String? get outputLabel => data['outputLabel'] as String?;
  String? get conversionNote => data['conversionNote'] as String?;
  StreamSignalFacts copyWith({
    Object? inputFormat = absent,
    Object? outputFormat = absent,
    Object? inputBits = absent,
    Object? outputBits = absent,
    Object? inputChroma = absent,
    Object? outputChroma = absent,
    Object? chromaChanged = absent,
    Object? conversion = absent,
    Object? containerSupport = absent,
    Object? inputLabel = absent,
    Object? outputLabel = absent,
    Object? conversionNote = absent,
    Object? extensions = absent,
  }) => StreamSignalFacts.fromJson(
    changed({
      if (!identical(inputFormat, absent)) 'inputFormat': inputFormat,
      if (!identical(outputFormat, absent)) 'outputFormat': outputFormat,
      if (!identical(inputBits, absent)) 'inputBits': inputBits,
      if (!identical(outputBits, absent)) 'outputBits': outputBits,
      if (!identical(inputChroma, absent)) 'inputChroma': inputChroma,
      if (!identical(outputChroma, absent)) 'outputChroma': outputChroma,
      if (!identical(chromaChanged, absent)) 'chromaChanged': chromaChanged,
      if (!identical(conversion, absent)) 'conversion': conversion,
      if (!identical(containerSupport, absent))
        'containerSupport': containerSupport,
      if (!identical(inputLabel, absent)) 'inputLabel': inputLabel,
      if (!identical(outputLabel, absent)) 'outputLabel': outputLabel,
      if (!identical(conversionNote, absent)) 'conversionNote': conversionNote,
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class SignalFormatFacts extends JsonModel {
  SignalFormatFacts({
    required String format,
    int? bits = null,
    String? chroma = null,
    String label = '',
    String shortLabel = '',
    JsonMap extensions = const {},
  }) : super({
         'format': format,
         'bits': bits,
         'chroma': chroma,
         'label': label,
         'shortLabel': shortLabel,
         'extensions': extensions,
       });
  SignalFormatFacts.fromJson(super.json);
  String get format => data['format'] as String;
  int? get bits => data['bits'] as int?;
  String? get chroma => data['chroma'] as String?;
  String get label => data['label'] as String? ?? '';
  String get shortLabel => data['shortLabel'] as String? ?? '';
  SignalFormatFacts copyWith({
    Object? format = absent,
    Object? bits = absent,
    Object? chroma = absent,
    Object? label = absent,
    Object? shortLabel = absent,
    Object? extensions = absent,
  }) => SignalFormatFacts.fromJson(
    changed({
      if (!identical(format, absent)) 'format': format,
      if (!identical(bits, absent)) 'bits': bits,
      if (!identical(chroma, absent)) 'chroma': chroma,
      if (!identical(label, absent)) 'label': label,
      if (!identical(shortLabel, absent)) 'shortLabel': shortLabel,
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class SourceSignalFacts extends JsonModel {
  SourceSignalFacts({
    required SignalFormatFacts video,
    SignalFormatFacts? audio = null,
    JsonMap extensions = const {},
  }) : super({
         'video': video.toJson(),
         'audio': audio?.toJson(),
         'extensions': extensions,
       });
  SourceSignalFacts.fromJson(super.json);
  SignalFormatFacts get video =>
      SignalFormatFacts.fromJson(jsonMap(data['video']));
  SignalFormatFacts? get audio => data['audio'] == null
      ? null
      : SignalFormatFacts.fromJson(jsonMap(data['audio']));
  SourceSignalFacts copyWith({
    Object? video = absent,
    Object? audio = absent,
    Object? extensions = absent,
  }) => SourceSignalFacts.fromJson(
    changed({
      if (!identical(video, absent))
        'video': (video as SignalFormatFacts).toJson(),
      if (!identical(audio, absent))
        'audio': (audio as SignalFormatFacts?)?.toJson(),
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class SignalPathFacts extends JsonModel {
  SignalPathFacts({
    StreamSignalFacts? video = null,
    List<StreamSignalFacts> audio = const [],
    SourceSignalFacts? source = null,
    JsonMap extensions = const {},
  }) : super({
         'video': video?.toJson(),
         'audio': audio.map((v) => v.toJson()).toList(),
         'source': source?.toJson(),
         'extensions': extensions,
       });
  SignalPathFacts.fromJson(super.json);
  StreamSignalFacts? get video => data['video'] == null
      ? null
      : StreamSignalFacts.fromJson(jsonMap(data['video']));
  List<StreamSignalFacts> get audio => List<StreamSignalFacts>.unmodifiable(
    jsonMaps(data['audio'] ?? []).map(StreamSignalFacts.fromJson),
  );
  SourceSignalFacts? get source => data['source'] == null
      ? null
      : SourceSignalFacts.fromJson(jsonMap(data['source']));
  SignalPathFacts copyWith({
    Object? video = absent,
    Object? audio = absent,
    Object? source = absent,
    Object? extensions = absent,
  }) => SignalPathFacts.fromJson(
    changed({
      if (!identical(video, absent))
        'video': (video as StreamSignalFacts?)?.toJson(),
      if (!identical(audio, absent))
        'audio': (audio as List<StreamSignalFacts>)
            .map((v) => v.toJson())
            .toList(),
      if (!identical(source, absent))
        'source': (source as SourceSignalFacts?)?.toJson(),
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class ExpectedStream extends JsonModel {
  ExpectedStream({
    required String kind,
    String? encoder = null,
    String? codec = null,
  }) : super({'kind': kind, 'encoder': encoder, 'codec': codec});
  ExpectedStream.fromJson(super.json);
  String get kind => data['kind'] as String;
  String? get encoder => data['encoder'] as String?;
  String? get codec => data['codec'] as String?;
}

class CompileResult extends JsonModel {
  CompileResult({
    required String executable,
    required List<String> argv,
    List<CommandToken> display = const [],
    String commandLine = '',
    String advancedTemplate = '',
    ResolvedSettings? resolved = null,
    SignalPathFacts? signalPath = null,
    List<Issue> issues = const [],
    JsonMap summary = const {},
    List<String> overriddenFields = const [],
    List<ExpectedStream>? expectedStreams = null,
    String? outputContainerId = null,
    String? outputExtension = null,
    JsonMap extensions = const {},
  }) : super({
         'executable': executable,
         'argv': argv,
         'display': display.map((v) => v.toJson()).toList(),
         'commandLine': commandLine,
         'advancedTemplate': advancedTemplate,
         'resolved': resolved?.toJson(),
         'signalPath': signalPath?.toJson(),
         'issues': issues.map((v) => v.toJson()).toList(),
         'summary': summary,
         'overriddenFields': overriddenFields,
         'expectedStreams': expectedStreams?.map((v) => v.data).toList(),
         'outputContainerId': outputContainerId,
         'outputExtension': outputExtension,
         'extensions': extensions,
       });
  CompileResult.fromJson(super.json);
  String get executable => data['executable'] as String;
  List<String> get argv =>
      List<String>.unmodifiable((data['argv'] as List? ?? []).cast<String>());
  List<CommandToken> get display => List<CommandToken>.unmodifiable(
    jsonMaps(data['display'] ?? []).map(CommandToken.fromJson),
  );
  String get commandLine => data['commandLine'] as String? ?? '';

  /// Native compiler input facts; absent in historical fake fixtures.
  List<String>? get inputStreams => data['inputStreams'] == null
      ? null
      : List<String>.unmodifiable(
          (data['inputStreams'] as List).cast<String>(),
        );
  List<ExpectedStream>? get expectedStreams => data['expectedStreams'] == null
      ? null
      : List.unmodifiable(
          jsonMaps(data['expectedStreams']).map(ExpectedStream.fromJson),
        );

  /// Established output container; unknown in unscoped Advanced commands.
  String? get outputContainerId => data['outputContainerId'] as String?;
  String? get outputExtension => data['outputExtension'] as String?;
  String get advancedTemplate => data['advancedTemplate'] as String? ?? '';
  ResolvedSettings? get resolved => data['resolved'] == null
      ? null
      : ResolvedSettings.fromJson(jsonMap(data['resolved']));
  SignalPathFacts? get signalPath => data['signalPath'] == null
      ? null
      : SignalPathFacts.fromJson(jsonMap(data['signalPath']));
  List<Issue> get issues => List<Issue>.unmodifiable(
    jsonMaps(data['issues'] ?? []).map(Issue.fromJson),
  );
  JsonMap get summary => jsonMap(data['summary'] ?? <String, Object?>{});
  List<String> get overriddenFields => List<String>.unmodifiable(
    (data['overriddenFields'] as List? ?? []).cast<String>(),
  );
  CompileResult copyWith({
    Object? executable = absent,
    Object? argv = absent,
    Object? display = absent,
    Object? commandLine = absent,
    Object? advancedTemplate = absent,
    Object? resolved = absent,
    Object? signalPath = absent,
    Object? issues = absent,
    Object? summary = absent,
    Object? overriddenFields = absent,
    Object? expectedStreams = absent,
    Object? outputContainerId = absent,
    Object? outputExtension = absent,
    Object? extensions = absent,
  }) => CompileResult.fromJson(
    changed({
      if (!identical(executable, absent)) 'executable': executable,
      if (!identical(argv, absent)) 'argv': argv,
      if (!identical(display, absent))
        'display': (display as List<CommandToken>)
            .map((v) => v.toJson())
            .toList(),
      if (!identical(commandLine, absent)) 'commandLine': commandLine,
      if (!identical(advancedTemplate, absent))
        'advancedTemplate': advancedTemplate,
      if (!identical(resolved, absent))
        'resolved': (resolved as ResolvedSettings?)?.toJson(),
      if (!identical(signalPath, absent))
        'signalPath': (signalPath as SignalPathFacts?)?.toJson(),
      if (!identical(issues, absent))
        'issues': (issues as List<Issue>).map((v) => v.toJson()).toList(),
      if (!identical(summary, absent)) 'summary': summary,
      if (!identical(overriddenFields, absent))
        'overriddenFields': overriddenFields,
      if (!identical(expectedStreams, absent))
        'expectedStreams': (expectedStreams as List<ExpectedStream>?)
            ?.map((v) => v.data)
            .toList(),
      if (!identical(outputContainerId, absent))
        'outputContainerId': outputContainerId,
      if (!identical(outputExtension, absent)) 'outputExtension': outputExtension,
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class NormalizeResult extends JsonModel {
  NormalizeResult({
    required Recipe recipe,
    List<Issue> issues = const [],
    List<String>? requiredEncoders = null,
    JsonMap extensions = const {},
  }) : super({
         'recipe': recipe.toJson(),
         'issues': issues.map((v) => v.toJson()).toList(),
         'requiredEncoders': requiredEncoders,
         'extensions': extensions,
       });
  NormalizeResult.fromJson(super.json);
  Recipe get recipe => Recipe.fromJson(jsonMap(data['recipe']));

  /// Core-derived Basic requirements; null means unknown (Advanced/older core).
  List<String>? get requiredEncoders => data['requiredEncoders'] == null
      ? null
      : List<String>.unmodifiable(
          (data['requiredEncoders'] as List).cast<String>(),
        );
  List<Issue> get issues => List<Issue>.unmodifiable(
    jsonMaps(data['issues'] ?? []).map(Issue.fromJson),
  );
  NormalizeResult copyWith({
    Object? recipe = absent,
    Object? issues = absent,
    Object? requiredEncoders = absent,
    Object? extensions = absent,
  }) => NormalizeResult.fromJson(
    changed({
      if (!identical(recipe, absent)) 'recipe': (recipe as Recipe).toJson(),
      if (!identical(issues, absent))
        'issues': (issues as List<Issue>).map((v) => v.toJson()).toList(),
      if (!identical(requiredEncoders, absent))
        'requiredEncoders': requiredEncoders,
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class Suggestion extends JsonModel {
  Suggestion({
    required String value,
    String description = '',
    String? type = null,
    Object? defaultValue = null,
    String? source = null,
    String? availability = null,
    JsonMap extensions = const {},
  }) : super({
         'value': value,
         'description': description,
         'type': type,
         'defaultValue': defaultValue,
         'source': source,
         'availability': availability,
         'extensions': extensions,
       });
  Suggestion.fromJson(super.json);
  String get value => data['value'] as String;
  String get description => data['description'] as String? ?? '';
  String? get type => data['type'] as String?;
  Object? get defaultValue => data['defaultValue'] ?? null;
  String? get source => data['source'] as String?;
  String? get availability => data['availability'] as String?;
  Suggestion copyWith({
    Object? value = absent,
    Object? description = absent,
    Object? type = absent,
    Object? defaultValue = absent,
    Object? source = absent,
    Object? availability = absent,
    Object? extensions = absent,
  }) => Suggestion.fromJson(
    changed({
      if (!identical(value, absent)) 'value': value,
      if (!identical(description, absent)) 'description': description,
      if (!identical(type, absent)) 'type': type,
      if (!identical(defaultValue, absent)) 'defaultValue': defaultValue,
      if (!identical(source, absent)) 'source': source,
      if (!identical(availability, absent)) 'availability': availability,
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class CompletionResult extends JsonModel {
  CompletionResult({
    String kind = 'none',
    String? of = null,
    int start = 0,
    int end = 0,
    List<Suggestion> items = const [],
    JsonMap extensions = const {},
  }) : super({
         'kind': kind,
         'of': of,
         'start': start,
         'end': end,
         'items': items.map((v) => v.toJson()).toList(),
         'extensions': extensions,
       });
  CompletionResult.fromJson(super.json);
  String get kind => data['kind'] as String? ?? 'none';
  String? get of => data['of'] as String?;
  int get start => data['start'] as int? ?? 0;
  int get end => data['end'] as int? ?? 0;
  List<Suggestion> get items => List<Suggestion>.unmodifiable(
    jsonMaps(data['items'] ?? []).map(Suggestion.fromJson),
  );
  CompletionResult copyWith({
    Object? kind = absent,
    Object? of = absent,
    Object? start = absent,
    Object? end = absent,
    Object? items = absent,
    Object? extensions = absent,
  }) => CompletionResult.fromJson(
    changed({
      if (!identical(kind, absent)) 'kind': kind,
      if (!identical(of, absent)) 'of': of,
      if (!identical(start, absent)) 'start': start,
      if (!identical(end, absent)) 'end': end,
      if (!identical(items, absent))
        'items': (items as List<Suggestion>).map((v) => v.toJson()).toList(),
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class SizeEstimate extends JsonModel {
  SizeEstimate({
    bool available = true,
    bool approx = true,
    double videoKbps = 0,
    double audioKbps = 0,
    double bytesPerMinute = 0,
    double? totalBytes = null,
    double? minBytesPerMinute = null,
    double? maxBytesPerMinute = null,
    double? minTotalBytes = null,
    double? maxTotalBytes = null,
    String explanation = '',
    JsonMap extensions = const {},
  }) : super({
         'available': available,
         'approx': approx,
         'videoKbps': videoKbps,
         'audioKbps': audioKbps,
         'bytesPerMinute': bytesPerMinute,
         'totalBytes': totalBytes,
         'minBytesPerMinute': minBytesPerMinute,
         'maxBytesPerMinute': maxBytesPerMinute,
         'minTotalBytes': minTotalBytes,
         'maxTotalBytes': maxTotalBytes,
         'explanation': explanation,
         'extensions': extensions,
       });
  SizeEstimate.fromJson(super.json);
  bool get available => data['available'] as bool? ?? true;
  bool get approx => data['approx'] as bool? ?? true;
  double get videoKbps => (data['videoKbps'] as num?)?.toDouble() ?? 0;
  double get audioKbps => (data['audioKbps'] as num?)?.toDouble() ?? 0;
  double get bytesPerMinute =>
      (data['bytesPerMinute'] as num?)?.toDouble() ?? 0;
  double? get totalBytes => (data['totalBytes'] as num?)?.toDouble();
  double? get minBytesPerMinute =>
      (data['minBytesPerMinute'] as num?)?.toDouble();
  double? get maxBytesPerMinute =>
      (data['maxBytesPerMinute'] as num?)?.toDouble();
  double? get minTotalBytes => (data['minTotalBytes'] as num?)?.toDouble();
  double? get maxTotalBytes => (data['maxTotalBytes'] as num?)?.toDouble();
  String get explanation => data['explanation'] as String? ?? '';
  SizeEstimate copyWith({
    Object? available = absent,
    Object? approx = absent,
    Object? videoKbps = absent,
    Object? audioKbps = absent,
    Object? bytesPerMinute = absent,
    Object? totalBytes = absent,
    Object? minBytesPerMinute = absent,
    Object? maxBytesPerMinute = absent,
    Object? minTotalBytes = absent,
    Object? maxTotalBytes = absent,
    Object? explanation = absent,
    Object? extensions = absent,
  }) => SizeEstimate.fromJson(
    changed({
      if (!identical(available, absent)) 'available': available,
      if (!identical(approx, absent)) 'approx': approx,
      if (!identical(videoKbps, absent)) 'videoKbps': videoKbps,
      if (!identical(audioKbps, absent)) 'audioKbps': audioKbps,
      if (!identical(bytesPerMinute, absent)) 'bytesPerMinute': bytesPerMinute,
      if (!identical(totalBytes, absent)) 'totalBytes': totalBytes,
      if (!identical(minBytesPerMinute, absent))
        'minBytesPerMinute': minBytesPerMinute,
      if (!identical(maxBytesPerMinute, absent))
        'maxBytesPerMinute': maxBytesPerMinute,
      if (!identical(minTotalBytes, absent)) 'minTotalBytes': minTotalBytes,
      if (!identical(maxTotalBytes, absent)) 'maxTotalBytes': maxTotalBytes,
      if (!identical(explanation, absent)) 'explanation': explanation,
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class FieldDiff extends JsonModel {
  FieldDiff({
    required String path,
    Object? before = null,
    Object? after = null,
    JsonMap extensions = const {},
  }) : super({
         'path': path,
         'before': before,
         'after': after,
         'extensions': extensions,
       });
  FieldDiff.fromJson(super.json);
  String get path => data['path'] as String;
  Object? get before => data['before'] ?? null;
  Object? get after => data['after'] ?? null;
  FieldDiff copyWith({
    Object? path = absent,
    Object? before = absent,
    Object? after = absent,
    Object? extensions = absent,
  }) => FieldDiff.fromJson(
    changed({
      if (!identical(path, absent)) 'path': path,
      if (!identical(before, absent)) 'before': before,
      if (!identical(after, absent)) 'after': after,
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class NumericControl extends JsonModel {
  NumericControl({
    String flag = '',
    double min = 0,
    double max = 0,
    double step = 1,
    double? def = null,
    bool lowerIsBetter = true,
    List<List<Object?>> marks = const [],
    JsonMap extensions = const {},
  }) : super({
         'flag': flag,
         'min': min,
         'max': max,
         'step': step,
         'def': def,
         'lowerIsBetter': lowerIsBetter,
         'marks': marks,
         'extensions': extensions,
       });
  NumericControl.fromJson(super.json);
  String get flag => data['flag'] as String? ?? '';
  double get min => (data['min'] as num?)?.toDouble() ?? 0;
  double get max => (data['max'] as num?)?.toDouble() ?? 0;
  double get step => (data['step'] as num?)?.toDouble() ?? 1;
  double? get def => (data['def'] as num?)?.toDouble();
  bool get lowerIsBetter => data['lowerIsBetter'] as bool? ?? true;
  List<List<Object?>> get marks => List<List<Object?>>.unmodifiable(
    (data['marks'] as List? ?? []).map(
      (x) => List<Object?>.unmodifiable(x as List),
    ),
  );
  NumericControl copyWith({
    Object? flag = absent,
    Object? min = absent,
    Object? max = absent,
    Object? step = absent,
    Object? def = absent,
    Object? lowerIsBetter = absent,
    Object? marks = absent,
    Object? extensions = absent,
  }) => NumericControl.fromJson(
    changed({
      if (!identical(flag, absent)) 'flag': flag,
      if (!identical(min, absent)) 'min': min,
      if (!identical(max, absent)) 'max': max,
      if (!identical(step, absent)) 'step': step,
      if (!identical(def, absent)) 'def': def,
      if (!identical(lowerIsBetter, absent)) 'lowerIsBetter': lowerIsBetter,
      if (!identical(marks, absent)) 'marks': marks,
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class ChoiceControl extends JsonModel {
  ChoiceControl({
    String flag = '',
    List<String> values = const [],
    String? def = null,
    JsonMap names = const {},
    bool slowFirst = false,
    String slowLabel = '',
    String fastLabel = '',
    JsonMap extensions = const {},
  }) : super({
         'flag': flag,
         'values': values,
         'def': def,
         'names': names,
         'slowFirst': slowFirst,
         'slowLabel': slowLabel,
         'fastLabel': fastLabel,
         'extensions': extensions,
       });
  ChoiceControl.fromJson(super.json);
  String get flag => data['flag'] as String? ?? '';
  List<String> get values =>
      List<String>.unmodifiable((data['values'] as List? ?? []).cast<String>());
  String? get def => data['def'] as String?;
  JsonMap get names => jsonMap(data['names'] ?? <String, Object?>{});
  bool get slowFirst => data['slowFirst'] as bool? ?? false;
  String get slowLabel => data['slowLabel'] as String? ?? '';
  String get fastLabel => data['fastLabel'] as String? ?? '';
  ChoiceControl copyWith({
    Object? flag = absent,
    Object? values = absent,
    Object? def = absent,
    Object? names = absent,
    Object? slowFirst = absent,
    Object? slowLabel = absent,
    Object? fastLabel = absent,
    Object? extensions = absent,
  }) => ChoiceControl.fromJson(
    changed({
      if (!identical(flag, absent)) 'flag': flag,
      if (!identical(values, absent)) 'values': values,
      if (!identical(def, absent)) 'def': def,
      if (!identical(names, absent)) 'names': names,
      if (!identical(slowFirst, absent)) 'slowFirst': slowFirst,
      if (!identical(slowLabel, absent)) 'slowLabel': slowLabel,
      if (!identical(fastLabel, absent)) 'fastLabel': fastLabel,
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class EncoderProfile extends JsonModel {
  EncoderProfile({
    required String id,
    required String label,
    required String codec,
    required String family,
    String? hw = null,
    String blurb = '',
    List<String> modes = const [],
    NumericControl? quality = null,
    NumericControl? qp = null,
    ChoiceControl? speed = null,
    ChoiceControl? tune = null,
    ChoiceControl? profile = null,
    ChoiceControl? profileQuality = null,
    ChoiceControl? multipass = null,
    JsonMap depths = const {},
    int? depthDef = null,
    JsonMap bitrate = const {},
    NumericControl? vbr = null,
    NumericControl? level = null,
    List<int> rates = const [],
    List<String> fixedArgs = const [],
    String? chroma = null,
    String? appleTag = null,
    String? paramsFlag = null,
    JsonMap extensions = const {},
  }) : super({
         'id': id,
         'label': label,
         'codec': codec,
         'family': family,
         'hw': hw,
         'blurb': blurb,
         'modes': modes,
         'quality': quality?.toJson(),
         'qp': qp?.toJson(),
         'speed': speed?.toJson(),
         'tune': tune?.toJson(),
         'profile': profile?.toJson(),
         'profileQuality': profileQuality?.toJson(),
         'multipass': multipass?.toJson(),
         'depths': depths,
         'depthDef': depthDef,
         'bitrate': bitrate,
         'vbr': vbr?.toJson(),
         'level': level?.toJson(),
         'rates': rates,
         'fixedArgs': fixedArgs,
         'chroma': chroma,
         'appleTag': appleTag,
         'paramsFlag': paramsFlag,
         'extensions': extensions,
       });
  EncoderProfile.fromJson(super.json);
  String get id => data['id'] as String;
  String get label => data['label'] as String;
  String get codec => data['codec'] as String;
  String get family => data['family'] as String;
  String? get hw => data['hw'] as String?;
  String get blurb => data['blurb'] as String? ?? '';
  List<String> get modes =>
      List<String>.unmodifiable((data['modes'] as List? ?? []).cast<String>());
  NumericControl? get quality => data['quality'] == null
      ? null
      : NumericControl.fromJson(jsonMap(data['quality']));
  NumericControl? get qp =>
      data['qp'] == null ? null : NumericControl.fromJson(jsonMap(data['qp']));
  ChoiceControl? get speed => data['speed'] == null
      ? null
      : ChoiceControl.fromJson(jsonMap(data['speed']));
  ChoiceControl? get tune => data['tune'] == null
      ? null
      : ChoiceControl.fromJson(jsonMap(data['tune']));
  ChoiceControl? get profile => data['profile'] == null
      ? null
      : ChoiceControl.fromJson(jsonMap(data['profile']));
  ChoiceControl? get profileQuality => data['profileQuality'] == null
      ? null
      : ChoiceControl.fromJson(jsonMap(data['profileQuality']));
  ChoiceControl? get multipass => data['multipass'] == null
      ? null
      : ChoiceControl.fromJson(jsonMap(data['multipass']));
  JsonMap get depths => jsonMap(data['depths'] ?? <String, Object?>{});
  int? get depthDef => data['depthDef'] as int?;
  JsonMap get bitrate => jsonMap(data['bitrate'] ?? <String, Object?>{});
  NumericControl? get vbr => data['vbr'] == null
      ? null
      : NumericControl.fromJson(jsonMap(data['vbr']));
  NumericControl? get level => data['level'] == null
      ? null
      : NumericControl.fromJson(jsonMap(data['level']));
  List<int> get rates =>
      List<int>.unmodifiable((data['rates'] as List? ?? []).cast<int>());
  List<String> get fixedArgs => List<String>.unmodifiable(
    (data['fixedArgs'] as List? ?? []).cast<String>(),
  );
  String? get chroma => data['chroma'] as String?;
  String? get appleTag => data['appleTag'] as String?;
  String? get paramsFlag => data['paramsFlag'] as String?;
  EncoderProfile copyWith({
    Object? id = absent,
    Object? label = absent,
    Object? codec = absent,
    Object? family = absent,
    Object? hw = absent,
    Object? blurb = absent,
    Object? modes = absent,
    Object? quality = absent,
    Object? qp = absent,
    Object? speed = absent,
    Object? tune = absent,
    Object? profile = absent,
    Object? profileQuality = absent,
    Object? multipass = absent,
    Object? depths = absent,
    Object? depthDef = absent,
    Object? bitrate = absent,
    Object? vbr = absent,
    Object? level = absent,
    Object? rates = absent,
    Object? fixedArgs = absent,
    Object? chroma = absent,
    Object? appleTag = absent,
    Object? paramsFlag = absent,
    Object? extensions = absent,
  }) => EncoderProfile.fromJson(
    changed({
      if (!identical(id, absent)) 'id': id,
      if (!identical(label, absent)) 'label': label,
      if (!identical(codec, absent)) 'codec': codec,
      if (!identical(family, absent)) 'family': family,
      if (!identical(hw, absent)) 'hw': hw,
      if (!identical(blurb, absent)) 'blurb': blurb,
      if (!identical(modes, absent)) 'modes': modes,
      if (!identical(quality, absent))
        'quality': (quality as NumericControl?)?.toJson(),
      if (!identical(qp, absent)) 'qp': (qp as NumericControl?)?.toJson(),
      if (!identical(speed, absent))
        'speed': (speed as ChoiceControl?)?.toJson(),
      if (!identical(tune, absent)) 'tune': (tune as ChoiceControl?)?.toJson(),
      if (!identical(profile, absent))
        'profile': (profile as ChoiceControl?)?.toJson(),
      if (!identical(profileQuality, absent))
        'profileQuality': (profileQuality as ChoiceControl?)?.toJson(),
      if (!identical(multipass, absent))
        'multipass': (multipass as ChoiceControl?)?.toJson(),
      if (!identical(depths, absent)) 'depths': depths,
      if (!identical(depthDef, absent)) 'depthDef': depthDef,
      if (!identical(bitrate, absent)) 'bitrate': bitrate,
      if (!identical(vbr, absent)) 'vbr': (vbr as NumericControl?)?.toJson(),
      if (!identical(level, absent))
        'level': (level as NumericControl?)?.toJson(),
      if (!identical(rates, absent)) 'rates': rates,
      if (!identical(fixedArgs, absent)) 'fixedArgs': fixedArgs,
      if (!identical(chroma, absent)) 'chroma': chroma,
      if (!identical(appleTag, absent)) 'appleTag': appleTag,
      if (!identical(paramsFlag, absent)) 'paramsFlag': paramsFlag,
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class ContainerProfile extends JsonModel {
  ContainerProfile({
    required String id,
    required String label,
    required String muxer,
    required String ext,
    String blurb = '',
    JsonMap extensions = const {},
  }) : super({
         'id': id,
         'label': label,
         'muxer': muxer,
         'ext': ext,
         'blurb': blurb,
         'extensions': extensions,
       });
  ContainerProfile.fromJson(super.json);
  String get id => data['id'] as String;
  String get label => data['label'] as String;
  String get muxer => data['muxer'] as String;
  String get ext => data['ext'] as String;
  String get blurb => data['blurb'] as String? ?? '';
  ContainerProfile copyWith({
    Object? id = absent,
    Object? label = absent,
    Object? muxer = absent,
    Object? ext = absent,
    Object? blurb = absent,
    Object? extensions = absent,
  }) => ContainerProfile.fromJson(
    changed({
      if (!identical(id, absent)) 'id': id,
      if (!identical(label, absent)) 'label': label,
      if (!identical(muxer, absent)) 'muxer': muxer,
      if (!identical(ext, absent)) 'ext': ext,
      if (!identical(blurb, absent)) 'blurb': blurb,
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class ProfileCatalog extends JsonModel {
  ProfileCatalog({
    int profiles = 1,
    String provenance = 'b0-design-fixture',
    List<EncoderProfile> video = const [],
    List<EncoderProfile> audio = const [],
    List<ContainerProfile> containers = const [],
    JsonMap compatibility = const {},
    JsonMap rateModes = const {},
    JsonMap videoOrder = const {},
    JsonMap audioOrder = const {},
    JsonMap extensions = const {},
  }) : super({
         'profiles': profiles,
         'provenance': provenance,
         'video': video.map((v) => v.toJson()).toList(),
         'audio': audio.map((v) => v.toJson()).toList(),
         'containers': containers.map((v) => v.toJson()).toList(),
         'compatibility': compatibility,
         'rateModes': rateModes,
         'videoOrder': videoOrder,
         'audioOrder': audioOrder,
         'extensions': extensions,
       });
  ProfileCatalog.fromJson(super.json);
  int get profiles => data['profiles'] as int? ?? 1;
  String get provenance => data['provenance'] as String? ?? 'b0-design-fixture';
  List<EncoderProfile> get video => List<EncoderProfile>.unmodifiable(
    jsonMaps(data['video'] ?? []).map(EncoderProfile.fromJson),
  );
  List<EncoderProfile> get audio => List<EncoderProfile>.unmodifiable(
    jsonMaps(data['audio'] ?? []).map(EncoderProfile.fromJson),
  );
  List<ContainerProfile> get containers => List<ContainerProfile>.unmodifiable(
    jsonMaps(data['containers'] ?? []).map(ContainerProfile.fromJson),
  );
  JsonMap get compatibility =>
      jsonMap(data['compatibility'] ?? <String, Object?>{});
  JsonMap get rateModes => jsonMap(data['rateModes'] ?? <String, Object?>{});
  JsonMap get videoOrder => jsonMap(data['videoOrder'] ?? <String, Object?>{});
  JsonMap get audioOrder => jsonMap(data['audioOrder'] ?? <String, Object?>{});
  ProfileCatalog copyWith({
    Object? profiles = absent,
    Object? provenance = absent,
    Object? video = absent,
    Object? audio = absent,
    Object? containers = absent,
    Object? compatibility = absent,
    Object? rateModes = absent,
    Object? videoOrder = absent,
    Object? audioOrder = absent,
    Object? extensions = absent,
  }) => ProfileCatalog.fromJson(
    changed({
      if (!identical(profiles, absent)) 'profiles': profiles,
      if (!identical(provenance, absent)) 'provenance': provenance,
      if (!identical(video, absent))
        'video': (video as List<EncoderProfile>)
            .map((v) => v.toJson())
            .toList(),
      if (!identical(audio, absent))
        'audio': (audio as List<EncoderProfile>)
            .map((v) => v.toJson())
            .toList(),
      if (!identical(containers, absent))
        'containers': (containers as List<ContainerProfile>)
            .map((v) => v.toJson())
            .toList(),
      if (!identical(compatibility, absent)) 'compatibility': compatibility,
      if (!identical(rateModes, absent)) 'rateModes': rateModes,
      if (!identical(videoOrder, absent)) 'videoOrder': videoOrder,
      if (!identical(audioOrder, absent)) 'audioOrder': audioOrder,
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class CoreCapabilities extends JsonModel {
  CoreCapabilities({
    required String installationId,
    String label = '',
    String identityKey = '',
    String version = '',
    int? libavformatMajor = null,
    JsonMap encoders = const {},
    JsonMap muxers = const {},
    JsonMap extensions = const {},
  }) : super({
         'installationId': installationId,
         'label': label,
         'identityKey': identityKey,
         'version': version,
         'libavformatMajor': libavformatMajor,
         'encoders': encoders,
         'muxers': muxers,
         'extensions': extensions,
       });
  CoreCapabilities.fromJson(super.json);
  String get installationId => data['installationId'] as String;
  String get label => data['label'] as String? ?? '';
  String get identityKey => data['identityKey'] as String? ?? '';
  String get version => data['version'] as String? ?? '';
  int? get libavformatMajor => data['libavformatMajor'] as int?;
  JsonMap get encoders => jsonMap(data['encoders'] ?? <String, Object?>{});
  JsonMap get muxers => jsonMap(data['muxers'] ?? <String, Object?>{});
  CoreCapabilities copyWith({
    Object? installationId = absent,
    Object? label = absent,
    Object? identityKey = absent,
    Object? version = absent,
    Object? libavformatMajor = absent,
    Object? encoders = absent,
    Object? muxers = absent,
    Object? extensions = absent,
  }) => CoreCapabilities.fromJson(
    changed({
      if (!identical(installationId, absent)) 'installationId': installationId,
      if (!identical(label, absent)) 'label': label,
      if (!identical(identityKey, absent)) 'identityKey': identityKey,
      if (!identical(version, absent)) 'version': version,
      if (!identical(libavformatMajor, absent))
        'libavformatMajor': libavformatMajor,
      if (!identical(encoders, absent)) 'encoders': encoders,
      if (!identical(muxers, absent)) 'muxers': muxers,
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class CoreVersion extends JsonModel {
  CoreVersion({
    String core = '0.1.0-b0-fake',
    int abi = 1,
    int schemaMax = 1,
    int contracts = 1,
    bool isFake = true,
    JsonMap extensions = const {},
  }) : super({
         'core': core,
         'abi': abi,
         'schemaMax': schemaMax,
         'contracts': contracts,
         'isFake': isFake,
         'extensions': extensions,
       });
  CoreVersion.fromJson(super.json);
  String get core => data['core'] as String? ?? '0.1.0-b0-fake';
  int get abi => data['abi'] as int? ?? 1;
  int get schemaMax => data['schemaMax'] as int? ?? 1;
  int get contracts => data['contracts'] as int? ?? 1;
  bool get isFake => data['isFake'] as bool? ?? true;
  CoreVersion copyWith({
    Object? core = absent,
    Object? abi = absent,
    Object? schemaMax = absent,
    Object? contracts = absent,
    Object? isFake = absent,
    Object? extensions = absent,
  }) => CoreVersion.fromJson(
    changed({
      if (!identical(core, absent)) 'core': core,
      if (!identical(abi, absent)) 'abi': abi,
      if (!identical(schemaMax, absent)) 'schemaMax': schemaMax,
      if (!identical(contracts, absent)) 'contracts': contracts,
      if (!identical(isFake, absent)) 'isFake': isFake,
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class TemplateSnapshot extends JsonModel {
  TemplateSnapshot({
    required Recipe recipe,
    Origin? origin = null,
    required VegasPreferences vegasPrefs,
    String writtenBy = '0.1.0-b0-fake',
    JsonMap extensions = const {},
  }) : super({
         'recipe': recipe.toJson(),
         'origin': origin?.toJson(),
         'vegasPrefs': vegasPrefs.toJson(),
         'writtenBy': writtenBy,
         'extensions': extensions,
       });
  TemplateSnapshot.fromJson(super.json);
  Recipe get recipe => Recipe.fromJson(jsonMap(data['recipe']));
  Origin? get origin =>
      data['origin'] == null ? null : Origin.fromJson(jsonMap(data['origin']));
  VegasPreferences get vegasPrefs =>
      VegasPreferences.fromJson(jsonMap(data['vegasPrefs']));
  String get writtenBy => data['writtenBy'] as String? ?? '0.1.0-b0-fake';
  TemplateSnapshot copyWith({
    Object? recipe = absent,
    Object? origin = absent,
    Object? vegasPrefs = absent,
    Object? writtenBy = absent,
    Object? extensions = absent,
  }) => TemplateSnapshot.fromJson(
    changed({
      if (!identical(recipe, absent)) 'recipe': (recipe as Recipe).toJson(),
      if (!identical(origin, absent)) 'origin': (origin as Origin?)?.toJson(),
      if (!identical(vegasPrefs, absent))
        'vegasPrefs': (vegasPrefs as VegasPreferences).toJson(),
      if (!identical(writtenBy, absent)) 'writtenBy': writtenBy,
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class PayloadResult extends JsonModel {
  PayloadResult({
    TemplateSnapshot? snapshot = null,
    bool migrated = false,
    List<Issue> issues = const [],
    JsonMap extensions = const {},
  }) : super({
         'snapshot': snapshot?.toJson(),
         'migrated': migrated,
         'issues': issues.map((v) => v.toJson()).toList(),
         'extensions': extensions,
       });
  PayloadResult.fromJson(super.json);
  TemplateSnapshot? get snapshot => data['snapshot'] == null
      ? null
      : TemplateSnapshot.fromJson(jsonMap(data['snapshot']));
  bool get migrated => data['migrated'] as bool? ?? false;
  List<Issue> get issues => List<Issue>.unmodifiable(
    jsonMaps(data['issues'] ?? []).map(Issue.fromJson),
  );
  PayloadResult copyWith({
    Object? snapshot = absent,
    Object? migrated = absent,
    Object? issues = absent,
    Object? extensions = absent,
  }) => PayloadResult.fromJson(
    changed({
      if (!identical(snapshot, absent))
        'snapshot': (snapshot as TemplateSnapshot?)?.toJson(),
      if (!identical(migrated, absent)) 'migrated': migrated,
      if (!identical(issues, absent))
        'issues': (issues as List<Issue>).map((v) => v.toJson()).toList(),
      if (!identical(extensions, absent)) 'extensions': extensions,
    }),
  );
}

class MacroDefinition extends JsonModel {
  MacroDefinition({
    required String name,
    required String description,
    bool required = false,
    String? value,
  }) : super({
         'name': name,
         'description': description,
         'required': required,
         'value': value,
       });
  MacroDefinition.fromJson(super.json);
  String get name => data['name'] as String;
  String get description => data['description'] as String;
  bool get required => data['required'] as bool? ?? false;
  String? get value => data['value'] as String?;
}
