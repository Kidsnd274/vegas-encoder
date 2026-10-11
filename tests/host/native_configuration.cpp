// Offline configuration proof: owned bytes, COM references and a hidden native
// checkbox page. Does not load VEGAS, a connector, or the exporter DLL.
#include "../../src/vegas/configuration/proof_page.h"
#include "../../src/vegas/configuration/native_store.h"
#include "../../src/vegas/abi/configuration_abi.h"

#include <cstdio>
#include <cstring>
#include <limits>
#include <new>
#include <stdexcept>
#include <thread>

using vegas_encoder::host::Tpl;
using namespace vegas_encoder::configuration;

namespace {
int failures = 0, checks = 0;
void Check(bool success, const char* label) {
  ++checks;
  printf("%s: %s\n", success ? "PASS" : "FAIL", label);
  if (!success) ++failures;
}
template <class Action> bool Rejects(Action action) {
  try { action(); } catch (const std::invalid_argument&) { return true; } catch (...) {}
  return false;
}

Tpl MakeTemplate() {
  Tpl value = Tpl::Make(L"Proof template \u03a9", L"Two independent settings", 64);
  value.SetU32(sfio::tpl::abExtra, 0x434e4556);
  value.SetU32(sfio::tpl::abExtra + 4, 1);
  value.SetU32(sfio::tpl::abExtra + 8, 7);
  // Uninterpreted host bytes and unused private bytes must survive edits.
  value.b[0x1d0] = 0xa5;
  value.b[sfio::tpl::abExtra + 52] = 0x6b;
  return value;
}

struct Store final : IProofTemplateStore {
  LONG refs = 1;
  Tpl saved = MakeTemplate();
  HRESULT loadResult = S_OK, commitResult = S_OK;
  bool throwLoad = false, throwCommit = false;
  int commits = 0;
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void** out) override {
    if (!out) return E_POINTER;
    *out = nullptr;
    if (iid != IID_IUnknown && iid != __uuidof(IProofTemplateStore)) return E_NOINTERFACE;
    *out = static_cast<IProofTemplateStore*>(this);
    AddRef();
    return S_OK;
  }
  ULONG STDMETHODCALLTYPE AddRef() override { return static_cast<ULONG>(++refs); }
  ULONG STDMETHODCALLTYPE Release() override { return static_cast<ULONG>(--refs); }
  HRESULT STDMETHODCALLTYPE Load(Tpl* owned) override {
    if (throwLoad) throw std::bad_alloc();
    if (loadResult != S_OK) return loadResult;
    *owned = saved;
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE Commit(const Tpl* owned) override {
    if (throwCommit) throw std::bad_alloc();
    if (commitResult != S_OK) return commitResult;
    Tpl copy = *owned;
    saved.b.swap(copy.b);
    ++commits;
    return S_OK;
  }
};

struct Site final : IPropertyPageSite {
  LONG refs = 1;
  int dirtyEvents = 0;
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void** out) override {
    if (!out) return E_POINTER;
    *out = nullptr;
    if (iid != IID_IUnknown && iid != IID_IPropertyPageSite) return E_NOINTERFACE;
    *out = static_cast<IPropertyPageSite*>(this);
    AddRef();
    return S_OK;
  }
  ULONG STDMETHODCALLTYPE AddRef() override { return static_cast<ULONG>(++refs); }
  ULONG STDMETHODCALLTYPE Release() override { return static_cast<ULONG>(--refs); }
  HRESULT STDMETHODCALLTYPE OnStatusChange(DWORD flags) override {
    if (flags & PROPPAGESTATUS_DIRTY) ++dirtyEvents;
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE GetLocaleID(LCID* out) override {
    if (!out) return E_POINTER;
    *out = 0x409;
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE GetPageContainer(IUnknown** out) override {
    if (out) *out = nullptr;
    return E_NOINTERFACE;
  }
  HRESULT STDMETHODCALLTYPE TranslateAccelerator(MSG*) override { return S_FALSE; }
};

struct Allocator final : sfio::ISfHostAllocator {
  LONG refs = 1;
  int allocations = 0, frees = 0;
  bool fail = false;
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void** out) override {
    if (!out) return E_POINTER;
    *out = nullptr;
    if (iid != IID_IUnknown && iid != sfio::IID_SfHostAllocator) return E_NOINTERFACE;
    *out = static_cast<sfio::ISfHostAllocator*>(this);
    AddRef();
    return S_OK;
  }
  ULONG STDMETHODCALLTYPE AddRef() override { return static_cast<ULONG>(++refs); }
  ULONG STDMETHODCALLTYPE Release() override { return static_cast<ULONG>(--refs); }
  void* STDMETHODCALLTYPE Alloc(SIZE_T bytes) override {
    if (fail) return nullptr;
    void* value = CoTaskMemAlloc(bytes);
    if (value) ++allocations;
    return value;
  }
  void STDMETHODCALLTYPE Free(void* value) override { if (value) { ++frees; CoTaskMemFree(value); } }
};

struct Holder final : sfio::ISfFileIOTemplateEditHolder {
  explicit Holder(Allocator& allocator) : allocator(allocator) {}
  Allocator& allocator;
  LONG refs = 1;
  Tpl saved = MakeTemplate();
  HRESULT readResult = S_OK, commitResult = S_OK;
  bool malformed = false;
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void** out) override {
    if (!out) return E_POINTER;
    *out = nullptr;
    if (iid != IID_IUnknown && iid != __uuidof(sfio::ISfFileIOTemplateEditHolder)) return E_NOINTERFACE;
    *out = static_cast<sfio::ISfFileIOTemplateEditHolder*>(this);
    AddRef();
    return S_OK;
  }
  ULONG STDMETHODCALLTYPE AddRef() override { return static_cast<ULONG>(++refs); }
  ULONG STDMETHODCALLTYPE Release() override { return static_cast<ULONG>(--refs); }
  HRESULT STDMETHODCALLTYPE Slot3(sfio::SFTEMPLATE** out) override {
    *out = nullptr;
    void* value = allocator.Alloc(saved.b.size());
    if (!value) return E_OUTOFMEMORY;
    memcpy(value, saved.b.data(), saved.b.size());
    if (malformed) { const DWORD bad = 1; memcpy(value, &bad, sizeof bad); }
    *out = static_cast<sfio::SFTEMPLATE*>(value);
    return readResult;  // also exercises an error accompanied by an allocation
  }
  HRESULT STDMETHODCALLTYPE Slot4(const sfio::SFTEMPLATE* in) override {
    if (commitResult != S_OK) return commitResult;
    Tpl copied = Tpl::Copy(in);
    saved.b.swap(copied.b);
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE Slot5(sfio::SFTEMPLATE**) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE Slot6(LONG, LONG*) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE Slot7(LONG, LONG) override { return E_NOTIMPL; }
};

void NativeBridge() {
  Allocator allocator;
  Holder holder(allocator);
  IProofTemplateStore* store = nullptr;
  Check(CreateNativeTemplateStore(&holder, &allocator, &store) == S_OK && store &&
        holder.refs == 2 && allocator.refs == 2, "native bridge retains the queried holder and matching allocator");
  if (!store) return;
  Tpl owned;
  Check(store->Load(&owned) == S_OK && owned.b == holder.saved.b && allocator.allocations == 1 &&
        allocator.frees == 1, "native read copies then releases the returned allocation exactly once");
  owned.b[0x1d0] = 0;
  Check(holder.saved.b[0x1d0] == 0xa5, "native read exposes independent owned bytes");
  const auto old = owned.b;
  holder.readResult = E_FAIL;
  Check(store->Load(&owned) == E_FAIL && owned.b == old && allocator.allocations == allocator.frees,
        "failed native read frees a supplied copy and preserves the previous owned value");
  holder.readResult = S_OK;
  holder.malformed = true;
  Check(store->Load(&owned) == E_INVALIDARG && owned.b == old && allocator.allocations == allocator.frees,
        "malformed native read is rejected and its allocation is freed");
  holder.malformed = false;
  allocator.fail = true;
  Check(store->Load(&owned) == E_OUTOFMEMORY && owned.b == old && allocator.allocations == allocator.frees,
        "native allocation failure preserves the owned value without an extra free");
  allocator.fail = false;
  Tpl edited = WithProofSettings(holder.saved, {true});
  Check(store->Commit(&edited) == S_OK && ReadProofSettings(holder.saved).extraReport,
        "native commit copies an edited snapshot into the holder");
  edited.SetU32(kProofOffset + 8, 0);
  Check(ReadProofSettings(holder.saved).extraReport, "holder retains its copy after caller bytes change");
  const auto committed = holder.saved.b;
  holder.commitResult = E_OUTOFMEMORY;
  Check(store->Commit(&edited) == E_OUTOFMEMORY && holder.saved.b == committed,
        "failed native commit preserves the holder's committed snapshot");
  store->Release();
  Check(holder.refs == 1 && allocator.refs == 1, "native bridge destruction balances holder and allocator references");

  IPropertyPage* page = nullptr;
  Site site;
  Check(CreateNativeProofPage(&allocator, &page) == S_OK && page && allocator.refs == 2,
        "native page factory retains its allocator");
  if (!page) return;
  sfio::ISfFileIOPropertyPage* native = nullptr;
  Check(page->QueryInterface(__uuidof(sfio::ISfFileIOPropertyPage), reinterpret_cast<void**>(&native)) == S_OK,
        "opt-in native page exposes the measured FileIO page IID");
  BYTE info[56]{};
  Check(native && native->Slot14(holder.saved.Ptr(), info) == S_OK && native->Slot15() == S_OK,
        "native initialization accepts owned source/scalar copies and the measured no-op slot");
  if (native) native->Release();
  IUnknown* object = &holder;
  Check(page->SetPageSite(&site) == S_OK && page->SetObjects(1, &object) == S_OK &&
        holder.refs == 2 && allocator.allocations == allocator.frees,
        "native SetObjects binds through the owned bridge and releases its read copy");
  HWND parent = CreateWindowExW(0, L"STATIC", L"Hidden native bridge test", WS_OVERLAPPED,
      0, 0, 400, 120, nullptr, nullptr, GetModuleHandleW(nullptr), nullptr);
  RECT rect{2, 2, 362, 82};
  const HRESULT activated = page->Activate(parent, &rect, FALSE);
  HWND dialog = parent ? GetWindow(parent, GW_CHILD) : nullptr;
  HWND checkbox = dialog ? GetDlgItem(dialog, kExtraReportControl) : nullptr;
  Check(activated == S_OK && checkbox, "native bridge checkbox page activates in the fake host");
  if (checkbox) {
    SendMessageW(checkbox, BM_CLICK, 0, 0);  // committed true -> pending false
    Check(page->Apply() == E_OUTOFMEMORY && page->IsPageDirty() == S_OK &&
          ReadProofSettings(holder.saved).extraReport,
          "failed native Apply preserves the committed value and dirty draft");
    holder.commitResult = S_OK;
    Check(page->Apply() == S_OK && page->IsPageDirty() == S_FALSE && !ReadProofSettings(holder.saved).extraReport,
          "native Apply retry commits the pending value");
  }
  Check(page->SetObjects(0, nullptr) == S_OK && holder.refs == 1 && allocator.refs == 2 &&
        !GetWindow(parent, GW_CHILD), "native object disconnect destroys the window and releases the holder bridge");
  page->Release();
  Check(allocator.refs == 1 && site.refs == 1 && allocator.allocations == allocator.frees,
        "native page cleanup balances all references and returned copies");
  if (parent) DestroyWindow(parent);
}

void Payloads() {
  const Tpl legacy = MakeTemplate();
  Check(!ReadProofSettings(legacy).extraReport, "untouched 64-byte marker loads the false default");
  TemplateDraft draft(legacy);
  draft.SetExtraReport(true);
  const Tpl edited = draft.Prepare();
  bool preserved = edited.b.size() == legacy.b.size();
  for (size_t i = 0; i < legacy.b.size(); ++i)
    if ((i < kProofOffset || i >= kProofOffset + 12) && edited.b[i] != legacy.b[i]) preserved = false;
  Check(preserved && legacy.U32(kProofOffset) == 0 && draft.Dirty(),
        "draft writes only 12 owned proof bytes and leaves the source untouched");
  const Tpl reloaded = Tpl::Copy(edited.Ptr(), edited.b.size());
  Check(ReadProofSettings(reloaded).extraReport && reloaded.Name() == legacy.Name() &&
        reloaded.Notes() == legacy.Notes(), "owned-byte save/reload preserves the setting and text");
  const Tpl second = WithProofSettings(legacy, {false});
  Check(!ReadProofSettings(second).extraReport && ReadProofSettings(edited).extraReport,
        "two separately saved template copies retain independent settings");
  draft.SetExtraReport(false);
  Check(!draft.Dirty(), "returning to the committed value clears draft dirtiness");
  draft.SetExtraReport(true);
  Tpl committed = draft.Prepare();
  draft.Accept(committed);
  Check(!draft.Dirty() && draft.ExtraReport(), "successful commit advances the draft baseline");

  Tpl invalid = edited;
  invalid.b.resize(sfio::tpl::fixedSize - 1);
  Check(Rejects([&] { ReadProofSettings(invalid); }), "reject a truncated owned template");
  invalid = edited;
  invalid.SetU32(sfio::tpl::cbExtra, (std::numeric_limits<DWORD>::max)());
  Check(Rejects([&] { ReadProofSettings(invalid); }), "reject overflowing private-payload span");
  invalid = edited;
  invalid.SetU32(sfio::tpl::abExtra, 0);
  Check(Rejects([&] { WithProofSettings(invalid, {false}); }), "reject another product marker");
  invalid = edited;
  invalid.SetU32(sfio::tpl::abExtra + 4, 2);
  Check(Rejects([&] { ReadProofSettings(invalid); }), "reject future outer marker version");
  invalid = edited;
  invalid.SetU32(kProofOffset, 0xdeadbeef);
  const auto before = invalid.b;
  Check(Rejects([&] { WithProofSettings(invalid, {false}); }) && invalid.b == before,
        "reject unknown proof bytes without overwriting them");
  invalid = edited;
  invalid.SetU32(kProofOffset + 4, 2);
  Check(Rejects([&] { ReadProofSettings(invalid); }), "reject future proof version");
  invalid = edited;
  invalid.SetU32(kProofOffset + 8, 2);
  Check(Rejects([&] { ReadProofSettings(invalid); }), "reject a non-boolean setting value");
  invalid = legacy;
  invalid.SetU32(kProofOffset + 8, 1);
  Check(Rejects([&] { ReadProofSettings(invalid); }), "reject a partial legacy proof marker");
}

void Page() {
  Store store, other;
  Site site;
  IPropertyPage* page = nullptr;
  Check(CreateProofPage(nullptr) == E_POINTER && CreateProofPage(&page) == S_OK && page,
        "page factory validates output and supplies a standard COM page");
  if (!page) return;
  void* unknown = reinterpret_cast<void*>(1);
  Check(page->QueryInterface(__uuidof(IProofTemplateStore), &unknown) == E_NOINTERFACE && !unknown,
        "page refuses unsupported interfaces and clears output");
  unknown = reinterpret_cast<void*>(1);
  Check(page->QueryInterface(__uuidof(sfio::ISfFileIOPropertyPage), &unknown) == E_NOINTERFACE && !unknown,
        "offline page does not advertise the unqualified VEGAS configuration interface");
  IUnknown* identity = nullptr;
  const HRESULT identityResult = page->QueryInterface(IID_IUnknown, reinterpret_cast<void**>(&identity));
  Check(identityResult == S_OK && identity == static_cast<IUnknown*>(page), "standard COM identity is stable");
  if (identity) identity->Release();
  Check(page->SetPageSite(&site) == S_OK && site.refs == 2 &&
        page->SetPageSite(&site) == E_UNEXPECTED && site.refs == 2,
        "site is retained once and duplicate attachment is rejected");
  Check(page->SetObjects(1, nullptr) == E_POINTER && page->SetObjects(2, nullptr) == E_INVALIDARG,
        "one-object scaffold rejects invalid object counts and null arrays");
  IUnknown* object = &store;
  Check(page->SetObjects(1, &object) == S_OK && store.refs == 2 && page->IsPageDirty() == S_FALSE,
        "SetObjects keeps one queried store reference and loads an owned clean draft");
  PROPPAGEINFO info{};
  info.cb = sizeof info;
  const HRESULT infoResult = page->GetPageInfo(&info);
  Check(infoResult == S_OK && info.pszTitle && info.size.cx > 0 && info.size.cy > 0,
        "page info returns a caller-owned task-allocated title");
  CoTaskMemFree(info.pszTitle);

  HWND parent = CreateWindowExW(0, L"STATIC", L"Offline hidden page test", WS_OVERLAPPED,
      0, 0, 400, 120, nullptr, nullptr, GetModuleHandleW(nullptr), nullptr);
  RECT rect{2, 2, 362, 82};
  Check(parent && page->Activate(parent, &rect, FALSE) == S_OK,
        "one-checkbox native page activates under a hidden same-thread parent");
  HWND dialog = parent ? GetWindow(parent, GW_CHILD) : nullptr;
  HWND checkbox = dialog ? GetDlgItem(dialog, kExtraReportControl) : nullptr;
  Check(checkbox && SendMessageW(checkbox, BM_GETCHECK, 0, 0) == BST_UNCHECKED,
        "control starts with the stored setting");
  if (!checkbox) {
    page->Release();
    if (parent) DestroyWindow(parent);
    return;
  }
  Check((GetWindowLongPtrW(dialog, GWL_STYLE) & WS_VISIBLE) != 0,
        "Activate shows the page without a separate host Show call");
  RECT placed{};
  GetWindowRect(dialog, &placed);
  MapWindowPoints(nullptr, parent, reinterpret_cast<POINT*>(&placed), 2);
  Check(EqualRect(&placed, &rect), "Activate positions the page in the supplied inset parent rectangle");
  ShowWindow(parent, SW_SHOWNOACTIVATE);
  Check(IsWindowVisible(dialog) && IsWindowVisible(checkbox),
        "page and checkbox are effectively visible when the host parent is shown");
  RECT pageClient{}, controlBounds{};
  GetClientRect(dialog, &pageClient);
  GetWindowRect(checkbox, &controlBounds);
  MapWindowPoints(nullptr, dialog, reinterpret_cast<POINT*>(&controlBounds), 2);
  Check(controlBounds.left >= 0 && controlBounds.top >= 0 && controlBounds.right <= pageClient.right &&
        controlBounds.bottom <= pageClient.bottom, "checkbox fits inside the activated page");
  Check(page->Show(SW_HIDE) == S_OK && !IsWindowVisible(dialog) && !IsWindowVisible(checkbox) &&
        page->Show(SW_SHOWNORMAL) == S_OK && IsWindowVisible(checkbox),
        "host Hide and Show commands toggle the whole page");
  RECT moved{4, 6, 374, 96};
  const HRESULT moveResult = page->Move(&moved);
  GetWindowRect(dialog, &placed);
  MapWindowPoints(nullptr, parent, reinterpret_cast<POINT*>(&placed), 2);
  Check(moveResult == S_OK && EqualRect(&placed, &moved) && IsWindowVisible(checkbox),
        "Move preserves visibility and uses parent coordinates");
  ShowWindow(parent, SW_HIDE);
  Check(page->Activate(parent, &rect, FALSE) == E_UNEXPECTED && page->Show(SW_MAXIMIZE) == E_INVALIDARG,
        "duplicate activation and unsupported show command are rejected");
  RECT bad{(std::numeric_limits<LONG>::min)(), 0, (std::numeric_limits<LONG>::max)(), 1};
  Check(page->Move(&bad) == E_INVALIDARG && page->Move(nullptr) == E_POINTER,
        "positioning rejects overflowing dimensions and missing rectangle");
  HRESULT wrongThread = S_OK;
  std::thread worker([&] { wrongThread = page->IsPageDirty(); });
  worker.join();
  Check(wrongThread == RPC_E_WRONG_THREAD, "page state rejects calls from another thread");

  SendMessageW(checkbox, BM_CLICK, 0, 0);
  Check(page->IsPageDirty() == S_OK && site.dirtyEvents == 1 && !ReadProofSettings(store.saved).extraReport,
        "checkbox edit marks the page dirty without changing the store");
  IUnknown* unsupported = &site;
  other.loadResult = E_FAIL;
  IUnknown* failedStore = &other;
  Check(page->SetObjects(1, &unsupported) == E_NOINTERFACE && page->SetObjects(1, &failedStore) == E_FAIL &&
        store.refs == 2 && other.refs == 1 && page->IsPageDirty() == S_OK,
        "failed object query/load preserves the prior draft and balances temporary references");
  other.loadResult = S_OK;
  other.throwLoad = true;
  Check(page->SetObjects(1, &failedStore) == E_OUTOFMEMORY && other.refs == 1,
        "throwing object load is contained and releases the queried reference");
  other.throwLoad = false;
  other.saved.SetU32(kProofOffset, 4);
  Check(page->SetObjects(1, &failedStore) == E_INVALIDARG && other.refs == 1,
        "malformed replacement payload is rejected without losing the draft");
  store.commitResult = E_FAIL;
  Check(page->Apply() == E_FAIL && page->IsPageDirty() == S_OK && !ReadProofSettings(store.saved).extraReport,
        "failed Apply leaves committed bytes unchanged and retains the dirty draft");
  store.commitResult = S_OK;
  store.throwCommit = true;
  Check(page->Apply() == E_OUTOFMEMORY && page->IsPageDirty() == S_OK,
        "throwing Apply is contained and remains retryable");
  store.throwCommit = false;
  Check(page->Apply() == S_OK && page->IsPageDirty() == S_FALSE && ReadProofSettings(store.saved).extraReport &&
        store.commits == 1 && page->Apply() == S_OK && store.commits == 1,
        "Apply commits one copied snapshot and repeated clean Apply does not write again");
  SendMessageW(checkbox, BM_CLICK, 0, 0);
  Check(page->Deactivate() == S_OK && !IsWindow(dialog) && page->Activate(parent, &rect, FALSE) == S_OK &&
        page->IsPageDirty() == S_OK, "tab deactivation destroys the window and reactivation preserves the draft");
  dialog = GetWindow(parent, GW_CHILD);
  checkbox = GetDlgItem(dialog, kExtraReportControl);
  Check(SendMessageW(checkbox, BM_GETCHECK, 0, 0) == BST_UNCHECKED,
        "reactivated control displays the unapplied draft");
  Check((GetWindowLongPtrW(dialog, GWL_STYLE) & WS_VISIBLE) != 0,
        "reactivation shows the replacement window without another host Show call");
  Check(page->Deactivate() == S_OK && page->SetObjects(0, nullptr) == S_OK && store.refs == 1 &&
        page->IsPageDirty() == S_FALSE && ReadProofSettings(store.saved).extraReport,
        "disconnect discards unapplied edits while retaining a prior successful Apply");
  Check(page->SetObjects(1, &object) == S_OK && page->Activate(parent, &rect, FALSE) == S_OK &&
        page->IsPageDirty() == S_FALSE, "reopening reloads the committed template setting");
  Check(page->SetPageSite(nullptr) == S_OK && site.refs == 1,
        "site disconnect releases its reference");
  page->Release();
  Check(store.refs == 1 && site.refs == 1 && !GetWindow(parent, GW_CHILD),
        "page destruction releases its remaining object and active child window");
  IPropertyPage* wrongRelease = nullptr;
  const HRESULT created = CreateProofPage(&wrongRelease);
  if (created == S_OK && wrongRelease) {
    wrongRelease->SetPageSite(&site);
    wrongRelease->SetObjects(1, &object);
    const HRESULT activation = wrongRelease->Activate(parent, &rect, FALSE);
    HWND remaining = GetWindow(parent, GW_CHILD);
    std::thread releaseWorker([&] { wrongRelease->Release(); });
    releaseWorker.join();
    Check(activation == S_OK && IsWindow(remaining) && GetWindowLongPtrW(remaining, DWLP_USER) == 0 &&
          store.refs == 1 && site.refs == 1,
          "off-thread final Release detaches userdata; creator thread must destroy the surviving window");
    if (remaining) DestroyWindow(remaining);
  } else {
    Check(false, "off-thread release safety fixture created");
  }
  DestroyWindow(parent);
}
}  // namespace

int main() {
  Payloads();
  Page();
  NativeBridge();
  printf("NATIVE CONFIGURATION %s (%d checks; %d failure(s)); offline only\n",
         failures ? "FAILED" : "PASSED", checks, failures);
  return failures ? 1 : 0;
}
