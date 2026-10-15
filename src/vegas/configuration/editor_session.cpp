#include "editor_session.h"
#include "../../support/diagnostics.h"
#include "../../support/native_boundary.h"
#include <algorithm>
#include <filesystem>

namespace vegas_encoder::configuration {
namespace {
namespace fs = std::filesystem;
struct Handle {
  HANDLE h = INVALID_HANDLE_VALUE;
  Handle() = default;
  explicit Handle(HANDLE value) : h(value) {}
  ~Handle() { Close(); }
  Handle(const Handle&) = delete;
  Handle& operator=(const Handle&) = delete;
  Handle(Handle&& other) noexcept : h(other.h) { other.h = INVALID_HANDLE_VALUE; }
  void Close() noexcept { if (h && h != INVALID_HANDLE_VALUE) CloseHandle(h); h = INVALID_HANDLE_VALUE; }
};
void Require(bool value, const char* message) { if (!value) throw std::runtime_error(message); }
std::wstring LocalAbsolute(const std::wstring& value) {
  Require(value.size() >= 3 && value.find(L'\0') == std::wstring::npos &&
    ((value[0] >= L'A' && value[0] <= L'Z') || (value[0] >= L'a' && value[0] <= L'z')) &&
    value[1] == L':' && (value[2] == L'\\' || value[2] == L'/'),
    "Editor transport requires an absolute local drive path.");
  const auto path = fs::path(value).lexically_normal();
  Require(path.is_absolute(), "Editor transport path is not absolute.");
  return path.wstring();
}
Handle PinDirectory(const fs::path& path) {
  // Directory-list access participates in Windows read/delete sharing checks;
  // an attributes-only handle can still permit a rename on this filesystem.
  Handle handle(CreateFileW(path.c_str(), FILE_LIST_DIRECTORY | FILE_READ_ATTRIBUTES, FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr,
    OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT, nullptr));
  BY_HANDLE_FILE_INFORMATION info{};
  Require(handle.h != INVALID_HANDLE_VALUE && GetFileInformationByHandle(handle.h, &info) &&
    (info.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) && !(info.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT),
    "Session directories must exist and must not be reparse points.");
  return handle;
}
std::vector<Handle> PinAncestors(const fs::path& path) {
  std::vector<Handle> handles;
  auto current = path.root_path();
  handles.push_back(PinDirectory(current));
  for (const auto& part : path.relative_path()) {
    if (part.empty() || part == L".") continue;
    current /= part;
    handles.push_back(PinDirectory(current));
  }
  return handles;
}
// Same authored CRT argv quoting used by the engine. An explicit application
// path and FALSE handle inheritance prevent shell parsing/host handle leakage.
std::wstring Quote(const std::wstring& value) {
  Require(value.find(L'\0') == std::wstring::npos, "NUL in editor argument.");
  std::wstring quoted = L"\"";
  size_t slashes = 0;
  for (wchar_t c : value) {
    if (c == L'\\') { ++slashes; continue; }
    quoted.append(slashes * (c == L'"' ? 2 : 1), L'\\');
    slashes = 0;
    if (c == L'"') quoted += L'\\';
    quoted += c;
  }
  quoted.append(2 * slashes, L'\\');
  return quoted + L'"';
}
void WriteRequest(const fs::path& directory, const std::string& bytes) {
  const auto temporary = directory / L"request.json.tmp";
  {
    Handle file(CreateFileW(temporary.c_str(), GENERIC_WRITE, 0, nullptr,
      CREATE_NEW, FILE_ATTRIBUTE_NORMAL, nullptr));
    Require(file.h != INVALID_HANDLE_VALUE, "Cannot create editor request.");
    size_t offset = 0;
    while (offset < bytes.size()) {
      DWORD count = 0;
      Require(WriteFile(file.h, bytes.data() + offset,
        static_cast<DWORD>((std::min)(bytes.size() - offset, size_t(65536))), &count, nullptr) && count,
        "Cannot write editor request.");
      offset += count;
    }
    Require(FlushFileBuffers(file.h) != FALSE, "Cannot flush editor request.");
  }
  if (!MoveFileExW(temporary.c_str(), (directory / L"request.json").c_str(), MOVEFILE_WRITE_THROUGH))
    throw std::runtime_error("Cannot publish editor request: Windows error " + std::to_string(GetLastError()));
}
ve::Json ReadResult(const fs::path& path) {
  // No write/delete sharing while reading: one stable inode/length. Do not follow
  // result links, directories, hard-link aliases, oversized or growing files.
  Handle file(CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr,
    OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, nullptr));
  BY_HANDLE_FILE_INFORMATION info{}; LARGE_INTEGER size{};
  Require(file.h != INVALID_HANDLE_VALUE && GetFileType(file.h) == FILE_TYPE_DISK &&
    GetFileInformationByHandle(file.h, &info) &&
    !(info.dwFileAttributes & (FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT)) && info.nNumberOfLinks == 1 &&
    GetFileSizeEx(file.h, &size) && size.QuadPart > 0 && size.QuadPart <= VE_CORE_JSON_LIMIT,
    "Missing, linked, busy or oversized editor result.");
  std::vector<uint8_t> bytes(static_cast<size_t>(size.QuadPart));
  size_t offset = 0;
  while (offset < bytes.size()) {
    DWORD count = 0;
    Require(ReadFile(file.h, bytes.data() + offset,
      static_cast<DWORD>((std::min)(bytes.size() - offset, size_t(65536))), &count, nullptr) && count,
      "Incomplete editor result.");
    offset += count;
  }
  return ve::Parse(bytes.data(), bytes.size());
}
bool KnownFile(const std::wstring& name) {
  return name == L"request.json" || name == L"request.json.tmp" || name == L"result.json" || name == L".result.lock" ||
    (name.size() > 16 && name.compare(0, 12, L"result.json.") == 0 && name.compare(name.size() - 4, 4, L".tmp") == 0);
}
}

