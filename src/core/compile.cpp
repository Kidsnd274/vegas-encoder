#include "core.h"
#include <algorithm>
#include <cmath>
#include <cctype>
#include <iterator>
#include <limits>
#include <map>
#include <regex>
#include <sstream>
#include <utility>

namespace ve {
namespace {
std::string Number(double value) {
    std::ostringstream out; out.imbue(std::locale::classic()); out.precision(15); out << value; return out.str();
}
void Push(Json& tokens, const std::string& role, const Json& field, const std::vector<std::string>& args) {
    for (const auto& arg : args) tokens.push_back(Json{{"text",arg},{"role",role},{"field",field}});
}
void Pair(Json& tokens, const std::string& role, const std::string& field, const std::string& flag, const Json& value) {
    if (value.is_null() || flag.empty()) return;
    Push(tokens,role,field,{flag,value.is_string() ? value.get<std::string>() : value.is_number() ? Number(value.get<double>()) : value.dump()});
}
std::vector<std::string> Args(const Json& value) {
    std::vector<std::string> args; if (value.is_array()) for (const auto& v : value) args.push_back(v.get<std::string>()); return args;
}
std::vector<std::string> InputColorTags(const Json& recipe) {
    // Basic's tagging policy labels the raw input before automatic format
    // negotiation. Otherwise current swscale converts assumed source colors to
    // the requested output tags, changing even lossless FFV1 pixel samples.
    // Advanced uses only its active text, never inactive Basic color settings.
    if (Str(recipe.at("command"),"mode") == "template" || !Bool(recipe.at("video"),"enabled",true)) return {};
    const std::vector<std::string> names{"color_primaries","color_trc","colorspace","color_range"};
    std::map<std::string,std::string> values;
    if (Str(recipe.at("video"),"color","bt709") == "bt709")
        for (const auto& name : names) values[name] = name == "color_range" ? "tv" : "bt709";
    // Final Extra tag replacements are tagging policy too, not an implicit
    // colorspace transform. A deliberate transform belongs in an explicit filter.
    try {
        const auto words = Tokenize(Str(recipe.at("video"),"extra"));
        for (size_t i = 0; i + 1 < words.size(); ++i) {
            const auto key = OptionKey(words[i].text);
            if (IsOption(words[i].text) && std::find(names.begin(),names.end(),key) != names.end() && !IsOption(words[i+1].text)) values[key] = words[++i].text;
        }
    } catch (const Error&) {} // Validate already reports malformed Extra text.
    std::vector<std::string> result;
    for (const auto& name : names) if (values.count(name)) { result.push_back("-" + name); result.push_back(values.at(name)); }
    return result;
}
void Extra(Json& tokens, const std::string& text, const std::string& field, Json& overridden) {
    std::vector<Word> words;
    try { words = Tokenize(text); } catch (const Error&) { return; } // Lint emits the blocking syntax issue.
    const auto offsets = Utf16Map(text);
    std::map<std::string, bool> names;
    std::map<std::string, std::string> replaced;
    auto owned = [](const std::string& key) { return key == "c" || key == "i" || key == "f" || key == "map" || key == "vn" || key == "an" || key == "progress"; };
    for (const auto& word : words) if (IsOption(word.text) && !owned(OptionKey(word.text))) names[OptionKey(word.text)] = true;
    Json retained = Json::array();
    for (size_t i = 0; i < tokens.size(); ++i) {
        if (IsOption(Str(tokens[i],"text")) && names.count(OptionKey(Str(tokens[i],"text")))) {
            const auto source = Str(tokens[i],"field");
            replaced[OptionKey(Str(tokens[i],"text"))] = source;
            if (!source.empty() && std::find(overridden.begin(),overridden.end(),Json(source)) == overridden.end()) overridden.push_back(source);
            if (i + 1 < tokens.size() && !IsOption(Str(tokens[i+1],"text"))) ++i;
        } else retained.push_back(tokens[i]);
    }
    tokens = std::move(retained);
    std::string replacedField;
    for (size_t i = 0; i < words.size(); ++i) {
        const auto& word = words[i];
        if (IsOption(word.text) && owned(OptionKey(word.text))) {
            if (i + 1 < words.size() && !IsOption(words[i+1].text)) ++i;
            continue;
        }
        if (IsOption(word.text)) {
            const auto source = replaced.find(OptionKey(word.text));
            replacedField = source == replaced.end() ? "" : source->second;
        }
        tokens.push_back(Json{{"text",word.text},{"role","extra"},{"field",field},
            {"replacedField",replacedField.empty() ? Json(nullptr) : Json(replacedField)},
            {"sourceStart",offsets[word.start]},{"sourceEnd",offsets[word.end]}});
    }
}
double Bitrate(const std::string& text, double fallback) {
    try {
        size_t used = 0; double value = std::stod(text,&used);
        const auto unit = text.substr(used);
        if (unit == "k" || unit == "K") return value;
        if (unit == "m" || unit == "M") return value * 1000;
        if (unit.empty()) return value / 1000;
    } catch (const std::exception&) {}
    return fallback;
}
void ReadStream(const Json& tokens, Json& resolved, bool video) {
    bool unknownVideoFormatScope = false;
    for (size_t i = 0; i + 1 < tokens.size(); ++i) {
        const auto option = Str(tokens[i],"text"); const auto key = OptionKey(option); const auto value = Str(tokens[i+1],"text");
        if (!IsOption(Str(tokens[i],"text")) || (tokens[i].contains("isOption") && !Bool(tokens[i],"isOption"))) continue;
        const std::string prefix = video ? "video" : "audio";
        if (video) {
            ReflectVideoFormatOption(resolved,key,value);
            // Reflection models one video output, not general FFmpeg stream
            // selectors. Do not apply another stream's pixel format to it.
            if (key == "pix_fmt" && option != "-pix_fmt" && option != "-pix_fmt:v" && option != "-pix_fmt:v:0") unknownVideoFormatScope = true;
        }
        // Basic audio Extra arguments are emitted after the video arguments.
        // A cross-stream pixel option there can supersede the generated video
        // format; this audio resolver cannot establish that final video scope.
        if (!video && key == "pix_fmt") unknownVideoFormatScope = true;
        if ((key == "crf" || key == "cq" || key == "global_quality" || key == "qp_i") && video) {
            try { resolved["quality"] = std::stod(value); } catch (const std::exception&) {}
        }
        if (key == "qp" && video) { try { resolved["qp"] = std::stod(value); } catch (const std::exception&) {} }
        if (key == "preset" && video) resolved["speed"] = value;
        if (key == "tune" && video) resolved["tune"] = value;
        if (key == "b") resolved[prefix + "BitrateK"] = Bitrate(value,Num(resolved,prefix + "BitrateK"));
        if (key == "g" && video) { try { size_t used = 0; const auto frames = std::stoll(value,&used); resolved["gopFrames"] = used == value.size() && frames >= 1 && frames <= 2147483647 ? Json(frames) : Json(nullptr); } catch (const std::exception&) { resolved["gopFrames"] = nullptr; } }
        if (key == "sample_fmt" && !video) resolved["audioSampleFormat"] = value;
        if (key == "ar" && !video) { try { resolved["audioRate"] = std::stod(value); } catch (const std::exception&) {} }
        if (key == "ac" && !video) { try { resolved["audioChannels"] = std::stod(value); } catch (const std::exception&) {} }
        const bool unknownFilterStream = key == "filter" && option.find(":v") == std::string::npos && option.find(":a") == std::string::npos;
        if (key == "vf" || key == "filter_complex" || unknownFilterStream || (key == "filter" && video)) resolved["videoFilter"] = true;
        if (key == "af" || key == "filter_complex" || unknownFilterStream || (key == "filter" && !video)) resolved["audioFilter"] = true;
    }
    if (unknownVideoFormatScope) { resolved["pixfmt"] = ""; resolved["depth"] = 0; }
}
Json Basic(const Json& r, const Json& media, Json& res, Json& overridden) {
    const auto& v = r.at("video"); const auto& a = r.at("audio")[0]; const auto& c = r.at("container");
    // ordered_json object storage can move when reflected values add keys to res.
    // Keep profiles owned across ReadStream instead of borrowing its object entries.
    const Json p = res.at("videoProfile"); const Json ap = res.at("audioProfile");
    const auto mode = Str(res,"videoMode"); const auto amode = Str(res,"audioMode");
    Json out = Json::array(), video = Json::array(), audio = Json::array();
    if (Bool(v,"enabled",true)) Push(out,"map",nullptr,{"-map","0:v:0"});
    if (Bool(a,"enabled",true) && media.contains("audio") && !media.at("audio").is_null()) Push(out,"map",nullptr,{"-map","1:a:0"});
    if (Bool(v,"enabled",true)) {
        Pair(video,"video","video.encoder","-c:v",Str(res,"videoEncoder"));
        if (p.contains("speed")) Pair(video,"video","video.speed",Str(p.at("speed"),"flag"),res.at("speed"));
        if (Str(p,"id") == "libvpx-vp9") { Pair(video,"video","video.encoder","-deadline","good"); Pair(video,"video","video.encoder","-row-mt",1); }
        if (p.contains("tune")) Pair(video,"video","video.tune",Str(p.at("tune"),"flag"),res.at("tune"));
        const auto bitrate = Num(v,"bitrateK",Num(p.value("bitrate",Json::object()),"def",12000));
        const bool nv = Str(p,"hw") == "NVIDIA";
        const bool amf = Str(p,"id") == "h264_amf";
        if (mode == "crf") {
            Pair(video,"video","video.quality",Str(p.value("quality",Json::object()),"flag","-crf"),res.at("quality"));
            if (Str(p,"id") == "libvpx-vp9") Pair(video,"video","video.mode","-b:v",0);
        } else if (mode == "cq") {
            if (nv) { Pair(video,"video","video.mode","-rc","vbr"); Pair(video,"video","video.quality","-cq",res.at("quality")); Pair(video,"video","video.mode","-b:v",0); }
            else Pair(video,"video","video.quality",Str(p.value("quality",Json::object()),"flag","-global_quality"),res.at("quality"));
        } else if (mode == "abr" || mode == "cbr") {
            if (nv) Pair(video,"video","video.mode","-rc",mode == "cbr" ? "cbr" : "vbr");
            if (amf) Pair(video,"video","video.mode","-rc",mode == "cbr" ? "cbr" : "vbr_peak");
            Pair(video,"video","video.bitrateK","-b:v",Number(bitrate) + "k");
            if (mode == "cbr") { Pair(video,"video","video.bitrateK","-minrate",Number(bitrate) + "k"); Pair(video,"video","video.bitrateK","-maxrate",Number(bitrate) + "k"); Pair(video,"video","video.bitrateK","-bufsize",Number(bitrate * 2) + "k"); }
            else if (Num(v,"maxrateK") > 0) { Pair(video,"video","video.maxrateK","-maxrate",Number(Num(v,"maxrateK")) + "k"); Pair(video,"video","video.maxrateK","-bufsize",Number(Num(v,"maxrateK") * 2) + "k"); }
        } else if (mode == "cqp") {
            if (nv) Pair(video,"video","video.mode","-rc","constqp");
            const auto qp = Num(v,"qp",Num(p.value("qp",Json::object()),"def",20));
            if (amf) {
                Pair(video,"video","video.mode","-rc","cqp");
                for (const auto& flag : {"-qp_i","-qp_p","-qp_b"}) Pair(video,"video","video.qp",flag,qp);
            } else Pair(video,"video","video.qp",Str(p.value("qp",Json::object()),"flag","-qp"),qp);
        } else if (mode == "profile") {
            Pair(video,"video","video.profile","-profile:v",res.at("profile"));
            if (p.contains("vendor")) Pair(video,"video","video.encoder","-vendor",p.at("vendor"));
        } else if (mode == "lossless") Push(video,"video","video.mode",Args(p.value("fixedArgs",Json::array())));
        if (p.contains("multipass")) Pair(video,"video","video.multipass",Str(p.at("multipass"),"flag"),v.value("multipass",Json(nullptr)));
        if (mode != "profile") Pair(video,"video","video.profile","-profile:v",res.at("profile"));
        Pair(video,"video",mode == "profile" ? "video.profile" : "video.depth","-pix_fmt",Str(res,"pixfmt"));
        if (Num(v,"gopSec") > 0 && mode != "profile" && mode != "lossless") {
            const auto& fps = media.at("video").at("fps"); const double frames = std::round(Num(v,"gopSec") * fps[0].get<double>() / fps[1].get<double>());
            if (std::isfinite(frames) && frames >= 1 && frames <= 2147483647) Pair(video,"video","video.gopSec","-g",frames);
        }
        if (Str(v,"color","bt709") == "bt709") for (const auto& flag : {"-color_primaries","-color_trc","-colorspace","-color_range"}) Pair(video,"video","video.color",flag,std::string(flag) == "-color_range" ? "tv" : "bt709");
        if (p.contains("appleTag") && (Str(c,"format") == "mp4" || Str(c,"format") == "mov")) Pair(video,"video","video.encoder","-tag:v",p.at("appleTag"));
        const auto resize = ResizeChain(r,media);
        if (!resize.empty()) { Pair(video,"video","video.filters","-vf",resize); res["structuredResize"] = true; }
        Extra(video,Str(v,"extra"),"video.extra",overridden); ReadStream(video,res,true);
    } else Push(video,"video","video.enabled",{"-vn"});
    if (Bool(a,"enabled",true) && media.contains("audio") && !media.at("audio").is_null()) {
        Pair(audio,"audio","audio[0].encoder","-c:a",Str(a,"encoder"));
        if (amode == "bitrate") {
            Pair(audio,"audio","audio[0].bitrateK","-b:a",Number(Num(a,"bitrateK",Num(ap.value("bitrate",Json::object()),"def",320))) + "k");
            if (ap.contains("vbrMode")) Pair(audio,"audio","audio[0].mode","-vbr",ap.at("vbrMode"));
        } else if (amode == "vbr") Pair(audio,"audio","audio[0].vbr",Str(ap.value("vbr",Json::object()),"flag","-q:a"),Num(a,"vbr",Num(ap.value("vbr",Json::object()),"def")));
        if (ap.contains("level")) Pair(audio,"audio","audio[0].level",Str(ap.at("level"),"flag","-compression_level"),Num(a,"level",Num(ap.at("level"),"def")));
        if (a.contains("sampleRate") && a.at("sampleRate").is_number()) Pair(audio,"audio","audio[0].sampleRate","-ar",a.at("sampleRate"));
        if (Str(a,"channels","source") != "source") Pair(audio,"audio","audio[0].channels","-ac",Str(a,"channels") == "mono" ? 1 : 2);
        Extra(audio,Str(a,"extra"),"audio[0].extra",overridden); ReadStream(audio,res,false);
    } else Push(audio,"audio","audio[0].enabled",{"-an"});
    for (const auto& token : video) out.push_back(token); for (const auto& token : audio) out.push_back(token);
    if (Str(c,"format") == "mp4" && Bool(c,"faststart")) Pair(out,"mux","container.faststart","-movflags","+faststart");
    const auto container = FindContainer(Str(c,"format"));
    if (container) Pair(out,"mux","container.format","-f",Str(*container,"muxer"));
    return out;
}
std::string Expand(const std::string& token, const Json& media, const Json& catalogue, Json& issues) {
    const auto& fps = media.at("video").at("fps");
    std::map<std::string,std::string> macros;
    for (const auto& item : catalogue) if (Str(item,"name") != "{inputs}" && item.at("value").is_string()) macros[Str(item,"name")] = Str(item,"value");
    std::string result;
    auto append = [&](const std::string& value) {
        if (value.size() > VE_CORE_JSON_LIMIT || result.size() > VE_CORE_JSON_LIMIT - value.size()) throw Error(VE_LIMIT_EXCEEDED,"COMMAND-LIMIT","Expanded command token exceeds 1 MiB.");
        result += value;
    };
    for (size_t i = 0; i < token.size();) {
        if (token[i] != '{') { if (result.size() >= VE_CORE_JSON_LIMIT) throw Error(VE_LIMIT_EXCEEDED,"COMMAND-LIMIT","Expanded command token exceeds 1 MiB."); result += token[i++]; continue; }
        const auto end = token.find('}',i+1);
        if (end == std::string::npos) { append(token.substr(i)); break; }
        const auto macro = token.substr(i,end-i+1); const auto known = macros.find(macro);
        if (known != macros.end()) append(known->second);
        else if (macro.rfind("{gop:",0) == 0 && macro.size() > 7 && macro[macro.size()-2] == 's') {
            const auto value = macro.substr(5,macro.size()-7); double seconds = 0;
            try { size_t used = 0; seconds = std::stod(value,&used); if (used != value.size()) seconds = 0; } catch (const std::exception&) {}
            const auto frames = std::round(seconds * fps[0].get<double>() / fps[1].get<double>());
            if (!(frames >= 1 && frames <= 2147483647)) { issues.push_back(Issue("L-GOP","error","command.template","Keyframe macro is outside FFmpeg's frame-count bounds.")); append(macro); }
            else append(Number(frames));
        } else append(macro);
        i = end+1;
    }
    return result;
}
void Reflected(const Json& tokens, Json& res) {
    Json video = Json::array(), audio = Json::array();
    std::string kind = "video";
    for (size_t i = 0; i < tokens.size(); ++i) {
        if (Str(tokens[i],"role") == "output") break; // Later options cannot describe this output.
        // TokenMetadata already establishes input/output option scope. Options
        // before {inputs}/-i describe that input, not the encoded output.
        if (Str(tokens[i],"stage") == "input") continue;
        const auto option = Str(tokens[i],"text"), key = IsOption(option) && (!tokens[i].contains("isOption") || Bool(tokens[i],"isOption")) ? OptionKey(option) : "";
        if (!key.empty() && option == "-vn") res["videoEnabled"] = false;
        if (!key.empty() && option == "-an") res["audioEnabled"] = false;
        if (!key.empty() && (option.find(":a") != std::string::npos || option == "-acodec" || key == "ar" || key == "ac" || key == "af" || key == "sample_fmt")) kind = "audio";
        if (!key.empty() && (option.find(":v") != std::string::npos || option == "-vcodec" || key == "pix_fmt" || key == "vf")) kind = "video";
        if (key == "c" && i + 1 < tokens.size()) {
            const auto encoder = Str(tokens[i+1],"text"); res[kind + "Encoder"] = encoder;
            const auto p = FindProfile(kind,encoder); res[kind + "Profile"] = p ? *p : Json{{"family","unknown"}};
        }
        if (key == "f" && i + 1 < tokens.size()) {
            const auto muxer = Str(tokens[i+1],"text");
            res["container"] = ""; // A later unknown muxer must not retain an earlier fact.
            for (const auto& c : Profiles().at("containers")) if (Str(c,"muxer") == muxer) res["container"] = Str(c,"id");
        }
        (kind == "video" ? video : audio).push_back(tokens[i]);
    }
    ReadStream(video,res,true); ReadStream(audio,res,false);
}
}
namespace {
bool VideoOption(const std::string& option, bool filterOnly) {
    const auto name = option.rfind("-/",0) == 0 ? "-" + option.substr(2) : option;
    const auto key = OptionKey(name);
    if (key == "vf" || key == "filter_complex" || key == "filter_complex_script" || key == "lavfi") return true;
    if (key == "filter" || key == "filter_script") return name.find(":a") == std::string::npos;
    return !filterOnly && (key == "s" || key == "aspect" || key == "autoscale") && name.find(":a") == std::string::npos;
}
bool ExtraVideoOption(const Json& recipe, bool filterOnly) {
    for (const auto& settings : {recipe.at("video"),recipe.at("audio")[0]}) {
        if (!Bool(settings,"enabled",true)) continue;
        try {
            const auto words = Tokenize(Str(settings,"extra")); const auto metadata = TokenMetadata(words,Json(nullptr));
            for (size_t i = 0; i < words.size(); ++i) if (Bool(metadata[i],"isOption") && VideoOption(words[i].text,filterOnly)) return true;
        } catch (const Error&) {} // Syntax issues independently prevent rendering.
    }
    return false;
}
const Json* ActiveResize(const Json& recipe) {
    if (FilterControl(recipe) != "structured" || !Bool(recipe.at("video"),"enabled",true)) return nullptr;
    const auto filters = recipe.at("video").find("filters");
    if (filters == recipe.at("video").end() || !filters->is_array()) return nullptr;
    for (const auto& filter : *filters) if (Str(filter,"type") == "resize" && Bool(filter,"enabled",true)) return &filter;
    return nullptr;
}
std::pair<int,int> ResizeAlignment(const Json& recipe) {
    auto resolved = Resolve(recipe);
    for (const auto& settings : {recipe.at("video"),recipe.at("audio")[0]}) if (Bool(settings,"enabled",true)) try {
        const auto words = Tokenize(Str(settings,"extra"));
        for (size_t i = 0; i + 1 < words.size(); ++i) if (IsOption(words[i].text)) ReflectVideoFormatOption(resolved,OptionKey(words[i].text),words[i+1].text);
    } catch (const Error&) {}
    const auto chroma = Str(VideoFormat(Str(resolved,"pixfmt")),"chroma");
    // Unknown negotiated formats use the conservative 4:2:0 grid; this is an
    // alignment policy, never a claim about their color/precision conversion.
    return chroma == "4:4:4" ? std::pair{1,1} : chroma == "4:2:2" ? std::pair{2,1} : std::pair{2,2};
}
std::string SarText(const Json& media) {
    if (!media.is_object() || !media.contains("video")) return {};
    auto text = Str(media.at("video"),"sar");
    const auto divider = text.find_first_of(":/");
    if (divider == std::string::npos) return {};
    try {
        size_t a = 0, b = 0; const auto left = text.substr(0,divider), right = text.substr(divider+1);
        const auto numerator = std::stoll(left,&a), denominator = std::stoll(right,&b);
        if (a != left.size() || b != right.size() || numerator <= 0 || denominator <= 0 || numerator > 1000000000 || denominator > 1000000000) return {};
        return std::to_string(numerator) + "/" + std::to_string(denominator);
    } catch (const std::exception&) { return {}; }
}
std::string AlgorithmLabel(const std::string& algorithm) {
    return algorithm == "bicubic" ? "Bicubic" : algorithm == "bilinear" ? "Bilinear" : algorithm == "lanczos" ? "Lanczos" : "Nearest neighbour";
}
}
std::string FilterControl(const Json& recipe) {
    if (Str(recipe.at("command"),"mode") == "template") return "advanced";
    return ExtraVideoOption(recipe,true) ? "extra" : "structured";
}
Json VideoGeometry(const Json& recipe, const Json& media) {
    const bool known = media.is_object() && media.contains("video");
    Json geometry{{"inputWidth",known ? media.at("video").at("width") : Json(nullptr)},
        {"inputHeight",known ? media.at("video").at("height") : Json(nullptr)},
        {"width",nullptr},{"height",nullptr},{"sar",nullptr},{"contentWidth",nullptr},{"contentHeight",nullptr},
        {"padLeft",nullptr},{"padTop",nullptr},{"padRight",nullptr},{"padBottom",nullptr},{"direction","unknown"},{"rounded",nullptr}};
    if (FilterControl(recipe) != "structured" || ExtraVideoOption(recipe,false)) return geometry;
    const auto resize = ActiveResize(recipe);
    if (!resize) {
        if (known) { geometry["width"] = geometry["inputWidth"]; geometry["height"] = geometry["inputHeight"]; geometry["direction"] = "unchanged"; geometry["rounded"] = false; }
        return geometry;
    }
    geometry["width"] = resize->at("width"); geometry["height"] = resize->at("height"); geometry["sar"] = "1:1";
    const auto sar = SarText(media);
    if (!known || sar.empty()) return geometry;
    const auto divider = sar.find('/'); const double aspect = std::stod(sar.substr(0,divider)) / std::stod(sar.substr(divider+1));
    const double inputWidth = Num(media.at("video"),"width"), inputHeight = Num(media.at("video"),"height");
    const double dar = inputWidth * aspect / inputHeight;
    const auto [alignX,alignY] = ResizeAlignment(recipe);
    const double idealWidth = std::min(Num(*resize,"width"),Num(*resize,"height") * dar);
    const double idealHeight = std::min(Num(*resize,"height"),Num(*resize,"width") / dar);
    const auto width = static_cast<int>(std::floor(idealWidth / alignX)) * alignX;
    const auto height = static_cast<int>(std::floor(idealHeight / alignY)) * alignY;
    const auto x = static_cast<int>(std::floor((Num(*resize,"width") - width) / (2 * alignX))) * alignX;
    const auto y = static_cast<int>(std::floor((Num(*resize,"height") - height) / (2 * alignY))) * alignY;
    geometry["contentWidth"] = width; geometry["contentHeight"] = height;
    geometry["padLeft"] = x; geometry["padTop"] = y; geometry["padRight"] = static_cast<int>(Num(*resize,"width")) - width - x; geometry["padBottom"] = static_cast<int>(Num(*resize,"height")) - height - y;
    geometry["rounded"] = std::abs(idealWidth-width) > 1e-8 || std::abs(idealHeight-height) > 1e-8;
    geometry["direction"] = width == inputWidth && height == inputHeight ? "unchanged" : width >= inputWidth && height >= inputHeight ? "upscale" : width <= inputWidth && height <= inputHeight ? "downscale" : "mixed";
    return geometry;
}
std::string ResizeChain(const Json& recipe, const Json& media, bool seed) {
    const auto resize = ActiveResize(recipe); if (!resize) return {};
    const auto [alignX,alignY] = ResizeAlignment(recipe);
    const auto width = Number(Num(*resize,"width")), height = Number(Num(*resize,"height"));
    const auto sar = seed ? std::string("{sar}") : SarText(media);
    const auto prefix = sar.empty() ? std::string() : "setsar=" + sar + ",";
    return prefix + "scale=w='trunc(min(" + width + "," + height + "*dar)/" + Number(alignX) + ")*" + Number(alignX) +
        "':h='trunc(min(" + height + "," + width + "/dar)/" + Number(alignY) + ")*" + Number(alignY) + "':flags=" + Str(*resize,"algorithm") +
        ",setsar=1,pad=" + width + ":" + height + ":'trunc((ow-iw)/" + Number(2*alignX) + ")*" + Number(alignX) +
        "':'trunc((oh-ih)/" + Number(2*alignY) + ")*" + Number(alignY) + "':color=black";
}
void ValidateFilters(const Json& recipe, const Json& media, const Json& capabilities, Json& issues) {
    const auto resize = ActiveResize(recipe); if (!resize) return;
    const std::string field = "video.filters[0]";
    const auto [alignX,alignY] = ResizeAlignment(recipe);
    if (static_cast<int>(Num(*resize,"width")) % alignX || static_cast<int>(Num(*resize,"height")) % alignY)
        issues.push_back(Issue("V-FILTER-ALIGNMENT","error",field,"Canvas dimensions must align with the selected pixel format's chroma grid.",{{"horizontal",alignX},{"vertical",alignY}}));
    if (ExtraVideoOption(recipe,false)) issues.push_back(Issue("V-FILTER-GEOMETRY-CONFLICT","error",field,"Remove the output size/aspect option from Extra arguments before using structured resize."));
    const auto geometry = VideoGeometry(recipe,media);
    if (geometry.at("contentWidth").is_number() && (Num(geometry,"contentWidth") < alignX || Num(geometry,"contentHeight") < alignY))
        issues.push_back(Issue("V-FILTER-ASPECT","error",field,"This aspect ratio cannot fit the canvas on the selected pixel format's chroma grid."));
    if (geometry.at("rounded") == true) issues.push_back(Issue("V-FILTER-ROUNDING","info",field,"Fitted picture dimensions are rounded down to the pixel format's chroma grid.",geometry));
    if (media.is_object() && media.contains("video") && media.at("video").contains("sar") && SarText(media).empty())
        issues.push_back(Issue("V-FILTER-SAR","error",field,"The delivered sample aspect ratio must be a positive rational value."));
    if (!capabilities.is_object()) { issues.push_back(Issue("V-FILTER-UNVERIFIED","warn",field,"Select and refresh FFmpeg to verify the required scale, pad, setsar filters and scaling algorithm.")); return; }
    const auto filters = capabilities.value("filters",Json::object());
    for (const auto* name : {"scale","pad","setsar"}) {
        if (!filters.is_object() || !filters.contains(name) || !filters.at(name).is_object() || !Bool(filters.at(name),"available") ||
            !filters.at(name).contains("options") || !filters.at(name).at("options").is_array() || filters.at(name).at("options").empty())
            issues.push_back(Issue("V-FILTER-MISSING","error",field,std::string("The selected FFmpeg does not provide verified ") + name + " filter help. Refresh FFmpeg or choose a build containing it.",{{"filter",name}}));
        else {
            const auto has = [&](const std::vector<std::string>& aliases) {
                const auto& options = filters.at(name).at("options");
                return std::any_of(options.begin(),options.end(),[&](const Json& option) { auto key = Str(option,"name"); if (!key.empty() && key[0] == '-') key.erase(0,1); return std::find(aliases.begin(),aliases.end(),key) != aliases.end(); });
            };
            const std::vector<std::vector<std::string>> required = std::string(name) == "scale" ? std::vector<std::vector<std::string>>{{"w","width"},{"h","height"},{"flags"}} :
                std::string(name) == "pad" ? std::vector<std::vector<std::string>>{{"w","width"},{"h","height"},{"x"},{"y"},{"color"}} : std::vector<std::vector<std::string>>{{"sar","ratio","r"}};
            for (const auto& aliases : required) if (!has(aliases)) issues.push_back(Issue("V-FILTER-OPTION","error",field,std::string("The selected FFmpeg does not report required ") + name + " option " + aliases.front() + ". Refresh FFmpeg or choose a supported build.",{{"filter",name},{"option",aliases.front()}}));
        }
    }
    if (filters.is_object() && filters.contains("scale") && filters.at("scale").is_object()) {
        const auto algorithms = filters.at("scale").value("algorithms",Json::array());
        if (!algorithms.is_array() || std::find(algorithms.begin(),algorithms.end(),resize->at("algorithm")) == algorithms.end())
            issues.push_back(Issue("V-FILTER-ALGORITHM","error",field,"The selected FFmpeg does not report support for this scaling algorithm. Refresh FFmpeg or select a supported algorithm.",{{"algorithm",resize->at("algorithm")}}));
    }
}
Json InputTokens(const Json& r, const Json& media, const Json& paths) {
    const auto& v = media.at("video"); const auto& fps = v.at("fps"); Json result = Json::array();
    Push(result,"input",nullptr,InputColorTags(r));
    if (Bool(paths,"liveInputs")) Push(result,"input",nullptr,{"-probesize","32","-analyzeduration","0"});
    Push(result,"input",nullptr,{"-f","rawvideo","-pix_fmt",Str(v,"pixfmt","p010le"),"-s",Number(Num(v,"width")) + "x" + Number(Num(v,"height")),
         "-r",fps[0].dump() + "/" + fps[1].dump(),"-i",Str(paths,"videoPipe")});
    if (Bool(r.at("audio")[0],"enabled",true) && media.contains("audio") && !media.at("audio").is_null()) {
        const auto& a = media.at("audio");
        if (Bool(paths,"liveInputs")) Push(result,"input",nullptr,{"-probesize","32","-analyzeduration","0"});
        Push(result,"input",nullptr,{"-f",Str(a,"sampleFmt","f32le"),"-ar",Number(Num(a,"rate")),"-ac",Number(Num(a,"channels")),"-i",Str(paths,"audioPipe")});
    }
    return result;
}
const Json& MacroDefinitions() {
    static const Json definitions = Json::array({
        {{"name","{inputs}"},{"description","Raw video and available audio from VEGAS"},{"required",true}},
        {{"name","{output}"},{"description","Selected preview path or allocated render output path"},{"required",true}},
        {{"name","{v}"},{"description","First VEGAS video stream (0:v:0)"},{"required",false}},
        {{"name","{a}"},{"description","First VEGAS audio stream (1:a:0)"},{"required",false}},
        {{"name","{width}"},{"description","Delivered video width in pixels"},{"required",false}},
        {{"name","{height}"},{"description","Delivered video height in pixels"},{"required",false}},
        {{"name","{sar}"},{"description","Delivered sample aspect ratio; source filter aspect when unknown"},{"required",false}},
        {{"name","{fps}"},{"description","Delivered rational video frame rate"},{"required",false}},
        {{"name","{sample_rate}"},{"description","Delivered audio sample rate; empty without audio"},{"required",false}},
        {{"name","{project}"},{"description","Supplied project name (may be empty)"},{"required",false}},
        {{"name","{gop:2s}"},{"description","Keyframe interval in frames; replace 2 with seconds"},{"required",false}}
    });
    return definitions;
}
Json Macros(const Json& request) {
    const auto& media = request.at("media"); const auto& paths = request.at("paths"); CheckMedia(media);
    const auto& v = media.at("video"); const auto& fps = v.at("fps");
    const auto a = media.value("audio",Json(nullptr));
    auto recipe = request.value("recipe",Json{{"video",{{"enabled",true}}},{"audio",Json::array({{{"enabled",true}}})},{"command",{{"mode","template"}}}});
    std::string inputs;
    for (const auto& token : InputTokens(recipe,media,paths)) { if (!inputs.empty()) inputs += " "; inputs += Quote(Str(token,"text")); }
    const auto frames = std::round(2 * fps[0].get<double>() / fps[1].get<double>());
    const std::vector<Json> values{inputs,Str(paths,"output"),"0:v:0","1:a:0",Number(Num(v,"width")),Number(Num(v,"height")),
        SarText(media).empty() ? "sar" : SarText(media),
        fps[0].dump() + "/" + fps[1].dump(),a.is_null() ? "" : Number(Num(a,"rate")),Str(paths,"project"),
        frames >= 1 && frames <= 2147483647 ? Json(Number(frames)) : Json(nullptr)};
    auto result = MacroDefinitions();
    for (size_t i = 0; i < result.size(); ++i) result[i]["value"] = values[i];
    return result;
}
static Json CompileInternal(const Json& request, const Json* capabilities, Json* effective = nullptr) {
    const auto& r = request.at("recipe"); const auto& media = request.at("media"); const auto& paths = request.at("paths");
    CheckMedia(media);
    if (!paths.is_object() || Str(paths,"ffmpeg","ffmpeg").empty() || Str(paths,"videoPipe").empty() || Str(paths,"output").empty()) throw Error(VE_INVALID_ARGUMENT,"PATHS","Executable, video pipe and output path must be nonempty strings.");
    Json issues = Validate(request,capabilities); const auto exe = Str(paths,"ffmpeg","ffmpeg");
    Json result{{"executable",exe},{"argv",Json::array()},{"display",Json::array()},{"commandLine",""},{"advancedTemplate",""},{"resolved",nullptr},{"signalPath",nullptr},{"issues",issues},{"summary",Json::object()},{"overriddenFields",Json::array()},{"expectedStreams",nullptr},{"outputContainerId",nullptr},{"outputExtension",nullptr},{"filterControl","structured"},{"videoGeometry",nullptr}};
    if (HasErrors(Structural(r))) return result;
    result["filterControl"] = FilterControl(r); result["videoGeometry"] = VideoGeometry(r,media);
    const bool audioInput = Bool(r.at("audio")[0],"enabled",true) && media.contains("audio") && !media.at("audio").is_null();
    result["inputStreams"] = audioInput ? Json::array({"video","audio"}) : Json::array({"video"});
    if (audioInput && Str(paths,"audioPipe").empty()) throw Error(VE_INVALID_ARGUMENT,"PATHS","Enabled audio needs a pipe path.");
    bool partialCommand = false;
    Json tokens = Json::array(); Push(tokens,"exe",nullptr,{exe});
    Push(tokens,"global",nullptr,{"-hide_banner","-nostdin","-loglevel","info","-stats_period","0.2","-progress","pipe:1"});
    if (Bool(paths,"overwriteOutput")) Push(tokens,"global",nullptr,{"-y"});
    const auto input = InputTokens(r,media,paths); Json res = Resolve(r); res["gopFrames"] = nullptr;
    const bool advanced = Str(r.at("command"),"mode") == "template";
    if (!advanced) {
        for (const auto& token : input) tokens.push_back(token);
        const auto basic = Basic(r,media,res,result["overriddenFields"]); for (const auto& token : basic) tokens.push_back(token);
        std::string seed;
        // Preserve the tagging policy when {inputs} is expanded in Advanced,
        // where inactive Basic fields deliberately do not alter the source.
        for (const auto& tag : InputColorTags(r)) seed += Quote(tag) + " ";
        seed += "{inputs}\n"; std::string lastRole;
        for (const auto& token : basic) {
            const auto role = Str(token,"role"); if (!lastRole.empty()) seed += lastRole == role ? " " : "\n";
            seed += Quote(Str(token,"field") == "video.filters" && !IsOption(Str(token,"text")) ? ResizeChain(r,media,true) : Str(token,"text")); lastRole = role;
        }
        result["advancedTemplate"] = seed + "\n{output}";
        Push(tokens,"output",nullptr,{Str(paths,"output")});
    } else {
        const auto text = Str(r.at("command"),"template"); result["advancedTemplate"] = text;
        const auto offsets = Utf16Map(text);
        // Reflect only the active command; inactive Basic fields are never claimed as command facts.
        res = Json{{"videoEncoder",""},{"audioEncoder",""},{"videoProfile",{{"family","unknown"}}},{"audioProfile",{{"family","unknown"}}},
                   {"videoMode",""},{"audioMode",""},{"pixfmt",""},{"depth",0},{"container",""},{"gopFrames",nullptr},
                   {"quality",nullptr},{"speed",nullptr},{"tune",nullptr},{"profile",nullptr},{"videoEnabled",true},{"audioEnabled",audioInput}};
        std::vector<Word> words;
        size_t quote = text.size(); words = Tokenize(text,&quote); partialCommand = quote != text.size();
        const Json noCapabilities = nullptr;
        const auto metadata = TokenMetadata(words,capabilities ? *capabilities : request.contains("capabilities") ? request.at("capabilities") : noCapabilities);
        Json reflected = Json::array();
        size_t expandedBytes = 0;
        const auto catalogue = Macros(Json{{"media",media},{"paths",paths},{"recipe",r}});
        for (size_t i = 0; i < words.size(); ++i) {
            const auto& word = words[i];
            if (i == 0 && (word.text == "ffmpeg" || word.text == "ffmpeg.exe")) continue;
            if (word.text == "-hide_banner" || word.text == "-nostdin") continue;
            if (word.text == "{inputs}") {
                for (auto token : input) { token["macros"] = Json::array({"{inputs}"}); token["stage"] = "input"; expandedBytes += Str(token,"text").size(); token["sourceStart"] = offsets[word.start]; token["sourceEnd"] = offsets[word.end]; tokens.push_back(token); }
                if (expandedBytes > VE_CORE_JSON_LIMIT) throw Error(VE_LIMIT_EXCEEDED,"COMMAND-LIMIT","Expanded command exceeds 1 MiB.");
                continue;
            }
            const auto prior = issues.size(); const auto expanded = Expand(word.text,media,catalogue,issues);
            expandedBytes += expanded.size();
            if (expandedBytes > VE_CORE_JSON_LIMIT) throw Error(VE_LIMIT_EXCEEDED,"COMMAND-LIMIT","Expanded command exceeds 1 MiB.");
            for (size_t j = prior; j < issues.size(); ++j) { issues[j]["params"]["start"] = offsets[word.start]; issues[j]["params"]["end"] = offsets[word.end]; }
            auto token = Json{{"text",expanded},{"role",word.text == "{output}" ? "output" : "extra"},{"field","command.template"},
                              {"sourceStart",offsets[word.start]},{"sourceEnd",offsets[word.end]}};
            token["stage"] = metadata[i].at("stage"); token["isOption"] = metadata[i].at("isOption"); token["macros"] = metadata[i].at("macros");
            if (word.text == "{output}") token["role"] = "output";
            else if (!token.at("macros").empty()) token["role"] = "macro";
            else if (token.at("stage").is_string() && token.at("stage") != "input" && token.at("stage") != "output") token["role"] = token.at("stage");
            tokens.push_back(token); reflected.push_back(token);
        }
        Reflected(reflected,res);
        const bool extraInputs = std::any_of(issues.begin(),issues.end(),[](const Json& issue) { return Str(issue,"id") == "L-INPUT"; });
        const bool extraOutputs = std::any_of(issues.begin(),issues.end(),[](const Json& issue) { return Str(issue,"id") == "L-OUTPUTS"; });
        const auto output = std::find_if(reflected.begin(),reflected.end(),[](const Json& token) { return Str(token,"role") == "output"; });
        const bool trailingOptions = output != reflected.end() && std::next(output) != reflected.end();
        if (extraInputs || extraOutputs || trailingOptions) {
            // General stream selection/output scoping needs FFmpeg. Keep the
            // source node, but do not label another input/output as the VG stream.
            res["pixfmt"] = ""; res["videoEncoder"] = ""; res["audioEncoder"] = "";
            res["videoProfile"] = Json{{"family","unknown"}}; res["audioProfile"] = Json{{"family","unknown"}};
            res["container"] = ""; res["unknownInputSource"] = extraInputs; res["unknownOutputScope"] = true;
            for (const auto& key : {"audioSampleFormat","audioRate","audioChannels"}) res.erase(key);
        }
        result["resolved"] = nullptr;
    }
    const Json noCaps = nullptr;
    const Json& caps = capabilities ? *capabilities : request.contains("capabilities") ? request.at("capabilities") : noCaps;
    // Validate actual emitted generated values against this build's private help.
    // Extra text was linted in Validate; it keeps its own spans and issue fields.
    if (!advanced && caps.is_object()) for (size_t i = 0; i + 1 < tokens.size(); ++i) {
        const auto role = Str(tokens[i],"role"), field = Str(tokens[i],"field");
        if ((role != "video" && role != "audio") || !IsOption(Str(tokens[i],"text")) || IsOption(Str(tokens[i+1],"text"))) continue;
        const auto encoder = Str(res,role + "Encoder");
        const auto flag = Str(tokens[i],"text"), value = Str(tokens[i+1],"text");
        if (!ValidEncoderOption(caps,encoder,role,flag,value))
            issues.push_back(Issue("V-BUILD-VALUE","error",field,"The selected FFmpeg build does not accept this generated option value.",{{"option",flag},{"value",value},{"encoder",encoder}}));
    }
    if (!advanced && Bool(res,"videoEnabled",Bool(r.at("video"),"enabled",true)) && caps.is_object()) {
        const auto detail = EncoderOptions(caps,Str(res,"videoEncoder"));
        if (!Str(res,"pixfmt").empty() && detail && detail->contains("pixelFormats") && !detail->at("pixelFormats").empty() &&
            std::find(detail->at("pixelFormats").begin(),detail->at("pixelFormats").end(),Json(Str(res,"pixfmt"))) == detail->at("pixelFormats").end())
            issues.push_back(Issue("V-BUILD-PIXFMT","error","video.depth","The selected FFmpeg encoder does not list this output pixel format.",{{"format",Str(res,"pixfmt")}}));
    }
    auto signal = Signal(r,media,res,caps);
    const bool unknownVideo = !signal.at("video").is_null() && signal.at("video").at("outputBits").is_null();
    if (!signal.at("video").is_null()) res["depth"] = unknownVideo ? Json(0) : signal.at("video").at("outputBits");
    if (!advanced && Bool(res,"videoEnabled",Bool(r.at("video"),"enabled",true))) CheckVideoProfile(res,issues);
    if (!advanced) {
        Json publicRes = res; publicRes.erase("videoProfile"); publicRes.erase("audioProfile");
        result["resolved"] = unknownVideo ? Json(nullptr) : publicRes;
        if (!signal.at("video").is_null()) {
            const auto& fact = signal.at("video");
            if (!fact.at("inputBits").is_null() && !fact.at("outputBits").is_null() && fact.at("inputBits").get<int>() > fact.at("outputBits").get<int>()) issues.push_back(Issue("V-DEPTH-DOWN","info","video.depth","Precision is reduced before encoding.",{{"inputBits",fact.at("inputBits")},{"outputBits",fact.at("outputBits")}}));
            if (fact.at("chromaChanged") == true) issues.push_back(Issue("V-CHROMA-UP","info","video.depth","Chroma sampling changes; added color resolution is interpolated, not recovered.",{{"inputChroma",fact.at("inputChroma")},{"outputChroma",fact.at("outputChroma")}}));
        }
    }
    for (auto& issue : issues) {
        Json refs = Json::array(); const auto field = Str(issue,"field"); const auto params = issue.value("params",Json::object()); const auto stream = Str(params,"stream");
        for (size_t i = 0; i < tokens.size(); ++i) {
            const auto tokenField = Str(tokens[i],"field"); bool match = !field.empty() && tokenField == field;
            if (!stream.empty() && tokenField == stream + ".encoder") match = true;
            if (field == "video.depth" && i > 0 && (Str(tokens[i],"text") == "-pix_fmt" || Str(tokens[i-1],"text") == "-pix_fmt") && Str(tokens[i],"role") != "input") match = true;
            if (advanced && params.contains("start") && tokens[i].contains("sourceStart")) match = Num(tokens[i],"sourceStart") < Num(params,"end") && Num(tokens[i],"sourceEnd") > Num(params,"start");
            if (!advanced && field.find(".extra") != std::string::npos && params.contains("start")) match = tokenField == field && tokens[i].contains("sourceStart") && Num(tokens[i],"sourceStart") < Num(params,"end") && Num(tokens[i],"sourceEnd") > Num(params,"start");
            if (match) refs.push_back(i);
        }
        issue["tokenIndices"] = refs;
    }
    std::string commandLine;
    for (size_t i = 0; i < tokens.size(); ++i) { if (i) commandLine += " "; commandLine += Quote(Str(tokens[i],"text")); if (i) result["argv"].push_back(Str(tokens[i],"text")); }
    result["display"] = tokens; result["commandLine"] = commandLine; result["signalPath"] = signal; result["issues"] = issues; result["summary"] = Summary(r,res);
    // This is an established command fact, independent of the path's extension
    // and the inactive Basic controls in Advanced mode. An explicit, known muxer
    // is required there; partial/general output scope leaves it unknown.
    if (!partialCommand && !Bool(res,"unknownOutputScope")) {
        const auto container = FindContainer(advanced ? Str(res,"container") : Str(r.at("container"),"format"));
        if (container) { result["outputContainerId"] = Str(*container,"id"); result["outputExtension"] = Str(*container,"ext"); }
    }
    // IDs are established below only after conservative stream-map qualification.
    result["summary"]["videoEncoderId"] = nullptr; result["summary"]["audioEncoderId"] = nullptr;
    if (partialCommand) { result["argv"] = Json::array(); result["commandLine"] = ""; }
    bool expectedScope = !Bool(res,"unknownOutputScope") && !partialCommand;
    bool expectedVideo = Bool(res,"videoEnabled",Bool(r.at("video"),"enabled",true));
    bool expectedAudio = Bool(res,"audioEnabled",audioInput);
    if (advanced && expectedScope) {
        size_t videoMaps = 0, audioMaps = 0; bool mapped = false;
        for (size_t i = 0; i < tokens.size(); ++i) {
            if (Str(tokens[i],"field") != "command.template") continue;
            if (Str(tokens[i],"stage") == "input") continue;
            if (!IsOption(Str(tokens[i],"text")) || (tokens[i].contains("isOption") && !Bool(tokens[i],"isOption"))) continue;
            const auto key = OptionKey(Str(tokens[i],"text"));
            const auto option = Str(tokens[i],"text");
            if (key == "c" && option != "-c:v" && option != "-c:a" && option != "-c:v:0" && option != "-c:a:0" &&
                option != "-vcodec" && option != "-acodec" && option != "-codec:v" && option != "-codec:a") expectedScope = false;
            if (key == "filter_complex") expectedScope = false;
            if (key != "map") continue;
            mapped = true;
            if (i + 1 >= tokens.size()) { expectedScope = false; continue; }
            auto source = Str(tokens[++i],"text");
            if (!source.empty() && source.back() == '?') source.pop_back();
            if (source == "0:v:0") ++videoMaps;
            else if (source == "1:a:0" && audioInput) ++audioMaps;
            else expectedScope = false;
        }
        // General maps, duplicate streams and complex-filter outputs need FFmpeg
        // to establish their output scope. Never infer them from Basic controls.
        if (mapped) {
            expectedScope = expectedScope && videoMaps <= 1 && audioMaps <= 1;
            expectedVideo = expectedVideo && videoMaps == 1;
            expectedAudio = expectedAudio && audioMaps == 1;
        }
    }
    if (expectedScope) {
        Json expected = Json::array();
        for (const auto& kind : {std::string("video"),std::string("audio")}) {
            if (!(kind == "video" ? expectedVideo : expectedAudio)) continue;
            const auto encoder = Str(res,kind + "Encoder"); const auto& profile = res.at(kind + "Profile");
            std::string codec; const auto supplied = EncoderOptions(caps,encoder);
            if (supplied) codec = Str(*supplied,"codec");
            if (codec.empty()) {
                const auto family = Str(profile,"family");
                if (family == "pcm" || family == "pcmf") codec = encoder;
                else if (family == "dnxhr") codec = "dnxhd";
                else if (family != "unknown") codec = family;
            }
            Json stream{{"kind",kind},{"encoder",encoder.empty() ? Json(nullptr) : Json(encoder)},{"codec",codec.empty() ? Json(nullptr) : Json(codec)}};
            // Existing commands keep their verification contract. Structured
            // processing adds established encoded geometry; handwritten graphs
            // remain unknown and never inherit inactive Basic canvas settings.
            if (kind == "video" && ActiveResize(r)) for (const auto* fact : {"width","height","sar"}) stream[fact] = result.at("videoGeometry").value(fact,Json(nullptr));
            expected.push_back(std::move(stream));
        }
        result["expectedStreams"] = expected;
        bool explicitScope = true;
        if (advanced) for (const auto& token : tokens) {
            if (Str(token,"field") != "command.template" || !Bool(token,"isOption")) continue;
            const auto name = Str(token,"text");
            if (OptionKey(name) == "c" && name != "-c:v" && name != "-c:a" && name != "-c:v:0" && name != "-c:a:0" && name != "-vcodec" && name != "-acodec" && name != "-codec:v" && name != "-codec:a") explicitScope = false;
        }
        if (explicitScope) for (const auto& stream : expected) {
            result["summary"][Str(stream,"kind") + "EncoderId"] = Str(stream,"encoder") == "copy" ? Json(nullptr) : stream.at("encoder");
        }
    }
    const auto container = result.at("outputContainerId").is_string() ? FindContainer(result.at("outputContainerId").get<std::string>()) : nullptr;
    if (container && caps.is_object() && caps.contains("muxers") && caps.at("muxers").is_object() &&
        !caps.at("muxers").contains(Str(*container,"muxer")))
        result["issues"].push_back(Issue("V-MUXER-MISSING","error",advanced ? "command.template" : "container.format",
            "The selected FFmpeg does not list the required output muxer.",{{"muxer",Str(*container,"muxer")}}));
    // Target constraints are transport context, never portable recipe policy.
    const auto target = paths.value("target",Json(nullptr));
    if (!target.is_null()) {
        if (!target.is_object() || Str(target,"id") != "vegas-native-v1") throw Error(VE_INVALID_ARGUMENT,"TARGET","Unknown compile target.");
        auto& targetIssues = result["issues"];
        // Complex graphs can create arbitrary output streams, including through
        // FFmpeg's -lavfi alias or its legacy script option. Apply native
        // admission in both modes; portable desktop commands remain permissive.
        const auto complexGraphOption = [](const std::string& option) {
            const auto key = OptionKey(option.rfind("-/",0) == 0 ? "-" + option.substr(2) : option);
            return key == "filter_complex" || key == "filter_complex_script" || key == "lavfi";
        };
        const auto hasComplexGraph = [&](const std::string& text) {
            try {
                auto words = Tokenize(text);
                // FFmpeg's slash form loads the option's argument from a file.
                // Normalize only for admission metadata, never the emitted argv.
                for (auto& word : words) if (word.text.rfind("-/",0) == 0 && complexGraphOption(word.text)) word.text.erase(1,1);
                const auto metadata = TokenMetadata(words,caps);
                for (size_t i = 0; i < words.size(); ++i)
                    if (Bool(metadata[i],"isOption") && complexGraphOption(words[i].text)) return true;
            } catch (const Error&) {} // Existing lint owns malformed command text.
            return false;
        };
        std::string complexGraphField;
        if (advanced) {
            if (std::any_of(tokens.begin(),tokens.end(),[&](const Json& token) { return Str(token,"field") == "command.template" && complexGraphOption(Str(token,"text")); }) &&
                hasComplexGraph(Str(r.at("command"),"template"))) complexGraphField = "command.template";
        } else {
            for (const auto& extra : {std::pair{"video.extra",Str(r.at("video"),"extra")},std::pair{"audio[0].extra",Str(r.at("audio")[0],"extra")}}) {
                // Only inspect fields actually emitted. Existing token metadata
                // distinguishes an option from a quoted literal option-name value.
                if (std::none_of(tokens.begin(),tokens.end(),[&](const Json& token) { return Str(token,"field") == extra.first && complexGraphOption(Str(token,"text")); })) continue;
                if (hasComplexGraph(extra.second)) complexGraphField = extra.first;
                if (!complexGraphField.empty()) break;
            }
        }
        if (!complexGraphField.empty()) targetIssues.push_back(Issue("N-COMPLEX-FILTER","error",complexGraphField,
            "Complex filter graphs are not supported by the VEGAS output. Use simple video or audio filters instead."));
        if (advanced && container && result.at("expectedStreams").is_array()) for (const auto& stream : result.at("expectedStreams")) {
            const auto kind = Str(stream,"kind"); const auto profile = FindProfile(kind,Str(stream,"encoder"));
            const auto support = profile ? ContainerSupport(kind,*profile,Str(*container,"id"),caps) : "";
            if (support == "no" || support == "warn") targetIssues.push_back(Issue("N-CONTAINER-" + kind,support == "no" ? "error" : "warn","command.template",
                support == "no" ? "The output container cannot hold this stream in the measured FFmpeg rule set." : "This output combination depends on FFmpeg version, stream settings or player support.",{{"encoder",Str(stream,"encoder")},{"container",Str(*container,"id")}}));
        }
        if (!container) targetIssues.push_back(Issue("N-CONTAINER","error",advanced ? "command.template" : "container.format",
            "VEGAS requires one explicit MP4, MKV, MOV, WebM or MXF output muxer. Put -f before {output} in Advanced mode."));
        if (!result.at("expectedStreams").is_array() ||
            std::count_if(result.at("expectedStreams").begin(),result.at("expectedStreams").end(),[](const Json& stream) { return Str(stream,"kind") == "video"; }) != 1 ||
            std::any_of(result.at("expectedStreams").begin(),result.at("expectedStreams").end(),[](const Json& stream) { return Str(stream,"encoder").empty() || Str(stream,"encoder") == "copy"; }))
            targetIssues.push_back(Issue("N-STREAMS","error",advanced ? "command.template" : "video.enabled",
                "VEGAS requires one established video output. Use explicit video/audio codec selectors and simple maps; general maps, complex filters and audio-only outputs are not supported."));
        if (advanced) {
            const auto output = std::find_if(tokens.begin(),tokens.end(),[](const Json& token) { return Str(token,"role") == "output"; });
            if (output != tokens.end() && std::next(output) != tokens.end()) targetIssues.push_back(Issue("N-OUTPUT-ORDER","error","command.template","Place all output options before the final {output} macro."));
        }
        if (target.contains("outputPath") && !target.at("outputPath").is_null()) {
            if (!target.at("outputPath").is_string()) throw Error(VE_INVALID_ARGUMENT,"TARGET","Target outputPath must be text or null.");
            auto path = Str(target,"outputPath");
            std::transform(path.begin(),path.end(),path.begin(),[](unsigned char c) { return static_cast<char>(std::tolower(c)); });
            const auto ext = container ? Str(*container,"ext") : std::string();
            if (container && (path.size() < ext.size() || path.compare(path.size()-ext.size(),ext.size(),ext) != 0))
                targetIssues.push_back(Issue("N-OUTPUT-SUFFIX","error","outputPath","Change the Render As filename to end in " + ext + "; Vegas Encoder preserves the exact destination you selected.",{{"extension",ext}}));
        }
    }
    if (effective) *effective = res;
    return result;
}
Json Compile(const Json& request, const Json* capabilities) { return CompileInternal(request,capabilities); }
Json SnapshotSummary(const Json& request) {
    const auto unknown = std::string("Custom / not determined");
    Json result{{"preset","Custom settings"},{"video",unknown},{"resolution",unknown},{"filters",unknown},
                {"audio",unknown},{"container",unknown},{"issues",Json::array()}};
    if (!request.contains("snapshot") || !request.at("snapshot").is_object() || !request.at("snapshot").contains("recipe")) {
        result["issues"].push_back(Issue("P-SNAPSHOT","error","","A complete template snapshot is required.")); return result;
    }
    const auto& snapshot = request.at("snapshot"); const auto& recipe = snapshot.at("recipe");
    const auto shape = Structural(recipe); result["issues"] = shape;
    if (HasErrors(shape)) return result;
    const auto origin = snapshot.value("origin",Json(nullptr));
    if (origin.is_object() && !Str(origin,"name").empty() && Num(origin,"revision") > 0)
        result["preset"] = Str(origin,"name") + " \xC2\xB7 revision " + Number(Num(origin,"revision"));
    const bool knownMedia = request.contains("media") && !request.at("media").is_null();
    // Compile with neutral context solely to reuse its exact effective option
    // reflection. None of these placeholder dimensions/rates escape as facts.
    const Json media = knownMedia ? request.at("media") : Json{{"video",{{"width",2},{"height",2},{"fps",{1,1}},{"pixfmt","p010le"},{"sar","1:1"}}},
        {"audio",{{"rate",48000},{"channels",2},{"sampleFmt","f32le"}}},{"durationSec",nullptr}};
    Json resolved;
    const auto compiled = CompileInternal({{"recipe",recipe},{"media",media},{"paths",{{"ffmpeg","ffmpeg"},{"videoPipe","video"},{"audioPipe","audio"},{"output","output"}}}},nullptr,&resolved);
    // Neutral media is an internal reflection aid, never validation evidence.
    // Validate without media so duration/GOP, padding, aspect and source audio
    // diagnostics cannot be manufactured from that placeholder context.
    result["issues"] = knownMedia ? compiled.at("issues") : Validate({{"recipe",recipe},{"media",nullptr}});
    if (!resolved.is_object()) return result;
    const bool advanced = Str(recipe.at("command"),"mode") == "template";
    const auto join = [](const std::vector<std::string>& values) {
        std::string text; for (const auto& value : values) if (!value.empty()) { if (!text.empty()) text += " \xC2\xB7 "; text += value; } return text;
    };
    bool customVideoRate = false, customAudioRate = false, customVideoFacts = false, customAudioFacts = false, customGeometry = Bool(resolved,"videoFilter");
    for (const auto& token : compiled.at("display")) if (Str(token,"role") == "extra" && IsOption(Str(token,"text"))) {
        const auto key = OptionKey(Str(token,"text"));
        if (key == "s" || key == "aspect" || key == "autoscale") customGeometry = true;
        const auto field = Str(token,"field");
        const auto option = Str(token,"text");
        // The Basic per-stream reflector intentionally has limited scope. A
        // cross-stream Extra option must not turn an inactive control into an
        // effective native-page claim. Keep its codec, but mark these details
        // unknown until the shared reflector can establish that final scope.
        if (field == "audio[0].extra" && (option.find(":v") != std::string::npos ||
            key == "crf" || key == "cq" || key == "qp" || key == "preset" || key == "tune" || key == "profile" || key == "pix_fmt" || key == "g" || key == "vf")) customVideoFacts = true;
        if (field == "video.extra" && (option.find(":a") != std::string::npos || key == "ar" || key == "ac" || key == "sample_fmt" || key == "af")) customAudioFacts = true;
        if (field == "video.extra" && key == "b" && option.find(":a") != std::string::npos) customVideoRate = true;
        if (field == "video.extra" && (key == "rc" || (key == "qp" && Str(resolved,"videoMode") != "cqp") ||
            (key == "crf" && Str(resolved,"videoMode") != "crf") || (key == "cq" && Str(resolved,"videoMode") != "cq") ||
            (key == "b" && Str(resolved,"videoMode") != "abr" && Str(resolved,"videoMode") != "cbr"))) customVideoRate = true;
        if (field == "audio[0].extra" && (key == "q" || key == "vbr") && Str(resolved,"audioMode") == "bitrate") customAudioRate = true;
    }
    const auto& summary = compiled.at("summary");
    const auto videoEncoder = Str(summary,"videoEncoderId");
    if (!Bool(resolved,"videoEnabled",Bool(recipe.at("video"),"enabled",true))) result["video"] = "No video";
    else if (!videoEncoder.empty()) result["video"] = join({advanced ? "Advanced command" : "",videoEncoder,customVideoFacts ? "" : Str(resolved,"profile"),
        advanced || customVideoRate || customVideoFacts ? unknown : Str(summary,"videoQuality"),customVideoFacts ? "" : Str(resolved,"speed")});
    else if (advanced) result["video"] = "Advanced command \xC2\xB7 " + unknown;
    if (!advanced && !customGeometry) {
        result["resolution"] = knownMedia ? Number(Num(media.at("video"),"width")) + " \xC3\x97 " + Number(Num(media.at("video"),"height")) + " (from VEGAS)" : "Same as input from VEGAS";
        result["filters"] = "None";
    } else result["filters"] = advanced ? "Advanced command" : "Filters set in Extra arguments";
    if (const auto resize = ActiveResize(recipe)) {
        const auto size = Number(Num(*resize,"width")) + " \xC3\x97 " + Number(Num(*resize,"height"));
        result["resolution"] = knownMedia ? Number(Num(media.at("video"),"width")) + " \xC3\x97 " + Number(Num(media.at("video"),"height")) + " \xE2\x86\x92 " + size : size + " (fit with padding; input set by VEGAS)";
        result["filters"] = "Resize to " + size + " \xC2\xB7 " + AlgorithmLabel(Str(*resize,"algorithm"));
    }
    if (!Bool(resolved,"audioEnabled",Bool(recipe.at("audio")[0],"enabled",true))) result["audio"] = "No audio";
    else {
        const auto encoder = Str(summary,"audioEncoderId");
        if (!encoder.empty()) {
            const auto& audio = recipe.at("audio")[0];
            const auto channels = resolved.contains("audioChannels") ? Num(resolved,"audioChannels") :
                !advanced && Str(audio,"channels","source") == "mono" ? 1 : !advanced && Str(audio,"channels","source") == "stereo" ? 2 :
                knownMedia && media.contains("audio") && !media.at("audio").is_null() ? Num(media.at("audio"),"channels") : 0;
            result["audio"] = join({encoder,advanced || customAudioRate || customAudioFacts ? unknown : Str(summary,"audioQuality"),
                customAudioFacts ? "" : channels == 1 ? "Mono" : channels == 2 ? "Stereo" : channels > 0 ? Number(channels) + " channels" : "Channels set by VEGAS"});
        }
    }
    if (!compiled.at("outputContainerId").is_null()) result["container"] = Str(summary,"container") + " (" + Str(compiled,"outputExtension") + ")";
    return result;
}
Json ErrorTokenIndices(const Json& compiled, const std::string& stderrTail) {
    Json result = Json::array();
    if (!compiled.contains("argv")) return result;
    const auto& argv = compiled.at("argv");
    for (const auto* prefix : {"Unrecognized option '","Error setting option ","Error applying option '"}) {
        size_t offset = 0;
        while ((offset = stderrTail.find(prefix,offset)) != std::string::npos) {
            offset += strlen(prefix); const auto end = stderrTail.find_first_of("' \r\n",offset);
            const auto name = stderrTail.substr(offset,end == std::string::npos ? end : end-offset);
            if (name.empty() || name.size() > 256) continue;
            for (size_t i = 0; i < argv.size(); ++i) {
                const auto text = argv[i].get<std::string>();
                if (text == "-" + name || text == name) {
                    if (std::find(result.begin(),result.end(),Json(i)) == result.end()) result.push_back(i);
                }
            }
        }
    }
    return result;
}
} // namespace ve
