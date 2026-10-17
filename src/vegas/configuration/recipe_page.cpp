#include "recipe_page.h"
#include "native_store.h"
#include "../../support/diagnostics.h"
#include "../../support/native_boundary.h"

#include <array>
#include <cstdint>
#include <cstring>
#include <limits>

namespace vegas_encoder::configuration {
void ReturnRecipeOwner(HWND owner, HWND focus, bool returnForeground) noexcept {
  if (!IsWindow(owner) || GetWindowThreadProcessId(owner,nullptr) != GetCurrentThreadId()) return;
  EnableWindow(owner,TRUE);
  if (!returnForeground) return;
  // GA_ROOTOWNER uses GetParent, which can stop at an owned WS_OVERLAPPED
  // window. Follow explicit top-level owners so the real host is restored too.
  auto main = GetAncestor(owner,GA_ROOT);
  for (unsigned depth=0; main && depth<32; ++depth) {
    const auto next=GetWindow(main,GW_OWNER);
    if (!next || next==main || GetWindowThreadProcessId(next,nullptr)!=GetCurrentThreadId()) break;
    main=next;
  }
  if (IsWindow(main) && GetWindowThreadProcessId(main,nullptr) == GetCurrentThreadId() && IsIconic(main))
    ShowWindow(main,SW_RESTORE);
  if (IsIconic(owner)) ShowWindow(owner,SW_RESTORE);
  (void)SetForegroundWindow(owner);
  if (GetForegroundWindow() == owner && IsWindow(focus)) SetFocus(focus);
}
namespace {
constexpr UINT kLaunchEditor = WM_APP + 37;
constexpr UINT_PTR kPollEditor = 1;

class RecipePage final : public sfio::ISfFileIOPropertyPage {
 public:
  RecipePage(sfio::ISfHostAllocator* allocator, const RecipePageOptions& options)
      : options_(options), allocator_(allocator) { allocator_->AddRef(); }
  ~RecipePage() {
    EndEditor();
    if (window_) (void)DestroyPageWindow();
    if (store_) store_->Release();
    if (site_) site_->Release();
    allocator_->Release();
  }
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void** out) override {
    if (!out) return E_POINTER;
    *out = nullptr;
    if (iid != IID_IUnknown && iid != IID_IPropertyPage && iid != __uuidof(sfio::ISfFileIOPropertyPage))
      return E_NOINTERFACE;
    *out = static_cast<IPropertyPage*>(this); AddRef(); return S_OK;
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
      if (!site_) EndEditor();
      return S_OK;
    });
  }
  HRESULT STDMETHODCALLTYPE SetObjects(ULONG count, IUnknown** objects) override {
    return Call([&]() -> HRESULT {
      if (!count) {
        EndEditor();
        if (window_) { const auto result = DestroyPageWindow(); if (FAILED(result)) return result; }
        if (store_) store_->Release();
        store_ = nullptr; draft_.reset();
        return S_OK;
      }
      if (count != 1) return E_INVALIDARG;
      if (!objects || !objects[0]) return E_POINTER;
      if (editor_ || launching_) return E_PENDING;
      IProofTemplateStore* next = nullptr;
      const auto query = CreateNativeTemplateStore(objects[0], allocator_, &next);
      if (FAILED(query)) return query;
      if (!next) return E_UNEXPECTED;
      struct Release { IProofTemplateStore* value; ~Release() { value->Release(); } } release{next};
      host::Tpl owned;
      const auto loaded = next->Load(&owned);
      if (loaded != S_OK) return loaded;
      auto draft = std::make_unique<RecipeTemplateDraft>(owned, options_.owner, options_.dllVersion,
                                                       Utf8(source_.Name().c_str()));
      if (owned.Name().empty()) BestEffortDiagnostic([&] {
        Log("B6 editor display-name fallback: source=%s cbStruct=%lu cbExtra=%lu cchAllocText=%lu notesUtf8Bytes=%zu",
            source_.Name().empty() ? "recipe" : "page", owned.U32(sfio::tpl::cbStruct),
            owned.U32(sfio::tpl::cbExtra), owned.U32(sfio::tpl::cchAllocText),
            ve::Str(draft->Snapshot().at("recipe"),"notes").size());
      });
      next->AddRef();
      if (store_) store_->Release();
      store_ = next; draft_ = std::move(draft);
      Status(L"Settings are stored in this VEGAS template.");
      SyncButton();
      return S_OK;
    });
  }
  HRESULT STDMETHODCALLTYPE GetPageInfo(PROPPAGEINFO* info) override {
    return Call([&]() -> HRESULT {
      if (!info) return E_POINTER;
      if (info->cb != sizeof *info) return E_INVALIDARG;
      const wchar_t title[] = L"Vegas Encoder";
      auto* text = static_cast<wchar_t*>(CoTaskMemAlloc(sizeof title));
      if (!text) return E_OUTOFMEMORY;
      memcpy(text, title, sizeof title);
      *info = {}; info->cb = sizeof *info; info->pszTitle = text; info->size = {440, 118};
      return S_OK;
    });
  }
  HRESULT STDMETHODCALLTYPE Activate(HWND parent, LPCRECT rect, BOOL) override {
    return Call([&]() -> HRESULT {
      if (!rect) return E_POINTER;
      if (window_ || !site_ || !store_ || !draft_) return E_UNEXPECTED;
      if (!IsWindow(parent) || GetWindowThreadProcessId(parent, nullptr) != thread_ || !ValidRect(*rect))
        return E_INVALIDARG;
      struct alignas(DWORD) EmptyDialog { DLGTEMPLATE dialog; WORD menu, windowClass, title; } layout{};
      layout.dialog.style = WS_CHILD | WS_CLIPCHILDREN | DS_CONTROL;
      layout.dialog.cx = 290; layout.dialog.cy = 78;
      window_ = CreateDialogIndirectParamW(GetModuleHandleW(nullptr), &layout.dialog, parent,
                                          Dialog, reinterpret_cast<LPARAM>(this));
      if (!window_) return WindowFailure();
      button_ = CreateWindowExW(0, L"BUTTON", L"Edit settings...", WS_CHILD | WS_VISIBLE | WS_TABSTOP |
          BS_PUSHBUTTON, 12, 12, 148, 28, window_, reinterpret_cast<HMENU>(static_cast<INT_PTR>(kEditRecipeControl)),
          GetModuleHandleW(nullptr), nullptr);
      status_ = CreateWindowExW(0, L"STATIC", statusText_.c_str(), WS_CHILD | WS_VISIBLE | SS_LEFT,
          12, 50, 410, 52, window_, reinterpret_cast<HMENU>(static_cast<INT_PTR>(kRecipeStatusControl)), GetModuleHandleW(nullptr), nullptr);
      if (!button_ || !status_) { const auto failure = WindowFailure(); (void)DestroyPageWindow(); return failure; }
      for (const auto control : {button_, status_})
        SendMessageW(control, WM_SETFONT, reinterpret_cast<WPARAM>(GetStockObject(DEFAULT_GUI_FONT)), TRUE);
      SyncButton();
      const auto moved = Move(rect);
      if (FAILED(moved)) { (void)DestroyPageWindow(); return moved; }
      return Show(SW_SHOWNORMAL); // This host does not always call Show after Activate.
    });
  }
  HRESULT STDMETHODCALLTYPE Deactivate() override {
    return Call([&]() -> HRESULT {
      if (!window_) return E_UNEXPECTED;
      EndEditor();
      return DestroyPageWindow(); // Preserve earlier unapplied edits while changing tabs.
    });
  }
  HRESULT STDMETHODCALLTYPE Show(UINT command) override {
    return Call([&]() -> HRESULT {
      if (!window_) return E_UNEXPECTED;
      if (command != SW_SHOW && command != SW_SHOWNORMAL && command != SW_HIDE) return E_INVALIDARG;
      ShowWindow(window_, static_cast<int>(command));
      if (command != SW_HIDE && !editor_) SetFocus(button_);
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
      if (launching_ || editor_) return E_PENDING;
      const auto result = draft_->Commit([&](const host::Tpl& value) { return store_->Commit(&value); });
      if (result == S_OK) Status(L"Settings are stored in this VEGAS template.");
      return result;
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
      if (!source || !info56) return E_INVALIDARG;
      auto copy = host::Tpl::Copy(source); source_.b.swap(copy.b);
      memcpy(infoScalars_.data(), info56, infoScalars_.size());
      return S_OK;
    });
  }
  HRESULT STDMETHODCALLTYPE Slot15() override { return Call([] { return S_OK; }); }

 private:
  static HRESULT WindowFailure() noexcept {
    const auto error = GetLastError(); return error ? HRESULT_FROM_WIN32(error) : E_FAIL;
  }
  template<class Action> HRESULT Call(Action action) noexcept {
    if (GetCurrentThreadId() != thread_) return RPC_E_WRONG_THREAD;
    return NativeBoundary(action);
  }
  static bool ValidRect(const RECT& rect) noexcept {
    const auto width = static_cast<int64_t>(rect.right) - rect.left;
    const auto height = static_cast<int64_t>(rect.bottom) - rect.top;
    return width > 0 && height > 0 && width <= (std::numeric_limits<int>::max)() &&
           height <= (std::numeric_limits<int>::max)();
  }
  void Status(const std::wstring& text) {
    statusText_ = text;
    if (draft_) try {
      const auto ext = RecipeOutputExtension(draft_->Snapshot().at("recipe"));
      if (!ext.empty()) statusText_ += L" Use a " + ext + L" filename in Render As.";
    } catch (...) { /* Preserve the useful status when malformed drafts cannot compile. */ }
    if (status_) SetWindowTextW(status_, statusText_.c_str());
  }
  void SyncButton() noexcept { if (button_) EnableWindow(button_, draft_ && !editor_ && !launching_); }
  void RestoreOwner(bool returnForeground = false) noexcept {
    const auto owner = owner_; const bool enable = ownerDisabled_;
    owner_ = nullptr; ownerDisabled_ = false;
    if (enable && IsWindow(owner) && GetWindowThreadProcessId(owner, nullptr) == thread_) {
      ReturnRecipeOwner(owner,button_,returnForeground);
    }
  }
  void EndEditor() noexcept {
    launching_ = false;
    editorStarted_ = editorHadForeground_ = false;
    if (window_) KillTimer(window_, kPollEditor);
    if (editor_) {
      BestEffortDiagnostic([&] { editor_->Cancel(); });
      editor_.reset(); // Kill-on-close; never wait for a child.
    }
    if (draft_) BestEffortDiagnostic([&] { if (draft_->Editing()) (void)draft_->FinishEdit(nullptr, 1); });
    RestoreOwner(); SyncButton();
  }
  HRESULT DestroyPageWindow() noexcept {
    SetWindowLongPtrW(window_, DWLP_USER, 0);
    if (!DestroyWindow(window_)) return WindowFailure();
    window_ = button_ = status_ = nullptr;
    return S_OK;
  }
  void LaunchEditor() {
    if (!launching_ || !draft_ || !window_) return;
    launching_ = false;
    const auto started = NowMs();
    try {
      Status(L"Starting the editor...");
      // A posted launch can run before WM_PAINT. Paint the status child before
      // any cold OS/file work, without pumping a nested host message loop.
      if (status_) UpdateWindow(status_);
      if (options_.beforeLaunch) options_.beforeLaunch();
      const auto prepared = NowMs();
      const auto parent = GetParent(window_);
      owner_ = GetAncestor(parent, GA_ROOT);
      if (!IsWindow(owner_) || GetWindowThreadProcessId(owner_, nullptr) != thread_)
        throw std::runtime_error("The VEGAS settings owner is unavailable.");
      auto request = draft_->BeginEdit({{"protocol", 1}, {"sessionId", NewEditSessionId()},
          {"ownerHwnd", std::to_string(reinterpret_cast<uintptr_t>(owner_))},
          {"dllVersion", options_.dllVersion}, {"coreVersion", options_.coreVersion},
          {"context", options_.context}, {"baseRecipe", nullptr}}, options_.capabilities);
      // The page's UI timer continues while the native owner is disabled. No
      // nested dialog loop, host object or Render worker participates.
      ownerDisabled_ = IsWindowEnabled(owner_) != FALSE;
      if (ownerDisabled_) EnableWindow(owner_, FALSE);
      auto transport = std::make_unique<EditorSessionTask>(options_.sessionRoot,request,options_.launch);
      BestEffortDiagnostic([&] { Log("B6 editor scheduling: preflight=%.1f ms request/schedule=%.1f ms",prepared-started,NowMs()-prepared); });
      editor_ = std::move(transport);
      editorStarted_ = editorHadForeground_ = false;
      if (!SetTimer(window_, kPollEditor, 100, nullptr)) throw std::runtime_error("Cannot poll the editor session.");
      Status(L"Starting the editor. Apply there to return changes to this template.");
    } catch (const std::exception& error) {
      EndEditor();
      Status(L"Could not open the editor: " + Widen(error.what()));
    }
    SyncButton();
  }
  void PollEditor() {
    if (!editor_) return;
    try {
      DWORD foregroundProcess = 0;
      const auto foreground = GetForegroundWindow();
      if (foreground) GetWindowThreadProcessId(foreground,&foregroundProcess);
      const bool editorForeground = foregroundProcess && foregroundProcess == editor_->ProcessId();
      auto exit = editor_->Poll();
      if (!exit) {
        editorHadForeground_ = editorForeground;
        if (editor_->ProcessId() && !editorStarted_) {
          editorStarted_ = true; Status(L"Editor is open. Apply there to return changes to this template.");
        }
        return;
      }
      KillTimer(window_, kPollEditor);
      if (options_.validateRecipe && exit->exitCode == 0 && exit->result.is_object() &&
          ve::Str(exit->result, "action") == "apply" && exit->result.contains("recipe"))
        options_.validateRecipe(exit->result.at("recipe"));
      const auto outcome = draft_->FinishEdit(exit->result, exit->exitCode);
      const auto action = ve::Str(exit->result,"action");
      const bool returnForeground = !exit->exitCode && (action == "apply" || action == "cancel") &&
          (editorForeground || editorHadForeground_ || foregroundProcess == GetCurrentProcessId());
      editor_.reset(); RestoreOwner(returnForeground); SyncButton();
      if (outcome.disposition == EditDisposition::applied) {
        Status(draft_->Dirty() ? L"Settings changed. Click VEGAS Apply or OK to keep them." : L"Settings are unchanged.");
        if (draft_->Dirty() && site_) BestEffortDiagnostic([&] { site_->OnStatusChange(PROPPAGESTATUS_DIRTY); });
      } else if (outcome.disposition == EditDisposition::rejected) {
        Status(L"Editor changes were rejected. The previous settings are preserved.");
      } else {
        Status(exit->diagnostic.empty() ? L"Editor cancelled. The previous settings are preserved." :
               L"Editor closed without applying changes: " + Widen(exit->diagnostic.c_str()));
      }
    } catch (const std::exception& error) {
      EndEditor(); Status(L"Editor session failed: " + Widen(error.what()));
    }
  }
  static INT_PTR CALLBACK Dialog(HWND dialog, UINT message, WPARAM wparam, LPARAM lparam) noexcept {
    if (message == WM_INITDIALOG) { SetWindowLongPtrW(dialog, DWLP_USER, lparam); return TRUE; }
    auto* page = reinterpret_cast<RecipePage*>(GetWindowLongPtrW(dialog, DWLP_USER));
    if (!page) return FALSE;
    if (message == WM_NCDESTROY) {
      page->EndEditor(); page->window_ = page->button_ = page->status_ = nullptr;
      SetWindowLongPtrW(dialog, DWLP_USER, 0); return FALSE;
    }
    // Window callbacks are exception boundaries, just like the COM methods.
    if (message == WM_COMMAND && LOWORD(wparam) == kEditRecipeControl && HIWORD(wparam) == BN_CLICKED) {
      (void)page->Call([&]() -> HRESULT {
        if (!page->draft_ || page->editor_ || page->launching_) return E_PENDING;
        page->launching_ = true; page->SyncButton();
        if (!PostMessageW(dialog, kLaunchEditor, 0, 0)) {
          page->launching_ = false; page->SyncButton(); return WindowFailure();
        }
        return S_OK;
      });
      return TRUE;
    }
    if (message == kLaunchEditor) { (void)page->Call([&] { page->LaunchEditor(); return S_OK; }); return TRUE; }
    if (message == WM_TIMER && wparam == kPollEditor) {
      (void)page->Call([&] { page->PollEditor(); return S_OK; }); return TRUE;
    }
    return FALSE;
  }

  LONG refs_ = 1;
  const DWORD thread_ = GetCurrentThreadId();
  RecipePageOptions options_;
  sfio::ISfHostAllocator* allocator_;
  IPropertyPageSite* site_ = nullptr;
  IProofTemplateStore* store_ = nullptr;
  host::Tpl source_;
  std::array<BYTE, 28> infoScalars_{};
  std::unique_ptr<RecipeTemplateDraft> draft_;
  std::unique_ptr<EditorSessionTask> editor_;
  bool editorStarted_ = false;
  bool editorHadForeground_ = false;
  HWND window_ = nullptr, button_ = nullptr, status_ = nullptr, owner_ = nullptr;
  bool ownerDisabled_ = false, launching_ = false;
  std::wstring statusText_ = L"Settings are stored in this VEGAS template.";
};
} // namespace

HRESULT CreateNativeRecipePage(sfio::ISfHostAllocator* allocator,
                              const RecipePageOptions& options, IPropertyPage** page) noexcept {
  if (!page) return E_POINTER;
  *page = nullptr;
  if (!allocator) return E_POINTER;
  if (options.dllVersion.empty() || options.coreVersion.empty() || options.sessionRoot.empty() ||
      options.launch.application.empty()) return E_INVALIDARG;
  return NativeBoundary([&]() -> HRESULT { *page = new RecipePage(allocator, options); return S_OK; });
}
} // namespace vegas_encoder::configuration
