// plugin.cpp - DLL exports, class factory, plug-in info and render class.
//
// Answers follow the calls VEGAS 2026.0.3 made to Voukoder Pro (F-031, F-036,
// F-038); unobserved methods return E_NOTIMPL and are logged so a capture
// shows whether the host relies on them.
#include "vegas_encoder.h"
#if defined(VEGAS_ENCODER_B6_RECIPE_PROOF)
#include "recipe_runtime.h"
#include "../configuration/recipe_template.h"
#endif
#if defined(VEGAS_ENCODER_CONFIGURATION_PROOF)
#include "../configuration/proof_page.h"
#endif

#include <new>

using namespace sfio;

// Distinct development identities; proof templates are not automatically migrated.
namespace vegas_encoder {
namespace {

const wchar_t kDisplayName[] = L"Vegas Encoder";

// Private template bytes (abExtra) so our templates are recognisable.
struct Extra {
  DWORD magic;    // 'VENC'
  DWORD version;  // 1
  DWORD preset;   // preset index, 0xFFFFFFFF for Project Settings
  DWORD reserved[13];
};
static_assert(sizeof(Extra) == 64, "abExtra is 64 bytes");
constexpr DWORD kExtraMagic = 0x434e4556;  // "VENC"

struct Preset {
  GUID guid;
  DWORD compression;
  const wchar_t* name;
  const wchar_t* notes;
};

// The template id is the preset index. VEGAS 2026 did not list the id-0 preset
// in Render As (F-041); Voukoder Pro also fills id 0 with a duplicate (F-033).
// Index 0 is therefore a probe that should stay hidden; the real presets
// start at id 1. P010 was delivered to Voukoder (F-031, F-036); BI_RGB 32 was
// delivered bottom-up through a direct-pointer token (F-041).
const Preset kPresets[] = {
#if defined(VEGAS_ENCODER_B6_RECIPE_PROOF)
    {{0x8f4af392, 0x31b0, 0x48c1, {0xa2, 0xa0, 0x4b, 0x40, 0xdf, 0x3f, 0x9c, 0x20}},
     MAKEFOURCC('P', '0', '1', '0'), L"Vegas Encoder recipe (id 0)", L"Recipe candidate; use the visible settings preset."},
    {{0x381851c2, 0x9c94, 0x4bd2, {0x81, 0x76, 0xb4, 0xb8, 0x59, 0x8b, 0xe8, 0x0d}},
     MAKEFOURCC('P', '0', '1', '0'), L"Vegas Encoder settings", L"Edit settings in the Vegas Encoder popup. Match the Render As filename to the selected container."},
#else
    {{0x5ac92e42, 0xf7bd, 0x4e84, {0x86, 0xe4, 0xaa, 0x50, 0xe4, 0xce, 0x44, 0x9b}},
     MAKEFOURCC('P', '0', '1', '0'),
     L"Raw P010 (id 0 probe; please report if visible)",
     L"Diagnostic: VEGAS is expected to hide template id 0. If you can see this, tell the developer."},
    {{0x3e941fe3, 0x405a, 0x4208, {0xba, 0x75, 0x5c, 0x89, 0xda, 0x74, 0x05, 0xab}},
     MAKEFOURCC('P', '0', '1', '0'),
     L"Raw P010 10-bit 4:2:0 + float WAV",
     L"Diagnostic: writes delivered frames and samples unmodified, plus a manifest."},
    {{0x76831cef, 0xae0f, 0x45c1, {0xb8, 0x8b, 0x21, 0x73, 0xf9, 0x38, 0xe1, 0x2b}},
     BI_RGB,
     L"Raw BI_RGB 32-bit + float WAV",
     L"Diagnostic: 8-bit BGRA, bottom-up rows, as VEGAS delivers it."},
#endif
};
constexpr LONG kPresetCount = (LONG)(sizeof kPresets / sizeof kPresets[0]);
LONG PresetCount() { return Cfg().encode ? 2 : kPresetCount; }

#if !defined(VEGAS_ENCODER_B6_RECIPE_PROOF)
void SetExtra(Tpl& t, DWORD preset) {
  Extra e{};
  e.magic = kExtraMagic;
  e.version = 1;
  e.preset = preset;
  memcpy(t.b.data() + tpl::abExtra, &e, sizeof e);
}
#endif

Tpl BuildPreset(LONG index) {
  const Preset& p = kPresets[index];
#if defined(VEGAS_ENCODER_B6_RECIPE_PROOF)
  Tpl t = Tpl::Make(p.name, p.notes, 0);
#else
  const wchar_t* name = Cfg().encode && index == 1 ? L"Lossless P010 10-bit + float audio (MKV)" : p.name;
  const wchar_t* notes = Cfg().encode ? L"Fixed FFmpeg proof: FFV1 video + PCM float stereo; settings in vegas-encoder.ini." : p.notes;
  Tpl t = Tpl::Make(name, notes, sizeof(Extra));
#endif
  // Byte pattern mirrors Voukoder Pro's presets (F-033): zero audio records
  // and zero size/fps mean "use the project".
  t.SetU32(tpl::id, (DWORD)index);
  t.SetGuid(tpl::iidOwner, GUID_VegasEncoderType);
  t.SetGuid(tpl::guidPreset, p.guid);
  t.SetU32(tpl::audioCb, tpl::sectionCb);
  t.SetU32(tpl::audioStreams, 1);
  t.SetU32(tpl::videoCb, tpl::sectionCb);
  t.SetU32(tpl::videoStreams, 1);
  BITMAPINFOHEADER h{};
  h.biSize = sizeof h;
  h.biPlanes = 1;
  h.biBitCount = 32;
  h.biCompression = p.compression;
  t.SetBih(tpl::videoRenderBih, h);
  t.SetBih(tpl::videoCodecBih, h);
  t.SetU32(tpl::videoRenderVex + 0x0, (DWORD)tpl::vexSize);
  t.SetU32(tpl::videoRenderVex + 0x4, 0xFFFFFFFF);
  t.SetU32(tpl::videoRenderVex + 0xC, 0xFFFFFFFF);
  t.SetF64(tpl::vexPixelAspect, 1.0);
  t.SetU32(tpl::keyFrameEvery, 1);
#if defined(VEGAS_ENCODER_B6_RECIPE_PROOF)
  t = configuration::CreateRecipeTemplate(t, GUID_VegasEncoderType, DefaultRecipeSnapshot());
#else
  SetExtra(t, (DWORD)index);
#endif
  return t;
}

// --- Render class ------------------------------------------------------------

class RenderClass final : public ISfRenderFileClass {
 public:
  ~RenderClass() {
    if (alloc_) alloc_->Release();
  }

  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void** ppv) override {
    return NativeBoundary([&]() -> HRESULT {
      if (!ppv) return E_POINTER;
      if (riid == IID_IUnknown || riid == __uuidof(ISfRenderFileClass)) {
        *ppv = static_cast<ISfRenderFileClass*>(this);
        AddRef();
        return S_OK;
      }
      *ppv = nullptr;
      if (LogDetail("class.qi")) BestEffortDiagnostic([&] { Log("RenderClass::QueryInterface(%s) -> E_NOINTERFACE", GuidText(riid).c_str()); });
      return E_NOINTERFACE;
    });
  }
  ULONG STDMETHODCALLTYPE AddRef() override { return (ULONG)InterlockedIncrement(&ref_); }
  ULONG STDMETHODCALLTYPE Release() override {
    LONG n = InterlockedDecrement(&ref_);
    if (n == 0) {
      BestEffortDiagnostic([&] { Log("RenderClass destroyed"); });
      delete this;
    }
    return (ULONG)n;
  }

