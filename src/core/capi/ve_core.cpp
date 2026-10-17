#include "../core.h"
#include <cstdlib>
#include <cstring>
#include <new>
#include <list>
#include <memory>
#include <mutex>
#include <limits>

namespace {
// Bounded optimization only: no host/process/file state, no lock during core work.
struct Snapshot { std::string id; std::shared_ptr<const ve::Json> value; };
std::mutex snapshotMutex;
std::list<Snapshot> snapshots;
uint64_t nextSnapshot = 0;
void CheckNodes(const ve::Json& value, size_t& count) {
    if (++count > 65536) throw ve::Error(VE_LIMIT_EXCEEDED,"CAPABILITIES-LIMIT","Capability snapshot exceeds 65536 JSON nodes.");
    if (value.is_structured()) for (const auto& child : value) CheckNodes(child,count);
}
std::string SnapshotId(const ve::Json& request) {
    const auto id = request.find("capabilitiesId");
    if (id == request.end() || !id->is_string() || id->get_ref<const std::string&>().empty())
        throw ve::Error(VE_INVALID_ARGUMENT,"CAPABILITIES-ID","Expected a nonempty capability snapshot ID.");
    return id->get<std::string>();
}
std::shared_ptr<const ve::Json> Acquire(const ve::Json& request) {
    if (!request.contains("capabilitiesId")) return {};
    const auto id = SnapshotId(request);
    if (request.contains("capabilities") && !request.at("capabilities").is_null())
        throw ve::Error(VE_INVALID_ARGUMENT,"CAPABILITIES-CONFLICT","Supply capabilities or capabilitiesId, not both.");
    std::lock_guard<std::mutex> lock(snapshotMutex);
    for (auto i = snapshots.begin(); i != snapshots.end(); ++i) if (i->id == id) {
        const auto value = i->value; snapshots.splice(snapshots.end(),snapshots,i); return value;
    }
    throw ve::Error(VE_INVALID_ARGUMENT,"CAPABILITIES-STALE","Capability snapshot expired; submit the immutable capability object again.");
}
bool Ready(ve_buffer* out) { return out && !out->data && out->length == 0; }
ve_status Bytes(const uint8_t* data, size_t length, ve_buffer* out) {
    if (length > VE_CORE_JSON_LIMIT) throw ve::Error(VE_LIMIT_EXCEEDED,"RESULT-LIMIT","Core result exceeds 1 MiB.");
    auto* allocation = static_cast<uint8_t*>(std::malloc(length ? length : 1));
    if (!allocation) throw std::bad_alloc();
    if (length) std::memcpy(allocation,data,length);
    out->data = allocation; out->length = static_cast<uint32_t>(length); return VE_OK;
}
ve_status JsonBytes(const ve::Json& value, ve_buffer* out) {
    const auto bytes = value.dump(); return Bytes(reinterpret_cast<const uint8_t*>(bytes.data()),bytes.size(),out);
}
ve_status Failure(ve_buffer* out, ve_status status, const std::string& code, const std::string& message) noexcept {
    try {
        // Parser diagnostics can quote malformed source bytes. The error envelope
        // must still be valid UTF-8 even when the request was not.
        const auto error = ve::Json{{"error",{{"code",code},{"message",message}}}}.dump(-1,' ',false,ve::Json::error_handler_t::replace);
        Bytes(reinterpret_cast<const uint8_t*>(error.data()),error.size(),out);
    } catch (...) {}
    return status;
}
template<class Operation> ve_status Guard(ve_buffer* out, Operation operation) noexcept {
    if (!Ready(out)) return VE_INVALID_ARGUMENT;
    try { return operation(); }
    catch (const ve::Error& e) { return Failure(out,e.status,e.code,e.what()); }
    catch (const ve::Json::exception& e) { return Failure(out,VE_INVALID_ARGUMENT,"REQUEST-SHAPE",e.what()); }
    catch (const std::bad_alloc&) { return VE_OUT_OF_MEMORY; }
    catch (const std::exception& e) { return Failure(out,VE_INTERNAL_ERROR,"CORE-INTERNAL",e.what()); }
    catch (...) { return Failure(out,VE_INTERNAL_ERROR,"CORE-INTERNAL","Unexpected core error."); }
}
template<class Operation> ve_status Call(const uint8_t* json, uint32_t length, ve_buffer* out, Operation function) noexcept {
    return Guard(out,[&] { const auto input = ve::Parse(json,length); if (!input.is_object()) throw ve::Error(VE_INVALID_ARGUMENT,"REQUEST-OBJECT","Expected a request object."); return JsonBytes(function(input),out); });
}
}
uint32_t ve_core_abi_version(void) { return VE_CORE_ABI_VERSION; }
uint32_t ve_schema_max(void) { return VE_CORE_SCHEMA_MAX; }
void ve_free(void* allocation) { std::free(allocation); }
ve_status ve_core_version(ve_buffer* out) { return Guard(out,[&] { return JsonBytes(ve::Json{{"core",VE_CORE_VERSION},{"abi",VE_CORE_ABI_VERSION},{"schemaMax",VE_CORE_SCHEMA_MAX},{"contracts",VE_CORE_CONTRACTS_VERSION},{"isFake",false}},out); }); }
ve_status ve_profiles(ve_buffer* out) { return Guard(out,[&] { return JsonBytes(ve::Profiles(),out); }); }
ve_status ve_recipe_normalize(const uint8_t* json, uint32_t length, ve_buffer* out) { return Call(json,length,out,ve::Normalize); }
ve_status ve_recipe_validate(const uint8_t* json, uint32_t length, ve_buffer* out) { return Call(json,length,out,[](const ve::Json& r) { const auto caps = Acquire(r); return ve::Json{{"issues",ve::Validate(r,caps.get())}}; }); }
ve_status ve_compile(const uint8_t* json, uint32_t length, ve_buffer* out) { return Call(json,length,out,[](const ve::Json& r) { const auto caps = Acquire(r); return ve::Compile(r,caps.get()); }); }
ve_status ve_template_lint(const uint8_t* json, uint32_t length, ve_buffer* out) { return Call(json,length,out,[](const ve::Json& r) { const auto caps = Acquire(r); return ve::Json{{"diagnostics",ve::Lint(r,caps.get())}}; }); }
ve_status ve_template_complete(const uint8_t* json, uint32_t length, ve_buffer* out) { return Call(json,length,out,[](const ve::Json& r) { const auto caps = Acquire(r); return ve::Complete(r,caps.get()); }); }
ve_status ve_estimate(const uint8_t* json, uint32_t length, ve_buffer* out) { return Call(json,length,out,ve::Estimate); }
ve_status ve_recipe_diff(const uint8_t* json, uint32_t length, ve_buffer* out) { return Call(json,length,out,[](const ve::Json& r) { return ve::Json{{"diff",ve::Diff(r)}}; }); }
ve_status ve_payload_encode(const uint8_t* json, uint32_t length, ve_buffer* out) { return Guard(out,[&] { const auto bytes = ve::EncodePayload(ve::Parse(json,length)); return Bytes(bytes.data(),bytes.size(),out); }); }
ve_status ve_payload_decode(const uint8_t* bytes, uint32_t length, ve_buffer* out) { return Guard(out,[&] { return JsonBytes(ve::DecodePayload(bytes,length),out); }); }
ve_status ve_session_request_validate(const uint8_t* json, uint32_t length, ve_buffer* out) { return Call(json,length,out,ve::SessionRequest); }
ve_status ve_session_result_validate(const uint8_t* json, uint32_t length, ve_buffer* out) { return Call(json,length,out,ve::SessionResult); }

