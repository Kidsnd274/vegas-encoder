// Actual candidate DLL callbacks with a fake allocator; no VEGAS/FFmpeg launch.
#include "../../src/vegas/adapter/vegas_encoder.h"
#include "../../src/vegas/adapter/render_formats.h"
#include "../../src/vegas/configuration/recipe_template.h"
#include "vegas_text.h"
#include <cstdio>
#include <fstream>
#include <iterator>
#include <stdexcept>

using namespace vegas_encoder;
using namespace sfio;
using ve::Json;
namespace {
int checks = 0;
void Check(bool ok, const char* what) { ++checks; if (!ok) throw std::runtime_error(what); }
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
    if (argc != 4) throw std::runtime_error("Pass candidate DLL, authored core fixtures and built-in catalog.");
    const auto module = LoadLibraryW(argv[1]); Check(module != nullptr,"load candidate DLL");
    using GetClass = HRESULT (STDAPICALLTYPE*)(REFCLSID,REFIID,void**);
    const auto getClass = reinterpret_cast<GetClass>(GetProcAddress(module,"DllGetClassObject"));
    Check(getClass != nullptr,"candidate factory export");
    IClassFactory* factory = nullptr;
    Check(getClass(CLSID_SfMediaGetUnsharedTypeInfo,IID_IClassFactory,reinterpret_cast<void**>(&factory)) == S_OK,"modern discovery factory");
    ISfUnsharedFIOPluginInfo* info = nullptr;
    Check(factory->CreateInstance(nullptr,__uuidof(ISfUnsharedFIOPluginInfo),reinterpret_cast<void**>(&info)) == S_OK,"modern discovery instance");
    factory->Release(); LONG formats = -1;
    Check(info->GetFilterCount(&formats) == S_OK && formats == 1,"default 2026 mode exposes one format");
    info->Release();
    for (size_t index = 1; index < std::size(kLegacyFormats); ++index) {
      factory = reinterpret_cast<IClassFactory*>(1);
      Check(getClass(kLegacyFormats[index].filter,IID_IClassFactory,reinterpret_cast<void**>(&factory)) == CLASS_E_CLASSNOTAVAILABLE && !factory,"legacy-only identity unavailable in default mode");
    }
    Check(getClass(CLSID_VegasEncoderFilter,IID_IClassFactory,reinterpret_cast<void**>(&factory)) == S_OK,"filter identity unchanged");
    ISfRenderFileClass* writer = nullptr;
    Check(factory->CreateInstance(nullptr,__uuidof(ISfRenderFileClass),reinterpret_cast<void**>(&writer)) == S_OK,"create writer");
    factory->Release(); Allocator allocator;
    Check(writer->SetHostInterface(&allocator) == S_OK,"fake allocator adoption");
    const LONG ids[] = {4,99,1}; BSTR strings[3]{};
    Check(writer->GetStrings(ids,3,strings) == S_OK,"batched GetStrings");
    Check(strings[0] && wcscmp(strings[0],L"*.mkv;*.mp4;*.mov;*.webm;*.mxf") == 0,"five-extension writer advertising, MKV first");
    Check(!strings[1] && strings[2] && wcscmp(strings[2],L"Vegas Encoder") == 0,"unknown string and display name preserved");
    for (const auto value : strings) SysFreeString(value);
    std::ifstream input{std::filesystem::path(argv[2]),std::ios::binary};
    const std::string text((std::istreambuf_iterator<char>(input)),{});
    const auto bundle = ve::Parse(reinterpret_cast<const uint8_t*>(text.data()),text.size());
    std::ifstream catalogInput{std::filesystem::path(argv[3]),std::ios::binary};
    const std::string catalogText((std::istreambuf_iterator<char>(catalogInput)),{});
    const auto catalog = ve::Parse(reinterpret_cast<const uint8_t*>(catalogText.data()),catalogText.size());
    LONG presetCount = 0;
    Check(writer->GetPresetCount(nullptr) == E_POINTER,"null preset count refused");
    Check(writer->GetPresetCount(&presetCount) == S_OK && presetCount == static_cast<LONG>(catalog.at("vegas").size()) + 2,"probe, general template and all fixed starter templates");
    Check(writer->GetPreset(nullptr,1) == E_POINTER,"null preset output refused");
    for (const LONG index : {LONG{-1},presetCount}) {
      SFTEMPLATE* invalid = reinterpret_cast<SFTEMPLATE*>(1);
      Check(writer->GetPreset(&invalid,index) == E_INVALIDARG && !invalid,"invalid index clears output");
    }
    std::vector<GUID> presetGuids;
    for (LONG index = 0; index < presetCount; ++index) {
      SFTEMPLATE* returned = nullptr;
      Check(writer->GetPreset(&returned,index) == S_OK && returned,"exporter creates starter through host allocator without app/user files");
      const auto value = Tpl::Copy(returned); allocator.Free(returned);
      Check(value.Guid(tpl::iidOwner) == GUID_VegasEncoderType,"owned type");
      Check(value.U32(tpl::cbExtra)%4 == 0,"all supplied template names start at the VEGAS DWORD boundary");
      Check(test::VegasDisplayName(value) == value.Name() && !value.Name().empty(),"VEGAS 2026 shows the full name the exporter wrote");
      const auto guid = value.Guid(tpl::guidPreset);
      Check(std::none_of(presetGuids.begin(),presetGuids.end(),[&](const GUID& prior) { return prior == guid; }),"unique preset GUID");
      presetGuids.push_back(guid);
      LONG roundtrip = -1;
      Check(writer->GetPresetIndexFromGuid(&guid,&roundtrip) == S_OK && roundtrip == index,"GUID/index roundtrip");
      const auto snapshot = configuration::ReadRecipeSnapshot(value,GUID_VegasEncoderType);
      if (index < 2) {
        Check(value.U32(tpl::id) == static_cast<DWORD>(index),"preserved probe/general template ID");
        Check(snapshot.at("origin").is_null(),"general/probe template has no library origin");
        if (index == 1) {
          const GUID original = {0x381851c2,0x9c94,0x4bd2,{0x81,0x76,0xb4,0xb8,0x59,0x8b,0xe8,0x0d}};
          Check(guid == original && value.Name() == L"Vegas Encoder settings","preserved existing general template identity");
        }
        continue;
      }
      const auto& entry = catalog.at("vegas").at(index-2);
      Check(entry.at("index") == value.U32(tpl::id),"stable template ID despite retired enumeration entries");
      const auto& presets = catalog.at("presets");
      const auto source = std::find_if(presets.begin(),presets.end(),[&](const Json& p) { return p.at("recipe").at("id") == entry.at("presetId"); });
      Check(source != presets.end(),"starter resolves a shared app recipe");
      const auto normalized = ve::Normalize({{"recipe",source->at("recipe")}});
      Check(!ve::HasErrors(normalized.at("issues")) && ve::Canonical(snapshot.at("recipe")) == ve::Canonical(normalized.at("recipe")),"exporter and app recipe settings agree through real core");
      const Json media{{"video",{{"width",1920},{"height",1080},{"fps",{30000,1001}},{"pixfmt","p010le"},{"sar","1:1"}}},
                       {"audio",{{"rate",48000},{"channels",2},{"sampleFmt","f32le"}}},{"durationSec",nullptr}};
      auto paths = bundle.at("fixtures")[0].at("paths");
      paths["target"] = {{"id","vegas-native-v1"}};
      paths["output"] = "starter." + source->at("recipe").at("container").at("format").get<std::string>();
      const auto compiled = ve::Compile({{"recipe",snapshot.at("recipe")},{"media",media},{"paths",paths}});
      Check(!ve::HasErrors(compiled.at("issues")),"starter compiles for native target with project media");
      GUID expected{};
      Check(SUCCEEDED(CLSIDFromString((L"{" + Widen(entry.at("guid").get<std::string>()) + L"}").c_str(),&expected)) && guid == expected,"committed catalog GUID retained");
      Check(Utf8(value.Name().c_str()) == entry.at("name") && Utf8(test::VegasDisplayName(value).c_str()) == entry.at("name"),
            "starter shows its full catalog name in VEGAS 2026 (no missing first letter)");
      Check(ve::Canonical(snapshot.at("origin")) == ve::Canonical(Json({{"presetId",entry.at("presetId")},{"revision",source->at("revision")},{"name",source->at("recipe").at("name")}})),"origin links app ID, revision and name");
      const auto bih = value.Bih(tpl::videoRenderBih);
      Check(bih.biWidth == 0 && bih.biHeight == 0,"starter follows project dimensions");
      wchar_t suffix[32]{};
      const auto wildcard = L"*." + Widen(source->at("recipe").at("container").at("format").get<std::string>());
      Check(writer->GetTemplateInfo(value.Ptr(),reinterpret_cast<BYTE*>(suffix),32,11) == S_OK && suffix == wildcard,"starter's active container controls filename suffix");
      // A saved/customized old revision must not be replaced by fresh defaults
      // just because its GUID still identifies a built-in starter.
      auto saved = snapshot;
      saved["recipe"]["notes"] = "Saved local changes";
      saved["origin"]["revision"] = 1;
      const auto customized = configuration::ReplaceRecipeSnapshot(value,GUID_VegasEncoderType,saved);
      SFTEMPLATE* conformed = nullptr;
      Check(writer->ConformTemplate(&conformed,customized.Ptr(),2) == S_OK && conformed,"saved starter conformance");
      Check(ve::Canonical(configuration::ReadRecipeSnapshot(Tpl::Copy(conformed),GUID_VegasEncoderType)) == ve::Canonical(saved),"saved recipe and origin survive conformance without library/default refresh");
      allocator.Free(conformed);
      returned = nullptr;
      Check(writer->GetPreset(&returned,index) == S_OK && returned,"fresh starter remains available");
      Check(configuration::ReadRecipeSnapshot(Tpl::Copy(returned),GUID_VegasEncoderType) == snapshot,"customizing one template leaves supplied default unchanged");
      allocator.Free(returned);
    }
    for (const auto& retired : catalog.at("retiredVegas")) {
      GUID guid{};
      Check(SUCCEEDED(CLSIDFromString((L"{" + Widen(retired.at("guid").get<std::string>()) + L"}").c_str(),&guid)),"retired catalog GUID parses");
      LONG index = -1;
      Check(writer->GetPresetIndexFromGuid(&guid,&index) == E_INVALIDARG,"retired preset is no longer enumerated");
      auto old = Tpl::Make(L"My saved personal preset",L"",0);
      old.SetGuid(tpl::iidOwner,GUID_VegasEncoderType);
      old.SetGuid(tpl::guidPreset,guid);
      old.SetU32(tpl::id,retired.at("index").get<DWORD>());
      const auto saved = configuration::CreateRecipeTemplate(old,GUID_VegasEncoderType,
          {{"recipe",bundle.at("fixtures")[0].at("recipe")},
           {"origin",{{"presetId",retired.at("presetId")},{"revision",1},{"name","Personal settings"}}},
           {"vegasPrefs",Json::object()},{"writtenBy","retired-preset-test"}});
      SFTEMPLATE* conformed = nullptr;
      Check(writer->ConformTemplate(&conformed,saved.Ptr(),2) == S_OK && conformed,"retired starter snapshot still conforms");
      const auto restored = Tpl::Copy(conformed); allocator.Free(conformed);
      Check(restored.U32(tpl::id) == old.U32(tpl::id) &&
            configuration::ReadRecipeSnapshot(restored,GUID_VegasEncoderType) == configuration::ReadRecipeSnapshot(saved,GUID_VegasEncoderType),
            "retired starter retains saved recipe, origin and ID without catalog lookup");
    }
    auto recipe = bundle.at("fixtures")[0].at("recipe");
    auto empty = Tpl::Make(L"Naming",L"",0); empty.SetGuid(tpl::iidOwner,GUID_VegasEncoderType);
    for (const auto& extension : {L".mkv",L".mp4",L".mov",L".webm",L".mxf"}) {
      recipe["container"]["format"] = Utf8(extension+1);
      recipe = ve::Normalize({{"recipe",recipe}}).at("recipe");
      if (ve::HasErrors(ve::Structural(recipe))) throw std::runtime_error(ve::Structural(recipe).dump());
      const auto value = configuration::CreateRecipeTemplate(empty,GUID_VegasEncoderType,{{"recipe",recipe},{"origin",nullptr},{"vegasPrefs",Json::object()},{"writtenBy","naming-test"}});
      const auto before = value.b;
      const auto wildcard = L"*"+std::wstring(extension);
      wchar_t buffer[264]; std::fill(std::begin(buffer),std::end(buffer),wchar_t{0x5555});
      Check(writer->GetTemplateInfo(value.Ptr(),reinterpret_cast<BYTE*>(buffer),260,11) == S_OK,"template wildcard callback");
      Check(buffer == wildcard && buffer[260] == 0x5555,"correct per-container wildcard and bounded host-sized write");
      std::fill(std::begin(buffer),std::end(buffer),wchar_t{0x5555});
      const auto exact = static_cast<LONG>(wildcard.size()+1);
      Check(writer->GetTemplateInfo(value.Ptr(),reinterpret_cast<BYTE*>(buffer),exact,11) == S_OK && buffer == wildcard && buffer[exact] == 0x5555,"capacity is UTF-16 characters including terminator");
      Check(writer->GetTemplateInfo(value.Ptr(),reinterpret_cast<BYTE*>(buffer),exact-1,11) == HRESULT_FROM_WIN32(ERROR_INSUFFICIENT_BUFFER) && !buffer[0],"short buffer refused and cleared");
      Check(writer->GetTemplateInfo(value.Ptr(),reinterpret_cast<BYTE*>(buffer),0,11) == E_INVALIDARG,"zero capacity refused");
      Check(writer->GetTemplateInfo(value.Ptr(),nullptr,32,11) == E_POINTER,"null output refused");
      Check(writer->GetTemplateInfo(value.Ptr(),reinterpret_cast<BYTE*>(buffer),32,9) == E_NOTIMPL,"unknown selector unchanged");
      Check(value.b == before,"naming does not mutate snapshot");
      SFTEMPLATE* conformed = nullptr;
      Check(writer->ConformTemplate(&conformed,value.Ptr(),2) == S_OK && conformed,"host conformance");
      Check(writer->GetTemplateInfo(conformed,reinterpret_cast<BYTE*>(buffer),32,11) == S_OK && buffer == wildcard,"naming survives source conformance");
      allocator.Free(conformed);
    }
    // Advanced's active muxer wins over inactive Basic controls.
    recipe["container"]["format"] = "mp4";
    recipe["command"] = {{"mode","template"},{"template","ffmpeg {inputs} -c:v libvpx-vp9 -an -f webm {output}"}};
    recipe = ve::Normalize({{"recipe",recipe}}).at("recipe");
    const auto advanced = configuration::CreateRecipeTemplate(empty,GUID_VegasEncoderType,{{"recipe",recipe},{"origin",nullptr},{"vegasPrefs",Json::object()},{"writtenBy","naming-test"}});
    wchar_t buffer[32]{};
    Check(writer->GetTemplateInfo(advanced.Ptr(),reinterpret_cast<BYTE*>(buffer),32,11) == S_OK && wcscmp(buffer,L"*.webm") == 0,"Advanced active-command naming");
    auto corrupt = advanced; corrupt.b[tpl::abExtra+20] ^= 1;
    Check(FAILED(writer->GetTemplateInfo(corrupt.Ptr(),reinterpret_cast<BYTE*>(buffer),32,11)) && !buffer[0],"corrupt snapshot never guesses a suffix");
    Check(writer->GetTemplateInfo(nullptr,reinterpret_cast<BYTE*>(buffer),32,11) == E_POINTER,"null template refused");
    Check(allocator.allocations == allocator.frees,"conformed template allocations balanced");
    writer->Release(); FreeLibrary(module);
    printf("Container naming and default presets: %d checks passed (candidate DLL, fake host; no real VEGAS).\n",checks);
    return 0;
  } catch (const std::exception& e) { fprintf(stderr,"Container naming failed: %s\n",e.what()); return 1; }
}
