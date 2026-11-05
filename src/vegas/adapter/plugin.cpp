// plugin.cpp - DLL exports, class factory, plug-in info and render class.
//
// Answers follow the calls VEGAS 2026.0.3 made to Voukoder Pro (F-031, F-036,
// F-038); unobserved methods return E_NOTIMPL and are logged so a capture
// shows whether the host relies on them.
#include "vegas_encoder.h"
#include "render_formats.h"
#if defined(VEGAS_ENCODER_B6_RECIPE_PROOF)
#include "recipe_runtime.h"
#include "../configuration/recipe_template.h"
#endif
#if defined(VEGAS_ENCODER_CONFIGURATION_PROOF)
#include "../configuration/proof_page.h"
#endif

#include <new>
#if defined(VEGAS_ENCODER_LEGACY_HOST)
#include <filesystem>
#endif

using namespace sfio;

// Distinct development identities; proof templates are not automatically migrated.
namespace vegas_encoder {
namespace {

const wchar_t kDisplayName[] = L"Vegas Encoder";
#if defined(VEGAS_ENCODER_B6_RECIPE_PROOF)
const wchar_t kEncodeExtensions[] = L"*.mkv;*.mp4;*.mov;*.webm;*.mxf";
// Nominal class suffix for LegacyAutoNames; never written to disk.
const wchar_t kLegacyPlaceholderExtensions[] = L"*.vencoder";
#else
const wchar_t kEncodeExtensions[] = L"*.mkv"; // Historical fixed-profile proof.
#endif

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
  const char* builtin = nullptr; // Generated library preset JSON; null for the general template.
  DWORD templateId = 0xFFFFFFFF; // Stable built-in identity, independent of enumeration position.
};

// Template IDs originally matched enumeration indices. Retiring a built-in leaves
// its ID unused; remaining GUIDs/IDs stay stable as enumeration becomes shorter.
// VEGAS 2026 did not list the id-0 preset
// in Render As (F-041); Voukoder Pro also fills id 0 with a duplicate (F-033).
// Index 0 is therefore a probe that should stay hidden; the real presets
// start at id 1. P010 was delivered to Voukoder (F-031, F-036); BI_RGB 32 was
// delivered bottom-up through a direct-pointer token (F-041).
const Preset kPresets[] = {
#if defined(VEGAS_ENCODER_B6_RECIPE_PROOF)
    {{0x8f4af392, 0x31b0, 0x48c1, {0xa2, 0xa0, 0x4b, 0x40, 0xdf, 0x3f, 0x9c, 0x20}},
     MAKEFOURCC('P', '0', '1', '0'), L"Vegas Encoder recipe (id 0)", L"Recipe candidate; use the visible settings preset."},
    {{0x381851c2, 0x9c94, 0x4bd2, {0x81, 0x76, 0xb4, 0xb8, 0x59, 0x8b, 0xe8, 0x0d}},
     MAKEFOURCC('P', '0', '1', '0'), L"Vegas Encoder settings", L"Edit settings in the Vegas Encoder popup. The output file uses the container chosen there."},
#include "builtin_presets.generated.inc"
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
LONG PresetCount() {
#if defined(VEGAS_ENCODER_B6_RECIPE_PROOF)
  return kPresetCount;
#else
  return Cfg().encode ? 2 : kPresetCount;
#endif
}

#if !defined(VEGAS_ENCODER_B6_RECIPE_PROOF)
void SetExtra(Tpl& t, DWORD preset) {
  Extra e{};
  e.magic = kExtraMagic;
  e.version = 1;
  e.preset = preset;
  memcpy(t.b.data() + tpl::abExtra, &e, sizeof e);
}
#endif

// The catalog remains the single source of starter settings and identities.
// Older-host formats select entries; they never rewrite a starter's container.
std::vector<LONG> ClassPresets(const RenderFormat& format) {
  std::vector<LONG> indices;
  for (LONG index = 0; index < PresetCount(); ++index) {
#if defined(VEGAS_ENCODER_B6_RECIPE_PROOF)
    if (format.container && index >= 2 &&
        configuration::RecipeOutputExtension(BuiltinRecipeSnapshot(kPresets[index].builtin).at("recipe")) !=
          std::wstring(L".") + Widen(format.container)) continue;
#else
    (void)format;
#endif
    indices.push_back(index);
  }
  return indices;
}
#if defined(VEGAS_ENCODER_B6_RECIPE_PROOF)
ve::Json ClassDefault(const RenderFormat& format) {
  if (!format.container || std::string(format.container) == "mkv") return DefaultRecipeSnapshot();
  const auto indices = ClassPresets(format);
  if (indices.size() <= 2) throw std::runtime_error("No default recipe for this VEGAS container format.");
  auto snapshot = BuiltinRecipeSnapshot(kPresets[indices[2]].builtin);
  snapshot["origin"] = nullptr;
  snapshot["recipe"]["id"] = std::string("vegas-") + format.container;
  snapshot["recipe"]["name"] = "VEGAS render";
  return snapshot;
}
HRESULT CheckClassTemplate(const Tpl& value, const RenderFormat& format) {
  try {
    const auto snapshot = configuration::ReadRecipeSnapshot(value,format.owner);
    if (format.container && configuration::RecipeOutputExtension(snapshot.at("recipe")) !=
          std::wstring(L".") + Widen(format.container)) return E_INVALIDARG;
    return S_OK;
  } catch (const std::invalid_argument&) { return E_INVALIDARG; }
    catch (const ve::Error&) { return E_INVALIDARG; }
}
#endif
GUID ClassPresetGuid(LONG index, const RenderFormat& format) {
#if defined(VEGAS_ENCODER_B6_RECIPE_PROOF)
  if (index == 0) return format.probe;
  if (index == 1) return format.general;
#else
  (void)format;
#endif
  return kPresets[index].guid;
}
Tpl BuildPreset(LONG index, const RenderFormat& format) {
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
  t.SetU32(tpl::id, p.templateId == 0xFFFFFFFF ? (DWORD)index : p.templateId);
  t.SetGuid(tpl::iidOwner, format.owner);
  t.SetGuid(tpl::guidPreset, ClassPresetGuid(index,format));
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
  t = configuration::CreateRecipeTemplate(t, format.owner,
      p.builtin ? BuiltinRecipeSnapshot(p.builtin) : ClassDefault(format));
#else
  SetExtra(t, (DWORD)index);
#endif
  return t;
}

#if defined(VEGAS_ENCODER_LEGACY_HOST)
#if VEGAS_ENCODER_LEGACY_HOST == 22
constexpr wchar_t kHostExe[] = L"vegas220.exe";
constexpr wchar_t kHostKernel[] = L"sharedk.dll";
constexpr char kHostVersion[] = "22.0.0.248";
#elif VEGAS_ENCODER_LEGACY_HOST == 21
constexpr wchar_t kHostExe[] = L"vegas210.exe";
constexpr wchar_t kHostKernel[] = L"vegas210k.dll";
constexpr char kHostVersion[] = "21.0.0.108";
#elif VEGAS_ENCODER_LEGACY_HOST == 13
constexpr wchar_t kHostExe[] = L"vegas130.exe";
constexpr wchar_t kHostKernel[] = L"vegas130k.dll";
constexpr char kHostVersion[] = "13.0.0.453";
#else
#error Unmeasured legacy host profile.
#endif

bool IsLegacyHost() {
  static const bool matches = [] {
    const auto path = ModulePath(nullptr);
    return _wcsicmp(std::filesystem::path(Widen(path)).filename().c_str(), kHostExe) == 0
        && FileVersion(path) == kHostVersion;
  }();
  return matches;
}

// This local allocator facade keeps configuration and template ownership on
// the same host heap. The paired exports are measured in F-066.
class LegacyTemplateAllocator final : public ISfHostAllocator {
 public:
  using Copy = HRESULT (WINAPI*)(SFTEMPLATE**, const SFTEMPLATE*);
  using FreeTemplate = void (WINAPI*)(SFTEMPLATE*);
  static LegacyTemplateAllocator* Acquire() {
    const auto host = std::filesystem::path(Widen(ModulePath(nullptr)));
    const auto path = host.parent_path() / kHostKernel;
    const HMODULE module = GetModuleHandleW(path.c_str());
    if (!module || FileVersion(ModulePath(module)) != kHostVersion) return nullptr;
    const auto copy = reinterpret_cast<Copy>(GetProcAddress(module,
        "?SfFio_CopyTemplate@@YAJPEAPEAUtagSFTEMPLATExV2@@PEBU1@@Z"));
    const auto release = reinterpret_cast<FreeTemplate>(GetProcAddress(module,
        "?SfFio_ReleaseTemplate@@YAXPEAUtagSFTEMPLATExV2@@@Z"));
    return copy && release ? new LegacyTemplateAllocator(copy, release) : nullptr;
  }
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void** out) override {
    if (!out) return E_POINTER;
    *out = nullptr;
    if (iid != IID_IUnknown && iid != IID_SfHostAllocator) return E_NOINTERFACE;
    *out = static_cast<ISfHostAllocator*>(this);
    AddRef();
    return S_OK;
  }
  ULONG STDMETHODCALLTYPE AddRef() override { return InterlockedIncrement(&refs_); }
  ULONG STDMETHODCALLTYPE Release() override {
    const LONG refs = InterlockedDecrement(&refs_);
    if (!refs) delete this;
    return refs;
  }
  void* STDMETHODCALLTYPE Alloc(SIZE_T size) override {
    if (size < tpl::fixedSize || size > Tpl::kMaxBytes) return nullptr;
    Tpl shell;
    shell.b.resize(size);
    shell.SetU32(tpl::cbStruct, static_cast<DWORD>(size));
    SFTEMPLATE* copy = nullptr;
    return copy_(&copy, shell.Ptr()) == S_OK ? copy : nullptr;
  }
  void STDMETHODCALLTYPE Free(void* value) override {
    if (value) release_(static_cast<SFTEMPLATE*>(value));
  }
 private:
  LegacyTemplateAllocator(Copy copy, FreeTemplate release) : copy_(copy), release_(release) {}
  LONG refs_ = 1;
  Copy copy_;
  FreeTemplate release_;
};
#endif

// --- Render class ------------------------------------------------------------

class RenderClass final : public ISfRenderFileClass {
 public:
  explicit RenderClass(const RenderFormat& format) : format_(format), presets_(ClassPresets(format)) {}
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

#if defined(VEGAS_ENCODER_LEGACY_HOST)
  HRESULT STDMETHODCALLTYPE SetTypeIndex(LONG index) override {
    typeIndex_ = index;
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE GetTypeIndex(LONG* index) override {
    if (!index) return E_POINTER;
    *index = typeIndex_;
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE SetIOManager(IUnknown* manager) override {
    return NativeBoundary([&]() -> HRESULT {
      if (manager && !alloc_) {
        alloc_ = LegacyTemplateAllocator::Acquire();
        if (!alloc_) {
          BestEffortDiagnostic([&] { Log("Legacy SetIOManager: template copy/free exports unavailable"); });
          return E_NOINTERFACE;
        }
      }
      if (manager) manager->AddRef();
      manager_.reset(manager);
      return S_OK;
    });
  }
  HRESULT STDMETHODCALLTYPE GetIOManager(IUnknown** out) override {
    if (!out) return E_POINTER;
    *out = manager_.get();
    if (!*out) return E_NOINTERFACE;
    (*out)->AddRef();
    return S_OK;
  }
#else
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

#endif

  HRESULT STDMETHODCALLTYPE GetTypeID(GUID* g) override {
    return NativeBoundary([&]() -> HRESULT {
      if (!g) return E_POINTER;
      *g = format_.owner;
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
#if defined(VEGAS_ENCODER_LEGACY_HOST)
  HRESULT STDMETHODCALLTYPE GetReadClass(IUnknown** out) override {
    if (!out) return E_POINTER;
    *out = nullptr;
    return E_NOTIMPL;
  }
#else
  HRESULT STDMETHODCALLTYPE GetReadClassGuid(GUID* g) override {
    return NativeBoundary([&]() -> HRESULT {
      if (!g) return E_POINTER;
      *g = GUID_NULL;  // no reader class (FrameServer does the same)
      BestEffortDiagnostic([&] { Log("GetReadClassGuid -> GUID_NULL"); });
      return S_OK;
    });
  }

#endif

  HRESULT STDMETHODCALLTYPE GetStrings(const LONG* ids, LONG count, BSTR* strings) override {
    return NativeBoundary([&]() -> HRESULT {
      if (!ids || !strings || count < 0) return E_POINTER;
      for (LONG i = 0; i < count; i++) strings[i] = nullptr;
      const bool encode = Cfg().encode;
      const wchar_t* extensions = format_.container ? format_.wildcard : kEncodeExtensions;
#if defined(VEGAS_ENCODER_B6_RECIPE_PROOF)
      // Legacy automatic mode advertises one placeholder class suffix, as
      // Voukoder Pro does (*.voukoderpro, research F-071): older hosts cannot ask
      // per template, so VEGAS never shows a container it cannot know. SetFile
      // resolves the actual destination from the selected recipe.
      // The retained manual experiment instead skips 23's suffix rewrite.
      if (Cfg().legacyAutoNames) extensions = kLegacyPlaceholderExtensions;
      else if (Cfg().legacyManualNames) extensions = L"";
#endif
      for (LONG i = 0; i < count; i++) {
        // Ids paired by position with FrameServer's SFFIO_FILECLASS_TEXT_* list
        // and Voukoder's answers (F-033): 1 brief, 2 long, 4 extensions, 5 localized.
        const wchar_t* s = nullptr;
        switch (ids[i]) {
          case 1: s = format_.name; break;
          case 2: s = format_.name; break;
          // Exact 2026 mp4plug3 writer ID-4 table uses semicolon-separated
          // wildcards. Keep MKV first for legacy/default class-wide naming.
          case 4: s = encode ? extensions : L"*.ffdiag"; break;
          case 5: s = format_.name; break;
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

#if defined(VEGAS_ENCODER_LEGACY_HOST)
  HRESULT STDMETHODCALLTYPE Open(ISfRenderFile*, LONG, LPCWSTR) override { return E_NOTIMPL; }
#else
  HRESULT STDMETHODCALLTYPE Open(ISfRenderFile** file, LONG h, LPCWSTR path) override {
    return NativeBoundary([&]() -> HRESULT {
      if (file) *file = nullptr;
      BestEffortDiagnostic([&] { Log("Open(h=%ld, path=%s) -> E_NOTIMPL", h, Utf8(path).c_str()); });
      return E_NOTIMPL;
    });
  }

#endif

  HRESULT STDMETHODCALLTYPE Create(ISfRenderFile** file, LPCWSTR path, LONG cStreams,
                                   ISfReadStream** streams, const SFTEMPLATE* t) override {
    return NativeBoundary([&]() -> HRESULT {
      BestEffortDiagnostic([&] { Log("Create(path=%s, cStreams=%ld, streams=%p, template=%p)", path ? Utf8(path).c_str() : "(null)",
          cStreams, (void*)streams, (const void*)t); });
      LogTemplate("create template", t, true);
      if (!file) return E_POINTER;
      *file = nullptr;
      if (!Tpl::Valid(t)) return E_INVALIDARG;
#if defined(VEGAS_ENCODER_B6_RECIPE_PROOF)
      if (format_.container) {
        const auto checked = CheckClassTemplate(Tpl::Copy(t),format_);
        if (FAILED(checked)) return checked;
      }
#endif
      ISfRenderFile* f = nullptr;
      HRESULT hr = CreateRenderFile(t, &f, format_.owner, this);
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
      *count = static_cast<LONG>(presets_.size());
      if (LogDetail("class.11")) BestEffortDiagnostic([&] { Log("GetPresetCount -> %ld", *count); });
      return S_OK;
    });
  }

  HRESULT STDMETHODCALLTYPE GetPreset(SFTEMPLATE** out, LONG index) override {
    return NativeBoundary([&]() -> HRESULT {
      if (!out) return E_POINTER;
      *out = nullptr;
      if (index < 0 || static_cast<size_t>(index) >= presets_.size()) return E_INVALIDARG;
      HRESULT hr = ToHost(BuildPreset(presets_[index],format_), out);
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
      for (LONG i = 0; i < static_cast<LONG>(presets_.size()); i++)
        if (*g == ClassPresetGuid(presets_[i],format_)) {
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
      t.SetGuid(tpl::iidOwner, format_.owner);
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
      const bool own = s.Guid(tpl::iidOwner) == format_.owner;
      if (own && format_.container) {
        const auto checked = CheckClassTemplate(s,format_);
        if (FAILED(checked)) return checked;
      } else if (!own) {
        for (const auto& other : kLegacyFormats)
          if (s.Guid(tpl::iidOwner) == other.owner) return E_INVALIDARG;
      }
      auto snapshot = own ? configuration::ReadRecipeSnapshot(s,format_.owner) : ClassDefault(format_);
      // The candidate accepts P010 input only. Never inherit a project RGB codec.
      auto input = t.Bih(tpl::videoRenderBih);
      input.biCompression = MAKEFOURCC('P', '0', '1', '0'); input.biBitCount = 32;
      t.SetBih(tpl::videoRenderBih, input); t.SetBih(tpl::videoCodecBih, input);
      t = configuration::CreateRecipeTemplate(t, format_.owner, snapshot);
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
#if defined(VEGAS_ENCODER_B6_RECIPE_PROOF)
      if (format_.container) {
        const auto checked = CheckClassTemplate(Tpl::Copy(base),format_);
        if (FAILED(checked)) return checked;
      }
#endif
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

  HRESULT STDMETHODCALLTYPE GetTemplateInfo(const SFTEMPLATE* value, BYTE* info, LONG cch, LONG type) override {
    return NativeBoundary([&]() -> HRESULT {
      // 2026.0.3.189 mp4plug3 writer slot 17 / selector 11 returns a UTF-16
      // wildcard for this template; capacity is WCHARs, not bytes. The host
      // calls it with 0x104 and 0x20-character buffers. See container plan.
#if defined(VEGAS_ENCODER_LEGACY_HOST)
      if (VEGAS_ENCODER_LEGACY_HOST == 22 && type == 11) {
        if (!value || !info) return E_POINTER;
        if (cch < static_cast<LONG>(sizeof(DWORD)) || !Tpl::Valid(value)) return E_INVALIDARG;
        const auto streams = Tpl::Copy(value).U32(tpl::videoStreams);
        memcpy(info, &streams, sizeof streams);
        return S_OK;
      }
      (void)value; (void)info;
#elif defined(VEGAS_ENCODER_B6_RECIPE_PROOF)
      if (type == 11 && Cfg().encode) {
        if (!info || !value) return E_POINTER;
        if (cch <= 0) return E_INVALIDARG;
        const wchar_t zero = L'\0';
        memcpy(info, &zero, sizeof zero);
        const auto snapshot = configuration::ReadRecipeSnapshot(Tpl::Copy(value), format_.owner);
        const auto extension = configuration::RecipeOutputExtension(snapshot.at("recipe"));
        if (extension.empty()) return E_FAIL;
        if (format_.container && extension != std::wstring(L".") + Widen(format_.container)) return E_INVALIDARG;
        const auto wildcard = L"*" + extension;
        if (static_cast<size_t>(cch) <= wildcard.size()) return HRESULT_FROM_WIN32(ERROR_INSUFFICIENT_BUFFER);
        memcpy(info, wildcard.c_str(), (wildcard.size() + 1) * sizeof(wchar_t));
        return S_OK;
      }
#else
      (void)value; (void)info;
#endif
      // Other selectors remain unestablished (F-038).
      if (LogDetail("class.17")) BestEffortDiagnostic([&] { Log("GetTemplateInfo(cch=%ld, type=%ld) -> E_NOTIMPL", cch, type); });
      return E_NOTIMPL;
    });
  }

#if defined(VEGAS_ENCODER_LEGACY_HOST) && VEGAS_ENCODER_LEGACY_HOST != 13
  HRESULT STDMETHODCALLTYPE GetLegacyTemplateInfoText(const SFTEMPLATE*, wchar_t*, LONG, LONG) override {
    return E_NOTIMPL;
  }
#endif
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
      if (index == 0) return configuration::CreateNativeRecipePage(alloc_, RecipeEditorOptions(format_.owner,format_.container), page);
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
#if defined(VEGAS_ENCODER_LEGACY_HOST)
  std::unique_ptr<IUnknown, ComRelease> manager_;
  LONG typeIndex_ = 0;
#endif
  const RenderFormat& format_;
  const std::vector<LONG> presets_;
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
      *count = RenderFormatCount();
      BestEffortDiagnostic([&] { Log("GetFilterCount -> %ld",*count); });
      return S_OK;
    });
  }
  HRESULT STDMETHODCALLTYPE GetFilterInfo(LONG index, GUID* clsid, LPWSTR name, LONG cchName, DWORD* access,
                                          DWORD* streamTypes, DWORD* app1, DWORD* app2, DWORD* app3,
                                          DWORD* app4, DWORD* expire, DWORD* flags) override {
    return NativeBoundary([&]() -> HRESULT {
      if (index < 0 || index >= RenderFormatCount()) return E_INVALIDARG;
      const auto& format = RenderFormatAt(index);
      const Config& c = Cfg();
      if (clsid) *clsid = format.filter;
      if (name && cchName > 0) wcsncpy_s(name, (size_t)cchName, format.name, _TRUNCATE);
      if (access) *access = c.access;
      if (streamTypes) *streamTypes = c.streamTypes;
      for (DWORD* p : {app1, app2, app3, app4})
        if (p) *p = 0xFFFFFFFF;
      if (expire) *expire = 0;
      if (flags) *flags = c.pluginFlags;
      BestEffortDiagnostic([&] { Log("GetFilterInfo(%ld, cch=%ld) -> clsid %s access=0x%lx streamTypes=0x%lx flags=0x%lx", index,cchName,
          GuidText(format.filter).c_str(), c.access, c.streamTypes, c.pluginFlags); });
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
        const auto* format = FindRenderFormat(clsid_);
        if (format) obj = new RenderClass(*format);
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
#if defined(VEGAS_ENCODER_LEGACY_HOST)
    if (!IsLegacyHost()) return CLASS_E_CLASSNOTAVAILABLE;
#endif
    HRESULT hr = CLASS_E_CLASSNOTAVAILABLE;
    if (clsid == CLSID_SfMediaGetUnsharedTypeInfo || FindRenderFormat(clsid)) {
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
