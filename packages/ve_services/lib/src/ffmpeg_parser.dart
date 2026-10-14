// Authored parser adapted from this repository's Capture-FFmpegFacts.py (B1).
// Literal strings, duplicate declarations and aliases are preserved; no encoder
// policy, compiler or validation rules are implemented here.
import 'dart:convert';
import 'package:ve_core/ve_core.dart';
import 'api.dart';
import 'models.dart';

class WindowsFFmpegHelpParser implements FFmpegHelpParser {
  @override
  int get version => 2;
  static const _flags = r'[EDFVASXRBT.P]{11}';
  final _option = RegExp(
    r'^\s{2,}-([^\s]+)\s+(\[?<[^>]+>\]?)\s*(' + _flags + r')\s*(.*)$',
  );
  final _constant = RegExp(
    r'^\s{5,}(\S+)\s+(?:(\S+)\s+)?(' + _flags + r')\s*(.*)$',
  );
  void _bound(String text) {
    if (utf8.encode(text).length > 4 * 1024 * 1024)
      throw const ServiceException('HELP-LIMIT', 'FFmpeg help exceeds 4 MiB.');
  }

  @override
  EncoderDetails parseEncoderHelp(String text) {
    _bound(text);
    final header = RegExp(
      r'^Encoder (\S+) \[',
      multiLine: true,
    ).firstMatch(text.replaceAll('\r', ''));
    if (header == null)
      throw const ServiceException(
        'ENCODER-NOT-FOUND',
        'FFmpeg did not recognize this encoder.',
      );
    List<String> formats(String label) {
      final match = RegExp(
        r'^\s+Supported ' + label + r': (.*)$',
        multiLine: true,
      ).firstMatch(text.replaceAll('\r', ''));
      return match == null
          ? []
          : match[1]!
                .trim()
                .split(RegExp(r'\s+'))
                .where((s) => s.isNotEmpty)
                .toList();
    }

    final pixels = formats('pixel formats');
    final samples = formats('sample formats');
    final kind = samples.isNotEmpty || text.contains('E...A')
        ? 'audio'
        : 'video';
    final options = parseOptions(text);
    return EncoderDetails.fromJson({
      ...EncoderDetails(
        name: header[1]!,
        kind: kind,
        pixelFormats: pixels,
        sampleFormats: samples,
        sampleRates: formats('sample rates').map(int.parse).toList(),
        options: options,
      ).data,
      'recognized': true,
    });
  }

  List<EncoderOption> parseOptions(String text) {
    _bound(text);
    final options = <JsonMap>[];
    JsonMap? current;
    for (final line in const LineSplitter().convert(
      text.replaceAll('\r', ''),
    )) {
      final match = _option.firstMatch(line);
      if (match != null) {
        final name = match[1]!;
        var description = match[4]!;
        final def = RegExp(r'\s*\(default (.*?)\)\s*$').firstMatch(description);
        if (def != null) description = description.substring(0, def.start);
        final bounds = RegExp(
          r'\s*\(from (\S+) to (\S+)\)\s*$',
        ).firstMatch(description);
        if (bounds != null)
          description = description.substring(0, bounds.start);
        current = options.where((o) => o['name'] == name).firstOrNull;
        if (current == null) {
          var defaultValue = def?[1];
          if (defaultValue != null)
            defaultValue = defaultValue.replaceAll(RegExp(r'^"|"$'), '');
          current = {
            'name': name,
            'aliases': <String>[],
            'type': match[2]!.replaceAll(RegExp(r'[<>\[\]]'), ''),
            'flags': match[3],
            'description': description.trim(),
            'min': bounds?[1],
            'max': bounds?[2],
            'defaultValue': defaultValue,
            'constants': <JsonMap>[],
          };
          options.add(current);
        }
      } else {
        final constant = _constant.firstMatch(line);
        if (constant != null && current != null) {
          final value = {
            'name': constant[1],
            'value': constant[2],
            'description': constant[4]!.trim(),
          };
          final constants = current['constants'] as List<JsonMap>;
          if (!constants.any((c) => jsonEncode(c) == jsonEncode(value)))
            constants.add(value);
        }
      }
    }
    final merged = <JsonMap>[];
    for (final option in options) {
      final alias = merged
          .where(
            (o) =>
                (o['name'] as String).replaceAll('_', '-') ==
                    (option['name'] as String).replaceAll('_', '-') &&
                [
                  'type',
                  'min',
                  'max',
                  'defaultValue',
                  'description',
                  'constants',
                ].every((key) => jsonEncode(o[key]) == jsonEncode(option[key])),
          )
          .firstOrNull;
      if (alias != null)
        (alias['aliases'] as List<String>).add(option['name'] as String);
      else
        merged.add(option);
    }
    return List.unmodifiable(merged.map(EncoderOption.fromJson));
  }

