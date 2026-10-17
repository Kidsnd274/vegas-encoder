#include "job_store.h"
#include "../support/diagnostics.h"
#include <bcrypt.h>
#include <algorithm>
#include <atomic>
#include <cctype>
#include <condition_variable>
#include <deque>
#include <filesystem>
#include <mutex>

namespace vegas_encoder {
namespace {
constexpr ULONGLONG kStatusIntervalMs = 200;
struct File {
  HANDLE h = INVALID_HANDLE_VALUE;
  ~File() { if (h != INVALID_HANDLE_VALUE) CloseHandle(h); }
};
void Check(bool ok, const char* message) { if (!ok) throw std::runtime_error(message); }
void Write(HANDLE file, const std::string& bytes) {
  size_t offset = 0;
  while (offset < bytes.size()) {
    DWORD count = 0;
    Check(WriteFile(file, bytes.data() + offset, static_cast<DWORD>((std::min)(bytes.size() - offset, size_t(65536))), &count, nullptr) && count, "job file write failed");
    offset += count;
  }
}
void Atomic(const std::wstring& path, const ve::Json& data) {
  const auto bytes = data.dump();
  Check(bytes.size() <= VE_CORE_JSON_LIMIT, "job JSON exceeds 1 MiB");
  const auto temp = path + L"." + Widen(NewJobId()) + L".tmp";
  try {
    { File file; file.h = CreateFileW(temp.c_str(), GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_DELETE, nullptr, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, nullptr);
      Check(file.h != INVALID_HANDLE_VALUE, "cannot create job temporary file"); Write(file.h, bytes);
      Check(FlushFileBuffers(file.h) != FALSE, "cannot flush job file"); }
    // Never retry a sharing violation for live files on Render; all retries here
    // belong to this independent writer and are bounded to 500 ms.
    const auto started = GetTickCount64();
    while (!MoveFileExW(temp.c_str(), path.c_str(), MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH)) {
      const DWORD error = GetLastError();
      Check((error == ERROR_SHARING_VIOLATION || error == ERROR_ACCESS_DENIED) && GetTickCount64() - started < 500, "cannot replace job file");
      Sleep(10);
    }
  } catch (...) { DeleteFileW(temp.c_str()); throw; }
}
void Index(const std::wstring& root, const ve::Json& record) {
  const auto path = root + L"\\jobs.jsonl";
  File lock;
  lock.h = CreateFileW((path + L".lock").c_str(), GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE,
                      nullptr, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
  Check(lock.h != INVALID_HANDLE_VALUE, "cannot open job index lock");
  OVERLAPPED overlap{}; const auto started = GetTickCount64();
  while (!LockFileEx(lock.h, LOCKFILE_EXCLUSIVE_LOCK | LOCKFILE_FAIL_IMMEDIATELY, 0, 1, 0, &overlap)) {
    Check(GetLastError() == ERROR_LOCK_VIOLATION && GetTickCount64() - started < 2000, "job index lock is busy"); Sleep(10);
  }
  // Same byte [0,1) and lock basename as Dart FileJobRepository.rebuildIndex().
  ve::Json entry{{"index",1},{"id",record.at("id")},{"recordFile",ve::Str(record,"id") + ".json"}};
  for (const auto* key : {"startedAt","status","templateName","outputPath","encoderSummary","project","durationSec","elapsedSec","sizeBytes","realtime"}) entry[key] = record.at(key);
  File file;
  file.h = CreateFileW(path.c_str(), GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_DELETE, nullptr, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
  Check(file.h != INVALID_HANDLE_VALUE, "cannot open job index");
  LARGE_INTEGER end{}; Check(GetFileSizeEx(file.h, &end) != FALSE, "cannot read index size");
  // A prior crashed append is discarded before a new complete line is appended.
  // Scan backwards in bounded blocks, not a potentially huge allocation.
  char block[4096]; LONGLONG cursor = end.QuadPart; bool found = cursor == 0;
  while (cursor > 0 && !found) {
    const auto start = (std::max)(LONGLONG(0), cursor - LONGLONG(sizeof(block)));
    LARGE_INTEGER pos{}; pos.QuadPart = start; Check(SetFilePointerEx(file.h, pos, nullptr, FILE_BEGIN) != FALSE, "cannot seek index");
    DWORD got = 0; Check(ReadFile(file.h, block, static_cast<DWORD>(cursor - start), &got, nullptr) && got == cursor - start, "cannot read index tail");
    for (DWORD i = got; i > 0; --i) if (block[i-1] == '\n') { end.QuadPart = start + i; found = true; break; }
    cursor = start;
  }
  if (!found) end.QuadPart = 0;
  Check(SetFilePointerEx(file.h, end, nullptr, FILE_BEGIN) && SetEndOfFile(file.h), "cannot repair interrupted index tail");
  Write(file.h, entry.dump() + "\n"); Check(FlushFileBuffers(file.h) != FALSE, "cannot flush index");
}
} // namespace
std::string JobUtcNow() {
  SYSTEMTIME t{}; GetSystemTime(&t); char text[40];
  snprintf(text, sizeof(text), "%04u-%02u-%02uT%02u:%02u:%02u.%03uZ", t.wYear,t.wMonth,t.wDay,t.wHour,t.wMinute,t.wSecond,t.wMilliseconds);
  return text;
}
std::string NewJobId() {
  GUID id{}; Check(SUCCEEDED(CoCreateGuid(&id)), "cannot create job ID");
  auto text = GuidText(id); text.erase(std::remove(text.begin(), text.end(), '{'), text.end());
  text.erase(std::remove(text.begin(), text.end(), '}'), text.end()); return text;
}
std::string RecipeHash(const ve::Json& recipe) {
  const auto bytes = ve::Canonical(recipe); BYTE hash[32]{};
  Check(BCryptHash(BCRYPT_SHA256_ALG_HANDLE, nullptr, 0, reinterpret_cast<PUCHAR>(const_cast<char*>(bytes.data())),
                   static_cast<ULONG>(bytes.size()), hash, sizeof(hash)) >= 0, "cannot hash recipe");
  return HexBytes(hash, sizeof(hash));
}
struct JobStore::State {
  std::wstring root; std::string id;
  std::wstring monitorApplication;
  mutable std::mutex mutex; std::condition_variable changed;
  std::deque<ve::Json> phases; ve::Json latest = nullptr, record = nullptr;
  bool closing = false; std::atomic<bool> completed{false}; std::string failure;
  HMODULE module = nullptr;
};
std::shared_ptr<JobStore> JobStore::Create(const std::wstring& root, const std::string& id, const std::wstring& monitorApplication) {
  Check(std::filesystem::path(root).is_absolute() && root.find(L'\0') == std::wstring::npos, "job root must be an absolute path");
  Check(id.size() == 36, "job ID must be a generated UUID");
  for (size_t i = 0; i < id.size(); ++i) {
    const bool separator = i == 8 || i == 13 || i == 18 || i == 23;
    Check(separator ? id[i] == '-' : std::isxdigit(static_cast<unsigned char>(id[i])) != 0, "unsafe job ID");
  }
  auto state = std::make_shared<State>(); state->root = root; state->id = id;
  state->monitorApplication = monitorApplication;
  Check(GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS,
    reinterpret_cast<LPCWSTR>(&Worker), &state->module) != FALSE, "cannot retain job writer module");
  auto* context = new std::shared_ptr<State>(state);
  HANDLE worker = CreateThread(nullptr, 0, Worker, context, 0, nullptr);
  if (!worker) { delete context; FreeLibrary(state->module); throw std::runtime_error("cannot start job writer"); }
  CloseHandle(worker);
  return std::shared_ptr<JobStore>(new JobStore(std::move(state)));
}
JobStore::~JobStore() { std::lock_guard<std::mutex> lock(state_->mutex); state_->closing = true; state_->changed.notify_all(); }
void JobStore::Status(ve::Json snapshot, bool phase) {
  std::lock_guard<std::mutex> lock(state_->mutex);
  if (state_->closing) return;
  if (phase) { if (state_->phases.size() < 16) state_->phases.push_back(std::move(snapshot)); state_->latest = nullptr; }
  else state_->latest = std::move(snapshot);
  state_->changed.notify_all();
}
void JobStore::Complete(ve::Json snapshot, ve::Json record) {
  std::lock_guard<std::mutex> lock(state_->mutex);
  state_->latest = nullptr; state_->phases.push_back(std::move(snapshot)); state_->record = std::move(record);
  state_->closing = true; state_->changed.notify_all();
}
bool JobStore::Completed() const { return state_->completed; }
std::string JobStore::Failure() const { std::lock_guard<std::mutex> lock(state_->mutex); return state_->failure; }
DWORD WINAPI JobStore::Worker(void* context) {
  auto state = *static_cast<std::shared_ptr<State>*>(context); delete static_cast<std::shared_ptr<State>*>(context);
  ULONGLONG last = 0;
  bool monitorAttempted = false;
  auto report = [&](const std::exception& error) { std::lock_guard<std::mutex> lock(state->mutex); state->failure = error.what(); Log("job publication nonfatal: %s", error.what()); };
  for (;;) {
    ve::Json status = nullptr, record = nullptr;
    { std::unique_lock<std::mutex> lock(state->mutex);
      // Wake for the first pending sample when the 5 Hz budget is free. Wait
      // only for the remaining budget, so idle gaps add no extra interval.
      for (;;) {
        if (state->closing || !state->phases.empty()) break;
        if (state->latest.is_null()) {
          state->changed.wait(lock,[&] { return state->closing || !state->phases.empty() || !state->latest.is_null(); });
        } else {
          const auto now = GetTickCount64();
          if (now - last >= kStatusIntervalMs) break;
          state->changed.wait_for(lock,std::chrono::milliseconds(kStatusIntervalMs - (now - last)),
            [&] { return state->closing || !state->phases.empty(); });
        }
      }
      if (!state->phases.empty()) { status = std::move(state->phases.front()); state->phases.pop_front(); }
      else if (!state->latest.is_null() && GetTickCount64() - last >= kStatusIntervalMs) { status = std::move(state->latest); state->latest = nullptr; }
      if (state->closing && state->phases.empty()) record = state->record;
      if (state->closing && status.is_null() && record.is_null()) break;
    }
    if (!status.is_null()) try {
      std::filesystem::create_directories(state->root);
      Atomic(state->root + L"\\" + Widen(state->id) + L".live.json", status); last = GetTickCount64();
      if (!monitorAttempted && !state->monitorApplication.empty()) {
        monitorAttempted = true;
        // Windows app creation happens only on this independent writer, after
        // initial C5 publication. No wait, acknowledgement or host call.
        const auto& application = state->monitorApplication;
        if (std::filesystem::path(application).is_absolute() && application.find(L'\0') == std::wstring::npos) {
          auto command = Widen(ve::Quote(Utf8(application.c_str())) + " --render-monitor " +
            ve::Quote(Utf8((state->root + L"\\" + Widen(state->id) + L".live.json").c_str())));
          STARTUPINFOW startup{}; startup.cb = sizeof(startup); startup.dwFlags = STARTF_USESHOWWINDOW; startup.wShowWindow = SW_SHOWNOACTIVATE;
          PROCESS_INFORMATION process{};
          if (command.size() < 32767 && CreateProcessW(application.c_str(),command.data(),nullptr,nullptr,FALSE,CREATE_NO_WINDOW,nullptr,
              std::filesystem::path(application).parent_path().c_str(),&startup,&process)) {
            CloseHandle(process.hThread); CloseHandle(process.hProcess);
          } else Log("monitor launch failed (nonfatal): %lu",GetLastError());
        } else Log("monitor launch path is invalid (nonfatal)");
      }
    } catch (const std::exception& error) { report(error); }
    if (!record.is_null()) {
      try { std::filesystem::create_directories(state->root); Atomic(state->root + L"\\" + Widen(state->id) + L".json", record); Index(state->root, record); }
      catch (const std::exception& error) { report(error); }
      break;
    }
  }
  const HMODULE module = state->module; state->completed = true; state.reset();
  // No native instructions are executed after releasing a DLL lifetime reference.
  if (module != GetModuleHandleW(nullptr)) FreeLibraryAndExitThread(module, 0);
  FreeLibrary(module); return 0;
}
} // namespace vegas_encoder
