// B6 preparation: owned native byte placement + C4 draft transactions only.
// No VEGAS, exporter DLL, editor, monitor or user-state access.
#include "../../src/vegas/configuration/recipe_template.h"
#include "../../src/vegas/configuration/native_store.h"
#include "../../src/vegas/adapter/vegas_encoder.h"
#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <iterator>
#include <thread>

using ve::Json;
using vegas_encoder::host::Tpl;
using namespace vegas_encoder::configuration;
namespace {
int checks = 0;
void Check(bool ok, const char* message) {
  ++checks;
  if (!ok) throw std::runtime_error(message);
}
template<class F> bool Rejects(F&& call) {
  try { call(); } catch (const std::exception&) { return true; }
  return false;
}
const GUID owner = vegas_encoder::GUID_VegasEncoderType;
bool Same(const Json& before, const Json& after) { return ve::Canonical(before) == ve::Canonical(after); }
Tpl Empty() {
  auto value = Tpl::Make(L"Recipe \u03a9 \u6d4b\u8bd5", L"Opaque text allocation", 0);
  value.SetGuid(sfio::tpl::iidOwner, owner);
  value.SetU32(sfio::tpl::id, 7);
  value.b[0x1ED] = 0xA5; // Uninterpreted host field.
  value.b.insert(value.b.end(), {0xDE,0xAD,0xBE,0xEF}); // Opaque declared trailer.
  value.SetU32(sfio::tpl::cbStruct, static_cast<DWORD>(value.b.size()));
  return value;
}
Json Snapshot(const Json& recipe) {
  return {{"recipe", recipe}, {"origin", {{"presetId", "source"}, {"revision", 3}, {"name", "Source"}}},
          {"vegasPrefs", {{"frame", "project"}, {"future", {{"preserve", true}}}}},
          {"writtenBy", "before-b6"}, {"extensions", {{"retain", Json::array({1,2,3})}}}};
}
bool PreservesHost(const Tpl& before, const Tpl& after) {
  auto fixedBefore = before.b, fixedAfter = after.b;
  // Only cbStruct and cbExtra can change in the fixed host prefix.
  for (auto offset : {sfio::tpl::cbStruct, sfio::tpl::cbExtra}) {
    std::fill_n(fixedBefore.begin()+offset, 4, BYTE{0});
    std::fill_n(fixedAfter.begin()+offset, 4, BYTE{0});
  }
  return std::equal(fixedBefore.begin(), fixedBefore.begin()+sfio::tpl::abExtra, fixedAfter.begin()) &&
    std::equal(before.b.begin()+sfio::tpl::abExtra+before.U32(sfio::tpl::cbExtra), before.b.end(),
               after.b.begin()+sfio::tpl::abExtra+after.U32(sfio::tpl::cbExtra), after.b.end());
}
Json Request(const char* id = "session-one") {
  return {{"protocol",1}, {"sessionId",id}, {"templateName","wrong/stale name"},
    {"ownerHwnd","1"}, {"dllVersion","offline-b6"}, {"coreVersion","test"},
    {"context",{{"hostVersion",nullptr},{"project",nullptr},{"media",nullptr}}},
    {"baseRecipe",nullptr}, {"extensions",{{"requestKeep",true}}}};
}
Json Apply(const Json& recipe, const char* id = "session-one") {
  return {{"protocol",1},{"sessionId",id},{"action","apply"},{"recipe",recipe},
          {"origin",{{"presetId","edited-source"},{"revision",4},{"name","Edited source"}}}};
}

struct Allocator final : sfio::ISfHostAllocator {
  ULONG refs = 1;
  int allocs = 0, frees = 0;
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID, void**) override { return E_NOINTERFACE; }
  ULONG STDMETHODCALLTYPE AddRef() override { return ++refs; }
  ULONG STDMETHODCALLTYPE Release() override { return --refs; }
  void* STDMETHODCALLTYPE Alloc(SIZE_T size) override { ++allocs; return std::calloc(1,size); }
  void STDMETHODCALLTYPE Free(void* memory) override { ++frees; std::free(memory); }
};
struct Holder final : sfio::ISfFileIOTemplateEditHolder {
  Tpl saved;
  Allocator& alloc;
  ULONG refs = 1;
  int commits = 0;
  HRESULT result = S_OK;
  Holder(Tpl value, Allocator& allocator) : saved(std::move(value)), alloc(allocator) {}
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void** out) override {
    if (!out) return E_POINTER;
    *out = nullptr;
    if (iid != IID_IUnknown && iid != __uuidof(sfio::ISfFileIOTemplateEditHolder)) return E_NOINTERFACE;
    *out = static_cast<sfio::ISfFileIOTemplateEditHolder*>(this); AddRef(); return S_OK;
  }
  ULONG STDMETHODCALLTYPE AddRef() override { return ++refs; }
  ULONG STDMETHODCALLTYPE Release() override { return --refs; }
  HRESULT STDMETHODCALLTYPE Slot3(sfio::SFTEMPLATE** out) override {
    if (!out) return E_POINTER;
    *out = static_cast<sfio::SFTEMPLATE*>(alloc.Alloc(saved.b.size()));
    if (!*out) return E_OUTOFMEMORY;
    std::memcpy(*out, saved.b.data(), saved.b.size()); return S_OK;
  }
  HRESULT STDMETHODCALLTYPE Slot4(const sfio::SFTEMPLATE* input) override {
    ++commits;
    if (result != S_OK) return result;
    auto next = Tpl::Copy(input); saved.b.swap(next.b); return S_OK;
  }
  HRESULT STDMETHODCALLTYPE Slot5(sfio::SFTEMPLATE**) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE Slot6(LONG, LONG*) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE Slot7(LONG, LONG) override { return E_NOTIMPL; }
};