  @override
  JsonMap parseEncoders(String text) {
    _bound(text);
    if (!text.contains('Encoders:'))
      throw const ServiceException(
        'HELP-PARSE',
        'Missing FFmpeg encoder-list header.',
      );
    final entries = <String, Object?>{};
    for (final m in RegExp(
      r'^\s+([VAS][A-Z.]{5})\s+(\S+)\s+(.*)$',
      multiLine: true,
    ).allMatches(text.replaceAll('\r', ''))) {
      if (m[2] == '=') continue;
      entries[m[2]!] = {
        'kind': {'V': 'video', 'A': 'audio', 'S': 'subtitle'}[m[1]![0]],
        'flags': m[1],
        'description': m[3],
        'codec': RegExp(r'\(codec ([A-Za-z0-9_]+)\)').firstMatch(m[3]!)?[1],
      };
    }
    if (entries.isEmpty)
      throw const ServiceException('HELP-PARSE', 'Empty FFmpeg encoder list.');
    return entries;
  }

  @override
  JsonMap parseMuxers(String text) {
    _bound(text);
    if (!text.contains('File formats:') &&
        !text.contains('Muxers:') &&
        !text.contains('Formats:'))
      throw const ServiceException(
        'HELP-PARSE',
        'Missing FFmpeg muxer-list header.',
      );
    final entries = <String, Object?>{};
    for (final m in RegExp(
      r'^\s+([D.Ed ]*E[D.Ed ]*)\s+(\S+)\s+(.*)$',
      multiLine: true,
    ).allMatches(text.replaceAll('\r', ''))) {
      if (m[2] == '=') continue;
      for (final name in m[2]!.split(',')) {
        entries[name] = {
          'flags': m[1]!.trim(),
          'description': m[3],
          'canonical': m[2]!.split(',').first,
          'aliases': m[2]!.split(','),
        };
      }
    }
    if (entries.isEmpty)
      throw const ServiceException('HELP-PARSE', 'Empty FFmpeg muxer list.');
    return entries;
  }

  JsonMap parseVersion(String text) {
    _bound(text);
    final version = RegExp(
      r'^ffmpeg version (\S+)',
      multiLine: true,
    ).firstMatch(text.replaceAll('\r', ''));
    final configuration = RegExp(
      r'^configuration: (.*)$',
      multiLine: true,
    ).firstMatch(text.replaceAll('\r', ''));
    final libraries = <String, Object?>{};
    for (final m in RegExp(
      r'^\s*(lib\w+)\s+\d+\.\s*\d+\.\s*\d+\s*/\s*(\d+)\.\s*(\d+)\.\s*(\d+)\s*$',
      multiLine: true,
    ).allMatches(text.replaceAll('\r', ''))) {
      libraries[m[1]!] = '${m[2]}.${m[3]}.${m[4]}';
    }
    if (version == null ||
        configuration == null ||
        libraries.isEmpty ||
        !libraries.containsKey('libavformat')) {
      throw const ServiceException(
        'VERSION-PARSE',
        'Cannot read complete FFmpeg version/configuration/libraries.',
      );
    }
    final build = RegExp(
      r'^built with (.*)$',
      multiLine: true,
    ).firstMatch(text.replaceAll('\r', ''));
    return {
      'version': version[1],
      'configuration': configuration[1],
      'libraries': libraries,
      'build': build?[1] ?? '',
      'license': configuration[1]!.contains('--enable-nonfree')
          ? 'nonfree'
          : configuration[1]!.contains('--enable-gpl')
          ? 'GPL'
          : 'LGPL',
    };
  }

  JsonMap parseProbeVersion(String text) {
    try {
      final data = jsonMap(jsonDecode(text));
      final program = jsonMap(data['program_version']);
      final libraries = <String, Object?>{};
      for (final entry in jsonMaps(data['library_versions'])) {
        libraries[entry['name'] as String] =
            '${entry['major']}.${entry['minor']}.${entry['micro']}';
      }
      if (program['version'] is! String ||
          program['configuration'] is! String ||
          libraries.isEmpty)
        throw const FormatException();
      return {
        'version': program['version'],
        'configuration': program['configuration'],
        'libraries': libraries,
      };
    } catch (_) {
      throw const ServiceException(
        'VERSION-PARSE',
        'Cannot read FFprobe identity JSON.',
      );
    }
  }
}
