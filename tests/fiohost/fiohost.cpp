// fiohost: minimal stand-in for the VEGAS FileIO host, for inspecting and
// testing exporter plug-ins without the VEGAS GUI.
//
// Replays the discovery sequence observed at runtime (F-031/F-033):
//   DllGetClassObject(CLSID_SfMediaGetUnsharedTypeInfo) -> plug-in info ->
//   per filter: DllGetClassObject(filter) -> ISfRenderFileClass ->
//   SetHostInterface(host with allocator) -> getters -> presets.
// Each preset template is written to <outdir>/preset-<n>.tpl.
// With --render, it then replays the pre-Create template calls and drives
// Create/Render through fake streams (fakehost.cpp); output lands in <outdir>.
//
// Usage: fiohost.exe <plugin.dll> <outdir> [--render <host-project.tpl>]
//          [--preset N] [--size WxH] [--fps F] [--frames N] [--cancel-at K]
//          [--renders R] [--no-wmi]
#include "../../src/vegas/abi/sfio_abi.h"
#include "fakehost.h"

#include <wbemidl.h>

#include <cstdio>
#include <cstdlib>
#include <string>
#include <vector>

using namespace sfio;

static void PrintGuid(const char* label, const GUID& g) {
  wchar_t s[64];
  StringFromGUID2(g, s, 64);
  printf("%s %ls\n", label, s);
}

static void Hex(const void* p, size_t n) {
  const unsigned char* b = (const unsigned char*)p;
  for (size_t off = 0; off < n; off += 32) {
    printf("    +%03zx:", off);
    for (size_t i = off; i < off + 32 && i < n; i++) printf("%s%02x", (i % 8) ? "" : " ", b[i]);
    printf("\n");
  }
}

// Host allocator: CoTaskMem-backed; logs every use.
class HostAllocator : public ISfHostAllocator {
 public:
  LONG allocs = 0, frees = 0;
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void** ppv) override {
    if (riid == IID_IUnknown || riid == IID_SfHostAllocator) {
      *ppv = this;
      return S_OK;
    }
    *ppv = nullptr;
    return E_NOINTERFACE;
  }
  ULONG STDMETHODCALLTYPE AddRef() override { return 2; }
  ULONG STDMETHODCALLTYPE Release() override { return 1; }
  void* STDMETHODCALLTYPE Alloc(SIZE_T cb) override {
    void* p = CoTaskMemAlloc(cb);
    allocs++;
    printf("  [host] Alloc(%zu) -> %p\n", (size_t)cb, p);
    return p;
  }
  void STDMETHODCALLTYPE Free(void* p) override {
    frees++;
    printf("  [host] Free(%p)\n", p);
    CoTaskMemFree(p);
  }
};

// Object passed to SetHostInterface; hands out the allocator.
class HostObject : public IUnknown {
 public:
  HostAllocator alloc;
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void** ppv) override {
    wchar_t s[64];
    StringFromGUID2(riid, s, 64);
    if (riid == IID_SfHostAllocator) {
      printf("  [host] QueryInterface(%ls) -> allocator\n", s);
      *ppv = &alloc;
      return S_OK;
    }
    if (riid == IID_IUnknown) {
      *ppv = this;
      return S_OK;
    }
    printf("  [host] QueryInterface(%ls) -> E_NOINTERFACE\n", s);
    *ppv = nullptr;
    return E_NOINTERFACE;
  }
  ULONG STDMETHODCALLTYPE AddRef() override { return 2; }
  ULONG STDMETHODCALLTYPE Release() override { return 1; }
};

using GetClassObjectFn = HRESULT(STDAPICALLTYPE*)(REFCLSID, REFIID, void**);

// Voukoder Pro's core runs a WMI query inside its DLL initialisation. In a
// fresh process that is the first COM remoting setup, which blocks under the
// loader lock (observed hang, F-033). VEGAS has remoting initialised long
// before loading plug-ins; do the same by connecting to WMI up front.
static void WarmUpComRemoting() {
  IWbemLocator* loc = nullptr;
  if (FAILED(CoCreateInstance(CLSID_WbemLocator, nullptr, CLSCTX_INPROC_SERVER, IID_IWbemLocator,
                              (void**)&loc)))
    return;
  IWbemServices* svc = nullptr;
  BSTR ns = SysAllocString(L"ROOT\\CIMV2");
  HRESULT hr = loc->ConnectServer(ns, nullptr, nullptr, nullptr, 0, nullptr, nullptr, &svc);
  printf("WMI warm-up hr=0x%08lx\n", hr);
  SysFreeString(ns);
  if (svc) svc->Release();
  loc->Release();
}

