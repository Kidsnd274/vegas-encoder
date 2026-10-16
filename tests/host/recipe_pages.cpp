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
int FakeEditor(const fs::path& root, const std::wstring& mode) {
  const auto request = Read(root / L"request.json");
  if (ve::HasErrors(ve::SessionRequest(request).at("issues"))) return 80;
  if (mode == L"unnamed" && request.at("templateName") != "Actual template name") return 83;
  HWND owner = reinterpret_cast<HWND>(static_cast<uintptr_t>(std::stoull(request.at("ownerHwnd").get<std::string>())));
  if (!IsWindow(owner) || IsWindowEnabled(owner)) return 81;
  Json result{{"protocol", 1}, {"sessionId", request.at("sessionId")}, {"action", "apply"},
    {"recipe", request.at("recipe")}, {"origin", request.at("origin")}};
  result["recipe"]["video"]["quality"] = 19;
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
    if (mode == L"apply" || mode == L"unnamed") {
      Check(page->IsPageDirty() == S_OK && site.dirty == 1, "valid editor Apply marks only pending page draft dirty");
      holder.commitResult = E_FAIL;
      Check(page->Apply() == E_FAIL && holder.saved.b == original && page->IsPageDirty() == S_OK,
            "failed native Apply preserves committed bytes and retryable draft");
      holder.commitResult = S_OK;
      Check(page->Apply() == S_OK && page->IsPageDirty() == S_FALSE && holder.commits == 1,
            "native Apply retry commits exactly once");
      const auto committed = holder.saved.b;
      Check(page->SetObjects(0, nullptr) == S_OK && holder.saved.b == committed,
            "disconnect retains prior successfully committed settings");
    } else {
      Check(page->IsPageDirty() == S_FALSE && holder.saved.b == original, "cancel/error/unsupported recipe preserves clean draft and store");
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
    for (const auto mode : {L"apply", L"unnamed", L"cancel", L"crash", L"invalid", L"unsupported", L"hang", L"preflight", L"queued-close"})
      Run(root, recipe, mode);
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
