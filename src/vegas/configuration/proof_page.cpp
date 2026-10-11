#include "proof_page.h"
#include "native_store.h"
#include "../../support/native_boundary.h"

#include <cstdint>
#include <array>
#include <cstring>
#include <limits>
#include <memory>
#include <new>
#include <stdexcept>

namespace vegas_encoder::configuration {
namespace {

class ProofPage final : public sfio::ISfFileIOPropertyPage {
 public:
  explicit ProofPage(sfio::ISfHostAllocator* allocator = nullptr) : allocator_(allocator) {
    if (allocator_) allocator_->AddRef();
  }
  ~ProofPage() {
    // Hosts must deactivate/release the page on its creator UI thread. Detach
    // userdata defensively even if that contract is violated, so a surviving
    // HWND cannot dispatch into a destroyed C++ object.
    if (window_) (void)DestroyPageWindow();
    if (store_) store_->Release();
    if (site_) site_->Release();
    if (allocator_) allocator_->Release();
  }

  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void** out) override {
    if (!out) return E_POINTER;
    *out = nullptr;
    if (iid != IID_IUnknown && iid != IID_IPropertyPage &&
        !(allocator_ && iid == __uuidof(sfio::ISfFileIOPropertyPage))) return E_NOINTERFACE;
    *out = static_cast<IPropertyPage*>(this);
    AddRef();
    return S_OK;
  }
  ULONG STDMETHODCALLTYPE AddRef() override { return static_cast<ULONG>(InterlockedIncrement(&refs_)); }
  ULONG STDMETHODCALLTYPE Release() override {
    const LONG refs = InterlockedDecrement(&refs_);
    if (!refs) delete this;
    return static_cast<ULONG>(refs);
  }

