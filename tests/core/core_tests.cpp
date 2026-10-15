#include "../../src/core/core.h"
#include <algorithm>
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
void Reject(Call operation, const ve::Json& request, const std::string& code) {
    const auto text = request.dump(); ve_buffer out{};
    const auto status = operation(reinterpret_cast<const uint8_t*>(text.data()),static_cast<uint32_t>(text.size()),&out);
    const auto error = out.data ? ve::Json::parse(out.data,out.data+out.length) : ve::Json(); ve_free(out.data);
    Check(status != VE_OK && error.at("error").at("code") == code,"contained " + code);
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
        if (argc != 3) throw std::runtime_error("Pass B0 source fixtures and B1 real-core argv goldens.");
        std::ifstream file(argv[1],std::ios::binary); if (!file) throw std::runtime_error("Cannot read fixtures.");
        const std::string data((std::istreambuf_iterator<char>(file)),std::istreambuf_iterator<char>());
        const auto bundle = ve::Json::parse(data);
        std::ifstream goldenFile(argv[2],std::ios::binary); if (!goldenFile) throw std::runtime_error("Cannot read B1 argv goldens.");
        const auto goldens = ve::Json::parse(std::string((std::istreambuf_iterator<char>(goldenFile)),std::istreambuf_iterator<char>()));
        for (const auto& f : bundle.at("fixtures")) {
            std::cout << "Native fixture " << ve::Str(f.at("recipe"),"id") << std::endl;
            const auto result = CallJson(ve_compile,{{"recipe",f.at("recipe")},{"media",f.at("media")},{"paths",f.at("paths")}});
            Check(!ve::HasErrors(result.at("issues")),"built-in semantics");
            Check(result.at("argv") == goldens.at("argv").at(ve::Str(f.at("recipe"),"id")),"B1 real-core golden argv parity");
            auto advancedRecipe = f.at("recipe"); advancedRecipe["command"]["mode"] = "template";
            advancedRecipe["command"]["template"] = result.at("advancedTemplate");
            const auto seeded = CallJson(ve_compile,{{"recipe",advancedRecipe},{"media",f.at("media")},{"paths",f.at("paths")}});
            Check(seeded.at("argv") == result.at("argv"),"Basic seed preserves input tagging in Advanced");
        }
        for (size_t i = 0; i < bundle.at("additionalFixtures").size(); ++i) {
            const auto& popup = bundle.at("additionalFixtures")[i];
            const auto result = CallJson(ve_compile,{{"recipe",popup.at("recipe")},{"media",popup.at("media")},{"paths",popup.at("paths")}});
            Check(!ve::HasErrors(result.at("issues")),"existing popup semantics");
            Check(result.at("argv") == goldens.at("additionalArgv")[i],"existing popup context has distinct argv golden");
        }
        const auto& f = bundle.at("fixtures")[0];
        auto recipe = f.at("recipe");
        auto normalized = CallJson(ve_recipe_normalize,{{"recipe",recipe}});
        Check(normalized.at("requiredEncoders") == ve::Json::array({"libx264","aac"}),"Basic requirements come from core");
        auto requirementRecipe = recipe;
        requirementRecipe["audio"][0]["enabled"] = false;
        Check(CallJson(ve_recipe_normalize,{{"recipe",requirementRecipe}}).at("requiredEncoders") == ve::Json::array({"libx264"}),"disabled audio is not a requirement");
        requirementRecipe["command"] = {{"mode","template"},{"template","{inputs} -c:v ffv1 {output}"}};
        Check(CallJson(ve_recipe_normalize,{{"recipe",requirementRecipe}}).at("requiredEncoders").is_null(),"Advanced requirements do not use inactive Basic controls");
        requirementRecipe["schema"] = 2;
        Check(CallJson(ve_recipe_normalize,{{"recipe",requirementRecipe}}).at("requiredEncoders").is_null(),"invalid recipe requirements remain unknown");
        const auto original = recipe.dump();
        auto request = ve::Json{{"recipe",recipe},{"media",f.at("media")},{"paths",f.at("paths")}};
        const auto result = CallJson(ve_compile,request);
        Check(result.at("expectedStreams") == ve::Json::array({{{"kind","video"},{"encoder","libx264"},{"codec","h264"}},{{"kind","audio"},{"encoder","aac"},{"codec","aac"}}}),"Basic verification codecs are native facts");
        auto verificationRequest = request;
        verificationRequest["recipe"]["audio"][0]["enabled"] = false;
        Check(CallJson(ve_compile,verificationRequest).at("expectedStreams").size() == 1,"disabled audio is absent from verification");
        verificationRequest = request; verificationRequest["media"]["audio"] = nullptr;
        Check(CallJson(ve_compile,verificationRequest).at("expectedStreams").size() == 1,"undelivered audio is absent from verification");
        verificationRequest = request;
        verificationRequest["recipe"]["command"] = {{"mode","template"},{"template",result.at("advancedTemplate")}};
        Check(CallJson(ve_compile,verificationRequest).at("expectedStreams") == result.at("expectedStreams"),"Advanced seed preserves verification facts");
        verificationRequest["recipe"]["command"]["template"] = "{inputs} -map 0:v:0 -c:v ffv1 {output}";
        Check(CallJson(ve_compile,verificationRequest).at("expectedStreams") == ve::Json::array({{{"kind","video"},{"encoder","ffv1"},{"codec","ffv1"}}}),"explicit video-only map does not claim audio output");
        verificationRequest["recipe"]["command"]["template"] = "{inputs} -c:v ffv1 -an {output}";
        Check(CallJson(ve_compile,verificationRequest).at("expectedStreams").size() == 1,"Advanced an disables verification audio");
        verificationRequest["recipe"]["command"]["template"] = "{inputs} -c:v ve_unknown -c:a ve_unknown_audio {output}";
        auto verification = CallJson(ve_compile,verificationRequest).at("expectedStreams");
        Check(verification[0].at("codec").is_null() && verification[1].at("codec").is_null(),"unestablished codecs remain unknown");
        verificationRequest["capabilities"] = {{"encoders",{{"ve_unknown",{{"kind","video"},{"codec","h264"}}}}}};
        Check(CallJson(ve_compile,verificationRequest).at("expectedStreams")[0].at("codec") == "h264","captured canonical codec supplies verification fact");
        verificationRequest.erase("capabilities");
        for (const auto& text : {"{inputs} -i extra.mkv -c:v ffv1 {output}","{inputs} -c:v ffv1 extra.mkv {output}","{inputs} -map 0 -c:v ffv1 {output}","{inputs} -map 0:v:0 -map 0:v:0 -c:v ffv1 {output}","{inputs} -filter_complex null -c:v ffv1 {output}"}) {
            verificationRequest["recipe"]["command"]["template"] = text;
            Check(CallJson(ve_compile,verificationRequest).at("expectedStreams").is_null(),"general input/output/maps/complex-filter scope remains unknown");
        }
        verificationRequest = request;
        verificationRequest["recipe"]["video"]["encoder"] = "dnxhd";
        verificationRequest["recipe"]["audio"][0]["encoder"] = "pcm_f32le";
        verificationRequest["recipe"]["audio"][0]["mode"] = "lossless";
        verification = CallJson(ve_compile,verificationRequest).at("expectedStreams");
        Check(verification[0].at("codec") == "dnxhd" && verification[1].at("codec") == "pcm_f32le","DNxHR family and PCM names map to FFprobe codecs");
        auto b1Recipe = f.at("recipe");
        b1Recipe["video"]["profile"] = nullptr; b1Recipe["video"]["depth"] = 10;
        auto b1Request = ve::Json{{"recipe",b1Recipe},{"media",f.at("media")},{"paths",f.at("paths")}};
        auto b1Result = CallJson(ve_compile,b1Request);
        Check(!ve::HasErrors(b1Result.at("issues")) && b1Result.at("resolved").at("profile") == "high10","10-bit x264 unset profile follows depth");
        b1Request["recipe"]["video"]["profile"] = "high";
        Check(ve::HasErrors(CallJson(ve_recipe_validate,b1Request).at("issues")),"explicit high profile with 10-bit pixels is rejected");
        for (const auto& extra : {"-profile:v high10","-pix_fmt yuv420p"}) {
            b1Request["recipe"]["video"]["extra"] = extra;
            b1Result = CallJson(ve_compile,b1Request);
            Check(!ve::HasErrors(CallJson(ve_recipe_validate,b1Request).at("issues")) && !ve::HasErrors(b1Result.at("issues")),"final Extra profile/pixel combination supersedes displaced controls");
            Check(extra == std::string("-profile:v high10") ? b1Result.at("resolved").at("profile") == "high10" && b1Result.at("resolved").at("depth") == 10 :
                  b1Result.at("resolved").at("profile") == "high" && b1Result.at("resolved").at("depth") == 8,"resolved profile/depth matches valid Extra replacement");
        }
        b1Request["recipe"]["video"]["depth"] = 8;
        b1Request["recipe"]["video"]["extra"] = "-pix_fmt yuv420p10le";
        Check(ve::HasErrors(CallJson(ve_recipe_validate,b1Request).at("issues")) && ve::HasErrors(CallJson(ve_compile,b1Request).at("issues")),"Extra can introduce an incompatible final profile/depth");
        b1Request["recipe"]["video"]["profile"] = "high10";
        b1Request["recipe"]["video"]["extra"] = "-vf scale=320:180,format=yuv420p10le -pix_fmt +yuv420p10le";
        b1Request["capabilities"] = {{"encoders",{{"libx264",{{"kind","video"},{"options",ve::Json::array()},{"pixelFormats",ve::Json::array({"yuv420p","yuv420p10le"})}}},{"aac",{{"kind","audio"},{"options",ve::Json::array()}}}}}};
        b1Result = CallJson(ve_compile,b1Request);
        Check(!ve::HasErrors(CallJson(ve_recipe_validate,b1Request).at("issues")) && !ve::HasErrors(b1Result.at("issues")),"FFmpeg exact pixel-format modifier is accepted against build capabilities");
        Check(std::find(b1Result.at("argv").begin(),b1Result.at("argv").end(),ve::Json("+yuv420p10le")) != b1Result.at("argv").end() &&
              b1Result.at("resolved").at("pixfmt") == "yuv420p10le" && b1Result.at("signalPath").at("video").at("outputBits") == 10,"plus syntax is preserved while resolved format facts use the format name");
        for (const auto& format : {"+","+ve_unknown_format"}) {
            b1Request["recipe"]["video"]["extra"] = std::string("-pix_fmt ") + format;
            b1Request["capabilities"] = nullptr;
            b1Result = CallJson(ve_compile,b1Request);
            Check(!ve::HasErrors(CallJson(ve_recipe_validate,b1Request).at("issues")) && b1Result.at("resolved").is_null() &&
                  b1Result.at("signalPath").at("video").at("outputBits").is_null(),"automatic or unmodeled exact format remains unknown");
        }
        b1Request["recipe"] = f.at("recipe"); b1Request["recipe"]["video"]["extra"] = "-crf 16 -preset faster -g 90";
        b1Result = CallJson(ve_compile,b1Request);
        for (const auto& token : b1Result.at("display")) if (ve::Str(token,"field") == "video.extra") {
            const auto text = ve::Str(token,"text");
            const auto expected = text == "-crf" || text == "16" ? "video.quality" : text == "-preset" || text == "faster" ? "video.speed" : "video.gopSec";
            Check(ve::Str(token,"replacedField") == expected,"Extra option/value replaced-control provenance");
        }
        b1Request["recipe"] = f.at("recipe"); b1Request["recipe"]["audio"][0]["encoder"] = "pcm_s24le";
        b1Request["recipe"]["audio"][0]["mode"] = "lossless";
        b1Request["capabilities"] = {{"libavformatMajor",59},{"encoders",{{"libx264",{{"kind","video"},{"options",ve::Json::array()}}},{"pcm_s24le",{{"kind","audio"},{"options",ve::Json::array()}}}}}};
        b1Result = CallJson(ve_compile,b1Request);
        Check(b1Result.at("signalPath").at("audio")[0].at("containerSupport") == "no" && ve::HasErrors(b1Result.at("issues")),"avformat59 MP4 PCM refused");
        b1Request["capabilities"]["libavformatMajor"] = 63;
        b1Result = CallJson(ve_compile,b1Request);
        Check(b1Result.at("signalPath").at("audio")[0].at("containerSupport") == "warn" && !ve::HasErrors(b1Result.at("issues")),"avformat63 MP4 PCM caveat");
        b1Request["capabilities"]["libavformatMajor"] = 999;
        Check(!ve::HasErrors(CallJson(ve_compile,b1Request).at("issues")),"unknown format major uses conservative consensus");
        b1Request["recipe"] = f.at("recipe"); b1Request["recipe"]["video"]["encoder"] = "h264_amf";
        b1Request["recipe"]["video"]["mode"] = "cqp"; b1Request["recipe"]["video"]["profile"] = nullptr;
        b1Request["recipe"]["video"]["speed"] = nullptr; b1Request["capabilities"] = nullptr;
        b1Result = CallJson(ve_compile,b1Request);
        for (const auto& flag : {"-rc","-qp_i","-qp_p","-qp_b"}) Check(std::find(b1Result.at("argv").begin(),b1Result.at("argv").end(),ve::Json(flag)) != b1Result.at("argv").end(),"AMF CQP explicit controls");
        const auto oldTuneCaps = ve::Json::parse(R"({"encoders":{"hevc_nvenc":{"options":[{"name":"tune","type":"int","min":"1","max":"4","constants":[{"name":"hq","value":"1"}]}]}}})");
        Check(!ve::ValidEncoderOption(oldTuneCaps,"hevc_nvenc","video","-tune","uhq"),"new NVENC tune is rejected by old build option data");
        Check(ve::ValidEncoderOption(oldTuneCaps,"hevc_nvenc","video","-tune","hq"),"old NVENC tune remains accepted");
        b1Request["recipe"] = f.at("recipe"); b1Request["recipe"]["video"]["extra"] = "-colorspace smpte170m";
        b1Request["capabilities"] = nullptr; b1Result = CallJson(ve_compile,b1Request);
        size_t colorTags = 0;
        for (size_t i = 0; i + 1 < b1Result.at("argv").size(); ++i) if (b1Result.at("argv")[i] == "-colorspace") {
            ++colorTags; Check(b1Result.at("argv")[i+1] == "smpte170m","Extra color tag is metadata on input and output");
        }
        Check(colorTags == 2,"input/output Extra tag policy stays aligned");
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
        auto liveRequest = request;
        liveRequest["paths"]["liveInputs"] = true;
        liveRequest["paths"]["overwriteOutput"] = true;
        auto liveResult = CallJson(ve_compile,liveRequest);
        const auto& liveArgv = liveResult.at("argv");
        Check(liveResult.at("inputStreams") == ve::Json::array({"video","audio"}),"core input facts own pipe selection");
        Check(std::count(liveArgv.begin(),liveArgv.end(),ve::Json("-y")) == 1,"core temporary output overwrite flag");
        Check(std::count(liveArgv.begin(),liveArgv.end(),ve::Json("-probesize")) == 2,"bounded raw input startup probing");
        Check(std::count(liveArgv.begin(),liveArgv.end(),ve::Json("-analyzeduration")) == 2,"raw live inputs skip analysis delay");
        Check(std::find(liveArgv.begin(),liveArgv.end(),ve::Json("-thread_queue_size")) == liveArgv.end(),"live inputs do not reintroduce rejected queue flags");
        liveRequest["recipe"]["audio"][0]["enabled"] = false;
        liveResult = CallJson(ve_compile,liveRequest);
        Check(liveResult.at("inputStreams") == ve::Json::array({"video"}),"disabled audio core input fact");
        Check(std::count(liveResult.at("argv").begin(),liveResult.at("argv").end(),ve::Json("-probesize")) == 1,"no inactive audio input options");
        const ve::Json diagnosticCommand{{"argv",ve::Json::array({"-wrong","1","-other","2","out"})}};
        Check(ve::ErrorTokenIndices(diagnosticCommand,"Unrecognized option 'wrong'.") == ve::Json::array({0}),"runtime diagnostic index excludes executable");
        Check(ve::ErrorTokenIndices(diagnosticCommand,"Error setting option other to value 2.") == ve::Json::array({2}),"runtime option setting diagnostic");
        Check(ve::ErrorTokenIndices(diagnosticCommand,"Generic hardware failure.").empty(),"unknown runtime provenance remains empty");
        // Immutable capability references: same results, bounded retention, no aliasing.
        const ve::Json capability{{"identityKey","same-binary"},{"encoders",{{"libx264",{{"kind","video"},{"options",ve::Json::array()}}},{"aac",{{"kind","audio"},{"options",ve::Json::array()}}}}}};
        auto id = CallJson(ve_capabilities_store,capability).at("capabilitiesId");
        auto cachedRequest = request; cachedRequest["capabilitiesId"] = id;
        auto inlineRequest = request; inlineRequest["capabilities"] = capability;
        Check(CallJson(ve_compile,cachedRequest) == CallJson(ve_compile,inlineRequest),"snapshot/inline compile parity");
        Check(CallJson(ve_recipe_validate,cachedRequest) == CallJson(ve_recipe_validate,inlineRequest),"snapshot/inline validation parity");
        const std::string command = "{inputs} -c:v libx264 -c:a aac -g {gop:2s} -b:a -2 -metadata \"-literal\" {output}";
        Check(CallJson(ve_template_lint,{{"text",command},{"capabilitiesId",id}}) == CallJson(ve_template_lint,{{"text",command},{"capabilities",capability}}),"snapshot lint parity");
        Check(CallJson(ve_template_complete,{{"text","-c:v "},{"caret",5},{"capabilitiesId",id}}) == CallJson(ve_template_complete,{{"text","-c:v "},{"caret",5},{"capabilities",capability}}),"snapshot completion parity");
        Reject(ve_compile,{{"capabilitiesId",id},{"capabilities",capability}},"CAPABILITIES-CONFLICT");
        Reject(ve_template_lint,{{"text",command},{"capabilitiesId",7}},"CAPABILITIES-ID");
        auto invalidSnapshot = capability; invalidSnapshot["huge"] = ve::Json::array();
        for (size_t i = 0; i < 65536; ++i) invalidSnapshot["huge"].push_back(0);
        Reject(ve_capabilities_store,invalidSnapshot,"CAPABILITIES-LIMIT");
        Reject(ve_capabilities_store,ve::Json::array(),"CAPABILITIES-SHAPE");
        Check(CallJson(ve_compile,cachedRequest) == CallJson(ve_compile,inlineRequest),"failed replacement preserves snapshot");
        std::vector<ve::Json> retainedIds;
        for (int i = 0; i < 8; ++i) retainedIds.push_back(CallJson(ve_capabilities_store,capability).at("capabilitiesId"));
        Reject(ve_template_lint,{{"text",command},{"capabilitiesId",id}},"CAPABILITIES-STALE");
        CallJson(ve_template_lint,{{"text",command},{"capabilitiesId",retainedIds.front()}});
        const auto lruId = CallJson(ve_capabilities_store,capability).at("capabilitiesId");
        Check(!CallJson(ve_template_lint,{{"text",command},{"capabilitiesId",retainedIds.front()}}).at("diagnostics").is_null(),"access refreshes native LRU");
        Reject(ve_template_lint,{{"text",command},{"capabilitiesId",retainedIds[1]}},"CAPABILITIES-STALE");
        CallJson(ve_capabilities_release,{{"capabilitiesId",lruId}});
        auto newestId = retainedIds.back();
        CallJson(ve_capabilities_release,{{"capabilitiesId",newestId}});
        CallJson(ve_capabilities_release,{{"capabilitiesId",newestId}});
        Reject(ve_template_lint,{{"text",command},{"capabilitiesId",newestId}},"CAPABILITIES-STALE");
        for (const auto& released : retainedIds) CallJson(ve_capabilities_release,{{"capabilitiesId",released}});
        auto metadataRequest = request; metadataRequest["recipe"]["command"] = {{"mode","template"},{"template",command}};
        const auto metadataResult = CallJson(ve_compile,metadataRequest);
        auto userToken = [&](const std::string& text) -> ve::Json { for (const auto& t : metadataResult.at("display")) if (ve::Str(t,"field") == "command.template" && ve::Str(t,"text") == text) return t; throw std::runtime_error("Missing user token " + text); };
        Check(userToken("-c:v").at("stage") == "video" && userToken("-c:v").at("isOption") == true,"Advanced video option stage/marker");
        Check(userToken("aac").at("stage") == "audio" && userToken("aac").at("isOption") == false,"Advanced audio value stage/marker");
        Check(userToken("-2").at("isOption") == false && userToken("-literal").at("isOption") == false,"negative and quoted dash values are values");
        Check(userToken("60").at("role") == "macro" && userToken("60").at("stage") == "video" && userToken("60").at("macros") == ve::Json::array({"{gop:2s}"}),"macro identity retains stage");
        Check(userToken(ve::Str(request.at("paths"),"output")).at("role") == "output","output macro retains locked-chip role");
        Check(metadataResult.at("summary").at("videoEncoderId") == "libx264" && metadataResult.at("summary").at("audioEncoderId") == "aac","Advanced encoder IDs");
        metadataRequest["recipe"]["command"]["template"] = "{inputs} -c libx264 {output}";
        Check(CallJson(ve_compile,metadataRequest).at("summary").at("videoEncoderId").is_null(),"general codec scope ID remains unknown");
        metadataRequest["recipe"]["command"]["template"] = "{inputs} -c:v libx264 -map 2:v {output}";
        Check(CallJson(ve_compile,metadataRequest).at("summary").at("videoEncoderId").is_null(),"general source mapping ID remains unknown");
        const auto macroResult = CallJson(ve_macros,{{"media",request.at("media")},{"paths",request.at("paths")}}).at("macros");
        Check(macroResult.size() == 10 && macroResult[0].at("required") == true && macroResult[1].at("required") == true,"shared catalogue required macros");
        Check(macroResult[9].at("value") == "60","catalogue GOP expansion matches compile");
        const auto suggestions = CallJson(ve_template_complete,{{"text","{"},{"caret",1}}).at("items");
        Check(suggestions.size() == macroResult.size() && suggestions[2].at("description") == macroResult[2].at("description"),"completion shares catalogue definitions");
        const auto scopes = ve::TokenMetadata(ve::Tokenize("{inputs} -c:v:0 libx264 -c:a aac -b 500k -unknown -g 30 {output}"),capability);
        Check(scopes[1].at("stage") == "video" && scopes[5].at("stage").is_null(),"stream specifier stage and ambiguous unsuffixed bitrate");
        Check(scopes[8].at("isOption") == true && scopes[8].at("stage") == "video","missing option value does not swallow following option metadata");
        const auto inputStages = ve::TokenMetadata(ve::Tokenize("-color_primaries bt709 {inputs} -f lavfi -i other -c:v libx264 {output}"),capability);
        Check(inputStages[0].at("stage") == "input" && inputStages[3].at("stage") == "input" && inputStages[7].at("stage") == "video","input groups do not masquerade as output video/mux stages");
        auto monoRecipe = request.at("recipe"); monoRecipe["audio"][0]["enabled"] = false;
        const auto monoMacros = CallJson(ve_macros,{{"media",request.at("media")},{"paths",request.at("paths")},{"recipe",monoRecipe}}).at("macros");
        Check(ve::Str(monoMacros[0],"value").find(ve::Str(request.at("paths"),"audioPipe")) == std::string::npos,"catalogue active recipe excludes disabled input audio");
        size_t unfinishedQuote = 0;
        const std::string escapedQuote = "ok \"closed\" word\"open";
        const auto prefixWords = ve::Tokenize(escapedQuote,&unfinishedQuote);
        Check(prefixWords.size() == 2 && unfinishedQuote == escapedQuote.rfind('"'),"quote tracking preserves completed words and last unmatched quote");
        Reject(ve_compile,{{"recipe",request.at("recipe")},{"media",request.at("media")},{"paths",request.at("paths")},{"capabilitiesId","released-foreign-id"}},"CAPABILITIES-STALE");
        const std::string prefix = u8"{inputs} -metadata title=编码😀 {output} -metadata ";
        const auto unfinished = prefix + "\"unfinished";
        const auto quoteDiagnostic = CallJson(ve_template_lint,{{"text",unfinished}}).at("diagnostics")[0];
        Check(quoteDiagnostic.at("id") == "L-QUOTE" && quoteDiagnostic.at("start") == ve::Utf16Offset(prefix,prefix.size()),"open quote diagnostic UTF-16 position");
        metadataRequest["recipe"]["command"]["template"] = unfinished;
        const auto partial = CallJson(ve_compile,metadataRequest);
        Check(partial.at("argv").empty() && partial.at("commandLine") == "" && ve::HasErrors(partial.at("issues")),"partial highlighting cannot produce executable argv");
        bool inputChip = false, outputChip = false;
        for (const auto& token : partial.at("display")) if (token.contains("sourceStart")) {
            Check(ve::Num(token,"sourceEnd") <= static_cast<double>(ve::Utf16Offset(prefix,prefix.size())),"prefix spans end before unfinished word");
            if (ve::Str(token,"role") == "input") inputChip = true;
            if (ve::Str(token,"role") == "output") outputChip = true;
        }
        Check(inputChip && outputChip,"completed locked macros survive unfinished quote");
        std::cout << "Native/static core: " << checks << " ownership, bounds, quoting, payload, fuzz and concurrency checks passed. No host or encoder process.\n";
        return 0;
    } catch (const std::exception& e) { std::cerr << "CORE TEST FAILED: " << e.what() << '\n'; return 1; }
}
