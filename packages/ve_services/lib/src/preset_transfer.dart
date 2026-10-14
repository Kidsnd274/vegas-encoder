import 'dart:convert';
import 'dart:io';
import 'api.dart';
import 'models.dart';
import 'storage.dart';

/// Composes the repository contract; no portable recipe or command rules here.
class PresetTransfer {
  PresetTransfer(this.library);
  final PresetLibrary library;
  Future<void> exportTo(String id, String selectedPath) async =>
      atomicWrite(selectedPath, await library.exportPreset(id));
  Future<String> shareString(String id) async =>
      'vepreset:1:${base64Url.encode(utf8.encode(await library.exportPreset(id)))}';
  Future<Preset> importShareString(String text, {required String newId}) async {
    if (!text.startsWith('vepreset:1:')) {
      throw const ServiceException(
        'SHARE-VERSION',
        'Unsupported preset share string.',
      );
    }
    if (text.length > (jsonFileLimit * 4 ~/ 3) + 16) {
      throw const ServiceException(
        'FILE-LIMIT',
        'Preset share string exceeds 1 MiB decoded.',
      );
    }
    try {
      return await library.importPreset(
        utf8.decode(base64Url.decode(text.substring(11))),
        newId: newId,
      );
    } on FormatException {
      throw const ServiceException(
        'SHARE-INVALID',
        'Preset share string is malformed.',
      );
    }
  }

  Future<Preset> duplicate(
    String id, {
    required String newId,
    String? name,
  }) async {
    final source = await library.get(id);
    if (source == null)
      throw const ServiceException('NOT-FOUND', 'Preset not found.');
    return library.save(
      source.copyWith(
        builtin: false,
        revision: 1,
        recipe: source.recipe.copyWith(
          id: safeId(newId),
          name: name ?? source.recipe.name,
        ),
        origin: source.builtin
            ? 'builtin/${source.recipe.id}'
            : 'preset/${source.recipe.id}@${source.revision}',
      ),
    );
  }

  Future<Preset> fromJob(
    JobRecord job, {
    required String newId,
    String? name,
  }) => library.save(
    Preset(
      updatedAt: DateTime.now().toUtc().toIso8601String(),
      origin: 'job/${safeId(job.id)}',
      requires: PresetRequirements(known: false),
      recipe: job.recipe.copyWith(
        id: safeId(newId),
        name: name ?? job.recipe.name,
      ),
    ),
  );
}

class FakePresetTransfer extends PresetTransfer {
  FakePresetTransfer(super.library);
  final Map<String, String> exported = {};
  @override
  Future<void> exportTo(String id, String selectedPath) async {
    exported[selectedPath] = await library.exportPreset(id);
  }
}

abstract interface class FileReveal {
  Future<void> reveal(String path);
}

class WindowsFileReveal implements FileReveal {
  @override
  Future<void> reveal(String path) async {
    if (!Platform.isWindows)
      throw const ServiceException(
        'UNSUPPORTED-PLATFORM',
        'Explorer requires Windows.',
      );
    if (path.contains('\u0000') ||
        (!RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path) &&
            !path.startsWith(r'\\'))) {
      throw const ServiceException(
        'INVALID-PATH',
        'Reveal requires an absolute Windows path.',
      );
    }
    final entity = await FileSystemEntity.type(path);
    if (entity == FileSystemEntityType.notFound)
      throw const ServiceException('NOT-FOUND', 'File or folder is missing.');
    final windows = Platform.environment['WINDIR'];
    if (windows == null)
      throw const ServiceException(
        'EXPLORER-MISSING',
        'Windows directory is unavailable.',
      );
    try {
      await Process.start(
        joinPath(windows, 'explorer.exe'),
        [entity == FileSystemEntityType.directory ? path : '/select,$path'],
        runInShell: false,
        mode: ProcessStartMode.detached,
      );
    } on ProcessException catch (e) {
      throw ServiceException('REVEAL-FAILED', e.message);
    }
  }
}

class FakeFileReveal implements FileReveal {
  final List<String> revealed = [];
  @override
  Future<void> reveal(String path) async {
    revealed.add(path);
  }
}