std::string NewEditSessionId() {
  GUID id{}; Require(SUCCEEDED(CoCreateGuid(&id)), "Cannot create editor session ID.");
  auto text = GuidText(id);
  text.erase(std::remove(text.begin(), text.end(), '{'), text.end());
  text.erase(std::remove(text.begin(), text.end(), '}'), text.end());
  return text;
}

struct EditorSessionTransport::Impl {
  DWORD caller = GetCurrentThreadId(), pid = 0;
  fs::path root, directory;
  std::vector<Handle> ancestors;
  Handle directoryPin, process, job;
  std::string sessionId;
  bool attempted = false, active = false, cancelled = false;
  explicit Impl(const std::wstring& path) : root(LocalAbsolute(path)), ancestors(PinAncestors(root)) {}
  void RequireCaller() const {
    if (GetCurrentThreadId() != caller) throw std::logic_error("Editor transport must stay on its creator UI thread.");
  }
  bool Cleanup() noexcept {
    if (directory.empty()) return true;
    try {
      // Only direct known protocol files in our fresh, pinned directory. Never
      // recurse, follow links, remove an unknown child or remove the supplied root.
      if (directoryPin.h == INVALID_HANDLE_VALUE) return false;
      size_t entries = 0;
      for (const auto& entry : fs::directory_iterator(directory)) {
        if (++entries > 64) return false;
        const auto attributes = GetFileAttributesW(entry.path().c_str());
        if (attributes == INVALID_FILE_ATTRIBUTES ||
            (attributes & (FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT)) ||
            !KnownFile(entry.path().filename().wstring())) continue;
        DeleteFileW(entry.path().c_str()); // Failure retains the directory, with a diagnostic.
      }
      directoryPin.Close();
      return RemoveDirectoryW(directory.c_str()) != FALSE;
    } catch (...) { return false; }
  }
  ~Impl() {
    if (active) {
      if (job.h != INVALID_HANDLE_VALUE) TerminateJobObject(job.h, 1);
      job.Close();
      // Destruction cannot block a caller. A still-running child may retain its
      // files; keep that session for diagnosis rather than deleting underneath it.
      if (process.h != INVALID_HANDLE_VALUE && WaitForSingleObject(process.h, 0) != WAIT_OBJECT_0) return;
    }
    (void)Cleanup();
  }
};

