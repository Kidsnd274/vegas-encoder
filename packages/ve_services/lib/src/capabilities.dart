import 'dart:convert';
import 'package:ve_core/ve_core.dart';
import 'models.dart';

final _coreViews = Expando<Map<String, CoreCapabilities>>();

extension FFmpegCapabilitiesCoreView on FFmpegCapabilities {
  /// Basic retains every availability/codec name and active streams' full option
  /// facts. Advanced retains the full map; commands are never parsed in Dart.
  CoreCapabilities toCoreCapabilities({String label = '', Recipe? recipe}) {
    final basic = recipe?.command.mode == 'structured';
    final selected = basic
        ? <String>{recipe!.video.encoder, ...recipe.audio.map((a) => a.encoder)}
        : null;
    final key = jsonEncode([
      label,
      if (selected != null) (selected.toList()..sort()),
    ]);
    final views = _coreViews[this] ??= {};
    JsonMap projectEncoder(String name, Object? value) {
      final entry = jsonMap(value);
      final availability = jsonMap(entry['availability'] ?? {});
      return {
        if (selected!.contains(name))
          ...entry
        else
          for (final field in ['name', 'kind', 'codec'])
            if (entry.containsKey(field)) field: entry[field],
        if (entry.containsKey('availability'))
          'availability': {
            for (final field in ['state', 'reason'])
              if (availability.containsKey(field)) field: availability[field],
          },
      };
    }

    return views.putIfAbsent(
      key,
      () => CoreCapabilities(
        installationId: installationId,
        label: label,
        identityKey: identityKey,
        version: version,
        libavformatMajor: libavformatMajor,
        encoders: selected == null
            ? encoders
            : {
                for (final entry in encoders.entries)
                  entry.key: projectEncoder(entry.key, entry.value),
              },
        muxers: selected == null
            ? muxers
            : {
                for (final entry in muxers.entries)
                  entry.key: <String, Object?>{},
              },
      ),
    );
  }
}
