#include "../support/diagnostics.h"
#include "encode.h"

#include <atomic>
#include <algorithm>
#include <chrono>
#include <cmath>
#include <condition_variable>
#include <cstring>
#include <deque>
#include <filesystem>
#include <limits>
#include <mutex>
#include <thread>

namespace vegas_encoder {
namespace {
struct Handle {
  HANDLE h = nullptr;
  ~Handle() { Close(); }
  void Close() {
    if (h && h != INVALID_HANDLE_VALUE) CloseHandle(h);
    h = nullptr;
  }
  bool Valid() const { return h && h != INVALID_HANDLE_VALUE; }
};
// Volume serial, file index, size and last write time: "still the same file".
struct FileIdentity {
  DWORD volume = 0; uint64_t index = 0, size = 0, written = 0;
  bool operator==(const FileIdentity& o) const { return volume == o.volume && index == o.index && size == o.size && written == o.written; }
};
bool ReadIdentity(const std::wstring& path, FileIdentity& identity) {
  Handle file;
  file.h = CreateFileW(path.c_str(), FILE_READ_ATTRIBUTES, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr,
                       OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
  BY_HANDLE_FILE_INFORMATION info{};
  if (!file.Valid() || !GetFileInformationByHandle(file.h, &info)) return false;
  identity.volume = info.dwVolumeSerialNumber;
  identity.index = (uint64_t(info.nFileIndexHigh) << 32) | info.nFileIndexLow;
  identity.size = (uint64_t(info.nFileSizeHigh) << 32) | info.nFileSizeLow;
  identity.written = (uint64_t(info.ftLastWriteTime.dwHighDateTime) << 32) | info.ftLastWriteTime.dwLowDateTime;
  return true;
}

// Windows CRT argv quoting; CreateProcessW receives an explicit application path.
std::wstring Quote(const std::wstring& value) {
  std::wstring s = L"\"";
  size_t slashes = 0;
  for (wchar_t c : value) {
    if (c == L'\\') { slashes++; continue; }
    s.append(slashes * (c == L'"' ? 2 : 1), L'\\');
    slashes = 0;
    if (c == L'"') s += L'\\';
    s += c;
  }
  s.append(2 * slashes, L'\\');
  return s + L'"';
}
}  // namespace

bool FatalFfmpegDiagnostic(const std::string& line) {
  // FFmpeg 4.4-8.x wording. After these FFmpeg only shuts down, but on Windows its
  // shutdown can wait forever on a demuxer blocked in a named-pipe read.
  for (const char* marker : {"Error while opening encoder", "Could not open encoder before EOF", "Error initializing output stream",
                             "Error opening output file", "Task finished with error", "Conversion failed!"})
    if (line.find(marker) != std::string::npos) return line.find("End of file") == std::string::npos;
  return false;
}

BOOL CreateProcessPolled(const std::function<BOOL()>& create, const std::function<bool()>& poll, bool& interrupted) {
  if (!poll) return create();
  std::atomic<bool> done{false}; BOOL result = FALSE;
  std::thread launcher([&] { result = create(); done.store(true,std::memory_order_release); });
  while (!done.load(std::memory_order_acquire)) {
    try { if (!poll()) interrupted = true; } catch (...) { interrupted = true; }
    Sleep(20);
  }
  launcher.join(); return result;
}

EncodeRate EncodeRate::FromDouble(double fps) {
  if (!std::isfinite(fps) || fps <= 0) return {};
  // Exact matches only: n/1 (1..240), n/2 (half rates such as 12.5), and k*1000/1001 (k <= 240).
  for (DWORD k = 1; k <= 240; ++k)
    if (std::abs(fps - k * 1000.0 / 1001) < 1e-8) return {k * 1000, 1001};
  const double nearest = std::round(fps);
  if (nearest >= 1 && nearest <= 240 && std::abs(fps - nearest) < 1e-8) return {(DWORD)nearest, 1};
  const double half = std::round(fps * 2);
  if (half >= 1 && half <= 480 && std::abs(fps * 2 - half) < 1e-8) return {(DWORD)half, 2};
  return {};  // Refuse an unqualified rate instead of rounding it.
}
bool EncodeRate::Endpoint(LONGLONG frames, DWORD sampleRate, LONGLONG& samples) const {
  if (!num || !den || !sampleRate || frames < 0) return false;
  uint64_t scale = (uint64_t)sampleRate * den;
  uint64_t limit = (uint64_t)(std::numeric_limits<LONGLONG>::max)();
  if ((uint64_t)frames > (limit - num / 2) / scale) return false;
  samples = (LONGLONG)(((uint64_t)frames * scale + num / 2) / num);
  return true;
}
std::wstring EncodeRate::Text() const { return std::to_wstring(num) + L"/" + std::to_wstring(den); }

struct FfmpegEncoder::Impl {
  struct Pipe {
    Handle handle;
    std::mutex mutex;
    std::condition_variable changed;
    std::deque<std::vector<BYTE>> queue;
    std::thread worker;
    std::atomic<bool> done{false};
    bool eof = false;
    size_t bytes = 0, blocks = 0, limit = 0;
    uint64_t highWater = 0, written = 0;
  };
  Pipe pipes[2];
  Handle process, job, progressRead;
  std::thread progressWorker;
  std::atomic<bool> stopping{false}, failed{false};
  mutable std::mutex errorMutex;
  HRESULT error = S_OK;
  std::string reason;
  EncodeStats stats;
  std::wstring output;
  DWORD stallTimeout = 120000, connectTimeout = 30000;
  uint64_t audioBytesPerSecond = 48000 * 2 * 4;
  std::atomic<bool> endedEarly{false};
  // Last proof that FFmpeg is working: an input write completed, or frame/out_time_us/total_size advanced.
  std::atomic<ULONGLONG> activity{0};
  // FFmpeg printed a fatal diagnostic: the writers close both inputs so it can exit.
  std::atomic<bool> fatalSeen{false};
  std::thread stderrWorker;
  static constexpr DWORD fatalExitMs = 5000;
  std::atomic<long long> lastFrame{-1};
  std::atomic<uint64_t> videoBuffersAllocated{0};
  bool replaceExisting = false, hadExisting = false;
  FileIdentity existing;
  // Finished input buffers come back here (bounded: queue depth + 2); ownership moves only.
  std::mutex poolMutex;
  std::vector<std::vector<BYTE>> pool[2];
  void Recycle(size_t index, std::vector<BYTE>&& buffer) {
    std::lock_guard<std::mutex> lock(poolMutex);
    if (pool[index].size() < (index ? 8u : 10u)) pool[index].push_back(std::move(buffer));
  }
  bool withAudio = false, tempOwned = false, finished = false, started = false;

