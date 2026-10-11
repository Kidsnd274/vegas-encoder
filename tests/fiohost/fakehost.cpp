// fakehost.cpp - fake VEGAS render streams for offline exporter tests.
//
// Stream behaviour copies what the F-031/F-036 captures recorded from VEGAS
// 2026: host-filled video tokens (P010: mode 1, per-session handle; BI_RGB:
// mode 0, no handle, lock value = data pointer, rows bottom-up, F-041), a
// 176-byte frame info, frame locks released through slot 15, exporter-filled
// audio tokens (mode 0, caller PID). Pixel content is the baseline fixture
// from scripts/Make-BaselineMedia.py so scripts/Check-RawRender.py --fixture
// can validate the exporter's output. Slot-6 cancel now follows F-045 and
// a final audio read returns S_FALSE with data (F-041).
#include "fakehost.h"
#include "../../src/vegas/abi/configuration_abi.h"

#include <cmath>
#include <cstdio>
#include <cstring>
#include <vector>

using namespace sfio;

namespace {

constexpr int FW = 320, FH = 180;  // fixture size
constexpr double kPi = 3.14159265358979323846;

struct Rgb {
  BYTE r, g, b;
};

// Fixture frame, top-down, same rectangles as Make-BaselineMedia.py.
std::vector<Rgb> FixtureFrame(LONGLONG frame) {
  std::vector<Rgb> px((size_t)FW * FH, Rgb{24, 24, 24});
  auto rect = [&px](int x0, int y0, int x1, int y1, Rgb c) {
    for (int y = y0; y < y1 && y < FH; y++)
      for (int x = x0; x < x1 && x < FW; x++) px[(size_t)y * FW + x] = c;
  };
  rect(0, 0, 32, 24, {255, 0, 0});
  rect(FW - 32, 0, FW, 24, {0, 255, 0});
  rect(0, FH - 24, 32, FH, {0, 0, 255});
  rect(FW - 32, FH - 24, FW, FH, {255, 255, 255});
  static const char* digits[] = {"abcdef", "bc", "abdeg", "abcdg", "bcfg", "acdfg", "acdefg", "abc", "abcdefg", "abcdfg"};
  static const int seg[7][4] = {{4, 0, 24, 4},   {24, 4, 28, 24}, {24, 28, 28, 48}, {4, 48, 24, 52},
                                {0, 28, 4, 48},  {0, 4, 4, 24},   {4, 24, 24, 28}};
  char text[8];
  snprintf(text, sizeof text, "%03lld", frame % 1000);
  for (int i = 0; i < 3; i++)
    for (const char* s = digits[text[i] - '0']; *s; s++) {
      const int* g = seg[*s - 'a'];
      rect(108 + i * 36 + g[0], 55 + g[1], 108 + i * 36 + g[2], 55 + g[3], {240, 240, 240});
    }
  rect(40, 135, (int)(42 + frame * 2), 143, {0, 180, 220});
  if (frame == 30) rect(100, 150, 220, 180, {255, 255, 0});
  if (frame == 60) rect(100, 150, 220, 180, {255, 0, 255});
  return px;
}

// Counts references; objects live on the test's stack and are never deleted.
template <class I>
class Counted : public I {
 public:
  ULONG STDMETHODCALLTYPE AddRef() override { return (ULONG)InterlockedIncrement(&ref); }
  ULONG STDMETHODCALLTYPE Release() override { return (ULONG)InterlockedDecrement(&ref); }
  LONG ref = 1;