  HRESULT STDMETHODCALLTYPE SetPageSite(IPropertyPageSite* site) override {
    return Call([&]() -> HRESULT {
      if (site && site_) return E_UNEXPECTED;
      if (site) site->AddRef();
      if (site_) site_->Release();
      site_ = site;
      return S_OK;
    });
  }
  HRESULT STDMETHODCALLTYPE SetObjects(ULONG count, IUnknown** objects) override {
    return Call([&]() -> HRESULT {
      if (!count) {
        if (window_) {
          const HRESULT closed = DestroyPageWindow();
          if (FAILED(closed)) return closed;
        }
        if (store_) store_->Release();
        store_ = nullptr;
        draft_.reset();
        SyncControl();
        return S_OK;
      }
      if (count != 1) return E_INVALIDARG;
      if (!objects || !objects[0]) return E_POINTER;
      IProofTemplateStore* next = nullptr;
      const HRESULT query = allocator_ ? CreateNativeTemplateStore(objects[0], allocator_, &next) :
          objects[0]->QueryInterface(__uuidof(IProofTemplateStore), reinterpret_cast<void**>(&next));
      if (FAILED(query)) return query;
      if (!next) return E_UNEXPECTED;
      struct ReleaseNext { IProofTemplateStore* value; ~ReleaseNext() { value->Release(); } } release{next};
      host::Tpl owned;
      const HRESULT load = next->Load(&owned);
      if (load != S_OK) return load;
      std::unique_ptr<TemplateDraft> draft;
      try { draft = std::make_unique<TemplateDraft>(owned); }
      catch (const std::invalid_argument&) { return E_INVALIDARG; }
      // Retain only after loading and validation succeed. A failed rebind leaves
      // the old object and its unapplied draft intact.
      next->AddRef();
      if (store_) store_->Release();
      store_ = next;
      draft_ = std::move(draft);
      SyncControl();
      return S_OK;
    });
  }
  HRESULT STDMETHODCALLTYPE GetPageInfo(PROPPAGEINFO* info) override {
    return Call([&]() -> HRESULT {
      if (!info) return E_POINTER;
      if (info->cb != sizeof *info) return E_INVALIDARG;
      const wchar_t title[] = L"Diagnostic setting proof";
      auto* text = static_cast<wchar_t*>(CoTaskMemAlloc(sizeof title));
      if (!text) return E_OUTOFMEMORY;
      memcpy(text, title, sizeof title);
      *info = {};
      info->cb = sizeof *info;
      info->pszTitle = text;
      info->size = {360, 80};
      return S_OK;
    });
  }
  HRESULT STDMETHODCALLTYPE Activate(HWND parent, LPCRECT rect, BOOL modal) override {
    return Call([&]() -> HRESULT {
      (void)modal;
      if (!rect) return E_POINTER;
      if (window_ || !site_ || !store_ || !draft_) return E_UNEXPECTED;
      if (!IsWindow(parent) || GetWindowThreadProcessId(parent, nullptr) != thread_) return E_INVALIDARG;
      if (!ValidRect(*rect)) return E_INVALIDARG;
      struct alignas(DWORD) EmptyDialog { DLGTEMPLATE dialog; WORD menu, windowClass, title; } layout{};
      layout.dialog.style = WS_CHILD | WS_CLIPCHILDREN | DS_CONTROL;
      layout.dialog.cx = 240;
      layout.dialog.cy = 50;
      window_ = CreateDialogIndirectParamW(GetModuleHandleW(nullptr), &layout.dialog, parent,
                                          Dialog, reinterpret_cast<LPARAM>(this));
      if (!window_) return WindowFailure();
      checkbox_ = CreateWindowExW(0, L"BUTTON", L"Include extra diagnostic report", WS_CHILD | WS_VISIBLE |
          WS_TABSTOP | BS_AUTOCHECKBOX, 12, 12, 330, 28, window_,
          reinterpret_cast<HMENU>(static_cast<INT_PTR>(kExtraReportControl)), GetModuleHandleW(nullptr), nullptr);
      if (!checkbox_) {
        const HRESULT failure = WindowFailure();
        (void)DestroyPageWindow();
        return failure;
      }
      SendMessageW(checkbox_, WM_SETFONT, reinterpret_cast<WPARAM>(GetStockObject(DEFAULT_GUI_FONT)), TRUE);
      SyncControl();
      if (!MoveWindow(window_, rect->left, rect->top, rect->right - rect->left, rect->bottom - rect->top, FALSE)) {
        const HRESULT failure = WindowFailure();
        (void)DestroyPageWindow();
        return failure;
      }
      // The measured VEGAS page container calls Activate without a separate
      // Show. Make the fully initialized page visible here, as its connector
      // does; later Show/Hide calls still control tab visibility.
      return Show(SW_SHOWNORMAL);
    });
  }
  HRESULT STDMETHODCALLTYPE Deactivate() override {
    return Call([&]() -> HRESULT {
      if (!window_) return E_UNEXPECTED;
      // Preserve unapplied draft while changing tabs/reactivating the same page.
      return DestroyPageWindow();
    });
  }
  HRESULT STDMETHODCALLTYPE Show(UINT command) override {
    return Call([&]() -> HRESULT {
      if (!window_) return E_UNEXPECTED;
      if (command != SW_SHOW && command != SW_SHOWNORMAL && command != SW_HIDE) return E_INVALIDARG;
      ShowWindow(window_, static_cast<int>(command));
      if (command != SW_HIDE) SetFocus(checkbox_);
      return S_OK;
    });
  }
  HRESULT STDMETHODCALLTYPE Move(LPCRECT rect) override {
    return Call([&]() -> HRESULT {
      if (!rect) return E_POINTER;
      if (!window_) return E_UNEXPECTED;
      if (!ValidRect(*rect)) return E_INVALIDARG;
      return MoveWindow(window_, rect->left, rect->top, rect->right - rect->left,
                        rect->bottom - rect->top, TRUE) ? S_OK : WindowFailure();
    });
  }
  HRESULT STDMETHODCALLTYPE IsPageDirty() override {
    return Call([&]() -> HRESULT { return draft_ && draft_->Dirty() ? S_OK : S_FALSE; });
  }
  HRESULT STDMETHODCALLTYPE Apply() override {
    return Call([&]() -> HRESULT {
      if (!draft_ || !store_) return E_UNEXPECTED;
      if (!draft_->Dirty()) return S_OK;
      host::Tpl edited = draft_->Prepare();
      const HRESULT committed = store_->Commit(&edited);
      if (committed == S_OK) draft_->Accept(edited);
      return committed;
    });
  }
  HRESULT STDMETHODCALLTYPE Help(LPCOLESTR) override { return Call([] { return E_NOTIMPL; }); }
  HRESULT STDMETHODCALLTYPE TranslateAccelerator(MSG* message) override {
    return Call([&]() -> HRESULT {
      if (!message) return E_POINTER;
      if (!window_) return E_UNEXPECTED;
      return IsDialogMessageW(window_, message) ? S_OK : S_FALSE;
    });
  }
  HRESULT STDMETHODCALLTYPE Slot14(const sfio::SFTEMPLATE* source, const void* info56) override {
    return Call([&]() -> HRESULT {
      if (!allocator_) return E_NOINTERFACE;
      if (!source || !info56) return E_INVALIDARG;
      try {
        host::Tpl copy = host::Tpl::Copy(source);
        source_.b.swap(copy.b);
      } catch (const std::invalid_argument&) { return E_INVALIDARG; }
      // Mirror the measured scalar copy only. The remaining info56 fields
      // include unknown pointer members and are neither read nor retained.
      memcpy(infoScalars_.data(), info56, infoScalars_.size());
      return S_OK;
    });
  }
  HRESULT STDMETHODCALLTYPE Slot15() override { return Call([] { return S_OK; }); }