void Placement(const Json& bundle) {
  for (const auto& fixture : bundle.at("fixtures")) {
    const auto empty = Empty();
    const auto original = empty.b;
    const auto snapshot = Snapshot(fixture.at("recipe"));
    const auto value = CreateRecipeTemplate(empty, owner, snapshot);
    Check(Tpl::Valid(value.Ptr(),value.b.size()) && empty.b == original, "fresh placement is valid and leaves source unchanged");
    Check(Same(ReadRecipeSnapshot(value,owner),snapshot), "core envelope/snapshot roundtrip including origin/preferences/extensions");
    Check(PreservesHost(empty,value) && value.Name() == empty.Name() && value.Notes() == empty.Notes(),
          "fixed fields, raw UTF-16 and opaque trailing bytes preserved");
    auto larger = snapshot;
    larger["recipe"]["notes"] = std::string(2000,'x');
    auto grown = ReplaceRecipeSnapshot(value,owner,larger);
    Check(PreservesHost(value,grown) && Same(ReadRecipeSnapshot(grown,owner),larger), "larger snapshot relocates entire host suffix");
    auto shrunk = ReplaceRecipeSnapshot(grown,owner,snapshot);
    Check(shrunk.b == value.b, "shrinking restores exact canonical/native bytes");
    auto odd = snapshot;
    // Force each parity rather than relying on a fixture's serialized length.
    for (int parity = 0; parity < 2; ++parity) {
      odd["extensions"]["parity"] = "x";
      if (ve::EncodePayload(odd).size()%2 != static_cast<size_t>(parity)) odd["extensions"]["parity"] = "xx";
      const auto placed = ReplaceRecipeSnapshot(value,owner,odd);
      Check(placed.U32(sfio::tpl::cbExtra)%2 == static_cast<DWORD>(parity) && PreservesHost(value,placed) &&
            placed.Name() == empty.Name(), "odd/even payload spans do not assume wchar alignment");
    }
  }
  const auto snapshot = Snapshot(bundle.at("fixtures")[0].at("recipe"));
  const auto value = CreateRecipeTemplate(Empty(),owner,snapshot);
  auto foreign = value; foreign.SetGuid(sfio::tpl::iidOwner, IID_IUnknown);
  Check(Rejects([&] { ReadRecipeSnapshot(foreign,owner); }), "foreign owner rejected");
  auto truncated = value; truncated.b.pop_back();
  Check(Rejects([&] { ReadRecipeSnapshot(truncated,owner); }), "truncated declared template rejected");
  auto overflow = value; overflow.SetU32(sfio::tpl::cbExtra,0xFFFFFFFF);
  Check(Rejects([&] { ReplaceRecipeSnapshot(overflow,owner,snapshot); }), "overflowing private span rejected before payload read");
  auto trailing = value; trailing.b.push_back(0);
  Check(Rejects([&] { ReadRecipeSnapshot(trailing,owner); }), "ambiguous unowned bytes after cbStruct rejected");
  auto proof = Tpl::Make(L"Proof",L"No migration",64); proof.SetGuid(sfio::tpl::iidOwner,owner);
  proof.SetU32(sfio::tpl::abExtra,0x434E4556); proof.SetU32(sfio::tpl::abExtra+4,1);
  const auto prior = proof.b;
  Check(Rejects([&] { ReadRecipeSnapshot(proof,owner); }) &&
        Rejects([&] { ReplaceRecipeSnapshot(proof,owner,snapshot); }) &&
        Rejects([&] { CreateRecipeTemplate(proof,owner,snapshot); }) && proof.b == prior,
        "proof cannot be read/replaced/initialized as product recipe");
  for (size_t offset : {size_t(4),size_t(6),size_t(12),size_t(16),size_t(20)}) {
    auto bad = value; bad.b[sfio::tpl::abExtra+offset] ^= 1; const auto preserved = bad.b;
    Check(Rejects([&] { ReplaceRecipeSnapshot(bad,owner,snapshot); }) && bad.b == preserved,
          "future/flags/CRC/schema/reserved payload rejection preserves bytes");
  }
  auto huge = Empty(); huge.b.resize(Tpl::kMaxBytes); huge.SetU32(sfio::tpl::cbStruct,static_cast<DWORD>(huge.b.size()));
  Check(Rejects([&] { CreateRecipeTemplate(huge,owner,snapshot); }), "host allocation growth limit enforced");
  auto tooLarge = snapshot; tooLarge["extensions"]["huge"] = std::string(VE_CORE_PAYLOAD_LIMIT,'x');
  Check(Rejects([&] { ReplaceRecipeSnapshot(value,owner,tooLarge); }), "core 16 KiB envelope limit retained at native boundary");
}

