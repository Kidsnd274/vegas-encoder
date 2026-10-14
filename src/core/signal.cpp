#include "core.h"
#include <algorithm>
#include <cmath>
#include <sstream>

namespace ve {
Json VideoFormat(const std::string& requested) {
    // '+' selects an exact format; '+' alone leaves it to the input/filtergraph.
    // Keep that unestablished format unknown rather than guessing a source format.
    const auto format = !requested.empty() && requested[0] == '+' ? requested.substr(1) : requested;
    int bits = 0; std::string chroma;
    if (format == "p010le" || format == "yuv420p10le") { bits = 10; chroma = "4:2:0"; }
    else if (format == "yuv420p" || format == "nv12") { bits = 8; chroma = "4:2:0"; }
    else if (format == "yuv422p") { bits = 8; chroma = "4:2:2"; }
    else if (format == "yuv422p10le") { bits = 10; chroma = "4:2:2"; }
    else if (format == "yuv444p10le") { bits = 10; chroma = "4:4:4"; }
    else if (format == "yuv444p") { bits = 8; chroma = "4:4:4"; }
    else if (format == "yuv420p12le") { bits = 12; chroma = "4:2:0"; }
    else if (format == "yuv422p12le") { bits = 12; chroma = "4:2:2"; }
    else if (format == "yuv444p12le") { bits = 12; chroma = "4:4:4"; }
    else if (format == "p016le" || format == "yuv420p16le") { bits = 16; chroma = "4:2:0"; }
    const std::string label = bits ? (format == "p010le" ? "P010, " : "") + std::to_string(bits) + "-bit " + chroma : format;
    return Json{{"format",format},{"bits",bits ? Json(bits) : Json(nullptr)},
                {"chroma",chroma.empty() ? Json(nullptr) : Json(chroma)},
                {"label",label},{"shortLabel",bits ? std::to_string(bits) + "-bit" : format}};
}
namespace {
Json AudioFormat(std::string format, int usefulBits = 0) {
    if (format == "f32le") format = "flt";
    else if (format == "f64le") format = "dbl";
    else if (format == "s16le") format = "s16";
    else if (format == "s32le") format = "s32";
    else if (format == "s24le") { format = "s32"; usefulBits = 24; }
    const bool floating = format == "flt" || format == "fltp" || format == "dbl" || format == "dblp";
    int bits = usefulBits;
    if (!bits) {
        if (format == "u8" || format == "u8p") bits = 8;
        else if (format == "s16" || format == "s16p") bits = 16;
        else if (format == "s32" || format == "s32p" || format == "flt" || format == "fltp") bits = 32;
        else if (format == "s64" || format == "s64p" || format == "dbl" || format == "dblp") bits = 64;
    }
    return Json{{"format",format},{"bits",bits ? Json(bits) : Json(nullptr)},{"chroma",nullptr},
                {"label",bits ? std::to_string(bits) + "-bit " + (floating ? "float" : "integer") : format},
                {"shortLabel",bits ? (floating ? "float" : std::to_string(bits) + "-bit") : format}};
}
Json StreamFacts(const Json& in, const Json& out, const std::string& support) {
    const bool known = !in.at("bits").is_null() && !out.at("bits").is_null();
    Json converted = known ? Json(in.at("format") != out.at("format") || in.at("bits") != out.at("bits")) : Json(nullptr);
    const bool knownChroma = !in.at("chroma").is_null() && !out.at("chroma").is_null();
    Json changed = knownChroma ? Json(in.at("chroma") != out.at("chroma")) : Json(nullptr);
    std::string note;
    if (known && in.at("bits").get<int>() > out.at("bits").get<int>()) note = "Precision is reduced before encoding.";
    if (knownChroma && changed == true) note += (note.empty() ? "" : " ") + std::string("Chroma sampling changes; added color resolution is interpolated, not recovered.");
    if (note.empty() && known && converted == true) note = "Sample or pixel storage layout changes before encoding.";
    return Json{{"inputFormat",Str(in,"format").empty() ? Json(nullptr) : in.at("format")},{"outputFormat",Str(out,"format").empty() ? Json(nullptr) : out.at("format")},
                {"inputBits",in.at("bits")},{"outputBits",out.at("bits")},
                {"inputChroma",in.at("chroma")},{"outputChroma",out.at("chroma")},
                {"chromaChanged",changed},{"conversion",converted},{"containerSupport",support},
                {"inputLabel",Str(in,"label").empty() ? Json(nullptr) : in.at("label")},{"outputLabel",Str(out,"label").empty() ? Json(nullptr) : out.at("label")},
                {"conversionNote",note.empty() ? Json(nullptr) : Json(note)}};
}
std::string FormatNumber(double number) {
    std::ostringstream out; out.imbue(std::locale::classic()); out.precision(12); out << number; return out.str();
}
std::string Rate(double kbps) {
    return kbps >= 1000 ? FormatNumber(kbps / 1000) + " Mb/s" : FormatNumber(kbps) + " kb/s";
}
}
Json Signal(const Json& r, const Json& media, const Json& res, const Json& caps) {
    const auto& v = media.at("video"); const auto& a = r.at("audio")[0];
    const auto sourceVideo = VideoFormat(Str(v,"pixfmt","p010le"));
    const bool audioInput = media.contains("audio") && !media.at("audio").is_null();
    const Json sourceAudio = audioInput ? AudioFormat(Str(media.at("audio"),"sampleFmt","f32le")) : Json(nullptr);
    Json signal{{"source",{{"video",sourceVideo},{"audio",sourceAudio}}},{"video",nullptr},{"audio",Json::array()}};
    const auto container = Str(res,"container",Str(r.at("container"),"format"));
    if (Bool(res,"videoEnabled",Bool(r.at("video"),"enabled",true))) {
        signal["video"] = StreamFacts(Bool(res,"unknownInputSource") ? VideoFormat("") : sourceVideo,VideoFormat(Str(res,"pixfmt")),ContainerSupport("video",res.at("videoProfile"),container,caps));
        if (Bool(res,"videoFilter")) signal["video"]["conversion"] = nullptr;
    }
    if (audioInput && Bool(res,"audioEnabled",Bool(a,"enabled",true))) {
        const bool advanced = Str(r.at("command"),"mode") == "template";
        const auto& p = res.at("audioProfile");
        auto output = AudioFormat(Str(res,"audioSampleFormat",Str(p,"sampleFormat")),static_cast<int>(Num(p,"sampleBits")));
        if (res.contains("audioSampleFormat")) output = AudioFormat(Str(res,"audioSampleFormat"));
        auto facts = StreamFacts(Bool(res,"unknownInputSource") ? AudioFormat("") : sourceAudio,output,ContainerSupport("audio",p,container,caps));
        const auto& delivered = media.at("audio");
        const double rate = Num(res,"audioRate",!advanced && a.contains("sampleRate") && a.at("sampleRate").is_number() ? Num(a,"sampleRate") : Num(delivered,"rate"));
        const double channels = Num(res,"audioChannels",!advanced && Str(a,"channels","source") == "mono" ? 1 : !advanced && Str(a,"channels","source") == "stereo" ? 2 : Num(delivered,"channels"));
        if (!Bool(res,"unknownOutputScope") && (rate != Num(delivered,"rate") || channels != Num(delivered,"channels"))) facts["conversion"] = true;
        if (advanced && !res.contains("audioRate") && p.contains("rates") && std::find(p.at("rates").begin(),p.at("rates").end(),delivered.at("rate")) == p.at("rates").end()) facts["conversion"] = nullptr;
        if (Bool(res,"audioFilter")) facts["conversion"] = nullptr;
        signal["audio"].push_back(std::move(facts));
    }
    return signal;
}
Json Summary(const Json& r, const Json& res) {
    const auto& v = r.at("video"); const auto& a = r.at("audio")[0]; const auto& p = res.at("videoProfile"); const auto& ap = res.at("audioProfile");
    const auto mode = Str(res,"videoMode"); const auto amode = Str(res,"audioMode");
    const bool advanced = Str(r.at("command"),"mode") == "template";
    std::string quality = mode == "crf" ? "CRF " + FormatNumber(Num(res,"quality")) : mode == "cq" ? "CQ " + FormatNumber(Num(res,"quality")) :
        mode == "abr" ? Rate(Num(res,"videoBitrateK",Num(v,"bitrateK",Num(p.value("bitrate",Json::object()),"def",12000)))) + " average" :
        mode == "cbr" ? Rate(Num(res,"videoBitrateK",Num(v,"bitrateK",Num(p.value("bitrate",Json::object()),"def",12000)))) + " constant" :
        mode == "cqp" ? "QP " + FormatNumber(Num(res,"qp",Num(v,"qp",Num(p.value("qp",Json::object()),"def",20)))) :
        mode == "profile" ? Str(p.value("profileQuality",Json::object()).value("names",Json::object()),Str(res,"profile"),Str(res,"profile")) : "Lossless";
    const bool videoEnabled = Bool(res,"videoEnabled",Bool(v,"enabled",true)); const bool audioEnabled = Bool(res,"audioEnabled",Bool(a,"enabled",true));
    const auto cp = FindContainer(Str(res,"container",Str(r.at("container"),"format")));
    return Json{{"container",cp ? Str(*cp,"label") : Str(res,"container","From command")},
        {"video",videoEnabled ? (advanced && Str(res,"videoEncoder").empty() ? "From command" : Str(p,"codec",Str(res,"videoEncoder"))) : "No video"},
        {"videoEncoder",videoEnabled ? Json(Str(p,"label",Str(res,"videoEncoder"))) : Json(nullptr)},
        {"videoQuality",advanced ? "From command" : quality},{"speed",res.value("speed",Json(nullptr))},
        {"depth",Num(res,"depth") > 0 ? std::to_string(static_cast<int>(Num(res,"depth"))) + "-bit" : "Unknown"},
        {"audio",audioEnabled ? (advanced && Str(res,"audioEncoder").empty() ? "From command" : Str(ap,"label",Str(res,"audioEncoder"))) : "No audio"},
        {"audioQuality",!audioEnabled ? "No audio" : advanced ? "From command" : amode == "bitrate" ? Rate(Num(res,"audioBitrateK",Num(a,"bitrateK",Num(ap.value("bitrate",Json::object()),"def",320)))) : amode == "vbr" ? "VBR " + FormatNumber(Num(a,"vbr",Num(ap.value("vbr",Json::object()),"def"))) : "Lossless"},
        {"mode",advanced ? "Advanced" : Str(Profiles().at("rateModes").value(mode,Json::object()),"label",mode)},{"command",advanced}};
}
Json Estimate(const Json& request) {
    const auto& r = request.at("recipe"); const auto& media = request.at("media"); CheckMedia(media);
    const auto duration = request.value("durationSec",Json(nullptr));
    if (!duration.is_null() && (!duration.is_number() || duration.get<double>() < 0 || !std::isfinite(duration.get<double>()))) throw Error(VE_INVALID_ARGUMENT,"DURATION","Length must be a finite nonnegative number of seconds.");
    Json result{{"available",false},{"approx",false},{"videoKbps",0},{"audioKbps",0},{"bytesPerMinute",0},
                {"totalBytes",nullptr},{"minBytesPerMinute",nullptr},{"maxBytesPerMinute",nullptr},
                {"minTotalBytes",nullptr},{"maxTotalBytes",nullptr},{"explanation","No size estimate for this recipe."}};
    if (HasErrors(Structural(r)) || Str(r.at("command"),"mode") == "template") return result;
    // Same compiler resolves defaults and Extra arguments; estimates never have a second resolver.
    const auto compiled = Compile(Json{{"recipe",r},{"media",media},{"paths",{{"ffmpeg","ffmpeg"},{"videoPipe","video"},{"audioPipe","audio"},{"output","output"},{"project",""}}}});
    if (HasErrors(compiled.at("issues")) || compiled.at("resolved").is_null()) return result;
    const auto& res = compiled.at("resolved"); const auto base = Resolve(r);
    const auto videoMode = Str(res,"videoMode");
    for (const auto& token : compiled.at("display")) if (Str(token,"role") == "extra" && IsOption(Str(token,"text"))) {
        const auto key = OptionKey(Str(token,"text"));
        if (key == "vf" || key == "af" || key == "filter_complex" || key == "t" || key == "rc" ||
            (key == "crf" && videoMode != "crf") || (key == "cq" && videoMode != "cq") || (key == "qp" && videoMode != "cqp")) {
            result["explanation"] = "No reliable size estimate for these Extra arguments."; return result;
        }
    }
    if ((videoMode == "abr" || videoMode == "cbr") && res.contains("videoBitrateK") && Num(res,"videoBitrateK") <= 0) return result;
    const auto& v = r.at("video"); const auto& a = r.at("audio")[0]; const auto& p = base.at("videoProfile"); const auto& ap = base.at("audioProfile");
    const auto mode = Str(res,"videoMode"), amode = Str(res,"audioMode");
    const double pixels = Num(media.at("video"),"width") * Num(media.at("video"),"height");
    const auto& fpsRatio = media.at("video").at("fps"); const double fps = fpsRatio[0].get<double>() / fpsRatio[1].get<double>();
    double videoRate = 0, audioRate = 0; bool approximate = false;
    if (Bool(v,"enabled",true)) {
        if (mode == "abr" || mode == "cbr") videoRate = Num(res,"videoBitrateK",Num(v,"bitrateK",Num(p.value("bitrate",Json::object()),"def",12000)));
        else if (mode == "profile") { videoRate = Num(p.value("profileQuality",Json::object()).value("mbps1080",Json::object()),Str(res,"profile")) * 1000 * (pixels / 2073600) * (fps / 29.97); approximate = true; }
        else if (mode == "lossless") { videoRate = Num(p,"mbpsPerMpix",35) * 1000 * pixels / 1000000 * (fps / 29.97); approximate = true; }
        else {
            const double q = mode == "cqp" ? Num(res,"qp",Num(v,"qp",Num(p.value("qp",Json::object()),"def",20))) : Num(res,"quality",20);
            const auto family = Str(p,"family"); const double efficiency = family == "hevc" ? .62 : family == "av1" ? .5 : family == "vp9" ? .6 : 1;
            const double pivot = Num(p.value("quality",Json::object()),"max",51) > 51 ? q * 51 / 63 : q;
            videoRate = .11 * std::pow(2,(18 - pivot) / 6) * efficiency * (p.contains("hw") && !p.at("hw").is_null() ? 1.25 : 1) * pixels * fps / 1000; approximate = true;
        }
    }
    if (Bool(a,"enabled",true) && media.contains("audio") && !media.at("audio").is_null()) {
        const auto& source = media.at("audio");
        const double rate = Num(res,"audioRate",a.contains("sampleRate") && a.at("sampleRate").is_number() ? Num(a,"sampleRate") : Num(source,"rate"));
        const double channels = Num(res,"audioChannels",Str(a,"channels","source") == "mono" ? 1 : Str(a,"channels","source") == "stereo" ? 2 : Num(source,"channels"));
        if (amode == "bitrate") audioRate = Num(res,"audioBitrateK",Num(a,"bitrateK",Num(ap.value("bitrate",Json::object()),"def",320)));
        else if (Str(ap,"family") == "pcm" || Str(ap,"family") == "pcmf") audioRate = Num(ap,"bits",24) * rate * channels / 1000;
        else { audioRate = .55 * 24 * rate * channels / 1000; approximate = true; }
    }
    const double perMinute = (videoRate + audioRate) * 1000 / 8 * 60;
    const double total = duration.is_null() ? 0 : perMinute * duration.get<double>() / 60;
    if (!std::isfinite(perMinute) || !std::isfinite(total) || std::max(perMinute,total) * (approximate ? 1.6 : 1) > 9.22e18) throw Error(VE_LIMIT_EXCEEDED,"ESTIMATE-LIMIT","Estimated size or its range exceeds signed 64-bit bytes.");
    result["available"] = true; result["approx"] = approximate; result["videoKbps"] = std::round(videoRate); result["audioKbps"] = std::round(audioRate); result["bytesPerMinute"] = perMinute;
    result["totalBytes"] = duration.is_null() ? Json(nullptr) : Json(total);
    result["minBytesPerMinute"] = approximate ? Json(perMinute * .6) : Json(nullptr); result["maxBytesPerMinute"] = approximate ? Json(perMinute * 1.6) : Json(nullptr);
    result["minTotalBytes"] = approximate && !duration.is_null() ? Json(total * .6) : Json(nullptr); result["maxTotalBytes"] = approximate && !duration.is_null() ? Json(total * 1.6) : Json(nullptr);
    result["explanation"] = approximate ? "Size depends on how busy the footage is; this is a rough guide, not a file-size guarantee." : "Calculated from the selected stream bitrates; container overhead is not included.";
    return result;
}
} // namespace ve
