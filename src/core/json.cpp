#include "core.h"
#include "profiles/data.h"
#include <limits>
#include <set>

namespace ve {
Json Parse(const uint8_t* bytes, size_t length) {
    if (!bytes || length == 0) throw Error(VE_INVALID_ARGUMENT, "EMPTY-INPUT", "Expected counted UTF-8 JSON.");
    if (length > VE_CORE_JSON_LIMIT) throw Error(VE_LIMIT_EXCEEDED, "JSON-LIMIT", "JSON exceeds the 1 MiB limit.");
    // The parser can promote an overflowing integer literal to double. Reject
    // such literals before parsing rather than losing an unknown field's bits.
    bool quoted = false;
    for (size_t i = 0; i < length; ++i) {
        const char c = static_cast<char>(bytes[i]);
        if (quoted) { if (c == '\\') ++i; else if (c == '"') quoted = false; continue; }
        if (c == '"') { quoted = true; continue; }
        if (c != '-' && (c < '0' || c > '9')) continue;
        const size_t start = i; bool decimal = false;
        while (i < length) {
            const char digit = static_cast<char>(bytes[i]);
            if (digit == '.' || digit == 'e' || digit == 'E') decimal = true;
            if ((digit < '0' || digit > '9') && digit != '.' && digit != 'e' && digit != 'E' && digit != '+' && digit != '-') break;
            ++i;
        }
        if (!decimal) {
            const bool negative = c == '-'; size_t first = start + (negative ? 1 : 0);
            while (first < i && bytes[first] == '0') ++first;
            const std::string magnitude(reinterpret_cast<const char*>(bytes+first),i-first);
            if (magnitude.size() > 19 || (magnitude.size() == 19 && magnitude > (negative ? "9223372036854775808" : "9223372036854775807")))
                throw Error(VE_INVALID_JSON,"JSON-INTEGER","JSON integer literal exceeds signed 64-bit.");
        }
        if (i) --i;
    }
    std::vector<std::set<std::string>> keys(66);
    auto callback = [&](int depth, Json::parse_event_t event, Json& value) {
        if (depth > 64) throw Error(VE_LIMIT_EXCEEDED, "JSON-DEPTH", "JSON nesting exceeds 64 levels.");
        const auto index = static_cast<size_t>(depth);
        if (event == Json::parse_event_t::object_start) keys[index + 1].clear();
        if (event == Json::parse_event_t::key && !keys[index].insert(value.get<std::string>()).second)
            throw Error(VE_INVALID_JSON, "JSON-DUPLICATE-KEY", "Duplicate JSON object key.");
        if (event == Json::parse_event_t::value && value.is_number_unsigned() &&
            value.get<uint64_t>() > static_cast<uint64_t>(std::numeric_limits<int64_t>::max()))
            throw Error(VE_INVALID_JSON, "JSON-INTEGER", "JSON integers must fit signed 64-bit.");
        return true;
    };
    try { return Json::parse(bytes, bytes + length, callback); }
    catch (const Json::exception& e) { throw Error(VE_INVALID_JSON, "INVALID-JSON", e.what()); }
}
std::string Canonical(const Json& value) { return nlohmann::json(value).dump(); }
const Json& Profiles() { static const Json data = Json::parse(data::Profiles()); return data; }
const Json& Options() { static const Json data = Json::parse(data::Options()); return data.at("encoders"); }
const Json& RecipeSchema() { static const Json data = Json::parse(data::RecipeSchema()); return data; }
std::string Str(const Json& o, const std::string& k, const std::string& fallback) {
    const auto i = o.find(k); return i != o.end() && i->is_string() ? i->get<std::string>() : fallback;
}
double Num(const Json& o, const std::string& k, double fallback) {
    const auto i = o.find(k); return i != o.end() && i->is_number() ? i->get<double>() : fallback;
}
bool Bool(const Json& o, const std::string& k, bool fallback) {
    const auto i = o.find(k); return i != o.end() && i->is_boolean() ? i->get<bool>() : fallback;
}
Json Issue(const std::string& id, const std::string& level, const std::string& field,
           const std::string& message, Json params, Json refs) {
    return Json{{"id",id},{"level",level},{"field",field},{"message",message},
                {"params",std::move(params)},{"fix",nullptr},{"tokenIndices",std::move(refs)}};
}
bool HasErrors(const Json& issues) {
    for (const auto& issue : issues) if (Str(issue,"level") == "error") return true;
    return false;
}
const Json* FindProfile(const std::string& kind, const std::string& id) {
    for (const auto& profile : Profiles().at(kind)) if (Str(profile,"id") == id) return &profile;
    return nullptr;
}
const Json* FindContainer(const std::string& id) {
    for (const auto& container : Profiles().at("containers")) if (Str(container,"id") == id) return &container;
    return nullptr;
}
const Json* EncoderOptions(const Json& caps, const std::string& id) {
    if (caps.is_object()) {
        const auto e = caps.find("encoders");
        if (e != caps.end() && e->is_object()) {
            const auto i = e->find(id);
            if (i != e->end() && i->is_object()) return &*i;
            return nullptr; // A supplied installation never silently uses another build's options.
        }
    }
    const auto i = Options().find(id); return i == Options().end() ? nullptr : &*i;
}
std::string ContainerSupport(const std::string& kind, const Json& profile,
                             const std::string& container, const Json& caps) {
    const Json* rules = &Profiles().at("compatibility");
    if (caps.is_object()) {
        const auto major = caps.find("libavformatMajor");
        const auto tables = Profiles().find("compatibilityByAvformatMajor");
        if (major != caps.end() && major->is_number_integer() && tables != Profiles().end()) {
            const auto table = tables->find(major->dump());
            // Untested majors use conservative cross-build rules, not the nearest version.
            if (table != tables->end()) rules = &*table;
        }
    }
    const auto& families = rules->at(kind);
    const auto family = Str(profile,"family");
    return families.contains(family) ? Str(families.at(family),container,"unknown") : "unknown";
}
} // namespace ve
