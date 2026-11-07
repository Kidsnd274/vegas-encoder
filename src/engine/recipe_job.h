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
  bool nativeTarget = false;
  // Contract 3.5: fail only after StallTimeoutMs without FFmpeg activity; ConnectTimeoutMs bounds pipe connection.
  DWORD stallTimeoutMs = 120000, connectTimeoutMs = 30000, probeTimeoutMs = 120000;
  std::function<std::string()> clock; // Tests inject a stepping clock; production uses JobUtcNow.
  // {encoder:{reason,testedAt}} from the app's last hardware test (decision D8): context, never a block.
  ve::Json failedEncoders = ve::Json::object();
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
  // FFmpeg finished successfully before all input was sent (for example -t). Stop fetching host frames, then Finish.
  bool EndedEarly() const { return encoder_.EndedEarly(); }
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
// Contracts 3.1/3.2: a render that stops before FFmpeg starts (suffix, audio format,
// pixel aspect, missing setup) still gets a C6 record with stage "preflight" and a
// terminal live file, so the progress window and history can say why.
struct PreflightFailure {
  std::wstring jobsRoot, output, monitorApplication;
  std::string templateName, project, message;
  ve::Json recipe = nullptr, origin = nullptr, media = nullptr, hostHwnd = nullptr;
  HRESULT hresult = E_FAIL;
  bool cancelled = false;
};
void WritePreflightRecord(const PreflightFailure& failure);
// Pure fact comparison, independently exercised with malformed/mismatched probes.
ve::Json VerifyProbe(const ve::Json& probe, const ve::Json& expectedStreams, const std::string& outputContainerId = {});
// C5's nullable video facts come only from a successfully compiled, scoped
// native-core result. No FFmpeg command or human-readable summary is parsed.
ve::Json LiveVideoFacts(const ve::Json& compiled);
// Bounded diagnostic text for an encoder failure, not a replacement HRESULT or
// an inference about host/verification/cancellation failures.
std::string EncoderFailureMessage(const std::string& fallback, const std::string& stderrTail);
} // namespace vegas_encoder
