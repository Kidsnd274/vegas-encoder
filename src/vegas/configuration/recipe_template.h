#pragma once
#include "../host/template.h"
#include "../../core/core.h"
#include <functional>

namespace vegas_encoder::configuration {
// Active-command naming fact from the shared core; no C7 or filesystem reads.
std::wstring RecipeOutputExtension(const ve::Json& recipe);

// Used by the opt-in B6 recipe candidate. Native persistence and production
// activation remain unqualified until the owner's real-host A5-A7 tests.
// Native private allocations align the following UTF-16 text with at most one
// zero byte outside the strict core envelope. Earlier unpadded bytes still read.
ve::Json ReadRecipeSnapshot(const host::Tpl& value, const GUID& owner);
// Only a fresh product template with NO private bytes can be initialized.
// Never interpret/convert the historical VENC/CFG1 proof marker as a recipe.
host::Tpl CreateRecipeTemplate(const host::Tpl& empty, const GUID& owner, const ve::Json& snapshot);
host::Tpl ReplaceRecipeSnapshot(const host::Tpl& value, const GUID& owner, const ve::Json& snapshot);

enum class EditDisposition { applied, cancelled, rejected, noSession };
struct EditOutcome {
  EditDisposition disposition;
  ve::Json issues = ve::Json::array();
};

// One creator UI thread, owned copies only. C++ core owns payload/session/domain
// validation. The native page owns file/process/modality transport separately.
class RecipeTemplateDraft final {
 public:
  RecipeTemplateDraft(const host::Tpl& value, const GUID& owner, std::string writer,
                      std::string pageTemplateName = {});
  RecipeTemplateDraft(const RecipeTemplateDraft&) = delete;
  RecipeTemplateDraft& operator=(const RecipeTemplateDraft&) = delete;
  ve::Json Snapshot() const;
  bool Dirty() const;
  bool Editing() const;
  // Caller supplies unique session ID/owner/version/context; draft supplies the
  // native template name (page/recipe display fallback when absent), recipe and
  // origin. Display fallback never changes native text. Null facts stay null.
  ve::Json BeginEdit(ve::Json request, ve::Json capabilities = nullptr);
  // Consume at most one terminal result. A missing/malformed/crashed editor is
  // cancellation; a structurally valid but invalid recipe is rejected unchanged.
  EditOutcome FinishEdit(const ve::Json& result, DWORD editorExitCode);
  host::Tpl Prepare() const;
  // Store callback must copy synchronously, committing only on S_OK and leaving
  // its prior bytes intact otherwise. Preallocate everything before that call.
  HRESULT Commit(const std::function<HRESULT(const host::Tpl&)>& store) noexcept;
  void Discard();

 private:
  void RequireCaller() const;
  DWORD caller_;
  GUID owner_;
  std::string writer_, pageTemplateName_;
  host::Tpl base_;
  ve::Json committed_, pending_, request_, capabilities_;
  bool editing_ = false;
};
} // namespace vegas_encoder::configuration
