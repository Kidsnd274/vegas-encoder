// C7 runtime reader bounds/selection and native editor preflight, isolated files.
#include "../../src/vegas/adapter/recipe_runtime.h"
#include "../../src/vegas/adapter/vegas_encoder.h"
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
    Check(argc == 3, "usage: recipe-runtime <fresh-root> <candidate-app>");
    const auto root = fs::absolute(argv[1]); Check(!fs::exists(root),"fresh root required"); fs::create_directories(root);
    Check(SetEnvironmentVariableW(L"VEGAS_ENCODER_DATA_ROOT",root.c_str()),"set isolated data root");
    wchar_t self[32768]{}; GetModuleFileNameW(nullptr,self,32768);
    const auto ini = fs::path(self).parent_path() / L"vegas-encoder.ini";
    WritePrivateProfileStringW(L"vegas-encoder",L"AppPath",argv[2],ini.c_str());
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
    Json caps{{"parser",2},{"identityKey",key},{"installationId","selected"},{"encoders",{{"h264_nvenc",{{"availability",{{"state","available"}}}}}}}};
    Write(cacheFile,{{"cache",1},{"capabilities",caps}});
    Check(LoadRecipeRuntime().capabilities.at("encoders").at("h264_nvenc").at("availability").at("state") == "unknown","native reader does not promote stored hardware readiness");
    caps["identityKey"] = std::string(64,'b'); Write(cacheFile,{{"cache",1},{"capabilities",caps}});
    Reject([] { LoadRecipeRuntime(); },"mismatched cache rejected");
    fs::remove(cacheFile);
    { std::ofstream file(machineFile,std::ios::binary); file << std::string(VE_CORE_JSON_LIMIT + 1,'x'); }
    Reject([] { LoadRecipeRuntime(); },"oversize C7 refused"); Write(machineFile,machine);
    auto options = RecipeEditorOptions();
    Check(!options.coreVersion.empty() && options.context.at("media").is_null() && options.context.at("project").is_null(),"editor core version is owned and unestablished context stays null");
    options.beforeLaunch(); Check(fs::is_directory(options.sessionRoot),"matching real app version accepted; session root prepared");
    const auto recipe = DefaultRecipeSnapshot().at("recipe"); options.validateRecipe(recipe); ++checks;
    auto unsupported = recipe; unsupported["container"]["format"] = "mp4";
    Reject([&] { options.validateRecipe(unsupported); },"non-MKV candidate rejected before native draft Apply");
    machine["progressWindow"] = true; Write(machineFile,machine);
    Check(LoadRecipeRuntime().monitorApplication == argv[2],"matching app monitor selected from C7 preference");
    printf("B6 C7 RUNTIME PASSED: %d checks; isolated files and real app version resource, no VEGAS\n",checks);
    return 0;
  } catch (const std::exception& error) { printf("B6 C7 RUNTIME FAILED after %d checks: %s\n",checks,error.what()); return 1; }
}