 private:
  static HRESULT WindowFailure() noexcept {
    const DWORD error = GetLastError();
    return error ? HRESULT_FROM_WIN32(error) : E_FAIL;
  }
  template <class Action> HRESULT Call(Action action) noexcept {
    if (GetCurrentThreadId() != thread_) return RPC_E_WRONG_THREAD;
    return NativeBoundary(action);
  }
  static bool ValidRect(const RECT& rect) noexcept {
    const int64_t width = static_cast<int64_t>(rect.right) - rect.left;
    const int64_t height = static_cast<int64_t>(rect.bottom) - rect.top;
    return width > 0 && height > 0 && width <= (std::numeric_limits<int>::max)() &&
           height <= (std::numeric_limits<int>::max)();
  }
  HRESULT DestroyPageWindow() noexcept {
    SetWindowLongPtrW(window_, DWLP_USER, 0);
    if (!DestroyWindow(window_)) {
      const DWORD error = GetLastError();
      return error ? HRESULT_FROM_WIN32(error) : E_FAIL;
    }
    window_ = checkbox_ = nullptr;
    return S_OK;
  }
  void SyncControl() noexcept {
    if (checkbox_) {
      EnableWindow(checkbox_, draft_ != nullptr);
      SendMessageW(checkbox_, BM_SETCHECK, draft_ && draft_->ExtraReport() ? BST_CHECKED : BST_UNCHECKED, 0);
    }
  }
  static INT_PTR CALLBACK Dialog(HWND dialog, UINT message, WPARAM wparam, LPARAM lparam) noexcept {
    if (message == WM_INITDIALOG) {
      SetWindowLongPtrW(dialog, DWLP_USER, lparam);
      return TRUE;
    }
    auto* page = reinterpret_cast<ProofPage*>(GetWindowLongPtrW(dialog, DWLP_USER));
    if (message == WM_NCDESTROY && page) {
      page->window_ = page->checkbox_ = nullptr;
      SetWindowLongPtrW(dialog, DWLP_USER, 0);
      return FALSE;
    }
    if (message == WM_COMMAND && LOWORD(wparam) == kExtraReportControl && HIWORD(wparam) == BN_CLICKED &&
        page && page->draft_) {
      page->draft_->SetExtraReport(SendMessageW(page->checkbox_, BM_GETCHECK, 0, 0) == BST_CHECKED);
      if (page->site_) BestEffortDiagnostic([&] { page->site_->OnStatusChange(PROPPAGESTATUS_DIRTY); });
      return TRUE;
    }
    return FALSE;
  }

  LONG refs_ = 1;
  const DWORD thread_ = GetCurrentThreadId();
  IPropertyPageSite* site_ = nullptr;
  sfio::ISfHostAllocator* allocator_ = nullptr;
  host::Tpl source_;
  std::array<BYTE, 28> infoScalars_{};
  IProofTemplateStore* store_ = nullptr;
  std::unique_ptr<TemplateDraft> draft_;
  HWND window_ = nullptr, checkbox_ = nullptr;
};

}  // namespace

HRESULT CreateProofPage(IPropertyPage** page) noexcept {
  if (!page) return E_POINTER;
  *page = nullptr;
  return NativeBoundary([&]() -> HRESULT { *page = new ProofPage; return S_OK; });
}

HRESULT CreateNativeProofPage(sfio::ISfHostAllocator* allocator, IPropertyPage** page) noexcept {
  if (!page) return E_POINTER;
  *page = nullptr;
  if (!allocator) return E_POINTER;
  return NativeBoundary([&]() -> HRESULT { *page = new ProofPage(allocator); return S_OK; });
}

}  // namespace vegas_encoder::configuration
