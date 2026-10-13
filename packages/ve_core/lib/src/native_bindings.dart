// Hand-authored bindings for the small counted-buffer C ABI in ve_core.h.
// No generated SDK surface or platform handles cross this boundary.
import 'dart:ffi';

final class NativeBuffer extends Struct {
  external Pointer<Uint8> data;
  @Uint32()
  external int length;
}

typedef NativeCall = int Function(Pointer<Uint8>, int, Pointer<NativeBuffer>);
typedef NativeSignature =
    Int32 Function(Pointer<Uint8>, Uint32, Pointer<NativeBuffer>);
typedef NativeRead = int Function(Pointer<NativeBuffer>);
typedef ReadSignature = Int32 Function(Pointer<NativeBuffer>);

@Native<Uint32 Function()>(symbol: 've_core_abi_version')
external int nativeAbiVersion();
@Native<Void Function(Pointer<Void>)>(symbol: 've_free')
external void nativeFree(Pointer<Void> pointer);
@Native<ReadSignature>(symbol: 've_core_version')
external int nativeVersion(Pointer<NativeBuffer> result);
@Native<ReadSignature>(symbol: 've_profiles')
external int nativeProfiles(Pointer<NativeBuffer> result);
@Native<NativeSignature>(symbol: 've_recipe_normalize')
external int nativeNormalize(
  Pointer<Uint8> json,
  int length,
  Pointer<NativeBuffer> result,
);
@Native<NativeSignature>(symbol: 've_recipe_validate')
external int nativeValidate(
  Pointer<Uint8> json,
  int length,
  Pointer<NativeBuffer> result,
);
@Native<NativeSignature>(symbol: 've_compile')
external int nativeCompile(
  Pointer<Uint8> json,
  int length,
  Pointer<NativeBuffer> result,
);
@Native<NativeSignature>(symbol: 've_template_lint')
external int nativeLint(
  Pointer<Uint8> json,
  int length,
  Pointer<NativeBuffer> result,
);
@Native<NativeSignature>(symbol: 've_template_complete')
external int nativeComplete(
  Pointer<Uint8> json,
  int length,
  Pointer<NativeBuffer> result,
);
@Native<NativeSignature>(symbol: 've_estimate')
external int nativeEstimate(
  Pointer<Uint8> json,
  int length,
  Pointer<NativeBuffer> result,
);
@Native<NativeSignature>(symbol: 've_recipe_diff')
external int nativeDiff(
  Pointer<Uint8> json,
  int length,
  Pointer<NativeBuffer> result,
);
@Native<NativeSignature>(symbol: 've_payload_encode')
external int nativeEncode(
  Pointer<Uint8> json,
  int length,
  Pointer<NativeBuffer> result,
);
@Native<NativeSignature>(symbol: 've_payload_decode')
external int nativeDecode(
  Pointer<Uint8> bytes,
  int length,
  Pointer<NativeBuffer> result,
);
@Native<NativeSignature>(symbol: 've_session_request_validate')
external int nativeSessionRequest(
  Pointer<Uint8> json,
  int length,
  Pointer<NativeBuffer> result,
);
@Native<NativeSignature>(symbol: 've_session_result_validate')
external int nativeSessionResult(
  Pointer<Uint8> json,
  int length,
  Pointer<NativeBuffer> result,
);

class NativeBindings {
  NativeBindings.assets()
    : abiVersion = nativeAbiVersion,
      free = nativeFree,
      version = nativeVersion,
      profiles = nativeProfiles,
      calls = {
        'normalize': nativeNormalize,
        'validate': nativeValidate,
        'compile': nativeCompile,
        'lint': nativeLint,
        'complete': nativeComplete,
        'estimate': nativeEstimate,
        'diff': nativeDiff,
        'encode': nativeEncode,
        'decode': nativeDecode,
        'sessionRequest': nativeSessionRequest,
        'sessionResult': nativeSessionResult,
      };
  NativeBindings.library(DynamicLibrary library)
    : abiVersion = library.lookupFunction<Uint32 Function(), int Function()>(
        've_core_abi_version',
      ),
      free = library
          .lookupFunction<
            Void Function(Pointer<Void>),
            void Function(Pointer<Void>)
          >('ve_free'),
      version = library.lookupFunction<ReadSignature, NativeRead>(
        've_core_version',
      ),
      profiles = library.lookupFunction<ReadSignature, NativeRead>(
        've_profiles',
      ),
      calls = {
        for (final entry in {
          'normalize': 've_recipe_normalize',
          'validate': 've_recipe_validate',
          'compile': 've_compile',
          'lint': 've_template_lint',
          'complete': 've_template_complete',
          'estimate': 've_estimate',
          'diff': 've_recipe_diff',
          'encode': 've_payload_encode',
          'decode': 've_payload_decode',
          'sessionRequest': 've_session_request_validate',
          'sessionResult': 've_session_result_validate',
        }.entries)
          entry.key: library.lookupFunction<NativeSignature, NativeCall>(
            entry.value,
          ),
      };
  final int Function() abiVersion;
  final void Function(Pointer<Void>) free;
  final NativeRead version;
  final NativeRead profiles;
  final Map<String, NativeCall> calls;
}
