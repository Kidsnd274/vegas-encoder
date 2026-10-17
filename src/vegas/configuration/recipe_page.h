#pragma once

#include "editor_session.h"
#include "recipe_template.h"
#include "../abi/configuration_abi.h"

namespace vegas_encoder::configuration {

// Explicit candidate configuration, copied for one page. The adapter prepares
// the per-user session root and checks the matching app before every launch.
// No path, command, HWND or host interface comes from a saved recipe.
struct RecipePageOptions {
  GUID owner{};
  EditorLaunch launch;
  std::wstring sessionRoot;
  std::string dllVersion, coreVersion;
  ve::Json context = {{"hostVersion", nullptr}, {"project", nullptr}, {"media", nullptr}};
  ve::Json capabilities = nullptr;
  std::function<void()> beforeLaunch;
  // Shared native-target preflight. Throw to preserve the previous draft.
  std::function<void(const ve::Json&)> validateRecipe;
};

// Creator UI thread only, including final Release. Native bridge ownership is
// the same as the proof page; edit sessions never run on the Render path.
HRESULT CreateNativeRecipePage(sfio::ISfHostAllocator* allocator,
                              const RecipePageOptions& options, IPropertyPage** page) noexcept;

inline constexpr int kEditRecipeControl = 101;
inline constexpr int kRecipeStatusControl = 102;

// Internal UI-thread return policy. Restore an iconic host only when returning
// from its foreground editor; background completion must not steal activation.
void ReturnRecipeOwner(HWND owner, HWND focus, bool returnForeground) noexcept;

} // namespace vegas_encoder::configuration
