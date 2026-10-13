#include "../core.h"
#include <cstdlib>
#include <cstring>
#include <new>

namespace {
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
ve_status ve_core_version(ve_buffer* out) { return Guard(out,[&] { return JsonBytes(ve::Json{{"core","0.2.0-b2"},{"abi",1},{"schemaMax",1},{"contracts",1},{"isFake",false}},out); }); }
ve_status ve_profiles(ve_buffer* out) { return Guard(out,[&] { return JsonBytes(ve::Profiles(),out); }); }
ve_status ve_recipe_normalize(const uint8_t* json, uint32_t length, ve_buffer* out) { return Call(json,length,out,ve::Normalize); }
ve_status ve_recipe_validate(const uint8_t* json, uint32_t length, ve_buffer* out) { return Call(json,length,out,[](const ve::Json& r) { return ve::Json{{"issues",ve::Validate(r)}}; }); }
ve_status ve_compile(const uint8_t* json, uint32_t length, ve_buffer* out) { return Call(json,length,out,ve::Compile); }
ve_status ve_template_lint(const uint8_t* json, uint32_t length, ve_buffer* out) { return Call(json,length,out,[](const ve::Json& r) { return ve::Json{{"diagnostics",ve::Lint(r)}}; }); }
ve_status ve_template_complete(const uint8_t* json, uint32_t length, ve_buffer* out) { return Call(json,length,out,ve::Complete); }
ve_status ve_estimate(const uint8_t* json, uint32_t length, ve_buffer* out) { return Call(json,length,out,ve::Estimate); }
ve_status ve_recipe_diff(const uint8_t* json, uint32_t length, ve_buffer* out) { return Call(json,length,out,[](const ve::Json& r) { return ve::Json{{"diff",ve::Diff(r)}}; }); }
ve_status ve_payload_encode(const uint8_t* json, uint32_t length, ve_buffer* out) { return Guard(out,[&] { const auto bytes = ve::EncodePayload(ve::Parse(json,length)); return Bytes(bytes.data(),bytes.size(),out); }); }
ve_status ve_payload_decode(const uint8_t* bytes, uint32_t length, ve_buffer* out) { return Guard(out,[&] { return JsonBytes(ve::DecodePayload(bytes,length),out); }); }
ve_status ve_session_request_validate(const uint8_t* json, uint32_t length, ve_buffer* out) { return Call(json,length,out,ve::SessionRequest); }
ve_status ve_session_result_validate(const uint8_t* json, uint32_t length, ve_buffer* out) { return Call(json,length,out,ve::SessionResult); }
