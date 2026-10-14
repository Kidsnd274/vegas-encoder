import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:crypto/crypto.dart';
import 'package:ve_core/ve_core.dart';
import 'api.dart';
import 'models.dart';
import 'storage.dart';
import 'process_runner.dart';

bool absoluteWindowsPath(String path) =>
    RegExp(r'^(?:[A-Za-z]:[\\/]|\\\\)').hasMatch(path) &&
    !path.contains('\u0000');
final _library = RegExp(
  r'^(?:avcodec|avformat|avutil|avdevice|avfilter|swscale|swresample|postproc).*\.dll$',
  caseSensitive: false,
);

class IsolatedHash {
  static Future<String> file(String path) => Isolate.run(
    () async => (await sha256.bind(File(path).openRead()).first).toString(),
  );
}

Future<String> canonicalExecutable(String path) async {
  if (!absoluteWindowsPath(path) || !path.toLowerCase().endsWith('.exe'))
    throw const ServiceException(
      'FFMPEG-PATH',
      'Select an absolute Windows FFmpeg executable path.',
    );
  try {
    return await File(path).resolveSymbolicLinks();
  } on FileSystemException {
    throw const ServiceException(
      'FFMPEG-MISSING',
      'The selected FFmpeg executable is missing or inaccessible.',
    );
  }
}

Future<JsonMap> binaryStats(String path) async {
  final executable = File(path);
  final stat = await executable.stat();
  if (stat.type != FileSystemEntityType.file)
    throw const ServiceException(
      'FFMPEG-MISSING',
      'FFmpeg executable is missing.',
    );
  final libraries = <String, Object?>{};
  final entries = await executable.parent.list(followLinks: false).toList();
  entries.sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
  for (final file in entries) {
    final name = file.uri.pathSegments.last.toLowerCase();
    if (!_library.hasMatch(name)) continue;
    final s = await File(file.path).stat();
    if (s.type != FileSystemEntityType.file)
      throw const ServiceException(
        'FFMPEG-LIBRARY',
        'A sibling FFmpeg library is unreadable.',
      );
    libraries[name] = {
      'size': s.size,
      'mtime': s.modified.toUtc().toIso8601String(),
    };
  }
  return {
    'size': stat.size,
    'mtime': stat.modified.toUtc().toIso8601String(),
    'libraries': libraries,
  };
}

Future<BinaryIdentity> binaryIdentity(String path, int parser) =>
    Isolate.run(() => _identity(path, parser));
Future<BinaryIdentity> _identity(String path, int parser) async {
  await requireX64Pe(path);
  final before = await binaryStats(path);
  final digest = (await sha256.bind(File(path).openRead()).first).toString();
  final libraries = <String, Object?>{};
  final directory = File(path).parent;
  final files = await directory.list(followLinks: false).toList();
  files.sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
  for (final file in files) {
    final name = file.uri.pathSegments.last.toLowerCase();
    if (_library.hasMatch(name))
      libraries[name] = (await sha256.bind(File(file.path).openRead()).first)
          .toString();
  }
  final after = await binaryStats(path);
  if (jsonEncode(before) != jsonEncode(after))
    throw const ServiceException(
      'FFMPEG-CHANGED',
      'FFmpeg files changed while identifying them; retry after the update finishes.',
    );
  final key = sha256
      .convert(
        utf8.encode(
          jsonEncode({
            'parser': parser,
            'sha256': digest,
            'libraries': libraries,
          }),
        ),
      )
      .toString();
  return BinaryIdentity(
    sha256: digest,
    key: key,
    size: before['size'] as int,
    mtime: before['mtime'] as String,
    libraries: libraries,
    extensions: {'fileStats': before, 'parser': parser},
  );
}

Future<void> requireX64Pe(String path) async {
  final file = await File(path).open();
  try {
    final header = await file.read(64);
    if (header.length < 64 || header[0] != 0x4d || header[1] != 0x5a)
      throw const ServiceException(
        'FFMPEG-ARCH',
        'Select a Windows x64 executable.',
      );
    final offset =
        header[60] |
        (header[61] << 8) |
        (header[62] << 16) |
        (header[63] << 24);
    if (offset < 64 || offset > await file.length() - 6)
      throw const ServiceException(
        'FFMPEG-ARCH',
        'Invalid Windows executable header.',
      );
    await file.setPosition(offset);
    final pe = await file.read(6);
    if (pe.length != 6 ||
        pe[0] != 0x50 ||
        pe[1] != 0x45 ||
        pe[2] != 0 ||
        pe[3] != 0 ||
        pe[4] != 0x64 ||
        pe[5] != 0x86) {
      throw const ServiceException(
        'FFMPEG-ARCH',
        'FFmpeg must be Windows x64.',
      );
    }
  } finally {
    await file.close();
  }
}

/// Fast read-only health: stats for executable, FFprobe and sibling libraries.
/// Content hashes are rechecked before any explicit probe/test execution.
Future<FFmpegInstallation> installationHealth(
  FFmpegInstallation installation,
) async {
  try {
    final stats = await binaryStats(installation.path);
    final known = installation.identity.extensions['fileStats'];
    var same = known == null
        ? stats['size'] == installation.identity.size &&
              stats['mtime'] == installation.identity.mtime &&
              jsonMap(stats['libraries']).keys
                  .toSet()
                  .difference(installation.identity.libraries.keys.toSet())
                  .isEmpty &&
              installation.identity.libraries.keys
                  .toSet()
                  .difference(jsonMap(stats['libraries']).keys.toSet())
                  .isEmpty
        : canonicalJson(stats) == canonicalJson(known);
    final probeExists = await File(installation.ffprobePath).exists();
    final probeIdentity = installation.extensions['ffprobeIdentity'];
    if (probeExists && probeIdentity is Map) {
      final probeStats = await File(installation.ffprobePath).stat();
      same =
          same &&
          probeIdentity['size'] == probeStats.size &&
          probeIdentity['mtime'] ==
              probeStats.modified.toUtc().toIso8601String();
    }
    return installation.copyWith(
      health: !same
          ? 'changed'
          : !probeExists
          ? 'ffprobe-missing'
          : 'unchanged',
      healthMessage: !same
          ? 'FFmpeg files changed since they were checked.'
          : !probeExists
          ? 'FFprobe is missing beside FFmpeg.'
          : '',
      availability: same ? installation.availability : <String, Object?>{},
    );
  } on ServiceException {
    return installation.copyWith(
      health: 'missing',
      healthMessage: 'FFmpeg executable or libraries are missing.',
      availability: <String, Object?>{},
    );
  } on FileSystemException {
    return installation.copyWith(
      health: 'missing',
      healthMessage: 'FFmpeg files are inaccessible.',
      availability: <String, Object?>{},
    );
  }
}

Future<void> requireCurrentInstallation(
  FFmpegInstallation installation,
  int parser,
  CancellationToken token,
) async {
  token.check();
  final identity = await binaryIdentity(installation.path, parser);
  token.check();
  if (identity.key != installation.identity.key)
    throw const ServiceException(
      'FFMPEG-CHANGED',
      'FFmpeg changed on disk; probe it again.',
    );
  if (!await File(installation.ffprobePath).exists())
    throw const ServiceException(
      'FFPROBE-MISSING',
      'FFprobe is missing beside FFmpeg.',
    );
  final probe = installation.extensions['ffprobeIdentity'];
  if (probe is! Map ||
      probe['sha256'] != await IsolatedHash.file(installation.ffprobePath)) {
    throw const ServiceException(
      'FFPROBE-CHANGED',
      'FFprobe has changed or was not identified; probe the installation again.',
    );
  }
  token.check();
}
