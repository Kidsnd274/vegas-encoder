#include "recipe_template.h"
#include "../../support/diagnostics.h"
#include "../../support/native_boundary.h"
#include <algorithm>
#include <cstring>

namespace vegas_encoder::configuration {
namespace {
void RequireTemplate(const host::Tpl& value, const GUID& owner) {
  if (!host::Tpl::Valid(value.Ptr(), value.b.size()) ||
      value.U32(sfio::tpl::cbStruct) != value.b.size() ||
      value.Guid(sfio::tpl::iidOwner) != owner)
    throw std::invalid_argument("Invalid or foreign owned product template.");
}
host::Tpl Place(const host::Tpl& value, const std::vector<uint8_t>& payload) {
  const size_t oldExtra = value.U32(sfio::tpl::cbExtra);
  const size_t suffix = sfio::tpl::abExtra + oldExtra;
  const size_t size = value.b.size() - oldExtra + payload.size();
  if (size > host::Tpl::kMaxBytes) throw std::length_error("Template allocation exceeds the owned byte limit.");
  host::Tpl result;
  result.b.resize(size);
  std::copy_n(value.b.begin(), sfio::tpl::abExtra, result.b.begin());
  std::copy(payload.begin(), payload.end(), result.b.begin() + sfio::tpl::abExtra);
  // Preserve the entire declared suffix, including raw text allocation/padding
  // and any opaque trailer; do not rebuild name/notes from interpreted strings.
  std::copy(value.b.begin() + suffix, value.b.end(),
            result.b.begin() + sfio::tpl::abExtra + payload.size());
  result.SetU32(sfio::tpl::cbStruct, static_cast<DWORD>(size));
  result.SetU32(sfio::tpl::cbExtra, static_cast<DWORD>(payload.size()));
  return result;
}
EditOutcome Cancelled(const char* message) {
  return {EditDisposition::cancelled,
          ve::Json::array({ve::Issue("S-CANCELLED", "info", "", message)})};
}
bool Same(const ve::Json& before, const ve::Json& after) {
  // Payload JSON is canonical. Object insertion order must not manufacture a
  // setting edit when an editor reorders properties while returning the same data.
  return ve::Canonical(before) == ve::Canonical(after);
}
}

ve::Json ReadRecipeSnapshot(const host::Tpl& value, const GUID& owner) {
  RequireTemplate(value, owner);
  const auto length = value.U32(sfio::tpl::cbExtra);
  const auto decoded = ve::DecodePayload(value.b.data() + sfio::tpl::abExtra, length);
  if (ve::HasErrors(decoded.at("issues")))
    throw ve::Error(VE_INVALID_ARGUMENT, "NATIVE-PAYLOAD", decoded.at("issues")[0].at("message").get<std::string>());
  return decoded.at("snapshot");
}
host::Tpl CreateRecipeTemplate(const host::Tpl& empty, const GUID& owner, const ve::Json& snapshot) {
  RequireTemplate(empty, owner);
  if (empty.U32(sfio::tpl::cbExtra) != 0)
    throw std::invalid_argument("Recipe initialization requires a fresh empty template; proof migration is unsupported.");
  return Place(empty, ve::EncodePayload(snapshot));
}
host::Tpl ReplaceRecipeSnapshot(const host::Tpl& value, const GUID& owner, const ve::Json& snapshot) {
  (void)ReadRecipeSnapshot(value, owner); // Reject damaged/future/proof bytes before replacement.
  return Place(value, ve::EncodePayload(snapshot));
}

RecipeTemplateDraft::RecipeTemplateDraft(const host::Tpl& value, const GUID& owner, std::string writer)
    : caller_(GetCurrentThreadId()), owner_(owner), writer_(std::move(writer)),
      base_(value), committed_(ReadRecipeSnapshot(base_, owner_)), pending_(committed_) {
  if (writer_.empty()) throw std::invalid_argument("Snapshot writer identity is required.");
}
void RecipeTemplateDraft::RequireCaller() const {
  if (GetCurrentThreadId() != caller_) throw std::logic_error("Template draft must stay on its creator UI thread.");
}
ve::Json RecipeTemplateDraft::Snapshot() const { RequireCaller(); return pending_; }
bool RecipeTemplateDraft::Dirty() const { RequireCaller(); return !Same(pending_, committed_); }
bool RecipeTemplateDraft::Editing() const { RequireCaller(); return editing_; }

ve::Json RecipeTemplateDraft::BeginEdit(ve::Json request, ve::Json capabilities) {
  RequireCaller();
  if (editing_) throw std::logic_error("An editor session is already active for this draft.");
  if (!request.is_object()) throw std::invalid_argument("Expected an edit-session request.");
  request["recipe"] = pending_.at("recipe");
  request["origin"] = pending_.value("origin", ve::Json(nullptr));
  request["templateName"] = Utf8(base_.Name().c_str());
  const auto validated = ve::SessionRequest(request);
  if (ve::HasErrors(validated.at("issues"))) throw std::invalid_argument("Invalid edit-session request/context.");
  if (ve::Canonical(request).size() > VE_CORE_JSON_LIMIT)
    throw std::length_error("Edit-session request exceeds the C4 JSON limit.");
  // Copy the returned request before opening the transaction. Allocation errors
  // cannot leave a session active that the caller never received.
  ve::Json returned = request;
  request_.swap(request);
  capabilities_.swap(capabilities);
  editing_ = true;
  return returned;
}

EditOutcome RecipeTemplateDraft::FinishEdit(const ve::Json& result, DWORD editorExitCode) {
  RequireCaller();
  if (!editing_) return {EditDisposition::noSession};
  editing_ = false; // One terminal result even for crash/mismatch/invalid input.
  if (editorExitCode != 0) return Cancelled("Editor exited unsuccessfully; draft preserved.");
  try {
    if (ve::Canonical(result).size() > VE_CORE_JSON_LIMIT)
      return Cancelled("Editor result exceeds the C4 JSON limit; draft preserved.");
    const auto shape = ve::SessionResult(result);
    if (ve::HasErrors(shape.at("issues"))) return Cancelled("Missing or invalid editor result; draft preserved.");
    if (ve::Str(result, "sessionId") != ve::Str(request_, "sessionId"))
      return Cancelled("Editor result belongs to another session; draft preserved.");
    if (ve::Str(result, "action") == "cancel") return Cancelled("Editor cancelled; draft preserved.");
    const auto issues = ve::Validate({{"recipe", result.at("recipe")},
      {"media", request_.at("context").value("media", ve::Json(nullptr))}, {"capabilities", capabilities_}});
    if (ve::HasErrors(issues)) return {EditDisposition::rejected, issues};
    const auto origin = result.value("origin", ve::Json(nullptr));
    if (Same(result.at("recipe"), pending_.at("recipe")) && Same(origin, pending_.value("origin", ve::Json(nullptr))))
      return {EditDisposition::applied, issues}; // No artificial writer-only dirty state.
    auto next = pending_; // Preserve preferences and unknown snapshot metadata.
    next["recipe"] = result.at("recipe");
    next["origin"] = origin;
    next["writtenBy"] = writer_;
    (void)ve::EncodePayload(next); // Bound/validate before exposing a dirty draft.
    EditOutcome outcome{EditDisposition::applied, issues};
    pending_.swap(next);
    return outcome;
  } catch (const ve::Error& error) {
    return {EditDisposition::rejected, ve::Json::array({ve::Issue(error.code, "error", "", error.what())})};
  } catch (const std::exception&) {
    return Cancelled("Malformed editor result or unavailable validation context; draft preserved.");
  }
}
host::Tpl RecipeTemplateDraft::Prepare() const {
  RequireCaller();
  if (editing_) throw std::logic_error("Editor is still open; no template Apply is allowed.");
  return ReplaceRecipeSnapshot(base_, owner_, pending_);
}
HRESULT RecipeTemplateDraft::Commit(const std::function<HRESULT(const host::Tpl&)>& store) noexcept {
  if (GetCurrentThreadId() != caller_) return RPC_E_WRONG_THREAD;
  if (editing_) return E_PENDING;
  if (!store) return E_POINTER;
  return NativeBoundary([&]() -> HRESULT {
    if (!Dirty()) return S_OK;
    auto prepared = Prepare();
    auto accepted = pending_; // No allocations after the host reports success.
    const HRESULT result = store(prepared);
    if (result == S_OK) {
      base_.b.swap(prepared.b);
      committed_.swap(accepted);
    }
    return result;
  });
}
void RecipeTemplateDraft::Discard() {
  RequireCaller();
  auto original = committed_;
  pending_.swap(original);
  editing_ = false;
}
} // namespace vegas_encoder::configuration