  HRESULT STDMETHODCALLTYPE SetHostInterface(IUnknown* host) override {
    return NativeBoundary([&]() -> HRESULT {
      ISfHostAllocator* a = nullptr;
      HRESULT hr = host ? host->QueryInterface(IID_SfHostAllocator, (void**)&a) : E_POINTER;
      if (SUCCEEDED(hr) && a) {
        ISfHostAllocator* old = (ISfHostAllocator*)InterlockedExchangePointer((void**)&alloc_, a);
        if (old) old->Release();
      }
      BestEffortDiagnostic([&] { Log("SetHostInterface(%p): allocator QI %s -> %p", (void*)host, Hr(hr).c_str(), (void*)a); });
      return S_OK;
    });
  }

  HRESULT STDMETHODCALLTYPE GetTypeID(GUID* g) override {
    return NativeBoundary([&]() -> HRESULT {
      if (!g) return E_POINTER;
      *g = GUID_VegasEncoderType;
      if (LogDetail("class.4")) BestEffortDiagnostic([&] { Log("GetTypeID -> %s", GuidText(*g).c_str()); });
      return S_OK;
    });
  }
  HRESULT STDMETHODCALLTYPE GetAllowedStreamTypes(DWORD* v) override {
    return NativeBoundary([&]() -> HRESULT {
      if (!v) return E_POINTER;
      *v = Cfg().streamTypes;
      if (LogDetail("class.5")) BestEffortDiagnostic([&] { Log("GetAllowedStreamTypes -> 0x%lx", *v); });
      return S_OK;
    });
  }
  HRESULT STDMETHODCALLTYPE GetCaps(DWORD* v) override {
    return NativeBoundary([&]() -> HRESULT {
      if (!v) return E_POINTER;
      *v = Cfg().caps;
      if (LogDetail("class.6")) BestEffortDiagnostic([&] { Log("GetCaps -> 0x%lx", *v); });
      return S_OK;
    });
  }
  HRESULT STDMETHODCALLTYPE GetReadClassGuid(GUID* g) override {
    return NativeBoundary([&]() -> HRESULT {
      if (!g) return E_POINTER;
      *g = GUID_NULL;  // no reader class (FrameServer does the same)
      BestEffortDiagnostic([&] { Log("GetReadClassGuid -> GUID_NULL"); });
      return S_OK;
    });
  }

