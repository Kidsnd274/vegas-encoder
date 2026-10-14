// B6 transport tests use only authored fake children and isolated local files.
// This executable is also the fake editor/descendant; no real app or VEGAS runs.
#include "../../src/vegas/configuration/editor_session.h"
#include "../../src/vegas/configuration/recipe_template.h"
#include "../../src/vegas/adapter/vegas_encoder.h"
#include "../../src/support/diagnostics.h"
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <iterator>
#include <thread>

using ve::Json;
using namespace vegas_encoder::configuration;
namespace fs = std::filesystem;
namespace {
int checks = 0;
const auto owner = vegas_encoder::GUID_VegasEncoderType;
const std::wstring oddArgument = L"space \u03a9 \u6d4b\u8bd5 \"quoted\" and trailing\\";
void Check(bool value, const char* message) { ++checks; if (!value) throw std::runtime_error(message); }
template<class F> bool Rejects(F&& call) { try { call(); } catch (const std::exception&) { return true; } return false; }
Json Read(const fs::path& path) {
  std::ifstream file(path, std::ios::binary);
  if (!file) throw std::runtime_error("Missing test JSON.");
  const std::string bytes((std::istreambuf_iterator<char>(file)), {});
  return ve::Parse(reinterpret_cast<const uint8_t*>(bytes.data()), bytes.size());
}
void Write(const fs::path& path, const std::string& bytes) {
  std::ofstream file(path, std::ios::binary); file << bytes; file.close();
  if (!file) throw std::runtime_error("Cannot write test file.");
}
void Atomic(const fs::path& directory, const Json& result) {
  const auto temp = directory / L"result.json.fake.tmp";
  Write(temp, result.dump());
  if (!MoveFileExW(temp.c_str(), (directory / L"result.json").c_str(), MOVEFILE_WRITE_THROUGH))
    throw std::runtime_error("Cannot publish fake result.");
}
std::wstring Executable() {
  wchar_t path[32768]; const auto count = GetModuleFileNameW(nullptr, path, 32768);
  if (!count || count >= 32768) throw std::runtime_error("Cannot locate fake executable.");
  return {path, count};
}
int FakeEditor(int argc, wchar_t** argv) {
  if (argc != 6 || std::wstring(argv[3]) != oddArgument || std::wstring(argv[4]) != L"--edit-session") return 81;
  const fs::path directory = argv[5]; const std::wstring mode = argv[2];
  const auto request = Read(directory / L"request.json");
  if (ve::HasErrors(ve::SessionRequest(request).at("issues"))) return 82;
  Json result{{"protocol", 1}, {"sessionId", request.at("sessionId")}, {"action", "apply"},
    {"recipe", request.at("recipe")}, {"origin", request.at("origin")}};
  result["recipe"]["video"]["quality"] = 19;
  if (mode == L"crash") { Atomic(directory, result); return 7; }
  if (mode == L"missing") return 0;
  if (mode == L"malformed") { Write(directory / L"result.json", "{unfinished"); return 0; }
  if (mode == L"oversize") { Write(directory / L"result.json", std::string(VE_CORE_JSON_LIMIT + 1, 'x')); return 0; }
  if (mode == L"directory") { fs::create_directory(directory / L"result.json"); return 0; }
  if (mode == L"alias") {
    const auto original = directory.parent_path() / L"alias-target.json";
    Write(original, result.dump());
    return CreateHardLinkW((directory / L"result.json").c_str(), original.c_str(), nullptr) ? 0 : 83;
  }
  if (mode == L"mismatch") result["sessionId"] = "another-session";
  if (mode == L"future") result["protocol"] = 2;
  if (mode == L"domain") result["recipe"]["video"]["quality"] = 1000;
  if (mode == L"cancel") result = {{"protocol", 1}, {"sessionId", request.at("sessionId")}, {"action", "cancel"}};
  if (mode == L"descendant") {
    std::wstring command = L"\"" + Executable() + L"\" --descendant";
    STARTUPINFOW startup{}; startup.cb = sizeof(startup); PROCESS_INFORMATION process{};
    if (!CreateProcessW(Executable().c_str(), command.data(), nullptr, nullptr, FALSE, CREATE_NO_WINDOW,
        nullptr, nullptr, &startup, &process)) return 84;
    result["childPid"] = process.dwProcessId;
    CloseHandle(process.hThread); CloseHandle(process.hProcess);
  }
  if (mode == L"unknown") Write(directory / L"keep.me", "preserve unknown files");
  // Real services also leave this lock and may leave an interrupted atomic temp.
  Write(directory / L".result.lock", "");
  Write(directory / L"result.json.interrupted.tmp", "unfinished");
  Atomic(directory, result);
  if (mode == L"early") Sleep(1500); // Result alone must not signal editor exit.
  if (mode == L"hang") Sleep(60000); // Explicit Cancel/destruction owns this process.
  return 0;
}
Json Request() {
  return {{"protocol", 1}, {"sessionId", NewEditSessionId()}, {"templateName", "draft supplies name"},
    {"ownerHwnd", "1"}, {"dllVersion", "offline-b6"}, {"coreVersion", "test"},
    {"context", {{"hostVersion", nullptr}, {"project", nullptr}, {"media", nullptr}}}, {"baseRecipe", nullptr}};
}
vegas_encoder::host::Tpl Template(const Json& recipe) {
  auto empty = vegas_encoder::host::Tpl::Make(L"Session \u03a9 \u6d4b\u8bd5", L"", 0);
  empty.SetGuid(sfio::tpl::iidOwner, owner);
  return CreateRecipeTemplate(empty, owner, {{"recipe", recipe}, {"origin", nullptr},
    {"vegasPrefs", {{"preserve", true}}}, {"writtenBy", "before-transport"}});
}
EditorLaunch Launch(const std::wstring& mode) { return {Executable(), {L"--fake-editor", mode, oddArgument}}; }
EditorExit Finish(EditorSessionTransport& transport) {
  const auto started = GetTickCount64();
  while (GetTickCount64() - started < 20000) {
    if (auto result = transport.Poll()) return std::move(*result);
    Sleep(10); // Harness only; no production wait loop.
  }
  transport.Cancel(); throw std::runtime_error("Fake child exceeded harness bound.");
}
void WaitForFile(const fs::path& path) {
  const auto started = GetTickCount64();
  while (!fs::exists(path) && GetTickCount64() - started < 20000) Sleep(10);
  Check(fs::exists(path), "fake child published its early result");
}
void StopCheck(DWORD pid) {
  HANDLE process = OpenProcess(SYNCHRONIZE | PROCESS_TERMINATE, FALSE, pid);
  if (!process) { Check(GetLastError() == ERROR_INVALID_PARAMETER, "owned fake process no longer exists"); return; }
  const auto result = WaitForSingleObject(process, 2000);
  if (result != WAIT_OBJECT_0) TerminateProcess(process, 1); // Failed-test cleanup of our explicit fake only.
  CloseHandle(process);
  Check(result == WAIT_OBJECT_0, "owned fake child/descendant terminates within harness bound");
}
void Run(const fs::path& parent, const Json& recipe) {
  const auto root = parent / (L"sessions \u03a9 \u6d4b\u8bd5 " + vegas_encoder::Widen(NewEditSessionId()));
  Check(fs::create_directory(root), "fresh isolated session root");
  Check(Rejects([&] { EditorSessionTransport relative(L"relative-root"); }) &&
        Rejects([&] { EditorSessionTransport missing((root / L"missing").wstring()); }), "relative/missing roots refused");
  const auto junction = parent / L"junction";
  if (fs::exists(junction)) {
    Check(Rejects([&] { EditorSessionTransport linked(junction.wstring()); }), "junction root refused");
    Check(Rejects([&] { EditorSessionTransport linked((junction / L"child").wstring()); }), "junction ancestor refused");
  }
  const auto value = Template(recipe);
  RecipeTemplateDraft draft(value, owner, "b6-transport-test");
  auto request = draft.BeginEdit(Request());
  std::wstring completedDirectory;
  {
    EditorSessionTransport transport(root.wstring());
    Check(!transport.Active() && !transport.Poll(), "transport starts idle");
    transport.Start(request, Launch(L"early")); completedDirectory = transport.Directory();
    Check(transport.Active() && transport.ProcessId() != 0 &&
      fs::path(completedDirectory).parent_path() == root, "child has a fresh directory confined to explicit root");
    Check(ve::Canonical(Read(fs::path(completedDirectory) / L"request.json")) == ve::Canonical(request) &&
      !fs::exists(fs::path(completedDirectory) / L"request.json.tmp"), "complete bounded request published before child");
    Check(Rejects([&] { transport.Start(request, Launch(L"apply")); }), "second launch cannot replace running editor");
    Check(!MoveFileExW(completedDirectory.c_str(), (completedDirectory + L"-moved").c_str(), 0),
      "live session directory pin prevents namespace replacement");
    WaitForFile(fs::path(completedDirectory) / L"result.json");
    Check(!transport.Poll() && transport.Active(), "early result ignored until child exits");
    const auto exit = Finish(transport);
    Check(exit.exitCode == 0 && exit.diagnostic.empty() && exit.cleanupComplete && !fs::exists(completedDirectory),
      "successful editor exit and known protocol temp/lock cleanup");
    Check(draft.FinishEdit(exit.result, exit.exitCode).disposition == EditDisposition::applied && draft.Dirty(),
      "real file/child Apply changes only draft through C4 transaction");
    Check(!transport.Active() && !transport.Poll() &&
      draft.FinishEdit(exit.result, exit.exitCode).disposition == EditDisposition::noSession, "terminal result consumed only once");
    bool wrongThread = false;
    std::thread worker([&] { wrongThread = Rejects([&] { transport.Poll(); }) && Rejects([&] { transport.Cancel(); }); });
    worker.join(); Check(wrongThread, "transport polling/cancellation remains on creator thread");
  }
  Check(ve::Canonical(ReadRecipeSnapshot(value, owner).at("recipe")) == ve::Canonical(recipe),
    "transport never alters stored template bytes");
  Write(root / L"not-executable.exe", "authored non-executable test file");
  {
    // The first invalid-image CreateProcess refusal changed the process-wide
    // count by 14 in this harness. Prime that path before measuring steady
    // state; repeating that failure below must not grow the handle count again.
    EditorSessionTransport warm(root.wstring()); auto invalid = Launch(L"apply");
    invalid.application = (root / L"not-executable.exe").wstring();
    Check(Rejects([&] { warm.Start(request, invalid); }) && !warm.Active() && !fs::exists(warm.Directory()),
      "prime invalid-image refusal while checking its owned cleanup");
  }
  DWORD handlesBefore = 0;
  Check(GetProcessHandleCount(GetCurrentProcess(), &handlesBefore) != FALSE, "record warmed parent handle balance");
  const auto prior = ve::Canonical(draft.Snapshot());
  for (const auto& mode : {L"cancel", L"crash", L"missing", L"malformed", L"oversize", L"mismatch", L"future", L"alias", L"domain", L"directory"}) {
    request = draft.BeginEdit(Request());
    EditorSessionTransport transport(root.wstring()); transport.Start(request, Launch(mode));
    const auto exit = Finish(transport);
    Check(exit.exitCode == (std::wstring(mode) == L"crash" ? 7u : 0u),
      "fake malformed-result modes actually exit normally; crash retains its exit code");
    const auto outcome = draft.FinishEdit(exit.result, exit.exitCode);
    Check(outcome.disposition == (std::wstring(mode) == L"domain" ? EditDisposition::rejected : EditDisposition::cancelled) &&
      ve::Canonical(draft.Snapshot()) == prior && !draft.Editing(), "cancel/crash/invalid result preserves earlier editor Apply");
    Check(!transport.Poll(), "invalid result also terminal once");
    if (std::wstring(mode) == L"directory") {
      Check(!exit.cleanupComplete && fs::is_directory(fs::path(transport.Directory()) / L"result.json"),
        "cleanup never recurses into a result directory");
      Check(RemoveDirectoryW((fs::path(transport.Directory()) / L"result.json").c_str()) &&
        RemoveDirectoryW(transport.Directory().c_str()), "harness removes only its two empty known directories");
    } else Check(exit.cleanupComplete, "invalid regular results cleaned without touching root");
  }
  Check(fs::exists(root / L"alias-target.json"), "linked result target outside session remains intact");
  {
    request = draft.BeginEdit(Request());
    EditorSessionTransport transport(root.wstring()); transport.Start(request, Launch(L"early"));
    WaitForFile(fs::path(transport.Directory()) / L"result.json");
    transport.Cancel(); transport.Cancel(); const auto exit = Finish(transport);
    Check(exit.result.is_null() && exit.exitCode != 0 && exit.cleanupComplete &&
      draft.FinishEdit(exit.result, exit.exitCode).disposition == EditDisposition::cancelled &&
      ve::Canonical(draft.Snapshot()) == prior, "explicit cancellation discards even a prewritten Apply and is idempotent");
  }
  {
    request = draft.BeginEdit(Request());
    EditorSessionTransport transport(root.wstring()); transport.Start(request, Launch(L"unknown"));
    const auto exit = Finish(transport);
    Check(!exit.cleanupComplete && !exit.diagnostic.empty() && fs::exists(fs::path(transport.Directory()) / L"keep.me"),
      "unexpected session file preserved and cleanup limitation reported");
    draft.FinishEdit(exit.result, exit.exitCode);
    Check(DeleteFileW((fs::path(transport.Directory()) / L"keep.me").c_str()) && RemoveDirectoryW(transport.Directory().c_str()),
      "harness removes its specific retained file and empty directory");
  }
  {
    request = draft.BeginEdit(Request());
    EditorSessionTransport transport(root.wstring()); transport.Start(request, Launch(L"descendant"));
    const auto exit = Finish(transport);
    Check(exit.result.contains("childPid") && exit.cleanupComplete, "fake editor descendant started in owned job");
    StopCheck(exit.result.at("childPid").get<DWORD>());
    draft.FinishEdit(exit.result, exit.exitCode);
  }
  {
    request = draft.BeginEdit(Request()); DWORD pid = 0;
    {
      EditorSessionTransport transport(root.wstring()); transport.Start(request, Launch(L"hang"));
      pid = transport.ProcessId(); WaitForFile(fs::path(transport.Directory()) / L"result.json");
    }
    StopCheck(pid);
    draft.Discard(); Check(!draft.Editing() && !draft.Dirty(), "page teardown discards draft; transport kills only its child");
  }
  for (int which = 0; which < 6; ++which) {
    request = draft.BeginEdit(Request());
    EditorSessionTransport transport(root.wstring()); auto launch = Launch(L"apply");
    if (which == 0) launch.application = (root / L"not-an-editor.exe").wstring();
    if (which == 1) launch.arguments.emplace_back(32768, L'x');
    if (which == 2) request["ownerHwnd"] = "0";
    if (which == 3) request["extra"] = std::string(VE_CORE_JSON_LIMIT, 'x');
    if (which == 4) launch.application = (root / L"not-executable.exe").wstring();
    if (which == 5) launch.arguments.emplace_back(L"embedded\0NUL", 12);
    Check(Rejects([&] { transport.Start(request, launch); }) && !transport.Active(),
      "bad executable/argv/request/size refuses startup");
    Check(transport.Directory().empty() || !fs::exists(transport.Directory()), "prelaunch failure leaves no owned session files");
    Check(draft.FinishEdit(nullptr, 1).disposition == EditDisposition::cancelled && !draft.Dirty(),
      "caller cancels failed-launch transaction without modifying template");
  }
  // Root and any teardown diagnostic directory intentionally remain under ignored
  // build output. The transport must never sweep its caller's supplied root.
  Check(fs::is_directory(root) && fs::exists(root / L"alias-target.json"), "supplied root and unrelated files never deleted");
  DWORD handlesAfter = 0;
  const auto counted = GetProcessHandleCount(GetCurrentProcess(), &handlesAfter);
  if (!counted || handlesAfter != handlesBefore)
    printf("Parent handle diagnostic: before=%lu after=%lu counted=%d\n", handlesBefore, handlesAfter, counted);
  Check(counted && handlesAfter == handlesBefore,
    "success/crash/cancel/teardown/launch-failure paths balance process/job/thread/directory handles");
}
}
int wmain(int argc, wchar_t** argv) {
  try {
    if (argc >= 2 && std::wstring(argv[1]) == L"--descendant") { Sleep(60000); return 0; }
    if (argc >= 2 && std::wstring(argv[1]) == L"--fake-editor") return FakeEditor(argc, argv);
    if (argc != 3) throw std::runtime_error("Pass fixture and isolated existing test root.");
    Run(fs::absolute(argv[2]).lexically_normal(), Read(argv[1]).at("fixtures")[0].at("recipe"));
    printf("B6 OFFLINE EDITOR TRANSPORT PASSED: %d checks; real Windows files/processes, fake children, no VEGAS/app/UI\n", checks);
    return 0;
  } catch (const std::exception& error) {
    printf("B6 TRANSPORT FAILED after %d checks: %s\n", checks, error.what()); return 1;
  }
}
