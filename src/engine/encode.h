// External FFmpeg transport. No VEGAS interfaces on worker threads.
#pragma once

#include <windows.h>
#include <cstdint>
#include <functional>
#include <memory>
#include <string>
#include <vector>

namespace vegas_encoder {
// CreateProcess itself can be slow (large static executables/AV inspection).
// Only the Windows launch moves to a worker; caller polling stays on Render.
BOOL CreateProcessPolled(const std::function<BOOL()>& create, const std::function<bool()>& poll, bool& interrupted);

struct EncodeRate {
  DWORD num = 0, den = 1;
  static EncodeRate FromDouble(double fps);
  bool Endpoint(LONGLONG frames, DWORD sampleRate, LONGLONG& samples) const;
  std::wstring Text() const;
};

struct EncodeStats {
  DWORD pid = 0, exitCode = STILL_ACTIVE;
  uint64_t videoBytes = 0, audioBytes = 0, videoHighWater = 0, audioHighWater = 0;
  bool published = false;
  std::wstring command, stderrPath, tempPath;
};

class FfmpegEncoder {
 public:
  using Poll = std::function<bool()>;  // invoked only on the caller's Render thread
  FfmpegEncoder();
  ~FfmpegEncoder();
  FfmpegEncoder(const FfmpegEncoder&) = delete;
  FfmpegEncoder& operator=(const FfmpegEncoder&) = delete;

  bool Start(const std::wstring& exe, const std::wstring& output, LONG width, LONG height,
             EncodeRate rate, bool audio, DWORD pipeTimeoutMs, DWORD finishTimeoutMs);
  struct CommandPlan { std::vector<std::wstring> argv; bool audioInput = false; };
  // The factory compiles after unique pipe/temp names are allocated, before spawn.
  // argv excludes the executable. The core owns every command/domain decision.
  using Compile = std::function<CommandPlan(const std::wstring&, const std::wstring&, const std::wstring&)>;
  using Progress = std::function<void(const char*, size_t)>;
  bool StartCompiled(const std::wstring& exe, const std::wstring& output,
                     const std::wstring& log, DWORD pipeTimeoutMs, DWORD finishTimeoutMs,
                     const Compile& compile, const Progress& progress, const Poll& startupPoll);
  bool Submit(bool audio, std::vector<BYTE> bytes, const Poll& poll);
  bool Finish(const Poll& poll, bool publish = true);
  bool Publish(); // only after successful Finish(..., false) and verification
  void RetainPartial();
  void Abort();
  HRESULT Error() const;
  std::string Reason() const;
  EncodeStats Stats() const;  // call after Finish/Abort; workers are joined

 private:
  bool StartImpl(const std::wstring&, const std::wstring&, LONG, LONG, EncodeRate, bool,
                 DWORD, DWORD, const Compile&, const Progress&, const std::wstring&, const Poll&);
  struct Impl;
  std::unique_ptr<Impl> p_;
};

}  // namespace vegas_encoder
