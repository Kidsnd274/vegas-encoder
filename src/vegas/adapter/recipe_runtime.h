#pragma once
#include "../../core/core.h"
#include "../configuration/recipe_page.h"

namespace vegas_encoder {
struct RecipeRuntime {
  ve::Json installation, capabilities = nullptr;
  std::wstring jobsRoot, monitorApplication;
  bool verifyOutput = true;
  ve::Json hostHwnd = nullptr;
};
// Owned C7/C3 snapshots only. No discovery, probes or executable hashing here.
RecipeRuntime LoadRecipeRuntime();
configuration::RecipePageOptions RecipeEditorOptions();
ve::Json DefaultRecipeSnapshot();
} // namespace vegas_encoder
