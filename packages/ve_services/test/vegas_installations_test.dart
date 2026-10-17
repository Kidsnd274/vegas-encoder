import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:ve_services/ve_services.dart';

Future<void> main(List<String> args) async {
  if (args.contains('--local')) {
    final snapshot = await WindowsVegasInstallations().inspect();
    for (final host in snapshot.hosts) {
      print(
        '${host.name} ${host.version}: ${host.state.name}; DLL ${host.exporterVersion}; ${host.executable}',
      );
      for (final detail in host.details) {
        print('  $detail');
      }
    }
    for (final error in snapshot.errors) {
      print('Discovery: $error');
    }
    return;
  }
  var checks = 0;
  void check(bool condition, String message) {
    checks++;
    if (!condition) throw StateError(message);
  }

  final base = await Directory(
    '${Directory.current.path}\\..\\..\\build\\test-results',
  ).absolute.create(recursive: true);
  final canonicalBase = Directory(await base.resolveSymbolicLinks());
  final root = await canonicalBase.createTemp("vegas-status-'容量-");
  final windows = Platform.environment['SystemRoot']!;
  final directories = <String>[];
  Future<Directory> fixture(
    String name, {
    bool installed = true,
    bool pdb = false,
  }) async {
    final dir = await Directory('${root.path}\\$name').create();
    directories.add(dir.path);
    await File('$windows\\System32\\cmd.exe').copy('${dir.path}\\vegas999.exe');
    // Helpers must never appear as hosts.
    await File('${dir.path}\\VegasCapture.exe').writeAsString('not a PE');
    if (!installed) return dir;
    final plugin = await Directory(
      '${dir.path}\\FileIO Plug-Ins\\vegas-encoder',
    ).create(recursive: true);
    await File(
      '$windows\\System32\\version.dll',
    ).copy('${plugin.path}\\vegas-encoder.dll');
    await File(
      '${plugin.path}\\vegas-encoder.ini',
    ).writeAsString('[VegasEncoder]\r\n');
    if (pdb)
      await File(
        '${plugin.path}\\vegas-encoder.pdb',
      ).writeAsString('optional symbols');
    final config = await File(
      '${dir.path}\\VegasEncoder-x64.fio2007-config',
    ).writeAsString('[FileIO Plug-Ins]\r\n');
    final files = <Map<String, String>>[];
    for (final name in [
      'vegas-encoder.dll',
      'vegas-encoder.ini',
      if (pdb) 'vegas-encoder.pdb',
    ]) {
      final f = File('${plugin.path}\\$name');
      files.add({
        'file': f.path,
        'sha256': (await sha256.bind(f.openRead()).first).toString(),
      });
    }
    await File('${plugin.path}\\install-manifest.json').writeAsString(
      jsonEncode({
        'schema': 'vegas-encoder-install/1',
        'product': 'Vegas Encoder',
        'vegasDir': dir.path,
        'pluginDir': plugin.path,
        'files': files,
        'config': config.path,
        'configSha256': (await sha256.bind(config.openRead()).first).toString(),
      }),
    );
    return dir;
  }

  File manifest(Directory d) =>
      File('${d.path}\\FileIO Plug-Ins\\vegas-encoder\\install-manifest.json');
  Future<void> editManifest(
    Directory d,
    void Function(Map<String, dynamic>) edit,
  ) async {
    final m =
        jsonDecode(await manifest(d).readAsString()) as Map<String, dynamic>;
    edit(m);
    await manifest(d).writeAsString(jsonEncode(m));
  }

  try {
    final absent = await fixture('absent', installed: false);
    final verified = await fixture('verified', pdb: true);
    final noManifest = await fixture('no-manifest');
    await manifest(noManifest).delete();
    final unsupported = await fixture('unsupported');
    await editManifest(unsupported, (m) => m['schema'] = 'future-installer/9');
    final changed = await fixture('changed');
    // Keep the PE/version the same; only content hashing can find this change.
    await File(
      '${changed.path}\\FileIO Plug-Ins\\vegas-encoder\\vegas-encoder.ini',
    ).writeAsString('changed');
    final missing = await fixture('missing');
    await File('${missing.path}\\VegasEncoder-x64.fio2007-config').delete();
    final malformed = await fixture('malformed');
    await manifest(malformed).writeAsString('{');
    final escape = await fixture('escaping');
    await editManifest(
      escape,
      (m) => (m['files'] as List).first['file'] = '${root.path}\\outside.dll',
    );
    final duplicate = await fixture('duplicate');
    await editManifest(
      duplicate,
      (m) => (m['files'] as List).add((m['files'] as List).first),
    );
    final unrecorded = await fixture('unrecorded');
    await File(
      '${unrecorded.path}\\FileIO Plug-Ins\\vegas-encoder\\unknown.txt',
    ).writeAsString('preserve');
    final badHost = await fixture('bad-host', installed: false);
    await File('${badHost.path}\\vegas999.exe').writeAsString('invalid PE');
    final missingDll = await fixture('missing-dll');
    await File(
      '${missingDll.path}\\FileIO Plug-Ins\\vegas-encoder\\vegas-encoder.dll',
    ).delete();
    final empty = await WindowsVegasInstallations(
      readRegistry: false,
    ).inspect();
    check(empty.hosts.isEmpty && empty.errors.isEmpty, 'empty discovery');
    final scanner = WindowsVegasInstallations(
      readRegistry: false,
      candidateDirectories: [
        ...directories,
        '${verified.path}\\',
        verified.path.toUpperCase(),
        '${root.path}\\gone',
      ],
    );
    final snapshot = await scanner.inspect();
    check(
      snapshot.hosts.length == directories.length,
      'deduplicated hosts and helpers excluded',
    );
    check(
      snapshot.errors.length == 1 && snapshot.errors.single.contains('gone'),
      'partial directory failure retained',
    );
    VegasHostStatus row(Directory d) => snapshot.hosts.singleWhere(
      (h) => h.executable == '${d.path}\\vegas999.exe',
    );
    for (final (dir, expected) in [
      (absent, VegasInstallationState.notInstalled),
      (verified, VegasInstallationState.verified),
      (noManifest, VegasInstallationState.unverified),
      (unsupported, VegasInstallationState.unverified),
      (changed, VegasInstallationState.changed),
      (missing, VegasInstallationState.changed),
      (malformed, VegasInstallationState.unreadable),
      (escape, VegasInstallationState.unverified),
      (duplicate, VegasInstallationState.unverified),
      (unrecorded, VegasInstallationState.changed),
      (badHost, VegasInstallationState.unreadable),
      (missingDll, VegasInstallationState.changed),
    ]) {
      check(
        row(dir).state == expected,
        '${dir.path}: expected $expected, got ${row(dir).state}: ${row(dir).details}',
      );
    }
    check(
      row(verified).exporterVersion?.isNotEmpty == true,
      'actual DLL version resource',
    );
    check(
      row(verified).x64 && !row(verified).selectedHostVersion,
      'x64 detection never implies support',
    );
    check(
      row(changed).exporterVersion == row(verified).exporterVersion,
      'same DLL version does not imply installation integrity',
    );
    check(
      row(malformed).details.single.isNotEmpty &&
          row(badHost).details.single.contains('PE'),
      'concrete per-host errors',
    );
    check(
      row(escape).details.single.contains('no hashes were trusted'),
      'escaping records not followed',
    );
    check(
      await File(
            '${unrecorded.path}\\FileIO Plug-Ins\\vegas-encoder\\unknown.txt',
          ).readAsString() ==
          'preserve',
      'inspection preserves unknown files',
    );
    // Refresh must discard the previous verified result after bytes change.
    await File(
      '${verified.path}\\FileIO Plug-Ins\\vegas-encoder\\vegas-encoder.pdb',
    ).delete();
    final refreshed = await WindowsVegasInstallations(
      readRegistry: false,
      candidateDirectories: [verified.path],
    ).inspect();
    check(
      refreshed.hosts.single.state == VegasInstallationState.changed,
      'refresh detects missing recorded optional PDB',
    );
    final locked = await fixture('locked');
    final handle = await manifest(locked).open(mode: FileMode.append);
    try {
      await handle.lock(FileLock.exclusive);
      final denied = await WindowsVegasInstallations(
        readRegistry: false,
        candidateDirectories: [locked.path, absent.path],
      ).inspect();
      final unreadable = denied.hosts.singleWhere(
        (h) => h.executable.startsWith(locked.path),
      );
      check(
        unreadable.state == VegasInstallationState.unreadable &&
            unreadable.details.last.contains('Windows error'),
        'locked manifest is unreadable, not missing or unverified',
      );
      check(
        denied.hosts
                .singleWhere((h) => h.executable.startsWith(absent.path))
                .state ==
            VegasInstallationState.notInstalled,
        'one unreadable installation does not hide other hosts',
      );
      await handle.unlock();
    } finally {
      await handle.close();
    }
    final recovered = await WindowsVegasInstallations(
      readRegistry: false,
      candidateDirectories: [locked.path],
    ).inspect();
    check(
      recovered.hosts.single.state == VegasInstallationState.verified,
      'fresh inspection recovers after lock release',
    );
    try {
      await WindowsVegasInstallations(
        readRegistry: false,
        candidateDirectories: List.filled(129, absent.path),
      ).inspect();
      throw StateError('accepted unbounded candidate input');
    } on ServiceException catch (e) {
      check(e.code == 'VEGAS-STATUS', 'native request bounds fail explicitly');
    }
    print(
      'VEGAS installation inspection: $checks checks passed (temporary files, direct Windows API reads; no VEGAS launch).',
    );
  } finally {
    // Only the unique test fixture under this checkout's ignored output root.
    if (!root.path.startsWith('${canonicalBase.path}\\'))
      throw StateError('Unsafe test cleanup');
    await root.delete(recursive: true);
  }
}
