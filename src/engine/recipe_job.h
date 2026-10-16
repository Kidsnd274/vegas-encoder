#pragma once
#include "encode.h"
#include "job_store.h"
#include "progress.h"
#include <mutex>

namespace vegas_encoder {
struct JobControl { HRESULT hresult = S_OK; bool cancelled = false; };
struct RecipeJobOptions {
  std::wstring output, jobsRoot;
  std::string templateName, project;
  ve::Json hostHwnd = nullptr;
  bool verifyOutput = true;
  std::wstring monitorApplication;
  std::string requiredOutputContainerId;
  bool requiredVideoOutput = false;
  DWORD pipeTimeoutMs = 10000, finishTimeoutMs = 120000, probeTimeoutMs = 120000;
};
// Immutable, already-selected installation/capability snapshot from C7/C3; B6
// supplies the real template payload. This engine contains no native host API.
class RecipeJob {
 public:
  using Poll = std::function<JobControl()>;
  RecipeJob();
  ~RecipeJob();
  bool Start(const ve::Json& recipe, const ve::Json& media, const ve::Json& installation,
             const ve::Json& capabilities, const ve::Json& origin, const RecipeJobOptions& options, const Poll& poll);
  bool Submit(bool audio, std::vector<BYTE> bytes, const Poll& poll);
  bool Finish(const Poll& poll);
  void Stop(HRESULT hresult, const std::string& message, bool cancelled = false);
  HRESULT Error() const { return error_; }
  std::string Reason() const { return message_; }
  EncodeStats Stats() const { return encoder_.Stats(); } // only after stop/finish
  const ve::Json& Compiled() const { return compiled_; }
  const ve::Json& Record() const { return record_; }
  const std::string& Id() const { return id_; }
  std::shared_ptr<JobStore> Store() const { return store_; }
  ve::Json LiveStatus() const { std::lock_guard<std::mutex> lock(liveMutex_); return live_; }
 private:
  bool Check(const Poll& poll);
  void Phase(const std::string& state, const std::string& message);
  void Progress(const ve::Json& metrics);
  void Complete(bool success);
  bool Verify(const Poll& poll);
  FfmpegEncoder encoder_;
  ProgressParser parser_;
  std::shared_ptr<JobStore> store_;
  RecipeJobOptions options_;
  ve::Json recipe_, media_, installation_, origin_, compiled_ = ve::Json::object();
  ve::Json live_, record_ = nullptr, verification_, timings_ = ve::Json::object();
  mutable std::mutex liveMutex_;
  std::string id_, startedAt_, message_;
  ULONGLONG started_ = 0, phaseStarted_ = 0;
  HRESULT error_ = S_OK;
  bool cancelled_ = false, terminal_ = false, startedOnce_ = false, encoderFailure_ = false;
};
// Pure fact comparison, independently exercised with malformed/mismatched probes.
ve::Json VerifyProbe(const ve::Json& probe, const ve::Json& expectedStreams);
// C5's nullable video facts come only from a successfully compiled, scoped
// native-core result. No FFmpeg command or human-readable summary is parsed.
ve::Json LiveVideoFacts(const ve::Json& compiled);
// Bounded diagnostic text for an encoder failure, not a replacement HRESULT or
// an inference about host/verification/cancellation failures.
std::string EncoderFailureMessage(const std::string& fallback, const std::string& stderrTail);
} // namespace vegas_encoder
