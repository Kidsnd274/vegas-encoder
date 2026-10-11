// Narrow configuration declarations from existing investigation captures.
// Used only by the opt-in configuration proof build. New method names remain
// unknown; exact-build ownership evidence is in docs/NATIVE_CONFIGURATION.md.
#pragma once

#include "sfio_abi.h"

namespace sfio {

// F-026 proxy/stub: IPropertyPage delegation, 16 total methods, two additions.
// F-032/F-036 capture: sharedk queries this IID and calls slot 14 before site
// and object attachment. info56 is an opaque 56-byte structure with embedded
// pointers. Matching connector RVA 0x88A0 copies the complete source template
// and the first 28 scalar info bytes, without retaining info pointer members.
struct __declspec(uuid("9A518D06-4ABD-4860-B790-7C7F80DF80AD")) ISfFileIOPropertyPage : IPropertyPage {
  virtual HRESULT STDMETHODCALLTYPE Slot14(const SFTEMPLATE* source, const void* info56) = 0;
  virtual HRESULT STDMETHODCALLTYPE Slot15() = 0;
};

// F-026 gives all five additional method shapes. F-032/F-036 show SetObjects
// querying this host object, slot 3 on activation and slot 4 during Apply.
// Matching sharedk 2026.0.3.189 slot 3 (RVA 0x2E7880) returns a full calloc/
// memcpy copy: release it through that host's ISfHostAllocator::Free. Slot 4
// (RVA 0x2E7910) copies input bytes and does not take ownership; OOM preserves
// stored bytes. Slots 5..7 have no configuration-path runtime proof.
struct __declspec(uuid("2F5F5809-AE7E-44DF-83A7-76E60CE44EC5")) ISfFileIOTemplateEditHolder : IUnknown {
  virtual HRESULT STDMETHODCALLTYPE Slot3(SFTEMPLATE** value) = 0;
  virtual HRESULT STDMETHODCALLTYPE Slot4(const SFTEMPLATE* value) = 0;
  virtual HRESULT STDMETHODCALLTYPE Slot5(SFTEMPLATE** value) = 0;
  virtual HRESULT STDMETHODCALLTYPE Slot6(LONG key, LONG* value) = 0;
  virtual HRESULT STDMETHODCALLTYPE Slot7(LONG key, LONG value) = 0;
};

}  // namespace sfio
