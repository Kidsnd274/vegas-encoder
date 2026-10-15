import 'dart:convert';
import 'dart:ffi';
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'api.dart';
import 'json_model.dart';
import 'models.dart';
import 'native_bindings.dart';

/// Isolate-local facade over the C++ core. No domain rules live in Dart.
class NativeVeCore implements VeCore, VeCoreMacroCatalog {
  factory NativeVeCore({bool cacheCapabilities = true}) =>
      NativeVeCore._load(NativeBindings.assets, cacheCapabilities);

  /// Explicit DLL loading for adapter parity tests and deployment diagnostics.
  /// Normal app usage uses the bundled native asset from hook/build.dart.
  factory NativeVeCore.open(String dllPath, {bool cacheCapabilities = true}) =>
      NativeVeCore._load(
        () => NativeBindings.library(DynamicLibrary.open(dllPath)),
        cacheCapabilities,
      );

  static NativeVeCore _load(
    NativeBindings Function() load,
    bool cacheCapabilities,
  ) {
    if (!Platform.isWindows || Abi.current() != Abi.windowsX64) {
      throw const CoreException(
        'UNSUPPORTED-PLATFORM',
        'Vegas Encoder requires Windows x64.',
      );
    }
    try {
      final bindings = load();
      if (sizeOf<NativeBuffer>() != 16 || bindings.abiVersion() != 1) {
        throw const CoreException(
          'ABI-MISMATCH',
          'Core ABI does not match this app.',
        );
      }
      return NativeVeCore._(bindings, cacheCapabilities);
    } on CoreException {
      rethrow;
    } catch (e) {
      throw CoreException('NATIVE-LOAD', 'Cannot load the product core: $e');
    }
  }

  NativeVeCore._(this._bindings, this._cacheCapabilities);
  final bool _cacheCapabilities;
  final NativeBindings _bindings;
  static const _jsonLimit = 1048576;

  Uint8List _buffer(Uint8List? input, {NativeCall? call, NativeRead? read}) {
    if (input != null && input.length > _jsonLimit) {
      throw const CoreException(
        'JSON-LIMIT',
        'Input exceeds the 1 MiB transport limit.',
      );
    }
    final out = calloc<NativeBuffer>();
    Pointer<Uint8> incoming = nullptr;
    try {
      if (input != null) {
        incoming = calloc<Uint8>(input.isEmpty ? 1 : input.length);
        incoming.asTypedList(input.length).setAll(0, input);
      }
      final status = read != null
          ? read(out)
          : call!(incoming, input!.length, out);
      if (out.ref.length > _jsonLimit ||
          (out.ref.length > 0 && out.ref.data == nullptr)) {
        throw const CoreException(
          'NATIVE-RESULT',
          'Invalid core result buffer.',
        );
      }
      final bytes = out.ref.data == nullptr
          ? Uint8List(0)
          : Uint8List.fromList(out.ref.data.asTypedList(out.ref.length));
      if (status != 0) {
        if (bytes.isNotEmpty) {
          try {
            final error = jsonMap(
              jsonMap(jsonDecode(utf8.decode(bytes)))['error'],
            );
            throw CoreException(
              error['code'] as String,
              error['message'] as String,
            );
          } on CoreException {
            rethrow;
          } catch (_) {
            /* Fall back to the transport status when error JSON is absent/invalid. */
          }
        }
        throw CoreException(
          'NATIVE-STATUS-$status',
          'Core transport failed (status $status).',
        );
      }
      return bytes; // Independent copy: native memory is freed before returning.
    } finally {
      if (out.ref.data != nullptr) _bindings.free(out.ref.data.cast<Void>());
      if (incoming != nullptr) calloc.free(incoming);
      calloc.free(out);
    }
  }

  JsonMap _decode(Uint8List bytes) {
    try {
      return jsonMap(jsonDecode(utf8.decode(bytes)));
    } catch (e) {
      throw CoreException('NATIVE-JSON', 'Invalid core result JSON: $e');
    }
  }

  JsonMap _call(String operation, JsonMap request) => _decode(
    _buffer(
      Uint8List.fromList(utf8.encode(jsonEncode(request))),
      call: _bindings.calls[operation]!,
    ),
  );

  // Identity, not installationId/identityKey: lazy details and hardware facts can
  // change without changing the binary identity. CoreCapabilities is immutable.
  final _capabilities = Map<CoreCapabilities, String>.identity();

  /// Optional early release; abandoned facades still occupy at most the DLL's
  /// bounded eight-entry LRU. Existing VeCore callers need no lifecycle changes.
  void clearCapabilitiesCache() {
    for (final id in _capabilities.values) {
      _call('capabilitiesRelease', {'capabilitiesId': id});
    }
    _capabilities.clear();
  }