  HRESULT STDMETHODCALLTYPE GetStrings(const LONG* ids, LONG count, BSTR* strings) override {
    return NativeBoundary([&]() -> HRESULT {
      if (!ids || !strings || count < 0) return E_POINTER;
      for (LONG i = 0; i < count; i++) strings[i] = nullptr;
      const bool encode = Cfg().encode;
      for (LONG i = 0; i < count; i++) {
        // Ids paired by position with FrameServer's SFFIO_FILECLASS_TEXT_* list
        // and Voukoder's answers (F-033): 1 brief, 2 long, 4 extensions, 5 localized.
        const wchar_t* s = nullptr;
        switch (ids[i]) {
          case 1: s = kDisplayName; break;
          case 2: s = kDisplayName; break;
          case 4: s = encode ? L"*.mkv" : L"*.ffdiag"; break;
          case 5: s = kDisplayName; break;
        }
        strings[i] = s ? SysAllocString(s) : nullptr;
        if (s && !strings[i]) {
          for (LONG j = 0; j < i; j++) {
            SysFreeString(strings[j]);
            strings[j] = nullptr;
          }
          return E_OUTOFMEMORY;
        }
        if (LogDetail("class.8")) BestEffortDiagnostic([&] { Log("GetStrings id %ld -> %s", ids[i], s ? Utf8(s).c_str() : "(null)"); });
      }
      return S_OK;
    });
  }

  HRESULT STDMETHODCALLTYPE Open(ISfRenderFile** file, LONG h, LPCWSTR path) override {
    return NativeBoundary([&]() -> HRESULT {
      if (file) *file = nullptr;
      BestEffortDiagnostic([&] { Log("Open(h=%ld, path=%s) -> E_NOTIMPL", h, Utf8(path).c_str()); });
      return E_NOTIMPL;
    });
  }

  HRESULT STDMETHODCALLTYPE Create(ISfRenderFile** file, LPCWSTR path, LONG cStreams,
                                   ISfReadStream** streams, const SFTEMPLATE* t) override {
    return NativeBoundary([&]() -> HRESULT {
      BestEffortDiagnostic([&] { Log("Create(path=%s, cStreams=%ld, streams=%p, template=%p)", path ? Utf8(path).c_str() : "(null)",
          cStreams, (void*)streams, (const void*)t); });
      LogTemplate("create template", t, true);
      if (!file) return E_POINTER;
      *file = nullptr;
      if (!Tpl::Valid(t)) return E_INVALIDARG;
      ISfRenderFile* f = nullptr;
      HRESULT hr = CreateRenderFile(t, &f);
      if (SUCCEEDED(hr) && path) hr = f->SetFile(path);
      for (LONG i = 0; SUCCEEDED(hr) && streams && i < cStreams; i++) hr = f->SetStreamReader(streams[i], i);
      if (FAILED(hr)) {
        if (f) f->Release();
        BestEffortDiagnostic([&] { Log("Create -> %s", Hr(hr).c_str()); });
        return hr;
      }
      *file = f;
      BestEffortDiagnostic([&] { Log("Create -> S_OK file=%p", (void*)f); });
      return S_OK;
    });
  }

