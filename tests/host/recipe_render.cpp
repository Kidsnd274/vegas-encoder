// Actual B6 adapter loop over the existing fake host and real supplied FFmpeg.
// Runtime selection is injected; no installed exporter, app or user data is used.
#include "../../src/vegas/adapter/vegas_encoder.h"
#include "../../src/vegas/adapter/recipe_runtime.h"
#include "../../src/vegas/configuration/recipe_template.h"
#include "../fiohost/fakehost.h"
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <atomic>
#include <thread>

using namespace vegas_encoder;
using namespace sfio;
using ve::Json;
namespace {
RecipeRuntime selected;
int checks = 0;
void Check(bool ok, const char* message) { ++checks; if (!ok) throw std::runtime_error(message); }
// Bound each tiny fake-host render even if a modal dialog blocks its return.
// On regression only this isolated test process exits; its kill-on-close job
// cleans up the owned encoder. Host calls stay on the original caller thread.
struct RenderDeadline {
  std::atomic<bool> done{false};
  std::thread worker;
  RenderDeadline() {
    worker = std::thread([this] {
      const auto until = GetTickCount64() + 15000;
      while (!done && GetTickCount64() < until) Sleep(10);
      if (!done) {
        fputs("B6 adapter FAIL: Render did not return to the host within 15 s with ShowEncoderErrors enabled.\n", stderr);
        fflush(stderr);
        TerminateProcess(GetCurrentProcess(), 1);
      }
    });
  }
  void Join() { done = true; if (worker.joinable()) worker.join(); }
  ~RenderDeadline() { Join(); }
};
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
         LONGLONG cancelAt = -1, int failureSlot = 0, bool mutateAfterCreate = false, bool existing = false,
         bool encoderFailure = false, const wchar_t* pathExtension = nullptr, bool suffixOnlyName = false) {
  const auto folder = root + L"\\" + name;
  std::filesystem::create_directories(folder);
  selected.jobsRoot = folder + L"\\jobs";
  const auto container = ve::FindContainer(ve::Str(recipe.at("container"),"format"));
  const auto extension = pathExtension ? std::wstring(pathExtension) : container ? Widen(ve::Str(*container,"ext")) : L".mkv";
  const auto output = folder + L"\\" + (suffixOnlyName ? L"" : L"render") + extension;
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
  RenderDeadline deadline;
  const auto began = GetTickCount64();
  const auto host = ExerciseRecipeHost(options, [&](ISfReadVideoRenderStream* video, ISfReadAudioStream* audio, ISfProgress* progress) {
    Check(render->SetStreamReader(video, 0) == S_OK && render->SetStreamReader(audio, 1) == S_OK, "adapter retains readers");
    Check(render->SetFile(output.c_str()) == S_OK, "adapter accepts output path");
    const auto result = render->Render(progress);
    wchar_t returnedPath[32768]{};
    Check(render->GetFileName(returnedPath,32768) == S_OK && output == returnedPath,"GetFileName preserves exact SetFile destination");
    Check(render->CloseFile() == S_OK, "adapter CloseFile after render");
    Check(render->SetStreamReader(nullptr, 0) == S_OK && render->SetStreamReader(nullptr, 1) == S_OK,
          "adapter releases reader references before host audit");
    return result;
  });
  deadline.Join();
  Check(GetTickCount64() - began < 15000, "Render returns to the host promptly with ShowEncoderErrors enabled");
  Check(encoderFailure ? FAILED(host.returned) && host.returned != SF_E_RENDER_STOPPED : host.returned == expected,
        "adapter preserves success/cancellation/host error HRESULT and returns encoder failures as failures");
  Check(host.served == host.released && !host.outstanding && !host.lockErrors && !host.callerThreadErrors && !host.tokenErrors,
        "adapter copies/releases frames and keeps all host calls on caller thread");
  if (expected == E_INVALIDARG) {
    Check(host.served == 0 && !std::filesystem::exists(output),"suffix mismatch is rejected before acquiring frames");
    return nullptr;
  }
  const auto record = Record(selected.jobsRoot);
  Check(record.at("outputPath") == Utf8(output.c_str()),"C6 preserves exact selected destination");
  Check(ve::Str(record,"hresult") == Hr(expected == SF_E_RENDER_STOPPED ? SF_E_PROGRESS_CANCELLED : host.returned),
        "C6 preserves the original failure while the host receives its established cancellation mapping");
  Check(record.at("recipe").at("name") == recipe.at("name"), "record uses immutable Create snapshot");
  Check(record.at("status") == (success ? "succeeded" : expected == SF_E_RENDER_STOPPED ? "cancelled" : "failed"), "native C6 terminal classification");
  if (success) {
    Check(std::filesystem::file_size(output) > 20, "real FFmpeg output published");
    const auto temporary = std::filesystem::path(Widen(record.at("argv").back().get<std::string>()));
    Check(temporary.parent_path() == std::filesystem::path(output).parent_path() && temporary.extension() == extension &&
      temporary.filename().wstring().find(L".ve-partial-") != std::wstring::npos,"unique temporary stays beside destination and retains final extension");
  }
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
    Check(argc == 4 || (argc == 5 && std::wstring(argv[4]) == L"--containers-only"), "usage: recipe-render <fixtures> <fresh-output-root> <ffmpeg> [--containers-only]");
    const auto root = std::filesystem::absolute(argv[2]).wstring();
    Check(!std::filesystem::exists(root), "fresh test output root required");
    std::filesystem::create_directories(root);
    wchar_t self[32768]{}; GetModuleFileNameW(nullptr, self, 32768);
    const auto ini = (std::filesystem::path(self).parent_path() / L"vegas-encoder.ini").wstring();
    WritePrivateProfileStringW(L"vegas-encoder", L"ShowEncoderErrors", L"1", ini.c_str());
    WritePrivateProfileStringW(L"vegas-encoder", L"LogDir", root.c_str(), ini.c_str());
    selected.installation = Installation(std::filesystem::absolute(argv[3]).wstring());
    selected.capabilities = nullptr; selected.verifyOutput = true; selected.hostHwnd = "123456";
    auto recipe = Read(argv[1]).at("fixtures")[0].at("recipe");
    recipe["container"] = {{"format", "mkv"}, {"faststart", false}};
    recipe["video"]["encoder"] = "ffv1"; recipe["video"]["mode"] = "lossless";
    recipe["video"]["depth"] = 10; recipe["video"]["profile"] = nullptr; recipe["video"]["speed"] = nullptr;
    recipe["audio"][0]["encoder"] = "pcm_f32le"; recipe["audio"][0]["mode"] = "lossless";
    if (argc == 5) {
      Run(root,L"mkv-regression",recipe,S_OK);
      for (const auto* id : {"mp4","mov","webm","mxf"}) {
        auto current = recipe; current["container"]["format"] = id;
        if (std::string(id) == "mp4") {
          current["container"]["faststart"] = true;
          current["video"]["encoder"] = "libx264"; current["video"]["mode"] = "crf"; current["video"]["quality"] = 20; current["video"]["depth"] = 8; current["video"]["speed"] = "ultrafast";
          current["audio"][0]["encoder"] = "aac"; current["audio"][0]["mode"] = "bitrate";
        } else if (std::string(id) == "mov") {
          current["video"]["encoder"] = "prores_ks"; current["video"]["mode"] = "profile"; current["video"]["profile"] = "hq";
          current["audio"][0]["encoder"] = "pcm_s24le";
        } else if (std::string(id) == "webm") {
          current["command"] = {{"mode","template"},{"template","{inputs} -map 0:v:0 -map 1:a:0 -c:v libvpx-vp9 -deadline realtime -cpu-used 5 -crf 35 -b:v 0 -pix_fmt yuv420p10le -c:a libopus -b:a 160k -f webm {output}"}};
        } else {
          current["video"]["encoder"] = "dnxhd"; current["video"]["mode"] = "profile"; current["video"]["profile"] = "dnxhr_hq"; current["video"]["depth"] = 8;
          current["audio"][0]["encoder"] = "pcm_s16le";
        }
        const auto record = Run(root,Widen(id).c_str(),current,S_OK);
        Check(record.at("verification").at("state") == "passed" && record.at("verification").at("containerEvidenceScope") == "demuxer-family","new container receives sampled readback and explicit family evidence");
      }
      Run(root,L"mismatched-suffix",recipe,E_INVALIDARG,-1,0,false,false,false,L".mp4");
      Run(root,L"suffix-only-name",recipe,S_OK,-1,0,false,false,false,L".mkv",true);
      Run(root,L"existing-destination",recipe,HRESULT_FROM_WIN32(ERROR_FILE_EXISTS),-1,0,false,true);
      printf("Native containers PASS: %d checks / five short fake-host real-FFmpeg renders, suffix preflight and existing destination. No VEGAS.\n",checks);
      return 0;
    }
    Run(root, L"immutable", recipe, S_OK, -1, 0, true);
    auto noAudio = recipe; noAudio["audio"][0]["enabled"] = false;
    Run(root, L"video-only", noAudio, S_OK);
    Run(root, L"cancel", recipe, SF_E_RENDER_STOPPED, 8);
    Run(root, L"host-error", recipe, E_ACCESSDENIED, -1, 7);
    auto advanced = recipe;
    advanced["command"] = {{"mode", "template"}, {"template", "{inputs} -map 0:v:0 -map 1:a:0 -c:v ffv1 -pix_fmt yuv420p10le -c:a pcm_f32le -f matroska {output}"}};
    Run(root, L"advanced-mkv", advanced, S_OK);
    auto invalid = recipe; invalid["command"] = {{"mode","template"},{"template","{inputs} -c:v ffv1 -c:a pcm_f32le -f unknown_muxer {output}"}};
    Run(root, L"unknown-muxer", invalid, E_FAIL);
    advanced["command"]["template"] = "{inputs} -c:v ffv1 -c:a pcm_f32le {output}";
    Run(root, L"unknown-container", advanced, E_FAIL);
    Run(root, L"recovery", recipe, S_OK);
    auto badFilter = recipe; badFilter["video"]["extra"] = "-vf vegas_encoder_deliberate_failure";
    const auto filterFailure = Run(root, L"bad-filter", badFilter, E_FAIL, -1, 0, false, false, true);
    Check(ve::Str(filterFailure,"message").find("No such filter: 'vegas_encoder_deliberate_failure'") != std::string::npos,
          "failure message preserves causal FFmpeg diagnostic instead of the secondary pipe failure");
    const auto failedId = Widen(ve::Str(filterFailure,"id"));
    const auto failedLive = Read(std::filesystem::path(root) / L"bad-filter" / L"jobs" / (failedId + L".live.json"));
    Check(failedLive.at("message") == filterFailure.at("message"), "C5 and C6 share the actionable failure message");
    Run(root, L"after-filter-failure", recipe, S_OK);
    Run(root, L"existing-destination", recipe, HRESULT_FROM_WIN32(ERROR_FILE_EXISTS), -1, 0, false, true);
    auto empty = Tpl::Make(L"Not a recipe", L"", 0); empty.SetGuid(tpl::iidOwner, GUID_VegasEncoderType);
    ISfRenderFile* rejected = nullptr;
    Check(CreateRenderFile(empty.Ptr(), &rejected) == E_INVALIDARG && !rejected, "Create rejects absent recipe instead of using proof settings");
    printf("B6 actual adapter PASS: %d checks / 11 fake-host real-FFmpeg cases.\n", checks);
    return 0;
  } catch (const std::exception& error) {
    fprintf(stderr, "B6 adapter FAIL after %d checks: %s\n", checks, error.what()); return 1;
  }
}
