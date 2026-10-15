#pragma once
#include "../core/core.h"
#include <windows.h>
#include <memory>
#include <string>

namespace vegas_encoder {
std::string JobUtcNow();
std::string RecipeHash(const ve::Json& recipe);
std::string NewJobId();
// One independent writer per render, holding a native module lifetime reference.
// No file work occurs while the queue mutex is held. Updates coalesce; phase
// transitions and the final record are bounded. Render never joins this worker.
class JobStore {
 public:
  static std::shared_ptr<JobStore> Create(const std::wstring& root, const std::string& id,
                                        const std::wstring& monitorApplication = {});
  ~JobStore();
  void Status(ve::Json snapshot, bool phase);
  void Complete(ve::Json snapshot, ve::Json record);
  bool Completed() const; // observation only, used by offline checks
  std::string Failure() const;
 private:
  struct State;
  explicit JobStore(std::shared_ptr<State> state) : state_(std::move(state)) {}
  static DWORD WINAPI Worker(void* context);
  std::shared_ptr<State> state_;
};
} // namespace vegas_encoder
