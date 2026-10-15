// Writer-owned monitor launch: no real app, host, installation or user files.
#include "../../src/engine/job_store.h"
#include "../../src/support/diagnostics.h"
#include <filesystem>
#include <fstream>
#include <cstdio>
using ve::Json;
using namespace vegas_encoder;
namespace fs = std::filesystem;
namespace {
Json Read(const fs::path& path) {
  std::ifstream file(path,std::ios::binary); const std::string bytes((std::istreambuf_iterator<char>(file)),{});
  return ve::Parse(reinterpret_cast<const uint8_t*>(bytes.data()),bytes.size());
}
void Check(bool ok, const char* message) { if (!ok) throw std::runtime_error(message); }
bool Sequence(const fs::path& path, int expected) {
  try { return Read(path).value("sequence",-1) == expected; } catch (const std::exception&) { return false; }
}
}
int wmain(int argc, wchar_t** argv) {
  try {
    if (argc == 3 && std::wstring(argv[1]) == L"--render-monitor") {
      const fs::path live = argv[2];
      const auto value = Read(live);
      const auto temp = live.wstring() + L".launched.tmp";
      { std::ofstream file(temp);
        file << Json{{"live",value},{"cwd",Utf8(fs::current_path().wstring().c_str())}}.dump(); }
      Check(MoveFileExW(temp.c_str(),(live.wstring() + L".launched.json").c_str(),MOVEFILE_WRITE_THROUGH),"publish child marker");
      const auto until = GetTickCount64() + 10000;
      while (GetTickCount64() < until && !fs::exists(live.wstring() + L".release")) Sleep(10);
      return 0;
    }
    Check(argc == 2,"usage: job-store-monitor <fresh-output-root>");
    const auto root = fs::absolute(argv[1]); Check(!fs::exists(root),"fresh output required");
    wchar_t executable[32768]{}; GetModuleFileNameW(nullptr,executable,32768);
    const auto id = NewJobId();
    const auto live = root / (Widen(id) + L".live.json");
    auto store = JobStore::Create(root.wstring(),id,executable);
    store->Status({{"live",1},{"phase","starting"}},true);
    // Parent makes progress before releasing the deliberately stalled child.
    const auto until = GetTickCount64() + 7000;
    const auto marker = live.wstring() + L".launched.json";
    while (GetTickCount64() < until && !fs::exists(marker)) Sleep(10);
    Check(fs::exists(marker),"writer launched monitor after complete C5 publication");
    const auto received = Read(marker);
    Check(received.at("live").at("phase") == "starting","child could read initial C5 at launch");
    Check(received.at("cwd") == Utf8(fs::path(executable).parent_path().wstring().c_str()),"child starts in app parent for Flutter data lookup");
    store->Status({{"live",1},{"phase","succeeded"}},true);
    { std::ofstream release(live.wstring() + L".release"); release << "done"; }
    store.reset();
    const auto failedId = NewJobId();
    const auto failedLive = root / L"missing-app" / (Widen(failedId) + L".live.json");
    auto failed = JobStore::Create((root / L"missing-app").wstring(),failedId,(root / L"missing.exe").wstring());
    failed->Status({{"live",1}},true);
    const auto deadline = GetTickCount64() + 2000;
    while (GetTickCount64() < deadline && !fs::exists(failedLive)) Sleep(10);
    Check(fs::exists(failedLive) && failed->Failure().empty(),"monitor launch refusal is nonfatal to publication");
    const auto timingId = NewJobId(); const auto timingRoot = root / L"timing";
    const auto timingFile = timingRoot / (Widen(timingId) + L".live.json");
    auto timing = JobStore::Create(timingRoot.wstring(),timingId);
    timing->Status({{"sequence",0}},true);
    auto end = GetTickCount64() + 2000;
    while (GetTickCount64() < end && !Sequence(timingFile,0)) Sleep(5);
    Check(Sequence(timingFile,0),"initial timing snapshot published");
    Sleep(550); // Idle beyond the 2 Hz deadline; a new sample should wake immediately.
    const auto sample = GetTickCount64(); timing->Status({{"sequence",1}},false);
    end = sample + 350;
    while (GetTickCount64() < end && !Sequence(timingFile,1)) Sleep(5);
    Check(Sequence(timingFile,1),"idle progress update has no extra half-second timer wait");
    timing->Status({{"sequence",2}},false); Sleep(100);
    Check(Sequence(timingFile,1),"ordinary samples remain coalesced within the 2 Hz budget");
    timing->Status({{"sequence",3}},true);
    end = GetTickCount64() + 350;
    while (GetTickCount64() < end && !Sequence(timingFile,3)) Sleep(5);
    Check(Sequence(timingFile,3),"phase changes bypass sample coalescing");
    printf("B6 MONITOR LAUNCH/CADENCE PASSED: initial publication, argv/cwd, stalled child independence, nonfatal refusal and 2 Hz wake/coalescing; fake child only\n");
    return 0;
  } catch (const std::exception& error) { printf("B6 MONITOR LAUNCH FAILED: %s\n",error.what()); return 1; }
}