  String _snapshot(CoreCapabilities capabilities) {
    final prior = _capabilities.remove(capabilities);
    if (prior != null) {
      _capabilities[capabilities] = prior;
      return prior;
    }
    final id =
        _call('capabilitiesStore', capabilities.data)['capabilitiesId']
            as String;
    _capabilities[capabilities] = id;
    if (_capabilities.length > 4) {
      final oldest = _capabilities.keys.first;
      _call('capabilitiesRelease', {
        'capabilitiesId': _capabilities.remove(oldest),
      });
    }
    return id;
  }

  JsonMap _withCapabilities(
    String operation,
    JsonMap request,
    CoreCapabilities? capabilities,
  ) {
    if (capabilities == null) return _call(operation, request);
    if (!_cacheCapabilities)
      return _call(operation, {...request, 'capabilities': capabilities.data});
    JsonMap invoke() => _call(operation, {
      ...request,
      'capabilitiesId': _snapshot(capabilities),
    });
    for (var attempt = 0; ; attempt++) {
      try {
        return invoke();
      } on CoreException catch (e) {
        // The optional cache has a tighter node bound than the legacy transport.
        // Valid larger maps still use the original inline request semantics.
        if (e.code == 'CAPABILITIES-LIMIT') {
          return _call(operation, {
            ...request,
            'capabilities': capabilities.data,
          });
        }
        if (e.code != 'CAPABILITIES-STALE' || attempt != 0) rethrow;
        _capabilities.remove(capabilities);
      }
    }
  }

  @override
  CoreVersion get version =>
      CoreVersion.fromJson(_decode(_buffer(null, read: _bindings.version)));
  @override
  ProfileCatalog profiles() =>
      ProfileCatalog.fromJson(_decode(_buffer(null, read: _bindings.profiles)));
  @override
  NormalizeResult normalize(JsonMap json) =>
      NormalizeResult.fromJson(_call('normalize', {'recipe': json}));
  @override
  List<Issue> validate(
    Recipe recipe, {
    MediaDescription? media,
    CoreCapabilities? capabilities,
  }) => jsonMaps(
    _withCapabilities('validate', {
      'recipe': recipe.toJson(),
      'media': media?.toJson(),
    }, capabilities)['issues'],
  ).map(Issue.fromJson).toList(growable: false);
  @override
  CompileResult compile(
    Recipe recipe, {
    required MediaDescription media,
    required CompilePaths paths,
    CoreCapabilities? capabilities,
  }) => CompileResult.fromJson(
    _withCapabilities('compile', {
      'recipe': recipe.toJson(),
      'media': media.toJson(),
      'paths': paths.toJson(),
    }, capabilities),
  );
  @override
  List<Diagnostic> lint(String text, {CoreCapabilities? capabilities}) =>
      jsonMaps(
        _withCapabilities('lint', {'text': text}, capabilities)['diagnostics'],
      ).map(Diagnostic.fromJson).toList(growable: false);
  @override
  CompletionResult complete(
    String text,
    int caret, {
    CoreCapabilities? capabilities,
  }) => CompletionResult.fromJson(
    _withCapabilities('complete', {'text': text, 'caret': caret}, capabilities),
  );
  @override
  SizeEstimate estimate(
    Recipe recipe, {
    required MediaDescription media,
    double? durationSec,
  }) => SizeEstimate.fromJson(
    _call('estimate', {
      'recipe': recipe.toJson(),
      'media': media.toJson(),
      'durationSec': durationSec,
    }),
  );
  @override
  List<FieldDiff> diff(Recipe before, Recipe after) => jsonMaps(
    _call('diff', {'before': before.toJson(), 'after': after.toJson()})['diff'],
  ).map(FieldDiff.fromJson).toList(growable: false);
  @override
  Uint8List encodePayload(TemplateSnapshot snapshot) => _buffer(
    Uint8List.fromList(utf8.encode(jsonEncode(snapshot.toJson()))),
    call: _bindings.calls['encode']!,
  );
  @override
  PayloadResult decodePayload(Uint8List bytes) => PayloadResult.fromJson(
    _decode(_buffer(bytes, call: _bindings.calls['decode']!)),
  );

  @override
  List<MacroDefinition> macros({
    required MediaDescription media,
    required CompilePaths paths,
    Recipe? recipe,
  }) => jsonMaps(
    _call('macros', {
      'media': media.toJson(),
      'paths': paths.toJson(),
      if (recipe != null) 'recipe': recipe.toJson(),
    })['macros'],
  ).map(MacroDefinition.fromJson).toList(growable: false);

  /// C4 pure checks; ve_services/adapter still own file I/O and session lifetime.
  JsonMap validateSessionRequest(JsonMap request) =>
      _call('sessionRequest', request);
  JsonMap validateSessionResult(JsonMap result) =>
      _call('sessionResult', result);
}
