// One-format naming modes, actual DLL and core; no host/UI/encoder launch.
#include "../../src/vegas/adapter/render_formats.h"
#include "../../src/vegas/configuration/recipe_template.h"
#include "vegas_text.h"
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <iterator>
using namespace vegas_encoder;
using namespace sfio;
using ve::Json;
namespace {
int checks = 0;
void Check(bool ok, const char* what) { ++checks; if (!ok) throw std::runtime_error(what); }
Json Read(const wchar_t* path) {
  std::ifstream file{std::filesystem::path(path),std::ios::binary};
  const std::string text((std::istreambuf_iterator<char>(file)),{});
  return ve::Parse(reinterpret_cast<const uint8_t*>(text.data()),text.size());
}
class Allocator final : public ISfHostAllocator {
 public:
  int allocations=0,frees=0;
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID id, void** out) override {
    if (!out) return E_POINTER;
    *out = nullptr;
    if (id != IID_IUnknown && id != IID_SfHostAllocator) return E_NOINTERFACE;
    *out = this; AddRef(); return S_OK;
  }
  ULONG STDMETHODCALLTYPE AddRef() override { return 2; }
  ULONG STDMETHODCALLTYPE Release() override { return 1; }
  void* STDMETHODCALLTYPE Alloc(SIZE_T size) override { ++allocations; return CoTaskMemAlloc(size); }
  void STDMETHODCALLTYPE Free(void* data) override { ++frees; CoTaskMemFree(data); }
};
}
int wmain(int argc, wchar_t** argv) {
  try {
    const bool automatic = argc == 5 && std::wstring(argv[4]) == L"--auto";
    const bool rejectHost = argc == 3 && std::wstring(argv[2]) == L"--reject-host";
    Check(argc == 4 || automatic || rejectHost,"pass naming DLL, core fixtures and catalog [--auto], or DLL --reject-host");
#if defined(VEGAS_ENCODER_LEGACY_HOST)
#if VEGAS_ENCODER_LEGACY_HOST == 22
    constexpr wchar_t kernelName[] = L"sharedk.dll";
#elif VEGAS_ENCODER_LEGACY_HOST == 21
    constexpr wchar_t kernelName[] = L"vegas210k.dll";
#else
    constexpr wchar_t kernelName[] = L"vegas130k.dll";
#endif
    const auto kernelPath = std::filesystem::path(Widen(ModulePath(nullptr))).parent_path() / kernelName;
    const auto kernel = LoadLibraryW(kernelPath.c_str());
    Check(kernel != nullptr,"load authored fake kernel");
#endif
    const auto module = LoadLibraryW(argv[1]); Check(module != nullptr,"load owned candidate DLL");
    using GetClass = HRESULT (STDAPICALLTYPE*)(REFCLSID,REFIID,void**);
    const auto getClass = reinterpret_cast<GetClass>(GetProcAddress(module,"DllGetClassObject"));
    Check(getClass != nullptr,"factory export");
    IClassFactory* factory = nullptr;
    if (rejectHost) {
      Check(getClass(CLSID_SfMediaGetUnsharedTypeInfo,IID_IClassFactory,reinterpret_cast<void**>(&factory)) ==
            CLASS_E_CLASSNOTAVAILABLE && !factory,"different process refused before class factory");
      FreeLibrary(module);
#if defined(VEGAS_ENCODER_LEGACY_HOST)
      FreeLibrary(kernel);
#endif
      puts("Wrong host rejected before discovery.");
      return 0;
    }
    Check(getClass(CLSID_SfMediaGetUnsharedTypeInfo,IID_IClassFactory,reinterpret_cast<void**>(&factory)) == S_OK,"discovery factory");
    ISfUnsharedFIOPluginInfo* info = nullptr;
    Check(factory->CreateInstance(nullptr,__uuidof(ISfUnsharedFIOPluginInfo),reinterpret_cast<void**>(&info)) == S_OK,"discovery interface");
    factory->Release(); LONG formats = -1;
    Check(info->GetFilterCount(&formats) == S_OK && formats == 1,"one-format policy overrides retained fallback flags");
    info->Release();
    for (size_t i = 1; i < std::size(kLegacyFormats); ++i) {
      factory = reinterpret_cast<IClassFactory*>(1);
      Check(getClass(kLegacyFormats[i].filter,IID_IClassFactory,reinterpret_cast<void**>(&factory)) == CLASS_E_CLASSNOTAVAILABLE && !factory,"separate format identity unavailable in manual mode");
    }
    Check(getClass(CLSID_VegasEncoderFilter,IID_IClassFactory,reinterpret_cast<void**>(&factory)) == S_OK,"original one-format identity");
    ISfRenderFileClass* writer = nullptr;
    Check(factory->CreateInstance(nullptr,__uuidof(ISfRenderFileClass),reinterpret_cast<void**>(&writer)) == S_OK,"create original writer");
    factory->Release(); Allocator allocator;
#if defined(VEGAS_ENCODER_LEGACY_HOST)
    using ReleaseTemplate = void (WINAPI*)(SFTEMPLATE*);
    using Outstanding = LONG (WINAPI*)();
    const auto releaseTemplate = reinterpret_cast<ReleaseTemplate>(GetProcAddress(kernel,
        "?SfFio_ReleaseTemplate@@YAXPEAUtagSFTEMPLATExV2@@@Z"));
    const auto outstanding = reinterpret_cast<Outstanding>(GetProcAddress(kernel,"OutstandingTemplates"));
    Check(releaseTemplate && outstanding,"fake kernel exports");
    auto** slots = *reinterpret_cast<void***>(writer);
    using SetIndex = HRESULT (WINAPI*)(ISfRenderFileClass*,LONG);
    using GetIndex = HRESULT (WINAPI*)(ISfRenderFileClass*,LONG*);
    LONG index = -1;
    Check(reinterpret_cast<SetIndex>(slots[3])(writer,37) == S_OK &&
          reinterpret_cast<GetIndex>(slots[4])(writer,&index) == S_OK && index == 37,
          "raw legacy slots 3 and 4 set and get the type index");
    Check(writer->SetIOManager(&allocator) == S_OK,"legacy manager and kernel adoption");
    IUnknown* manager = nullptr;
    Check(writer->GetIOManager(&manager) == S_OK && manager == &allocator,"retained IO manager");
    manager->Release();
    constexpr size_t pageSlot = VEGAS_ENCODER_LEGACY_HOST == 13 ? 21 : 22;
    using CountPages = HRESULT (WINAPI*)(ISfRenderFileClass*,LONG*,LONG*,LONG*);
    LONG pages = 0, sale = -1, options = -1;
    Check(reinterpret_cast<CountPages>(slots[pageSlot])(writer,&pages,&sale,&options) == S_OK &&
          pages == 1 && sale == 0 && options == 0,"legacy class page-count slot");
    IPropertyPage* page = nullptr;
    Check(writer->GetPropertyPage(0,&page) == S_OK && page,"legacy page creation");
    page->Release();
#else
    Check(writer->SetHostInterface(&allocator) == S_OK,"host allocator adoption");
#endif
    const LONG ids[] = {1,4,99}; BSTR strings[3]{};
    Check(writer->GetStrings(ids,3,strings) == S_OK,"query class display and extension");
    Check(strings[0] && wcscmp(strings[0],L"Vegas Encoder") == 0 && !strings[2],"same display name and unknown-ID behavior");
    Check(strings[1] && (automatic ? wcscmp(strings[1],L"*.vencoder") == 0 : SysStringLen(strings[1]) == 0),"automatic policy advertises placeholder .vencoder; manual policy advertises allocated empty extension");
    for (const auto s : strings) SysFreeString(s);
    const auto fixtures = Read(argv[2]); const auto catalog = Read(argv[3]);
    const Json media{{"video",{{"width",1920},{"height",1080},{"fps",{30000,1001}},{"pixfmt","p010le"},{"sar","1:1"}}},
                     {"audio",{{"rate",48000},{"channels",2},{"sampleFmt","f32le"}}},{"durationSec",nullptr}};
    LONG count = 0;
    Check(writer->GetPresetCount(&count) == S_OK && count == static_cast<LONG>(catalog.at("vegas").size()) + 2,"all starters plus original general/probe in one class");
    for (LONG i = 0; i < count; ++i) {
      SFTEMPLATE* raw = nullptr;
      Check(writer->GetPreset(&raw,i) == S_OK && raw,"supplied template through host allocator");
      const auto value = Tpl::Copy(raw);
#if defined(VEGAS_ENCODER_LEGACY_HOST)
      Check(outstanding() == 1,"preset allocated by fake kernel");
      releaseTemplate(raw);
#else
      allocator.Free(raw);
#endif
      Check(value.Guid(tpl::iidOwner) == GUID_VegasEncoderType && value.U32(tpl::cbExtra)%4 == 0,"original owner and fixed name alignment");
      Check(test::VegasDisplayName(value) == value.Name() && !value.Name().empty(),"older VEGAS shows the full name the exporter wrote");
      const auto snapshot = configuration::ReadRecipeSnapshot(value,GUID_VegasEncoderType);
      const auto suffix = configuration::RecipeOutputExtension(snapshot.at("recipe"));
      Check(!suffix.empty(),"recipe keeps its core-derived output identity");
#if defined(VEGAS_ENCODER_LEGACY_HOST)
      DWORD fields[2]{0xCCCCCCCCu,0xAAAAAAAAu};
      const auto result = writer->GetTemplateInfo(value.Ptr(),reinterpret_cast<BYTE*>(fields),sizeof(DWORD),11);
      Check((VEGAS_ENCODER_LEGACY_HOST == 22
          ? result == S_OK && fields[0] == value.U32(tpl::videoStreams)
          : result == E_NOTIMPL && fields[0] == 0xCCCCCCCCu) && fields[1] == 0xAAAAAAAAu,
          "old selector 11 respects DWORD capacity and legacy semantics");
#else
      wchar_t wildcard[32]{};
      Check(writer->GetTemplateInfo(value.Ptr(),reinterpret_cast<BYTE*>(wildcard),32,11) == S_OK && wildcard == L"*" + suffix,"per-template callback remains available without changing class extension");
#endif
      const auto name = std::wstring(L"D:\\Render Tests\\日本語 typed") + suffix;
      const auto requested = automatic ? std::wstring(L"D:\\Render Tests\\日本語 typed.vencoder") : name;
      ISfRenderFile* render = nullptr;
      Check(writer->Create(&render,nullptr,0,nullptr,value.Ptr()) == S_OK && render,"native render object owns selected snapshot");
#if defined(VEGAS_ENCODER_LEGACY_HOST)
      ISfRenderFileClass* parent = nullptr;
      Check(render->GetRenderClass(&parent) == S_OK && parent == writer,"render returns retained class");
      parent->Release();
#endif
      Check(render->SetFile(requested.c_str()) == S_OK,"accept nominal or exact typed destination");
      wchar_t returned[260]{};
      Check(render->GetFileName(returned,260) == S_OK && name == returned,"GetFileName reports actual core-derived Unicode destination");
      if (automatic) {
        wchar_t shortPath[2]{L'x',L'x'};
        Check(render->GetFileName(shortPath,2) == HRESULT_FROM_WIN32(ERROR_INSUFFICIENT_BUFFER) && shortPath[0] == 0,"insufficient filename buffer fails without reporting a truncated actual path");
        Check(render->GetFileName(nullptr,260) == E_POINTER && render->GetFileName(shortPath,0) == E_POINTER,"invalid filename output buffers refused");
        Check(render->SetFile(L"D:\\folder.with.dots\\clip") == S_OK,"extensionless filename accepted");
        Check(render->GetFileName(returned,260) == S_OK && returned == std::wstring(L"D:\\folder.with.dots\\clip") + suffix,"parent dots do not truncate directory or extensionless basename");
        Check(render->SetFile(L"D:/Render Tests/日本語.final.MP4") == S_OK,"forward slashes and multiple dots accepted");
        Check(render->GetFileName(returned,260) == S_OK && returned == std::wstring(L"D:/Render Tests/日本語.final") + suffix,"only final filename extension changes");
        const std::wstring last = returned;
        for (const auto* invalid : {L"D:\\folder\\",L"D:\\folder\\.",L"D:\\folder\\..",L"D:\\clip.mp4:stream",L"D:"}) {
          Check(render->SetFile(invalid) == E_INVALIDARG,"incomplete destination cannot become a different output file");
          Check(render->GetFileName(returned,260) == S_OK && last == returned,"failed SetFile preserves prior actual destination");
        }
        Check(render->SetFile(nullptr) == S_OK && render->GetFileName(returned,260) == S_OK && !returned[0],"explicit path reset stays empty");
        Check(render->SetFile(requested.c_str()) == S_OK,"restoring nominal destination is deterministic");
      }
      render->Release();
      auto paths = fixtures.at("fixtures")[0].at("paths");
      paths["output"] = Utf8(name.c_str());
      paths["target"] = {{"id","vegas-native-v1"},{"outputPath",Utf8(name.c_str())}};
      const auto correct = ve::Compile({{"recipe",snapshot.at("recipe")},{"media",media},{"paths",paths}});
      Check(!ve::HasErrors(correct.at("issues")),"manual destination with required suffix passes real native admission");
      paths["target"]["outputPath"] = suffix == L".mkv" ? "D:\\wrong.mp4" : "D:\\wrong.mkv";
      const auto wrong = ve::Compile({{"recipe",snapshot.at("recipe")},{"media",media},{"paths",paths}});
      Check(std::any_of(wrong.at("issues").begin(),wrong.at("issues").end(),[](const Json& issue) { return ve::Str(issue,"id") == "N-OUTPUT-SUFFIX"; }),"manual mode retains the exact-destination suffix guard");
      if (i < 2) Check(value.U32(tpl::id) == static_cast<DWORD>(i),"original general/probe IDs");
      else {
        const auto& entry = catalog.at("vegas").at(i-2);
        GUID expected{};
        Check(SUCCEEDED(CLSIDFromString((L"{" + Widen(entry.at("guid").get<std::string>()) + L"}").c_str(),&expected)) && value.Guid(tpl::guidPreset) == expected && value.U32(tpl::id) == entry.at("index"),"starter GUID and sparse ID retained");
        Check(Utf8(value.Name().c_str()) == entry.at("name") && Utf8(test::VegasDisplayName(value).c_str()) == entry.at("name"),
              "starter shows its full catalog name in older VEGAS (no missing first letter)");
      }
    }
    if (automatic) {
      auto recipe = fixtures.at("fixtures")[0].at("recipe");
      recipe["container"]["format"] = "mp4";
      recipe["command"] = {{"mode","template"},{"template","{inputs} -c:v libvpx-vp9 -an -f webm {output}"}};
      auto base = Tpl::Make(L"Advanced naming",L"",0); base.SetGuid(tpl::iidOwner,GUID_VegasEncoderType);
      auto value = configuration::CreateRecipeTemplate(base,GUID_VegasEncoderType,{{"recipe",recipe},{"origin",nullptr},{"vegasPrefs",Json::object()},{"writtenBy","naming-test"}});
      ISfRenderFile* frozen = nullptr;
      Check(writer->Create(&frozen,nullptr,0,nullptr,value.Ptr()) == S_OK && frozen,"Create owns Advanced snapshot");
      recipe["command"]["template"] = "{inputs} -c:v ffv1 -an -f matroska {output}";
      auto changed = configuration::ReadRecipeSnapshot(value,GUID_VegasEncoderType); changed["recipe"] = recipe;
      value = configuration::ReplaceRecipeSnapshot(value,GUID_VegasEncoderType,changed);
      ISfRenderFile* later = nullptr;
      Check(writer->Create(&later,nullptr,0,nullptr,value.Ptr()) == S_OK && later,"independent later recipe render");
      wchar_t returned[260]{};
      Check(frozen->SetFile(L"D:\\advanced.mp4") == S_OK && later->SetFile(L"D:\\later.mp4") == S_OK,"interleaved SetFile calls use per-object recipes");
      Check(frozen->GetFileName(returned,260) == S_OK && wcscmp(returned,L"D:\\advanced.webm") == 0,"immutable active Advanced muxer overrides inactive MP4 and later edits");
      Check(later->GetFileName(returned,260) == S_OK && wcscmp(returned,L"D:\\later.mkv") == 0,"later render has its own destination and muxer");
      frozen->Release(); later->Release();
      recipe["command"]["template"] = "{inputs} -c:v ffv1 -an {output}";
      changed["recipe"] = recipe; value = configuration::ReplaceRecipeSnapshot(value,GUID_VegasEncoderType,changed);
      ISfRenderFile* unknown = nullptr;
      Check(writer->Create(&unknown,nullptr,0,nullptr,value.Ptr()) == S_OK && unknown,"snapshot can be inspected before naming admission");
      Check(unknown->SetFile(L"D:\\unknown.mp4") == E_INVALIDARG,"unknown active muxer cannot guess a suffix from inactive Basic controls or requested name");
      unknown->Release();
    }
    Check(allocator.allocations == allocator.frees,"host allocations balanced");
    writer->Release(); FreeLibrary(module);
#if defined(VEGAS_ENCODER_LEGACY_HOST)
    Check(outstanding() == 0,"kernel allocations balanced");
    FreeLibrary(kernel);
#endif
    printf("Single-format %s names: %d checks passed (actual DLL/core, fake host; no real VEGAS).\n",automatic ? "automatic" : "manual",checks);
    return 0;
  } catch (const std::exception& error) { fprintf(stderr,"Manual names FAIL after %d checks: %s\n",checks,error.what()); return 1; }
}
