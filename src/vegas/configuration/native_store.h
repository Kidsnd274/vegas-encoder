#pragma once

#include "proof_page.h"
#include "../abi/configuration_abi.h"

namespace vegas_encoder::configuration {

// Adapts the measured holder to owned values. Retains the queried holder and
// the matching host allocator. No borrowed template escapes Load/Commit.
HRESULT CreateNativeTemplateStore(IUnknown* object, sfio::ISfHostAllocator* allocator,
                                  IProofTemplateStore** store) noexcept;

}  // namespace vegas_encoder::configuration
