// Actual B6 adapter loop over the existing fake host and real supplied FFmpeg.
// Runtime selection is injected; no installed exporter, app or user data is used.
#include "../../src/vegas/adapter/vegas_encoder.h"
#include "../../src/vegas/adapter/recipe_runtime.h"
#include "../../src/vegas/configuration/recipe_template.h"
#include "../../src/vegas/adapter/recipe_destination.h"
#include "../fiohost/fakehost.h"
#include <cstdio>
#include <filesystem>
#include <tuple>
#include <fstream>
#include <atomic>
#include <thread>

using namespace vegas_encoder;
using namespace sfio;
using ve::Json;
namespace {
RecipeRuntime selected;
int checks = 0;
bool legacyAutomaticNames = false;
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
// Project facts the conformed template and the fake streams deliver (T2).
DWORD projectRate = 48000; WORD projectChannels = 2; double projectAspect = 1.0;
Tpl Template(const Json& recipe) {
  auto value = Tpl::Make(L"Immutable recipe", L"B6 adapter test", 0);
  value.SetGuid(tpl::iidOwner, GUID_VegasEncoderType);
  value.SetAudio(tpl::audioRender, Float32Record(projectRate, projectChannels));
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
         bool encoderFailure = false, const wchar_t* pathExtension = nullptr, bool suffixOnlyName = false,
         bool nominalExisting = false) {
  const auto folder = root + L"\\" + name;
  std::filesystem::create_directories(folder);
  selected.jobsRoot = folder + L"\\jobs";
  const auto container = ve::FindContainer(ve::Str(recipe.at("container"),"format"));
  const auto extension = legacyAutomaticNames ? configuration::RecipeOutputExtension(recipe) :
    pathExtension ? std::wstring(pathExtension) : container ? Widen(ve::Str(*container,"ext")) : L".mkv";
  const auto requested = folder + L"\\" + (suffixOnlyName ? L"" : L"render") + (pathExtension ? pathExtension : extension);
  const auto resolved = legacyAutomaticNames ? ResolveRecipeDestination(recipe,requested) : requested;
  // Decision D1: VEGAS 2026 checked this exact name, so an existing file is replaced. Legacy automatic
  // names change the suffix VEGAS checked, so they never replace and take the first free "name (n)".
  const auto output = legacyAutomaticNames && existing ?
    (std::filesystem::path(resolved).parent_path() / (std::filesystem::path(resolved).stem().wstring() + L" (2)" +
                                                      std::filesystem::path(resolved).extension().wstring())).wstring() : resolved;
  const bool success = expected == S_OK;
  if (existing) { std::ofstream file{std::filesystem::path(resolved)}; file << "preserve destination"; }
  if (nominalExisting) { Check(requested != output,"nominal-collision fixture must use a different actual path"); std::ofstream file{std::filesystem::path(requested)}; file << "preserve nominal"; }
  auto value = Template(recipe);
  ISfRenderFile* raw = nullptr;
  Check(CreateRenderFile(value.Ptr(), &raw) == S_OK && raw, "recipe Create accepts owned snapshot");
  std::unique_ptr<ISfRenderFile, ComRelease> render(raw);
  if (mutateAfterCreate) {
    auto changed = configuration::ReadRecipeSnapshot(value, GUID_VegasEncoderType);
    changed["recipe"]["name"] = "Later page edit";
    changed["recipe"]["video"]["encoder"] = "unknown_later_edit";
    changed["recipe"]["container"]["format"] = "mp4";
    value = configuration::ReplaceRecipeSnapshot(value, GUID_VegasEncoderType, changed);
  }
  RenderTestOptions options; options.width = 320; options.height = 180; options.frames = 24;
#if VEGAS_ENCODER_LEGACY_HOST == 13
  options.recipeVideoCompression = BI_RGB;
#endif
  options.fps = 30000.0 / 1001; options.cancelAt = cancelAt; options.progressFailureSlot = failureSlot;
  options.progressFailureAt = 8; options.shortRead = 257;
  options.sampleRate = projectRate; options.channels = projectChannels; options.pixelAspect = projectAspect;
  RenderDeadline deadline;
  const auto began = GetTickCount64();
  const auto host = ExerciseRecipeHost(options, [&](ISfReadVideoRenderStream* video, ISfReadAudioStream* audio, ISfProgress* progress) {
    Check(render->SetStreamReader(video, 0) == S_OK && render->SetStreamReader(audio, 1) == S_OK, "adapter retains readers");
    Check(render->SetFile(requested.c_str()) == S_OK, "adapter accepts nominal or exact output path");
    const auto result = render->Render(progress);
    wchar_t returnedPath[32768]{};
    Check(render->GetFileName(returnedPath,32768) == S_OK && output == returnedPath,"GetFileName reports actual destination after Render");
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
  if (success) {
    // At most two SetPosition/CheckCancel pairs per unblocked frame; frames waiting on FFmpeg may poll more.
    if (host.quietMidFrames * 4 < host.midFrames * 3)
      fprintf(stderr,"%ls: %lld of %lld middle frames used at most two progress polls\n",name,host.quietMidFrames,host.midFrames);
    Check(host.midFrames > 0 && host.quietMidFrames * 4 >= host.midFrames * 3,"unblocked frames poll VEGAS progress at most twice");
  }
  if (expected == E_INVALIDARG) {
    Check((host.served == 0 || projectAspect != 1.0) && !std::filesystem::exists(output),"preflight failure is rejected before encoding");
    // Contracts 3.1/3.2: a render that stops before FFmpeg starts still explains itself.
    const auto record = Record(selected.jobsRoot);
    Check(ve::Str(record,"stage") == "preflight" && record.at("status") == "failed" && record.at("argv").empty() &&
          record.at("published") == false && record.at("sizeBytes") == 0 && record.at("ffmpegExitCode").is_null() &&
          record.at("logFile").is_null() && !ve::Str(record,"message").empty(),"preflight failure writes a C6 record with its reason");
    const auto live = Read(std::filesystem::path(selected.jobsRoot) / (Widen(ve::Str(record,"id")) + L".live.json"));
    Check(live.at("state") == "failed" && live.at("message") == record.at("message"),"preflight failure writes a terminal live status");
    return record;
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
    if (existing) {
      std::ifstream file{std::filesystem::path(resolved)}; const std::string bytes((std::istreambuf_iterator<char>(file)), {});
      if (legacyAutomaticNames)
        Check(bytes == "preserve destination" && record.at("requestedOutputPath") == Utf8(requested.c_str()) && !record.contains("replacedExisting"),
              "legacy automatic names keep the existing file and render to the first free name");
      else Check(bytes != "preserve destination" && record.value("replacedExisting",false) == true,"a confirmed existing destination is replaced");
    }
  }
  else if (existing) {
    std::ifstream file{std::filesystem::path(output)}; const std::string bytes((std::istreambuf_iterator<char>(file)), {});
    Check(bytes == "preserve destination", "failed/cancelled recipe preserves existing output");
  } else Check(!std::filesystem::exists(output), "failed/cancelled recipe does not publish a destination");
  if (!recipe.at("audio")[0].at("enabled").get<bool>()) Check(host.reads == 0, "core inputStreams omits unused audio reads");
  if (requested != output) {
    if (nominalExisting) {
      std::ifstream file{std::filesystem::path(requested)}; const std::string bytes((std::istreambuf_iterator<char>(file)),{});
      Check(bytes == "preserve nominal","nominal path remains untouched when actual path differs");
    } else Check(!std::filesystem::exists(requested),"encoding never publishes to the wrong nominal extension");
  }
  return record;
}
} // namespace
namespace vegas_encoder {
RecipeRuntime LoadRecipeRuntime() { return selected; }
std::wstring RecipeJobsRoot() { return selected.jobsRoot; }
}

int wmain(int argc, wchar_t** argv) {
  try {
    legacyAutomaticNames = argc == 5 && std::wstring(argv[4]) == L"--legacy-auto-names";
    Check(argc == 4 || (argc == 5 && (legacyAutomaticNames || std::wstring(argv[4]) == L"--containers-only")), "usage: recipe-render <fixtures> <fresh-output-root> <ffmpeg> [--containers-only|--legacy-auto-names]");
    const auto root = std::filesystem::absolute(argv[2]).wstring();
    Check(!std::filesystem::exists(root), "fresh test output root required");
    std::filesystem::create_directories(root);
    wchar_t self[32768]{}; GetModuleFileNameW(nullptr, self, 32768);
    const auto ini = (std::filesystem::path(self).parent_path() / L"vegas-encoder.ini").wstring();
    WritePrivateProfileStringW(L"vegas-encoder", L"ShowEncoderErrors", L"1", ini.c_str());
    WritePrivateProfileStringW(L"vegas-encoder", L"LogDir", root.c_str(), ini.c_str());
    WritePrivateProfileStringW(L"vegas-encoder", L"LegacyAutoNames", legacyAutomaticNames ? L"1" : L"0", ini.c_str());
    selected.installation = Installation(std::filesystem::absolute(argv[3]).wstring());
    selected.capabilities = nullptr; selected.verifyOutput = true; selected.hostHwnd = "123456";
    auto recipe = Read(argv[1]).at("fixtures")[0].at("recipe");
    recipe["container"] = {{"format", "mkv"}, {"faststart", false}};
    recipe["video"]["encoder"] = "ffv1"; recipe["video"]["mode"] = "lossless";
    recipe["video"]["depth"] = 10; recipe["video"]["profile"] = nullptr; recipe["video"]["speed"] = nullptr;
    recipe["audio"][0]["encoder"] = "pcm_f32le"; recipe["audio"][0]["mode"] = "lossless";
    if (argc == 5) {
      Run(root,L"mkv-regression",recipe,S_OK,-1,0,true,false,false,legacyAutomaticNames ? L".vencoder" : nullptr);
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
        const auto record = Run(root,Widen(id).c_str(),current,S_OK,-1,0,false,false,false,legacyAutomaticNames ? L".vencoder" : nullptr);
        Check(record.at("verification").at("state") == "passed" && record.at("verification").at("containerEvidenceScope") == "demuxer-family","new container receives sampled readback and explicit family evidence");
      }
      if (legacyAutomaticNames) {
        Run(root,L"nominal-existing",recipe,S_OK,-1,0,false,false,false,L".vencoder",false,true);
        Run(root,L"cancel",recipe,SF_E_RENDER_STOPPED,8,0,false,false,false,L".vencoder");
        Run(root,L"host-error",recipe,E_ACCESSDENIED,-1,7,false,false,false,L".vencoder");
        Run(root,L"recovery",recipe,S_OK,-1,0,false,false,false,L".vencoder");
      } else Run(root,L"mismatched-suffix",recipe,E_INVALIDARG,-1,0,false,false,false,L".mp4");
      Run(root,L"suffix-only-name",recipe,S_OK,-1,0,false,false,false,L".mkv",true);
      Run(root,L"existing-destination",recipe,S_OK,-1,0,false,true,false,legacyAutomaticNames ? L".vencoder" : nullptr);
      printf("Native %s PASS: %d checks / short fake-host real-FFmpeg renders across five containers, output paths and existing destination. No VEGAS.\n",legacyAutomaticNames ? "automatic names" : "containers",checks);
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
    // Projects that are not 48 kHz stereo: the template carries the project's audio format.
    auto aac = recipe; aac["audio"][0]["encoder"] = "aac"; aac["audio"][0]["mode"] = "bitrate"; aac["audio"][0]["bitrateK"] = 192;
    for (const auto& [name, rate, channels] : {std::tuple{L"audio-44100-stereo", DWORD(44100), WORD(2)},
                                               std::tuple{L"audio-48000-mono", DWORD(48000), WORD(1)},
                                               std::tuple{L"audio-48000-5.1", DWORD(48000), WORD(6)}}) {
      projectRate = rate; projectChannels = channels;
      const auto record = Run(root, name, aac, S_OK);
      Check(record.at("media").at("audio").at("rate") == rate && record.at("media").at("audio").at("channels") == channels,
            "C6 media records the project's audio rate and channel count");
    }
    projectRate = 44100; projectChannels = 2;
    Run(root, L"audio-44100-video-only", noAudio, S_OK);
    projectRate = 48000; projectChannels = 2;
    projectAspect = 1.2121;
    const auto nonSquare = Run(root, L"non-square", recipe, E_INVALIDARG);
    Check(ve::Str(nonSquare,"message").find("non-square pixels (pixel aspect 1.2121)") != std::string::npos,
          "non-square project explains the pixel aspect requirement");
    projectAspect = 1.0;
    auto badFilter = recipe; badFilter["video"]["extra"] = "-vf vegas_encoder_deliberate_failure";
    const auto filterFailure = Run(root, L"bad-filter", badFilter, E_FAIL, -1, 0, false, false, true);
    Check(ve::Str(filterFailure,"message").find("No such filter: 'vegas_encoder_deliberate_failure'") != std::string::npos,
          "failure message preserves causal FFmpeg diagnostic instead of the secondary pipe failure");
    const auto failedId = Widen(ve::Str(filterFailure,"id"));
    const auto failedLive = Read(std::filesystem::path(root) / L"bad-filter" / L"jobs" / (failedId + L".live.json"));
    Check(failedLive.at("message") == filterFailure.at("message"), "C5 and C6 share the actionable failure message");
    // 0.2.1 field report: SVT-AV1 rejects a peak rate outside CRF at encoder open and
    // FFmpeg stays alive with its pipes unread. Render must return a failure, not wait
    // for StallTimeoutMs (120 s here) or the user's cancel.
    const auto encoders = [&] {
      FILE* pipe = _wpopen((L"\"\"" + std::filesystem::absolute(argv[3]).wstring() + L"\" -hide_banner -encoders 2>NUL\"").c_str(), L"r");
      std::string text; char buffer[4096]; size_t got = 0;
      while (pipe && (got = fread(buffer, 1, sizeof(buffer), pipe)) > 0) text.append(buffer, got);
      if (pipe) _pclose(pipe);
      return text;
    }();
    if (encoders.find(" libsvtav1 ") != std::string::npos) {
      auto svt = recipe; svt["command"] = {{"mode","template"},{"template","{inputs} -map 0:v:0 -map 1:a:0 -c:v libsvtav1 -preset 8 -b:v 4000k "
                                          "-maxrate 4000k -bufsize 8000k -pix_fmt yuv420p10le -c:a pcm_f32le -f matroska {output}"}};
      const auto began = GetTickCount64();
      const auto svtFailure = Run(root, L"svt-peak-rejected", svt, E_FAIL, -1, 0, false, false, true);
      Check(GetTickCount64() - began < 4000, "SVT-AV1 encoder-open failure returns to VEGAS within seconds");
      Check(ve::Str(svtFailure,"message") == "FFmpeg: Svt[error]: Max Bitrate only supported with CRF mode" && ve::Str(svtFailure,"hresult") == Hr(E_FAIL) && svtFailure.at("ffmpegExitCode") == -22,
            "History, the returned HRESULT and FFmpeg's own exit code (-22) report SVT-AV1's diagnostic");
      const auto svtLive = Read(std::filesystem::path(root) / L"svt-peak-rejected" / L"jobs" / (Widen(ve::Str(svtFailure,"id")) + L".live.json"));
      Check(svtLive.at("state") == "failed" && svtLive.at("message") == svtFailure.at("message"), "the progress window shows the same SVT-AV1 diagnostic");
    } else puts("SKIP svt-peak-rejected: no libsvtav1");
    Run(root, L"after-filter-failure", recipe, S_OK);
    Run(root, L"existing-destination", recipe, S_OK, -1, 0, false, true);
    auto empty = Tpl::Make(L"Not a recipe", L"", 0); empty.SetGuid(tpl::iidOwner, GUID_VegasEncoderType);
    ISfRenderFile* rejected = nullptr;
    Check(CreateRenderFile(empty.Ptr(), &rejected) == E_INVALIDARG && !rejected, "Create rejects absent recipe instead of using proof settings");
    printf("B6 actual adapter PASS: %d checks / %s fake-host real-FFmpeg cases.\n", checks, encoders.find(" libsvtav1 ") != std::string::npos ? "12" : "11");
    return 0;
  } catch (const std::exception& error) {
    fprintf(stderr, "B6 adapter FAIL after %d checks: %s\n", checks, error.what()); return 1;
  }
}
