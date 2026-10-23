// Focused native page integration checks. Hidden authored owner + fake child;
// no VEGAS, real Flutter application, installation or process inspection.
#include "../../src/vegas/configuration/recipe_page.h"
#include "../../src/vegas/adapter/vegas_encoder.h"
#include "../../src/support/diagnostics.h"

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iterator>

using namespace vegas_encoder::configuration;
using vegas_encoder::host::Tpl;
using ve::Json;
namespace fs = std::filesystem;
namespace {
int checks = 0;
void Check(bool value, const char* message) { ++checks; if (!value) throw std::runtime_error(message); }
Json Read(const fs::path& path) {
  std::ifstream input(path, std::ios::binary);
  if (!input) throw std::runtime_error("Missing authored fixture/request.");
  const std::string text((std::istreambuf_iterator<char>(input)), {});
  return ve::Parse(reinterpret_cast<const uint8_t*>(text.data()), text.size());
}
std::wstring Exe() {
  wchar_t text[32768]; const auto count = GetModuleFileNameW(nullptr, text, 32768);
  if (!count || count >= 32768) throw std::runtime_error("Cannot locate fake editor.");
  return {text, count};
}
Json ResizeFilter() {
  return {{"type", "resize"}, {"enabled", true}, {"width", 1280}, {"height", 720},
          {"backend", "scale"}, {"algorithm", "bicubic"}, {"fit", "pad"}};
}
int FakeEditor(const fs::path& root, const std::wstring& mode) {
  const auto request = Read(root / L"request.json");
  if (ve::HasErrors(ve::SessionRequest(request).at("issues"))) return 80;
  if (mode == L"unnamed" && request.at("templateName") != "Actual template name") return 83;
  HWND owner = reinterpret_cast<HWND>(static_cast<uintptr_t>(std::stoull(request.at("ownerHwnd").get<std::string>())));
  if (!IsWindow(owner) || IsWindowEnabled(owner)) return 81;
  Json result{{"protocol", 1}, {"sessionId", request.at("sessionId")}, {"action", "apply"},
    {"recipe", request.at("recipe")}, {"origin", request.at("origin")}};
  result["recipe"]["video"]["quality"] = 19;
  if (mode == L"resize-apply" || mode == L"resize-apply-cancel") {
    result["recipe"]["schema"] = 2;
    result["recipe"]["video"]["filters"] = Json::array({ResizeFilter()});
  }
  if (mode == L"apply-cancel" && request.at("recipe").at("video").at("quality") == 19)
    result = {{"protocol", 1}, {"sessionId", request.at("sessionId")}, {"action", "cancel"}};
  if (mode == L"resize-apply-cancel" && request.at("recipe").at("schema") == 2)
    result = {{"protocol", 1}, {"sessionId", request.at("sessionId")}, {"action", "cancel"}};
  if (mode == L"cancel") result = {{"protocol", 1}, {"sessionId", request.at("sessionId")}, {"action", "cancel"}};
  if (mode == L"invalid") result["recipe"]["video"]["quality"] = 1000;
  if (mode == L"unsupported") result["recipe"]["container"]["format"] = "mp4";
  if (mode == L"crash") return 7;
  if (mode == L"hang") { Sleep(60000); return 0; }
  const auto temporary = root / L"result.json.page.tmp";
  std::ofstream file(temporary, std::ios::binary); file << result.dump(); file.close();
  if (!MoveFileExW(temporary.c_str(), (root / L"result.json").c_str(), MOVEFILE_WRITE_THROUGH)) return 82;
  Sleep(100); // Allows the hidden-owner check to see an active session.
  return 0;
}
struct Allocator final : sfio::ISfHostAllocator {
  ULONG refs = 1; int allocations = 0, frees = 0;
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID, void**) override { return E_NOINTERFACE; }
  ULONG STDMETHODCALLTYPE AddRef() override { return ++refs; }
  ULONG STDMETHODCALLTYPE Release() override { return --refs; }
  void* STDMETHODCALLTYPE Alloc(SIZE_T count) override { ++allocations; return std::calloc(1, count); }
  void STDMETHODCALLTYPE Free(void* value) override { ++frees; std::free(value); }
};
struct Holder final : sfio::ISfFileIOTemplateEditHolder {
  Holder(Allocator& allocator, const Json& recipe) : allocator(allocator) {
    auto empty = Tpl::Make(L"Actual template name", L"Preserved notes", 0);
    empty.SetGuid(sfio::tpl::iidOwner, vegas_encoder::GUID_VegasEncoderType);
    saved = CreateRecipeTemplate(empty, vegas_encoder::GUID_VegasEncoderType,
        {{"recipe", recipe}, {"origin", nullptr}, {"vegasPrefs", Json::object()}, {"writtenBy", "page-test"}});
  }
  Allocator& allocator; Tpl saved; ULONG refs = 1; int commits = 0;
  HRESULT commitResult = S_OK;
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void** out) override {
    if (!out) return E_POINTER; *out = nullptr;
    if (iid != IID_IUnknown && iid != __uuidof(sfio::ISfFileIOTemplateEditHolder)) return E_NOINTERFACE;
    *out = this; AddRef(); return S_OK;
  }
  ULONG STDMETHODCALLTYPE AddRef() override { return ++refs; }
  ULONG STDMETHODCALLTYPE Release() override { return --refs; }
  HRESULT STDMETHODCALLTYPE Slot3(sfio::SFTEMPLATE** out) override {
    *out = static_cast<sfio::SFTEMPLATE*>(allocator.Alloc(saved.b.size()));
    if (!*out) return E_OUTOFMEMORY;
    memcpy(*out, saved.b.data(), saved.b.size()); return S_OK;
  }
  HRESULT STDMETHODCALLTYPE Slot4(const sfio::SFTEMPLATE* value) override {
    if (commitResult != S_OK) return commitResult;
    auto copy = Tpl::Copy(value); saved.b.swap(copy.b); ++commits; return S_OK;
  }
  HRESULT STDMETHODCALLTYPE Slot5(sfio::SFTEMPLATE**) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE Slot6(LONG, LONG*) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE Slot7(LONG, LONG) override { return E_NOTIMPL; }
};
struct Site final : IPropertyPageSite {
  ULONG refs = 1; int dirty = 0;
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID, void**) override { return E_NOINTERFACE; }
  ULONG STDMETHODCALLTYPE AddRef() override { return ++refs; }
  ULONG STDMETHODCALLTYPE Release() override { return --refs; }
  HRESULT STDMETHODCALLTYPE OnStatusChange(DWORD flags) override { if (flags & PROPPAGESTATUS_DIRTY) ++dirty; return S_OK; }
  HRESULT STDMETHODCALLTYPE GetLocaleID(LCID* locale) override { if (!locale) return E_POINTER; *locale = 0x409; return S_OK; }
  HRESULT STDMETHODCALLTYPE GetPageContainer(IUnknown** out) override { if (out) *out = nullptr; return E_NOINTERFACE; }
  HRESULT STDMETHODCALLTYPE TranslateAccelerator(MSG*) override { return S_FALSE; }
};
void Pump() {
  MSG message{};
  while (PeekMessageW(&message, nullptr, 0, 0, PM_REMOVE)) { TranslateMessage(&message); DispatchMessageW(&message); }
}
void WaitEnabled(HWND button) {
  const auto started = GetTickCount64();
  while (!IsWindowEnabled(button) && GetTickCount64() - started < 15000) { Pump(); Sleep(10); }
  Check(IsWindowEnabled(button) != FALSE, "fake editor exits within focused harness bound");
}
std::wstring Status(HWND page) {
  wchar_t text[2048]{}; GetDlgItemTextW(page, kRecipeStatusControl, text, 2048); return text;
}
std::wstring Summary(HWND page) {
  const auto control = GetDlgItem(page, kRecipeSummaryControl);
  const int length = GetWindowTextLengthW(control);
  std::wstring text(static_cast<size_t>(length) + 1, L'\0');
  GetWindowTextW(control, text.data(), length + 1); text.resize(static_cast<size_t>(length));
  return text;
}
void CheckSummary(HWND page, const Json& snapshot, const Json& media = Json(nullptr)) {
  const auto facts = ve::SnapshotSummary({{"snapshot", snapshot}, {"media", media}});
  const auto text = Summary(page);
  for (const auto name : {"preset", "video", "resolution", "filters", "audio", "container"})
    Check(text.find(vegas_encoder::Widen(ve::Str(facts, name))) != std::wstring::npos,
          "native summary displays selected draft's core-generated fact");
  Check(text.find(L"Preset:") != std::wstring::npos && text.find(L"Container:") != std::wstring::npos &&
        text.find(L"Use a ") == std::wstring::npos, "six summary rows remain separate from suffix/session guidance");
}
void CheckLayout(HWND dialog) {
  RECT area{}; GetClientRect(dialog, &area);
  int previousBottom = 0;
  for (const auto id : {kRecipeSummaryLabelControl, kRecipeSummaryControl, kEditRecipeControl, kRecipeStatusControl}) {
    RECT child{}; GetWindowRect(GetDlgItem(dialog, id), &child);
    MapWindowPoints(nullptr, dialog, reinterpret_cast<POINT*>(&child), 2);
    Check(child.left >= 0 && child.top >= previousBottom && child.right <= area.right &&
          child.bottom <= area.bottom && child.right > child.left && child.bottom > child.top,
          "DPI/layout keeps summary, edit button and status visible without overlap");
    previousBottom = child.bottom;
  }
}
void Run(const fs::path& root, const Json& recipe, const std::wstring& mode) {
  Allocator allocator; Holder holder(allocator, recipe); Site site;
  RecipePageOptions options;
  options.owner = vegas_encoder::GUID_VegasEncoderType;
  options.launch = {Exe(), {L"--fake-page", mode}};
  options.sessionRoot = root.wstring(); options.dllVersion = "page-test"; options.coreVersion = "core-test";
  int preflights = 0;
  options.beforeLaunch = [&] { ++preflights; if (mode == L"preflight") throw std::runtime_error("App version mismatch."); };
  options.validateRecipe = [](const Json& candidate) {
    if (candidate.at("container").at("format") != "mkv") throw std::runtime_error("This candidate requires MKV.");
  };
  IPropertyPage* page = nullptr;
  Check(CreateNativeRecipePage(nullptr, options, &page) == E_POINTER &&
        CreateNativeRecipePage(&allocator, options, nullptr) == E_POINTER, "page factory rejects missing allocator/output");
  Check(CreateNativeRecipePage(&allocator, options, &page) == S_OK && page, "candidate native recipe page created");
  PROPPAGEINFO pageInfo{}; pageInfo.cb = sizeof pageInfo;
  Check(page->GetPageInfo(&pageInfo) == S_OK && pageInfo.size.cy >= 250,
        "native page requests enough preferred height for a six-row summary");
  CoTaskMemFree(pageInfo.pszTitle);
  if (mode == L"unnamed") {
    const auto captured = holder.saved;
    holder.saved.SetU32(sfio::tpl::cchAllocText,0);
    BYTE info[56]{};
    auto* nativePage = static_cast<sfio::ISfFileIOPropertyPage*>(page);
    Check(nativePage->Slot14(captured.Ptr(),info) == S_OK && holder.saved.Name().empty(),
          "page captures display name separately from an unnamed intact holder snapshot");
  }
  IUnknown* object = &holder;
  Check(page->SetPageSite(&site) == S_OK && page->SetObjects(1, &object) == S_OK &&
        page->IsPageDirty() == S_FALSE, "native holder loads an owned clean draft");
  HWND parent = CreateWindowExW(0, L"STATIC", L"Hidden native recipe page owner", WS_OVERLAPPED,
      0, 0, 480, 180, nullptr, nullptr, GetModuleHandleW(nullptr), nullptr);
  RECT rectangle{0, 0, 440, 118};
  Check(parent && page->Activate(parent, &rectangle, FALSE) == S_OK, "page activates on hidden creator-thread owner");
  HWND dialog = GetWindow(parent, GW_CHILD), button = GetDlgItem(dialog, kEditRecipeControl);
  Check(dialog && button && IsWindowEnabled(button), "native edit control starts ready");
  CheckSummary(dialog, ReadRecipeSnapshot(holder.saved, options.owner));
  CheckLayout(dialog);
  const HWND summary = GetDlgItem(dialog, kRecipeSummaryControl);
  const auto summaryStyle = GetWindowLongPtrW(summary, GWL_STYLE);
  Check((summaryStyle & (ES_MULTILINE | ES_READONLY | WS_TABSTOP | WS_VSCROLL)) ==
        (ES_MULTILINE | ES_READONLY | WS_TABSTOP | WS_VSCROLL) && !(summaryStyle & ES_AUTOHSCROLL),
        "summary supports keyboard selection, vertical scrolling and wrapping while read-only");
  Check(GetNextDlgTabItem(dialog, summary, FALSE) == button &&
        GetNextDlgTabItem(dialog, button, FALSE) == GetDlgItem(dialog, kRecipeStatusControl),
        "keyboard tab order connects selectable summary, settings button and scrollable session text");
  const auto originalSummary = Summary(dialog);
  SendMessageW(summary, EM_SETSEL, 0, 6);
  DWORD selectionStart = 0, selectionEnd = 0;
  SendMessageW(summary, EM_GETSEL, reinterpret_cast<WPARAM>(&selectionStart), reinterpret_cast<LPARAM>(&selectionEnd));
  Check(selectionStart == 0 && selectionEnd == 6, "read-only summary text can be selected for copying");
  SendMessageW(summary, WM_CHAR, L'X', 1);
  Check(Summary(dialog) == originalSummary, "read-only summary rejects text edits");
  const auto original = holder.saved.b;
  SendMessageW(button, BM_CLICK, 0, 0);
  Check(page->Apply() == E_PENDING && !IsWindowEnabled(button), "queued editor startup prevents host Apply/repeated launches");
  if (mode == L"queued-close") {
    Check(page->SetObjects(0, nullptr) == S_OK && IsWindowEnabled(parent), "disconnect cancels queued startup before any helper");
    Pump(); Check(preflights == 0 && holder.saved.b == original, "stale startup message cannot launch or commit");
  } else {
    Pump();
    if (mode == L"preflight") {
      Check(IsWindowEnabled(parent) && IsWindowEnabled(button) && Status(dialog).find(L"version mismatch") != std::wstring::npos,
            "failed app preflight leaves owner enabled and reports actionable failure");
    } else {
      Check(!IsWindowEnabled(parent) && page->Apply() == E_PENDING, "active helper disables actual root owner and prevents host Apply");
      if (mode == L"hang") {
        Check(page->Deactivate() == S_OK && IsWindowEnabled(parent), "teardown cancels owned helper and restores owner without waiting");
      } else {
        WaitEnabled(button);
        Check(IsWindowEnabled(parent), "exit/cancel/crash/rejection restores native owner");
      }
    }
    Check(holder.saved.b == original && holder.commits == 0, "editor never directly mutates native template store");
    if (mode == L"apply" || mode == L"unnamed" || mode == L"apply-cancel" ||
        mode == L"resize-apply" || mode == L"resize-apply-cancel") {
      Check(page->IsPageDirty() == S_OK && site.dirty == 1, "valid editor Apply marks only pending page draft dirty");
      Check(Summary(dialog) != originalSummary && Status(dialog).find(L"VEGAS Apply or OK") != std::wstring::npos,
            "accepted editor change refreshes summary and separately marks pending host Apply");
      const auto pendingSummary = Summary(dialog);
      if (mode == L"apply-cancel" || mode == L"resize-apply-cancel") {
        SendMessageW(button, BM_CLICK, 0, 0); Pump(); WaitEnabled(button);
        Check(Summary(dialog) == pendingSummary && page->IsPageDirty() == S_OK &&
              holder.saved.b == original && holder.commits == 0,
              "cancel after an accepted draft preserves its summary and pending native transaction");
        Check(Status(dialog).find(L"VEGAS Apply or OK") != std::wstring::npos,
              "cancel after accepted draft keeps pending host-Apply guidance");
      }
      Check(page->Deactivate() == S_OK && page->Activate(parent, &rectangle, FALSE) == S_OK,
            "changing tabs preserves the unapplied summary");
      dialog = GetWindow(parent, GW_CHILD); button = GetDlgItem(dialog, kEditRecipeControl);
      Check(Summary(dialog) == pendingSummary && page->IsPageDirty() == S_OK,
            "reactivated page displays the pending draft rather than committed snapshot");
      holder.commitResult = E_FAIL;
      Check(page->Apply() == E_FAIL && holder.saved.b == original && page->IsPageDirty() == S_OK,
            "failed native Apply preserves committed bytes and retryable draft");
      Check(Summary(dialog) == pendingSummary, "failed host Apply preserves pending summary");
      holder.commitResult = S_OK;
      Check(page->Apply() == S_OK && page->IsPageDirty() == S_FALSE && holder.commits == 1,
            "native Apply retry commits exactly once");
      Check(Summary(dialog) == pendingSummary && Status(dialog).find(L"VEGAS Apply or OK") == std::wstring::npos,
            "successful host Apply retains summary and clears pending-Apply indication");
      if (mode == L"resize-apply" || mode == L"resize-apply-cancel") {
        const auto saved = ReadRecipeSnapshot(holder.saved, options.owner);
        Check(saved.at("recipe").at("schema") == 2 &&
              ve::Canonical(saved.at("recipe").at("video").at("filters")) == ve::Canonical(Json::array({ResizeFilter()})),
              "accepted structured resize survives schema-2 native payload and host commit");
        CheckSummary(dialog, saved);
      }
      const auto committed = holder.saved.b;
      Check(page->SetObjects(0, nullptr) == S_OK && holder.saved.b == committed,
            "disconnect retains prior successfully committed settings");
    } else {
      Check(page->IsPageDirty() == S_FALSE && holder.saved.b == original, "cancel/error/unsupported recipe preserves clean draft and store");
      if (mode != L"hang") Check(Summary(dialog) == originalSummary, "cancel/crash/rejection/launch failure preserves prior summary");
      if (mode == L"unsupported") Check(Status(dialog).find(L"requires MKV") != std::wstring::npos, "native candidate constraint explains rejected editor result");
    }
  }
  Check(page->SetObjects(0, nullptr) == S_OK && page->SetPageSite(nullptr) == S_OK,
        "native disconnect releases draft and page site");
  page->Release();
  Check(allocator.refs == 1 && holder.refs == 1 && site.refs == 1 && allocator.allocations == allocator.frees &&
        IsWindowEnabled(parent) && !GetWindow(parent, GW_CHILD), "page teardown balances references/allocations and owner state");
  DestroyWindow(parent);
}
void SelectionAndLayout(const fs::path& root, const Json& recipe) {
  Allocator allocator; Holder first(allocator, recipe), second(allocator, recipe); Site site;
  auto changed = ReadRecipeSnapshot(second.saved, vegas_encoder::GUID_VegasEncoderType);
  changed["recipe"]["video"]["quality"] = 24;
  changed["origin"] = {{"presetId", "saved-origin"}, {"revision", 7},
    {"name", std::string("Saved origin \xe5\xae\xb9\xe9\x87\x8f ") + std::string(220, 'W')}};
  second.saved = ReplaceRecipeSnapshot(second.saved, vegas_encoder::GUID_VegasEncoderType, changed);
  RecipePageOptions options;
  options.owner = vegas_encoder::GUID_VegasEncoderType;
  options.launch = {Exe(), {L"--fake-page", L"apply"}};
  options.sessionRoot = root.wstring(); options.dllVersion = "page-test"; options.coreVersion = "core-test";
  options.beforeLaunch = [] { throw std::runtime_error("Summary must never launch or probe."); };
  options.context["media"] = {{"video", {{"width", 320}, {"height", 240}, {"fps", {30000, 1001}}, {"pixfmt", "p010le"}, {"sar", "4:3"}}},
    {"audio", {{"rate", 48000}, {"channels", 2}, {"sampleFmt", "f32le"}}}, {"durationSec", nullptr}};
  IPropertyPage* page = nullptr;
  Check(CreateNativeRecipePage(&allocator, options, &page) == S_OK, "selection test creates native summary page");
  IUnknown* object = &first;
  Check(page->SetPageSite(&site) == S_OK && page->SetObjects(1, &object) == S_OK, "selection test loads first snapshot");
  HWND parent = CreateWindowExW(0, L"STATIC", L"Summary layout owner", WS_OVERLAPPED,
      0, 0, 900, 600, nullptr, nullptr, GetModuleHandleW(nullptr), nullptr);
  RECT bounds{0, 0, 440, 270};
  Check(parent && page->Activate(parent, &bounds, FALSE) == S_OK, "selection test activates native page");
  const HWND dialog = GetWindow(parent, GW_CHILD);
  const auto initial = Summary(dialog);
  object = &second;
  Check(page->SetObjects(1, &object) == S_OK && Summary(dialog) != initial && page->IsPageDirty() == S_FALSE,
        "selecting another template refreshes embedded settings without launching editor or dirtying template");
  CheckSummary(dialog, changed, options.context.at("media"));
  Check(Summary(dialog).find(L"320 × 240") != std::wstring::npos && Summary(dialog).find(L"1920") == std::wstring::npos,
        "explicit host facts reach summary without substituting preview sample dimensions");
  Check(Summary(dialog).find(L"Saved origin 容量") != std::wstring::npos && Summary(dialog).find(L"Modified") == std::wstring::npos,
        "stored Unicode/long origin survives wrapping without invented modified marker");
  for (const UINT dpi : {96u, 144u, 192u}) {
    bounds.right = MulDiv(440, static_cast<int>(dpi), 96);
    bounds.bottom = MulDiv(270, static_cast<int>(dpi), 96);
    SendMessageW(dialog, WM_DPICHANGED, MAKEWPARAM(dpi, dpi), 0);
    Check(page->Move(&bounds) == S_OK, "host may resize native page after DPI changes");
    CheckLayout(dialog);
    LOGFONTW font{};
    const auto handle = reinterpret_cast<HFONT>(SendMessageW(GetDlgItem(dialog, kEditRecipeControl), WM_GETFONT, 0, 0));
    Check(handle && GetObjectW(handle, sizeof font, &font) && -font.lfHeight >= MulDiv(8, static_cast<int>(dpi), 96),
          "native page updates the system message font for DPI");
  }
  bounds = {0, 0, 320, 118};
  SendMessageW(dialog, WM_DPICHANGED, MAKEWPARAM(96, 96), 0);
  Check(page->Move(&bounds) == S_OK, "legacy small host allocation remains supported");
  CheckLayout(dialog);
  SendMessageW(GetDlgItem(dialog, kRecipeSummaryControl), EM_LINESCROLL, 0, 100);
  Check(SendMessageW(GetDlgItem(dialog, kRecipeSummaryControl), EM_GETFIRSTVISIBLELINE, 0, 0) > 0,
        "long summary remains reachable by scrolling in small host allocation");
  Check(page->SetObjects(0, nullptr) == S_OK && page->SetPageSite(nullptr) == S_OK,
        "selection test disconnects native summary page");
  page->Release(); DestroyWindow(parent);
  Check(allocator.allocations == allocator.frees && allocator.refs == 1 && first.refs == 1 && second.refs == 1 && site.refs == 1,
        "selection and DPI teardown balance native references and allocations");
}
} // namespace
int wmain(int argc, wchar_t** argv) {
  try {
    if (argc == 5 && std::wstring(argv[1]) == L"--fake-page" && std::wstring(argv[3]) == L"--edit-session")
      return FakeEditor(argv[4], argv[2]);
    if (argc != 3) throw std::runtime_error("Pass authored B0 fixtures and isolated session root.");
    auto recipe = Read(argv[1]).at("fixtures")[0].at("recipe");
    recipe["container"]["format"] = "mkv";
    const auto root = fs::absolute(fs::path(argv[2])) / vegas_encoder::Widen("page-" + NewEditSessionId());
    fs::create_directory(root);
    for (const auto mode : {L"apply", L"unnamed", L"apply-cancel", L"resize-apply", L"resize-apply-cancel",
        L"cancel", L"crash", L"invalid", L"unsupported", L"hang", L"preflight", L"queued-close"})
      Run(root, recipe, mode);
    SelectionAndLayout(root, recipe);
    auto resized = recipe; resized["schema"] = 2; resized["video"]["filters"] = Json::array({ResizeFilter()});
    Run(root, resized, L"cancel");
    WNDCLASSW returnClass{}; returnClass.lpfnWndProc=DefWindowProcW; returnClass.hInstance=GetModuleHandleW(nullptr);
    returnClass.lpszClassName=L"B6_RETURN_TEST";
    Check(RegisterClassW(&returnClass)!=0,"register real top-level owner regression class");
    const auto main = CreateWindowExW(0,returnClass.lpszClassName,L"Owned host return regression",WS_OVERLAPPEDWINDOW,
      0,0,320,180,nullptr,nullptr,GetModuleHandleW(nullptr),nullptr);
    const auto owner = CreateWindowExW(0,returnClass.lpszClassName,L"Owned settings return regression",WS_OVERLAPPEDWINDOW,
      0,0,240,120,main,nullptr,GetModuleHandleW(nullptr),nullptr);
    Check(main && owner,"create owned native return regression windows");
    Check(GetWindow(owner,GW_OWNER)==main,"settings window belongs to the host window");
    ShowWindow(main,SW_SHOWMINNOACTIVE); EnableWindow(owner,FALSE);
    ReturnRecipeOwner(owner,nullptr,false);
    Check(IsIconic(main) && IsWindowEnabled(owner),"background completion re-enables without restoring or activating host");
    EnableWindow(owner,FALSE); ReturnRecipeOwner(owner,nullptr,true);
    if (IsIconic(main) || !IsWindowEnabled(owner))
      printf("Owner return diagnostic: main=%p owner=%p rootOwner=%p mainIconic=%d ownerEnabled=%d caller=%lu mainThread=%lu\n",
        static_cast<void*>(main),static_cast<void*>(owner),static_cast<void*>(GetAncestor(owner,GA_ROOTOWNER)),
        IsIconic(main),IsWindowEnabled(owner),GetCurrentThreadId(),GetWindowThreadProcessId(main,nullptr));
    Check(!IsIconic(main) && IsWindowEnabled(owner),"return from foreground editor restores iconic host and its settings owner");
    DestroyWindow(owner); DestroyWindow(main);
    UnregisterClassW(returnClass.lpszClassName,returnClass.hInstance);
    printf("B6 NATIVE RECIPE PAGE PASSED: %d checks; hidden authored owner/fake child, no VEGAS or real app\n", checks);
    return 0;
  } catch (const std::exception& error) {
    printf("B6 NATIVE RECIPE PAGE FAILED after %d checks: %s\n", checks, error.what()); return 1;
  }
}
