// C7 runtime reader bounds/selection and native editor preflight, isolated files.
#include "../../src/vegas/adapter/recipe_runtime.h"
#include "../../src/vegas/adapter/vegas_encoder.h"
#include "../../src/vegas/adapter/render_formats.h"
#include "../../src/support/diagnostics.h"
#include <filesystem>
#include <fstream>
#include <cstdio>
using ve::Json;
using namespace vegas_encoder;
namespace fs = std::filesystem;
namespace {
int checks = 0;
void Check(bool ok, const char* message) { ++checks; if (!ok) throw std::runtime_error(message); }
template<class F> void Reject(F action, const char* message) {
  bool rejected = false; try { action(); } catch (const std::exception&) { rejected = true; } Check(rejected,message);
}
void Write(const fs::path& path, const Json& value) {
  fs::create_directories(path.parent_path()); std::ofstream file(path,std::ios::binary); file << value.dump();
  if (!file) throw std::runtime_error("cannot write test settings");
}
}
int wmain(int argc, wchar_t** argv) {
  try {
    const bool legacyNames = argc == 4 && std::wstring(argv[3]) == L"--legacy-auto-names";
    Check(argc == 3 || legacyNames, "usage: recipe-runtime <fresh-root> <candidate-app> [--legacy-auto-names]");
    const auto root = fs::absolute(argv[1]); Check(!fs::exists(root),"fresh root required"); fs::create_directories(root);
    const DWORD me = 100, other = 200;
    const std::vector<HostWindowCandidate> windows{{1,other,true,false,900},{2,me,true,true,800},{3,me,false,false,700},{4,me,true,false,300},{5,me,true,false,600}};
    Check(ChooseHostWindow({9,me,true,false,100},windows,me) == 9,"progress window follows this process's foreground window");
    Check(ChooseHostWindow({1,other,true,false,900},windows,me) == 5,"otherwise it follows this process's visible, unowned, largest top-level window");
    Check(ChooseHostWindow({1,other,true,false,900},{{1,other,true,false,900}},me) == 0,"no window of this process leaves placement unknown");
    Check(SetEnvironmentVariableW(L"VEGAS_ENCODER_DATA_ROOT",root.c_str()),"set isolated data root");
    wchar_t self[32768]{}; GetModuleFileNameW(nullptr,self,32768);
    Check(ModuleFileName(nullptr,4) == self && !ModuleFileName(nullptr).empty(),"module path helper grows a tiny buffer and returns the full path");
    Check(SetEnvironmentVariableW(L"VEGAS_ENCODER_LONG_TEST",std::wstring(1000,L'x').c_str()) &&
          EnvironmentValue(L"VEGAS_ENCODER_LONG_TEST") == std::wstring(1000,L'x') && EnvironmentValue(L"VEGAS_ENCODER_UNSET_TEST").empty(),
          "environment helper returns values longer than MAX_PATH");
    const auto ini = fs::path(self).parent_path() / L"vegas-encoder.ini";
    WritePrivateProfileStringW(L"vegas-encoder",L"AppPath",argv[2],ini.c_str());
    Check(WritePrivateProfileStringW(L"vegas-encoder",L"LegacyAutoNames",legacyNames ? L"1" : L"0",ini.c_str()),
          "configure test naming policy");
    const auto machineFile = root / L"Roaming" / L"machine.json";
    Reject([] { LoadRecipeRuntime(); },"absent C7 rejected without proof fallback");
    const std::string key(64,'a');
    const Json installation{{"id","selected"},{"identity",{{"key",key}}}};
    Json machine{{"machine",1},{"defaultFFmpegId","selected"},{"installations",Json::array({installation})},
                 {"verifyOutput",false},{"progressWindow",false}};
    Write(machineFile,machine);
    const auto runtime = LoadRecipeRuntime();
    Check(runtime.installation == installation && runtime.capabilities.is_null() && !runtime.verifyOutput && runtime.monitorApplication.empty(),"selected C7 copied; absent cache and disabled monitor remain absent");
    Check(fs::path(runtime.jobsRoot) == root / L"Local" / L"jobs","native root matches app override mapping");
    for (int variant = 0; variant < 5; ++variant) {
      auto bad = machine;
      if (variant == 0) bad["machine"] = 2;
      if (variant == 1) bad["installations"].push_back(installation);
      if (variant == 2) bad["defaultFFmpegId"] = "missing";
      if (variant == 3) bad["verifyOutput"] = "true";
      if (variant == 4) bad["installations"][0]["identity"]["key"] = "../escape";
      Write(machineFile,bad); Reject([] { LoadRecipeRuntime(); },"future/duplicate/missing/bad flags/unsafe identity refused");
    }
    Write(machineFile,machine);
    const auto cacheFile = root / L"Local" / L"cache" / (Widen(key) + L".json");
    Json caps{{"parser",VE_FFMPEG_PARSER_VERSION},{"identityKey",key},{"installationId","selected"},{"encoders",{{"h264_nvenc",{{"availability",{{"state","available"}}}}}}}};
    Write(cacheFile,{{"cache",1},{"capabilities",caps}});
    Check(LoadRecipeRuntime().capabilities.at("encoders").at("h264_nvenc").at("availability").at("state") == "unknown","native reader does not promote stored hardware readiness");
    caps["encoders"]["h264_nvenc"]["availability"] = {{"state","failed"},{"reason","No NVENC capable devices found."},{"testedAt","2026-11-01T10:00:00Z"}};
    Write(cacheFile,{{"cache",1},{"capabilities",caps}});
    const auto failedRuntime = LoadRecipeRuntime();
    Check(failedRuntime.capabilities.at("encoders").at("h264_nvenc").at("availability").at("state") == "unknown" &&
          failedRuntime.failedEncoders.contains("h264_nvenc") &&
          failedRuntime.failedEncoders.at("h264_nvenc").at("reason") == "No NVENC capable devices found." &&
          failedRuntime.failedEncoders.at("h264_nvenc").at("testedAt") == "2026-11-01T10:00:00Z",
          "a failed hardware test warns instead of blocking, and its date and reason are kept");
    caps["encoders"]["h264_nvenc"]["availability"] = {{"state","available"}};
    caps["filters"] = {{"scale", {{"available", true}, {"algorithms", Json::array({"bicubic", "bilinear", "lanczos", "neighbor"})}}},
                       {"pad", {{"available", true}}}, {"setsar", {{"available", true}}}};
    Write(cacheFile,{{"cache",1},{"capabilities",caps}});
    Check(LoadRecipeRuntime().capabilities.at("filters") == caps.at("filters"),
          "native runtime preserves selected filter capability facts without probing");
    caps["parser"] = VE_FFMPEG_PARSER_VERSION - 1; Write(cacheFile,{{"cache",1},{"capabilities",caps}});
    Reject([] { LoadRecipeRuntime(); },"stale parser cache requires refresh");
    caps["parser"] = VE_FFMPEG_PARSER_VERSION;
    caps["identityKey"] = std::string(64,'b'); Write(cacheFile,{{"cache",1},{"capabilities",caps}});
    Reject([] { LoadRecipeRuntime(); },"mismatched cache rejected");
    fs::remove(cacheFile);
    { std::ofstream file(machineFile,std::ios::binary); file << std::string(VE_CORE_JSON_LIMIT + 1,'x'); }
    Reject([] { LoadRecipeRuntime(); },"oversize C7 refused"); Write(machineFile,machine);
    auto options = RecipeEditorOptions(GUID_VegasEncoderType,nullptr);
    Check(!options.coreVersion.empty() && options.context.at("media").is_null() && options.context.at("project").is_null(),"editor core version is owned and unestablished context stays null");
    options.beforeLaunch(); Check(fs::is_directory(options.sessionRoot),"matching real app version accepted; session root prepared");
    const auto recipe = DefaultRecipeSnapshot().at("recipe"); options.validateRecipe(recipe); ++checks;
    auto resized = recipe; resized["schema"] = 2;
    resized["video"]["filters"] = Json::array({{{"type", "resize"}, {"enabled", true}, {"width", 1280}, {"height", 720},
      {"backend", "scale"}, {"algorithm", "bicubic"}, {"fit", "pad"}}});
    options.validateRecipe(resized); ++checks;
    auto narrow = resized; narrow["video"]["filters"][0]["width"] = 2; narrow["video"]["filters"][0]["height"] = 1000;
    options.validateRecipe(narrow); ++checks;
    auto invalidCanvas = narrow; invalidCanvas["video"]["filters"][0]["width"] = 0;
    Reject([&] { options.validateRecipe(invalidCanvas); }, "unknown-source editor still rejects invalid canvas dimensions");
    auto unalignedCanvas = narrow; unalignedCanvas["video"]["filters"][0]["width"] = 3;
    Reject([&] { options.validateRecipe(unalignedCanvas); }, "unknown-source editor still rejects known chroma-grid misalignment");
    Check(options.capabilities.is_null(), "editor snapshot acceptance does not invent capability or source facts");
    auto supported = recipe; supported["command"] = {{"mode","template"},{"template","{inputs} -c:v libx264 -c:a aac -f mp4 {output}"}};
    options.validateRecipe(supported); ++checks;
    Check(options.context.at("target").at("id") == "vegas-native-v1","native target reaches popup before Apply");
    Check(options.context.at("extensions").at("renderAsExtension") ==
          (legacyNames ? Json(".vencoder") : Json(nullptr)),
          "popup context reports the active Render As placeholder policy");
    const auto bound = RecipeEditorOptions(kLegacyFormats[1].owner,"mp4");
    Check(bound.owner == kLegacyFormats[1].owner && bound.context.at("target").at("containerId") == "mp4",
          "legacy class ownership and container reach popup together");
    bound.validateRecipe(supported); ++checks;
    Reject([&] { bound.validateRecipe(recipe); },"legacy native Apply refuses MKV recipe in MP4 class");
    Check(options.context.at("target").size() == 1,"modern popup target has no fixed container");
    auto unsupported = recipe; unsupported["command"] = {{"mode","template"},{"template","{inputs} -c:v ffv1 -c:a pcm_f32le {output}"}};
    Reject([&] { options.validateRecipe(unsupported); },"unknown output muxer rejected before native draft Apply");
    machine["progressWindow"] = true; Write(machineFile,machine);
    Check(LoadRecipeRuntime().monitorApplication == argv[2],"matching app monitor selected from C7 preference");
    printf("B6 C7 RUNTIME PASSED: %d checks; isolated files and real app version resource, no VEGAS\n",checks);
    return 0;
  } catch (const std::exception& error) { printf("B6 C7 RUNTIME FAILED after %d checks: %s\n",checks,error.what()); return 1; }
}
