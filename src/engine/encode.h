// Fixed-profile external FFmpeg transport. No VEGAS interfaces on worker threads.
#pragma once

#include <windows.h>
#include <cstdint>
#include <functional>
#include <memory>
#include <string>
#include <vector>

namespace vegas_encoder {

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
  bool Submit(bool audio, std::vector<BYTE> bytes, const Poll& poll);
  bool Finish(const Poll& poll);
  void Abort();
  HRESULT Error() const;
  std::string Reason() const;
  EncodeStats Stats() const;  // call after Finish/Abort; workers are joined

 private:
  struct Impl;
  std::unique_ptr<Impl> p_;
};

}  // namespace vegas_encoder
