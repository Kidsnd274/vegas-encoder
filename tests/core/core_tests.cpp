#include "../../src/core/core.h"
#include <chrono>
#include <fstream>
#include <future>
#include <iostream>
#include <iterator>
#include <limits>
#include <random>

namespace {
int checks = 0;
void Check(bool ok, const std::string& message) { ++checks; if (!ok) throw std::runtime_error(message); }
using Call = ve_status (*)(const uint8_t*,uint32_t,ve_buffer*);
ve::Json CallJson(Call operation, const ve::Json& request) {
    const auto text = request.dump(); ve_buffer out{};
    const auto status = operation(reinterpret_cast<const uint8_t*>(text.data()),static_cast<uint32_t>(text.size()),&out);
    std::string returned;
    if (out.data) returned.assign(reinterpret_cast<const char*>(out.data),out.length);
    ve_free(out.data);
    if (status != VE_OK) throw std::runtime_error("C ABI status " + std::to_string(status) + ": " + returned);
    return ve::Json::parse(returned);
}
void BadJson(const std::string& text, ve_status expected) {
    ve_buffer out{};
    const auto status = ve_recipe_normalize(reinterpret_cast<const uint8_t*>(text.data()),static_cast<uint32_t>(text.size()),&out);
    Check(status == expected,"malformed input returns contained status");
    Check(out.data && out.length,"transport failure has actionable error JSON");
    if (out.data) { const auto error = ve::Json::parse(out.data,out.data+out.length); Check(error.contains("error"),"error envelope"); }
    ve_free(out.data);
}
}
int main(int argc, char** argv) {
    try {
        if (argc != 2) throw std::runtime_error("Pass schema/fixtures/b0/core-and-services.json.");
        std::ifstream file(argv[1],std::ios::binary); if (!file) throw std::runtime_error("Cannot read fixtures.");
        const std::string data((std::istreambuf_iterator<char>(file)),std::istreambuf_iterator<char>());
        const auto bundle = ve::Json::parse(data);
        for (const auto& f : bundle.at("fixtures")) {
            std::cout << "Native fixture " << ve::Str(f.at("recipe"),"id") << std::endl;
            const auto result = CallJson(ve_compile,{{"recipe",f.at("recipe")},{"media",f.at("media")},{"paths",f.at("paths")}});
            Check(!ve::HasErrors(result.at("issues")),"built-in semantics");
            Check(result.at("argv") == f.at("compile").at("argv"),"golden argv parity");
        }
        const auto& f = bundle.at("fixtures")[0];
        auto recipe = f.at("recipe");
        const auto original = recipe.dump();
        auto request = ve::Json{{"recipe",recipe},{"media",f.at("media")},{"paths",f.at("paths")}};
        const auto result = CallJson(ve_compile,request);
        Check(recipe.dump() == original,"input recipe is not mutated");
        Check(result.at("resolved").at("gopFrames") == 60,"fractional rate and keyframe timing");
        for (const auto& argument : {std::string(""),std::string("simple"),std::string("with space"),std::string("C:\\with space\\"),std::string("a\\\\\"b"),std::string("\"quoted\""),std::string(u8"🧪 出力\\")}) {
            const auto words = ve::Tokenize(ve::Quote(argument));
            Check(words.size() == 1 && words[0].text == argument,"CRT quoting/tokenizing round trip");
        }
        BadJson("{",VE_INVALID_JSON);
        BadJson("{\"recipe\":{},\"recipe\":{}}",VE_INVALID_JSON);
        BadJson(std::string("{\"text\":\"") + static_cast<char>(0xff) + "\"}",VE_INVALID_JSON);
        BadJson("{\"recipe\":{\"schema\":9223372036854775808}}",VE_INVALID_JSON);
        BadJson("{\"unknown\":-9223372036854775809}",VE_INVALID_JSON);
        BadJson("{\"unknown\":18446744073709551616}",VE_INVALID_JSON);
        const std::string integerText = "{\"lo\":-9223372036854775808,\"hi\":9223372036854775807}";
        const auto integerBounds = ve::Parse(reinterpret_cast<const uint8_t*>(integerText.data()),integerText.size());
        Check(integerBounds.at("lo") == std::numeric_limits<int64_t>::min(),"signed integer minimum preserved");
        Check(integerBounds.at("hi") == std::numeric_limits<int64_t>::max(),"signed integer maximum preserved");
        BadJson(std::string(70,'[') + "0" + std::string(70,']'),VE_LIMIT_EXCEEDED);
        BadJson(std::string(VE_CORE_JSON_LIMIT+1,' '),VE_LIMIT_EXCEEDED);
        ve_buffer empty{};
        Check(ve_compile(nullptr,0,&empty) == VE_INVALID_ARGUMENT,"null counted input"); ve_free(empty.data);
        Check(ve_profiles(nullptr) == VE_INVALID_ARGUMENT,"null output buffer");
        ve_buffer occupied{}; Check(ve_core_version(&occupied) == VE_OK,"allocate version");
        auto* address = occupied.data;
        Check(ve_profiles(&occupied) == VE_INVALID_ARGUMENT && occupied.data == address,"nonempty output is not overwritten or leaked"); ve_free(occupied.data);
        ve_free(nullptr);
        ve::Json snapshot{{"recipe",recipe},{"origin",nullptr},{"vegasPrefs",recipe.at("vegas")},{"writtenBy","native-test"}};
        auto payload = ve::EncodePayload(snapshot);
        const auto good = payload;
        for (size_t i = 0; i < payload.size(); ++i) {
            auto damaged = good; damaged[i] ^= 0x80;
            const auto decoded = ve::DecodePayload(damaged.data(),damaged.size());
            Check(decoded.at("snapshot").is_null(),"every single-bit payload damage is rejected");
        }
        std::mt19937 random(12345);
        for (int i = 0; i < 2000; ++i) {
            std::string fuzz; const auto length = random() % 200;
            for (size_t n = 0; n < length; ++n) fuzz += static_cast<char>(random() & 255);
            ve_buffer out{}; const auto status = ve_recipe_normalize(reinterpret_cast<const uint8_t*>(fuzz.data()),static_cast<uint32_t>(fuzz.size()),&out);
            Check(status >= VE_OK && status <= VE_INTERNAL_ERROR,"fuzz status contained"); ve_free(out.data);
        }
        std::vector<std::future<bool>> futures;
        for (int thread = 0; thread < 8; ++thread) futures.push_back(std::async(std::launch::async,[request] {
            for (int i = 0; i < 50; ++i) if (ve::HasErrors(CallJson(ve_compile,request).at("issues"))) return false;
            return true;
        }));
        for (auto& future : futures) Check(future.get(),"concurrent C ABI callers");
        std::cout << "Native/static core: " << checks << " ownership, bounds, quoting, payload, fuzz and concurrency checks passed. No host or encoder process.\n";
        return 0;
    } catch (const std::exception& e) { std::cerr << "CORE TEST FAILED: " << e.what() << '\n'; return 1; }
}
