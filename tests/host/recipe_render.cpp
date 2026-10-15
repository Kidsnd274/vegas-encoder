// Actual B6 adapter loop over the existing fake host and real supplied FFmpeg.
// Runtime selection is injected; no installed exporter, app or user data is used.
#include "../../src/vegas/adapter/vegas_encoder.h"
#include "../../src/vegas/adapter/recipe_runtime.h"
#include "../../src/vegas/configuration/recipe_template.h"
#include "../fiohost/fakehost.h"
#include <cstdio>
#include <filesystem>
#include <fstream>

using namespace vegas_encoder;
using namespace sfio;
using ve::Json;
namespace {
RecipeRuntime selected;
int checks = 0;
void Check(bool ok, const char* message) { ++checks; if (!ok) throw std::runtime_error(message); }
Json Read(const std::filesystem::path& path) {
  std::ifstream file(path, std::ios::binary);
  if (!file) throw std::runtime_error("Cannot open test JSON: " + path.string());
  const std::string bytes((std::istreambuf_iterator<char>(file)), {});
  return ve::Parse(reinterpret_cast<const uint8_t*>(bytes.data()), bytes.size());
}
Json Installation(const std::wstring& ffmpeg) {
  const auto folder = std::filesystem::path(ffmpeg).parent_path();
  const auto probe = (folder / L"ffprobe.exe").wstring();
  const auto hash = Sha256File(ffmpeg);
  Json libraries = Json::object();
  for (const auto& entry : std::filesystem::directory_iterator(folder)) {
    const auto name = entry.path().filename().string();
    if (entry.path().extension() == L".dll" && (name.rfind("av", 0) == 0 || name.rfind("sw", 0) == 0 || name.rfind("postproc", 0) == 0))
      libraries[name] = Sha256File(entry.path().wstring());
  }
  return {{"id", hash.substr(0, 12)}, {"path", Utf8(ffmpeg.c_str())}, {"ffprobePath", Utf8(probe.c_str())},
    {"label", "B6 adapter test installation"}, {"version", "supplied Windows build"}, {"source", "manual"},
    {"identity", {{"sha256", hash}, {"key", hash}, {"libraries", libraries}}},
    {"extensions", {{"ffprobeIdentity", {{"sha256", Sha256File(probe)}}}}}};
}
Tpl Template(const Json& recipe) {
  auto value = Tpl::Make(L"Immutable recipe", L"B6 adapter test", 0);
  value.SetGuid(tpl::iidOwner, GUID_VegasEncoderType);
  value.SetAudio(tpl::audioRender, Float32Record(48000, 2));
  return configuration::CreateRecipeTemplate(value, GUID_VegasEncoderType,
    {{"recipe", recipe}, {"origin", nullptr}, {"vegasPrefs", Json::object()}, {"writtenBy", "b6-adapter-test"}, {"extensions", Json::object()}});
}
Json Record(const std::wstring& root) {
  const auto until = GetTickCount64() + 7000;
  while (GetTickCount64() < until) {
    if (std::filesystem::exists(root)) for (const auto& file : std::filesystem::directory_iterator(root)) {
      const auto name = file.path().filename().wstring();
      if (file.path().extension() == L".json" && name.find(L".live.json") == std::wstring::npos) {
        // Publication is asynchronous; tolerate a transient sharing refusal,
        // just as the production readers retain their prior successful read.
        std::ifstream input(file.path(),std::ios::binary);
        if (!input) continue;
        const std::string bytes((std::istreambuf_iterator<char>(input)), {});
        if (bytes.empty()) continue;
        return ve::Parse(reinterpret_cast<const uint8_t*>(bytes.data()),bytes.size());
      }
    }
    Sleep(10);
  }
  throw std::runtime_error("native asynchronous record was not published within 7 s");
}
Json Run(const std::wstring& root, const wchar_t* name, Json recipe, HRESULT expected,
         LONGLONG cancelAt = -1, int failureSlot = 0, bool mutateAfterCreate = false, bool existing = false) {
  const auto folder = root + L"\\" + name;
  std::filesystem::create_directories(folder);
  selected.jobsRoot = folder + L"\\jobs";
  const auto output = folder + L"\\render.mkv";
  const bool success = expected == S_OK;
  if (existing) { std::ofstream file{std::filesystem::path(output)}; file << "preserve destination"; }
  auto value = Template(recipe);
  ISfRenderFile* raw = nullptr;
  Check(CreateRenderFile(value.Ptr(), &raw) == S_OK && raw, "recipe Create accepts owned snapshot");
  std::unique_ptr<ISfRenderFile, ComRelease> render(raw);
  if (mutateAfterCreate) {
    auto changed = configuration::ReadRecipeSnapshot(value, GUID_VegasEncoderType);
    changed["recipe"]["name"] = "Later page edit";
    changed["recipe"]["video"]["encoder"] = "unknown_later_edit";
    value = configuration::ReplaceRecipeSnapshot(value, GUID_VegasEncoderType, changed);
  }
  RenderTestOptions options; options.width = 320; options.height = 180; options.frames = 24;
  options.fps = 30000.0 / 1001; options.cancelAt = cancelAt; options.progressFailureSlot = failureSlot;
  options.progressFailureAt = 8; options.shortRead = 257;
  const auto host = ExerciseRecipeHost(options, [&](ISfReadVideoRenderStream* video, ISfReadAudioStream* audio, ISfProgress* progress) {
    Check(render->SetStreamReader(video, 0) == S_OK && render->SetStreamReader(audio, 1) == S_OK, "adapter retains readers");
    Check(render->SetFile(output.c_str()) == S_OK, "adapter accepts output path");
    const auto result = render->Render(progress);
    Check(render->CloseFile() == S_OK, "adapter CloseFile after render");
    Check(render->SetStreamReader(nullptr, 0) == S_OK && render->SetStreamReader(nullptr, 1) == S_OK,
          "adapter releases reader references before host audit");
    return result;
  });
  Check(host.returned == expected, "adapter preserves success/cancellation/host error HRESULT");
  Check(host.served == host.released && !host.outstanding && !host.lockErrors && !host.callerThreadErrors && !host.tokenErrors,
        "adapter copies/releases frames and keeps all host calls on caller thread");
  const auto record = Record(selected.jobsRoot);
  Check(record.at("recipe").at("name") == recipe.at("name"), "record uses immutable Create snapshot");
  Check(record.at("status") == (success ? "succeeded" : expected == SF_E_RENDER_STOPPED ? "cancelled" : "failed"), "native C6 terminal classification");
  if (success) Check(std::filesystem::file_size(output) > 20, "real FFmpeg output published");
  else if (existing) {
    std::ifstream file{std::filesystem::path(output)}; const std::string bytes((std::istreambuf_iterator<char>(file)), {});
    Check(bytes == "preserve destination", "failed/cancelled recipe preserves existing output");
  } else Check(!std::filesystem::exists(output), "failed/cancelled recipe does not publish a destination");
  if (!recipe.at("audio")[0].at("enabled").get<bool>()) Check(host.reads == 0, "core inputStreams omits unused audio reads");
  return record;
}
} // namespace
namespace vegas_encoder { RecipeRuntime LoadRecipeRuntime() { return selected; } }

