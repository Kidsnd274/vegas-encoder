#pragma once
#include "../configuration/recipe_template.h"

namespace vegas_encoder {
// Legacy hosts supply one class-wide suffix. Resolve it from the immutable
// recipe's core fact before output admission, reservation or job creation.
// Authored from the naming policy; no third-party implementation is reused.
inline std::wstring ResolveRecipeDestination(const ve::Json& recipe, const std::wstring& requested) {
  if (requested.empty()) return requested; // Preserve SetFile's explicit reset.
  const auto separator = requested.find_last_of(L"/\\");
  const auto first = separator == std::wstring::npos ? 0 : separator + 1;
  const auto name = requested.substr(first);
  if (name.empty() || name == L"." || name == L".." || name.find(L':') != std::wstring::npos)
    throw std::invalid_argument("Choose a complete output filename.");
  const auto extension = configuration::RecipeOutputExtension(recipe);
  if (extension.empty())
    throw std::invalid_argument("The selected recipe needs an explicit supported output container before its filename can be resolved.");
  const auto dot = requested.find_last_of(L'.');
  const auto end = dot != std::wstring::npos && dot >= first ? dot : requested.size();
  return requested.substr(0,end) + extension;
}
} // namespace vegas_encoder
