#include "../../src/vegas/abi/sfio_abi.h"

#include <cstdlib>
#include <cstring>

namespace {
LONG outstanding = 0;
}

// Authored fake for the kernel's two template exports. Its static CRT heap
// belongs to this module, so the test releases copies through the paired export.
extern "C" HRESULT WINAPI CopyTemplate(sfio::SFTEMPLATE** out, const sfio::SFTEMPLATE* source) {
  if (!out || !source) return E_POINTER;
  *out = nullptr;
  DWORD bytes = 0;
  memcpy(&bytes, source, sizeof bytes);
  if (bytes < sfio::tpl::fixedSize || bytes > (1u << 20)) return E_INVALIDARG;
  auto* copy = static_cast<sfio::SFTEMPLATE*>(malloc(bytes));
  if (!copy) return E_OUTOFMEMORY;
  memcpy(copy, source, bytes);
  *out = copy;
  InterlockedIncrement(&outstanding);
  return S_OK;
}

extern "C" void WINAPI ReleaseTemplate(sfio::SFTEMPLATE* value) {
  if (!value) return;
  free(value);
  InterlockedDecrement(&outstanding);
}

extern "C" LONG WINAPI OutstandingTemplates() { return outstanding; }