EditorSessionTransport::EditorSessionTransport(const std::wstring& root) : impl_(std::make_unique<Impl>(root)) {}
EditorSessionTransport::~EditorSessionTransport() = default;
bool EditorSessionTransport::Active() const { impl_->RequireCaller(); return impl_->active; }
std::wstring EditorSessionTransport::Directory() const { impl_->RequireCaller(); return impl_->directory.wstring(); }
DWORD EditorSessionTransport::ProcessId() const { impl_->RequireCaller(); return impl_->pid; }
void EditorSessionTransport::Start(const ve::Json& request, const EditorLaunch& launch) {
  const auto started = NowMs();
  auto& p = *impl_; p.RequireCaller();
  Require(!p.attempted, "Editor transport permits one launch only.");
  p.attempted = true;
  const auto bytes = ve::Canonical(request);
  Require(bytes.size() <= VE_CORE_JSON_LIMIT && !ve::HasErrors(ve::SessionRequest(request).at("issues")),
    "Invalid or oversized editor request.");
  p.sessionId = ve::Str(request, "sessionId");
  const auto application = LocalAbsolute(launch.application);
  auto applicationAncestors = PinAncestors(fs::path(application).parent_path());
  const auto attributes = GetFileAttributesW(application.c_str());
  Require(attributes != INVALID_FILE_ATTRIBUTES && !(attributes & (FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT)),
    "Editor executable is missing or linked.");
  p.directory = p.root / Widen(NewEditSessionId());
  Require(CreateDirectoryW(p.directory.c_str(), nullptr) != FALSE, "Cannot create fresh editor session directory.");
  // Inherit the existing per-user root ACL. No process-global/local-app-data path
  // is selected here; production root creation/ACL policy belongs to the bridge.
  try {
    auto pin = PinDirectory(p.directory); p.directoryPin.h = pin.h; pin.h = INVALID_HANDLE_VALUE;
    WriteRequest(p.directory, bytes);
    const auto prepared = NowMs();
    std::wstring command = Quote(application);
    for (const auto& argument : launch.arguments) command += L" " + Quote(argument);
    command += L" --edit-session " + Quote(p.directory.wstring());
    Require(command.size() < 32767, "Editor command exceeds the Windows argv limit.");
    p.job.h = CreateJobObjectW(nullptr, nullptr);
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits{};
    limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
    Require(p.job.h && SetInformationJobObject(p.job.h, JobObjectExtendedLimitInformation, &limits, sizeof(limits)),
      "Cannot create editor ownership job.");
    STARTUPINFOW startup{}; startup.cb = sizeof(startup);
    PROCESS_INFORMATION info{};
    Require(CreateProcessW(application.c_str(), command.data(), nullptr, nullptr, FALSE,
      CREATE_SUSPENDED | CREATE_NO_WINDOW, nullptr, fs::path(application).parent_path().c_str(), &startup, &info) != FALSE,
      "Cannot start editor helper.");
    p.process.h = info.hProcess; p.pid = info.dwProcessId;
    Handle thread(info.hThread);
    if (!AssignProcessToJobObject(p.job.h, p.process.h) || ResumeThread(thread.h) == DWORD(-1)) {
      // An unassigned suspended child is ours too, and has executed no user code.
      TerminateProcess(p.process.h, 1);
      throw std::runtime_error("Cannot own/resume editor helper.");
    }
    p.active = true;
    BestEffortDiagnostic([&] { Log("B6 editor transport: files/validation=%.1f ms spawn=%.1f ms",prepared-started,NowMs()-prepared); });
  } catch (...) {
    p.job.Close();
    (void)p.Cleanup();
    throw;
  }
}
void EditorSessionTransport::Cancel() {
  auto& p = *impl_; p.RequireCaller();
  if (!p.active || p.cancelled) return;
  p.cancelled = true;
  Require(TerminateJobObject(p.job.h, 1) != FALSE, "Cannot terminate owned editor job.");
}
std::optional<EditorExit> EditorSessionTransport::Poll() {
  auto& p = *impl_; p.RequireCaller();
  if (!p.active) return std::nullopt;
  const auto wait = WaitForSingleObject(p.process.h, 0);
  if (wait == WAIT_TIMEOUT) return std::nullopt;
  Require(wait == WAIT_OBJECT_0, "Cannot poll editor lifetime.");
  EditorExit exit;
  Require(GetExitCodeProcess(p.process.h, &exit.exitCode) != FALSE, "Cannot read editor exit code.");
  p.active = false;
  p.job.Close(); // Any remaining descendants are owned and terminated, not detached.
  if (p.cancelled) { exit.exitCode = 1; exit.diagnostic = "Editor session cancelled; result discarded."; }
  else if (exit.exitCode != 0) exit.diagnostic = "Editor exited unsuccessfully; result discarded.";
  else {
    try {
      auto result = ReadResult(p.directory / L"result.json");
      Require(!ve::HasErrors(ve::SessionResult(result).at("issues")) && ve::Str(result, "sessionId") == p.sessionId,
        "Invalid or mismatched editor result.");
      exit.result.swap(result);
    } catch (const std::exception& error) { exit.diagnostic = error.what(); }
  }
  p.process.Close();
  exit.cleanupComplete = p.Cleanup();
  if (!exit.cleanupComplete) exit.diagnostic += " Session cleanup incomplete; directory retained.";
  return exit;
}
} // namespace vegas_encoder::configuration
