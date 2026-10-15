// Offline owner-trial inputs, using the existing core and preset repository.
// Does not change trial settings, install files or invoke VEGAS/FFmpeg.
import 'dart:convert';
import 'dart:io';
import 'package:ve_services/ve_services.dart';

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    throw ArgumentError('Pass a fresh output directory and matching core DLL.');
  }
  final output = Directory(args[0]).absolute;
  if (await output.exists()) throw StateError('Preserve existing output.');
  await output.create(recursive: true);
  final core = NativeVeCore.open(args[1]);
  final library = FilePresetLibrary(
    core: core,
    paths: ServicePaths(
      roaming: '${output.path}\\scratch\\Roaming',
      local: '${output.path}\\scratch\\Local',
    ),
  );
  final base = (await library.list()).firstWhere(
    (p) => p.recipe.video.encoder == 'ffv1',
  );
  final records = <Map<String, Object?>>[];
  for (final budget in [4096, 8192, 12288, 16000]) {
    final id = 'b6-capacity-$budget';
    var recipe = base.recipe.copyWith(
      id: id,
      name: 'B6 capacity $budget',
      notes: '',
    );
    TemplateSnapshot snapshot(Recipe value) => TemplateSnapshot(
      recipe: value,
      origin: Origin(presetId: id, revision: 1, name: recipe.name),
      vegasPrefs: VegasPreferences(),
      writtenBy: '0.1.7-recipe-proof',
    );
    final emptyBytes = core.encodePayload(snapshot(recipe)).length;
    // ASCII padding has an exact UTF-8 size and leaves headroom for UI origin
    // labels. A non-ASCII suffix also exercises byte count vs character count.
    const marker = ' END 容量';
    recipe = recipe.copyWith(
      notes: 'N' * (budget - emptyBytes - utf8.encode(marker).length) + marker,
    );
    final bytes = core.encodePayload(snapshot(recipe));
    if (bytes.length != budget ||
        core.decodePayload(bytes).snapshot?.recipe.notes != recipe.notes) {
      throw StateError('Capacity fixture did not round-trip at $budget bytes.');
    }
    await library.save(
      base.copyWith(recipe: recipe, builtin: false, origin: null),
    );
    final filename = '$id.vepreset';
    await File(
      '${output.path}\\$filename',
    ).writeAsString(await library.exportPreset(id));
    records.add({
      'file': filename,
      'envelopeBytes': bytes.length,
      'notesUtf8Bytes': utf8.encode(recipe.notes).length,
    });
  }
  await File('${output.path}\\capacity-inputs.json').writeAsString(
    const JsonEncoder.withIndent('  ').convert({
      'measuredOfflineOnly': true,
      'hostCapacityQualified': false,
      'note':
          'Envelope sizes use the stated origin; popup origin metadata can change the exact size. 16 KiB is the product draft ceiling, not a VEGAS limit.',
      'inputs': records,
    }),
  );
  stdout.writeln(
    'Prepared four capacity presets in ${output.path}; real-host capacity unverified.',
  );
}