void Sessions(const Json& recipe) {
  const auto snapshot = Snapshot(recipe);
  auto value = CreateRecipeTemplate(Empty(),owner,snapshot);
  RecipeTemplateDraft draft(value,owner,"b6-offline");
  Check(!draft.Dirty() && !draft.Editing(), "draft starts clean with an owned snapshot");
  auto independent = draft.Snapshot(); independent["recipe"]["name"] = "external mutation";
  Check(Same(draft.Snapshot(),snapshot), "snapshot getter does not expose mutable draft storage");
  int calls = 0;
  auto saved = value;
  auto store = [&](const Tpl& next) { ++calls; auto copy = next; saved.b.swap(copy.b); return S_OK; };
  Check(draft.Commit(store) == S_OK && calls == 0, "clean Apply does not call host store");
  auto request = draft.BeginEdit(Request());
  Check(Same(request.at("recipe"),recipe) && request.at("templateName") == vegas_encoder::Utf8(value.Name().c_str()) &&
        request.at("context").at("media").is_null() && request.at("extensions").at("requestKeep") == true,
        "C4 request uses actual snapshot/name and preserves unknown/null context");
  Check(Rejects([&] { draft.BeginEdit(Request("another")); }) && draft.Editing(), "second editor cannot replace active transaction");
  Check(draft.Commit(store) == E_PENDING && calls == 0 && Rejects([&] { draft.Prepare(); }),
        "host Apply is blocked while editor is active");
  auto changed = recipe; changed["video"]["quality"] = 19;
  auto apply = Apply(changed);
  Check(draft.FinishEdit(apply,0).disposition == EditDisposition::applied && draft.Dirty(), "editor Apply changes draft only");
  Check(saved.b == value.b && Same(ReadRecipeSnapshot(value,owner),snapshot), "editor result does not touch stored template");
  Check(Same(draft.Snapshot().at("vegasPrefs"),snapshot.at("vegasPrefs")) &&
        Same(draft.Snapshot().at("extensions"),snapshot.at("extensions")), "edited recipe preserves snapshot preferences/unknown metadata");
  Check(draft.FinishEdit(apply,0).disposition == EditDisposition::noSession, "duplicate terminal result cannot apply twice");
  const auto pending = draft.Snapshot();
  Check(draft.Commit([&](const Tpl&) { ++calls; return E_ACCESSDENIED; }) == E_ACCESSDENIED &&
        draft.Dirty() && saved.b == value.b && draft.Snapshot() == pending, "failed host Apply leaves draft dirty and stored bytes intact");
  Check(draft.Commit([](const Tpl&) { return S_FALSE; }) == S_FALSE && draft.Dirty(), "only S_OK accepts committed baseline");
  Check(draft.Commit([](const Tpl&) -> HRESULT { throw std::bad_alloc(); }) == E_OUTOFMEMORY && draft.Dirty(),
        "allocation exception during commit is contained without accepting draft");
  Check(draft.Commit(store) == S_OK && !draft.Dirty() && Same(ReadRecipeSnapshot(saved,owner),pending),
        "successful host Apply copies bytes and accepts a clean baseline");
  RecipeTemplateDraft reopened(saved,owner,"reopened");
  Check(Same(reopened.Snapshot(),pending) && !reopened.Dirty(), "owned save/reload has independent committed settings (fake only)");
  request = draft.BeginEdit(Request("unchanged"));
  auto noChange = Apply(pending.at("recipe"),"unchanged"); noChange["origin"] = pending.at("origin");
  Check(draft.FinishEdit(noChange,0).disposition == EditDisposition::applied && !draft.Dirty(),
        "unchanged editor Apply does not create writer-only changes");
  draft.BeginEdit(Request("reordered"));
  auto reordered = Json::object();
  for (auto it = pending.at("recipe").rbegin(); it != pending.at("recipe").rend(); ++it) reordered[it.key()] = it.value();
  auto reorderedResult = Apply(reordered,"reordered"); reorderedResult["origin"] = pending.at("origin");
  Check(draft.FinishEdit(reorderedResult,0).disposition == EditDisposition::applied && !draft.Dirty(),
        "editor object-key reordering cannot manufacture a setting edit");
  for (int which = 0; which < 6; ++which) {
    draft.BeginEdit(Request("cancel-case"));
    Json result = Apply(recipe,"cancel-case"); DWORD exit = 0;
    if (which == 0) result = nullptr;
    if (which == 1) result["protocol"] = 2;
    if (which == 2) result["sessionId"] = "foreign";
    if (which == 3) exit = 7;
    if (which == 4) result = {{"protocol",1},{"sessionId","cancel-case"},{"action","cancel"}};
    if (which == 5) result["recipe"] = "malformed";
    Check(draft.FinishEdit(result,exit).disposition == EditDisposition::cancelled &&
          !draft.Editing() && draft.Snapshot() == pending, "missing/future/mismatched/crashed/cancel/malformed result preserves prior Apply");
  }
  for (int which = 0; which < 3; ++which) {
    auto invalid = pending.at("recipe");
    if (which == 0) invalid["video"]["quality"] = 1000;
    if (which == 1) { invalid["command"]["mode"] = "template"; invalid["command"]["template"] = "{inputs} -c:v libx264 \"unterminated {output}"; }
    if (which == 2) invalid["notes"] = std::string(VE_CORE_PAYLOAD_LIMIT,'x');
    draft.BeginEdit(Request("invalid"));
    const auto outcome = draft.FinishEdit(Apply(invalid,"invalid"),0);
    Check(outcome.disposition == EditDisposition::rejected && ve::HasErrors(outcome.issues) &&
          draft.Snapshot() == pending, "core domain/lint/size rejection preserves prior draft");
  }
  auto badRequest = Request(); badRequest["ownerHwnd"] = "0";
  Check(Rejects([&] { draft.BeginEdit(badRequest); }) && !draft.Editing(), "invalid request never opens transaction");
  auto hugeRequest = Request(); hugeRequest["extensions"]["huge"] = std::string(VE_CORE_JSON_LIMIT,'x');
  Check(Rejects([&] { draft.BeginEdit(hugeRequest); }) && !draft.Editing(), "oversize C4 request never opens transaction");
  draft.BeginEdit(Request("oversize-result"));
  auto hugeResult = Apply(recipe,"oversize-result"); hugeResult["extensions"]["huge"] = std::string(VE_CORE_JSON_LIMIT,'x');
  Check(draft.FinishEdit(hugeResult,0).disposition == EditDisposition::cancelled && draft.Snapshot() == pending,
        "oversize C4 result consumes only its session and preserves draft");
  Json missingCaps{{"encoders",Json::object()}};
  draft.BeginEdit(Request("missing-encoder"),missingCaps);
  Check(draft.FinishEdit(Apply(recipe,"missing-encoder"),0).disposition == EditDisposition::rejected &&
        draft.Snapshot() == pending, "native core checks selected-FFmpeg capability snapshot");
  draft.BeginEdit(Request("later"));
  auto later = recipe; later["video"]["quality"] = 20;
  Check(draft.FinishEdit(Apply(later,"later"),0).disposition == EditDisposition::applied && draft.Dirty(), "second independent editor draft");
  draft.Discard();
  Check(!draft.Dirty() && draft.Snapshot() == pending, "unapplied changes discard to last successful host Apply");
  draft.BeginEdit(Request("closed-page")); draft.Discard();
  Check(draft.FinishEdit(Apply(recipe,"closed-page"),0).disposition == EditDisposition::noSession,
        "late editor result after disconnect cannot leak into draft");
  HRESULT workerResult = S_OK; bool workerReadRejected = false;
  std::thread worker([&] { workerResult = draft.Commit(store); workerReadRejected = Rejects([&] { draft.Snapshot(); }); });
  worker.join();
  Check(workerResult == RPC_E_WRONG_THREAD && workerReadRejected && !draft.Dirty(), "draft/host commit stay on creator UI thread");
  const auto immutableRender = ReadRecipeSnapshot(saved,owner);
  draft.BeginEdit(Request("render-independence")); draft.FinishEdit(Apply(later,"render-independence"),0);
  Check(Same(immutableRender,pending), "existing render snapshot is independent of later UI edits/library state");

  // Exercise the existing measured holder/allocator bridge with variable recipe
  // bytes; this is a fake holder, never a real persistence gate.
  Allocator allocator; Holder holder(saved,allocator);
  IProofTemplateStore* native = nullptr;
  Check(CreateNativeTemplateStore(&holder,&allocator,&native) == S_OK && native,
        "recipe draft uses existing holder/allocator ownership boundary");
  Tpl loaded; Check(native->Load(&loaded) == S_OK && loaded.b == saved.b && allocator.allocs == allocator.frees,
                    "variable recipe read is copied/released through matching allocator");
  RecipeTemplateDraft nativeDraft(loaded,owner,"native-offline");
  nativeDraft.BeginEdit(Request("native")); nativeDraft.FinishEdit(Apply(later,"native"),0);
  holder.result = E_ACCESSDENIED;
  auto nativeStore = [&](const Tpl& next) { return native->Commit(&next); };
  Check(nativeDraft.Commit(nativeStore) == E_ACCESSDENIED && holder.saved.b == loaded.b && nativeDraft.Dirty(),
        "holder refusal preserves both committed bytes and dirty snapshot");
  holder.result = S_OK;
  Check(nativeDraft.Commit(nativeStore) == S_OK && !nativeDraft.Dirty() &&
        Same(ReadRecipeSnapshot(holder.saved,owner),nativeDraft.Snapshot()), "holder retry commits independent complete recipe snapshot");
  loaded.b.clear();
  Check(!holder.saved.b.empty(), "caller storage is never retained by holder");
  native->Release();
  Check(holder.refs == 1 && allocator.refs == 1 && allocator.allocs == allocator.frees,
        "fake holder/allocator references and returned buffers balanced");
}
}
int main(int argc, char** argv) {
  try {
    if (argc != 2) throw std::runtime_error("Pass authored B0 fixtures.");
    std::ifstream file(argv[1],std::ios::binary);
    if (!file) throw std::runtime_error("Missing fixture input.");
    const std::string bytes((std::istreambuf_iterator<char>(file)),{});
    const auto bundle = ve::Parse(reinterpret_cast<const uint8_t*>(bytes.data()),bytes.size());
    Placement(bundle);
    Sessions(bundle.at("fixtures")[0].at("recipe"));
    printf("B6 OFFLINE SNAPSHOT/SESSION PASSED: %d checks; owned bytes/fake holder, no VEGAS/process/UI\n", checks);
    return 0;
  } catch (const std::exception& error) {
    printf("B6 FAILED after %d checks: %s\n",checks,error.what()); return 1;
  }
}
