#include "core.h"
#include <algorithm>
#include <cctype>
#include <cmath>
#include <map>
#include <set>

namespace ve {
namespace {
const std::map<std::string,std::string> generic{
    {"c","Codec for a stream"},{"b","Bitrate"},{"maxrate","Maximum bitrate"},{"minrate","Minimum bitrate"},
    {"bufsize","Rate-control buffer size"},{"g","Keyframe interval in frames"},{"bf","Maximum B-frames"},
    {"refs","Reference frames"},{"pix_fmt","Output pixel format"},{"profile","Codec profile"},{"level","Codec level"},
    {"r","Output frame rate"},{"s","Output frame size"},{"vf","Video filter graph"},{"af","Audio filter graph"},
    {"filter_complex","Complex filter graph"},{"ar","Audio sample rate"},{"ac","Audio channels"},{"map","Select output stream"},
    {"metadata","Metadata"},{"movflags","MP4/MOV muxer flags"},{"tag","Codec tag"},{"color_primaries","Color primaries tag"},
    {"color_trc","Transfer characteristic tag"},{"colorspace","Matrix coefficients tag"},{"color_range","Color range tag"},
    {"threads","Encoder threads"},{"f","Container format"},{"t","Stop after duration"},{"shortest","Stop with shortest stream"},
    {"q","Quality scale"},{"compression_level","Compression level"},{"vn","No video"},{"an","No audio"},
    {"map_metadata","Copy metadata"},{"fps_mode","Frame timing mode"},{"strict","Allow experimental features"},
    {"hide_banner","Hide the banner"},{"loglevel","Log level"},{"stats","Print progress"},{"progress","Machine-readable progress"},
    {"stats_period","Progress update period"},{"nostdin","Ignore console input"},{"y","Overwrite output"},{"n","Do not overwrite"},
    {"x264-params","x264 parameter string"},{"x265-params","x265 parameter string"},{"svtav1-params","SVT-AV1 parameter string"},
    {"aspect","Display aspect ratio"},{"sample_fmt","Audio sample format"},{"channel_layout","Audio channel layout"},
    {"disposition","Stream disposition"},{"max_muxing_queue_size","Muxer queue size"},{"write_tmcd","Write timecode"},
    {"timecode","Start timecode"},{"vtag","Video codec tag"},{"atag","Audio codec tag"},{"crf","Constant rate factor"},
    {"qp","Quantizer"},{"i","Input file"},{"filter","Filter graph"},{"flags","Codec flags"},{"flags2","Additional codec flags"},
    {"nostats","Hide periodic statistics"},{"to","Stop at position"},{"frames","Stop after a number of frames"},
    {"vframes","Stop after a number of video frames"},{"aframes","Stop after a number of audio frames"},{"fs","Stop at file size"},
    {"attach","Attach a file"},{"dump_attachment","Extract an attachment to a file"},{"filter_script","Filter graph read from a file"},
    {"filter_complex_script","Complex filter graph read from a file"}};
const std::string shorterMessage = "This option can stop the render before the end of the VEGAS timeline. The output will be shorter.";
// URL or protocol arguments, including tee targets ("[f=flv]rtmp://...|udp:...").
bool Network(const std::string& text) {
    std::string lower = text;
    std::transform(lower.begin(),lower.end(),lower.begin(),[](unsigned char c) { return static_cast<char>(std::tolower(c)); });
    if (lower.find("://") != std::string::npos) return true;
    for (const auto* protocol : {"http:","https:","ftp:","ftps:","sftp:","tcp:","udp:","rtp:","rtsp:","rtmp:","rtmps:","rtmpt:","srt:","rist:","tls:","mms:","mmsh:","ipfs:","ipns:","icecast:","gopher:"})
        for (auto at = lower.find(protocol); at != std::string::npos; at = lower.find(protocol,at + 1))
            if (at == 0 || lower[at-1] == '|' || lower[at-1] == ']' || lower[at-1] == '=') return true;
    return false;
}
// Filters whose arguments name files: movie, amovie, subtitles, ass, drawtext textfile.
bool FileFilter(const std::string& graph) {
    for (size_t start = 0; start <= graph.size();) {
        auto end = graph.find_first_of(",;",start); if (end == std::string::npos) end = graph.size();
        auto part = graph.substr(start,end - start);
        while (!part.empty() && (part.front() == ' ' || part.front() == '[')) {
            if (part.front() == ' ') { part.erase(0,1); continue; }
            const auto close = part.find(']'); if (close == std::string::npos) break; part.erase(0,close + 1);
        }
        const auto name = part.substr(0,part.find('='));
        if (name == "movie" || name == "amovie" || name == "subtitles" || name == "ass" || (name == "drawtext" && part.find("textfile=") != std::string::npos)) return true;
        start = end + 1;
    }
    return false;
}
bool GenericValue(const std::string& key, const std::string& value) {
    if (key == "g" || key == "ar" || key == "ac" || key == "bf" || key == "refs" || key == "threads") {
        try { size_t used = 0; const auto n = std::stoll(value,&used); return used == value.size() && n >= ((key == "g" || key == "ar" || key == "ac") ? 1 : 0) && n <= 2147483647; }
        catch (const std::exception&) { return false; }
    }
    if (key == "b" || key == "maxrate" || key == "minrate" || key == "bufsize") {
        try { size_t used = 0; const auto n = std::stod(value,&used); const auto suffix = value.substr(used); return std::isfinite(n) && n >= 0 && (suffix.empty() || suffix == "k" || suffix == "K" || suffix == "m" || suffix == "M" || suffix == "g" || suffix == "G"); }
        catch (const std::exception&) { return false; }
    }
    return true;
}
std::string Kind(const std::string& option) {
    if (option.find(":a") != std::string::npos || option == "-acodec") return "audio";
    if (option.find(":v") != std::string::npos || option == "-vcodec") return "video";
    return "";
}
const Json* PrivateOption(const Json& caps, const std::string& encoder, const std::string& key) {
    const auto data = EncoderOptions(caps,encoder);
    if (!data || !data->contains("options") || !data->at("options").is_array()) return nullptr;
    for (const auto& option : data->at("options")) {
        if (Str(option,"name") == key) return &option;
        const auto aliases = option.value("aliases",Json::array());
        for (const auto& alias : aliases) if (alias == key) return &option;
    }
    return nullptr;
}
const Json* Choice(const std::string& encoder, const std::string& kind, const std::string& key) {
    const auto p = FindProfile(kind,encoder); if (!p) return nullptr;
    for (const auto& name : {"speed","tune","profile","profileQuality","multipass"}) {
        const auto i = p->find(name);
        if (i != p->end() && i->is_object() && i->contains("flag") && OptionKey(Str(*i,"flag")) == key) return &*i;
    }
    return nullptr;
}
bool AllowedChoice(const Json& choices, const std::string& value) {
    if (!choices.contains("values")) return true;
    for (const auto& item : choices.at("values")) if (item == value) return true;
    return false;
}
bool PrivateValue(const Json& option, const std::string& value) {
    const auto type = Str(option,"type"); const auto constants = option.value("constants",Json::array());
    if ((type == "string" || type == "dictionary" || type == "flags") || value == "auto") return true;
    for (const auto& constant : constants) if (Str(constant,"name") == value || Str(constant,"value") == value) return true;
    try {
        size_t end = 0; const double numeric = std::stod(value,&end);
        if (end != value.size() || !std::isfinite(numeric)) return type == "pixel_fmt" || type == "sample_fmt";
        auto bound = [](const std::string& text, double fallback) { try { size_t end = 0; const double n = std::stod(text,&end); return end == text.size() ? n : fallback; } catch (const std::exception&) { return fallback; } };
        return numeric >= bound(Str(option,"min"),-1e300) && numeric <= bound(Str(option,"max"),1e300);
    } catch (const std::exception&) { return constants.empty() && type != "int" && type != "int64" && type != "float" && type != "double" && type != "boolean"; }
}
Json Diagnostic(const std::string& id, const std::string& level, const std::vector<size_t>& offsets, size_t start, size_t end, const std::string& message, Json params = Json::object()) {
    return Json{{"id",id},{"level",level},{"start",offsets[start]},{"end",offsets[end]},{"message",message},{"params",params},{"fix",nullptr}};
}
Json Suggestion(const std::string& value, const std::string& description, const Json& type = nullptr, const Json& def = nullptr, const Json& source = nullptr, const Json& availability = nullptr) {
    return Json{{"value",value},{"description",description},{"type",type},{"defaultValue",def},{"source",source},{"availability",availability}};
}
std::map<std::string,std::string> Encoders(const std::vector<Word>& words) {
    std::map<std::string,std::string> encoders;
    for (const auto& pair : PairOptions(words)) {
        if (pair.key != "c" || !pair.HasValue()) continue;
        const auto kind = Kind(pair.name); const auto& encoder = words[pair.value].text;
        if (!kind.empty()) encoders[kind] = encoder;
        else { encoders["video"] = encoder; encoders["audio"] = encoder; }
    }
    return encoders;
}
}
bool ValidEncoderOption(const Json& caps, const std::string& encoder, const std::string& kind,
                        const std::string& flag, const std::string& value) {
    const auto key = OptionKey(flag);
    const auto option = PrivateOption(caps,encoder,key);
    const auto choice = Choice(encoder,kind,key);
    return (!choice || AllowedChoice(*choice,value)) && (!option || PrivateValue(*option,value)) && GenericValue(key,value);
}
Json TokenMetadata(const std::vector<Word>& words, const Json& caps) {
    const auto encoders = Encoders(words);
    const std::set<std::string> video{"crf","qp","cq","g","bf","refs","pix_fmt","vf","r","s","aspect","vtag","color_primaries","color_trc","colorspace","color_range","vn"};
    const std::set<std::string> audio{"ar","ac","af","sample_fmt","channel_layout","atag","an"};
    const std::set<std::string> global{"hide_banner","nostdin","nostats","loglevel","stats","progress","stats_period","y","n"};
    const std::set<std::string> mux{"f","movflags","max_muxing_queue_size","shortest"};
    // Reverse scope pass keeps metadata linear at the 16384-word limit.
    std::vector<bool> inputScope(words.size()); bool beforeInput = false;
    for (size_t next = words.size(); next > 0;) {
        --next;
        if (words[next].text == "{output}") beforeInput = false;
        if (words[next].text == "{inputs}" || (words[next].text == "-i" && !words[next].quoted)) beforeInput = true;
        inputScope[next] = beforeInput;
    }
    Json result = Json::array();
    std::string valueStage; bool value = false;
    for (size_t index = 0; index < words.size(); ++index) {
        const auto& word = words[index];
        const auto key = OptionKey(word.text);
        const bool option = !value && IsOption(word.text);
        std::string stage;
        if (value) { stage = valueStage; value = false; }
        else if (word.text == "{inputs}") stage = "input";
        else if (word.text == "{output}") stage = "output";
        else if (option) {
            stage = Kind(word.text);
            if (stage.empty()) {
                if (global.count(key)) stage = "global";
                else if (video.count(key)) stage = "video";
                else if (audio.count(key)) stage = "audio";
                else if (mux.count(key)) stage = "mux";
                else if (key == "map") stage = "map";
                else if (key == "i") stage = "input";
                else {
                    for (const auto& [kind,encoder] : encoders) if (PrivateOption(caps,encoder,key) || Choice(encoder,kind,key)) {
                        if (!stage.empty() && stage != kind) { stage.clear(); break; }
                        stage = kind;
                    }
                }
            }
            if (stage != "global" && inputScope[index]) stage = "input";
            value = !IsSwitch(key) && index + 1 < words.size() &&
                (!IsOption(words[index+1].text) || words[index+1].quoted) && words[index+1].text != "{inputs}" && words[index+1].text != "{output}";
            valueStage = stage;
        }
        Json macros = Json::array();
        for (size_t i = 0; (i = word.text.find('{',i)) != std::string::npos;) {
            const auto end = word.text.find('}',i); if (end == std::string::npos) break;
            const auto name = word.text.substr(i,end-i+1);
            bool known = name.rfind("{gop:",0) == 0 && name.size() > 7 && name[name.size()-2] == 's';
            for (const auto& macro : MacroDefinitions()) if (Str(macro,"name") == name) known = true;
            if (known && std::find(macros.begin(),macros.end(),Json(name)) == macros.end()) macros.push_back(name);
            i = end+1;
        }
        result.push_back(Json{{"stage",stage.empty() ? Json(nullptr) : Json(stage)},{"isOption",option},{"macros",macros}});
    }
    return result;
}
Json Lint(const Json& request, const Json* capabilities) {
    const auto text = Str(request,"text"); const Json noCaps = nullptr;
    const Json& caps = capabilities ? *capabilities : request.contains("capabilities") ? request.at("capabilities") : noCaps;
    const auto offsets = Utf16Map(text);
    const bool extra = Bool(request,"extra"); Json diagnostics = Json::array(); std::vector<Word> words;
    auto emit = [&](const std::string& id, const std::string& level, size_t start, size_t end, const std::string& message, Json params = Json::object()) { diagnostics.push_back(Diagnostic(id,level,offsets,start,end,message,params)); };
    if (text.find('\0') != std::string::npos) { emit("L-NUL","error",0,text.size(),"Commands cannot contain a NUL character."); return diagnostics; }
    size_t quote = text.size(); words = Tokenize(text,&quote);
    if (quote != text.size()) { emit("L-QUOTE","error",quote,text.size(),"Close the double quote in the command."); return diagnostics; }
    auto encoders = Encoders(words);
    if (extra) encoders[Str(request,"kind","video")] = Str(request,"encoder");
    if (!extra) for (const auto& macro : {"{inputs}","{output}"}) {
        size_t count = 0; for (const auto& word : words) if (word.text == macro) ++count;
        const bool input = std::string(macro) == "{inputs}";
        if (!count) emit(input ? "L-INPUTS" : "L-OUTPUT","error",input ? 0 : text.size(),input ? 0 : text.size(),std::string("Add ") + macro + (input ? " to connect the VEGAS pipes." : " where the output file goes."));
        if (count > 1) emit("L-MACRO-COUNT","error",0,text.size(),std::string(macro) + " must appear exactly once.");
    }
    size_t inputsPosition = text.size(); for (const auto& word : words) if (word.text == "{inputs}") inputsPosition = word.start;
    size_t outputs = 0;
    const auto pairs = PairOptions(words);
    std::vector<const OptionPair*> optionAt(words.size(),nullptr); std::vector<bool> valueWord(words.size(),false);
    for (const auto& pair : pairs) { optionAt[pair.option] = &pair; if (pair.HasValue()) valueWord[pair.value] = true; }
    const std::string ownStream = Str(request,"kind","video"), otherStream = ownStream == "video" ? "audio" : "video";
    const std::string networkMessage = "This argument makes FFmpeg use a network address.";
    for (size_t i = 0; i < words.size(); ++i) {
        if (valueWord[i]) continue;
        const auto& word = words[i]; const auto* pair = optionAt[i];
        if (!pair) {
            if (word.text == "{output}") ++outputs;
            else if (!extra && word.text != "{inputs}" && !(i == 0 && (word.text == "ffmpeg" || word.text == "ffmpeg.exe"))) ++outputs;
            else if (extra) emit("V-EXTRA-ARGUMENT","error",word.start,word.end,"Extra arguments must be stream options and their values.");
            if (Network(word.text)) emit(extra ? "V-EXTRA-NETWORK" : "L-NETWORK","warn",word.start,word.end,networkMessage);
            continue;
        }
        const auto& key = pair->key; const auto kind = Kind(pair->name);
        const Word* next = pair->HasValue() ? &words[pair->value] : nullptr;
        const auto end = next ? next->end : word.end;
        if (extra && (key == "c" || key == "i" || key == "f" || key == "map" || key == "vn" || key == "an" || key == "progress")) emit("V-EXTRA-OWNED","error",word.start,end,"Use the stream/container controls or Advanced mode for this option.");
        if (key == "t" || key == "to" || key == "frames" || key == "vframes" || key == "aframes" || key == "fs") emit(extra ? "V-EXTRA-DURATION" : "L-DURATION-LIMIT","warn",word.start,end,shorterMessage,{{"option",word.text}});
        if (key == "shortest") emit(extra ? "V-EXTRA-SHORTEST" : "L-SHORTEST","warn",word.start,end,shorterMessage,{{"option",word.text}});
        if (next && Network(next->text)) emit(extra ? "V-EXTRA-NETWORK" : "L-NETWORK","warn",word.start,end,networkMessage,{{"option",word.text}});
        if (pair->fromFile || key == "attach" || key == "dump_attachment" || key == "filter_script" || key == "filter_complex_script" ||
            (next && (key == "vf" || key == "af" || key == "filter" || key == "filter_complex" || key == "lavfi") && FileFilter(next->text)))
            emit(extra ? "V-EXTRA-FILE" : "L-FILE-ACCESS","warn",word.start,end,"This argument makes FFmpeg read or write a file outside the render.",{{"option",word.text}});
        if (extra) {
            static const std::set<std::string> videoOnly{"pix_fmt","vf","r","s","aspect","crf","g","bf","refs","color_primaries","color_trc","colorspace","color_range","vtag","vframes"};
            static const std::set<std::string> audioOnly{"ar","ac","af","sample_fmt","channel_layout","atag","aframes"};
            if (pair->stream == otherStream || (pair->stream.empty() && (ownStream == "audio" ? videoOnly : audioOnly).count(key)))
                emit("V-EXTRA-WRONG-STREAM","warn",word.start,end,"This option affects the " + otherStream + " stream. Put it in " + (otherStream == "video" ? "Video" : "Audio") + " Extra arguments.",{{"option",word.text},{"stream",otherStream}});
        }
        if (!extra && (key == "hide_banner" || key == "nostdin" || key == "nostats")) emit("L-GLOBAL","hint",word.start,word.end,"Vegas Encoder always adds this option.");
        if (!extra && (key == "y" || key == "n")) emit("L-OVERWRITE","hint",word.start,word.end,"Vegas Encoder publishes a temporary file and handles overwrite itself.");
        if (!extra && key == "i") emit("L-INPUT","warn",word.start,next ? next->end : word.end,"Extra inputs follow the VEGAS inputs: normally index 2, or index 1 without generated audio.");
        if (!extra && key == "i" && word.start < inputsPosition) emit("L-INPUT-ORDER","error",word.start,next ? next->end : word.end,"Place extra inputs after {inputs} so the VEGAS inputs keep indexes 0 and 1.");
        if (!IsSwitch(key) && !next) emit("L-VALUE","error",word.start,word.end,"This option needs a value.");
        bool known = generic.count(key) != 0; const Json* option = nullptr; const Json* choice = nullptr; std::string owner;
        for (const auto& [candidate,encoder] : encoders) {
            if (!kind.empty() && candidate != kind) continue;
            const auto privateOption = PrivateOption(caps,encoder,key); const auto curated = Choice(encoder,candidate,key);
            if (privateOption || curated) { option = privateOption; choice = curated; owner = encoder; known = true; break; }
        }
        if (!known) emit(extra ? "V-EXTRA-OPTION" : "L-OPTION","warn",word.start,word.end,"Unknown option for the selected encoder and FFmpeg.",{{"option",word.text}});
        const bool macroValue = next && !extra && next->text.find('{') != std::string::npos;
        if (next && !macroValue && ((choice && !AllowedChoice(*choice,next->text)) || (option && !PrivateValue(*option,next->text)) || !GenericValue(key,next->text))) emit("L-VALUE","error",next->start,next->end,"Unsupported value for this encoder option.",{{"option",word.text},{"value",next->text},{"encoder",owner}});
        if (key == "c" && next && next->text != "copy") {
            bool missing = false;
            if (caps.is_object() && caps.contains("encoders")) missing = !caps.at("encoders").contains(next->text);
            else missing = !FindProfile("video",next->text) && !FindProfile("audio",next->text) && !Options().contains(next->text);
            if (missing) emit("L-ENCODER","warn",next->start,next->end,"This encoder is not in the selected FFmpeg's encoder list.",{{"encoder",next->text}});
        }
        const auto paramsOwner = key == "x264-params" ? "libx264" : key == "x265-params" ? "libx265" : key == "svtav1-params" ? "libsvtav1" : "";
        if (*paramsOwner && encoders.count("video") && encoders.at("video") != paramsOwner) emit("L-OPTION-OWNER","warn",word.start,word.end,std::string(word.text) + " applies to " + paramsOwner + ".");
    }
    if (!extra && outputs > 1) emit("L-OUTPUTS","warn",0,text.size(),"Only {output} is published and cleaned up; other output files are left as FFmpeg writes them.");
    return diagnostics;
}
Json Complete(const Json& request, const Json* capabilities) {
    const auto text = Str(request,"text"); const auto caret = request.at("caret");
    if (!caret.is_number_integer() || caret.get<int64_t>() < 0) throw Error(VE_INVALID_ARGUMENT,"CARET","Caret must be a nonnegative UTF-16 offset.");
    const auto offset = Utf8Offset(text,static_cast<size_t>(caret.get<int64_t>()));
    const auto before = text.substr(0,offset); std::vector<Word> words;
    Json result{{"kind","none"},{"of",nullptr},{"start",caret},{"end",caret},{"items",Json::array()}};
    try { words = Tokenize(before); } catch (const Error&) { return result; }
    const bool space = before.empty() || before.back() == ' ' || before.back() == '\t' || before.back() == '\n' || before.back() == '\r';
    const auto partial = space || words.empty() ? "" : words.back().text;
    const size_t startByte = space || words.empty() ? offset : words.back().start;
    size_t endByte = offset;
    while (endByte < text.size() && text[endByte] != ' ' && text[endByte] != '\t' && text[endByte] != '\n' && text[endByte] != '\r') ++endByte;
    result["start"] = Utf16Offset(text,startByte); result["end"] = Utf16Offset(text,endByte);
    const auto encoders = Encoders(words); const Json noCaps = nullptr;
    const Json& caps = capabilities ? *capabilities : request.contains("capabilities") ? request.at("capabilities") : noCaps;
    const size_t prevIndex = space ? words.size() : words.empty() ? 0 : words.size() - 1;
    const auto previous = prevIndex ? words[prevIndex-1].text : "";
    std::set<std::string> seen;
    auto add = [&](Json suggestion) { const auto value = Str(suggestion,"value"); if (value.rfind(partial,0) == 0 && seen.insert(value).second && result["items"].size() < 80) result["items"].push_back(std::move(suggestion)); };
    if (!previous.empty() && IsOption(previous) && (partial.empty() || partial[0] != '-')) {
        const auto key = OptionKey(previous), kind = Kind(previous); result["kind"] = "value"; result["of"] = previous;
        if (key == "c") {
            if (caps.is_object() && caps.contains("encoders")) for (const auto& item : caps.at("encoders").items()) {
                if (!kind.empty() && Str(item.value(),"kind") != kind) continue;
                add(Suggestion(item.key(),Str(item.value(),"description",item.key()),nullptr,nullptr,"FFmpeg",Str(item.value().value("availability",Json::object()),"state","unknown")));
            } else for (const auto& candidate : {"video","audio"}) if (kind.empty() || kind == candidate) for (const auto& p : Profiles().at(candidate)) add(Suggestion(Str(p,"id"),Str(p,"blurb"),nullptr,nullptr,"Curated profile","unknown"));
        } else for (const auto& [candidate,encoder] : encoders) {
            if (!kind.empty() && kind != candidate) continue;
            const auto choices = Choice(encoder,candidate,key); const auto option = PrivateOption(caps,encoder,key);
            if (choices) for (const auto& value : choices->at("values")) { const auto name = value.get<std::string>(); add(Suggestion(name,Str(choices->value("names",Json::object()),name,name),nullptr,choices->value("def",Json(nullptr)),encoder)); }
            if (option) for (const auto& constant : option->value("constants",Json::array())) add(Suggestion(Str(constant,"name"),Str(constant,"description"),option->value("type",Json(nullptr)),option->value("defaultValue",Json(nullptr)),encoder));
        }
        if (result["items"].empty()) result["kind"] = "none";
        return result;
    }
    if (!partial.empty() && partial[0] == '{') {
        result["kind"] = "value";
        for (const auto& macro : MacroDefinitions()) add(Suggestion(Str(macro,"name"),Str(macro,"description"),nullptr,nullptr,"Macro"));
        return result;
    }
    result["kind"] = "option";
    for (const auto& [kind,encoder] : encoders) {
        (void)kind; const auto options = EncoderOptions(caps,encoder);
        if (options && options->contains("options")) for (const auto& option : options->at("options")) add(Suggestion("-" + Str(option,"name"),Str(option,"description"),option.value("type",Json(nullptr)),option.value("defaultValue",Json(nullptr)),encoder));
    }
    for (const auto& [option,description] : generic) add(Suggestion("-" + option,description,nullptr,nullptr,"FFmpeg"));
    return result;
}
} // namespace ve