static void DumpTemplate(const std::wstring& dir, LONG index, const SFTEMPLATE* tpl) {
  DWORD cb = *(const DWORD*)tpl;
  printf("  preset %ld: template %p cbStruct=%lu\n", index, (const void*)tpl, cb);
  if (cb < 16 || cb > 65536) return;
  Hex(tpl, cb);
  wchar_t path[MAX_PATH];
  swprintf_s(path, L"%s\\preset-%ld.tpl", dir.c_str(), index);
  FILE* f = nullptr;
  if (_wfopen_s(&f, path, L"wb") == 0 && f) {
    fwrite(tpl, 1, cb, f);
    fclose(f);
  }
}

int wmain(int argc, wchar_t** argv) {
  if (argc < 3) {
    fprintf(stderr,
            "usage: fiohost <plugin.dll> <outdir> [--render <host-project.tpl>] [--preset N] [--size WxH]\n"
            "               [--fps F] [--delivered-fps F] [--frames N] [--cancel-at K] [--renders R]\n"
            "               [--extension mkv|ffdiag] [--short-read N] [--video-only] [--expect-failure] [--no-wmi]\n");
    return 2;
  }
  setvbuf(stdout, nullptr, _IONBF, 0);  // keep output if the plug-in hangs
  CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  std::wstring outdir = argv[2];
  CreateDirectoryW(outdir.c_str(), nullptr);
  RenderTestOptions render;
  render.outDir = outdir;
  bool wmi = true;
  for (int i = 3; i < argc; i++) {
    std::wstring a = argv[i];
    const wchar_t* v = i + 1 < argc ? argv[i + 1] : L"";
    bool takesValue = true;
    if (a == L"--render") render.hostTemplate = v;
    else if (a == L"--preset") render.preset = _wtol(v);
    else if (a == L"--size") swscanf_s(v, L"%ldx%ld", &render.width, &render.height);
    else if (a == L"--fps") render.fps = _wtof(v);
    else if (a == L"--delivered-fps") render.deliveredFps = _wtof(v);
    else if (a == L"--frames") render.frames = _wtoi64(v);
    else if (a == L"--cancel-at") render.cancelAt = _wtoi64(v);
    else if (a == L"--renders") render.renders = _wtoi(v);
    else if (a == L"--extension") render.extension = v;
    else if (a == L"--short-read") render.shortRead = _wtol(v);
    else if (a == L"--video-only") render.videoOnly = true, takesValue = false;
    else if (a == L"--expect-failure") render.expectFailure = true, takesValue = false;
    else if (a == L"--no-wmi") wmi = false, takesValue = false;
    else {
      fprintf(stderr, "unknown option %ls\n", a.c_str());
      return 2;
    }
    if (takesValue) i++;
  }

  if (wmi) WarmUpComRemoting();
  printf("loading %ls\n", argv[1]);
  HMODULE mod = LoadLibraryExW(argv[1], nullptr, LOAD_WITH_ALTERED_SEARCH_PATH);
  if (!mod) {
    printf("LoadLibrary failed: %lu\n", GetLastError());
    return 1;
  }
  printf("loaded at %p\n", (void*)mod);
  auto getClass = (GetClassObjectFn)GetProcAddress(mod, "DllGetClassObject");
  if (!getClass) return 1;
  // VEGAS goes straight to DllGetClassObject (no DllInitClasses call was
  // observed in the F-030/F-031 logs).

  // 1. Plug-in info.
  IClassFactory* cf = nullptr;
  printf("DllGetClassObject(PluginInfo)...\n");
  HRESULT hr = getClass(CLSID_SfMediaGetUnsharedTypeInfo, IID_IClassFactory, (void**)&cf);
  printf("DllGetClassObject(PluginInfo) hr=0x%08lx\n", hr);
  if (FAILED(hr)) return 1;
  ISfUnsharedFIOPluginInfo* info = nullptr;
  hr = cf->CreateInstance(nullptr, __uuidof(ISfUnsharedFIOPluginInfo), (void**)&info);
  cf->Release();
  printf("CreateInstance(ISfUnsharedFIOPluginInfo) hr=0x%08lx\n", hr);
  if (FAILED(hr)) return 1;
  LONG filters = 0;
  info->GetFilterCount(&filters);
  printf("filters=%ld\n", filters);

  std::vector<GUID> clsids;
  for (LONG i = 0; i < filters; i++) {
    GUID clsid{};
    wchar_t name[256] = L"";
    DWORD v[8];
    for (auto& x : v) x = 0xCCCCCCCC;
    hr = info->GetFilterInfo(i, &clsid, name, 256, &v[0], &v[1], &v[2], &v[3], &v[4], &v[5],
                             &v[6], &v[7]);
    printf("filter %ld hr=0x%08lx name=\"%ls\"\n", i, hr, name);
    PrintGuid("  clsid", clsid);
    printf("  access=0x%lx streamTypes=0x%lx appLevel=0x%lx/0x%lx/0x%lx/0x%lx expire=0x%lx flags=0x%lx\n",
           v[0], v[1], v[2], v[3], v[4], v[5], v[6], v[7]);
    if (SUCCEEDED(hr)) clsids.push_back(clsid);
  }
  info->Release();

  // 2. Render class per filter.
  HostObject host;
  int result = 0;
  for (const GUID& clsid : clsids) {
    hr = getClass(clsid, IID_IClassFactory, (void**)&cf);
    if (FAILED(hr)) continue;
    // VEGAS also asks for the reader class (F-033); report whether it exists.
    IUnknown* reader = nullptr;
    hr = cf->CreateInstance(nullptr, IID_ISfReadFileClass, (void**)&reader);
    printf("CreateInstance(ISfReadFileClass) hr=0x%08lx\n", hr);
    if (reader) reader->Release();
    ISfRenderFileClass* rc = nullptr;
    hr = cf->CreateInstance(nullptr, __uuidof(ISfRenderFileClass), (void**)&rc);
    cf->Release();
    printf("CreateInstance(ISfRenderFileClass) hr=0x%08lx\n", hr);
    if (FAILED(hr)) continue;

    hr = rc->SetHostInterface(&host);
    printf("SetHostInterface hr=0x%08lx\n", hr);
    GUID g{};
    DWORD d = 0;
    hr = rc->GetTypeID(&g);
    printf("slot4 GetTypeID hr=0x%08lx ", hr);
    PrintGuid("guid", g);
    hr = rc->GetAllowedStreamTypes(&d);
    printf("slot5 GetAllowedStreamTypes hr=0x%08lx value=0x%lx\n", hr, d);
    hr = rc->GetCaps(&d);
    printf("slot6 GetCaps hr=0x%08lx value=0x%lx\n", hr, d);
    g = GUID{};
    hr = rc->GetReadClassGuid(&g);
    printf("slot7 GetReadClassGuid hr=0x%08lx ", hr);
    PrintGuid("guid", g);

    for (LONG id = 0; id < 48; id++) {
      BSTR s = nullptr;
      hr = rc->GetStrings(&id, 1, &s);
      if (s) {
        printf("string[%ld] hr=0x%08lx \"%ls\"\n", id, hr, s);
        SysFreeString(s);
      }
    }

    LONG a = -1, b = -1, c = -1;
    hr = rc->GetPropertyPageCount(&a, &b, &c);
    printf("GetPropertyPageCount hr=0x%08lx %ld %ld %ld\n", hr, a, b, c);
    printf("HasAboutBox hr=0x%08lx\n", rc->HasAboutBox());

    LONG presets = 0;
    hr = rc->GetPresetCount(&presets);
    printf("GetPresetCount hr=0x%08lx count=%ld\n", hr, presets);
    for (LONG i = 0; i < presets; i++) {
      SFTEMPLATE* tpl = nullptr;
      hr = rc->GetPreset(&tpl, i);
      printf("GetPreset(%ld) hr=0x%08lx\n", i, hr);
      if (SUCCEEDED(hr) && tpl) {
        DumpTemplate(outdir, i, tpl);
        host.alloc.Free(tpl);
      }
    }
    if (!render.hostTemplate.empty() && result == 0) result = RunRenderTest(rc, &host.alloc, render);
    rc->Release();
  }
  printf("allocations=%ld frees=%ld\n", host.alloc.allocs, host.alloc.frees);
  fflush(stdout);
  // Exit without FreeLibrary/CoUninitialize: plug-in threads may still run.
  ExitProcess((UINT)result);
}
