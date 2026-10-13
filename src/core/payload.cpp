#include "core.h"
#include <cstring>
#include <regex>

namespace ve {
namespace {
uint32_t Crc(const uint8_t* bytes, size_t length) {
    uint32_t crc = 0xffffffffu;
    for (size_t i = 0; i < length; ++i) { crc ^= bytes[i]; for (int n = 0; n < 8; ++n) crc = (crc >> 1) ^ ((crc & 1u) ? 0xedb88320u : 0u); }
    return crc ^ 0xffffffffu;
}
void Put32(std::vector<uint8_t>& bytes, size_t at, uint32_t value) {
    for (size_t n = 0; n < 4; ++n) bytes[at+n] = static_cast<uint8_t>(value >> (n * 8));
}
uint32_t Get32(const uint8_t* bytes, size_t at) {
    uint32_t value = 0; for (size_t n = 0; n < 4; ++n) value |= static_cast<uint32_t>(bytes[at+n]) << (n * 8); return value;
}
bool OriginValid(const Json& origin) {
    if (origin.is_null()) return true;
    return origin.is_object() && !Str(origin,"presetId").empty() && !Str(origin,"name").empty() &&
        origin.contains("revision") && origin.at("revision").is_number_integer() && origin.at("revision").get<int64_t>() > 0;
}
Json SnapshotIssues(const Json& snapshot) {
    if (!snapshot.is_object() || !snapshot.contains("recipe")) return Json::array({Issue("P-SNAPSHOT","error","","Payload must contain a complete recipe snapshot.")});
    Json issues = Structural(snapshot.at("recipe"));
    if (!snapshot.contains("vegasPrefs") || !snapshot.at("vegasPrefs").is_object() || !snapshot.contains("writtenBy") || !snapshot.at("writtenBy").is_string() || !OriginValid(snapshot.value("origin",Json(nullptr)))) issues.push_back(Issue("P-SNAPSHOT","error","","Payload origin, preferences or writer is invalid."));
    return issues;
}
Json PayloadFailure(const std::string& code, const std::string& message) {
    return Json{{"snapshot",nullptr},{"migrated",false},{"issues",Json::array({Issue(code,"error","",message)})}};
}
bool HandleValid(const Json& value) {
    if (!value.is_string()) return false;
    const auto handle = value.get<std::string>();
    if (handle.empty() || handle.size() > 20 || !std::regex_match(handle,std::regex("[0-9]+"))) return false;
    const auto first = handle.find_first_not_of('0');
    if (first == std::string::npos) return false;
    const auto trimmed = handle.substr(first);
    return trimmed.size() < 20 || (trimmed.size() == 20 && trimmed <= "18446744073709551615");
}
}
std::vector<uint8_t> EncodePayload(const Json& snapshot) {
    const auto issues = SnapshotIssues(snapshot);
    if (HasErrors(issues)) throw Error(VE_INVALID_ARGUMENT,"PAYLOAD-SNAPSHOT","A complete structurally valid snapshot is required; normalize it first.");
    const auto body = Canonical(snapshot);
    if (body.size() > VE_CORE_PAYLOAD_LIMIT - 32) throw Error(VE_LIMIT_EXCEEDED,"PAYLOAD-LIMIT","Template payload exceeds the draft 16 KiB envelope limit.");
    std::vector<uint8_t> bytes(32 + body.size(),0);
    std::memcpy(bytes.data(),"VEnc",4); bytes[4] = 1;
    Put32(bytes,8,static_cast<uint32_t>(body.size())); Put32(bytes,12,Crc(reinterpret_cast<const uint8_t*>(body.data()),body.size())); Put32(bytes,16,1);
    std::memcpy(bytes.data()+32,body.data(),body.size()); return bytes;
}
Json DecodePayload(const uint8_t* bytes, size_t length) {
    if (!bytes || length < 32) return PayloadFailure("P-TRUNCATED","Can't read this template's settings: envelope is missing or truncated.");
    if (length > VE_CORE_PAYLOAD_LIMIT) return PayloadFailure("P-LIMIT","Template payload exceeds the draft 16 KiB limit.");
    if (std::memcmp(bytes,"VEnc",4) != 0) return PayloadFailure("P-LEGACY","Not a Vegas Encoder product payload. Proof templates are not migrated.");
    if (bytes[4] != 1 || bytes[5] != 0) return PayloadFailure("P-VERSION","This template needs a different Vegas Encoder payload version.");
    if (bytes[6] != 0 || bytes[7] != 0 || Get32(bytes,16) != 1) return PayloadFailure("P-SCHEMA","Unsupported payload flags or recipe schema.");
    for (size_t i = 20; i < 32; ++i) if (bytes[i]) return PayloadFailure("P-RESERVED","Reserved payload bytes are not zero.");
    if (Get32(bytes,8) != length - 32) return PayloadFailure("P-LENGTH","Payload length does not match its envelope.");
    if (Get32(bytes,12) != Crc(bytes+32,length-32)) return PayloadFailure("P-CRC","Template settings checksum failed; original bytes are preserved.");
    try {
        const auto snapshot = Parse(bytes+32,length-32); const auto issues = SnapshotIssues(snapshot);
        return Json{{"snapshot",HasErrors(issues) ? Json(nullptr) : snapshot},{"migrated",false},{"issues",issues}};
    } catch (const Error&) { return PayloadFailure("P-JSON","Template settings contain invalid UTF-8 or JSON; original bytes are preserved."); }
}
Json SessionRequest(const Json& request) {
    Json issues = Json::array();
    if (!request.is_object() || !request.contains("protocol") || request.at("protocol") != 1 || !request.at("protocol").is_number_integer()) issues.push_back(Issue("S-PROTOCOL","error","protocol","Unsupported edit-session protocol."));
    if (!request.is_object()) return Json{{"request",request},{"issues",issues}};
    for (const auto& key : {"sessionId","templateName","dllVersion","coreVersion"}) if (Str(request,key).empty()) issues.push_back(Issue("S-REQUEST","error",key,"Required session text is missing."));
    if (!request.contains("ownerHwnd") || !HandleValid(request.at("ownerHwnd"))) issues.push_back(Issue("S-HWND","error","ownerHwnd","Expected a nonzero unsigned decimal HWND string."));
    if (!request.contains("recipe")) issues.push_back(Issue("S-RECIPE","error","recipe","A complete recipe snapshot is required."));
    else for (const auto& issue : Structural(request.at("recipe"))) issues.push_back(issue);
    if (!OriginValid(request.value("origin",Json(nullptr)))) issues.push_back(Issue("S-ORIGIN","error","origin","Invalid session origin."));
    if (!request.contains("context") || !request.at("context").is_object()) issues.push_back(Issue("S-CONTEXT","error","context","Expected a session context object, with null facts when unknown."));
    else for (const auto& key : {"hostVersion","project"}) if (request.at("context").contains(key) && !request.at("context").at(key).is_null() && !request.at("context").at(key).is_string()) issues.push_back(Issue("S-CONTEXT","error",std::string("context.") + key,"Expected text or null."));
    if (request.contains("baseRecipe") && !request.at("baseRecipe").is_null()) for (const auto& issue : Structural(request.at("baseRecipe"))) issues.push_back(issue);
    if (request.contains("context") && request.at("context").is_object() && request.at("context").contains("media") && !request.at("context").at("media").is_null()) {
        try { CheckMedia(request.at("context").at("media")); } catch (const Error& e) { issues.push_back(Issue("S-MEDIA","error","context.media",e.what())); }
    }
    return Json{{"request",request},{"issues",issues}};
}
Json SessionResult(const Json& result) {
    Json issues = Json::array();
    if (!result.is_object() || !result.contains("protocol") || result.at("protocol") != 1 || !result.at("protocol").is_number_integer()) issues.push_back(Issue("S-PROTOCOL","error","protocol","Unsupported edit-session protocol."));
    if (!result.is_object()) return Json{{"result",result},{"issues",issues}};
    if (Str(result,"sessionId").empty()) issues.push_back(Issue("S-RESULT","error","sessionId","Session ID is required."));
    const auto action = Str(result,"action");
    if (action != "apply" && action != "cancel") issues.push_back(Issue("S-ACTION","error","action","Expected apply or cancel."));
    if (action == "apply") {
        if (!result.contains("recipe")) issues.push_back(Issue("S-RECIPE","error","recipe","Apply requires a complete recipe."));
        else for (const auto& issue : Structural(result.at("recipe"))) issues.push_back(issue);
        if (!OriginValid(result.value("origin",Json(nullptr)))) issues.push_back(Issue("S-ORIGIN","error","origin","Invalid applied origin."));
    } else if (action == "cancel" && ((!result.value("recipe",Json(nullptr)).is_null()) || !result.value("origin",Json(nullptr)).is_null())) issues.push_back(Issue("S-CANCEL","error","recipe","Cancel must not carry a recipe draft or origin."));
    return Json{{"result",result},{"issues",issues}};
}
} // namespace ve
