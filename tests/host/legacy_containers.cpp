// Actual candidate callbacks and the measured 23 class-extension selection.
// No installed host/exporter, app launch, FFmpeg or user settings are used.
#include "../../src/vegas/adapter/render_formats.h"
#include "../../src/vegas/configuration/recipe_template.h"
#include "vegas_text.h"
#include <cstdio>
#include <fstream>
#include <iterator>
#include <set>
using namespace vegas_encoder;
using namespace sfio;
using ve::Json;
namespace {
int checks = 0;
void Check(bool ok, const char* message) { ++checks; if (!ok) throw std::runtime_error(message); }
class Allocator final : public ISfHostAllocator {
 public:
  int allocations = 0, frees = 0;
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
    Check(argc == 3,"pass the opt-in candidate DLL and authored built-in catalog");
    const auto module = LoadLibraryW(argv[1]); Check(module != nullptr,"candidate loads");
    using GetClass = HRESULT (STDAPICALLTYPE*)(REFCLSID,REFIID,void**);
    const auto getClass = reinterpret_cast<GetClass>(GetProcAddress(module,"DllGetClassObject"));
    Check(getClass != nullptr,"factory export");
    IClassFactory* factory = nullptr;
    Check(getClass(CLSID_SfMediaGetUnsharedTypeInfo,IID_IClassFactory,reinterpret_cast<void**>(&factory)) == S_OK,"discovery factory");
    ISfUnsharedFIOPluginInfo* info = nullptr;
    Check(factory->CreateInstance(nullptr,__uuidof(ISfUnsharedFIOPluginInfo),reinterpret_cast<void**>(&info)) == S_OK,"discovery instance");
    factory->Release();
    LONG count = -1;
    Check(info->GetFilterCount(&count) == S_OK && count == 5,"five independent container formats");
    Check(info->GetFilterCount(nullptr) == E_POINTER,"null count refused");
    for (const LONG index : {LONG{-1},LONG{5}})
      Check(info->GetFilterInfo(index,nullptr,nullptr,0,nullptr,nullptr,nullptr,nullptr,nullptr,nullptr,nullptr,nullptr) == E_INVALIDARG,"invalid filter index refused");
    std::ifstream file{std::filesystem::path(argv[2]),std::ios::binary};
    const std::string text((std::istreambuf_iterator<char>(file)),{});
    const auto catalog = ve::Parse(reinterpret_cast<const uint8_t*>(text.data()),text.size());
    Allocator allocator;
    std::set<std::string> starters;
    std::vector<GUID> allGuids;
    for (LONG index = 0; index < count; ++index) {
      const auto& expected = kLegacyFormats[index];
      GUID filter{}; wchar_t name[80]{}; DWORD access=0,streams=0,a=0,b=0,c=0,d=0,expires=0,flags=0;
      Check(info->GetFilterInfo(index,&filter,name,80,&access,&streams,&a,&b,&c,&d,&expires,&flags) == S_OK,"filter metadata");
      Check(filter == expected.filter && wcscmp(name,expected.name) == 0,"stable own filter identity and name");
      Check(access == SFFIO_FILTER_ACCESS_RENDER && streams == 0x0b && flags == 1,"existing render-only discovery answers");
      Check(getClass(filter,IID_IClassFactory,reinterpret_cast<void**>(&factory)) == S_OK,"advertised class factory");
      ISfRenderFileClass* writer = nullptr;
      Check(factory->CreateInstance(nullptr,__uuidof(ISfRenderFileClass),reinterpret_cast<void**>(&writer)) == S_OK,"advertised writer instantiates");
      factory->Release();
      GUID owner{}; Check(writer->GetTypeID(&owner) == S_OK && owner == expected.owner,"independent template owner");
      Check(writer->SetHostInterface(&allocator) == S_OK,"host allocator adoption");
      const LONG extensionId = 4; BSTR extension = nullptr;
      Check(writer->GetStrings(&extensionId,1,&extension) == S_OK && extension,"class-wide extension string");
      // F-061 sharedk 0x39B1A0 takes ID 4, truncates at ';', removes '*'.
      std::wstring selected(extension); SysFreeString(extension);
      selected.resize(selected.find(L';') == std::wstring::npos ? selected.size() : selected.find(L';'));
      if (!selected.empty() && selected.front() == L'*') selected.erase(0,1);
      Check(selected == std::wstring(L".") + Widen(expected.container),"measured 23 fallback chooses this container without selector 11");
      LONG presets = 0; Check(writer->GetPresetCount(&presets) == S_OK && presets >= 3,"hidden probe, general and matching starters");
      for (LONG p = 0; p < presets; ++p) {
        SFTEMPLATE* raw = nullptr;
        Check(writer->GetPreset(&raw,p) == S_OK && raw,"host-owned supplied template");
        const auto value = Tpl::Copy(raw); allocator.Free(raw);
        Check(value.Guid(tpl::iidOwner) == owner && value.U32(tpl::cbExtra)%4 == 0,"correct owner and DWORD name placement");
        const auto guid = value.Guid(tpl::guidPreset);
        Check(std::none_of(allGuids.begin(),allGuids.end(),[&](const GUID& prior) { return prior == guid; }),"no duplicate supplied GUIDs across classes");
        allGuids.push_back(guid);
        LONG roundtrip = -1;
        Check(writer->GetPresetIndexFromGuid(&guid,&roundtrip) == S_OK && roundtrip == p,"per-class GUID/index roundtrip");
        const auto snapshot = configuration::ReadRecipeSnapshot(value,owner);
        Check(configuration::RecipeOutputExtension(snapshot.at("recipe")) == selected,"every recipe matches the class-selected destination");
        wchar_t callback[32]{};
        Check(writer->GetTemplateInfo(value.Ptr(),reinterpret_cast<BYTE*>(callback),32,11) == S_OK && callback == L"*" + selected,"modern callback agrees if requested");
        if (p < 2) Check(snapshot.at("origin").is_null() && value.U32(tpl::id) == static_cast<DWORD>(p),"bound general/probe keeps general IDs without a library origin");
        else {
          const auto id = snapshot.at("origin").at("presetId").get<std::string>();
          Check(starters.insert(id).second,"starter occurs in exactly one container class");
          const auto source = std::find_if(catalog.at("presets").begin(),catalog.at("presets").end(),[&](const Json& entry) { return entry.at("recipe").at("id") == id; });
          Check(source != catalog.at("presets").end(),"origin resolves shared source catalog");
          const auto normalized = ve::Normalize({{"recipe",source->at("recipe")}});
          Check(ve::Canonical(snapshot.at("recipe")) == ve::Canonical(normalized.at("recipe")),"container grouping preserves every normalized starter setting");
          const auto entry = std::find_if(catalog.at("vegas").begin(),catalog.at("vegas").end(),[&](const Json& row) { return row.at("presetId") == id; });
          GUID expectedGuid{};
          Check(entry != catalog.at("vegas").end() && SUCCEEDED(CLSIDFromString((L"{" + Widen(entry->at("guid").get<std::string>()) + L"}").c_str(),&expectedGuid)) && guid == expectedGuid && value.U32(tpl::id) == entry->at("index"),"starter native GUID and sparse persistent ID retained");
          Check(Utf8(value.Name().c_str()) == entry->at("name") && Utf8(test::VegasDisplayName(value).c_str()) == entry->at("name"),
                "starter shows its full catalog name in VEGAS 23 five-format mode");
        }
        ISfRenderFile* render = nullptr;
        Check(writer->Create(&render,nullptr,0,nullptr,value.Ptr()) == S_OK && render,"bound owner survives real render object construction");
        render->Release();
        auto changed = snapshot; changed["recipe"]["notes"] = "Saved personal edit";
        const auto saved = configuration::ReplaceRecipeSnapshot(value,owner,changed);
        SFTEMPLATE* conformed = nullptr;
        Check(writer->ConformTemplate(&conformed,saved.Ptr(),2) == S_OK && conformed,"saved snapshot conformance");
        Check(configuration::ReadRecipeSnapshot(Tpl::Copy(conformed),owner) == changed,"saved settings and origin survive conformance");
        allocator.Free(conformed);
        auto foreign = value; foreign.SetGuid(tpl::iidOwner,kLegacyFormats[(index+1)%count].owner);
        render = reinterpret_cast<ISfRenderFile*>(1);
        Check(writer->Create(&render,nullptr,0,nullptr,foreign.Ptr()) == E_INVALIDARG && !render,"foreign class template cannot create or leak render object");
        conformed = reinterpret_cast<SFTEMPLATE*>(1);
        Check(writer->ConformTemplate(&conformed,foreign.Ptr(),2) == E_INVALIDARG && !conformed,"foreign product class cannot silently become default settings");
        // Wrong muxer with the correct owner is rejected in Basic and Advanced.
        changed["recipe"]["command"] = {{"mode","template"},{"template",std::string("{inputs} -c:v libx264 -an -f ") + (selected == L".mp4" ? "matroska" : "mp4") + " {output}"}};
        const auto mismatch = configuration::ReplaceRecipeSnapshot(value,owner,changed);
        Check(writer->Create(&render,nullptr,0,nullptr,mismatch.Ptr()) == E_INVALIDARG && !render,"active Advanced muxer cannot escape class binding");
        Check(writer->ConformTemplate(&conformed,mismatch.Ptr(),2) == E_INVALIDARG && !conformed,"mismatching saved muxer is not silently rewritten");
      }
      writer->Release();
    }
    Check(starters.size() == catalog.at("vegas").size(),"all shared starters are present once across the five formats");
    Check(allocator.allocations == allocator.frees,"all host allocations balanced");
    info->Release(); FreeLibrary(module);
    printf("Legacy containers: %d checks passed (actual DLL, fake host; no real VEGAS).\n",checks);
    return 0;
  } catch (const std::exception& error) { fprintf(stderr,"Legacy containers FAIL after %d checks: %s\n",checks,error.what()); return 1; }
}