  HRESULT STDMETHODCALLTYPE GetPresetCount(LONG* count) override {
    return NativeBoundary([&]() -> HRESULT {
      if (!count) return E_POINTER;
      *count = PresetCount();
      if (LogDetail("class.11")) BestEffortDiagnostic([&] { Log("GetPresetCount -> %ld", *count); });
      return S_OK;
    });
  }

  HRESULT STDMETHODCALLTYPE GetPreset(SFTEMPLATE** out, LONG index) override {
    return NativeBoundary([&]() -> HRESULT {
      if (!out) return E_POINTER;
      *out = nullptr;
      if (index < 0 || index >= PresetCount()) return E_INVALIDARG;
      HRESULT hr = ToHost(BuildPreset(index), out);
      bool detail = LogDetail("class.12");
      if (detail || FAILED(hr)) BestEffortDiagnostic([&] { Log("GetPreset(%ld) -> %s", index, Hr(hr).c_str()); });
      if (detail && SUCCEEDED(hr)) LogTemplate("preset", *out, index == 0 && LogDetail("class.12.dump"));
      return hr;
    });
  }

  HRESULT STDMETHODCALLTYPE GetPresetIndexFromGuid(const GUID* g, LONG* index) override {
    return NativeBoundary([&]() -> HRESULT {
      if (!g || !index) return E_POINTER;
      *index = 0;
      for (LONG i = 0; i < PresetCount(); i++)
        if (*g == kPresets[i].guid) {
          *index = i;
          BestEffortDiagnostic([&] { Log("GetPresetIndexFromGuid(%s) -> %ld", GuidText(*g).c_str(), i); });
          return S_OK;
        }
      BestEffortDiagnostic([&] { Log("GetPresetIndexFromGuid(%s) -> E_INVALIDARG", GuidText(*g).c_str()); });
      return E_INVALIDARG;
    });
  }

  HRESULT STDMETHODCALLTYPE ChooseBestPreset(const SFTEMPLATE* t, LONG rules, LONG* index) override {
    return NativeBoundary([&]() -> HRESULT {
      if (!index) return E_POINTER;
      *index = 0;
      BestEffortDiagnostic([&] { Log("ChooseBestPreset(rules=%ld) -> 0", rules); });
      LogTemplate("match", t, false);
      return S_OK;
    });
  }

