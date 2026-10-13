#include "core.h"
#include <algorithm>
#include <cmath>
#include <functional>
#include <limits>
#include <regex>
#include <set>

namespace ve {
namespace {
bool TypeMatches(const Json& value, const std::string& type) {
    if (type == "object") return value.is_object();
    if (type == "array") return value.is_array();
    if (type == "string") return value.is_string();
    if (type == "integer") return value.is_number_integer();
    if (type == "number") return value.is_number();
    if (type == "boolean") return value.is_boolean();
    return type == "null" && value.is_null();
}
void SchemaCheck(const Json& value, const Json& schema, const std::string& path, Json& issues) {
    auto fail = [&](const std::string& message) { issues.push_back(Issue("V-SHAPE","error",path,message)); };
    if (schema.contains("$ref")) {
        const auto ref = Str(schema,"$ref").substr(1);
        SchemaCheck(value,RecipeSchema().at(Json::json_pointer(ref)),path,issues); return;
    }
    if (schema.contains("oneOf")) {
        size_t matched = 0;
        for (const auto& branch : schema.at("oneOf")) { Json local = Json::array(); SchemaCheck(value,branch,path,local); if (local.empty()) ++matched; }
        if (matched != 1) fail("Value does not match the recipe schema.");
    }
    if (schema.contains("type")) {
        const auto types = schema.at("type").is_array() ? schema.at("type") : Json::array({schema.at("type")});
        bool matched = false;
        for (const auto& type : types) matched |= TypeMatches(value,type.get<std::string>());
        if (!matched) { fail("Wrong value type for this recipe field."); return; }
    }
    if (schema.contains("const") && value != schema.at("const")) fail("Unsupported recipe value or schema version.");
    if (schema.contains("enum") && std::find(schema.at("enum").begin(),schema.at("enum").end(),value) == schema.at("enum").end()) fail("Unsupported value for this recipe field.");
    if (value.is_object()) {
        if (schema.contains("required")) for (const auto& key : schema.at("required")) {
            const auto name = key.get<std::string>();
            if (!value.contains(name)) issues.push_back(Issue("V-SHAPE","error",path.empty() ? name : path + "." + name,"Required recipe field is missing."));
        }
        if (schema.contains("properties")) for (const auto& item : schema.at("properties").items()) {
            if (value.contains(item.key())) SchemaCheck(value.at(item.key()),item.value(),path.empty() ? item.key() : path + "." + item.key(),issues);
        }
    }
    if (value.is_array()) {
        const auto count = static_cast<double>(value.size());
        if (count < Num(schema,"minItems",0) || count > Num(schema,"maxItems",std::numeric_limits<double>::max())) fail("Wrong number of recipe entries.");
        if (schema.contains("items")) for (size_t i = 0; i < value.size(); ++i) SchemaCheck(value.at(i),schema.at("items"),path + "[" + std::to_string(i) + "]",issues);
    }
    if (value.is_string()) {
        const auto text = value.get<std::string>();
        size_t count = 0; for (const auto c : text) if ((static_cast<unsigned char>(c) & 0xc0) != 0x80) ++count;
        if (static_cast<double>(count) < Num(schema,"minLength",0) || static_cast<double>(count) > Num(schema,"maxLength",std::numeric_limits<double>::max())) fail("Text is outside the recipe field's length bounds.");
        if (schema.contains("pattern") && !std::regex_match(text,std::regex(Str(schema,"pattern")))) fail("Preset ID must use letters, digits, dots, underscores or hyphens, starting with a letter or digit.");
    }
    if (value.is_number()) {
        const auto number = value.get<double>();
        if (!std::isfinite(number) || number < Num(schema,"minimum",-std::numeric_limits<double>::max()) ||
            number <= Num(schema,"exclusiveMinimum",-std::numeric_limits<double>::max())) fail("Number is outside the recipe field's bounds.");
    }
}
Json EmptyProfile(const std::string& encoder, bool video) {
    return Json{{"id",encoder},{"label",encoder},{"codec",encoder},{"family","unknown"},{"hw",nullptr},
                {"modes",video ? Json::array({"abr","cbr"}) : Json::array({"bitrate"})},
                {"depthDef",10},{"depths",{{"8","yuv420p"},{"10","p010le"}}},
                {"bitrate",{{"def",video ? 12000 : 320}}}};
}
Json DefaultValue(const Json& settings, const std::string& key, const Json& control, const std::string& controlKey = "def") {
    if (settings.contains(key) && !settings.at(key).is_null()) return settings.at(key);
    return control.is_object() && control.contains(controlKey) ? control.at(controlKey) : Json(nullptr);
}
bool Includes(const Json& array, const Json& value) {
    return array.is_array() && std::find(array.begin(),array.end(),value) != array.end();
}
std::string Support(const std::string& kind, const Json& profile, const std::string& container) {
    const auto& table = Profiles().at("compatibility").at(kind);
    const auto family = Str(profile,"family");
    return table.contains(family) ? Str(table.at(family),container,"unknown") : "unknown";
}
}
Json Structural(const Json& recipe) {
    Json issues = Json::array(); SchemaCheck(recipe,RecipeSchema(),"",issues);
    if (recipe.is_object() && recipe.contains("schema") && !recipe.at("schema").is_number_integer()) issues.push_back(Issue("V-SCHEMA","error","schema","Recipe schema must be integer 1."));
    return issues;
}
Json Normalize(const Json& request) {
    const auto& recipe = request.at("recipe");
    if (!recipe.is_object()) throw Error(VE_INVALID_ARGUMENT,"RECIPE-OBJECT","Expected a recipe object.");
    return Json{{"recipe",recipe},{"issues",Structural(recipe)}}; // Defaults are resolved at compile time only.
}
Json Resolve(const Json& recipe) {
    const auto& video = recipe.at("video"); const auto& audio = recipe.at("audio").at(0);
    const auto vp = FindProfile("video",Str(video,"encoder")); const auto ap = FindProfile("audio",Str(audio,"encoder"));
    const Json v = vp ? *vp : EmptyProfile(Str(video,"encoder"),true);
    const Json a = ap ? *ap : EmptyProfile(Str(audio,"encoder"),false);
    const auto mode = Str(video,"mode",v.at("modes").at(0).get<std::string>());
    const auto amode = Str(audio,"mode",a.at("modes").at(0).get<std::string>());
    const double requestedDepth = Num(video,"depth",Num(v,"depthDef",10));
    const auto depth = static_cast<int>(requestedDepth >= 1 && requestedDepth <= 64 ? requestedDepth : Num(v,"depthDef",10));
    const auto& depths = v.at("depths");
    const auto depthKey = std::to_string(depth);
    std::string pixfmt = Str(depths,depthKey,Str(depths,std::to_string(static_cast<int>(Num(v,"depthDef",10)))));
    const Json profileControl = v.contains("profileQuality") ? v.at("profileQuality") : v.value("profile",Json::object());
    const Json profile = DefaultValue(video,"profile",profileControl);
    if (profile.is_string() && profileControl.is_object() && profileControl.contains("pixfmt")) pixfmt = Str(profileControl.at("pixfmt"),profile.get<std::string>(),pixfmt);
    if (Str(v,"id") == "prores_ks" && profile.is_string() && profile.get<std::string>().rfind("4444",0) == 0) pixfmt = "yuv444p10le";
    const int actualDepth = pixfmt.find("10") != std::string::npos || pixfmt == "p010le" ? 10 : pixfmt.find("12") != std::string::npos ? 12 : depth;
    return Json{{"videoEncoder",Str(video,"encoder")},{"audioEncoder",Bool(audio,"enabled",true) ? Json(Str(audio,"encoder")) : Json(nullptr)},
                {"videoMode",mode},{"audioMode",Bool(audio,"enabled",true) ? Json(amode) : Json(nullptr)},
                {"quality",DefaultValue(video,"quality",v.value("quality",Json::object()))},
                {"speed",DefaultValue(video,"speed",v.value("speed",Json::object()))},
                {"tune",DefaultValue(video,"tune",v.value("tune",Json::object()))},
                {"profile",profile},{"depth",actualDepth},{"pixfmt",pixfmt},
                {"videoProfile",v},{"audioProfile",a}};
}
void CheckMedia(const Json& media) {
    if (!media.is_object() || !media.contains("video") || !media.at("video").is_object()) throw Error(VE_INVALID_ARGUMENT,"MEDIA","Expected delivered video facts.");
    const auto& v = media.at("video");
    if (!v.contains("width") || !v.at("width").is_number_integer() || !v.contains("height") || !v.at("height").is_number_integer() ||
        Num(v,"width") <= 0 || Num(v,"height") <= 0 || Num(v,"width") > 65536 || Num(v,"height") > 65536 ||
        !v.contains("fps") || !v.at("fps").is_array() || v.at("fps").size() != 2 ||
        !v.at("fps")[0].is_number_integer() || !v.at("fps")[1].is_number_integer() ||
        v.at("fps")[0].get<double>() <= 0 || v.at("fps")[1].get<double>() <= 0 || Str(v,"pixfmt","p010le").empty() ||
        (v.contains("pixfmt") && !v.at("pixfmt").is_string()) || (v.contains("sar") && !v.at("sar").is_string()))
        throw Error(VE_INVALID_ARGUMENT,"MEDIA","Invalid dimensions or rational frame rate.");
    if (media.contains("audio") && !media.at("audio").is_null()) {
        const auto& a = media.at("audio");
        if (!a.is_object() || !a.contains("rate") || !a.at("rate").is_number_integer() || !a.contains("channels") || !a.at("channels").is_number_integer() ||
            Num(a,"rate") <= 0 || Num(a,"rate") > 768000 || Num(a,"channels") <= 0 || Num(a,"channels") > 64 ||
            (a.contains("sampleFmt") && !a.at("sampleFmt").is_string()))
            throw Error(VE_INVALID_ARGUMENT,"MEDIA","Invalid delivered audio facts.");
    }
}
Json Validate(const Json& request) {
    const auto& r = request.at("recipe"); Json issues = Structural(r);
    if (HasErrors(issues)) return issues;
    const auto& v = r.at("video"); const auto& a = r.at("audio")[0]; const auto& c = r.at("container");
    const auto media = request.value("media",Json(nullptr)); const auto caps = request.value("capabilities",Json(nullptr));
    if (!media.is_null()) CheckMedia(media);
    const bool withVideo = Bool(v,"enabled",true), withAudio = Bool(a,"enabled",true);
    if (!withVideo && !withAudio) issues.push_back(Issue("V-STREAMS","error","video.enabled","Turn on video, audio, or both."));
    else if (!withVideo) issues.push_back(Issue("V-AUDIO-ONLY","error","video.enabled","Audio-only renders are not supported by the VEGAS adapter yet."));
    if (Str(r.at("command"),"mode") == "template") {
        for (const auto& d : Lint(Json{{"text",Str(r.at("command"),"template")},{"capabilities",caps}})) {
            Json params = d.at("params"); params["start"] = d.at("start"); params["end"] = d.at("end");
            issues.push_back(Issue(Str(d,"id"),Str(d,"level"),"command.template",Str(d,"message"),params));
        }
        issues.push_back(Issue("V-UNTESTED","info","","Not tested with VEGAS yet.")); return issues;
    }
    const Json res = Resolve(r);
    auto stream = [&](const Json& settings, const Json& profile, const std::string& kind, const std::string& field) {
        const auto encoder = Str(settings,"encoder");
        if (!FindProfile(kind,encoder)) issues.push_back(Issue("V-UNCURATED","warn",field + ".encoder","Using generic bitrate controls for an uncurated encoder.",{{"encoder",encoder}}));
        if (!caps.is_null()) {
            if (!caps.is_object() || !caps.contains("encoders") || !caps.at("encoders").is_object()) throw Error(VE_INVALID_ARGUMENT,"CAPABILITIES","Expected an encoder capability map.");
            const auto& encoders = caps.at("encoders");
            if (!encoders.contains(encoder)) issues.push_back(Issue("V-ENC-MISSING","error",field + ".encoder",encoder + " is not in the selected FFmpeg.",{{"encoder",encoder}}));
            else {
                const auto& enc = encoders.at(encoder);
                const Json availability = enc.value("availability",Json::object()); const auto state = Str(availability,"state","unknown");
                if (state == "missing" || state == "failed") issues.push_back(Issue(state == "failed" ? "V-ENC-FAILED" : "V-ENC-MISSING","error",field + ".encoder",encoder + (state == "failed" ? " failed its test encode on this PC. " : " is unavailable. ") + Str(availability,"reason"),{{"encoder",encoder}}));
                else if (state != "ok") issues.push_back(Issue("V-ENC-UNKNOWN","warn",field + ".encoder","This encoder has not been tested on this PC.",{{"encoder",encoder}}));
            }
        }
        const std::string mode = Str(settings,"mode",profile.at("modes")[0].get<std::string>());
        if (!Includes(profile.at("modes"),mode)) issues.push_back(Issue("V-MODE","error",field + ".mode","This encoder does not support the selected rate-control mode."));
        for (const auto& name : {"quality","qp","vbr","level"}) {
            const bool active = (std::string(name) == "quality" && (mode == "crf" || mode == "cq")) ||
                (std::string(name) == "qp" && mode == "cqp") || (std::string(name) == "vbr" && mode == "vbr") || std::string(name) == "level";
            if (active && settings.contains(name) && !settings.at(name).is_null() && profile.contains(name) && profile.at(name).is_object()) {
                const auto value = Num(settings,name); const auto& control = profile.at(name);
                if (value < Num(control,"min",-1e30) || value > Num(control,"max",1e30)) issues.push_back(Issue("V-VALUE","error",field + "." + name,"Value is outside this encoder's supported range."));
            }
        }
        for (const auto& name : {"speed","tune","profile","multipass"}) {
            if (settings.contains(name) && !settings.at(name).is_null()) {
                const Json control = std::string(name) == "profile" && profile.contains("profileQuality") ? profile.at("profileQuality") : profile.value(name,Json::object());
                if (control.is_object() && control.contains("values") && !Includes(control.at("values"),settings.at(name))) issues.push_back(Issue("V-VALUE","error",field + "." + name,"Value is not one of this encoder's supported choices."));
            }
        }
        const auto support = Support(kind,profile,Str(c,"format"));
        if (support == "no" || support == "warn") issues.push_back(Issue(kind == "video" ? "V-CONTAINER-VIDEO" : "V-CONTAINER-AUDIO",support == "no" ? "error" : "warn","container.format",
            support == "no" ? "The container cannot hold this stream." : "This stream muxes, but some players cannot open it.",{{"stream",field},{"support",support},{"encoder",encoder},{"container",Str(c,"format")}}));
        const auto extra = Str(settings,"extra");
        if (!extra.empty()) {
            for (const auto& d : Lint(Json{{"text",extra},{"capabilities",caps},{"extra",true},{"encoder",encoder},{"kind",kind}})) {
                Json params = d.at("params"); params["start"] = d.at("start"); params["end"] = d.at("end");
                issues.push_back(Issue(Str(d,"id"),Str(d,"level"),field + ".extra",Str(d,"message"),params));
            }
        }
    };
    if (!FindContainer(Str(c,"format"))) issues.push_back(Issue("V-CONTAINER","error","container.format","Choose a supported container."));
    if (withVideo) {
        stream(v,res.at("videoProfile"),"video","video");
        const auto& p = res.at("videoProfile");
        if (v.contains("depth") && !v.at("depth").is_null() && (Num(v,"depth") > 64 || !p.at("depths").contains(v.at("depth").dump()))) issues.push_back(Issue("V-DEPTH","error","video.depth","This encoder does not support the selected bit depth."));
        if (Num(v,"gopSec") > 0 && !media.is_null()) {
            const auto& fps = media.at("video").at("fps");
            const double frames = std::round(Num(v,"gopSec") * fps[0].get<double>() / fps[1].get<double>());
            if (!(frames >= 1 && frames <= 2147483647)) issues.push_back(Issue("V-GOP-BOUNDS","error","video.gopSec","Keyframe interval must resolve to 1…2147483647 frames."));
        }
        if (Str(v,"color","bt709") != "bt709" && Str(v,"color") != "none") issues.push_back(Issue("V-COLOR","error","video.color","Use BT.709 tags or no tags; other color policies need Advanced mode."));
        if (Num(v,"gopSec") > 10) issues.push_back(Issue("V-GOP","warn","video.gopSec","Keyframes more than 10 seconds apart make seeking slow."));
        if (Str(v,"encoder") == "libx264" && Num(res,"depth") == 10) issues.push_back(Issue("V-H264-10BIT","warn","video.depth","10-bit H.264 does not play on most phones, browsers or TVs."));
    }
    if (withAudio) {
        stream(a,res.at("audioProfile"),"audio","audio[0]");
        if (!media.is_null() && (!media.contains("audio") || media.at("audio").is_null())) issues.push_back(Issue("V-AUDIO-INPUT","error","audio[0].enabled","This source has no audio stream; turn audio off."));
        else {
            const auto rate = a.contains("sampleRate") && a.at("sampleRate").is_number() ? a.at("sampleRate") : !media.is_null() ? media.at("audio").at("rate") : Json(nullptr);
            const auto& profile = res.at("audioProfile");
            if (!rate.is_null() && profile.contains("rates") && !Includes(profile.at("rates"),rate)) issues.push_back(Issue("V-RATE","error","audio[0].sampleRate","This encoder does not support the selected audio sample rate.",{{"rate",rate}}));
        }
    }
    if (Str(c,"format") == "mp4" && Bool(c,"faststart")) issues.push_back(Issue("V-FASTSTART","info","container.faststart","Fast start rewrites the file after encoding so playback can begin before download finishes."));
    if (caps.is_null()) issues.push_back(Issue("V-CAPABILITIES-UNKNOWN","info","","Preview uses curated profile data; select and probe FFmpeg to check this installation."));
    issues.push_back(Issue("V-UNTESTED","info","","Not tested with VEGAS yet."));
    return issues;
}
Json Diff(const Json& request) {
    Json result = Json::array();
    const std::set<std::string> metadata{"id","name","notes","tags","category","revision","updated","builtin","favorite"};
    std::function<void(const Json&,const Json&,const std::string&)> walk;
    walk = [&](const Json& before, const Json& after, const std::string& path) {
        if (before.is_object() && after.is_object()) {
            std::set<std::string> keys; for (const auto& i : before.items()) keys.insert(i.key()); for (const auto& i : after.items()) keys.insert(i.key());
            for (const auto& key : keys) {
                if (path.empty() && metadata.count(key)) continue;
                const auto next = path.empty() ? key : path + "." + key;
                if (before.contains(key) && after.contains(key)) walk(before.at(key),after.at(key),next);
                else result.push_back(Json{{"path",next},{"before",before.value(key,Json(nullptr))},{"after",after.value(key,Json(nullptr))}});
            }
        } else if (before.is_array() && after.is_array() && path == "audio" && before.size() == after.size()) {
            for (size_t i = 0; i < before.size(); ++i) walk(before[i],after[i],path + "[" + std::to_string(i) + "]");
        } else if (before != after) result.push_back(Json{{"path",path},{"before",before},{"after",after}});
    };
    walk(request.at("before"),request.at("after"),""); return result;
}
} // namespace ve
