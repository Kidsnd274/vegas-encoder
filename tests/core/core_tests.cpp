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
// 0.2.1 fix-plan regressions (B1-B6) collect every failure so each item shows.
std::vector<std::string> failed;
void Expect(bool ok, const std::string& message) { ++checks; if (!ok) failed.push_back(message); }
const ve::Json* FindIssue(const ve::Json& issues, const std::string& id) {
    for (const auto& issue : issues) if (ve::Str(issue,"id") == id) return &issue;
    return nullptr;
}
size_t Count(const ve::Json& argv, const std::string& text) { return static_cast<size_t>(std::count(argv.begin(),argv.end(),ve::Json(text))); }
std::string After(const ve::Json& argv, const std::string& flag) {
    const auto at = std::find(argv.begin(),argv.end(),ve::Json(flag));
    return at == argv.end() || std::next(at) == argv.end() ? std::string() : std::next(at)->get<std::string>();
}
bool Ranged(const ve::Json* issue, const std::string& level, size_t start, size_t end, bool params) {
    if (!issue || ve::Str(*issue,"level") != level) return false;
    const auto& at = params ? issue->at("params") : *issue;
    return at.at("start") == start && at.at("end") == end;
}
void FixPlanChecks(const ve::Json& bundle, const ve::Json& request) {
    const auto compiled = CallJson(ve_compile,request);
    Expect(Count(compiled.at("argv"),"-nostats") == 1,"B1 generated global options include -nostats once");
    Expect(After(compiled.at("argv"),"-progress") == "pipe:1","B1 progress still uses -progress pipe:1");
    auto advanced = request;
    advanced["recipe"]["command"] = {{"mode","template"},{"template","{inputs} -nostats -c:v libx264 -c:a aac -f mp4 {output}"}};
    Expect(Count(CallJson(ve_compile,advanced).at("argv"),"-nostats") == 1,"B1 Advanced -nostats is not duplicated");
    const auto nostats = CallJson(ve_template_lint,{{"text","{inputs} -nostats -c:v libx264 {output}"}}).at("diagnostics");
    Expect(FindIssue(nostats,"L-GLOBAL") && !FindIssue(nostats,"L-OPTION") && !FindIssue(nostats,"L-VALUE"),"B1 lint knows -nostats as an always-added switch");

    const std::string shorter = "This option can stop the render before the end of the VEGAS timeline. The output will be shorter.";
    const std::string prefix = u8"{inputs} -metadata title=编码😀 ";
    for (const std::string option : {"-t","-to","-frames","-frames:v","-vframes","-aframes","-fs"}) {
        const auto text = prefix + option + " 5 -c:v libx264 {output}";
        const auto lint = CallJson(ve_template_lint,{{"text",text}}).at("diagnostics");
        const auto issue = FindIssue(lint,"L-DURATION-LIMIT");
        Expect(Ranged(issue,"warn",ve::Utf16Offset(text,prefix.size()),ve::Utf16Offset(text,prefix.size() + option.size() + 2),false) && ve::Str(*issue,"message") == shorter,"B2 L-DURATION-LIMIT warning and UTF-16 range for " + option);
        Expect(!FindIssue(lint,"L-OPTION"),"B2 " + option + " is a known option");
    }
    const auto shortestText = prefix + "-shortest -c:v libx264 {output}";
    Expect(Ranged(FindIssue(CallJson(ve_template_lint,{{"text",shortestText}}).at("diagnostics"),"L-SHORTEST"),"warn",ve::Utf16Offset(shortestText,prefix.size()),ve::Utf16Offset(shortestText,prefix.size() + 9),false),"B2 L-SHORTEST warning");
    for (const auto& [field,extra,id] : {std::tuple{"video","-t 5","V-EXTRA-DURATION"},{"video","-frames:v 100","V-EXTRA-DURATION"},{"video","-fs 10M","V-EXTRA-DURATION"},{"audio","-aframes 100","V-EXTRA-DURATION"},{"video","-shortest","V-EXTRA-SHORTEST"}}) {
        auto basic = request;
        (std::string(field) == "video" ? basic["recipe"]["video"] : basic["recipe"]["audio"][0])["extra"] = extra;
        const auto issues = CallJson(ve_recipe_validate,basic).at("issues");
        const auto issue = FindIssue(issues,id);
        Expect(Ranged(issue,"warn",0,std::string(extra).size(),true) && ve::Str(*issue,"field") == (std::string(field) == "video" ? "video.extra" : "audio[0].extra") && !ve::HasErrors(issues),std::string("B2 ") + id + " warning for " + extra);
        Expect(!ve::HasErrors(CallJson(ve_compile,basic).at("issues")),std::string("B2 length-limiting Extra still compiles: ") + extra);
    }

    for (const auto* text : {"{inputs} -c:v libx264 -f flv rtmp://host/live {output}","{inputs} -i https://example.com/logo.png -c:v libx264 {output}",
                             "{inputs} -c:v libx264 -metadata comment=srt://host:9000 {output}","{inputs} -c:v libx264 -f tee \"[f=mp4]a.mp4|[f=mpegts]udp:239.0.0.1:1234\" {output}",
                             "{inputs} -c:v libx264 -metadata comment=ftp://x/y {output}","{inputs} -c:v libx264 -metadata comment=TCP://x:1 {output}"})
        Expect(FindIssue(CallJson(ve_template_lint,{{"text",text}}).at("diagnostics"),"L-NETWORK") != nullptr,std::string("B3 L-NETWORK for ") + text);
    for (const auto* text : {"{inputs} -c:v libx264 -attach cover.jpg {output}","-dump_attachment:t out.bin {inputs} -c:v libx264 {output}",
                             "{inputs} -c:v libx264 -/vf graph.txt {output}","{inputs} -c:v libx264 -filter_script:v graph.txt {output}",
                             "{inputs} -c:v libx264 -filter_complex_script graph.txt {output}","{inputs} -c:v libx264 -vf movie=logo.png[l];[in][l]overlay {output}",
                             "{inputs} -c:v libx264 -af amovie=a.wav {output}","{inputs} -c:v libx264 -vf subtitles=subs.srt {output}",
                             "{inputs} -c:v libx264 -vf scale=1280:720,ass=subs.ass {output}","{inputs} -c:v libx264 -vf drawtext=textfile=t.txt:fontsize=20 {output}"})
        Expect(FindIssue(CallJson(ve_template_lint,{{"text",text}}).at("diagnostics"),"L-FILE-ACCESS") != nullptr,std::string("B3 L-FILE-ACCESS for ") + text);
    const auto ordinary = CallJson(ve_template_lint,{{"text","{inputs} -c:v libx264 -vf scale=1280:720,drawtext=text=hello -metadata \"comment=Note: a:b\" -metadata title=12:30 -progress pipe:1 {output}"}}).at("diagnostics");
    Expect(!FindIssue(ordinary,"L-NETWORK") && !FindIssue(ordinary,"L-FILE-ACCESS"),"B3 ordinary filters and metadata containing colons are not flagged");
    for (const auto& [extra,id] : {std::pair{"-metadata comment=https://example.com","V-EXTRA-NETWORK"},{"-vf subtitles=subs.srt","V-EXTRA-FILE"},{"-/vf graph.txt","V-EXTRA-FILE"}}) {
        auto basic = request; basic["recipe"]["video"]["extra"] = extra;
        const auto issues = CallJson(ve_recipe_validate,basic).at("issues");
        Expect(FindIssue(issues,id) && ve::Str(*FindIssue(issues,id),"level") == "warn" && !ve::HasErrors(issues),std::string("B3 ") + id + " warning only for " + extra);
    }

    auto rate = request; rate["recipe"]["video"]["mode"] = "abr"; rate["recipe"]["video"]["extra"] = "-b:a 128k";
    auto rateResult = CallJson(ve_compile,rate);
    Expect(After(rateResult.at("argv"),"-b:v") == "12000k" && rateResult.at("overriddenFields").empty(),"B4 -b:a in Video Extra keeps the generated -b:v and overrides nothing");
    Expect(FindIssue(rateResult.at("issues"),"V-EXTRA-WRONG-STREAM") != nullptr,"B4 V-EXTRA-WRONG-STREAM warns for -b:a in Video Extra");
    auto profile = request; profile["recipe"]["video"]["extra"] = "-profile:a aac_low";
    Expect(CallJson(ve_compile,profile).at("resolved").at("profile") == compiled.at("resolved").at("profile"),"B4 -profile:a in Video Extra does not change the resolved video profile");
    auto quoted = request; quoted["recipe"]["video"]["extra"] = "-flags \"-global_header\"";
    const auto quotedResult = CallJson(ve_compile,quoted);
    bool quotedValue = false;
    for (const auto& token : quotedResult.at("display")) if (ve::Str(token,"field") == "video.extra" && ve::Str(token,"text") == "-global_header") quotedValue = token.contains("isOption") && token.at("isOption") == false;
    Expect(quotedValue && quotedResult.at("overriddenFields").empty() && !ve::HasErrors(quotedResult.at("issues")),"B4 quoted dash word is a value in compile, as in lint");
    quoted["recipe"]["video"]["extra"] = "-metadata \"-crf\"";
    const auto quotedCrf = CallJson(ve_compile,quoted);
    Expect(After(quotedCrf.at("argv"),"-crf") == "18" && quotedCrf.at("overriddenFields").empty(),"B4 quoted option name value does not override the generated option");
    auto chroma = request; chroma["recipe"]["schema"] = 2; chroma["recipe"]["audio"][0]["extra"] = "-pix_fmt yuv444p";
    chroma["recipe"]["video"]["filters"] = ve::Json::array({{{"type","resize"},{"enabled",true},{"width",1281},{"height",720},{"backend","scale"},{"algorithm","bicubic"},{"fit","pad"}}});
    const auto chromaIssues = CallJson(ve_compile,chroma).at("issues");
    Expect(FindIssue(chromaIssues,"V-FILTER-ALIGNMENT") != nullptr,"B4 audio Extra pixel format leaves resize alignment conservative (2x2)");
    const auto wrong = FindIssue(chromaIssues,"V-EXTRA-WRONG-STREAM");
    Expect(wrong && ve::Str(*wrong,"field") == "audio[0].extra" && ve::Str(*wrong,"level") == "warn","B4 lint warns about a video option in Audio Extra");

    for (const auto& [num,den] : {std::pair{48000,1001},{25,2},{240000,1001}}) {
        auto rational = request; rational["media"]["video"]["fps"] = {num,den};
        const auto result = CallJson(ve_compile,rational);
        Expect(!ve::HasErrors(result.at("issues")) && After(result.at("argv"),"-r") == std::to_string(num) + "/" + std::to_string(den),"B6 core accepts and emits " + std::to_string(num) + "/" + std::to_string(den));
    }

    // Decision D11: "source" audio the encoder or container can't take resamples to 48 kHz with a note.
    // Output options only: the raw audio input also carries -ar.
    auto outputAr = [](const ve::Json& argv) {
        size_t start = 0;
        for (size_t i = 0; i < argv.size(); ++i) if (argv[i] == "-i") start = i + 2;
        for (size_t i = start; i + 1 < argv.size(); ++i) if (argv[i] == "-ar") return argv[i+1].get<std::string>();
        return std::string();
    };
    auto fixtureRequest = [&](const char* id) {
        for (const auto& f : bundle.at("fixtures")) if (ve::Str(f.at("recipe"),"id") == id)
            return ve::Json{{"recipe",f.at("recipe")},{"media",f.at("media")},{"paths",f.at("paths")}};
        throw std::runtime_error(std::string("missing fixture ") + id);
    };
    for (const auto* id : {"av1-small","dnxhr-hq","ffv1-master"}) {
        auto at44 = fixtureRequest(id); at44["media"]["audio"]["rate"] = 44100;
        const auto result = CallJson(ve_compile,at44);
        const auto note = FindIssue(result.at("issues"),"V-RATE-RESAMPLED");
        Expect(!ve::HasErrors(result.at("issues")) && outputAr(result.at("argv")) == "48000" && note && ve::Str(*note,"level") == "info" &&
               ve::Str(*note,"message").rfind("Audio is resampled from 44100 Hz to 48000 Hz because ",0) == 0,
               std::string("D11 a 44.1 kHz project resamples to 48 kHz with ") + id);
    }
    auto opus = fixtureRequest("av1-small"); opus["media"]["audio"]["rate"] = 44100;
    const auto opusResult = CallJson(ve_compile,opus);
    Expect(outputAr(opusResult.at("argv")) == "48000" && FindIssue(opusResult.at("issues"),"V-RATE-RESAMPLED") &&
           ve::Str(*FindIssue(opusResult.at("issues"),"V-RATE-RESAMPLED"),"message").find("Opus doesn't support 44100 Hz.") != std::string::npos,
           "D11 Opus at 44.1 kHz resamples to 48 kHz and names the encoder");
    auto mxf = fixtureRequest("dnxhr-hq"); mxf["media"]["audio"]["rate"] = 44100;
    const auto mxfResult = CallJson(ve_compile,mxf);
    const auto mxfNote = FindIssue(mxfResult.at("issues"),"V-RATE-RESAMPLED");
    Expect(mxfNote && ve::Str(*mxfNote,"message").find("MXF files need 48000 Hz audio.") != std::string::npos,"D11 MXF at 44.1 kHz explains the container rule");
    opus["recipe"]["audio"][0]["sampleRate"] = 44100;
    Expect(FindIssue(CallJson(ve_compile,opus).at("issues"),"V-RATE") != nullptr,"D11 an explicitly chosen unsupported rate stays an error");
    const auto at48 = CallJson(ve_compile,fixtureRequest("av1-small"));
    Expect(outputAr(at48.at("argv")).empty() && !FindIssue(at48.at("issues"),"V-RATE-RESAMPLED"),"D11 a supported project rate is not resampled");

    // SVT-AV1 (4.3.0 in N-128435) refuses a peak rate outside CRF ("Max Bitrate only
    // supported with CRF mode"). Saved recipes such as "AV1 4Mb/s Smol" r1 must be
    // refused before FFmpeg starts, on the field the user can fix.
    for (const int schema : {1,2}) {
        auto peak = fixtureRequest("av1-small"); peak["recipe"]["schema"] = schema;
        peak["recipe"]["video"]["mode"] = "abr"; peak["recipe"]["video"]["bitrateK"] = 4000; peak["recipe"]["video"]["maxrateK"] = 4000;
        for (const auto call : {ve_recipe_validate,ve_compile}) {
            const auto issues = CallJson(call,peak).at("issues"); const auto issue = FindIssue(issues,"V-PEAK-UNSUPPORTED");
            Expect(issue && ve::Str(*issue,"level") == "error" && ve::Str(*issue,"field") == "video.maxrateK" &&
                   ve::Str(*issue,"message").find("Peak bitrate") != std::string::npos,"SVT-AV1 target bitrate with a peak is an error on Peak bitrate (schema " + std::to_string(schema) + ")");
        }
    }
    auto svt = fixtureRequest("av1-small"); svt["recipe"]["video"]["mode"] = "abr"; svt["recipe"]["video"]["bitrateK"] = 4000;
    svt["recipe"]["video"]["maxrateK"] = nullptr;
    const auto noPeak = CallJson(ve_compile,svt);
    Expect(!ve::HasErrors(noPeak.at("issues")) && After(noPeak.at("argv"),"-b:v") == "4000k" && !Count(noPeak.at("argv"),"-maxrate"),"SVT-AV1 target bitrate without a peak compiles");
    svt["recipe"]["video"]["extra"] = "-maxrate 5000k -bufsize 10000k";
    const auto svtExtraIssues = CallJson(ve_compile,svt).at("issues");
    const auto svtExtra = FindIssue(svtExtraIssues,"V-PEAK-UNSUPPORTED");
    Expect(svtExtra && ve::Str(*svtExtra,"level") == "error" && ve::Str(*svtExtra,"field") == "video.extra","SVT-AV1 target bitrate with -maxrate in Extra is an error on Extra arguments");
    svt["recipe"]["video"]["mode"] = "crf"; svt["recipe"]["video"]["maxrateK"] = 4000;
    const auto cappedCrf = CallJson(ve_compile,svt);
    Expect(!ve::HasErrors(cappedCrf.at("issues")) && After(cappedCrf.at("argv"),"-maxrate") == "5000k","SVT-AV1 capped CRF through Extra stays allowed; an inactive Peak bitrate is ignored");
    // HEVC profile and bit depth. Measured with N-128435: x265 refuses main/main444-8 with
    // 10-bit pixels at encoder open and writes Main for main10 with 8-bit pixels; HEVC NVENC
    // (RTX 5070 Ti, driver 617.42) writes an 8-bit file labelled Main 10.
    auto hevc = [&](const char* encoder, const ve::Json& profile, int depth, const char* extra = "") {
        auto r = fixtureRequest("yt-hevc-nv"); auto& v = r["recipe"]["video"];
        v["encoder"] = encoder; v["mode"] = std::string(encoder) == "libx265" ? "crf" : "cq";
        v["speed"] = nullptr; v["tune"] = nullptr; v["profile"] = profile; v["depth"] = depth; v["extra"] = extra;
        return CallJson(ve_compile,r);
    };
    auto hevcIssue = [](const ve::Json& result, const char* id) { return FindIssue(result.at("issues"),id) != nullptr; };
    for (const auto* encoder : {"libx265","hevc_nvenc","hevc_qsv"}) for (const int depth : {8,10}) {
        const auto result = hevc(encoder,nullptr,depth);
        Expect(After(result.at("argv"),"-profile:v") == (depth == 8 ? "main" : "main10") && !hevcIssue(result,"V-PROFILE-DEPTH") && !hevcIssue(result,"V-PROFILE-LABEL"),
               std::string("an unset HEVC profile follows the bit depth: ") + encoder + " " + std::to_string(depth) + "-bit");
    }
    // Unset depth (owner decision, 2026-11-20): x265 and HEVC NVENC are 10-bit Main 10. Every
    // HEVC-capable NVIDIA GPU from Pascal on encodes 10-bit; Maxwell 2nd gen (GTX 950-980 Ti,
    // Quadro M2000-M6000) encodes 8-bit HEVC only (NVIDIA Video Encode and Decode Support Matrix).
    for (const auto& [encoder,expectedProfile,pixfmt] : {std::tuple{"libx265","main10","yuv420p10le"},{"hevc_nvenc","main10","p010le"}}) {
        auto unsetDepth = fixtureRequest("yt-hevc-nv"); auto& v = unsetDepth["recipe"]["video"];
        v["encoder"] = encoder; v["mode"] = std::string(encoder) == "libx265" ? "crf" : "cq"; v["speed"] = nullptr; v["tune"] = nullptr; v["profile"] = nullptr; v["depth"] = nullptr;
        const auto result = CallJson(ve_compile,unsetDepth); const auto& argv = result.at("argv");
        const auto outputPixfmt = std::find(argv.rbegin(),argv.rend(),ve::Json("-pix_fmt")); // the first -pix_fmt describes the raw input
        Expect(After(argv,"-profile:v") == expectedProfile && outputPixfmt != argv.rend() && outputPixfmt != argv.rbegin() && *std::prev(outputPixfmt) == pixfmt &&
               !ve::HasErrors(result.at("issues")) && !hevcIssue(result,"V-PROFILE-LABEL"),
               std::string("unset depth default for ") + encoder + ": " + expectedProfile + " / " + pixfmt);
    }
    for (const auto* eightBitOnly : {"main","main444-8"}) {
        const auto refused = hevc("libx265",eightBitOnly,10); const auto issue = FindIssue(refused.at("issues"),"V-PROFILE-DEPTH");
        Expect(issue && ve::Str(*issue,"level") == "error" && ve::Str(*issue,"field") == "video.profile",std::string("x265 ") + eightBitOnly + " with 10-bit pixels is an error on Profile");
    }
    const auto extraProfile = hevc("libx265",nullptr,10,"-profile:v main");
    Expect(hevcIssue(extraProfile,"V-PROFILE-DEPTH"),"x265 Main through Extra with 10-bit pixels is an error too");
    for (const auto& [accepted,depth] : {std::pair{"main10",8},{"main",8},{"main10",10},{"main444-10",10}}) {
        const auto allowed = hevc("libx265",accepted,depth);
        Expect(!ve::HasErrors(allowed.at("issues")) && !hevcIssue(allowed,"V-PROFILE-LABEL"),std::string("x265 accepts and labels correctly: ") + accepted + " " + std::to_string(depth) + "-bit");
    }
    const auto label = hevc("hevc_nvenc","main10",8); const auto labelIssue = FindIssue(label.at("issues"),"V-PROFILE-LABEL");
    Expect(labelIssue && ve::Str(*labelIssue,"level") == "warn" && ve::Str(*labelIssue,"field") == "video.profile" && !ve::HasErrors(label.at("issues")),
           "HEVC NVENC Main 10 with 8-bit pixels warns on Profile");
    const auto starter = CallJson(ve_compile,fixtureRequest("yt-hevc-nv"));
    Expect(!hevcIssue(starter,"V-PROFILE-LABEL") && !hevcIssue(starter,"V-PROFILE-DEPTH") && After(starter.at("argv"),"-profile:v") == "main10","the 10-bit HEVC NVENC starter is unchanged");

    auto x264 = request; x264["recipe"]["video"]["mode"] = "abr"; x264["recipe"]["video"]["maxrateK"] = 16000;
    const auto x264Peak = CallJson(ve_compile,x264);
    Expect(!ve::HasErrors(x264Peak.at("issues")) && After(x264Peak.at("argv"),"-maxrate") == "16000k" && After(x264Peak.at("argv"),"-bufsize") == "32000k",
           "encoders that support a peak keep -maxrate/-bufsize");

#if defined(__SANITIZE_ADDRESS__)
    const int rounds = 20;
#else
    const int rounds = 1000;
#endif
    const auto started = std::chrono::steady_clock::now(); size_t compiles = 0;
    for (const auto& fixture : bundle.at("fixtures")) {
        const ve::Json each{{"recipe",fixture.at("recipe")},{"media",fixture.at("media")},{"paths",fixture.at("paths")}};
        for (int i = 0; i < rounds; ++i, ++compiles) ve::Compile(each);
    }
    const auto micros = std::chrono::duration<double,std::micro>(std::chrono::steady_clock::now() - started).count() / static_cast<double>(compiles);
    std::cout << "B5 compile benchmark: " << compiles << " compiles of the built-in fixtures, " << micros << " us each.\n";
    if (!failed.empty()) {
        std::string text = std::to_string(failed.size()) + " fix-plan regression(s):";
        for (const auto& message : failed) text += "\n  - " + message;
        throw std::runtime_error(text);
    }
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
            Check(result.at("outputContainerId") == f.at("recipe").at("container").at("format"),"Basic container is an established core fact");
            auto advancedRecipe = f.at("recipe"); advancedRecipe["command"]["mode"] = "template";
            advancedRecipe["command"]["template"] = result.at("advancedTemplate");
            const auto seeded = CallJson(ve_compile,{{"recipe",advancedRecipe},{"media",f.at("media")},{"paths",f.at("paths")}});
            Check(seeded.at("argv") == result.at("argv"),"Basic seed preserves input tagging in Advanced");
            Check(seeded.at("outputContainerId") == result.at("outputContainerId"),"Advanced seed preserves the explicit output container fact");
        }
        for (size_t i = 0; i < bundle.at("additionalFixtures").size(); ++i) {
            const auto& popup = bundle.at("additionalFixtures")[i];
            const auto result = CallJson(ve_compile,{{"recipe",popup.at("recipe")},{"media",popup.at("media")},{"paths",popup.at("paths")}});
            Check(!ve::HasErrors(result.at("issues")),"existing popup semantics");
            Check(result.at("argv") == goldens.at("additionalArgv")[i],"existing popup context has distinct argv golden");
        }
        const auto& f = bundle.at("fixtures")[0];
        auto recipe = f.at("recipe");
        auto summarySnapshot = ve::Json{{"recipe",recipe},{"origin",nullptr},{"vegasPrefs",ve::Json::object()},{"writtenBy","core-summary-test"}};
        auto selectedSummary = CallJson(ve_snapshot_summary,{{"snapshot",summarySnapshot}});
        Check(selectedSummary.at("preset") == "Custom settings" && selectedSummary.at("resolution") == "Same as input from VEGAS", "native summary never invents source dimensions");
        Check(ve::Str(selectedSummary,"video").find("libx264") != std::string::npos && selectedSummary.at("filters") == "None", "native summary reflects active Basic settings");
        Check(ve::Str(selectedSummary,"audio").find("Channels set by VEGAS") != std::string::npos, "unknown channels do not borrow neutral summary media");
        summarySnapshot["origin"] = {{"presetId","saved"},{"name","Saved \xE5\x90\x8D"},{"revision",7}};
        summarySnapshot["recipe"]["video"]["extra"] = "-crf 21 -preset fast -vf scale=1280:720";
        selectedSummary = CallJson(ve_snapshot_summary,{{"snapshot",summarySnapshot}});
        Check(ve::Str(selectedSummary,"preset").find("revision 7") != std::string::npos && ve::Str(selectedSummary,"preset").find("Modified") == std::string::npos, "saved origin is identified without invented library comparison");
        Check(ve::Str(selectedSummary,"video").find("CRF 21") != std::string::npos && ve::Str(selectedSummary,"video").find("fast") != std::string::npos, "summary reflects Extra overrides");
        Check(selectedSummary.at("resolution") == "Custom / not determined" && selectedSummary.at("filters") == "Filters set in Extra arguments", "handwritten graph is conservative");
        summarySnapshot["recipe"]["command"] = {{"mode","template"},{"template","{inputs} -c:v libx265 -c:a libopus -f matroska {output}"}};
        selectedSummary = CallJson(ve_snapshot_summary,{{"snapshot",summarySnapshot}});
        Check(ve::Str(selectedSummary,"video").find("Advanced command") != std::string::npos && ve::Str(selectedSummary,"video").find("libx264") == std::string::npos && ve::Str(selectedSummary,"video").find("CRF 21") == std::string::npos, "Advanced summary never reports inactive Basic settings");
        Check(selectedSummary.at("container") == "Matroska (MKV) (.mkv)", "Advanced summary uses the active muxer");
        auto crossSummarySnapshot = summarySnapshot; crossSummarySnapshot["recipe"] = recipe;
        crossSummarySnapshot["recipe"]["audio"][0]["extra"] = "-crf:v 25 -preset:v medium";
        auto crossSummary = CallJson(ve_snapshot_summary,{{"snapshot",crossSummarySnapshot}});
        Check(ve::Str(crossSummary,"video").find("Custom / not determined") != std::string::npos && ve::Str(crossSummary,"video").find("CRF 18") == std::string::npos && ve::Str(crossSummary,"video").find("slow") == std::string::npos, "cross-stream video overrides cannot display inactive Basic controls");
        crossSummarySnapshot["recipe"]["video"]["extra"] = "-b:a 160k -ac 1";
        crossSummary = CallJson(ve_snapshot_summary,{{"snapshot",crossSummarySnapshot}});
        Check(ve::Str(crossSummary,"audio").find("Custom / not determined") != std::string::npos && ve::Str(crossSummary,"audio").find("Stereo") == std::string::npos, "cross-stream audio overrides keep unsupported reflection unknown");
        auto normalized = CallJson(ve_recipe_normalize,{{"recipe",recipe}});
        Check(normalized.at("requiredEncoders") == ve::Json::array({"libx264","aac"}),"Basic requirements come from core");
        auto requirementRecipe = recipe;
        requirementRecipe["audio"][0]["enabled"] = false;
        Check(CallJson(ve_recipe_normalize,{{"recipe",requirementRecipe}}).at("requiredEncoders") == ve::Json::array({"libx264"}),"disabled audio is not a requirement");
        requirementRecipe["command"] = {{"mode","template"},{"template","{inputs} -c:v ffv1 {output}"}};
        Check(CallJson(ve_recipe_normalize,{{"recipe",requirementRecipe}}).at("requiredEncoders").is_null(),"Advanced requirements do not use inactive Basic controls");
        requirementRecipe["schema"] = 3;
        Check(CallJson(ve_recipe_normalize,{{"recipe",requirementRecipe}}).at("requiredEncoders").is_null(),"invalid recipe requirements remain unknown");
        const auto original = recipe.dump();
        auto request = ve::Json{{"recipe",recipe},{"media",f.at("media")},{"paths",f.at("paths")}};
        const auto result = CallJson(ve_compile,request);
        auto resizeRequest = request;
        resizeRequest["recipe"]["schema"] = 2;
        resizeRequest["recipe"]["video"]["filters"] = ve::Json::array({{{"type","resize"},{"enabled",true},{"width",1280},{"height",720},{"backend","scale"},{"algorithm","bicubic"},{"fit","pad"}}});
        const auto options = [](std::initializer_list<const char*> names) { ve::Json values = ve::Json::array(); for (const auto* name : names) values.push_back({{"name",name}}); return values; };
        const auto filterCapabilities = ve::Json{{"encoders",{{"libx264",ve::Options().at("libx264")},{"aac",ve::Options().at("aac")}}},
            {"muxers",{{"mp4",ve::Json::object()}}},
            {"filters",{{"scale",{{"available",true},{"options",options({"w","h","flags"})},{"algorithms",{"bicubic","bilinear","lanczos","neighbor"}}}},
                        {"pad",{{"available",true},{"options",options({"width","height","x","y","color"})}}},
                        {"setsar",{{"available",true},{"options",options({"sar"})}}}}}};
        resizeRequest["capabilities"] = filterCapabilities;
        auto resizeResult = CallJson(ve_compile,resizeRequest);
        Check(!ve::HasErrors(resizeResult.at("issues")), "structured resize with selected-build support compiles: " + resizeResult.at("issues").dump());
        Check(ve_schema_max() == 2 && CallJson(ve_recipe_normalize,{{"recipe",resizeRequest.at("recipe")}}).at("requiredFilters") == ve::Json::array({"scale","pad","setsar"}), "core advertises schema2 and required processing");
        Check(resizeResult.at("filterControl") == "structured" && resizeResult.at("videoGeometry").at("width") == 1280 && resizeResult.at("expectedStreams")[0].at("height") == 720 && resizeResult.at("expectedStreams")[0].at("sar") == "1:1", "output geometry is separate from delivered raw input");
        Check(resizeResult.at("argv")[std::find(resizeResult.at("argv").begin(),resizeResult.at("argv").end(),ve::Json("-s")) - resizeResult.at("argv").begin() + 1] == request.at("media").at("video").at("width").dump() + "x" + request.at("media").at("video").at("height").dump(), "raw pipe keeps delivered dimensions");
        for (const auto* algorithm : {"bicubic","bilinear","lanczos","neighbor"}) {
            auto current = resizeRequest; current["recipe"]["video"]["filters"][0]["algorithm"] = algorithm;
            const auto compiledResize = CallJson(ve_compile,current);
            Check(!ve::HasErrors(compiledResize.at("issues")) && ve::Str(compiledResize,"commandLine").find(std::string("flags=") + algorithm) != std::string::npos, "each curated algorithm is explicit");
        }
        for (const auto* manual : {"-vf null","-filter:v null","-filter:v:0 null","-filter:0 null","-filter null"}) {
            auto current = resizeRequest; current["recipe"]["video"]["extra"] = manual;
            const auto compiledResize = CallJson(ve_compile,current);
            Check(compiledResize.at("filterControl") == "extra" && compiledResize.at("videoGeometry").at("width").is_null() && ve::Str(compiledResize,"commandLine").find("scale=w=") == std::string::npos, "manual filter aliases own the single video chain");
            Check(CallJson(ve_recipe_normalize,{{"recipe",current.at("recipe")}}).at("requiredFilters").empty(), "inactive structured filters are not requirements");
        }
        auto resizeDisabled = resizeRequest; resizeDisabled["recipe"]["video"]["filters"][0]["enabled"] = false;
        Check(CallJson(ve_compile,resizeDisabled).at("argv") == result.at("argv"), "disabled resize preserves existing command bytes");
        auto oldFilterRecipe = resizeRequest.at("recipe"); oldFilterRecipe["schema"] = 1;
        Check(ve::HasErrors(CallJson(ve_recipe_normalize,{{"recipe",oldFilterRecipe}}).at("issues")), "structured processing cannot hide under schema1");
        auto unknownSourceSummary = summarySnapshot; unknownSourceSummary["recipe"] = resizeRequest.at("recipe");
        Check(ve::Str(CallJson(ve_snapshot_summary,{{"snapshot",unknownSourceSummary}}),"resolution").find("1280") != std::string::npos, "unknown-input summary still gives configured output");
        unknownSourceSummary["recipe"]["video"]["gopSec"] = 0.1;
        const auto unknownSummaryIssues = CallJson(ve_snapshot_summary,{{"snapshot",unknownSourceSummary}}).at("issues");
        Check(std::none_of(unknownSummaryIssues.begin(),unknownSummaryIssues.end(),[](const ve::Json& issue) { const auto id = ve::Str(issue,"id"); return id == "V-GOP-BOUNDS" || id == "V-FILTER-ROUNDING" || id == "V-FILTER-ASPECT"; }), "summary without media never validates against placeholder timing or geometry");
        auto resizeNoCaps = resizeRequest; resizeNoCaps.erase("capabilities");
        Check(!ve::HasErrors(CallJson(ve_compile,resizeNoCaps).at("issues")), "no selected-build facts still permits editing with warning");
        auto narrowCanvas = resizeRequest; narrowCanvas["recipe"]["video"]["filters"][0]["width"] = 2; narrowCanvas["recipe"]["video"]["filters"][0]["height"] = 1000;
        const auto actualNarrow = CallJson(ve_compile,narrowCanvas);
        Check(std::any_of(actualNarrow.at("issues").begin(),actualNarrow.at("issues").end(),[](const ve::Json& issue) { return ve::Str(issue,"id") == "V-FILTER-ASPECT"; }), "actual media still rejects an aspect ratio that cannot fit on its chroma grid");
        narrowCanvas["paths"]["mediaIsSample"] = true;
        const auto sampleNarrow = CallJson(ve_compile,narrowCanvas);
        Check(!ve::HasErrors(sampleNarrow.at("issues")) && std::none_of(sampleNarrow.at("issues").begin(),sampleNarrow.at("issues").end(),[](const ve::Json& issue) { const auto id = ve::Str(issue,"id"); return id == "V-FILTER-ASPECT" || id == "V-FILTER-ROUNDING"; }), "labelled sample media cannot block unknown-project filter admission or report project rounding");
        Check(sampleNarrow.at("videoGeometry") == actualNarrow.at("videoGeometry"), "sample marker leaves command-preview geometry unchanged");
        auto invalidSampleFilter = narrowCanvas; invalidSampleFilter["recipe"]["video"]["filters"][0]["width"] = 0;
        Check(ve::HasErrors(CallJson(ve_compile,invalidSampleFilter).at("issues")), "sample marker does not suppress structural filter errors");
        invalidSampleFilter = narrowCanvas; invalidSampleFilter["recipe"]["video"]["filters"][0]["width"] = 3;
        Check(ve::HasErrors(CallJson(ve_compile,invalidSampleFilter).at("issues")), "sample marker does not suppress canvas chroma alignment errors");
        invalidSampleFilter = narrowCanvas; invalidSampleFilter["capabilities"]["filters"].erase("pad");
        Check(ve::HasErrors(CallJson(ve_compile,invalidSampleFilter).at("issues")), "sample marker does not suppress missing filter capabilities");
        auto resizeMissing = resizeRequest; resizeMissing["capabilities"]["filters"].erase("pad");
        Check(ve::HasErrors(CallJson(ve_compile,resizeMissing).at("issues")), "selected FFmpeg missing required filter blocks processing");
        resizeMissing = resizeRequest; resizeMissing["capabilities"]["filters"]["scale"]["algorithms"] = {"bilinear"};
        Check(ve::HasErrors(CallJson(ve_compile,resizeMissing).at("issues")), "missing selected algorithm never substitutes another");
        resizeMissing = resizeRequest; resizeMissing["capabilities"]["filters"]["pad"]["options"] = options({"fake"});
        Check(ve::HasErrors(CallJson(ve_compile,resizeMissing).at("issues")), "listed filter without emitted option support blocks processing");
        for (const auto* key : {"width","height"}) for (const auto dimension : {0,65537,1279}) {
            auto current = resizeRequest; current["recipe"]["video"]["filters"][0][key] = dimension;
            Check(ve::HasErrors(CallJson(ve_compile,current).at("issues")), "invalid or chroma-unaligned resize dimensions are rejected");
        }
        struct GeometryCase { int width,height,contentWidth,contentHeight; const char* sar; };
        for (const auto& shapeCase : {GeometryCase{1920,1080,1280,720,"1:1"},GeometryCase{640,480,960,720,"1:1"},GeometryCase{480,640,540,720,"1:1"},GeometryCase{640,480,1280,720,"4:3"},GeometryCase{1280,720,1280,720,"1:1"}}) {
            auto current = resizeRequest; current["media"]["video"]["width"] = shapeCase.width; current["media"]["video"]["height"] = shapeCase.height; current["media"]["video"]["sar"] = shapeCase.sar;
            auto compiledResize = CallJson(ve_compile,current);
            Check(!ve::HasErrors(compiledResize.at("issues")) && compiledResize.at("videoGeometry").at("contentWidth") == shapeCase.contentWidth && compiledResize.at("videoGeometry").at("contentHeight") == shapeCase.contentHeight, "fit honors delivered shape and sample aspect");
            current["recipe"]["command"] = {{"mode","template"},{"template",compiledResize.at("advancedTemplate")}};
            Check(CallJson(ve_compile,current).at("argv") == compiledResize.at("argv"), "Advanced seed expands source SAR without changing the effective chain");
        }
        auto advancedInactive = resizeRequest; advancedInactive["recipe"]["command"] = {{"mode","template"},{"template","{inputs} -c:v libx264 -c:a aac -f mp4 {output}"}};
        Check(ve::Str(CallJson(ve_compile,advancedInactive),"commandLine").find("scale=w=") == std::string::npos, "inactive Basic resize cannot affect Advanced");
        auto payloadResize = summarySnapshot; payloadResize["recipe"] = resizeRequest.at("recipe");
        auto encodedResize = ve::EncodePayload(payloadResize);
        Check(encodedResize[16] == 2 && ve::Canonical(ve::DecodePayload(encodedResize.data(),encodedResize.size()).at("snapshot")) == ve::Canonical(payloadResize), "schema2 processing roundtrips with a rejecting-old-reader envelope discriminator");
        encodedResize[16] = 1;
        Check(ve::HasErrors(ve::DecodePayload(encodedResize.data(),encodedResize.size()).at("issues")), "payload and recipe schema disagreement is rejected");
        // Native admission is a compile target, not a portable preset field.
        auto nativeRequest = request;
        nativeRequest["paths"]["target"] = {{"id","vegas-native-v1"}};
        for (const auto& container : ve::Profiles().at("containers")) {
            auto current = nativeRequest;
            const auto id = ve::Str(container,"id"), muxer = ve::Str(container,"muxer"), ext = ve::Str(container,"ext");
            current["recipe"]["container"]["format"] = id;
            // Use compatible curated stream families for each container.
            if (id == "webm") { current["recipe"]["video"]["encoder"] = "libvpx-vp9"; current["recipe"]["video"]["profile"] = nullptr; current["recipe"]["video"]["speed"] = "4"; current["recipe"]["audio"][0]["encoder"] = "libopus"; }
            if (id == "mov" || id == "mxf") { current["recipe"]["video"]["encoder"] = "prores_ks"; current["recipe"]["video"]["mode"] = "profile"; current["recipe"]["video"]["profile"] = "hq"; current["recipe"]["video"]["depth"] = 10; current["recipe"]["video"]["speed"] = nullptr; current["recipe"]["audio"][0]["encoder"] = "pcm_s16le"; current["recipe"]["audio"][0]["mode"] = "lossless"; }
            const auto basicContainer = CallJson(ve_compile,current);
            Check(!ve::HasErrors(basicContainer.at("issues")) && basicContainer.at("outputExtension") == ext,"Basic native target " + id + ": " + basicContainer.at("issues").dump());
            current["paths"]["target"]["containerId"] = id;
            Check(!ve::HasErrors(CallJson(ve_compile,current).at("issues")),"bound legacy format accepts its Basic container");
            current["paths"]["target"]["containerId"] = id == "mkv" ? "mp4" : "mkv";
            auto mismatch = CallJson(ve_compile,current);
            Check(std::any_of(mismatch.at("issues").begin(),mismatch.at("issues").end(),[](const ve::Json& issue) { return ve::Str(issue,"id") == "N-FORMAT-CONTAINER"; }),"legacy Basic mismatch rejected before a filename is known");
            current["paths"]["target"]["containerId"] = id;
            current["recipe"]["command"] = {{"mode","template"},{"template","{inputs} -c:v " + ve::Str(current["recipe"]["video"],"encoder") + " -c:a " + ve::Str(current["recipe"]["audio"][0],"encoder") + " -f " + muxer + " {output}"}};
            const auto compiledContainer = CallJson(ve_compile,current);
            Check(!ve::HasErrors(compiledContainer.at("issues")) && compiledContainer.at("outputContainerId") == id && compiledContainer.at("outputExtension") == ext,"Advanced explicit muxer establishes native container independently of inactive Basic controls");
            current["paths"]["target"]["containerId"] = id == "mkv" ? "mp4" : "mkv";
            mismatch = CallJson(ve_compile,current);
            Check(std::any_of(mismatch.at("issues").begin(),mismatch.at("issues").end(),[](const ve::Json& issue) { return ve::Str(issue,"id") == "N-FORMAT-CONTAINER"; }),"legacy Advanced constraint follows active muxer, not inactive Basic controls");
            current["paths"]["target"]["containerId"] = id;
            current["paths"]["target"]["outputPath"] = "D:\\Renders\\exact" + ext;
            Check(!ve::HasErrors(CallJson(ve_compile,current).at("issues")),"matching destination accepted");
            current["paths"]["target"]["outputPath"] = "D:\\Renders\\wrong.bin";
            Check(ve::HasErrors(CallJson(ve_compile,current).at("issues")),"native destination suffix mismatch rejected");
        }
        for (const auto& badContainer : {ve::Json(3),ve::Json("unknown")}) {
            auto badTarget = nativeRequest;
            badTarget["paths"]["target"]["containerId"] = badContainer;
            Reject(ve_compile,badTarget,"TARGET");
        }
        for (const auto* command : {"{inputs} -c:v ffv1 -c:a pcm_f32le {output}", "-f matroska {inputs} -c:v ffv1 -c:a pcm_f32le {output}",
            "{inputs} -c:v ffv1 -c:a pcm_f32le -f tee {output}", "{inputs} -c:v ffv1 -c:a pcm_f32le -f matroska {output} -f mov",
            "{inputs} -c:v:1 ffv1 -c:a pcm_f32le -f matroska {output}", "{inputs} -c ffv1 -f matroska {output}",
            "{inputs} -map 0:v:0 -map 0:v:0 -c:v ffv1 -f matroska {output}", "{inputs} -vn -c:a pcm_f32le -f matroska {output}",
            "{inputs} -filter_complex null -c:v ffv1 -c:a pcm_f32le -f matroska {output}"}) {
            nativeRequest["recipe"]["command"] = {{"mode","template"},{"template",command}};
            Check(ve::HasErrors(CallJson(ve_compile,nativeRequest).at("issues")),"native target refuses unestablished muxer, order or stream scope");
        }
        nativeRequest["recipe"]["command"] = {{"mode","template"},{"template","{inputs} -c:v ffv1 -c:a pcm_f32le -vf null -f matroska {output}"}};
        Check(!ve::HasErrors(CallJson(ve_compile,nativeRequest).at("issues")),"simple filter precision uncertainty is independent of output ownership");
        for (const auto* graphOption : {"-filter_complex \"[0:v]split=2\"","-lavfi \"[0:v]split=2\"","-filter_complex_script graph.txt"}) {
            for (const bool advancedGraph : {false,true}) {
                auto graphRequest = request;
                if (advancedGraph) graphRequest["recipe"]["command"] = {{"mode","template"},{"template",std::string("{inputs} ") + graphOption + " -c:v libx264 -c:a aac -f mp4 {output}"}};
                else graphRequest["recipe"]["video"]["extra"] = graphOption;
                Check(!ve::HasErrors(CallJson(ve_compile,graphRequest).at("issues")),"portable commands retain complex graph policy in both modes");
                graphRequest["paths"]["target"] = {{"id","vegas-native-v1"}};
                const auto graphResult = CallJson(ve_compile,graphRequest);
                Check(std::any_of(graphResult.at("issues").begin(),graphResult.at("issues").end(),[](const ve::Json& issue) { return ve::Str(issue,"id") == "N-COMPLEX-FILTER" && ve::Str(issue,"level") == "error"; }),"native target rejects complex graph option, alias and script in both modes");
            }
        }
        auto fileGraph = request;
        fileGraph["recipe"]["command"] = {{"mode","template"},{"template","{inputs} -/filter_complex graph.txt -c:v libx264 -c:a aac -f mp4 {output}"}};
        Check(!ve::HasErrors(CallJson(ve_compile,fileGraph).at("issues")),"portable file-loaded graph remains permissive");
        fileGraph["paths"]["target"] = {{"id","vegas-native-v1"}};
        auto fileGraphResult = CallJson(ve_compile,fileGraph);
        Check(std::any_of(fileGraphResult.at("issues").begin(),fileGraphResult.at("issues").end(),[](const ve::Json& issue) { return ve::Str(issue,"id") == "N-COMPLEX-FILTER"; }),"native file-loaded graph is explicitly rejected");
        fileGraph = request;
        fileGraph["recipe"]["video"]["extra"] = "-/filter_complex graph.txt";
        fileGraph["paths"]["target"] = {{"id","vegas-native-v1"}};
        fileGraphResult = CallJson(ve_compile,fileGraph);
        Check(std::any_of(fileGraphResult.at("issues").begin(),fileGraphResult.at("issues").end(),[](const ve::Json& issue) { return ve::Str(issue,"id") == "N-COMPLEX-FILTER"; }),"native Basic file-loaded graph is explicitly rejected too");
        auto simpleExtra = request;
        simpleExtra["paths"]["target"] = {{"id","vegas-native-v1"}};
        simpleExtra["recipe"]["video"]["extra"] = "-vf null -metadata comment=lavfi";
        Check(!ve::HasErrors(CallJson(ve_compile,simpleExtra).at("issues")),"native Basic retains simple filters");
        simpleExtra["recipe"]["video"]["extra"] = "-metadata \"-lavfi\"";
        Check(!ve::HasErrors(CallJson(ve_compile,simpleExtra).at("issues")),"quoted complex option name used as a value is not a graph");
        simpleExtra["recipe"]["video"]["enabled"] = false;
        simpleExtra["recipe"]["video"]["extra"] = "-filter_complex null";
        const auto omittedExtra = CallJson(ve_compile,simpleExtra);
        Check(std::none_of(omittedExtra.at("issues").begin(),omittedExtra.at("issues").end(),[](const ve::Json& issue) { return ve::Str(issue,"id") == "N-COMPLEX-FILTER"; }),"native guard ignores Extra that is not emitted");
        auto missingMuxer = request; missingMuxer["capabilities"] = {{"encoders",{{"libx264",ve::Json::object()},{"aac",ve::Json::object()}}},{"muxers",ve::Json::object()}};
        Check(ve::HasErrors(CallJson(ve_compile,missingMuxer).at("issues")),"known absent output muxer refuses compile");
        auto containerRequest = request;
        containerRequest["recipe"]["container"]["format"] = "unknown-container";
        Check(CallJson(ve_compile,containerRequest).at("outputContainerId").is_null(),"invalid Basic container remains unknown");
        containerRequest = request;
        containerRequest["recipe"]["command"] = {{"mode","template"},{"template","{inputs} -c:v ffv1 -f matroska {output}"}};
        Check(CallJson(ve_compile,containerRequest).at("outputContainerId") == "mkv","Advanced explicit muxer overrides inactive Basic container and filename");
        containerRequest["recipe"]["command"]["template"] = "{inputs} -c:v ffv1 -f matroska -f mov {output}";
        Check(CallJson(ve_compile,containerRequest).at("outputContainerId") == "mov","last known output muxer owns container fact");
        for (const auto* text : {"{inputs} -c:v ffv1 {output}",
                                 "-f matroska {inputs} -c:v ffv1 {output}",
                                 "{inputs} -c:v ffv1 -f matroska -f unknown-muxer {output}",
                                 "{inputs} -i extra.mkv -c:v ffv1 -f matroska {output}",
                                 "{inputs} -c:v ffv1 -f matroska extra.mkv {output}",
                                 "{inputs} -c:v ffv1 -f matroska {output} -metadata \"unfinished"}) {
            containerRequest["recipe"]["command"]["template"] = text;
            Check(CallJson(ve_compile,containerRequest).at("outputContainerId").is_null(),"absent/input/unknown/general/partial Advanced muxer facts remain unknown");
        }
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
        b1Request["recipe"] = f.at("recipe"); b1Request["capabilities"] = nullptr;
        for (const auto* selector : {"-pix_fmt:v:1","-pix_fmt:0"}) {
            b1Request["recipe"]["video"]["extra"] = std::string(selector) + " yuv420p";
            b1Result = CallJson(ve_compile,b1Request);
            Check(b1Result.at("signalPath").at("video").at("outputBits").is_null() && b1Result.at("signalPath").at("video").at("conversion").is_null(),"Basic unsupported pixel-format selectors do not label the first video output");
            Check(std::find(b1Result.at("argv").begin(),b1Result.at("argv").end(),ve::Json(selector)) != b1Result.at("argv").end(),"unknown format scope preserves authored argv");
        }
        for (const auto* filter : {"-vf","-filter:v","-filter:v:0"}) {
            b1Request["recipe"]["video"]["extra"] = std::string(filter) + " format=yuv420p";
            b1Result = CallJson(ve_compile,b1Request);
            Check(b1Result.at("signalPath").at("video").at("outputBits") == 8 && b1Result.at("signalPath").at("video").at("conversion").is_null(),"Basic arbitrary filter aliases preserve explicit depth but leave conversion unknown");
        }
        b1Request["recipe"] = f.at("recipe"); b1Request["recipe"]["video"]["depth"] = 10; b1Request["recipe"]["video"]["profile"] = "high10";
        b1Request["recipe"]["audio"][0]["extra"] = "-pix_fmt yuv420p";
        Check(CallJson(ve_compile,b1Request).at("signalPath").at("video").at("outputBits").is_null(),"Basic cross-stream audio Extra pixel format cannot leave stale generated video facts");
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
        for (const auto* text : {"-pix_fmt yuv420p {inputs} -map 0:v:0 -c:v libx264 {output}",
                                 "{inputs} -map 0:v:0 -c:v libx264 -pix_fmt:v:1 yuv420p {output}",
                                 "{inputs} -map 1:a:0 -map 0:v:0 -c:v libx264 -c:a aac -pix_fmt:0 yuv420p {output}"}) {
            metadataRequest["recipe"]["command"]["template"] = text;
            const auto scoped = CallJson(ve_compile,metadataRequest);
            Check(scoped.at("signalPath").at("video").at("outputBits").is_null(),"Advanced input or unsupported pixel-format scope stays unknown");
        }
        metadataRequest["recipe"]["command"]["template"] = "-c:v libx265 -pix_fmt yuv420p {inputs} -map 0:v:0 -c:v libx264 -pix_fmt:v:0 yuv420p10le {output}";
        auto scoped = CallJson(ve_compile,metadataRequest);
        Check(scoped.at("summary").at("videoEncoderId") == "libx264" && scoped.at("signalPath").at("video").at("outputBits") == 10,"Advanced input options do not displace established output encoder/format facts");
        metadataRequest["recipe"]["command"]["template"] = "{inputs} -map 0:v:0 -c:v libx264 -filter:v format=yuv420p,format=yuv420p10le -pix_fmt:v:0 yuv420p10le {output}";
        scoped = CallJson(ve_compile,metadataRequest);
        Check(scoped.at("signalPath").at("video").at("outputBits") == 10 && scoped.at("signalPath").at("video").at("conversion").is_null(),"Advanced filter alias leaves possible intermediate precision loss unknown");
        metadataRequest["recipe"]["command"]["template"] = "{inputs} -map 0:v:0 -c:v libx264 -pix_fmt yuv420p10le -c:a aac -filter format=yuv420p,format=yuv420p10le {output}";
        Check(CallJson(ve_compile,metadataRequest).at("signalPath").at("video").at("conversion").is_null(),"Advanced unscoped filter keeps video conversion unknown after an audio option");
        const auto macroResult = CallJson(ve_macros,{{"media",request.at("media")},{"paths",request.at("paths")}}).at("macros");
        Check(macroResult.size() == 11 && macroResult[0].at("required") == true && macroResult[1].at("required") == true,"shared catalogue required macros");
        Check(macroResult[10].at("value") == "60","catalogue GOP expansion matches compile");
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
        FixPlanChecks(bundle,request);
        std::cout << "Native/static core: " << checks << " ownership, bounds, quoting, payload, fuzz and concurrency checks passed. No host or encoder process.\n";
        return 0;
    } catch (const std::exception& e) { std::cerr << "CORE TEST FAILED: " << e.what() << '\n'; return 1; }
}
