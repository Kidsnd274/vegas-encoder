#include "recipe_runtime.h"
#include "vegas_encoder.h"
#include <algorithm>
#include <filesystem>
#include <regex>

namespace vegas_encoder {
namespace {
namespace fs = std::filesystem;
struct File {
  HANDLE value = INVALID_HANDLE_VALUE;
  ~File() { if (value != INVALID_HANDLE_VALUE) CloseHandle(value); }
};
std::wstring Environment(const wchar_t* name) {
  const auto length = GetEnvironmentVariableW(name,nullptr,0);
  if (!length) return {};
  if (length > 32768) throw std::runtime_error("User data path is too long.");
  std::wstring result(length,L'\0');
  const auto written = GetEnvironmentVariableW(name,result.data(),length);
  if (!written || written >= length) throw std::runtime_error("User data path changed while reading.");
  result.resize(written); return result;
}
std::wstring Root(bool local) {
  const auto overrideRoot = Environment(L"VEGAS_ENCODER_DATA_ROOT");
  const auto result = !overrideRoot.empty() ? fs::path(overrideRoot) / (local ? L"Local" : L"Roaming") :
    fs::path(Environment(local ? L"LOCALAPPDATA" : L"APPDATA")) / L"VegasEncoder";
  if (!result.is_absolute()) throw std::runtime_error("Absolute per-user Vegas Encoder data roots are required.");
  return result.lexically_normal().wstring();
}
ve::Json Read(const std::wstring& path) {
  File file; file.value = CreateFileW(path.c_str(),GENERIC_READ,FILE_SHARE_READ | FILE_SHARE_DELETE,nullptr,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,nullptr);
  if (file.value == INVALID_HANDLE_VALUE) {
    if (GetLastError() == ERROR_FILE_NOT_FOUND || GetLastError() == ERROR_PATH_NOT_FOUND) return nullptr;
    throw std::runtime_error("Cannot read Vegas Encoder settings/cache. Close other writers and retry.");
  }
  LARGE_INTEGER size{};
  if (!GetFileSizeEx(file.value,&size) || size.QuadPart < 0 || size.QuadPart > VE_CORE_JSON_LIMIT)
    throw std::runtime_error("Vegas Encoder settings/cache exceeds its 1 MiB limit.");
  std::vector<uint8_t> bytes(static_cast<size_t>(size.QuadPart) + 1);
  DWORD count = 0;
  if (!ReadFile(file.value,bytes.data(),static_cast<DWORD>(bytes.size()),&count,nullptr) || count > VE_CORE_JSON_LIMIT)
    throw std::runtime_error("Cannot read bounded Vegas Encoder settings/cache.");
  // A short/growing concurrent write is rejected by the core parser. Atomic
  // repository replacement keeps this handle on one independently owned file.
  return ve::Parse(bytes.data(),count);
}
bool Flag(const ve::Json& object, const char* key, bool fallback) {
  if (!object.contains(key)) return fallback;
  if (!object.at(key).is_boolean()) throw std::runtime_error("Invalid boolean in machine.json.");
  return object.at(key).get<bool>();
}
void AppReady() {
  const auto& application = Cfg().appPath;
  if (application.empty() || application.find(L'\0') != std::wstring::npos || !fs::path(application).is_absolute() ||
      GetFileAttributesW(application.c_str()) == INVALID_FILE_ATTRIBUTES)
    throw std::runtime_error("Matching Vegas Encoder app is missing. Run the reviewed setup or restore the staged app folder.");
  if (FileVersion(Utf8(application.c_str())) != VE_APP_FILE_VERSION_STRING)
    throw std::runtime_error("Vegas Encoder app and plug-in versions differ. Run the matching setup (app " VE_APP_VERSION ").");
}
void EnsureDirectory(const fs::path& path) {
  // Refuse known junctions before creating children; the transport subsequently
  // pins every ancestor while a session is active.
  fs::path current;
  for (const auto& component : path) {
    current /= component;
    const auto attributes = GetFileAttributesW(current.c_str());
    if (attributes != INVALID_FILE_ATTRIBUTES && (attributes & FILE_ATTRIBUTE_REPARSE_POINT))
      throw std::runtime_error("Editor session roots must not traverse a reparse point.");
  }
  fs::create_directories(path);
}
void ValidateCandidateRecipe(const ve::Json& recipe) {
  const ve::Json media{{"video",{{"width",1920},{"height",1080},{"fps",{30000,1001}},{"pixfmt","p010le"},{"sar","1:1"}}},
                       {"audio",{{"rate",48000},{"channels",2},{"sampleFmt","f32le"}}},{"durationSec",nullptr}};
  const ve::Json paths{{"ffmpeg","ffmpeg.exe"},{"videoPipe","candidate-video"},{"audioPipe","candidate-audio"},{"output","candidate.mkv"},{"project",""}};
  auto targetPaths = paths; targetPaths["target"] = {{"id","vegas-native-v1"}};
  const auto compiled = ve::Compile({{"recipe",recipe},{"media",media},{"paths",targetPaths}});
  for (const auto& issue : compiled.at("issues")) if (ve::Str(issue,"level") == "error")
    throw std::runtime_error(ve::Str(issue,"message"));
}
}
ve::Json DefaultRecipeSnapshot() {
  const ve::Json recipe{{"schema",1},{"id","vegas-mkv"},{"name","VEGAS render"},{"notes",""},{"tags",ve::Json::array()},{"category","archive"},
    {"container",{{"format","mkv"},{"faststart",false}}},
    {"video",{{"enabled",true},{"encoder","ffv1"},{"mode","lossless"},{"depth",10},{"color","bt709"},{"extra",""}}},
    {"audio",ve::Json::array({{{"enabled",true},{"encoder","pcm_f32le"},{"mode","lossless"},{"sampleRate","source"},{"channels","source"},{"extra",""}}})},
    {"command",{{"mode","structured"},{"template",""}}},{"vegas",{{"frame","project"},{"inputFormat","p010"}}}};
  const auto normalized = ve::Normalize({{"recipe",recipe}});
  if (ve::HasErrors(normalized.at("issues"))) throw std::runtime_error("Candidate default recipe failed native normalization.");
  return {{"recipe",normalized.at("recipe")},{"origin",nullptr},{"vegasPrefs",ve::Json::object()},{"writtenBy",kVersion}};
}
RecipeRuntime LoadRecipeRuntime() {
  RecipeRuntime result;
  const auto machine = Read((fs::path(Root(false)) / L"machine.json").wstring());
  if (!machine.is_object() || machine.value("machine",ve::Json(nullptr)) != 1 || !machine.at("machine").is_number_integer())
    throw std::runtime_error("Set up a default FFmpeg in the matching Vegas Encoder desktop app before rendering (machine.json v1 required).");
  const auto selected = ve::Str(machine,"defaultFFmpegId");
  if (selected.empty() || !machine.contains("installations") || !machine.at("installations").is_array())
    throw std::runtime_error("Choose a default FFmpeg in Vegas Encoder before rendering.");
  size_t matches = 0;
  for (const auto& item : machine.at("installations")) if (ve::Str(item,"id") == selected) { result.installation = item; ++matches; }
  if (matches != 1 || !result.installation.is_object()) throw std::runtime_error("The default FFmpeg selection is missing or duplicated in machine.json.");
  const auto& installation = result.installation;
  if (!installation.contains("identity") || !installation.at("identity").is_object()) throw std::runtime_error("FFmpeg identity is missing; add the installation again in the app.");
  const auto key = ve::Str(installation.at("identity"),"key");
  if (!std::regex_match(key,std::regex("[A-Fa-f0-9]{64}"))) throw std::runtime_error("Invalid FFmpeg cache identity.");
  result.jobsRoot = (fs::path(Root(true)) / L"jobs").wstring();
  result.verifyOutput = Flag(machine,"verifyOutput",true);
  const auto cache = Read((fs::path(Root(true)) / L"cache" / (Widen(key) + L".json")).wstring());
  if (!cache.is_null()) {
    if (!cache.is_object() || cache.value("cache",ve::Json(nullptr)) != 1 || !cache.at("cache").is_number_integer() ||
        !cache.contains("capabilities") || !cache.at("capabilities").is_object()) throw std::runtime_error("Invalid FFmpeg capability cache.");
    const auto& capabilities = cache.at("capabilities");
    if (capabilities.value("parser",ve::Json(nullptr)) != 2 || ve::Str(capabilities,"identityKey") != key ||
        ve::Str(capabilities,"installationId") != selected) throw std::runtime_error("FFmpeg capability cache does not match the selected installation; probe it again in the app.");
    result.capabilities = capabilities;
    // Hardware readiness includes GPU/driver/age checks in the app. Do not label
    // a stored smoke result as currently qualified from this lightweight reader.
    for (const auto& profile : ve::Profiles().at("video")) if (!profile.value("hw",ve::Json(nullptr)).is_null()) {
      const auto name = ve::Str(profile,"id");
      if (result.capabilities.contains("encoders") && result.capabilities["encoders"].contains(name))
        result.capabilities["encoders"][name]["availability"] = {{"state","unknown"},{"reason","Hardware readiness is not requalified by the native candidate."}};
    }
  }
  HWND window = GetAncestor(GetForegroundWindow(),GA_ROOTOWNER); DWORD pid = 0;
  if (window && GetWindowThreadProcessId(window,&pid) && pid == GetCurrentProcessId())
    result.hostHwnd = std::to_string(reinterpret_cast<uintptr_t>(window));
  if (Flag(machine,"progressWindow",true)) {
    try { AppReady(); result.monitorApplication = Cfg().appPath; }
    catch (const std::exception& error) { Log("monitor unavailable (render continues): %s",error.what()); }
  }
  return result;
}
configuration::RecipePageOptions RecipeEditorOptions() {
  configuration::RecipePageOptions options;
  options.owner = GUID_VegasEncoderType;
  options.launch.application = Cfg().appPath;
  options.sessionRoot = (fs::path(Root(true)) / L"sessions").wstring();
  options.dllVersion = kVersion;
  ve_buffer version{};
  if (ve_core_version(&version) != VE_OK) { ve_free(version.data); throw std::runtime_error("Cannot read native core version."); }
  try { options.coreVersion = ve::Str(ve::Parse(version.data,version.length),"core"); }
  catch (...) { ve_free(version.data); throw; }
  ve_free(version.data);
  options.context["hostVersion"] = FileVersion(ModulePath(nullptr));
  options.context["target"] = {{"id","vegas-native-v1"}};
  options.beforeLaunch = [root = options.sessionRoot] { AppReady(); EnsureDirectory(root); };
  options.validateRecipe = ValidateCandidateRecipe;
  return options;
}
} // namespace vegas_encoder
