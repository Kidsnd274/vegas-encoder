#include "../../src/core/capi/ve_core.h"
#include <stddef.h>
typedef char ve_buffer_size_check[sizeof(ve_buffer) == 16 ? 1 : -1];
typedef char ve_buffer_offset_check[offsetof(ve_buffer, length) == 8 ? 1 : -1];
int main(void) { return 0; }