  // "Project Settings" template from the host project template. Observed
  // only with reason 2 (F-036); other reasons are refused like FrameServer.
  HRESULT STDMETHODCALLTYPE ConformTemplate(SFTEMPLATE** out, const SFTEMPLATE* src, LONG reason) override {
    return NativeBoundary([&]() -> HRESULT {
      bool detail = LogDetail("class.15");
      if (detail) {
        BestEffortDiagnostic([&] { Log("ConformTemplate(reason=%ld)", reason); });
        LogTemplate("source", src, LogDetail("class.15.dump"));
      }
      if (!out) return E_POINTER;
      *out = nullptr;
      if (reason != 2) {
        BestEffortDiagnostic([&] { Log("ConformTemplate reason %ld -> E_INVALIDARG", reason); });
        return E_INVALIDARG;
      }
      if (!Tpl::Valid(src)) return E_INVALIDARG;
      Tpl s = Tpl::Copy(src);
#if defined(VEGAS_ENCODER_B6_RECIPE_PROOF)
      Tpl t = Tpl::Make(L"Project Settings", L"Vegas Encoder recipe", 0);
#else
      Tpl t = Tpl::Make(L"Project Settings", L"Render Audio and Video", sizeof(Extra));
#endif
      t.SetU32(tpl::id, s.U32(tpl::id));
      t.SetGuid(tpl::iidOwner, GUID_VegasEncoderType);
      t.SetU32(tpl::audioCb, tpl::sectionCb);
      t.SetU32(tpl::audioStreams, 1);
      SFAUDIORECORD a = s.Audio(tpl::audioRender);
      if (a.sampleRate && a.channels) {
        t.SetAudio(tpl::audioRender, Float32Record(a.sampleRate, a.channels));
        t.SetAudio(tpl::audioCodec, t.Audio(tpl::audioRender));
      }
      t.SetU32(tpl::videoCb, tpl::sectionCb);
      t.SetU32(tpl::videoStreams, 1);
      memcpy(t.b.data() + tpl::videoRenderBih, s.b.data() + tpl::videoRenderBih, sizeof(BITMAPINFOHEADER));
      memcpy(t.b.data() + tpl::videoRenderVex, s.b.data() + tpl::videoRenderVex, tpl::vexSize);
      BITMAPINFOHEADER codec = s.Bih(tpl::videoCodecBih);
      t.SetBih(tpl::videoCodecBih, codec.biWidth ? codec : t.Bih(tpl::videoRenderBih));
#if defined(VEGAS_ENCODER_B6_RECIPE_PROOF)
      auto snapshot = s.Guid(tpl::iidOwner) == GUID_VegasEncoderType ?
          configuration::ReadRecipeSnapshot(s, GUID_VegasEncoderType) : DefaultRecipeSnapshot();
      // The candidate accepts P010 input only. Never inherit a project RGB codec.
      auto input = t.Bih(tpl::videoRenderBih);
      input.biCompression = MAKEFOURCC('P', '0', '1', '0'); input.biBitCount = 32;
      t.SetBih(tpl::videoRenderBih, input); t.SetBih(tpl::videoCodecBih, input);
      t = configuration::CreateRecipeTemplate(t, GUID_VegasEncoderType, snapshot);
#else
      SetExtra(t, 0xFFFFFFFF);
#endif
      HRESULT hr = ToHost(t, out);
      if (detail || FAILED(hr)) {
        BestEffortDiagnostic([&] { Log("ConformTemplate -> %s", Hr(hr).c_str()); });
        if (SUCCEEDED(hr)) LogTemplate("project settings", *out, false);
      }
      return hr;
    });
  }

  // Fills project-default (zero) fields of `base` from `source` into a new
  // template. With no source the host passes *io == base and Voukoder returns
  // S_FALSE without touching it; the final Create template comes from two
  // reason-0 passes with *io == null (F-036, F-038).
  HRESULT STDMETHODCALLTYPE ConformTemplateToSource(SFTEMPLATE** io, const SFTEMPLATE* base,
                                                    const SFTEMPLATE* source, LONG reason) override {
    return NativeBoundary([&]() -> HRESULT {
      bool detail = LogDetail("class.16");
      if (detail)
        BestEffortDiagnostic([&] { Log("ConformTemplateToSource(reason=%ld, *io=%p, base=%p, source=%p)", reason,
            io ? (void*)*io : nullptr, (const void*)base, (const void*)source); });
      if (!io || !base) return E_POINTER;
      if (!source) {
        if (detail) BestEffortDiagnostic([&] { Log("ConformTemplateToSource -> S_FALSE (no source)"); });
        return S_FALSE;
      }
      if (!Tpl::Valid(base) || !Tpl::Valid(source)) return E_INVALIDARG;
      if (*io && *io != base) BestEffortDiagnostic([&] { Log("ConformTemplateToSource: *io=%p was set; replacing", (void*)*io); });
      Tpl t = Tpl::Copy(base);
      Tpl s = Tpl::Copy(source);
      if (t.Zero(tpl::audioRender, sizeof(SFAUDIORECORD))) {
        SFAUDIORECORD a = s.Audio(tpl::audioRender);
        if (a.sampleRate && a.channels) t.SetAudio(tpl::audioRender, Float32Record(a.sampleRate, a.channels));
      }
      if (t.Zero(tpl::audioCodec, sizeof(SFAUDIORECORD))) t.SetAudio(tpl::audioCodec, t.Audio(tpl::audioRender));
      BITMAPINFOHEADER r = t.Bih(tpl::videoRenderBih), sr = s.Bih(tpl::videoRenderBih);
      if (r.biWidth == 0) {
        r.biWidth = sr.biWidth;
        r.biHeight = sr.biHeight;
      }
      if (r.biSize == 0) r.biSize = sizeof r;
      if (r.biPlanes == 0) r.biPlanes = 1;
      if (r.biBitCount == 0) r.biBitCount = sr.biBitCount;
      t.SetBih(tpl::videoRenderBih, r);
      if (t.F64(tpl::vexFps) == 0.0)
        memcpy(t.b.data() + tpl::videoRenderVex, s.b.data() + tpl::videoRenderVex, tpl::vexSize);
      if (t.Bih(tpl::videoCodecBih).biWidth == 0) t.SetBih(tpl::videoCodecBih, r);
      HRESULT hr = ToHost(t, io);
      if (detail || FAILED(hr)) {
        BestEffortDiagnostic([&] { Log("ConformTemplateToSource -> %s", Hr(hr).c_str()); });
        LogTemplate("base", base, false);
        LogTemplate("source", source, false);
        if (SUCCEEDED(hr)) LogTemplate("result", *io, LogDetail("class.16.dump"));
      }
      return hr;
    });
  }

