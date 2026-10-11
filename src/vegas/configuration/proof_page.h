// Minimal COM page, built into the offline harness and opt-in native proof DLL.
#pragma once

#include "template_draft.h"

namespace vegas_encoder::configuration {

// Product-owned in-process test seam. This is not a VEGAS IID, SDK, or public
// ABI. Load returns an owned value; Commit must copy before returning S_OK and
// leave the store unchanged on any other result. No raw host pointer crosses it.
struct __declspec(uuid("DC1077D8-D547-47D7-8E02-1156D96399BA")) IProofTemplateStore : IUnknown {
  virtual HRESULT STDMETHODCALLTYPE Load(host::Tpl* owned) = 0;
  virtual HRESULT STDMETHODCALLTYPE Commit(const host::Tpl* owned) = 0;
};

// Bind, activate, disconnect/deactivate and perform final Release on the creator
// UI thread. No cross-thread COM marshaling/window destruction is supplied.
HRESULT CreateProofPage(IPropertyPage** page) noexcept;
HRESULT CreateNativeProofPage(sfio::ISfHostAllocator* allocator, IPropertyPage** page) noexcept;

// Only used to locate the authored checkbox in the offline harness.
inline constexpr int kExtraReportControl = 100;

}  // namespace vegas_encoder::configuration
