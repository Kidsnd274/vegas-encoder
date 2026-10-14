// Fake-host recipe qualification. No installed exporter/VEGAS or user state.
#include "../../src/engine/recipe_job.h"
#include "../../src/vegas/host/frame_lease.h"
#include "../../src/support/diagnostics.h"
#include "../fiohost/fakehost.h"
#include <psapi.h>
#include <algorithm>
#include <atomic>
#include <cmath>
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <thread>

using namespace vegas_encoder;
using ve::Json;
using namespace sfio;
namespace {
int checks = 0;
#if defined(VE_B4_ASAN)
constexpr bool instrumented = true;
#else
constexpr bool instrumented = false;
#endif
Json installationSnapshots = Json::array();
void Require(bool ok, const char* message) { ++checks; if (!ok) throw std::runtime_error(message); }
Json Read(const std::wstring& path) {
  std::ifstream file(std::filesystem::path(path),std::ios::binary);
  const std::string bytes((std::istreambuf_iterator<char>(file)),{});
  return ve::Parse(reinterpret_cast<const uint8_t*>(bytes.data()),bytes.size());
}
void Save(const std::wstring& path, const Json& json) { std::ofstream file{std::filesystem::path(path)}; file << json.dump(2); }
std::wstring Self() { wchar_t path[32768]; GetModuleFileNameW(nullptr,path,32768); return path; }
Json Installation(const std::wstring& exe, const std::wstring& probe = {}) {
  for (const auto& snapshot : installationSnapshots) if (_wcsicmp(Widen(ve::Str(snapshot,"path")).c_str(),exe.c_str()) == 0) {
    auto result = snapshot;
    if (!probe.empty()) { result["ffprobePath"] = Utf8(probe.c_str()); result["extensions"]["ffprobeIdentity"] = {{"sha256",Sha256File(probe)}}; }
    return result;
  }
  const auto ffprobe = probe.empty() ? (std::filesystem::path(exe).parent_path()/L"ffprobe.exe").wstring() : probe;
  Json libraries = Json::object();
  for (const auto& entry : std::filesystem::directory_iterator(std::filesystem::path(exe).parent_path())) {
    const auto name = entry.path().filename().string();
    if (name.size() > 4 && entry.path().extension() == L".dll" && (name.rfind("av",0) == 0 || name.rfind("sw",0) == 0 || name.rfind("postproc",0) == 0)) libraries[name] = Sha256File(entry.path().wstring());
  }
  const auto hash = Sha256File(exe);
  return {{"id",hash.substr(0,12)},{"label","B4 supplied Windows test installation"},{"path",Utf8(exe.c_str())},{"ffprobePath",Utf8(ffprobe.c_str())},
    {"source","manual"},{"version","B4 controlled installation fixture"},{"isFixture",true},
    {"identity",{{"sha256",hash},{"key",hash},{"libraries",libraries}}},
    {"extensions",{{"ffprobeIdentity",{{"sha256",Sha256File(ffprobe)}}}}}};
}
void WaitStore(const std::shared_ptr<JobStore>& store) {
  const auto started = GetTickCount64(); while (store && !store->Completed() && GetTickCount64()-started < 7000) Sleep(10);
  Require(store && store->Completed(),"asynchronous record writer completed within 7 s");
}
Json metrics = Json::array();
void PureChecks() {
  ProgressParser parser([](const Json& metric) { metrics.push_back(metric); });
  const std::string progress = "frame=42\r\nfps=61.8\nspeed=2.06x\nbitrate=30700.0kbits/s\ntotal_size=123456\nunknown=ignored\nprogress=continue\n";
  for (auto c : progress) parser.Feed(&c,1);
  Require(metrics.size() == 1 && metrics[0]["framesDone"] == 42,"fragmented progress record");
  Require(metrics[0]["encodeFps"] == 61.8 && metrics[0]["speed"] == 2.06,"numeric progress");
  Require(metrics[0]["bitrateKbps"] == 30700 && metrics[0]["bytesWritten"] == 123456,"size/bitrate units");
  const std::string invalid = "frame=-1\nfps=nan\nspeed=inf\nbitrate=N/A\ntotal_size=99999999999999999999999\nprogress=end\n";
  parser.Feed(invalid.data(),invalid.size());
  Require(metrics.size() == 2 && metrics[1]["framesDone"].is_null() && metrics[1]["encodeFps"].is_null() && metrics[1]["speed"].is_null(),"nonfinite/negative metrics unknown");
  Require(metrics[1]["bytesWritten"].is_null() && metrics[1]["bitrateKbps"].is_null(),"overflow/N-A metrics unknown");
  const std::string huge(1024*1024,'a'); parser.Feed(huge.data(),huge.size());
  Require(parser.Buffered() <= 4096,"progress no-newline allocation bounded");
  const std::string recovery = "\nframe=9\nprogress=continue\n"; parser.Feed(recovery.data(),recovery.size());
  Require(metrics.back()["framesDone"] == 9,"oversized progress line recovery");
  Json expected = Json::array({{{"kind","video"},{"codec","ffv1"}},{{"kind","audio"},{"codec","pcm_f32le"}}});
  Json probe{{"streams",Json::array({{{"codec_type","video"},{"codec_name","ffv1"},{"width",320},{"height",180},{"nb_read_frames","60"}},{{"codec_type","audio"},{"codec_name","pcm_f32le"}}})}};
  Require(VerifyProbe(probe,expected)["state"] == "passed","probe matches core facts");
  auto changed = probe; changed["streams"][0]["codec_name"] = "h264";
  Require(VerifyProbe(changed,expected)["state"] == "failed","codec mismatch refuses publication");
  changed = probe; changed["streams"].erase(1);
  Require(VerifyProbe(changed,expected)["state"] == "failed","missing stream refuses publication");
  changed = probe; changed["streams"].push_back(probe["streams"][1]);
  Require(VerifyProbe(changed,expected)["state"] == "failed","duplicate stream refuses publication");
  changed = probe; changed["streams"][0]["nb_read_frames"] = "0";
  Require(VerifyProbe(changed,expected)["state"] == "failed","unreadable video refuses publication");
  expected[0]["codec"] = nullptr;
  Require(VerifyProbe(probe,expected)["state"] == "passed","unknown codec remains unknown");
  Require(VerifyProbe(probe,nullptr)["state"] == "passed","unknown Advanced scope readback is explicit");
  Require(RecipeHash(Json{{"b",2},{"a",1}}) == RecipeHash(Json{{"a",1},{"b",2}}),"canonical recipe hash order");
  const Json compiled{{"argv",Json::array({"-i","input","-wrong","3","out"})}};
  Require(ve::ErrorTokenIndices(compiled,"Unrecognized option 'wrong'.") == Json::array({2}),"runtime argv indexes exclude executable");
  Require(ve::ErrorTokenIndices(compiled,"generic encoder failure").empty(),"unknown error provenance stays empty");
}
struct Case {
  std::string name;
  Json recipe, installation;
  int width = 320,height = 180,frames = 60;
  EncodeRate rate{30000,1001};
  LONGLONG cancelAt = -1; int failureSlot = 0;
  bool success = true, verify = true, blockedIndex = false, blockedLive = false, collision = false;
  bool cancelDuringProbe = false, timedCancel = false, invalidRoot = false;
  DWORD pipeTimeout = 3000, probeTimeout = 3000;
};
Json Run(const Case& test, const std::wstring& root) {
  const auto path = root + L"\\" + Widen(test.name); std::filesystem::create_directories(path);
  RecipeJobOptions options; options.output = path + L"\\output.mkv"; options.jobsRoot = root + L"\\jobs";
  options.templateName = test.name; options.project = "B4 synthetic fake-host recipe"; options.verifyOutput = test.verify;
  options.hostHwnd = "123456";
  // ASan child initialization/instrumented sleeps use the product's normal pipe
  // bound. Deliberate short timeout cases retain their explicit bounds.
  options.pipeTimeoutMs = instrumented && test.pipeTimeout >= 3000 ? 10000 : test.pipeTimeout;
  options.probeTimeoutMs = test.probeTimeout;
  options.finishTimeoutMs = instrumented ? 30000 : 5000;
  std::filesystem::create_directories(options.jobsRoot);
  if (test.invalidRoot) { options.jobsRoot = path + L"\\root-is-file"; std::ofstream file(std::filesystem::path(options.jobsRoot)); file << "blocked"; }
  Json media{{"video",{{"width",test.width},{"height",test.height},{"fps",Json::array({test.rate.num,test.rate.den})},{"pixfmt","p010le"},{"sar","1:1"},{"frames",test.frames}}},
    {"audio",{{"rate",48000},{"channels",2},{"sampleFmt","f32le"}}},{"durationSec",double(test.frames)*test.rate.den/test.rate.num}};
  const bool withAudio = test.recipe["audio"][0]["enabled"].get<bool>();
  if (!withAudio) media["audio"] = nullptr;
  RenderTestOptions host; host.width = test.width; host.height = test.height; host.frames = test.frames;
  host.fps = double(test.rate.num)/test.rate.den; host.cancelAt = test.cancelAt; host.progressFailureSlot = test.failureSlot;
  host.progressFailureAt = 15; host.videoOnly = !withAudio; host.shortRead = 257;
  LONGLONG held = 0, samples = 0, endpoint = 0; int repolls = 0;
  ULONGLONG pollAt = GetTickCount64(), maxPollGap = 0, abortMs = 0;
  const auto began = GetTickCount64(); RecipeJob job; ULONGLONG probeBegan = 0;
  HANDLE indexLock = INVALID_HANDLE_VALUE, liveHandle = INVALID_HANDLE_VALUE; OVERLAPPED overlap{};
  if (test.blockedIndex) {
    indexLock = CreateFileW((options.jobsRoot+L"\\jobs.jsonl.lock").c_str(),GENERIC_READ|GENERIC_WRITE,FILE_SHARE_READ|FILE_SHARE_WRITE,nullptr,OPEN_ALWAYS,0,nullptr);
    Require(indexLock != INVALID_HANDLE_VALUE && LockFileEx(indexLock,LOCKFILE_EXCLUSIVE_LOCK,0,1,0,&overlap),"index lock held");
  }
  PROCESS_MEMORY_COUNTERS memory{}; memory.cb = sizeof(memory); GetProcessMemoryInfo(GetCurrentProcess(),&memory,sizeof(memory));
  const auto baseline = memory.WorkingSetSize;
  std::atomic<bool> monitoring{true}; std::atomic<size_t> peak{baseline};
  std::thread monitor([&] { while (monitoring) {
    PROCESS_MEMORY_COUNTERS current{}; current.cb=sizeof(current); if (GetProcessMemoryInfo(GetCurrentProcess(),&current,sizeof(current))) peak = (std::max)(peak.load(),current.WorkingSetSize); Sleep(10);
  }});
  struct MonitorGuard { std::atomic<bool>& flag; std::thread& worker; ~MonitorGuard() { flag=false; if (worker.joinable()) worker.join(); } } guard{monitoring,monitor};
  const auto result = ExerciseRecipeHost(host,[&](ISfReadVideoRenderStream* video, ISfReadAudioStream* audio, ISfProgress* progress) {
    progress->SetTotal(test.frames);
    LONGLONG position = 0;
    auto poll = [&]() -> JobControl {
      Require(held == 0,"host frame released before every wait/poll");
      const auto now = GetTickCount64(); maxPollGap = (std::max)(maxPollGap,now-pollAt); pollAt = now; ++repolls;
      const auto current = test.cancelDuringProbe ? job.LiveStatus() : Json(nullptr);
      if (current.is_object() && current.value("state",std::string()) == "verifying") {
        if (!probeBegan) probeBegan = now;
        if (now-probeBegan >= 100) return {SF_E_RENDER_STOPPED,true};
      }
      if (test.timedCancel && now-began >= 250) return {SF_E_RENDER_STOPPED,true};
      HRESULT hr = progress->SetPosition(position);
      if (hr == SF_E_PROGRESS_CANCELLED) return {SF_E_RENDER_STOPPED,true};
      if (FAILED(hr)) return {hr,false};
      hr = progress->CheckCancel(); return {hr,false};
    };
    for (position = 0; position < test.frames; ++position) {
      const auto control = poll(); if (FAILED(control.hresult)) { const auto at = GetTickCount64(); job.Stop(control.hresult,"Host stopped before next frame.",control.cancelled); abortMs=GetTickCount64()-at; return control.hresult; }
      SFMEMORYTOKEN token{}; LONG_PTR lock = 0; BYTE info[frameinfo::size]{}; LONG count = 0;
      Require(SUCCEEDED(video->GetRenderFrame(position,&token,&lock,info,&count)),"fake host acquisition");
      host::FrameLease lease(video,lock,held);
      std::vector<BYTE> frame(static_cast<size_t>(test.width)*test.height*3);
      DWORD planes[3]{}; memcpy(planes,info+frameinfo::planeFields,sizeof(planes));
      const auto* source = reinterpret_cast<const BYTE*>(static_cast<uintptr_t>(token.pData+token.offset));
      for (int row = 0; row < test.height; ++row) memcpy(frame.data()+size_t(row)*test.width*2,source+size_t(row)*planes[0],size_t(test.width)*2);
      for (int row = 0; row < test.height/2; ++row) memcpy(frame.data()+size_t(test.width)*test.height*2+size_t(row)*test.width*2,source+planes[1]+size_t(row)*planes[2],size_t(test.width)*2);
      Require(SUCCEEDED(lease.Release()) && held == 0,"release copied host frame before Start/Submit");
      if (position == 0) {
        if (!job.Start(test.recipe,media,test.installation,nullptr,nullptr,options,poll)) return job.Error();
        if (test.blockedLive) {
          const auto live = options.jobsRoot+L"\\"+Widen(job.Id())+L".live.json";
          const auto until = GetTickCount64()+1000;
          while (GetFileAttributesW(live.c_str()) == INVALID_FILE_ATTRIBUTES && GetTickCount64()<until) Sleep(5);
          liveHandle=CreateFileW(live.c_str(),GENERIC_READ,FILE_SHARE_READ,nullptr,OPEN_EXISTING,0,nullptr);
          Require(liveHandle != INVALID_HANDLE_VALUE,"live reader deliberately denies delete sharing");
          pollAt=GetTickCount64();
        }
        if (test.collision) { std::ofstream file(std::filesystem::path(options.output)); file << "sentinel"; }
      }
      if (!job.Submit(false,std::move(frame),poll)) return job.Error();
      if (audio) {
        Require(test.rate.Endpoint(position+1,48000,endpoint),"rational audio endpoint");
        while (samples < endpoint) {
          const LONG want = static_cast<LONG>((std::min)(endpoint-samples,LONGLONG(4096)));
          std::vector<BYTE> buffer(size_t(want)*8); SFMEMORYTOKEN out{}; out.pData=reinterpret_cast<ULONGLONG>(buffer.data());
          out.cbData=out.cbAlloc=want*8; out.pid=GetCurrentProcessId(); LONG got = 0;
          Require(SUCCEEDED(audio->Read(samples,&out,want,&got)) && got>0 && got<=want,"short/final S_FALSE audio read");
          buffer.resize(size_t(got)*8); if (!job.Submit(true,std::move(buffer),poll)) return job.Error(); samples += got;
        }
      }
    }
    const auto at = GetTickCount64(); const bool done = job.Finish(poll); abortMs=GetTickCount64()-at;
    return done ? S_OK : job.Error();
  });
  monitoring=false; monitor.join();
  const auto duration = GetTickCount64()-began;
  if (liveHandle != INVALID_HANDLE_VALUE) CloseHandle(liveHandle);
  if (indexLock != INVALID_HANDLE_VALUE) { UnlockFileEx(indexLock,0,1,0,&overlap); CloseHandle(indexLock); }
  if ((result.returned == S_OK) != test.success) {
    WaitStore(job.Store()); fprintf(stderr,"%s: %s\n%s\n",test.name.c_str(),job.Reason().c_str(),job.Compiled().dump().c_str());
  }
  Require((result.returned == S_OK) == test.success,"expected render outcome");
  Require(result.served == result.released && !result.outstanding && !result.lockErrors && !result.callerThreadErrors && !result.tokenErrors,"fake host lifetime/caller thread");
  const auto stats = job.Stats();
  Require(stats.videoHighWater <= 64u*1024*1024 && stats.audioHighWater <= 2u*1024*1024,"bounded in-flight pipe queues");
  Require(peak.load() <= baseline+160u*1024*1024,"parent additional working set under 160 MiB");
  // Identity hashing/start are not transport polling. First startup poll interval
  // is tracked separately; wait-time polls must remain responsive below 250 ms.
  Require(duration < (instrumented ? 45000u : 15000u),"focused job timing budget");
  // Sanitized /Od core initialization is not a release performance measurement.
  Require(maxPollGap < (instrumented ? 2000u : 250u),"caller progress polling gap budget");
  Require(job.Record()["published"] == test.success,"terminal publication fact");
  Require(job.Record()["recipeSha256"] == RecipeHash(test.recipe),"canonical recorded recipe hash");
  if (test.success) {
    Require(stats.published && stats.exitCode == 0 && job.Record()["sizeBytes"] > 0,"success means exit/output publication");
    Require(!withAudio || samples == endpoint,"cumulative fractional samples exact");
    Require(stats.videoBytes == uint64_t(test.frames)*test.width*test.height*3 && stats.audioBytes == uint64_t(samples)*8,"every owned frame/sample byte reaches input EOF");
  } else {
    Require(!stats.published && job.Record()["sizeBytes"] == 0,"stopped job never publishes bytes");
    if (test.cancelAt >= 0 || test.timedCancel || test.cancelDuringProbe) Require(job.Record()["status"] == "cancelled","cancellation remains distinct");
    if (test.failureSlot) Require(job.Record()["status"] == "failed" && job.Error() == E_ACCESSDENIED,"host failure HRESULT preserved");
    if (test.collision) { std::ifstream file(std::filesystem::path(options.output)); std::string text; file>>text; Require(text=="sentinel","destination created during render preserved"); }
    if (test.name == "child-exit") Require(!job.Record()["errorTokenIndices"].empty(),"native runtime error provenance recorded");
    if (test.name == "probe-mismatch" || test.name == "probe-malformed" || test.name == "probe-limit" || test.name == "probe-timeout")
      Require(!job.Record()["retainedPartialPath"].is_null(),"failed verification retains explicit unique partial");
  }
  if (test.timedCancel) Require(duration < 3000,"blocked-pipe cancellation under 3 s");
  if (test.cancelDuringProbe) Require(probeBegan && job.Record()["verification"]["state"] == "failed" && job.Record()["retainedPartialPath"].is_null(),"cancel during actual probe reaps child/removes partial");
  if (test.blockedIndex || test.blockedLive) Require(duration < 3000,"publication cannot hold Render behind file readers");
  WaitStore(job.Store());
  if (!test.invalidRoot && !test.blockedLive) Require(job.Store()->Failure().empty(),"record/live/index writer succeeded");
  if (!test.invalidRoot) {
    const auto record=Read(options.jobsRoot+L"\\"+Widen(job.Id())+L".json"); Require(record==job.Record(),"atomic record equals immutable job");
    const auto live=Read(options.jobsRoot+L"\\"+Widen(job.Id())+L".live.json"); Require(live["state"]==(test.success ? "done" : job.Record()["status"]),"terminal live state matches outcome");
    Require(live["hostHwnd"]=="123456" && live["sequence"].get<int64_t>()>0,"C5 placement/sequence facts");
  } else Require(!job.Store()->Failure().empty(),"status publication failure nonfatal");
  Json summary{{"case",test.name},{"id",job.Id()},{"success",test.success},{"elapsedMs",duration},{"polls",repolls},{"maxPollGapMs",maxPollGap},
    {"finishOrAbortMs",abortMs},{"workingSetGrowth",peak.load()-baseline},{"videoHighWater",stats.videoHighWater},{"audioHighWater",stats.audioHighWater},
    {"videoBytes",stats.videoBytes},{"audioBytes",stats.audioBytes},{"samples",samples},{"rate",Json::array({test.rate.num,test.rate.den})}};
  Save(path+L"\\summary.json",summary); printf("PASS %s: %llu ms, video queue %llu, audio queue %llu\n",test.name.c_str(),duration,stats.videoHighWater,stats.audioHighWater);
  return summary;
}
int Child(int argc, wchar_t** argv) {
  std::wstring mode, output; std::vector<std::wstring> inputs;
  bool probe = false;
  for (int i=1;i<argc;++i) {
    if (std::wstring(argv[i]) == L"-b4-fixture" && i+1<argc) mode=argv[++i];
    else if (std::wstring(argv[i]) == L"-count_frames") probe=true;
    else if (std::wstring(argv[i]) == L"-i" && i+1<argc) inputs.emplace_back(argv[++i]);
  }
  if (mode.empty() && !probe) return -1;
  output=argv[argc-1];
  if (probe) {
    if (output.find(L"probe-timeout")!=std::wstring::npos || output.find(L"probe-cancel")!=std::wstring::npos) { Sleep(20000); return 0; }
    if (output.find(L"probe-limit")!=std::wstring::npos) { const std::string bytes(2*1024*1024,'a'); fwrite(bytes.data(),1,bytes.size(),stdout); return 0; }
    if (output.find(L"probe-malformed")!=std::wstring::npos) { puts("{broken-json"); return 0; }
    puts("{\"streams\":[{\"codec_type\":\"video\",\"codec_name\":\"wrong\",\"width\":320,\"height\":180,\"nb_read_frames\":\"60\"}]}"); return 0;
  }
  if (mode == L"exit") { fputs("Unrecognized option 'b4-fixture'.\n",stderr); return 9; }
  if (mode == L"hold") { Sleep(20000); return 0; }
  std::vector<std::thread> readers;
  for (const auto& input : inputs) readers.emplace_back([input] {
    HANDLE pipe = CreateFileW(input.c_str(),GENERIC_READ,0,nullptr,OPEN_EXISTING,0,nullptr);
    char bytes[32768]; DWORD got=0;
    while (ReadFile(pipe,bytes,sizeof(bytes),&got,nullptr) && got) Sleep(5);
    CloseHandle(pipe);
  });
  for (auto& reader : readers) reader.join();
  std::ofstream file{std::filesystem::path(output)}; file << "owned synthetic output"; file.close();
  puts("frame=60\nfps=30.0\nspeed=1.0x\ntotal_size=22\nbitrate=1.0kbits/s\nprogress=end"); return 0;
}
} // namespace
int wmain(int argc, wchar_t** argv) {
  const int child = Child(argc,argv); if (child >= 0) return child;
  try {
    Require(argc>=4,"usage recipe-jobs <fixtures> <fresh-output-root> <ffmpeg> [ffmpeg...]");
    CoInitializeEx(nullptr,COINIT_MULTITHREADED); PureChecks();
    const auto fixtures=Read(argv[1]); const auto root=std::filesystem::absolute(argv[2]).wstring();
    Require(!std::filesystem::exists(root),"fresh output root required"); std::filesystem::create_directories(root);
    Json summaries=Json::array(); Json base=fixtures["fixtures"][0]["recipe"];
    base["container"]={{"format","mkv"},{"faststart",false}}; base["video"]["encoder"]="ffv1"; base["video"]["mode"]="lossless";
    base["video"]["depth"]=10; base["video"]["profile"]=nullptr; base["video"]["speed"]=nullptr;
    base["audio"][0]["encoder"]="pcm_f32le"; base["audio"][0]["mode"]="lossless";
    int firstBuild = 3;
    if (argc > 5 && std::wstring(argv[3]) == L"--snapshots") { installationSnapshots = Read(argv[4]); firstBuild = 5; }
    for (int build=firstBuild;build<argc;++build) {
      const auto install=Installation(argv[build]); const std::string suffix="-build"+std::to_string(build-firstBuild+1);
      Case test; test.recipe=base; test.installation=install; test.name="lossless"+suffix; summaries.push_back(Run(test,root));
      test.name="h264"+suffix; test.recipe=fixtures["fixtures"][0]["recipe"]; test.recipe["video"]["speed"]="ultrafast";
      summaries.push_back(Run(test,root));
      test.name="video-only"+suffix; test.recipe=base; test.recipe["audio"][0]["enabled"]=false; summaries.push_back(Run(test,root));
      test.name="advanced"+suffix; test.recipe=base; test.recipe["command"]={{"mode","template"},{"template","{inputs} -map 0:v:0 -map 1:a:0 -c:v ffv1 -pix_fmt yuv420p10le -c:a pcm_f32le -f matroska {output}"}};
      summaries.push_back(Run(test,root));
    }
    Case test; test.recipe=base; test.installation=Installation(argv[firstBuild]);
    test.name="cancel-mid"; test.cancelAt=15; test.success=false; summaries.push_back(Run(test,root));
    test.name="cancel-final"; test.cancelAt=60; summaries.push_back(Run(test,root));
    test.cancelAt=-1; test.name="host-failure"; test.failureSlot=6; summaries.push_back(Run(test,root));
    test.failureSlot=0; test.name="destination-race"; test.collision=true; summaries.push_back(Run(test,root));
    test.collision=false; test.success=true; test.name="recovery"; summaries.push_back(Run(test,root));
    test.name="1080p-fractional"; test.width=1920; test.height=1080; summaries.push_back(Run(test,root));
    test.width=320; test.height=180; test.name="index-blocked"; test.blockedIndex=true; summaries.push_back(Run(test,root));
    test.blockedIndex=false; test.name="live-blocked"; test.blockedLive=true; summaries.push_back(Run(test,root));
    test.blockedLive=false; test.name="status-root-failure"; test.invalidRoot=true; summaries.push_back(Run(test,root));
    test.invalidRoot=false; test.installation=Installation(argv[firstBuild],Self()); test.success=false;
    for (const auto* name : {"probe-mismatch","probe-malformed","probe-limit","probe-timeout"}) { test.name=name; test.probeTimeout=300; summaries.push_back(Run(test,root)); }
    test.name="probe-cancel"; test.probeTimeout=3000; test.cancelDuringProbe=true; summaries.push_back(Run(test,root)); test.cancelDuringProbe=false;
    test.installation=Installation(Self(),Self()); test.verify=false;
    test.recipe=base; test.recipe["command"]={{"mode","template"},{"template","{inputs} -b4-fixture hold -c:v ffv1 -c:a pcm_f32le -f matroska {output}"}};
    test.name="blocked-pipe-cancel"; test.timedCancel=true; summaries.push_back(Run(test,root));
    test.timedCancel=false; test.name="pipe-timeout"; test.pipeTimeout=200; summaries.push_back(Run(test,root));
    test.pipeTimeout=3000; test.name="child-exit"; test.recipe["command"]["template"]="{inputs} -b4-fixture exit -c:v ffv1 -c:a pcm_f32le -f matroska {output}"; summaries.push_back(Run(test,root));
    test.success=true; test.name="slow-backpressure"; test.recipe["command"]["template"]="{inputs} -b4-fixture slow -c:v ffv1 -c:a pcm_f32le -f matroska {output}"; summaries.push_back(Run(test,root));
    Save(root+L"\\summary.json",{{"checks",checks},{"instrumented",instrumented},{"validation","fake host / real FFmpeg plus controlled child fakes"},{"cases",summaries}});
    printf("B4 PASS: %d checks, %zu cases\n",checks,summaries.size()); return 0;
  } catch (const std::exception& error) { fprintf(stderr,"B4 FAIL after %d checks: %s\n",checks,error.what()); return 1; }
}
