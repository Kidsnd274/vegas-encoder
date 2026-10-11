#include "native_store.h"
#include "../../support/native_boundary.h"

#include <stdexcept>

namespace vegas_encoder::configuration {
namespace {

class NativeStore final : public IProofTemplateStore {
 public:
  NativeStore(sfio::ISfFileIOTemplateEditHolder* holder, sfio::ISfHostAllocator* allocator)
      : holder_(holder), allocator_(allocator) { allocator_->AddRef(); }
  ~NativeStore() { holder_->Release(); allocator_->Release(); }

  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void** out) override {
    if (!out) return E_POINTER;
    *out = nullptr;
    if (iid != IID_IUnknown && iid != __uuidof(IProofTemplateStore)) return E_NOINTERFACE;
    *out = static_cast<IProofTemplateStore*>(this);
    AddRef();
    return S_OK;
  }
  ULONG STDMETHODCALLTYPE AddRef() override { return static_cast<ULONG>(InterlockedIncrement(&refs_)); }
  ULONG STDMETHODCALLTYPE Release() override {
    const LONG refs = InterlockedDecrement(&refs_);
    if (!refs) delete this;
    return static_cast<ULONG>(refs);
  }
  HRESULT STDMETHODCALLTYPE Load(host::Tpl* owned) override {
    return NativeBoundary([&]() -> HRESULT {
      if (!owned) return E_POINTER;
      sfio::SFTEMPLATE* returned = nullptr;
      struct ReturnedCopy {
        sfio::ISfHostAllocator* allocator;
        sfio::SFTEMPLATE*& value;
        ~ReturnedCopy() { if (value) allocator->Free(value); }
      } release{allocator_, returned};
      const HRESULT read = holder_->Slot3(&returned);
      if (read != S_OK) return read;
      if (!returned) return E_UNEXPECTED;
      try {
        host::Tpl copy = host::Tpl::Copy(returned);
        owned->b.swap(copy.b);
      } catch (const std::invalid_argument&) { return E_INVALIDARG; }
      return S_OK;
    });
  }
  HRESULT STDMETHODCALLTYPE Commit(const host::Tpl* owned) override {
    return NativeBoundary([&]() -> HRESULT {
      if (!owned) return E_POINTER;
      if (!host::Tpl::Valid(owned->Ptr(), owned->b.size())) return E_INVALIDARG;
      // The measured host copies before returning. Keeping our owned storage
      // alive for this synchronous call is sufficient; ownership never transfers.
      return holder_->Slot4(owned->Ptr());
    });
  }

 private:
  LONG refs_ = 1;
  sfio::ISfFileIOTemplateEditHolder* holder_;
  sfio::ISfHostAllocator* allocator_;
};

}  // namespace

HRESULT CreateNativeTemplateStore(IUnknown* object, sfio::ISfHostAllocator* allocator,
                                  IProofTemplateStore** store) noexcept {
  if (!store) return E_POINTER;
  *store = nullptr;
  if (!object || !allocator) return E_POINTER;
  return NativeBoundary([&]() -> HRESULT {
    sfio::ISfFileIOTemplateEditHolder* holder = nullptr;
    const HRESULT query = object->QueryInterface(__uuidof(sfio::ISfFileIOTemplateEditHolder),
                                                  reinterpret_cast<void**>(&holder));
    if (FAILED(query)) return query;
    if (!holder) return E_UNEXPECTED;
    try { *store = new NativeStore(holder, allocator); }
    catch (...) { holder->Release(); throw; }
    return S_OK;
  });
}

}  // namespace vegas_encoder::configuration