int wmain(int argc, wchar_t** argv) {
  try {
    Check(argc == 4, "usage: recipe-render <fixtures> <fresh-output-root> <ffmpeg>");
    const auto root = std::filesystem::absolute(argv[2]).wstring();
    Check(!std::filesystem::exists(root), "fresh test output root required");
    std::filesystem::create_directories(root);
    wchar_t self[32768]{}; GetModuleFileNameW(nullptr, self, 32768);
    const auto ini = (std::filesystem::path(self).parent_path() / L"vegas-encoder.ini").wstring();
    WritePrivateProfileStringW(L"vegas-encoder", L"ShowEncoderErrors", L"0", ini.c_str());
    WritePrivateProfileStringW(L"vegas-encoder", L"LogDir", root.c_str(), ini.c_str());
    selected.installation = Installation(std::filesystem::absolute(argv[3]).wstring());
    selected.capabilities = nullptr; selected.verifyOutput = true;
    auto recipe = Read(argv[1]).at("fixtures")[0].at("recipe");
    recipe["container"] = {{"format", "mkv"}, {"faststart", false}};
    recipe["video"]["encoder"] = "ffv1"; recipe["video"]["mode"] = "lossless";
    recipe["video"]["depth"] = 10; recipe["video"]["profile"] = nullptr; recipe["video"]["speed"] = nullptr;
    recipe["audio"][0]["encoder"] = "pcm_f32le"; recipe["audio"][0]["mode"] = "lossless";
    Run(root, L"immutable", recipe, S_OK, -1, 0, true);
    auto noAudio = recipe; noAudio["audio"][0]["enabled"] = false;
    Run(root, L"video-only", noAudio, S_OK);
    Run(root, L"cancel", recipe, SF_E_RENDER_STOPPED, 8);
    Run(root, L"host-error", recipe, E_ACCESSDENIED, -1, 7);
    auto advanced = recipe;
    advanced["command"] = {{"mode", "template"}, {"template", "{inputs} -map 0:v:0 -map 1:a:0 -c:v ffv1 -pix_fmt yuv420p10le -c:a pcm_f32le -f matroska {output}"}};
    Run(root, L"advanced-mkv", advanced, S_OK);
    auto invalid = recipe; invalid["container"]["format"] = "mp4";
    Run(root, L"wrong-container", invalid, E_FAIL);
    advanced["command"]["template"] = "{inputs} -c:v ffv1 -c:a pcm_f32le {output}";
    Run(root, L"unknown-container", advanced, E_FAIL);
    Run(root, L"recovery", recipe, S_OK);
    Run(root, L"existing-destination", recipe, HRESULT_FROM_WIN32(ERROR_FILE_EXISTS), -1, 0, false, true);
    auto empty = Tpl::Make(L"Not a recipe", L"", 0); empty.SetGuid(tpl::iidOwner, GUID_VegasEncoderType);
    ISfRenderFile* rejected = nullptr;
    Check(CreateRenderFile(empty.Ptr(), &rejected) == E_INVALIDARG && !rejected, "Create rejects absent recipe instead of using proof settings");
    printf("B6 actual adapter PASS: %d checks / 9 fake-host real-FFmpeg cases.\n", checks);
    return 0;
  } catch (const std::exception& error) {
    fprintf(stderr, "B6 adapter FAIL after %d checks: %s\n", checks, error.what()); return 1;
  }
}