ve_status ve_capabilities_store(const uint8_t* json, uint32_t length, ve_buffer* out) {
    return Guard(out,[&] {
        auto value = ve::Parse(json,length);
        if (!value.is_object()) throw ve::Error(VE_INVALID_ARGUMENT,"CAPABILITIES-SHAPE","Expected a capability object.");
        size_t nodes = 0; CheckNodes(value,nodes);
        auto owned = std::make_shared<const ve::Json>(std::move(value));
        std::lock_guard<std::mutex> lock(snapshotMutex);
        if (nextSnapshot == std::numeric_limits<uint64_t>::max()) throw ve::Error(VE_LIMIT_EXCEEDED,"CAPABILITIES-LIMIT","Capability snapshot IDs exhausted.");
        const auto id = std::to_string(++nextSnapshot);
        // Allocate the result and list entry before evicting a valid prior entry.
        const auto status = JsonBytes(ve::Json{{"capabilitiesId",id}},out);
        try { snapshots.push_back({id,std::move(owned)}); }
        catch (...) { ve_free(out->data); out->data = nullptr; out->length = 0; throw; }
        if (snapshots.size() > 8) snapshots.pop_front();
        return status;
    });
}
ve_status ve_capabilities_release(const uint8_t* json, uint32_t length, ve_buffer* out) {
    return Call(json,length,out,[](const ve::Json& r) {
        const auto id = SnapshotId(r);
        std::lock_guard<std::mutex> lock(snapshotMutex);
        for (auto i = snapshots.begin(); i != snapshots.end(); ++i) if (i->id == id) { snapshots.erase(i); break; }
        return ve::Json::object();
    });
}

ve_status ve_macros(const uint8_t* json, uint32_t length, ve_buffer* out) { return Call(json,length,out,[](const ve::Json& r) { return ve::Json{{"macros",ve::Macros(r)}}; }); }
