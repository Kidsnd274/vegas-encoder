typedef JsonMap = Map<String, Object?>;

/// Used by copyWith to distinguish an omitted parameter from explicit null.
const Object absent = _Absent();

class _Absent {
  const _Absent();
}

Object? _freeze(Object? value) {
  if (value is Map) {
    return Map<String, Object?>.unmodifiable(
      value.map((key, value) {
        if (key is! String) throw FormatException('JSON keys must be strings');
        return MapEntry(key, _freeze(value));
      }),
    );
  }
  if (value is List) return List<Object?>.unmodifiable(value.map(_freeze));
  if (value == null || value is String || value is bool || value is num) {
    if (value is num && !value.isFinite)
      throw FormatException('Non-finite JSON number');
    return value;
  }
  throw FormatException('Not a JSON value: ${value.runtimeType}');
}

Object? _thaw(Object? value) {
  if (value is Map)
    return value.map((key, value) => MapEntry(key as String, _thaw(value)));
  if (value is List) return value.map(_thaw).toList();
  return value;
}

JsonMap jsonMap(Object? value) => Map<String, Object?>.from(value as Map);
List<JsonMap> jsonMaps(Object? value) => (value as List).map(jsonMap).toList();

/// Deeply immutable JSON storage. Unknown keys (including nested ones) round-trip
/// at their original positions. Reading a default never inserts it into JSON.
abstract class JsonModel {
  JsonModel(JsonMap json) : data = _freeze(json) as JsonMap;
  final JsonMap data;
  JsonMap toJson() => _thaw(data) as JsonMap;
  JsonMap get extensions => jsonMap(data['extensions'] ?? <String, Object?>{});
  JsonMap changed(JsonMap updates) => {...toJson(), ...updates};
}
