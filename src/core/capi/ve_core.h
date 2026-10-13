#ifndef VEGAS_ENCODER_VE_CORE_H
#define VEGAS_ENCODER_VE_CORE_H

/* Product core ABI 1, contract 1. Implemented/built in B2.
 * Portable C and C++17. No Windows or VEGAS types cross this boundary. */
#include <stdint.h>

#if defined(_WIN32) && defined(VE_CORE_BUILD_DLL)
#define VE_CORE_API __declspec(dllexport)
#elif defined(_WIN32) && defined(VE_CORE_USE_DLL)
#define VE_CORE_API __declspec(dllimport)
#else
#define VE_CORE_API
#endif

#ifdef __cplusplus
extern "C" {
#endif

#define VE_CORE_ABI_VERSION 1u
#define VE_CORE_SCHEMA_MAX 1u
#define VE_CORE_JSON_LIMIT 1048576u
#define VE_CORE_PAYLOAD_LIMIT 16384u

typedef struct ve_buffer {
    uint8_t* data;
    uint32_t length;
} ve_buffer;

typedef enum ve_status {
    VE_OK = 0,
    VE_INVALID_ARGUMENT = 1,
    VE_INVALID_JSON = 2,
    VE_UNSUPPORTED_VERSION = 3,
    VE_LIMIT_EXCEEDED = 4,
    VE_OUT_OF_MEMORY = 5,
    VE_INTERNAL_ERROR = 6
} ve_status;

/* All JSON is UTF-8, counted bytes, no trailing NUL included/required.
 * Functions are synchronous/reentrant. Inputs are borrowed only for the call.
 * Set result to {NULL,0} before calling. A returned allocation (including an
 * error JSON allocation on failure) must be released once with ve_free.
 * ve_free(NULL) is allowed. Never use host allocators or a foreign CRT to free.
 * An error status does not imply a result allocation exists (notably OOM).
 * Validation errors are domain issues with VE_OK, not transport failures.
 * No function opens a file, probes FFmpeg, or calls the host. */
VE_CORE_API uint32_t ve_core_abi_version(void);
VE_CORE_API uint32_t ve_schema_max(void);
VE_CORE_API void ve_free(void* allocation);
VE_CORE_API ve_status ve_core_version(ve_buffer* result);
VE_CORE_API ve_status ve_profiles(ve_buffer* result);
VE_CORE_API ve_status ve_recipe_normalize(const uint8_t* json, uint32_t length, ve_buffer* result);
VE_CORE_API ve_status ve_recipe_validate(const uint8_t* json, uint32_t length, ve_buffer* result);
VE_CORE_API ve_status ve_compile(const uint8_t* json, uint32_t length, ve_buffer* result);
VE_CORE_API ve_status ve_template_lint(const uint8_t* json, uint32_t length, ve_buffer* result);
VE_CORE_API ve_status ve_template_complete(const uint8_t* json, uint32_t length, ve_buffer* result);
VE_CORE_API ve_status ve_estimate(const uint8_t* json, uint32_t length, ve_buffer* result);
VE_CORE_API ve_status ve_recipe_diff(const uint8_t* json, uint32_t length, ve_buffer* result);
/* encode returns binary envelope; decode takes binary envelope, returns JSON. */
VE_CORE_API ve_status ve_payload_encode(const uint8_t* json, uint32_t length, ve_buffer* result);
VE_CORE_API ve_status ve_payload_decode(const uint8_t* bytes, uint32_t length, ve_buffer* result);
/* Pure C4 structural validation/serialization; never session file I/O.
 * Results: {request:originalObject,issues:Issue[]} / {result:originalObject,issues:Issue[]}.
 * Matching sessionId and one-final-result file semantics stay in ve_services/adapter. */
VE_CORE_API ve_status ve_session_request_validate(const uint8_t* json, uint32_t length, ve_buffer* result);
VE_CORE_API ve_status ve_session_result_validate(const uint8_t* json, uint32_t length, ve_buffer* result);

#ifdef __cplusplus
}
#endif
#endif
