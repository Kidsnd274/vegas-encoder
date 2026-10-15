#include "core.h"
#include <algorithm>
#include <cmath>
#include <limits>
#include <map>
#include <regex>
#include <sstream>

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
    for (size_t i = 0; i + 1 < tokens.size(); ++i) {
        const auto key = OptionKey(Str(tokens[i],"text")); const auto value = Str(tokens[i+1],"text");
        if (!IsOption(Str(tokens[i],"text")) || (tokens[i].contains("isOption") && !Bool(tokens[i],"isOption"))) continue;
        const std::string prefix = video ? "video" : "audio";
        if (video) ReflectVideoFormatOption(resolved,key,value);
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
        if (key == "vf" || key == "filter_complex") resolved["videoFilter"] = true;
        if (key == "af" || key == "filter_complex") resolved["audioFilter"] = true;
    }
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
            for (const auto& c : Profiles().at("containers")) if (Str(c,"muxer") == muxer) res["container"] = Str(c,"id");
        }
        (kind == "video" ? video : audio).push_back(tokens[i]);
    }
    ReadStream(video,res,true); ReadStream(audio,res,false);
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
        fps[0].dump() + "/" + fps[1].dump(),a.is_null() ? "" : Number(Num(a,"rate")),Str(paths,"project"),
        frames >= 1 && frames <= 2147483647 ? Json(Number(frames)) : Json(nullptr)};
    auto result = MacroDefinitions();
    for (size_t i = 0; i < result.size(); ++i) result[i]["value"] = values[i];
    return result;
}
Json Compile(const Json& request, const Json* capabilities) {
    const auto& r = request.at("recipe"); const auto& media = request.at("media"); const auto& paths = request.at("paths");
    CheckMedia(media);
    if (!paths.is_object() || Str(paths,"ffmpeg","ffmpeg").empty() || Str(paths,"videoPipe").empty() || Str(paths,"output").empty()) throw Error(VE_INVALID_ARGUMENT,"PATHS","Executable, video pipe and output path must be nonempty strings.");
    Json issues = Validate(request,capabilities); const auto exe = Str(paths,"ffmpeg","ffmpeg");
    Json result{{"executable",exe},{"argv",Json::array()},{"display",Json::array()},{"commandLine",""},{"advancedTemplate",""},{"resolved",nullptr},{"signalPath",nullptr},{"issues",issues},{"summary",Json::object()},{"overriddenFields",Json::array()},{"expectedStreams",nullptr}};
    if (HasErrors(Structural(r))) return result;
    const bool audioInput = Bool(r.at("audio")[0],"enabled",true) && media.contains("audio") && !media.at("audio").is_null();
    result["inputStreams"] = audioInput ? Json::array({"video","audio"}) : Json::array({"video"});
    if (audioInput && Str(paths,"audioPipe").empty()) throw Error(VE_INVALID_ARGUMENT,"PATHS","Enabled audio needs a pipe path.");
    bool partialCommand = false;
    Json tokens = Json::array(); Push(tokens,"exe",nullptr,{exe});
    Push(tokens,"global",nullptr,{"-hide_banner","-nostdin","-loglevel","info","-stats_period","0.5","-progress","pipe:1"});
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
            seed += Quote(Str(token,"text")); lastRole = role;
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
        if (extraInputs || extraOutputs) {
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
            if (!IsOption(Str(tokens[i],"text")) || (tokens[i].contains("isOption") && !Bool(tokens[i],"isOption"))) continue;
            const auto key = OptionKey(Str(tokens[i],"text"));
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
            expected.push_back({{"kind",kind},{"encoder",encoder.empty() ? Json(nullptr) : Json(encoder)},{"codec",codec.empty() ? Json(nullptr) : Json(codec)}});
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