  HRESULT STDMETHODCALLTYPE GetTemplateInfo(const SFTEMPLATE*, BYTE*, LONG cb, LONG type) override {
    return NativeBoundary([&]() -> HRESULT {
      // Voukoder Pro returns E_NOTIMPL to every observed call (F-038).
      if (LogDetail("class.17")) BestEffortDiagnostic([&] { Log("GetTemplateInfo(cb=%ld, type=%ld) -> E_NOTIMPL", cb, type); });
      return E_NOTIMPL;
    });
  }

  HRESULT STDMETHODCALLTYPE GetPropertyPageCount(LONG* free, LONG* forSale, LONG* options) override {
    return NativeBoundary([&]() -> HRESULT {
      constexpr LONG count =
#if defined(VEGAS_ENCODER_CONFIGURATION_PROOF) || defined(VEGAS_ENCODER_B6_RECIPE_PROOF)
          1;
#else
          0;
#endif
      if (free) *free = count;
      if (forSale) *forSale = 0;
      if (options) *options = 0;
      if (LogDetail("class.18")) BestEffortDiagnostic([&] { Log("GetPropertyPageCount -> %ld, 0, 0", count); });
      return S_OK;
    });
  }
  HRESULT STDMETHODCALLTYPE GetPropertyPage(LONG index, IPropertyPage** page) override {
    return NativeBoundary([&]() -> HRESULT {
      if (page) *page = nullptr;
#if defined(VEGAS_ENCODER_CONFIGURATION_PROOF)
      if (!page) return E_POINTER;
      if (index == 0) return configuration::CreateNativeProofPage(alloc_, page);
#elif defined(VEGAS_ENCODER_B6_RECIPE_PROOF)
      if (!page) return E_POINTER;
      if (index == 0) return configuration::CreateNativeRecipePage(alloc_, RecipeEditorOptions(), page);
#endif
      BestEffortDiagnostic([&] { Log("GetPropertyPage(%ld) -> E_INVALIDARG", index); });
      return E_INVALIDARG;
    });
  }
  HRESULT STDMETHODCALLTYPE BuyPropertyPages(HWND) override {
    return NativeBoundary([&]() -> HRESULT {
      BestEffortDiagnostic([&] { Log("BuyPropertyPages -> E_NOTIMPL"); });
      return E_NOTIMPL;
    });
  }
  HRESULT STDMETHODCALLTYPE HasAboutBox() override {
    return NativeBoundary([&]() -> HRESULT {
      if (LogDetail("class.21")) BestEffortDiagnostic([&] { Log("HasAboutBox -> S_OK"); });
      return S_OK;
    });
  }
  HRESULT STDMETHODCALLTYPE ShowAboutBox(HWND parent) override {
    return NativeBoundary([&]() -> HRESULT {
      BestEffortDiagnostic([&] { Log("ShowAboutBox"); });
      std::wstring text = std::wstring(kDisplayName) + L" " + Widen(kVersion) +
#if defined(VEGAS_ENCODER_B6_RECIPE_PROOF)
                          L"\n\nRecipe-based container candidate.\nLog folder: " +
#else
                          L"\n\nFixed FFmpeg lossless MKV or raw diagnostic output.\nLog folder: " +
#endif
                          Cfg().logDir;
      MessageBoxW(parent, text.c_str(), kDisplayName, MB_OK | MB_ICONINFORMATION);
      return S_OK;
    });
  }
  HRESULT STDMETHODCALLTYPE GetStatus(LONG* status, BSTR* text) override {
    return NativeBoundary([&]() -> HRESULT {
      (void)status;
      (void)text;
      if (LogDetail("class.23")) BestEffortDiagnostic([&] { Log("GetStatus -> E_NOTIMPL"); });
      return E_NOTIMPL;
    });
  }

