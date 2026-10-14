#pragma once
#include "../host/template.h"
#include "../../core/core.h"
#include <functional>

namespace vegas_encoder::configuration {

// B6 offline preparation. No discovery/page/Render call site uses this yet;
// native placement/persistence and production activation remain gated A5-A7.
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
// validation. File/process/modality transport will be a separate gated layer.
class RecipeTemplateDraft final {
 public:
  RecipeTemplateDraft(const host::Tpl& value, const GUID& owner, std::string writer);
  RecipeTemplateDraft(const RecipeTemplateDraft&) = delete;
  RecipeTemplateDraft& operator=(const RecipeTemplateDraft&) = delete;
  ve::Json Snapshot() const;
  bool Dirty() const;
  bool Editing() const;
  // Caller supplies unique session ID/owner/version/context; draft supplies the
  // actual template name, recipe and origin. Null context facts stay null.
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
  std::string writer_;
  host::Tpl base_;
  ve::Json committed_, pending_, request_, capabilities_;
  bool editing_ = false;
};
} // namespace vegas_encoder::configuration
