// Actual candidate DLL callbacks with a fake allocator; no VEGAS/FFmpeg launch.
#include "../../src/vegas/adapter/vegas_encoder.h"
#include "../../src/vegas/configuration/recipe_template.h"
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
    if (argc != 3) throw std::runtime_error("Pass candidate DLL and authored core fixtures.");
    const auto module = LoadLibraryW(argv[1]); Check(module != nullptr,"load candidate DLL");
    using GetClass = HRESULT (STDAPICALLTYPE*)(REFCLSID,REFIID,void**);
    const auto getClass = reinterpret_cast<GetClass>(GetProcAddress(module,"DllGetClassObject"));
    Check(getClass != nullptr,"candidate factory export");
    IClassFactory* factory = nullptr;
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
    printf("Container naming: %d checks passed (candidate DLL, fake host; no real VEGAS).\n",checks);
    return 0;
  } catch (const std::exception& e) { fprintf(stderr,"Container naming failed: %s\n",e.what()); return 1; }
}