 private:
  HRESULT ToHost(const Tpl& t, SFTEMPLATE** out) {
    // Every template handed to the host comes from its allocator (F-033).
    ISfHostAllocator* a = alloc_;
    if (!a) {
      BestEffortDiagnostic([&] { Log("no host allocator; cannot return a template"); });
      return E_UNEXPECTED;
    }
    void* p = a->Alloc(t.b.size());
    if (!p) return E_OUTOFMEMORY;
    memcpy(p, t.b.data(), t.b.size());
    *out = (SFTEMPLATE*)p;
    return S_OK;
  }

  LONG ref_ = 1;
  ISfHostAllocator* alloc_ = nullptr;
};

// --- Plug-in info ------------------------------------------------------------

class PluginInfo final : public ISfUnsharedFIOPluginInfo {
 public:
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void** ppv) override {
    return NativeBoundary([&]() -> HRESULT {
      if (!ppv) return E_POINTER;
      if (riid == IID_IUnknown || riid == __uuidof(ISfUnsharedFIOPluginInfo)) {
        *ppv = static_cast<ISfUnsharedFIOPluginInfo*>(this);
        AddRef();
        return S_OK;
      }
      *ppv = nullptr;
      BestEffortDiagnostic([&] { Log("PluginInfo::QueryInterface(%s) -> E_NOINTERFACE", GuidText(riid).c_str()); });
      return E_NOINTERFACE;
    });
  }
  ULONG STDMETHODCALLTYPE AddRef() override { return (ULONG)InterlockedIncrement(&ref_); }
  ULONG STDMETHODCALLTYPE Release() override {
    LONG n = InterlockedDecrement(&ref_);
    if (n == 0) delete this;
    return (ULONG)n;
  }
  HRESULT STDMETHODCALLTYPE Init(LPCWSTR key, LONG grade, LONG demo) override {
    return NativeBoundary([&]() -> HRESULT {
      BestEffortDiagnostic([&] { Log("PluginInfo::Init(%s, %ld, %ld)", Utf8(key).c_str(), grade, demo); });
      return S_OK;
    });
  }
  HRESULT STDMETHODCALLTYPE GetFilterCount(LONG* count) override {
    return NativeBoundary([&]() -> HRESULT {
      if (!count) return E_POINTER;
      *count = 1;
      BestEffortDiagnostic([&] { Log("GetFilterCount -> 1"); });
      return S_OK;
    });
  }
  HRESULT STDMETHODCALLTYPE GetFilterInfo(LONG index, GUID* clsid, LPWSTR name, LONG cchName, DWORD* access,
                                          DWORD* streamTypes, DWORD* app1, DWORD* app2, DWORD* app3,
                                          DWORD* app4, DWORD* expire, DWORD* flags) override {
    return NativeBoundary([&]() -> HRESULT {
      if (index != 0) return E_INVALIDARG;
      const Config& c = Cfg();
      if (clsid) *clsid = CLSID_VegasEncoderFilter;
      if (name && cchName > 0) wcsncpy_s(name, (size_t)cchName, kDisplayName, _TRUNCATE);
      if (access) *access = c.access;
      if (streamTypes) *streamTypes = c.streamTypes;
      for (DWORD* p : {app1, app2, app3, app4})
        if (p) *p = 0xFFFFFFFF;
      if (expire) *expire = 0;
      if (flags) *flags = c.pluginFlags;
      BestEffortDiagnostic([&] { Log("GetFilterInfo(0, cch=%ld) -> clsid %s access=0x%lx streamTypes=0x%lx flags=0x%lx", cchName,
          GuidText(CLSID_VegasEncoderFilter).c_str(), c.access, c.streamTypes, c.pluginFlags); });
      return S_OK;
    });
  }

