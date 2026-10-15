#pragma once
#include "../../core/core.h"
#include <windows.h>
#include <memory>
#include <optional>
#include <functional>

namespace vegas_encoder::configuration {

std::string NewEditSessionId();

struct EditorLaunch {
  std::wstring application; // Explicit absolute executable, never a shell command.
  std::vector<std::wstring> arguments; // Controlled launch context; tests use fake modes.
};
struct EditorExit {
  ve::Json result = nullptr;
  DWORD exitCode = 1;
  std::string diagnostic;
  bool cleanupComplete = false;
};

// Low-level owned transport. A page separately owns modality/draft/HWND lifetime.
// All methods stay on its creator thread. Poll never waits for an editor.
// Start does synchronous local file/process setup; it has no visibility/latency
// qualification and must never be called from Render.
class EditorSessionTransport final {
 public:
  explicit EditorSessionTransport(const std::wstring& existingRoot);
  ~EditorSessionTransport();
  EditorSessionTransport(const EditorSessionTransport&) = delete;
  EditorSessionTransport& operator=(const EditorSessionTransport&) = delete;
  // One launch per object. Core-validated request must contain a fresh sessionId.
  // Launch failure throws; the caller cancels its draft transaction unchanged.
  void Start(const ve::Json& request, const EditorLaunch& launch);
  bool Active() const;
  std::wstring Directory() const;
  DWORD ProcessId() const;
  // Consume a result once, only after the directly owned child exits. File/shape/
  // session errors return null (cancel). RecipeTemplateDraft owns domain checking.
  std::optional<EditorExit> Poll();
  // Page teardown fallback: terminate ONLY this job, without waiting; discard any
  // result even if Apply was already written. Future UI supplies graceful WM_CLOSE.
  void Cancel();

 private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
};

// One background owner for the low-level transport, including slow Windows
// process creation. UI methods copy/poll values only, never join or touch host
// objects on a worker. The worker retains its DLL through late cancellation.
class EditorSessionTask final {
 public:
  EditorSessionTask(const std::wstring& existingRoot, const ve::Json& request,
                    const EditorLaunch& launch, std::function<void()> beforeStart = {});
  ~EditorSessionTask();
  EditorSessionTask(const EditorSessionTask&) = delete;
  EditorSessionTask& operator=(const EditorSessionTask&) = delete;
  std::optional<EditorExit> Poll();
  void Cancel() noexcept;
  DWORD ProcessId() const noexcept;
 private:
  struct State;
  static DWORD WINAPI Worker(void* context);
  std::shared_ptr<State> state_;
  const DWORD caller_ = GetCurrentThreadId();
  bool consumed_ = false;
};
} // namespace vegas_encoder::configuration
