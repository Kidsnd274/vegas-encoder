#pragma once
#include "capi/ve_core.h"
#include "third_party/nlohmann/json.hpp"
#include <stdexcept>
#include <string>
#include <vector>

namespace ve {
using Json = nlohmann::ordered_json;
struct Error : std::runtime_error {
    ve_status status;
    std::string code;
    Error(ve_status status_, std::string code_, const std::string& message)
        : std::runtime_error(message), status(status_), code(std::move(code_)) {}
};
Json Parse(const uint8_t* bytes, size_t length);
std::string Canonical(const Json& value);
const Json& Profiles();
const Json& Options();
const Json& RecipeSchema();
std::string Str(const Json& object, const std::string& key, const std::string& fallback = "");
double Num(const Json& object, const std::string& key, double fallback = 0);
bool Bool(const Json& object, const std::string& key, bool fallback = false);
Json Issue(const std::string& id, const std::string& level, const std::string& field,
           const std::string& message, Json params = Json::object(), Json refs = Json::array());
bool HasErrors(const Json& issues);
Json Structural(const Json& recipe);
Json Validate(const Json& request);
Json Normalize(const Json& request);
Json Compile(const Json& request);
// Conservative runtime diagnostic provenance: argv indexes, executable excluded.
Json ErrorTokenIndices(const Json& compiled, const std::string& stderrTail);
Json Estimate(const Json& request);
Json Diff(const Json& request);
Json Lint(const Json& request);
Json Complete(const Json& request);
std::vector<uint8_t> EncodePayload(const Json& snapshot);
Json DecodePayload(const uint8_t* bytes, size_t length);
// Pure serialization checks; session file I/O belongs to ve_services/adapter.
Json SessionRequest(const Json& request);
Json SessionResult(const Json& result);

struct Word { std::string text; size_t start = 0; size_t end = 0; };
std::vector<Word> Tokenize(const std::string& text);
std::string Quote(const std::string& text);
size_t Utf16Offset(const std::string& text, size_t byteOffset);
size_t Utf8Offset(const std::string& text, size_t utf16Offset);
std::vector<size_t> Utf16Map(const std::string& text);
std::string OptionKey(const std::string& option);
bool IsOption(const std::string& text);
const Json* FindProfile(const std::string& kind, const std::string& encoder);
const Json* FindContainer(const std::string& container);
const Json* EncoderOptions(const Json& capabilities, const std::string& encoder);
bool ValidEncoderOption(const Json& capabilities, const std::string& encoder,
                        const std::string& kind, const std::string& flag, const std::string& value);
std::string ContainerSupport(const std::string& kind, const Json& profile,
                             const std::string& container, const Json& capabilities);
Json Resolve(const Json& recipe);
Json VideoFormat(const std::string& format);
void ReflectVideoFormatOption(Json& resolved, const std::string& key, const std::string& value);
void CheckVideoProfile(const Json& resolved, Json& issues);
Json Signal(const Json& recipe, const Json& media, const Json& resolved, const Json& capabilities = Json(nullptr));
Json Summary(const Json& recipe, const Json& resolved);
Json InputTokens(const Json& recipe, const Json& media, const Json& paths);
void CheckMedia(const Json& media);
} // namespace ve
