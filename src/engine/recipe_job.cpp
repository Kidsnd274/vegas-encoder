#include "recipe_job.h"
#include "../support/diagnostics.h"
#include <algorithm>
#include <cmath>
#include <filesystem>

namespace vegas_encoder {
namespace {
struct Handle { HANDLE h = nullptr; ~Handle() { if (h && h != INVALID_HANDLE_VALUE) CloseHandle(h); } };
std::wstring QuoteArg(const std::wstring& value) {
  std::wstring text = L"\""; size_t slashes = 0;
  for (auto c : value) {
    if (c == L'\\') { ++slashes; continue; }
    text.append(slashes * (c == L'"' ? 2 : 1), L'\\'); slashes = 0;
    if (c == L'"') text += L'\\'; text += c;
  }
  text.append(slashes * 2, L'\\'); return text + L'"';
}
bool AbsoluteExe(const std::string& text) {
  return text.size() > 3 && text[1] == ':' && (text[2] == '\\' || text[2] == '/') && text.find('\0') == std::string::npos;
}
bool SameHash(const std::string& recorded, const std::string& actual) {
  return recorded.size() == 64 && actual.size() == 64 && _stricmp(recorded.c_str(),actual.c_str()) == 0;
}
std::string Tail(const std::wstring& path) {
  Handle file; file.h = CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                                  nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (file.h == INVALID_HANDLE_VALUE) return {};
  LARGE_INTEGER size{}, position{}; if (!GetFileSizeEx(file.h,&size)) return {};
  position.QuadPart = (std::max)(LONGLONG(0),size.QuadPart - 65536); if (!SetFilePointerEx(file.h,position,nullptr,FILE_BEGIN)) return {};
  std::string bytes(static_cast<size_t>(size.QuadPart-position.QuadPart),'\0'); DWORD got = 0;
  if (!ReadFile(file.h,bytes.data(),static_cast<DWORD>(bytes.size()),&got,nullptr)) return {};
  bytes.resize(got);
  // Windows Widen/Utf8 replaces invalid/truncated UTF-8; persisted JSON stays valid.
  return Utf8(Widen(bytes).c_str());
}
// Bounded shell-free owned FFprobe. Caller polling happens on this thread only.
// stderr shares stdout: any error diagnostic makes the JSON readback fail closed.
bool ProbeChild(const std::wstring& exe, const std::vector<std::wstring>& args, DWORD timeout,
                const std::function<bool()>& poll, std::string& bytes, std::string& failure) {
  SECURITY_ATTRIBUTES sa{sizeof(sa),nullptr,TRUE}; Handle read,write,input,process,thread,job;
  if (!CreatePipe(&read.h,&write.h,&sa,65536) || !SetHandleInformation(read.h,HANDLE_FLAG_INHERIT,0)) { failure = "cannot create FFprobe pipe"; return false; }
  input.h = CreateFileW(L"NUL",GENERIC_READ,FILE_SHARE_READ|FILE_SHARE_WRITE,&sa,OPEN_EXISTING,0,nullptr);
  if (input.h == INVALID_HANDLE_VALUE) { failure = "cannot open FFprobe input"; return false; }
  SIZE_T size = 0; InitializeProcThreadAttributeList(nullptr,1,0,&size); std::vector<BYTE> storage(size);
  auto attributes = reinterpret_cast<LPPROC_THREAD_ATTRIBUTE_LIST>(storage.data());
  if (!InitializeProcThreadAttributeList(attributes,1,0,&size)) { failure = "cannot initialize FFprobe attributes"; return false; }
  HANDLE handles[]{input.h,write.h};
  const bool updated = UpdateProcThreadAttribute(attributes,0,PROC_THREAD_ATTRIBUTE_HANDLE_LIST,handles,sizeof(handles),nullptr,nullptr) != FALSE;
  std::wstring command = QuoteArg(exe); for (const auto& arg : args) command += L" " + QuoteArg(arg);
  STARTUPINFOEXW start{}; start.StartupInfo.cb = sizeof(start); start.StartupInfo.dwFlags = STARTF_USESTDHANDLES;
  start.StartupInfo.hStdInput = input.h; start.StartupInfo.hStdOutput = start.StartupInfo.hStdError = write.h; start.lpAttributeList = attributes;
  PROCESS_INFORMATION info{};
  bool interrupted = false;
  const bool created = updated && command.size() < 32767 && CreateProcessPolled([&] {
    return CreateProcessW(exe.c_str(),command.data(),nullptr,nullptr,TRUE,
      EXTENDED_STARTUPINFO_PRESENT | CREATE_NO_WINDOW | CREATE_SUSPENDED,nullptr,nullptr,&start.StartupInfo,&info);
  },poll,interrupted);
  DeleteProcThreadAttributeList(attributes);
  if (!created) { failure = "cannot start FFprobe"; return false; }
  process.h = info.hProcess; thread.h = info.hThread; job.h = CreateJobObjectW(nullptr,nullptr);
  if (interrupted) { TerminateProcess(process.h,1); WaitForSingleObject(process.h,2000); failure = "Caller stopped during FFprobe startup"; return false; }
  JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits{}; limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
  if (!job.h || !SetInformationJobObject(job.h,JobObjectExtendedLimitInformation,&limits,sizeof(limits)) || !AssignProcessToJobObject(job.h,process.h)) {
    TerminateProcess(process.h,1); WaitForSingleObject(process.h,2000); failure = "cannot own FFprobe"; return false;
  }
  if (ResumeThread(thread.h) == DWORD(-1)) { TerminateJobObject(job.h,1); WaitForSingleObject(process.h,2000); failure = "cannot resume FFprobe"; return false; }
  CloseHandle(write.h); write.h = nullptr;
  const auto started = GetTickCount64(); bool exited = false, ok = true;
  for (;;) {
    if (!poll() || GetTickCount64()-started >= timeout) { failure = "FFprobe cancelled/failed poll or timed out"; ok = false; break; }
    DWORD available = 0;
    if (!PeekNamedPipe(read.h,nullptr,0,nullptr,&available,nullptr)) {
      if (GetLastError() != ERROR_BROKEN_PIPE) { failure = "FFprobe output read failed"; ok = false; }
      break;
    }
    if (available) {
      char buffer[8192]; DWORD got = 0;
      if (!ReadFile(read.h,buffer,(std::min)(available,DWORD(sizeof(buffer))),&got,nullptr)) { failure = "FFprobe output read failed"; ok = false; break; }
      if (bytes.size()+got > VE_CORE_JSON_LIMIT) { failure = "FFprobe output exceeds 1 MiB"; ok = false; break; }
      bytes.append(buffer,got);
    } else if (exited) break;
    else WaitForSingleObject(process.h,20);
    exited = WaitForSingleObject(process.h,0) == WAIT_OBJECT_0;
  }
  if (!ok || WaitForSingleObject(process.h,0) != WAIT_OBJECT_0) TerminateJobObject(job.h,1);
  WaitForSingleObject(process.h,2000); DWORD code = STILL_ACTIVE; GetExitCodeProcess(process.h,&code);
  if (code != 0) { if (failure.empty()) failure = "FFprobe returned a failing exit code"; return false; }
  return ok;
}
ve::Json Verification(const std::string& state, const std::string& message) {
  return {{"state",state},{"message",message},{"expectedCodecs",ve::Json::array()},{"actualCodecs",ve::Json::array()},{"ffprobeVersion",nullptr}};
}
} // namespace
ve::Json VerifyProbe(const ve::Json& probe, const ve::Json& expected) {
  auto result = Verification("failed","FFprobe returned invalid or unreadable streams.");
  if (!probe.is_object() || !probe.contains("streams") || !probe.at("streams").is_array() || probe.at("streams").empty()) return result;
  if (probe.contains("program_version")) result["ffprobeVersion"] = ve::Str(probe.at("program_version"),"version");
  const auto& streams = probe.at("streams");
  if (expected.is_array()) for (const auto& fact : expected) if (!fact.at("codec").is_null()) result["expectedCodecs"].push_back(fact.at("codec"));
  std::vector<bool> matched(streams.size(),false);
  for (const auto& stream : streams) {
    const auto kind = ve::Str(stream,"codec_type"), codec = ve::Str(stream,"codec_name");
    if (codec.empty()) return result;
    result["actualCodecs"].push_back(codec);
    if (kind == "video") {
      if (ve::Num(stream,"width") <= 0 || ve::Num(stream,"height") <= 0) return result;
      const auto count = ve::Str(stream,"nb_read_frames");
      if (count.empty() || !std::all_of(count.begin(),count.end(),[](char c) { return c >= '0' && c <= '9'; }) || count.find_first_not_of('0') == std::string::npos) return result;
    } else if (kind != "audio" && expected.is_array()) return result;
  }
  if (expected.is_array()) {
    if (expected.size() != streams.size()) { result["message"] = "Output stream count differs from the core's expectedStreams."; return result; }
    for (const auto& fact : expected) {
      bool found = false;
      for (size_t i = 0; i < streams.size(); ++i) {
        if (matched[i] || ve::Str(streams[i],"codec_type") != ve::Str(fact,"kind")) continue;
        if (!fact.at("codec").is_null() && ve::Str(streams[i],"codec_name") != fact.at("codec").get<std::string>()) continue;
        matched[i] = true; found = true; break;
      }
      if (!found) { result["message"] = "Output kind/codec differs from the core's expectedStreams."; return result; }
    }
  }
  result["state"] = "passed"; result["message"] = expected.is_array() ?
    "FFprobe readback passed; stream kinds/count and known core codecs match." :
    "FFprobe readback passed; exact Advanced output scope is unknown to the core.";
  return result;
}
ve::Json LiveVideoFacts(const ve::Json& compiled) {
  ve::Json facts{{"outputBitDepth",nullptr},{"pixelFormatConversionReducesPrecision",nullptr}};
  if (!compiled.is_object() || !compiled.contains("issues") || !compiled.at("issues").is_array() ||
      ve::HasErrors(compiled.at("issues")) || !compiled.contains("expectedStreams") || !compiled.at("expectedStreams").is_array() ||
      !compiled.contains("summary") || !compiled.at("summary").is_object()) return facts;
  const auto encoder = ve::Str(compiled.at("summary"),"videoEncoderId");
  if (encoder.empty() || encoder == "copy") return facts;
  size_t videoStreams = 0;
  for (const auto& stream : compiled.at("expectedStreams")) if (ve::Str(stream,"kind") == "video") ++videoStreams;
  if (videoStreams != 1 || !compiled.contains("signalPath") || !compiled.at("signalPath").is_object()) return facts;
  const auto& signal = compiled.at("signalPath");
  if (!signal.contains("video") || !signal.at("video").is_object()) return facts;
  const auto& video = signal.at("video");
  if (!video.contains("outputBits") || !video.at("outputBits").is_number_integer() || video.at("outputBits").get<int64_t>() <= 0) return facts;
  facts["outputBitDepth"] = video.at("outputBits");
  // Filters can change precision inside the graph, even when its endpoints have
  // equal depths. Core marks that conversion unknown; retain the unknown here.
  if (video.contains("conversion") && video.at("conversion").is_boolean() && video.contains("inputBits") &&
      video.at("inputBits").is_number_integer() && video.at("inputBits").get<int64_t>() > 0)
    facts["pixelFormatConversionReducesPrecision"] = video.at("inputBits").get<int64_t>() > video.at("outputBits").get<int64_t>();
  return facts;
}
RecipeJob::RecipeJob() : parser_([this](const ve::Json& metrics) { Progress(metrics); }) {}
RecipeJob::~RecipeJob() { if (startedOnce_ && !terminal_) Stop(E_ABORT,"Job abandoned before completion."); }
bool RecipeJob::Start(const ve::Json& recipe, const ve::Json& media, const ve::Json& installation,
                      const ve::Json& capabilities, const ve::Json& origin, const RecipeJobOptions& options, const Poll& poll) {
  if (startedOnce_) return false;
  if (options.output.find(L'\0') != std::wstring::npos || options.jobsRoot.find(L'\0') != std::wstring::npos ||
      !std::filesystem::path(options.output).is_absolute() || !std::filesystem::path(options.jobsRoot).is_absolute()) {
    error_ = E_INVALIDARG; message_ = "Output and job root must be absolute paths."; return false;
  }
  options_ = options; recipe_ = recipe; media_ = media; installation_ = installation; origin_ = origin;
  // Malformed snapshots fail before a record is created; historical readers must
  // be able to validate all recorded snapshots, including failed domain recipes.
  if (ve::HasErrors(ve::Structural(recipe))) { error_ = E_INVALIDARG; message_ = "Malformed recipe snapshot."; return false; }
  try { ve::CheckMedia(media); }
  catch (const std::exception& e) { error_ = E_INVALIDARG; message_ = e.what(); return false; }
  startedOnce_ = true; id_ = NewJobId(); startedAt_ = JobUtcNow(); started_ = phaseStarted_ = GetTickCount64();
  verification_ = Verification("skipped","Encoder stopped before output verification.");
  live_ = {{"live",1},{"jobId",id_},{"hostHwnd",options.hostHwnd},{"sequence",0},{"updatedAt",startedAt_},{"state","starting"},
    {"framesDone",0},{"framesTotal",media.at("video").value("frames",ve::Json(nullptr))},{"encodeFps",nullptr},{"speed",nullptr},{"bitrateKbps",nullptr},
    {"bytesWritten",0},{"elapsedSec",0},{"etaSec",nullptr},{"estimatedFinalBytes",nullptr},{"outputPath",Utf8(options.output.c_str())},
    {"templateName",options.templateName},{"encoderSummary",""},{"outputBitDepth",nullptr},{"pixelFormatConversionReducesPrecision",nullptr},
    {"message","Preparing encoder."},{"ffmpegExitCode",nullptr}};
  std::wstring log = options.output + L".ffmpeg.log";
  try {
    std::filesystem::create_directories(options.jobsRoot);
    log = options.jobsRoot + L"\\" + Widen(id_) + L".ffmpeg.log";
  } catch (const std::exception& e) { Log("job log root unavailable: %s",e.what()); }
  try { store_ = JobStore::Create(options.jobsRoot,id_,options.monitorApplication); store_->Status(live_,true); }
  catch (const std::exception& e) { Log("job status writer unavailable (nonfatal): %s",e.what()); }
  try {
    if (!Check(poll)) { Stop(error_,message_,cancelled_); return false; }
    if (!AbsoluteExe(ve::Str(installation,"path")) || (options.verifyOutput && !AbsoluteExe(ve::Str(installation,"ffprobePath"))))
      throw std::runtime_error("Selected FFmpeg/FFprobe must have absolute executable paths.");
    // Exact selected executable/shared DLL identities are retained. Refuse changed
    // bytes instead of silently running another installation or probing on Render.
    const auto& identity = installation.at("identity");
    auto hash = [&](const std::wstring& file) { return Sha256File(file,[&] { return Check(poll); }); };
    if (!SameHash(ve::Str(identity,"sha256"),hash(Widen(ve::Str(installation,"path"))))) throw std::runtime_error("Selected FFmpeg identity changed.");
    if (identity.contains("libraries")) for (auto it = identity.at("libraries").begin(); it != identity.at("libraries").end(); ++it) {
      if (it.key().find_first_of("/\\:") != std::string::npos || it.key() == "." || it.key() == "..") throw std::runtime_error("Invalid shared library identity path.");
      const auto file = std::filesystem::path(Widen(ve::Str(installation,"path"))).parent_path() / Widen(it.key());
      if (!SameHash(it.value().get<std::string>(),hash(file.wstring()))) throw std::runtime_error("Selected shared library identity changed.");
    }
    const auto ext = installation.value("extensions",ve::Json::object());
    const auto probeHash = ext.contains("ffprobeIdentity") ? ve::Str(ext.at("ffprobeIdentity"),"sha256") : std::string();
    if (options.verifyOutput && !SameHash(probeHash,hash(Widen(ve::Str(installation,"ffprobePath")))))
      throw std::runtime_error("Selected FFprobe identity changed or unknown.");
    const bool ok = encoder_.StartCompiled(Widen(ve::Str(installation,"path")), options.output,log,options.pipeTimeoutMs,options.finishTimeoutMs,
      [&](const std::wstring& video, const std::wstring& audio, const std::wstring& temp) {
        const ve::Json paths{{"ffmpeg",installation.at("path")},{"videoPipe",Utf8(video.c_str())},{"audioPipe",Utf8(audio.c_str())},
          {"output",Utf8(temp.c_str())},{"project",options.project},{"liveInputs",true},{"overwriteOutput",true}};
        compiled_ = ve::Compile({{"recipe",recipe},{"media",media},{"paths",paths},{"capabilities",capabilities}});
        const auto& summary = compiled_.at("summary");
        { std::lock_guard<std::mutex> lock(liveMutex_); live_["encoderSummary"] = ve::Str(summary,"video") + " / " + ve::Str(summary,"audio"); }
        if (ve::HasErrors(compiled_.at("issues"))) throw std::runtime_error("Core validation refused this render recipe.");
        if (!options.requiredOutputContainerId.empty() && compiled_.value("outputContainerId",ve::Json(nullptr)) != options.requiredOutputContainerId)
          throw std::runtime_error("This VEGAS candidate requires Matroska (.mkv). Choose Matroska or explicit -f matroska in Advanced mode.");
        if (options.requiredVideoOutput && (!compiled_.at("expectedStreams").is_array() ||
            std::none_of(compiled_.at("expectedStreams").begin(),compiled_.at("expectedStreams").end(),[](const ve::Json& stream) { return ve::Str(stream,"kind") == "video"; })))
          throw std::runtime_error("This VEGAS candidate requires an established video output; general maps/filters and audio-only commands are not supported yet.");
        const auto videoFacts = LiveVideoFacts(compiled_);
        { std::lock_guard<std::mutex> lock(liveMutex_);
          for (auto it = videoFacts.begin(); it != videoFacts.end(); ++it) live_[it.key()] = it.value();
        }
        FfmpegEncoder::CommandPlan plan;
        for (const auto& arg : compiled_.at("argv")) plan.argv.push_back(Widen(arg.get<std::string>()));
        const auto& inputs = compiled_.at("inputStreams"); plan.audioInput = std::find(inputs.begin(),inputs.end(),ve::Json("audio")) != inputs.end();
        return plan;
      },[this](const char* bytes, size_t count) { parser_.Feed(bytes,count); },[&] { return Check(poll); });
    if (!ok) { Stop(encoder_.Error(),encoder_.Reason()); return false; }
    Phase("encoding","Encoding."); return true;
  } catch (const std::exception& e) {
    Stop(FAILED(error_) ? error_ : E_FAIL,FAILED(error_) ? message_ : e.what(),cancelled_); return false;
  }
}
bool RecipeJob::Check(const Poll& poll) {
  const auto control = poll();
  if (control.cancelled || FAILED(control.hresult)) {
    error_ = FAILED(control.hresult) ? control.hresult : E_ABORT; cancelled_ = control.cancelled;
    message_ = cancelled_ ? "Render cancelled by the host." : "Host progress failed."; return false;
  }
  return true;
}
bool RecipeJob::Submit(bool audio, std::vector<BYTE> bytes, const Poll& poll) {
  if (terminal_ || !startedOnce_) return false;
  if (encoder_.Submit(audio,std::move(bytes),[&] { return Check(poll); })) return true;
  Stop(FAILED(error_) ? error_ : encoder_.Error(),message_.empty() ? encoder_.Reason() : message_,cancelled_); return false;
}
void RecipeJob::Progress(const ve::Json& metrics) {
  std::lock_guard<std::mutex> lock(liveMutex_);
  if (live_.is_null() || (ve::Str(live_,"state") != "encoding" && ve::Str(live_,"state") != "finishing")) return;
  for (auto it = metrics.begin(); it != metrics.end(); ++it) {
    if ((it.key() == "framesDone" || it.key() == "bytesWritten") && it.value().is_null()) continue;
    live_[it.key()] = it.value();
  }
  const double elapsed = (GetTickCount64()-started_)/1000.0;
  live_["elapsedSec"] = elapsed; live_["updatedAt"] = JobUtcNow(); live_["sequence"] = live_["sequence"].get<int64_t>()+1;
  live_["etaSec"] = nullptr; live_["estimatedFinalBytes"] = nullptr;
  const double duration = ve::Num(media_,"durationSec"); const double speed = ve::Num(live_,"speed");
  if (duration > 0 && speed > 0) {
    live_["etaSec"] = (std::max)(0.0,duration/speed-elapsed);
    if (elapsed > 0) {
      const double estimate = ve::Num(live_,"bytesWritten") * duration / speed / elapsed;
      if (std::isfinite(estimate) && estimate >= 0 && estimate < 9.22e18) live_["estimatedFinalBytes"] = static_cast<int64_t>(estimate);
    }
  }
  if (store_) store_->Status(live_,false);
}
void RecipeJob::Phase(const std::string& state, const std::string& message) {
  std::lock_guard<std::mutex> lock(liveMutex_); const auto now = GetTickCount64();
  timings_[ve::Str(live_,"state")] = (now-phaseStarted_)/1000.0; phaseStarted_ = now;
  live_["state"] = state; live_["message"] = message; live_["elapsedSec"] = (now-started_)/1000.0;
  live_["updatedAt"] = JobUtcNow(); live_["sequence"] = live_["sequence"].get<int64_t>()+1;
  live_["etaSec"] = nullptr; live_["estimatedFinalBytes"] = nullptr;
  if (store_ && state != "done" && state != "failed" && state != "cancelled") store_->Status(live_,true);
}
bool RecipeJob::Verify(const Poll& poll) {
  if (!options_.verifyOutput) { verification_ = Verification("skipped","Output verification explicitly disabled by machine settings."); return true; }
  Phase("verifying","Checking encoded output.");
  std::string bytes, failure;
  const auto stats = encoder_.Stats();
  const bool ok = ProbeChild(Widen(ve::Str(installation_,"ffprobePath")),
    {L"-v",L"error",L"-count_frames",L"-show_entries",L"program_version=version:stream=codec_type,codec_name,width,height,nb_read_frames:format=duration",
     L"-show_program_version",L"-of",L"json",stats.tempPath}, options_.probeTimeoutMs,[&] { return Check(poll); },bytes,failure);
  if (!ok) { verification_ = Verification("failed",failure); return false; }
  try { verification_ = VerifyProbe(ve::Parse(reinterpret_cast<const uint8_t*>(bytes.data()),bytes.size()),compiled_.at("expectedStreams")); }
  catch (const std::exception& e) { verification_ = Verification("failed",std::string("Invalid FFprobe readback: ")+e.what()); }
  return ve::Str(verification_,"state") == "passed";
}
bool RecipeJob::Finish(const Poll& poll) {
  if (terminal_ || !startedOnce_) return false;
  Phase("finishing","Waiting for encoder completion.");
  if (!encoder_.Finish([&] { return Check(poll); },false)) {
    Stop(FAILED(error_) ? error_ : encoder_.Error(),message_.empty() ? encoder_.Reason() : message_,cancelled_); return false;
  }
  if (!Verify(poll)) {
    // Verification failures retain only this uniquely owned partial for inspection;
    // cancelled probes remove it, and nothing reaches the final destination.
    if (!cancelled_) encoder_.RetainPartial();
    Stop(FAILED(error_) ? error_ : E_FAIL,message_.empty() ? ve::Str(verification_,"message") : message_,cancelled_); return false;
  }
  if (!Check(poll)) { Stop(error_,message_,cancelled_); return false; }
  if (!encoder_.Publish()) { Stop(encoder_.Error(),encoder_.Reason()); return false; }
  message_ = "Render completed."; Complete(true); return true;
}
void RecipeJob::Stop(HRESULT hresult, const std::string& message, bool cancelled) {
  if (terminal_ || !startedOnce_) return;
  error_ = FAILED(hresult) ? hresult : E_FAIL; message_ = message; cancelled_ = cancelled;
  encoder_.Abort(); Complete(false);
}
void RecipeJob::Complete(bool success) {
  if (terminal_) return; terminal_ = true;
  const auto stats = encoder_.Stats(); const auto state = success ? "done" : cancelled_ ? "cancelled" : "failed";
  Phase(state,message_);
  const double elapsed = (GetTickCount64()-started_)/1000.0;
  const auto stderrTail = Tail(stats.stderrPath);
  ve::Json indices = ve::ErrorTokenIndices(compiled_,stderrTail);
  if (compiled_.contains("issues")) for (const auto& issue : compiled_.at("issues")) {
    if (ve::Str(issue,"level") != "error") continue;
    for (const auto& index : issue.at("tokenIndices")) {
      const auto displayIndex = index.get<size_t>();
      if (displayIndex && std::find(indices.begin(),indices.end(),ve::Json(displayIndex-1)) == indices.end()) indices.push_back(displayIndex-1);
    }
  }
  uint64_t size = 0; WIN32_FILE_ATTRIBUTE_DATA attrs{};
  if (success && GetFileAttributesExW(options_.output.c_str(),GetFileExInfoStandard,&attrs)) size = (uint64_t(attrs.nFileSizeHigh)<<32)|attrs.nFileSizeLow;
  const auto retained = !success && GetFileAttributesW(stats.tempPath.c_str()) != INVALID_FILE_ATTRIBUTES ? ve::Json(Utf8(stats.tempPath.c_str())) : ve::Json(nullptr);
  std::lock_guard<std::mutex> lock(liveMutex_);
  live_["ffmpegExitCode"] = stats.pid && stats.exitCode != STILL_ACTIVE ? ve::Json(static_cast<int32_t>(stats.exitCode)) : ve::Json(nullptr);
  record_ = {{"job",1},{"id",id_},{"startedAt",startedAt_},{"endedAt",JobUtcNow()},{"project",options_.project},
    {"templateName",options_.templateName},{"outputPath",Utf8(options_.output.c_str())},{"status",success ? "succeeded" : cancelled_ ? "cancelled" : "failed"},
    {"recipe",recipe_},{"origin",origin_},{"recipeSha256",RecipeHash(recipe_)},{"media",media_},{"ffmpeg",installation_},
    {"argv",compiled_.value("argv",ve::Json::array())},{"elapsedSec",elapsed},{"sizeBytes",size},{"avgFps",live_["encodeFps"]},
    {"ffmpegExitCode",live_["ffmpegExitCode"]},{"hresult",Hr(success ? S_OK : error_)},{"message",message_},{"stderrTail",stderrTail},
    {"verification",verification_},{"timings",timings_},{"published",success},{"retainedPartialPath",retained},
    {"commandLine",compiled_.value("commandLine",ve::Json(nullptr))},{"encoderSummary",live_["encoderSummary"]},
    {"logFile",stats.stderrPath == options_.jobsRoot + L"\\" + Widen(id_) + L".ffmpeg.log" ? ve::Json(id_ + ".ffmpeg.log") : ve::Json(nullptr)},
    {"durationSec",media_.value("durationSec",ve::Json(nullptr))},{"realtime",live_["speed"]},{"errorTokenIndices",indices}};
  if (store_) store_->Complete(live_,record_);
}
} // namespace vegas_encoder
