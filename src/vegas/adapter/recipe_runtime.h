#pragma once
#include "../../core/core.h"
#include "../configuration/recipe_page.h"

namespace vegas_encoder {
struct RecipeRuntime {
  ve::Json installation, capabilities = nullptr;
  std::wstring jobsRoot, monitorApplication;
  bool verifyOutput = true;
  ve::Json hostHwnd = nullptr;
  ve::Json failedEncoders = ve::Json::object(); // {encoder:{reason,testedAt}} kept from the app's cache
};
struct HostWindowCandidate { uintptr_t handle = 0; DWORD process = 0; bool visible = false, owned = false; LONGLONG area = 0; };
// Progress-window placement: the foreground root window when it belongs to this
// process, otherwise this process's visible, unowned, largest top-level window (0: unknown).
uintptr_t ChooseHostWindow(const HostWindowCandidate& foreground, const std::vector<HostWindowCandidate>& topLevel, DWORD process);
// Owned C7/C3 snapshots only. No discovery, probes or executable hashing here.
RecipeRuntime LoadRecipeRuntime();
// The per-user jobs folder, available even when machine.json is missing or invalid.
std::wstring RecipeJobsRoot();
configuration::RecipePageOptions RecipeEditorOptions(const GUID& owner, const char* container);
ve::Json DefaultRecipeSnapshot();
ve::Json BuiltinRecipeSnapshot(const char* presetJson);
} // namespace vegas_encoder