  // Size the audio queue by time, not by block count: an encoder's lookahead can
  // hold back audio reads for seconds while it consumes video (the AV1 "stall").
  size_t AudioLimit() const {
    return (size_t)(std::min)((std::max)(audioBytesPerSecond * 60, (uint64_t)2 * 1024 * 1024), (uint64_t)192 * 1024 * 1024);
  }
  void Active() { activity = GetTickCount64(); }
  bool Stalled() const { return GetTickCount64() - activity.load() > stallTimeout; }
  std::string StallMessage() const {
    auto text = "FFmpeg stopped making progress for " + std::to_string((stallTimeout + 500) / 1000) + " s";
    if (lastFrame >= 0) text += " (last frame " + std::to_string(lastFrame.load()) + ")";
    return text + ".";
  }
  void Observe(const char* bytes, size_t count, std::string& line, long long (&seen)[3]) {
    static const char* keys[] = {"frame=", "out_time_us=", "total_size="};
    for (size_t i = 0; i < count; ++i) {
      if (bytes[i] != '\n') { if (line.size() < 128) line += bytes[i]; continue; }
      for (int k = 0; k < 3; ++k) if (line.rfind(keys[k], 0) == 0) {
        const long long value = _strtoi64(line.c_str() + strlen(keys[k]), nullptr, 10);
        if (value > seen[k]) { seen[k] = value; Active(); if (k == 0) lastFrame = value; }
      }
      line.clear();
    }
  }
  // Follows the stderr log while FFmpeg runs. After a fatal diagnostic FFmpeg only shuts
  // down, but on Windows a demuxer blocked in a named-pipe read keeps it alive, so it
  // never exits. Closing our end of both pipes (EOF) lets FFmpeg exit with its own exit
  // code, which fails the encode through the normal exit path; the log keeps the full
  // text for the message. FFmpeg still running fatalExitMs later is failed here.
  void WatchStderr() {
    Handle file;
    file.h = CreateFileW(stats.stderrPath.c_str(), GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                         nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (!file.Valid()) { Log("FFmpeg stderr watcher unavailable: %lu", GetLastError()); return; }
    std::string line, fatal; ULONGLONG fatalAt = 0; char bytes[4096]; DWORD count = 0;
    while (!stopping && !failed && !Exited()) {
      while (fatal.empty() && ReadFile(file.h, bytes, sizeof(bytes), &count, nullptr) && count) {
        for (DWORD i = 0; i < count && fatal.empty(); ++i) {
          if (bytes[i] != '\r' && bytes[i] != '\n') { if (line.size() < 4096) line += bytes[i]; continue; }
          if (FatalFfmpegDiagnostic(line)) { fatal = line; fatalAt = GetTickCount64(); }
          line.clear();
        }
      }
      if (!fatal.empty() && !fatalSeen) {
        Log("FFmpeg reported a fatal error; closing its inputs so it can exit: %s", fatal.c_str());
        fatalSeen = true;
        for (auto& pipe : pipes) pipe.changed.notify_all();
      }
      if (fatalSeen && GetTickCount64() - fatalAt >= fatalExitMs && !Exited() && !stopping) {
        Fail(E_FAIL, "FFmpeg reported a fatal error and did not exit.");
        return;
      }
      Sleep(50);
    }
  }

  void Fail(HRESULT hr, const char* why) {
    {
      std::lock_guard<std::mutex> lock(errorMutex);
      if (FAILED(error)) return;
      error = FAILED(hr) ? hr : E_FAIL;
      reason = why;
      failed = true;
    }
    for (auto& pipe : pipes) pipe.changed.notify_all();
  }
  bool Exited() const { return process.Valid() && WaitForSingleObject(process.h, 0) == WAIT_OBJECT_0; }
  static bool ClosedPipe(DWORD code) { return code == ERROR_NO_DATA || code == ERROR_BROKEN_PIPE || code == ERROR_PIPE_NOT_CONNECTED; }
  // FFmpeg stopped reading its input. Exit code 0 means an option (for example -t)
  // finished the output early (decision D4); anything else is a failure.
  void InputClosed() {
    if (stopping || failed || endedEarly) return;
    while (!Exited() && !Stalled() && !stopping && !failed) Sleep(10);
    if (stopping || failed) return;
    if (!Exited()) { Fail(E_FAIL, StallMessage().c_str()); return; }
    DWORD code = STILL_ACTIVE;
    GetExitCodeProcess(process.h, &code);
    if (code != 0) { Fail(E_FAIL, "FFmpeg exited before input EOF"); return; }
    if (fatalSeen) { Fail(E_FAIL, "FFmpeg reported a fatal error."); return; }
    endedEarly = true;
    for (auto& pipe : pipes) pipe.changed.notify_all();
  }

  bool Complete(Pipe& pipe, OVERLAPPED& ov, DWORD& count, bool connecting = false) {
    ULONGLONG start = GetTickCount64();
    for (;;) {
      DWORD wait = WaitForSingleObject(ov.hEvent, 100);
      if (wait == WAIT_OBJECT_0) {
        if (GetOverlappedResult(pipe.handle.h, &ov, &count, FALSE)) return true;
        const DWORD code = GetLastError();
        if (ClosedPipe(code)) InputClosed();
        else if (!stopping && !failed && !endedEarly && !fatalSeen) Fail(HRESULT_FROM_WIN32(code), "named pipe I/O failed");
        return false;
      }
      const bool exited = Exited();
      const bool late = connecting ? GetTickCount64() - start > connectTimeout : Stalled();
      if (wait == WAIT_FAILED || stopping || failed || endedEarly || fatalSeen || exited || late) {
        if (wait == WAIT_FAILED) { if (!stopping && !failed) Fail(HRESULT_FROM_WIN32(GetLastError()), "named pipe wait failed"); }
        else if (exited) InputClosed();
        else if (late && !stopping && !failed && !endedEarly && !fatalSeen)
          Fail(E_FAIL, connecting ? "FFmpeg did not open its input pipe in time" : StallMessage().c_str());
        CancelIoEx(pipe.handle.h, &ov);
        // Cancellation is a request: keep operation/buffer storage alive until completion.
        GetOverlappedResult(pipe.handle.h, &ov, &count, TRUE);
        return false;
      }
    }
  }

  void WritePipe(size_t index) {
    Pipe& pipe = pipes[index];
    try {
      Handle event;
      event.h = CreateEventW(nullptr, TRUE, FALSE, nullptr);
      if (!event.Valid()) { Fail(HRESULT_FROM_WIN32(GetLastError()), "cannot create pipe event"); }
      else {
        OVERLAPPED ov{};
        ov.hEvent = event.h;
        DWORD count = 0;
        bool connected = ConnectNamedPipe(pipe.handle.h, &ov) != FALSE;
        if (!connected) {
          DWORD code = GetLastError();
          if (code == ERROR_PIPE_CONNECTED) connected = true;
          else if (code == ERROR_IO_PENDING) connected = Complete(pipe, ov, count, true);
          else Fail(HRESULT_FROM_WIN32(code), "cannot connect FFmpeg input pipe");
        }
        while (connected && !stopping && !failed && !endedEarly && !fatalSeen) {
          std::vector<BYTE> data;
          bool closed = false;
          {
            std::unique_lock<std::mutex> lock(pipe.mutex);
            while (pipe.queue.empty() && !pipe.eof && !stopping && !failed && !endedEarly && !fatalSeen) {
              pipe.changed.wait_for(lock, std::chrono::milliseconds(100));
              if (Exited()) { closed = true; break; }
            }
            if (!closed && !stopping && !failed && !endedEarly && !fatalSeen && !(pipe.queue.empty() && pipe.eof)) {
              data = std::move(pipe.queue.front());
              pipe.queue.pop_front();  // byte/block accounting includes this in-flight buffer
            }
          }
          if (closed) { InputClosed(); break; }
          if (data.empty()) break;
          size_t offset = 0;
          while (offset < data.size() && !stopping && !failed && !endedEarly && !fatalSeen) {
            ResetEvent(event.h);
            ov = OVERLAPPED{};
            ov.hEvent = event.h;
            DWORD want = (DWORD)((std::min)(data.size() - offset, (size_t)(1u << 20)));
            count = 0;
            BOOL written = WriteFile(pipe.handle.h, data.data() + offset, want, &count, &ov);
            if (!written) {
              DWORD code = GetLastError();
              if (code == ERROR_IO_PENDING) written = Complete(pipe, ov, count);
              else if (ClosedPipe(code)) InputClosed();
              else if (!fatalSeen) Fail(HRESULT_FROM_WIN32(code), "FFmpeg input pipe write failed");
            }
            if (!written || !count || count > want) {
              if (!stopping && !failed && !endedEarly && !fatalSeen) Fail(E_FAIL, "invalid pipe write completion");
              break;
            }
            offset += count;
            pipe.written += count;
            Active();
          }
          {
            std::lock_guard<std::mutex> lock(pipe.mutex);
            pipe.bytes -= data.size();
            pipe.blocks--;
          }
          pipe.changed.notify_all();
          Recycle(index, std::move(data));
        }
      }
    } catch (...) { Fail(E_OUTOFMEMORY, "pipe writer exception"); }
    // Closing after successful writes (or after FFmpeg's fatal error) sends EOF.
    // Do not Disconnect/flush away queued data.
    pipe.handle.Close();
    pipe.done = true;
    pipe.changed.notify_all();
  }

  void Abort() {
    stopping = true;
    for (auto& pipe : pipes) pipe.changed.notify_all();
    // Terminating only the owned child also unblocks its pending pipe readers/writers.
    if (process.Valid() && !Exited()) {
      if (job.Valid()) TerminateJobObject(job.h, 1);
      else TerminateProcess(process.h, 1);
      WaitForSingleObject(process.h, 2000);
    }
    for (auto& pipe : pipes) {
      if (pipe.worker.joinable()) pipe.worker.join();
      pipe.handle.Close();
      std::lock_guard<std::mutex> lock(pipe.mutex);
      pipe.queue.clear();
      pipe.bytes = pipe.blocks = 0;
    }
    if (stderrWorker.joinable()) stderrWorker.join();
    // Closing the kill-on-close job also closes stdout inherited by descendants.
    job.Close();
    if (progressWorker.joinable()) progressWorker.join();
    progressRead.Close();
    if (process.Valid()) GetExitCodeProcess(process.h, &stats.exitCode);
    process.Close();
    job.Close();
    if (tempOwned && !stats.published) {
      if (!DeleteFileW(stats.tempPath.c_str()) && GetLastError() != ERROR_FILE_NOT_FOUND)
        Log("cannot remove partial encode %s: %lu", Utf8(stats.tempPath.c_str()).c_str(), GetLastError());
      tempOwned = false;
    }
  }
  ~Impl() { Abort(); }
};

FfmpegEncoder::FfmpegEncoder() : p_(new Impl) {}
FfmpegEncoder::~FfmpegEncoder() = default;

bool FfmpegEncoder::Start(const std::wstring& exe, const std::wstring& output, LONG width, LONG height,
                          EncodeRate rate, bool audio, DWORD stallTimeoutMs, DWORD connectTimeoutMs) {
  return StartImpl(exe, output, width, height, rate, audio, stallTimeoutMs, connectTimeoutMs, {}, {}, {}, {});
}
bool FfmpegEncoder::StartCompiled(const std::wstring& exe, const std::wstring& output,
                                 const std::wstring& log, DWORD stallTimeoutMs, DWORD connectTimeoutMs,
                                 const Compile& compile, const Progress& progress, const Poll& startupPoll) {
  if (!compile) { p_->Fail(E_INVALIDARG, "missing command compiler"); return false; }
  return StartImpl(exe, output, 0, 0, {}, true, stallTimeoutMs, connectTimeoutMs, compile, progress, log, startupPoll);
}
bool FfmpegEncoder::StartImpl(const std::wstring& exe, const std::wstring& output, LONG width, LONG height,
                              EncodeRate rate, bool audio, DWORD stallTimeoutMs, DWORD connectTimeoutMs,
                              const Compile& compile, const Progress& progress, const std::wstring& logPath, const Poll& startupPoll) {
  auto& p = *p_;
  if (p.started) { p.Fail(E_UNEXPECTED, "encoder instances are single-use"); return false; }
  p.started = true;
  p.output = output;
  p.withAudio = audio;
  p.stallTimeout = (std::max)((DWORD)100, stallTimeoutMs);
  p.connectTimeout = (std::max)((DWORD)100, connectTimeoutMs);
  if (exe.size() < 3 || exe[1] != L':' || (exe[2] != L'\\' && exe[2] != L'/')) {
    p.Fail(E_INVALIDARG, "FFmpegPath must be an absolute executable path"); return false;
  }
  if (GetFileAttributesW(output.c_str()) != INVALID_FILE_ATTRIBUTES) {
    // Decision D1: replace only a file VEGAS confirmed, and only if it is unchanged at publication.
    if (!p.replaceExisting) {
      p.Fail(HRESULT_FROM_WIN32(ERROR_FILE_EXISTS), "The destination file already exists. Choose another name."); return false;
    }
    if (!ReadIdentity(output, p.existing)) {
      p.Fail(HRESULT_FROM_WIN32(GetLastError()), "Cannot read the existing destination file."); return false;
    }
    p.hadExisting = true;
  }
  GUID id{};
  if (FAILED(CoCreateGuid(&id))) { p.Fail(E_FAIL, "cannot create encode session ID"); return false; }
  wchar_t nonce[64];
  StringFromGUID2(id, nonce, 64);
  std::wstring prefix = L"\\\\.\\pipe\\vegas-encoder-" + std::to_wstring(GetCurrentProcessId()) + nonce;
  const std::filesystem::path destination(output);
  // Treat a suffix-only basename (".mkv") consistently with core admission;
  // filesystem::extension treats that as a dotfile with no extension.
  const auto filename = destination.filename().wstring();
  const auto dot = filename.find_last_of(L'.');
  const auto stem = dot == std::wstring::npos ? filename : filename.substr(0,dot);
  const auto suffix = dot == std::wstring::npos ? std::wstring() : filename.substr(dot);
  p.stats.tempPath = (destination.parent_path() / (stem + L".ve-partial-" + nonce + suffix)).wstring();
  p.stats.stderrPath = logPath.empty() ? output + L".ffmpeg.log" : logPath;
  Handle temp;
  temp.h = CreateFileW(p.stats.tempPath.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (!temp.Valid()) { p.Fail(HRESULT_FROM_WIN32(GetLastError()), "cannot create temporary encode output"); return false; }
  p.tempOwned = true;
  temp.Close();
  for (size_t i = 0; i < (audio ? 2u : 1u); i++) {
    std::wstring name = prefix + (i ? L"-audio" : L"-video");
    p.pipes[i].limit = i ? p.AudioLimit() : 64u * 1024 * 1024;
    p.pipes[i].handle.h = CreateNamedPipeW(name.c_str(), PIPE_ACCESS_OUTBOUND | FILE_FLAG_OVERLAPPED |
                                         FILE_FLAG_FIRST_PIPE_INSTANCE,
                                         PIPE_TYPE_BYTE | PIPE_WAIT | PIPE_REJECT_REMOTE_CLIENTS,
                                         1, 65536, 65536, 0, nullptr);
    if (!p.pipes[i].handle.Valid()) { p.Fail(HRESULT_FROM_WIN32(GetLastError()), "cannot create input pipe"); return false; }
  }
  // Current FFmpeg rejects -thread_queue_size as an input option; the core dropped it too.
  std::vector<std::wstring> args = {exe, L"-hide_banner", L"-nostdin", L"-y",
    L"-probesize", L"32", L"-analyzeduration", L"0",
    L"-f", L"rawvideo", L"-pixel_format", L"p010le", L"-video_size",
    std::to_wstring(width) + L"x" + std::to_wstring(height), L"-framerate", rate.Text(),
    L"-i", prefix + L"-video"};
  if (audio) {
    const std::vector<std::wstring> a = {L"-probesize", L"32",
      L"-analyzeduration", L"0", L"-f", L"f32le", L"-ar", L"48000", L"-ac", L"2",
      L"-i", prefix + L"-audio"};
    args.insert(args.end(), a.begin(), a.end());
  }
  for (const auto& a : {L"-map", L"0:v:0"}) args.emplace_back(a);
  if (audio) { args.emplace_back(L"-map"); args.emplace_back(L"1:a:0"); }
  const std::vector<std::wstring> tail = {L"-c:v", L"ffv1", L"-pix_fmt", L"yuv420p10le"};
  args.insert(args.end(), tail.begin(), tail.end());
  if (audio) { args.emplace_back(L"-c:a"); args.emplace_back(L"pcm_f32le"); }
  args.emplace_back(L"-f"); args.emplace_back(L"matroska"); args.push_back(p.stats.tempPath);
  if (compile) {
    auto plan = compile(prefix + L"-video", prefix + L"-audio", p.stats.tempPath);
    args = {exe};
    args.insert(args.end(), plan.argv.begin(), plan.argv.end());
    p.withAudio = plan.audioInput;
    if (!p.withAudio) p.pipes[1].handle.Close();
  }
  for (const auto& a : args) if (a.find(L'\0') != std::wstring::npos) {
    p.Fail(E_INVALIDARG, "NUL in executable/argv"); return false;
  }
  for (const auto& a : args) p.stats.command += (p.stats.command.empty() ? L"" : L" ") + Quote(a);
  if (p.stats.command.size() >= 32767) { p.Fail(E_INVALIDARG, "Windows command line exceeds 32766 UTF-16 units"); return false; }
  if (!compile) Log("FFmpeg exe=%s sha256=%s", Utf8(exe.c_str()).c_str(), Sha256File(exe).c_str());
  Log("FFmpeg command: %s", Utf8(p.stats.command.c_str()).c_str());

  SECURITY_ATTRIBUTES sa = {sizeof(sa), nullptr, TRUE};
  Handle input, nullOut, log;
  input.h = CreateFileW(L"NUL", GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE, &sa, OPEN_EXISTING, 0, nullptr);
  nullOut.h = CreateFileW(L"NUL", GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, &sa, OPEN_EXISTING, 0, nullptr);
  log.h = CreateFileW(p.stats.stderrPath.c_str(), GENERIC_WRITE, FILE_SHARE_READ, &sa, CREATE_ALWAYS,
                      FILE_ATTRIBUTE_NORMAL, nullptr);
  if (progress) {
    nullOut.Close();
    if (!CreatePipe(&p.progressRead.h, &nullOut.h, &sa, 65536) ||
        !SetHandleInformation(p.progressRead.h, HANDLE_FLAG_INHERIT, 0)) {
      p.Fail(HRESULT_FROM_WIN32(GetLastError()), "cannot create FFmpeg progress pipe"); return false;
    }
  }
  if (!input.Valid() || !nullOut.Valid() || !log.Valid()) {
    p.Fail(HRESULT_FROM_WIN32(GetLastError()), "cannot open FFmpeg diagnostic handles"); return false;
  }
  SIZE_T attrSize = 0;
  InitializeProcThreadAttributeList(nullptr, 1, 0, &attrSize);
  std::vector<BYTE> attrs(attrSize);
  auto attr = reinterpret_cast<LPPROC_THREAD_ATTRIBUTE_LIST>(attrs.data());
  if (!InitializeProcThreadAttributeList(attr, 1, 0, &attrSize)) {
    p.Fail(HRESULT_FROM_WIN32(GetLastError()), "cannot initialize process attributes"); return false;
  }
  HANDLE inherit[] = {input.h, nullOut.h, log.h};
  bool attrOk = UpdateProcThreadAttribute(attr, 0, PROC_THREAD_ATTRIBUTE_HANDLE_LIST, inherit,
                                         sizeof(inherit), nullptr, nullptr) != FALSE;
  STARTUPINFOEXW si{};
  si.StartupInfo.cb = sizeof(si);
  si.StartupInfo.dwFlags = STARTF_USESTDHANDLES;
  si.StartupInfo.hStdInput = input.h;
  si.StartupInfo.hStdOutput = nullOut.h;
  si.StartupInfo.hStdError = log.h;
  si.lpAttributeList = attr;
  PROCESS_INFORMATION pi{};
  std::vector<wchar_t> command(p.stats.command.begin(), p.stats.command.end());
  command.push_back(0);
  DWORD createError = ERROR_INVALID_PARAMETER; bool interrupted = false;
  BOOL created = attrOk && CreateProcessPolled([&] {
    const auto result = CreateProcessW(exe.c_str(), command.data(), nullptr, nullptr, TRUE,
      EXTENDED_STARTUPINFO_PRESENT | CREATE_NO_WINDOW | CREATE_SUSPENDED, nullptr, nullptr, &si.StartupInfo, &pi);
    createError = GetLastError(); return result;
  },startupPoll,interrupted);
  DeleteProcThreadAttributeList(attr);
  if (!created) { p.Fail(HRESULT_FROM_WIN32(createError), "cannot start FFmpeg"); return false; }
  p.process.h = pi.hProcess;
  Handle thread;
  thread.h = pi.hThread;
  p.stats.pid = pi.dwProcessId;
  if (interrupted) {
    TerminateProcess(p.process.h,1); WaitForSingleObject(p.process.h,2000);
    p.Fail(E_ABORT,"caller stopped during FFmpeg startup"); return false;
  }
  p.job.h = CreateJobObjectW(nullptr, nullptr);
  JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits{};
  limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
  if (!p.job.Valid() || !SetInformationJobObject(p.job.h, JobObjectExtendedLimitInformation, &limits, sizeof(limits)) ||
      !AssignProcessToJobObject(p.job.h, p.process.h)) {
    p.Fail(HRESULT_FROM_WIN32(GetLastError()), "cannot own FFmpeg in a job");
    // An unassigned suspended process must be terminated directly.
    TerminateProcess(p.process.h, 1); return false;
  }
  if (ResumeThread(thread.h) == (DWORD)-1) {
    p.Fail(HRESULT_FROM_WIN32(GetLastError()), "cannot resume FFmpeg"); return false;
  }
  input.Close(); nullOut.Close(); log.Close();
  p.Active();
  if (progress) p.progressWorker = std::thread([&p, progress] {
    char bytes[4096]; DWORD count = 0; std::string line; long long seen[3] = {-1, -1, -1};
    while (ReadFile(p.progressRead.h, bytes, sizeof(bytes), &count, nullptr) && count) {
      p.Observe(bytes, count, line, seen);
      try { progress(bytes, count); } catch (...) { Log("progress observer failed (nonfatal)"); }
    }
  });
  p.stderrWorker = std::thread([&p] { try { p.WatchStderr(); } catch (...) { Log("FFmpeg stderr watcher failed (nonfatal)"); } });
  for (size_t i = 0; i < (p.withAudio ? 2u : 1u); i++) p.pipes[i].worker = std::thread([&p, i] { p.WritePipe(i); });
  return true;
}

bool FfmpegEncoder::Submit(bool audio, std::vector<BYTE> data, const Poll& poll) {
  auto& p = *p_;
  if (!p.process.Valid() || p.finished) { p.Fail(E_UNEXPECTED, "Submit requires an active encoder"); return false; }
  auto& pipe = p.pipes[audio ? 1 : 0];
  if (data.empty()) return true;
  if (data.size() > pipe.limit || (audio && !p.withAudio)) { p.Fail(E_INVALIDARG, "input exceeds pipe queue limit"); return false; }
  // The caller polls once per frame; poll here only while waiting for queue space (every 100 ms).
  for (bool waited = false;; waited = true) {
    // A recognized FFmpeg failure stays the outcome even if the host cancels meanwhile.
    if (p.failed || p.stopping || (waited && !poll())) return false;
    if (p.endedEarly) return true;  // FFmpeg already finished; the caller stops fetching input.
    if (p.Exited()) { p.InputClosed(); return p.endedEarly; }
    {
      std::unique_lock<std::mutex> lock(pipe.mutex);
      // After FFmpeg's fatal error nothing more is queued; wait for its exit (or the watcher's failure).
      if (!p.fatalSeen && pipe.bytes <= pipe.limit - data.size() && pipe.blocks < (audio ? 4096u : 8u)) {
        pipe.bytes += data.size(); pipe.blocks++;
        pipe.highWater = (std::max)(pipe.highWater, (uint64_t)pipe.bytes);
        pipe.queue.push_back(std::move(data));
        pipe.changed.notify_all();
        return true;
      }
      pipe.changed.wait_for(lock, std::chrono::milliseconds(100));
    }
    if (p.Stalled()) { p.Fail(E_FAIL, p.StallMessage().c_str()); return false; }
  }
}

bool FfmpegEncoder::Finish(const Poll& poll, bool publish) {
  auto& p = *p_;
  if (!p.process.Valid() || p.finished) { p.Fail(E_UNEXPECTED, "Finish requires an active encoder"); return false; }
  if (!poll()) { p.Abort(); return false; }
  for (size_t i = 0; i < (p.withAudio ? 2u : 1u); i++) {
    std::lock_guard<std::mutex> lock(p.pipes[i].mutex);
    p.pipes[i].eof = true;
    p.pipes[i].changed.notify_all();
  }
  p.Active();  // A slow flush is healthy while progress keeps advancing.
  while (!p.pipes[0].done || (p.withAudio && !p.pipes[1].done) || !p.Exited()) {
    if (p.failed || !poll() || p.Stalled()) {
      if (!p.failed && p.Stalled()) p.Fail(E_FAIL, p.StallMessage().c_str());
      p.Abort(); return false;
    }
    WaitForSingleObject(p.process.h, 100);
    // Once the child exits, do not busy-spin while the pipe threads finish.
    if (p.Exited()) std::this_thread::sleep_for(std::chrono::milliseconds(10));
  }
  for (auto& pipe : p.pipes) if (pipe.worker.joinable()) pipe.worker.join();
  if (p.stderrWorker.joinable()) p.stderrWorker.join();
  GetExitCodeProcess(p.process.h, &p.stats.exitCode);
  p.job.Close();
  if (p.progressWorker.joinable()) p.progressWorker.join();
  p.progressRead.Close();
  if (p.failed || p.stats.exitCode != 0 || p.fatalSeen) {
    p.Fail(E_FAIL, "FFmpeg returned a failing exit code"); p.Abort(); return false;
  }
  WIN32_FILE_ATTRIBUTE_DATA file{};
  if (!GetFileAttributesExW(p.stats.tempPath.c_str(), GetFileExInfoStandard, &file) ||
      (file.nFileSizeHigh == 0 && file.nFileSizeLow == 0)) {
    p.Fail(E_FAIL, "FFmpeg produced no output"); p.Abort(); return false;
  }
  p.finished = true;
  p.process.Close();
  return !publish || Publish();
}
bool FfmpegEncoder::Publish() {
  auto& p = *p_;
  if (!p.finished || p.failed || p.stopping || p.stats.published) {
    p.Fail(E_UNEXPECTED, "publication requires a finished unfailed encoder"); return false;
  }
  // A refused publication keeps the finished render and names it.
  auto refuse = [&](DWORD code, const std::string& why) {
    p.tempOwned = false;
    p.Fail(HRESULT_FROM_WIN32(code), (why + " The finished render was kept as " + Utf8(p.stats.tempPath.c_str()) + ".").c_str());
    p.Abort(); return false;
  };
  if (p.hadExisting) {
    FileIdentity now;
    if (!ReadIdentity(p.output, now) || !(now == p.existing))
      return refuse(ERROR_FILE_EXISTS, "The destination file changed during the render, so it was not replaced.");
    if (!MoveFileExW(p.stats.tempPath.c_str(), p.output.c_str(), MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH)) {
      const DWORD code = GetLastError();
      return refuse(code, code == ERROR_SHARING_VIOLATION || code == ERROR_ACCESS_DENIED || code == ERROR_LOCK_VIOLATION ?
        "The existing destination file is in use, so it was not replaced." : "The existing destination file could not be replaced.");
    }
    p.stats.replacedExisting = true;
  } else if (!MoveFileExW(p.stats.tempPath.c_str(), p.output.c_str(), MOVEFILE_WRITE_THROUGH)) {
    // No REPLACE_EXISTING: a destination created during encoding must be preserved.
    const DWORD code = GetLastError();
    if (code == ERROR_ALREADY_EXISTS || code == ERROR_FILE_EXISTS)
      return refuse(code, "The destination file appeared during the render, so it was not overwritten.");
    p.Fail(HRESULT_FROM_WIN32(code), "cannot publish completed output"); p.Abort(); return false;
  }
  p.stats.published = true;
  p.tempOwned = false;
  p.process.Close(); p.job.Close();
  return true;
}
void FfmpegEncoder::SetAudioBytesPerSecond(uint64_t bytesPerSecond) { p_->audioBytesPerSecond = bytesPerSecond; }
void FfmpegEncoder::SetReplaceExisting(bool replace) { p_->replaceExisting = replace; }
bool FfmpegEncoder::EndedEarly() const { return p_->endedEarly; }
std::vector<BYTE> FfmpegEncoder::TakeBuffer(bool audio, size_t size) {
  auto& p = *p_;
  {
    std::lock_guard<std::mutex> lock(p.poolMutex);
    auto& pool = p.pool[audio ? 1 : 0];
    for (auto it = pool.begin(); it != pool.end(); ++it) if (it->capacity() >= size) {
      auto buffer = std::move(*it);
      pool.erase(it);
      buffer.resize(size);  // within capacity: no allocation, and no fill for a same-size frame
      return buffer;
    }
  }
  if (!audio) p.videoBuffersAllocated++;
  return std::vector<BYTE>(size);
}
void FfmpegEncoder::RetainPartial() { p_->tempOwned = false; }
void FfmpegEncoder::Abort() { p_->Abort(); }
HRESULT FfmpegEncoder::Error() const { std::lock_guard<std::mutex> lock(p_->errorMutex); return p_->error; }
std::string FfmpegEncoder::Reason() const { std::lock_guard<std::mutex> lock(p_->errorMutex); return p_->reason; }
EncodeStats FfmpegEncoder::Stats() const {
  EncodeStats s = p_->stats;
  s.videoBytes = p_->pipes[0].written; s.audioBytes = p_->pipes[1].written;
  s.videoHighWater = p_->pipes[0].highWater; s.audioHighWater = p_->pipes[1].highWater;
  s.videoQueueLimit = 64u * 1024 * 1024; s.audioQueueLimit = p_->AudioLimit();
  s.videoBuffersAllocated = p_->videoBuffersAllocated;
  return s;
}
}  // namespace vegas_encoder
