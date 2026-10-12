#include "../../src/core/capi/ve_core.h"
#include <cstddef>
#include <type_traits>

static_assert(VE_CORE_ABI_VERSION == 1u, "ABI contract");
static_assert(VE_CORE_SCHEMA_MAX == 1u, "recipe contract");
static_assert(std::is_standard_layout<ve_buffer>::value, "C-compatible buffer");
static_assert(sizeof(uint32_t) == 4, "count width");
static_assert(sizeof(void*) == 8, "Windows x64 only");
static_assert(offsetof(ve_buffer, length) == 8, "x64 buffer offset");
static_assert(sizeof(ve_buffer) == 16, "x64 buffer size");
int main() { return 0; }