 private:
  LONG ref_ = 1;
};

// --- Class factory -----------------------------------------------------------

class Factory final : public IClassFactory {
 public:
  explicit Factory(const GUID& clsid) : clsid_(clsid) {}
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void** ppv) override {
    return NativeBoundary([&]() -> HRESULT {
      if (!ppv) return E_POINTER;
      if (riid == IID_IUnknown || riid == IID_IClassFactory) {
        *ppv = static_cast<IClassFactory*>(this);
        AddRef();
        return S_OK;
      }
      *ppv = nullptr;
      return E_NOINTERFACE;
    });
  }
  ULONG STDMETHODCALLTYPE AddRef() override { return (ULONG)InterlockedIncrement(&ref_); }
  ULONG STDMETHODCALLTYPE Release() override {
    LONG n = InterlockedDecrement(&ref_);
    if (n == 0) delete this;
    return (ULONG)n;
  }
  HRESULT STDMETHODCALLTYPE CreateInstance(IUnknown* outer, REFIID riid, void** ppv) override {
    return NativeBoundary([&]() -> HRESULT {
      if (!ppv) return E_POINTER;
      *ppv = nullptr;
      if (outer) return CLASS_E_NOAGGREGATION;
      IUnknown* obj = nullptr;
      if (clsid_ == CLSID_SfMediaGetUnsharedTypeInfo) {
        if (riid == IID_IUnknown || riid == __uuidof(ISfUnsharedFIOPluginInfo)) obj = new PluginInfo;
      } else if (riid == IID_IUnknown || riid == __uuidof(ISfRenderFileClass)) {
        obj = new RenderClass;
      }
      HRESULT hr = E_NOINTERFACE;
      if (obj) {
        hr = obj->QueryInterface(riid, ppv);
        obj->Release();
      }
      const char* note = riid == IID_ISfReadFileClass ? " (render-only exporter; no reader class)" : "";
      BestEffortDiagnostic([&] { Log("CreateInstance(%s, %s) -> %s%s", GuidText(clsid_).c_str(), GuidText(riid).c_str(), Hr(hr).c_str(),
          note); });
      return hr;
    });
  }
  HRESULT STDMETHODCALLTYPE LockServer(BOOL) override {
    return NativeBoundary([&]() -> HRESULT {
      return S_OK;
    });
  }

 private:
  LONG ref_ = 1;
  GUID clsid_;
};

}  // namespace
}  // namespace vegas_encoder

using namespace vegas_encoder;

BOOL APIENTRY DllMain(HINSTANCE inst, DWORD reason, LPVOID) {
  if (reason == DLL_PROCESS_ATTACH) {
    g_module = inst;
    DisableThreadLibraryCalls(inst);
  }
  return TRUE;
}

STDAPI DllGetClassObject(REFCLSID clsid, REFIID riid, void** ppv) {
  return NativeBoundary([&]() -> HRESULT {
    if (!ppv) return E_POINTER;
    *ppv = nullptr;
    HRESULT hr = CLASS_E_CLASSNOTAVAILABLE;
    if (clsid == CLSID_SfMediaGetUnsharedTypeInfo || clsid == CLSID_VegasEncoderFilter) {
      Factory* f = new Factory(clsid);
      hr = f->QueryInterface(riid, ppv);
      f->Release();
    }
    BestEffortDiagnostic([&] { Log("DllGetClassObject(%s, %s) -> %s", GuidText(clsid).c_str(), GuidText(riid).c_str(), Hr(hr).c_str()); });
    return hr;
  });
}

// The host may hold pointers into this module for its whole lifetime.
STDAPI DllCanUnloadNow() {
  return NativeBoundary([&]() -> HRESULT {
    return S_FALSE;
  });
}

// Exported like FrameServer and Voukoder; VEGAS was not seen calling it (F-033).
extern "C" void STDAPICALLTYPE DllInitClasses(BOOL loading) { BestEffortDiagnostic([&] { Log("DllInitClasses(%d)", loading); }); }

STDAPI DllRegisterServer() {
  return NativeBoundary([&]() -> HRESULT {
    return E_NOTIMPL;
  });
}
STDAPI DllUnregisterServer() {
  return NativeBoundary([&]() -> HRESULT {
    return E_NOTIMPL;
  });
}
