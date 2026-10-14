#pragma once
#include "../../core/core.h"
#include <windows.h>
#include <memory>
#include <optional>

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

// B6 offline transport, NOT linked into an exporter/page/Render. A page must
// separately own modality, draft lifetime, startup scheduling and HWND validation.
// All methods stay on the creator UI thread. Poll never waits for an editor.
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
} // namespace vegas_encoder::configuration