 protected:
  HRESULT Qi(REFIID riid, void** ppv, std::initializer_list<GUID> ids) {
    if (!ppv) return E_POINTER;
    for (const GUID& g : ids)
      if (riid == g) {
        *ppv = static_cast<I*>(this);
        AddRef();
        return S_OK;
      }
    *ppv = nullptr;
    return E_NOINTERFACE;
  }
};

class FakeVideo final : public Counted<ISfReadVideoRenderStream> {
 public:
  FakeVideo(LONGLONG frames, LONG w, LONG h, DWORD compression, double fps)
      : frames_(frames), w_(w), h_(h), compression_(compression), fps_(fps) {
    bool p010 = compression == MAKEFOURCC('P', '0', '1', '0');
    stride0_ = p010 ? w * 2 : w * 4;
    plane1_ = p010 ? stride0_ * h : 0;
    stride1_ = p010 ? stride0_ : 0;
    size_ = p010 ? plane1_ + stride1_ * (h / 2) : stride0_ * h;
    buf_.resize((size_t)size_);
  }
  bool Supported() const { return compression_ == MAKEFOURCC('P', '0', '1', '0') || compression_ == BI_RGB; }

  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void** ppv) override {
    return Qi(riid, ppv, {IID_IUnknown, __uuidof(ISfReadStream), __uuidof(ISfReadVideoRenderStream)});
  }
  HRESULT STDMETHODCALLTYPE GetFile(IUnknown** p) override {
    if (p) *p = nullptr;
    return E_NOTIMPL;
  }
  HRESULT STDMETHODCALLTYPE Slot4(LONG*) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE Slot5(LONG*, LONG*, LONG*) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE GetStreamLength(LONGLONG* p) override {
    if (!p) return E_POINTER;
    *p = frames_;
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE Slot7(LONGLONG*) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE Slot8() override {
    unexpected++;
    return E_NOTIMPL;
  }
  HRESULT STDMETHODCALLTYPE GetFrameCount(LONGLONG* frames) override {
    if (!frames) return E_POINTER;
    *frames = frames_;
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE GetFormat10(void*) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE GetReadVideoFormat(void*) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE SetRenderFrameFormat(void*, const void*) override {
    unexpected++;
    return E_NOTIMPL;
  }
  HRESULT STDMETHODCALLTYPE Slot13(void*, LONG) override {
    unexpected++;
    return E_NOTIMPL;
  }
  HRESULT STDMETHODCALLTYPE GetRenderFrame(LONGLONG frame, SFMEMORYTOKEN* token, LONG_PTR* lock, void* info,
                                           LONG* cb) override {
    if (!token || !lock || !info || !cb) return E_POINTER;
    if (frame < 0 || frame >= frames_ || !Supported()) return E_INVALIDARG;
    if (outstanding) lockErrors++;  // the captured exporter always released first
    Fill(frame);
    bool rgb = compression_ == BI_RGB;
    *token = SFMEMORYTOKEN{};
    token->hHandle = rgb ? 0 : 0x32D4;  // P010: constant per session (F-036); BI_RGB: none (F-041)
    token->pData = (ULONGLONG)(uintptr_t)buf_.data();
    token->cbData = size_;
    token->cbAlloc = size_;
    token->mode = rgb ? 0 : 1;
    token->pid = GetCurrentProcessId();
    BYTE* fi = (BYTE*)info;
    memset(fi, 0, frameinfo::size);
    double one = 1.0;
    LONGLONG size64 = size_;
    memcpy(fi + frameinfo::frame, &frame, 8);
    memcpy(fi + 0x10, &one, 8);
    memcpy(fi + frameinfo::dataSize, &size64, 8);
    DWORD vex[4] = {64, 0xFFFFFFFF, 0, 0};
    memcpy(fi + frameinfo::vex, vex, sizeof vex);
    memcpy(fi + frameinfo::fps, &fps_, 8);
    memcpy(fi + frameinfo::pixelAspect, &one, 8);
    BITMAPINFOHEADER h{};
    h.biSize = sizeof h;
    h.biWidth = w_;
    h.biHeight = h_;
    h.biPlanes = 1;
    h.biBitCount = compression_ == BI_RGB ? 32 : 24;  // 24 observed for P010
    h.biCompression = compression_;
    h.biSizeImage = (DWORD)size_;
    memcpy(fi + frameinfo::bih, &h, sizeof h);
    DWORD planes[3] = {(DWORD)stride0_, (DWORD)plane1_, (DWORD)stride1_};
    memcpy(fi + frameinfo::planeFields, planes, sizeof planes);
    *cb = size_;
    *lock = rgb ? (LONG_PTR)buf_.data() : (LONG_PTR)(0x120C140000LL + frame * 0x10000);
    lastLock_ = *lock;
    outstanding++;
    served++;
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE ReleaseRenderFrame(LONG_PTR lock) override {
    if (outstanding <= 0 || lock != lastLock_) {
      lockErrors++;
      return E_INVALIDARG;
    }
    outstanding--;
    released++;
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE Slot16(LONGLONG, const void*, const SFMEMORYTOKEN*, void*, LONG*) override {
    unexpected++;
    return E_NOTIMPL;
  }

  LONGLONG served = 0, released = 0, outstanding = 0, lockErrors = 0, unexpected = 0;

 private:
  void Fill(LONGLONG frame) {
    std::vector<Rgb> px = FixtureFrame(frame);
    BYTE* out = buf_.data();
    for (LONG y = 0; y < h_; y++) {
      const Rgb* src = &px[(size_t)(y * FH / h_) * FW];
      if (compression_ == BI_RGB) {
        BYTE* row = out + (size_t)(h_ - 1 - y) * stride0_;  // bottom-up, as VEGAS 2026 delivers (F-041)
        for (LONG x = 0; x < w_; x++) {
          const Rgb& c = src[x * FW / w_];
          row[4 * x] = c.b;
          row[4 * x + 1] = c.g;
          row[4 * x + 2] = c.r;
          row[4 * x + 3] = 255;
        }
      } else {
        WORD* row = (WORD*)(out + (size_t)y * stride0_);
        for (LONG x = 0; x < w_; x++) {
          const Rgb& c = src[x * FW / w_];
          double luma = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;  // BT.709, limited range
          row[x] = (WORD)((64 + (int)lround(876.0 * luma / 255.0)) << 6);
        }
      }
    }
    if (compression_ != BI_RGB)
      for (LONG y = 0; y < h_ / 2; y++) {
        WORD* row = (WORD*)(out + plane1_ + (size_t)y * stride1_);
        for (LONG x = 0; x < w_; x++) row[x] = 512 << 6;
      }
  }

  LONGLONG frames_;
  LONG_PTR lastLock_ = 0;
  LONG w_, h_;
  DWORD compression_;
  double fps_;
  LONG stride0_, plane1_, stride1_, size_;
  std::vector<BYTE> buf_;
};

class FakeAudio final : public Counted<ISfReadAudioStream> {
 public:
  FakeAudio(DWORD rate, WORD channels, DWORD format, LONGLONG length, double fps, LONG shortRead)
      : rate_(rate), channels_(channels), format_(format), length_(length), fps_(fps), shortRead_(shortRead) {}

  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void** ppv) override {
    return Qi(riid, ppv, {IID_IUnknown, __uuidof(ISfReadStream), __uuidof(ISfReadAudioStream)});
  }
  HRESULT STDMETHODCALLTYPE GetFile(IUnknown** p) override {
    if (p) *p = nullptr;
    return E_NOTIMPL;
  }
  HRESULT STDMETHODCALLTYPE Slot4(LONG*) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE Slot5(LONG*, LONG*, LONG*) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE GetStreamLength(LONGLONG* p) override {
    if (!p) return E_POINTER;
    *p = length_;
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE Slot7(LONGLONG*) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE Slot8() override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE GetSampleCount(LONGLONG* p) override {
    if (!p) return E_POINTER;
    *p = length_;
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE Slot10(LONG*) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE GetFormat11(void*) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE GetFormat12(void*) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE SetFormat13(void*) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE Read(LONGLONG pos, const SFMEMORYTOKEN* t, LONG count, LONG* got) override {
    if (!t || !got) return E_POINTER;
    LONG align = (LONG)channels_ * (format_ == SFAUDIO_FORMAT_FLOAT32 ? 4 : 2);
    // Exporter-filled token as captured: {0, buf, bytes, bytes, 0, 0, mode 0, PID}.
    if (t->hHandle != 0 || !t->pData || t->cbData != count * align || t->cbAlloc < t->cbData || t->offset ||
        t->mode != 0 || t->pid != GetCurrentProcessId() || pos != next_)
      tokenErrors++;
    BYTE* out = (BYTE*)(uintptr_t)t->pData;
    if (pos >= length_) { *got = 0; return S_FALSE; }
    count = (LONG)((std::min)((LONGLONG)count, length_ - pos));
    if (shortRead_ > 0) count = (std::min)(count, shortRead_);
    for (LONG i = 0; i < count; i++)
      for (WORD c = 0; c < channels_; c++) {
        double v = Sample(pos + i, c);
        if (format_ == SFAUDIO_FORMAT_FLOAT32) {
          float f = (float)(v / 32768.0);
          memcpy(out + (size_t)i * align + 4 * c, &f, 4);
        } else {
          short s = (short)v;
          memcpy(out + (size_t)i * align + 2 * c, &s, 2);
        }
      }
    *got = count;
    next_ = pos + count;
    reads++;
    samples += count;
    return next_ == length_ ? S_FALSE : S_OK;
  }
  HRESULT STDMETHODCALLTYPE Slot15(LONGLONG*, LONGLONG*, LONG*) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE Slot16(LONG) override { return E_NOTIMPL; }

  LONGLONG reads = 0, samples = 0, tokenErrors = 0;

 private:
  // Bursts at visual frames 30/60, retimed for fractional delivered fps.
  double Sample(LONGLONG n, WORD channel) const {
    LONGLONG start = channel < 2 ? (LONGLONG)llround((channel + 1) * 30.0 * rate_ / fps_) : -1;
    double freq = channel == 0 ? 1000 : 500;
    LONGLONG off = n - start;
    if (start < 0 || off < 0 || off >= 480) return 0;
    return (double)lround(12000 * cos(2 * kPi * freq * (double)off / rate_));
  }

  DWORD rate_;
  WORD channels_;
  DWORD format_;
  LONGLONG length_, next_ = 0;
  double fps_;
  LONG shortRead_;
};

class FakeProgress final : public Counted<ISfProgress> {
 public:
  FakeProgress(LONGLONG cancelAt, int failureSlot, LONGLONG failureAt, int failureCall,
               const LONGLONG* audioReads)
      : cancelAt_(cancelAt), failureSlot_(failureSlot), failureAt_(failureAt), failureCall_(failureCall),
        audioReads_(audioReads) {}
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void** ppv) override {
    return Qi(riid, ppv, {IID_IUnknown, __uuidof(ISfProgress)});
  }
  HRESULT STDMETHODCALLTYPE Slot3(LPCWSTR, LONGLONG) override { return S_OK; }
  HRESULT STDMETHODCALLTYPE Slot4(LPCWSTR) override { return S_OK; }
  HRESULT STDMETHODCALLTYPE SetTotal(LONGLONG t) override {
    total = t;
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE SetPosition(LONGLONG p) override {
    if (position != p) callsAtPosition_ = 0;
    callsAtPosition_++;
    position = p;
    positions++;
    if (FailNow(6)) return E_ACCESSDENIED;
    return (cancelAt_ >= 0 && p >= cancelAt_) ? SF_E_PROGRESS_CANCELLED : S_OK;
  }
  HRESULT STDMETHODCALLTYPE CheckCancel() override {
    checks++;
    return FailNow(7) ? E_ACCESSDENIED : S_OK;
  }
  HRESULT STDMETHODCALLTYPE Slot8(LONG) override { return S_OK; }
  LONGLONG total = -1, position = -1, positions = 0, checks = 0;

 private:
  bool FailNow(int slot) const {
    return failureSlot_ == slot && position >= failureAt_ && callsAtPosition_ >= failureCall_ &&
        (!audioReads_ || *audioReads_ > failureAt_);
  }
  LONGLONG cancelAt_;
  int failureSlot_;
  LONGLONG failureAt_;
  int failureCall_, callsAtPosition_ = 0;
  const LONGLONG* audioReads_;
};

class FakeMeta final : public Counted<ISfReadMeta> {
 public:
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void** ppv) override {
    return Qi(riid, ppv, {IID_IUnknown, __uuidof(ISfReadMeta)});
  }
};

std::vector<BYTE> ReadFileBytes(const std::wstring& path) {
  std::vector<BYTE> d;
  FILE* f = nullptr;
  if (_wfopen_s(&f, path.c_str(), L"rb") != 0 || !f) return d;
  BYTE buf[4096];
  size_t n;
  while ((n = fread(buf, 1, sizeof buf, f)) > 0) d.insert(d.end(), buf, buf + n);
  fclose(f);
  return d;
}

void SaveTemplate(const std::wstring& dir, const wchar_t* name, const SFTEMPLATE* t) {
  if (!t) return;
  DWORD cb;
  memcpy(&cb, t, 4);
  FILE* f = nullptr;
  if (_wfopen_s(&f, (dir + L"\\" + name).c_str(), L"wb") == 0 && f) {
    fwrite(t, 1, cb, f);
    fclose(f);
  }
}

template <class T>
T At(const void* t, size_t off) {
  T v;
  memcpy(&v, (const BYTE*)t + off, sizeof v);
  return v;
}

int g_failures = 0;
void Check(bool ok, const char* what) {
  printf("  %s %s\n", ok ? "ok  " : "FAIL", what);
  if (!ok) g_failures++;
}

class FakeTemplateHolder final : public Counted<ISfFileIOTemplateEditHolder> {
 public:
  FakeTemplateHolder(ISfHostAllocator* allocator, const SFTEMPLATE* value) : allocator_(allocator) {
    const BYTE* bytes = reinterpret_cast<const BYTE*>(value);
    saved.assign(bytes, bytes + At<DWORD>(value, 0));
  }
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void** out) override {
    return Qi(iid, out, {IID_IUnknown, __uuidof(ISfFileIOTemplateEditHolder)});
  }
  HRESULT STDMETHODCALLTYPE Slot3(SFTEMPLATE** out) override {
    *out = static_cast<SFTEMPLATE*>(allocator_->Alloc(saved.size()));
    if (!*out) return E_OUTOFMEMORY;
    memcpy(*out, saved.data(), saved.size());
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE Slot4(const SFTEMPLATE* value) override {
    const DWORD bytes = At<DWORD>(value, 0);
    if (bytes < tpl::fixedSize || bytes > (1u << 20)) return E_INVALIDARG;
    const BYTE* start = reinterpret_cast<const BYTE*>(value);
    std::vector<BYTE> copy(start, start + bytes);
    saved.swap(copy);
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE Slot5(SFTEMPLATE**) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE Slot6(LONG, LONG*) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE Slot7(LONG, LONG) override { return E_NOTIMPL; }
  std::vector<BYTE> saved;
 private:
  ISfHostAllocator* allocator_;
};

class FakePageSite final : public Counted<IPropertyPageSite> {
 public:
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void** out) override {
    return Qi(iid, out, {IID_IUnknown, IID_IPropertyPageSite});
  }
  HRESULT STDMETHODCALLTYPE OnStatusChange(DWORD) override { return S_OK; }
  HRESULT STDMETHODCALLTYPE GetLocaleID(LCID* out) override { if (!out) return E_POINTER; *out = 0x409; return S_OK; }
  HRESULT STDMETHODCALLTYPE GetPageContainer(IUnknown** out) override { if (out) *out = nullptr; return E_NOINTERFACE; }
  HRESULT STDMETHODCALLTYPE TranslateAccelerator(MSG*) override { return S_FALSE; }
};

bool ConfigureAndReload(ISfRenderFileClass* renderClass, ISfHostAllocator* allocator,
                        SFTEMPLATE*& value, const RenderTestOptions& options) {
  LONG free = 0, sale = 0, flags = 0;
  if (renderClass->GetPropertyPageCount(&free, &sale, &flags) != S_OK || free != 1) return false;
  IPropertyPage* page = nullptr;
  if (renderClass->GetPropertyPage(0, &page) != S_OK || !page) return false;
  ISfFileIOPropertyPage* native = nullptr;
  FakeTemplateHolder holder(allocator, value);
  FakePageSite site;
  IUnknown* object = &holder;
  BYTE info[56]{};
  HRESULT result = page->QueryInterface(__uuidof(ISfFileIOPropertyPage), reinterpret_cast<void**>(&native));
  if (SUCCEEDED(result)) result = native->Slot14(value, info);
  if (native) native->Release();
  if (SUCCEEDED(result)) result = page->SetPageSite(&site);
  if (SUCCEEDED(result)) result = page->SetObjects(1, &object);
  HWND parent = CreateWindowExW(0, L"STATIC", L"Offline proof page", WS_OVERLAPPED,
      0, 0, 400, 120, nullptr, nullptr, GetModuleHandleW(nullptr), nullptr);
  RECT rect{0, 0, 360, 80};
  bool active = false;
  if (SUCCEEDED(result)) { result = page->Activate(parent, &rect, FALSE); active = SUCCEEDED(result); }
  HWND dialog = parent ? GetWindow(parent, GW_CHILD) : nullptr;
  HWND checkbox = dialog ? GetDlgItem(dialog, 100) : nullptr;
  if (SUCCEEDED(result) && !checkbox) result = E_FAIL;
  if (SUCCEEDED(result)) {
    const bool enabled = SendMessageW(checkbox, BM_GETCHECK, 0, 0) == BST_CHECKED;
    if (enabled != (options.configurationProof != 0)) SendMessageW(checkbox, BM_CLICK, 0, 0);
    result = page->Apply();
  }
  if (active) page->Deactivate();
  page->SetObjects(0, nullptr);
  page->SetPageSite(nullptr);
  page->Release();
  if (parent) DestroyWindow(parent);
  if (result != S_OK || holder.ref != 1 || site.ref != 1) return false;
  const SFTEMPLATE* saved = reinterpret_cast<const SFTEMPLATE*>(holder.saved.data());
  SaveTemplate(options.outDir, L"configured-template.tpl", saved);
  const std::vector<BYTE> reloaded = ReadFileBytes(options.outDir + L"\\configured-template.tpl");
  if (reloaded != holder.saved) return false;
  auto* restored = static_cast<SFTEMPLATE*>(allocator->Alloc(reloaded.size()));
  if (!restored) return false;
  memcpy(restored, reloaded.data(), reloaded.size());
  allocator->Free(value);
  value = restored;
  // The following Create uses saved bytes directly, with no new conform call.
  return true;
}

}  // namespace

int RunRenderTest(ISfRenderFileClass* rc, ISfHostAllocator* alloc, const RenderTestOptions& o) {
  g_failures = 0;
  std::vector<BYTE> host = ReadFileBytes(o.hostTemplate);
  if (host.size() < tpl::fixedSize || At<DWORD>(host.data(), 0) != host.size()) {
    printf("render test: cannot use host template %ls (%zu bytes)\n", o.hostTemplate.c_str(), host.size());
    return 1;
  }
  if (o.width > 0 && o.height > 0) {
    memcpy(host.data() + tpl::videoRenderBih + 4, &o.width, 4);
    memcpy(host.data() + tpl::videoRenderBih + 8, &o.height, 4);
    DWORD image = (DWORD)(o.width * o.height * 4);
    memcpy(host.data() + tpl::videoRenderBih + 20, &image, 4);
  }
  if (o.fps > 0) memcpy(host.data() + tpl::vexFps, &o.fps, 8);
  const SFTEMPLATE* hostTpl = (const SFTEMPLATE*)host.data();
  LONG width = At<LONG>(host.data(), tpl::videoRenderBih + 4), height = At<LONG>(host.data(), tpl::videoRenderBih + 8);
  double fps = At<double>(host.data(), tpl::vexFps);
  SFAUDIORECORD hostAudio = At<SFAUDIORECORD>(host.data(), tpl::audioRender);
  printf("render test: host template %ldx%ld fps %.17g audio %lu Hz %u ch\n", width, height, fps,
         hostAudio.sampleRate, hostAudio.channels);

  // Template calls in the order VEGAS made them before the captured Create.
  SFTEMPLATE* project = nullptr;
  HRESULT hr = rc->ConformTemplate(&project, hostTpl, 2);
  printf("ConformTemplate(host, 2) hr=0x%08lx\n", hr);
  Check(hr == S_OK && project, "ConformTemplate returns a Project Settings template");
  SaveTemplate(o.outDir, L"project-settings.tpl", project);
  SFTEMPLATE* preset = nullptr;
  hr = rc->GetPreset(&preset, o.preset);
  Check(hr == S_OK && preset, "GetPreset");
  SaveTemplate(o.outDir, L"render-preset.tpl", preset);
  if (!project || !preset) return 1;

  SFTEMPLATE* io = preset;
  hr = rc->ConformTemplateToSource(&io, preset, nullptr, 2);
  printf("ConformTemplateToSource(preset, null, 2) hr=0x%08lx\n", hr);
  Check(hr == S_FALSE && io == preset, "no source: S_FALSE and *io untouched (as Voukoder)");
  SFTEMPLATE* pass1 = nullptr;
  hr = rc->ConformTemplateToSource(&pass1, preset, project, 0);
  printf("ConformTemplateToSource(preset, project, 0) hr=0x%08lx\n", hr);
  Check(hr == S_OK && pass1, "first reason-0 pass allocates a template");
  SFTEMPLATE* create = nullptr;
  if (pass1) hr = rc->ConformTemplateToSource(&create, pass1, hostTpl, 0);
  printf("ConformTemplateToSource(pass1, host, 0) hr=0x%08lx\n", hr);
  Check(hr == S_OK && create, "second reason-0 pass allocates the Create template");
  if (!create) return 1;
  if (o.configurationProof >= 0)
    Check(ConfigureAndReload(rc, alloc, create, o), "native page Apply and owned-byte save/reload before Create (no fresh conform)");
  SaveTemplate(o.outDir, L"create.tpl", create);

  BITMAPINFOHEADER bih = At<BITMAPINFOHEADER>(create, tpl::videoRenderBih);
  BITMAPINFOHEADER presetBih = At<BITMAPINFOHEADER>(preset, tpl::videoRenderBih);
  SFAUDIORECORD audioRec = At<SFAUDIORECORD>(create, tpl::audioRender);
  double createFps = At<double>(create, tpl::vexFps);
  Check(bih.biWidth == width && bih.biHeight == height, "Create template takes the project frame size");
  Check(bih.biCompression == presetBih.biCompression, "Create template keeps the preset's compression");
  Check(createFps == fps, "Create template takes the project fps");
  Check(audioRec.format == SFAUDIO_FORMAT_FLOAT32 && audioRec.sampleRate == hostAudio.sampleRate &&
            audioRec.channels == hostAudio.channels && audioRec.blockAlign == 4 * hostAudio.channels,
        "Create template requests float32 at the project rate/channels");
  Check(memcmp((const BYTE*)create + tpl::audioCodec, &audioRec, sizeof audioRec) == 0,
        "codec audio record equals render record");

  double deliveredFps = o.deliveredFps > 0 ? o.deliveredFps : createFps;
  LONGLONG samples = (LONGLONG)llround((double)o.frames * audioRec.sampleRate / deliveredFps);
  for (int run = 1; run <= o.renders; run++) {
    printf("render %d of %d\n", run, o.renders);
    FakeVideo video(o.frames, bih.biWidth, bih.biHeight, bih.biCompression, deliveredFps);
    FakeAudio audio(audioRec.sampleRate, audioRec.channels, audioRec.format, samples, deliveredFps, o.shortRead);
    const bool injectStop = !o.recover || run == 1;
    const LONGLONG cancelAt = injectStop ? o.cancelAt : -1;
    const int failureSlot = injectStop ? o.progressFailureSlot : 0;
    FakeProgress progress(cancelAt, failureSlot, o.progressFailureAt, o.progressFailureCall,
                          o.progressFailureAfterAudioRead ? &audio.reads : nullptr);
    FakeMeta meta;
    ISfRenderFile* file = nullptr;
    hr = rc->Create(&file, nullptr, 0, nullptr, create);  // VEGAS passes null/0 here (F-036)
    Check(hr == S_OK && file, "Create(null path, 0 streams)");
    if (!file) break;
    wchar_t path[MAX_PATH];
    swprintf_s(path, L"%s\\render-%d.%s", o.outDir.c_str(), run, o.extension.c_str());
    Check(file->SetStreamReader(&video, 0) == S_OK, "SetStreamReader(video, 0)");
    if (!o.videoOnly) Check(file->SetStreamReader(&audio, 1) == S_OK, "SetStreamReader(audio, 1)");
    Check(file->SetMetaReader(&meta) == S_OK, "SetMetaReader");
    Check(file->SetFile(path) == S_OK, "SetFile");
    hr = file->Render(&progress);
    printf("Render hr=0x%08lx frames served %lld released %lld outstanding %lld; audio reads %lld samples %lld\n", hr,
           video.served, video.released, video.outstanding, audio.reads, audio.samples);
    wchar_t name[0x104] = L"";
    if (SUCCEEDED(hr))
      Check(file->GetFileName(name, 0x104) == S_OK && wcscmp(name, path) == 0, "GetFileName returns the SetFile path");
    Check(file->CloseFile() == S_OK, "CloseFile");
    file->Release();
    if (injectStop && (o.expectFailure || failureSlot)) {
      Check(FAILED(hr) && hr != SF_E_RENDER_STOPPED, "failure is distinct from cancel");
      if (failureSlot) Check(hr == E_ACCESSDENIED, "progress failure preserves its original HRESULT");
    } else if (cancelAt < 0) {
      Check(hr == S_OK, "Render returns S_OK");
      Check(video.served == o.frames, "every frame requested once");
      Check(audio.samples == (o.videoOnly ? 0 : samples), "audio sample count matches delivered duration");
    } else {
      Check(hr == SF_E_RENDER_STOPPED, "cancelled Render returns 0x8004E017 (Voukoder's code)");
      Check(video.served == cancelAt, "no frame requested after the cancel");
    }
    Check(progress.total == o.frames, "progress total = frame count");
    Check(video.outstanding == 0 && video.lockErrors == 0, "frame locks balanced");
    Check(audio.tokenErrors == 0, "audio tokens and positions match the captured shape");
    Check(video.unexpected == 0, "no unobserved video slots called");
    Check(video.ref == 1 && audio.ref == 1 && progress.ref == 1 && meta.ref == 1,
          "all host objects released after the file is released");
  }
  for (SFTEMPLATE* t : {project, preset, pass1, create})
    if (t) alloc->Free(t);
  printf("RENDER TEST %s (%d failure(s))\n", g_failures ? "FAILED" : "PASSED", g_failures);
  return g_failures ? 1 : 0;
}
