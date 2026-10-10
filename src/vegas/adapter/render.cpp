// render.cpp - ISfRenderFile: the render loop and raw output writers.
//
// Loop order follows the working exporter captured on VEGAS 2026 (F-030,
// F-031): frame count (video slot 9), progress total, then per frame
// SetPosition, cancel check, GetRenderFrame, ReleaseRenderFrame, audio Read.
// Audio is read per frame up to round((i + 1) * rate / fps) so it does not
// drift (Voukoder's fixed 1601-sample reads lose ~0.6 samples per frame).
#include "vegas_encoder.h"
#include "../../engine/encode.h"

#include <cmath>
#include <cstdio>
#include <cstring>
#include <new>
#include <algorithm>
#include <limits>

using namespace sfio;

namespace vegas_encoder {
namespace {

LONG g_renderCount = 0;

uint64_t Fnv1a64(const BYTE* p, size_t n) {
  uint64_t h = 0xcbf29ce484222325ull;
  for (size_t i = 0; i < n; i++) {
    h ^= p[i];
    h *= 0x100000001b3ull;
  }
  return h;
}

std::string BaseName(const std::wstring& path) {
  size_t slash = path.find_last_of(L"\\/");
  return Utf8((slash == std::wstring::npos ? path : path.substr(slash + 1)).c_str());
}

class OutFile {
 public:
  ~OutFile() { Close(); }
  bool Open(const std::wstring& path) {
    h_ = CreateFileW(path.c_str(), GENERIC_WRITE, FILE_SHARE_READ, nullptr, CREATE_ALWAYS,
                     FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN, nullptr);
    if (h_ == INVALID_HANDLE_VALUE) {
      error_ = GetLastError();
      BestEffortDiagnostic([&] { Log("cannot create %s: error %lu", Utf8(path.c_str()).c_str(), error_); });
      return false;
    }
    return true;
  }
  bool Write(const void* p, size_t n) {
    const BYTE* b = (const BYTE*)p;
    while (n) {
      DWORD chunk = (DWORD)(n > (1u << 30) ? (1u << 30) : n), done = 0;
      if (!WriteFile(h_, b, chunk, &done, nullptr) || done != chunk) {
        error_ = GetLastError();
        return false;
      }
      b += chunk;
      n -= chunk;
      bytes_ += chunk;
    }
    return true;
  }
  bool WriteAt(uint64_t off, const void* p, size_t n) {
    LARGE_INTEGER pos;
    pos.QuadPart = (LONGLONG)off;
    DWORD done = 0;
    return SetFilePointerEx(h_, pos, nullptr, FILE_BEGIN) && WriteFile(h_, p, (DWORD)n, &done, nullptr) &&
           done == n;
  }
  void Close() {
    if (h_ != INVALID_HANDLE_VALUE) CloseHandle(h_);
    h_ = INVALID_HANDLE_VALUE;
  }
  bool IsOpen() const { return h_ != INVALID_HANDLE_VALUE; }
  uint64_t Bytes() const { return bytes_; }
  DWORD Error() const { return error_; }

 private:
  HANDLE h_ = INVALID_HANDLE_VALUE;
  uint64_t bytes_ = 0;
  DWORD error_ = 0;
};

// RIFF/WAVE with IEEE float (tag 3, fmt 18 + fact) or PCM16 (tag 1).
class WavFile {
 public:
  bool Open(const std::wstring& path, bool isFloat, WORD channels, DWORD rate, WORD align) {
    float_ = isFloat;
    channels_ = channels;
    rate_ = rate;
    align_ = align;
    if (!f_.Open(path)) return false;
    std::vector<BYTE> h = Header(0);
    return f_.Write(h.data(), h.size());
  }
  bool Write(const void* p, size_t n) {
    data_ += n;
    return f_.Write(p, n);
  }
  bool Finish() {
    if (!f_.IsOpen()) return true;
    std::vector<BYTE> h = Header(data_);
    bool ok = f_.WriteAt(0, h.data(), h.size());
    f_.Close();
    return ok;
  }
  DWORD Error() const { return f_.Error(); }

 private:
  std::vector<BYTE> Header(uint64_t dataBytes) const {
    DWORD data = (DWORD)(dataBytes > 0xFFFFFF00ull ? 0xFFFFFF00ull : dataBytes);
    std::vector<BYTE> h;
    auto put = [&h](const void* p, size_t n) { h.insert(h.end(), (const BYTE*)p, (const BYTE*)p + n); };
    auto u32 = [&put](DWORD v) { put(&v, 4); };
    auto u16 = [&put](WORD v) { put(&v, 2); };
    DWORD fmtSize = float_ ? 18 : 16;
    DWORD riff = 4 + (8 + fmtSize) + (float_ ? 12 : 0) + 8 + data;
    put("RIFF", 4);
    u32(riff);
    put("WAVEfmt ", 8);
    u32(fmtSize);
    u16(float_ ? 3 : 1);
    u16(channels_);
    u32(rate_);
    u32(rate_ * align_);
    u16(align_);
    u16((WORD)(8 * align_ / (channels_ ? channels_ : 1)));
    if (float_) {
      u16(0);
      put("fact", 4);
      u32(4);
      u32(align_ ? data / align_ : 0);
    }
    put("data", 4);
    u32(data);
    return h;
  }
  OutFile f_;
  bool float_ = true;
  WORD channels_ = 2, align_ = 8;
  DWORD rate_ = 48000;
  uint64_t data_ = 0;
};

struct Probe {
  std::string stream;
  int slot;
  HRESULT hr;
  std::string value;
};

struct NonOk {
  int slot;
  LONGLONG frame;
  HRESULT hr;
};

struct Report {
  int index = 0;
  std::string status = "failed";
  HRESULT returned = E_FAIL;
  std::string stopReason;
  HRESULT stopHr = S_OK;
  double elapsedMs = 0;
  std::wstring manifestPath;
  std::string videoFile, audioFile, csvFile;
  // template
  DWORD tplCb = 0, tplId = 0;
  std::string tplName, tplFourcc;
  LONG tplWidth = 0, tplHeight = 0;
  WORD tplBits = 0;
  double tplFps = 0;
  SFAUDIORECORD tplAudio{};
  // video
  bool videoPresent = false;
  LONGLONG frameCountReported = -1;
  LONGLONG framesWritten = 0;
  LONG frameBytes = 0;
  std::string fourcc;
  LONG width = 0, height = 0;
  WORD bitCount = 0;
  double fps = 0, pixelAspect = 0;
  DWORD planeFields[6] = {};
  BYTE firstInfo[frameinfo::size] = {};
  bool haveInfo = false;
  LONGLONG infoChanges = 0, sizeChanges = 0;
  LONG tokenMode = -1;
  LONGLONG locksOutstanding = 0;
  // audio
  bool audioPresent = false;
  bool audioAssumed = false;
  std::string wavFormat;
  LONGLONG samplesWritten = 0, samplesExpected = 0, reads = 0, shortReads = 0;
  LONGLONG streamLength = -1;
  // progress / probes / timing
  LONGLONG progressTotal = -1;
  std::vector<NonOk> nonOk;
  std::vector<Probe> probes;
  double msGet = 0, msRelease = 0, msAudio = 0, msWriteVideo = 0, msWriteAudio = 0, msLoop = 0;
  double msProgress = 0, msChecksum = 0;
  bool encoded = false;
  EncodeRate rate;
  EncodeStats encoder;
  std::string encodedFile;
};

class RenderFile final : public ISfRenderFile {
 public:
  explicit RenderFile(Tpl t) : tpl_(std::move(t)) {}
  ~RenderFile() {
    encoder_.reset();
    for (ISfReadStream*& s : streams_)
      if (s) s->Release();
    if (meta_) meta_->Release();
    BestEffortDiagnostic([&] { Log("RenderFile %p destroyed", (void*)this); });
  }

  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void** ppv) override {
    return NativeBoundary([&]() -> HRESULT {
      if (!ppv) return E_POINTER;
      if (riid == IID_IUnknown || riid == __uuidof(ISfRenderFile)) {
        *ppv = static_cast<ISfRenderFile*>(this);
        AddRef();
        return S_OK;
      }
      *ppv = nullptr;
      BestEffortDiagnostic([&] { Log("RenderFile::QueryInterface(%s) -> E_NOINTERFACE", GuidText(riid).c_str()); });
      return E_NOINTERFACE;
    });
  }
  ULONG STDMETHODCALLTYPE AddRef() override { return (ULONG)InterlockedIncrement(&ref_); }
  ULONG STDMETHODCALLTYPE Release() override {
    LONG n = InterlockedDecrement(&ref_);
    if (n == 0) delete this;
    return (ULONG)n;
  }

  HRESULT STDMETHODCALLTYPE CloseFile() override {
    return NativeBoundary([&]() -> HRESULT {
      BestEffortDiagnostic([&] { Log("CloseFile (file %p)", (void*)this); });
      encoder_.reset();
      return S_OK;
    });
  }
  HRESULT STDMETHODCALLTYPE IsFileOpen() override {
    return NativeBoundary([&]() -> HRESULT {
      return Unimplemented("IsFileOpen");
    });
  }
  HRESULT STDMETHODCALLTYPE OpenFile(LONG, LONG) override {
    return NativeBoundary([&]() -> HRESULT {
      return Unimplemented("OpenFile");
    });
  }
  HRESULT STDMETHODCALLTYPE SetFile(LPCWSTR path) override {
    return NativeBoundary([&]() -> HRESULT {
      path_ = path ? path : L"";
      BestEffortDiagnostic([&] { Log("SetFile(%s)", Utf8(path_.c_str()).c_str()); });
      return S_OK;
    });
  }
  HRESULT STDMETHODCALLTYPE GetFileName(LPWSTR path, LONG cch) override {
    return NativeBoundary([&]() -> HRESULT {
      if (!path || cch <= 0) return E_POINTER;
      wcsncpy_s(path, (size_t)cch, path_.c_str(), _TRUNCATE);
      BestEffortDiagnostic([&] { Log("GetFileName(cch=%ld) -> %s", cch, Utf8(path).c_str()); });
      return S_OK;
    });
  }
  HRESULT STDMETHODCALLTYPE GetStreamCount(LONG* count) override {
    return NativeBoundary([&]() -> HRESULT {
      if (!count) return E_POINTER;
      *count = (LONG)streams_.size();
      BestEffortDiagnostic([&] { Log("GetStreamCount -> %ld", *count); });
      return S_OK;
    });
  }
  HRESULT STDMETHODCALLTYPE GetStreamFormatInfo(void*, LONG, LONG) override {
    return NativeBoundary([&]() -> HRESULT {
      return Unimplemented("GetStreamFormatInfo");
    });
  }
  HRESULT STDMETHODCALLTYPE SetStreamFormatInfo(const void*, LONG) override {
    return NativeBoundary([&]() -> HRESULT {
      return Unimplemented("SetStreamFormatInfo");
    });
  }
  HRESULT STDMETHODCALLTYPE SetStreamReader(ISfReadStream* s, LONG index) override {
    return NativeBoundary([&]() -> HRESULT {
      if (index < 0 || index > 15) return E_INVALIDARG;
      if (streams_.size() <= (size_t)index) streams_.resize((size_t)index + 1, nullptr);
      if (s) s->AddRef();
      if (streams_[index]) streams_[index]->Release();
      streams_[index] = s;
      BestEffortDiagnostic([&] { Log("SetStreamReader(%p, %ld)", (void*)s, index); });
      return S_OK;
    });
  }
  HRESULT STDMETHODCALLTYPE SetMetaReader(ISfReadMeta* meta) override {
    return NativeBoundary([&]() -> HRESULT {
      if (meta) meta->AddRef();
      if (meta_) meta_->Release();
      meta_ = meta;
      BestEffortDiagnostic([&] { Log("SetMetaReader(%p)", (void*)meta); });
      return S_OK;
    });
  }
  HRESULT STDMETHODCALLTYPE GetTemplate(SFTEMPLATE** t, LONG) override {
    return NativeBoundary([&]() -> HRESULT {
      if (t) *t = nullptr;
      return Unimplemented("GetTemplate");
    });
  }
  HRESULT STDMETHODCALLTYPE EstimateFileSize(LONGLONG*) override {
    return NativeBoundary([&]() -> HRESULT {
      return Unimplemented("EstimateFileSize");
    });
  }
  HRESULT STDMETHODCALLTYPE Render(ISfProgress* progress) override {
    return NativeBoundary([&]() -> HRESULT {
      try {
        HRESULT hr = (Cfg().encode || !Cfg().validMode) ? DoEncode(progress) : DoRender(progress);
        encoder_.reset();
        return hr;
      } catch (const std::bad_alloc&) {
        encoder_.reset();
        BestEffortDiagnostic([&] { Log("Render: out of memory"); });
        return E_OUTOFMEMORY;
      } catch (...) {
        encoder_.reset();
        BestEffortDiagnostic([&] { Log("Render: unexpected C++ exception"); });
        return E_UNEXPECTED;
      }
    });
  }
  HRESULT STDMETHODCALLTYPE UpdateMetaData(LONG, LONG) override {
    return NativeBoundary([&]() -> HRESULT {
      return Unimplemented("UpdateMetaData");
    });
  }

 private:
  HRESULT Unimplemented(const char* name) {
    BestEffortDiagnostic([&] { Log("RenderFile::%s -> E_NOTIMPL", name); });
    return E_NOTIMPL;
  }

  void Stop(Report& r, const char* status, const char* reason, HRESULT hr) {
    r.status = status;
    r.stopReason = reason;
    r.stopHr = hr;
    BestEffortDiagnostic([&] { Log("render stopped: %s (%s) hr=%s", status, reason, Hr(hr).c_str()); });
  }

  void ReadTemplate(Report& r) {
    r.tplCb = tpl_.U32(tpl::cbStruct);
    r.tplId = tpl_.U32(tpl::id);
    r.tplName = Utf8(tpl_.Name().c_str());
    BITMAPINFOHEADER h = tpl_.Bih(tpl::videoRenderBih);
    r.tplFourcc = FourCC(h.biCompression);
    r.tplWidth = h.biWidth;
    r.tplHeight = h.biHeight;
    r.tplBits = h.biBitCount;
    r.tplFps = tpl_.F64(tpl::vexFps);
    r.tplAudio = tpl_.Audio(tpl::audioRender);
  }

  template <class T>
  void ProbeValue(Report& r, const char* stream, int slot, HRESULT hr, T value) {
    char s[64];
    snprintf(s, sizeof s, "%lld", (long long)value);
    r.probes.push_back({stream, slot, hr, s});
    BestEffortDiagnostic([&] { Log("probe %s slot %d -> %s value=%s", stream, slot, Hr(hr).c_str(), s); });
  }
  void ProbeBlock(Report& r, const char* stream, int slot, HRESULT hr, const BYTE* p) {
    r.probes.push_back({stream, slot, hr, HexBytes(p, 184)});
    BestEffortDiagnostic([&] { Log("probe %s slot %d -> %s", stream, slot, Hr(hr).c_str()); });
    if (SUCCEEDED(hr)) LogHex("  184-byte format", p, 184);
  }

  // Out-only getters whose shapes come from the host's MIDL stub (F-026).
  // Called once per render for evidence; meanings are not assumed.
  void ProbeGetters(Report& r, ISfReadVideoRenderStream* v, ISfReadAudioStream* a) {
    // Each call is made before its value is read (argument order is unspecified).
    BYTE block[512];
    HRESULT hr;
    if (v) {
      BestEffortDiagnostic([&] { Log("probing video getters (stub shapes; log flushed before each call)"); });
      LONG l = 0;
      LONGLONG q = 0;
      hr = v->Slot4(&l);
      ProbeValue(r, "video", 4, hr, l);
      hr = v->GetStreamLength(&q);
      ProbeValue(r, "video", 6, hr, q);
      q = 0;
      hr = v->Slot7(&q);
      ProbeValue(r, "video", 7, hr, q);
      memset(block, 0, sizeof block);
      hr = v->GetFormat10(block);
      ProbeBlock(r, "video", 10, hr, block);
      memset(block, 0, sizeof block);
      hr = v->GetReadVideoFormat(block);
      ProbeBlock(r, "video", 11, hr, block);
    }
    if (a) {
      BestEffortDiagnostic([&] { Log("probing audio getters (stub shapes; log flushed before each call)"); });
      LONG l = 0;
      LONGLONG q = 0;
      hr = a->Slot4(&l);
      ProbeValue(r, "audio", 4, hr, l);
      hr = a->GetStreamLength(&q);
      ProbeValue(r, "audio", 6, hr, q);
      q = 0;
      hr = a->Slot7(&q);
      ProbeValue(r, "audio", 7, hr, q);
      q = 0;
      hr = a->GetSampleCount(&q);
      ProbeValue(r, "audio", 9, hr, q);
      if (hr == S_OK && q > 0) r.streamLength = q;
      l = 0;
      hr = a->Slot10(&l);
      ProbeValue(r, "audio", 10, hr, l);
      memset(block, 0, sizeof block);
      hr = a->GetFormat11(block);
      ProbeBlock(r, "audio", 11, hr, block);
      memset(block, 0, sizeof block);
      hr = a->GetFormat12(block);
      ProbeBlock(r, "audio", 12, hr, block);
      LONGLONG q1 = 0, q2 = 0;
      LONG l3 = 0;
      hr = a->Slot15(&q1, &q2, &l3);
      char s[96];
      snprintf(s, sizeof s, "%lld,%lld,%ld", q1, q2, l3);
      r.probes.push_back({"audio", 15, hr, s});
      BestEffortDiagnostic([&] { Log("probe audio slot 15 -> %s value=%s", Hr(hr).c_str(), s); });
    }
  }

  bool CheckProgress(Report& r, ISfProgress* p, LONGLONG frame) {
    if (!p) return true;
    HRESULT hr = p->SetPosition(frame);
    if (hr != S_OK) r.nonOk.push_back({6, frame, hr});
    if (FAILED(hr)) {
      Stop(r, "cancelled", "progress SetPosition failed", hr);
      return false;
    }
    hr = p->CheckCancel();
    if (hr != S_OK) r.nonOk.push_back({7, frame, hr});
    if (FAILED(hr)) {
      Stop(r, "cancelled", "progress slot 7 failed", hr);
      return false;
    }
    return true;
  }

  // Phase-3 proof kept separate so the phase-2 raw writer remains a regression path.
  HRESULT DoEncode(ISfProgress* progress) {
    Report r;
    r.index = InterlockedIncrement(&g_renderCount);
    r.encoded = true;
    r.manifestPath = path_ + L".vegas-encoder.json";
    double start = NowMs();
    ReadTemplate(r);
    const Config& cfg = Cfg();
    std::unique_ptr<ISfReadVideoRenderStream, ComRelease> video;
    std::unique_ptr<ISfReadAudioStream, ComRelease> audio;
    for (auto* s : streams_) {
      if (!s) continue;
      ISfReadVideoRenderStream* v = nullptr;
      ISfReadAudioStream* a = nullptr;
      if (!video && SUCCEEDED(s->QueryInterface(__uuidof(ISfReadVideoRenderStream), (void**)&v))) video.reset(v);
      else if (!audio && SUCCEEDED(s->QueryInterface(__uuidof(ISfReadAudioStream), (void**)&a))) audio.reset(a);
    }
    r.videoPresent = video != nullptr;
    r.audioPresent = audio != nullptr;
    SFAUDIORECORD fmt = r.tplAudio;
    bool ok = true;
    auto fail = [&](const char* why, HRESULT hr) { Stop(r, "failed", why, FAILED(hr) ? hr : E_FAIL); ok = false; };
    auto poll = [&](LONGLONG position) {
      double t = NowMs();
      bool go = CheckProgress(r, progress, position);
      r.msProgress += NowMs() - t;
      if (!go) ok = false;
      return go;
    };
    if (!cfg.validMode) fail("OutputMode must be ffmpeg or raw", E_INVALIDARG);
    else if (path_.size() < 4 || _wcsicmp(path_.c_str() + path_.size() - 4, L".mkv") != 0)
      fail("choose a .mkv output filename for the fixed FFmpeg profile", E_INVALIDARG);
    else if (!video) fail("fixed FFmpeg profile requires a video render stream", E_NOINTERFACE);
    else if (audio && (fmt.format != SFAUDIO_FORMAT_FLOAT32 || fmt.sampleRate != 48000 ||
                       fmt.channels != 2 || fmt.blockAlign != 8))
      fail("fixed FFmpeg profile requires float32 stereo at 48000 Hz", E_INVALIDARG);
    if (ok) {
      HRESULT hr = video->GetFrameCount(&r.frameCountReported);
      if (FAILED(hr) || r.frameCountReported <= 0) fail("cannot obtain a positive frame count", hr);
    }
    if (ok && audio) {
      HRESULT hr = audio->GetSampleCount(&r.streamLength);
      if (FAILED(hr) || r.streamLength < 0) fail("cannot obtain audio sample count", hr);
    }
    if (ok && progress) {
      r.progressTotal = r.frameCountReported;
      HRESULT hr = progress->SetTotal(r.frameCountReported);
      if (FAILED(hr)) fail("progress SetTotal failed", hr);
    }
    double streamFps = 0;
    if (ok) {
      BYTE sf[streamfmt::size]{};
      if (SUCCEEDED(video->GetReadVideoFormat(sf))) memcpy(&streamFps, sf + streamfmt::fps, sizeof streamFps);
    }
    for (LONGLONG frame = 0; ok && frame < r.frameCountReported; frame++) {
      if (!poll(frame)) break;
      SFMEMORYTOKEN tok{};
      LONG_PTR lock = 0;
      BYTE info[frameinfo::size]{};
      LONG count = 0;
      double t = NowMs();
      HRESULT hr = video->GetRenderFrame(frame, &tok, &lock, info, &count);
      r.msGet += NowMs() - t;
      if (FAILED(hr)) { fail("GetRenderFrame failed", hr); break; }
      FrameLease lease(video.get(), lock, r.locksOutstanding);
      BITMAPINFOHEADER bih{};
      double fps = 0, par = 0;
      LONGLONG index = -1;
      DWORD planes[6]{};
      memcpy(&bih, info + frameinfo::bih, sizeof bih);
      memcpy(&fps, info + frameinfo::fps, sizeof fps);
      memcpy(&par, info + frameinfo::pixelAspect, sizeof par);
      memcpy(&index, info + frameinfo::frame, sizeof index);
      memcpy(planes, info + frameinfo::planeFields, sizeof planes);
      std::vector<BYTE> owned;
      uint64_t row = bih.biWidth > 0 ? (uint64_t)bih.biWidth * 2 : 0;
      uint64_t height = bih.biHeight > 0 ? (uint64_t)bih.biHeight : 0;
      uint64_t packed = row * height * 3 / 2;
      bool layout = bih.biCompression == MAKEFOURCC('P', '0', '1', '0') && row && height &&
        bih.biWidth <= 8192 && bih.biHeight <= 8192 && !(bih.biWidth & 1) && !(bih.biHeight & 1) &&
        packed <= 64u * 1024 * 1024 && planes[0] >= row && planes[2] >= row &&
        (uint64_t)planes[0] * (height - 1) + row <= planes[1] &&
        (uint64_t)planes[1] + (uint64_t)planes[2] * (height / 2 - 1) + row <= (uint64_t)count &&
        count > 0 && tok.cbData == count && tok.offset >= 0 && tok.cbAlloc >= 0 &&
        (uint64_t)tok.offset + (uint64_t)count <= (uint64_t)tok.cbAlloc && tok.pData &&
        tok.pData <= (std::numeric_limits<ULONGLONG>::max)() - (uint64_t)tok.offset &&
        tok.pid == GetCurrentProcessId() && (tok.mode == 0 || tok.mode == 1) &&
        index == frame && std::isfinite(fps) && std::isfinite(par) && std::abs(par - 1.0) < 1e-8;
      if (!layout) fail("unsupported P010 layout/token/aspect; inspect the frame log", E_INVALIDARG);
      if (ok && !r.haveInfo) {
        r.haveInfo = true;
        r.fourcc = "P010"; r.width = bih.biWidth; r.height = bih.biHeight; r.bitCount = bih.biBitCount;
        r.fps = fps; r.pixelAspect = par; r.frameBytes = (LONG)packed; r.tokenMode = tok.mode;
        r.rate = EncodeRate::FromDouble(fps);
        memcpy(r.firstInfo, info, sizeof info);
        memcpy(r.planeFields, planes, sizeof planes);
        LogHex("FFmpeg first frame info", info, sizeof info);
        BestEffortDiagnostic([&] { Log("FFmpeg delivered P010 %ldx%ld fps=%.17g (%s), stream fps=%.17g", r.width, r.height,
            fps, Utf8(r.rate.Text().c_str()).c_str(), streamFps); });
        if (!r.rate.num || (streamFps && (!std::isfinite(streamFps) || std::abs(streamFps - fps) > 1e-8)))
          fail("unsupported or inconsistent delivered frame rate", E_INVALIDARG);
        LONGLONG expected = 0;
        if (ok && audio && (!r.rate.Endpoint(r.frameCountReported, fmt.sampleRate, expected) ||
                            std::abs(expected - r.streamLength) > 1))
          fail("audio length differs from delivered video duration", E_INVALIDARG);
        r.samplesExpected = audio ? r.streamLength : 0;
      } else if (ok && (bih.biWidth != r.width || bih.biHeight != r.height ||
                         std::abs(fps - r.fps) > 1e-8 || memcmp(planes, r.planeFields, sizeof planes))) {
        r.infoChanges++;
        fail("frame format changed during encoding", E_INVALIDARG);
      }
      if (ok) {
        t = NowMs();
        owned.resize((size_t)packed);
        const BYTE* data = reinterpret_cast<const BYTE*>((uintptr_t)(tok.pData + (uint64_t)tok.offset));
        for (size_t y = 0; y < (size_t)height; y++)
          memcpy(owned.data() + y * (size_t)row, data + y * planes[0], (size_t)row);
        for (size_t y = 0; y < (size_t)height / 2; y++)
          memcpy(owned.data() + (size_t)(row * height) + y * (size_t)row,
                 data + planes[1] + y * planes[2], (size_t)row);
        r.msWriteVideo += NowMs() - t;
      }
      t = NowMs();
      HRESULT released = lease.Release();
      r.msRelease += NowMs() - t;
      if (FAILED(released)) fail("ReleaseRenderFrame failed", released);
      if (!ok) break;  // no host frame is held from this point forward
      if (!encoder_) {
        encoder_.reset(new FfmpegEncoder);
        if (!encoder_->Start(cfg.ffmpegPath, path_, r.width, r.height, r.rate, audio != nullptr,
                             cfg.pipeTimeoutMs, cfg.finishTimeoutMs)) {
          fail(encoder_->Reason().c_str(), encoder_->Error()); break;
        }
      }
      auto keepGoing = [&] { return poll(frame); };
      if (!encoder_->Submit(false, std::move(owned), keepGoing)) {
        if (r.status != "cancelled") fail(encoder_->Reason().c_str(), encoder_->Error());
        break;
      }
      r.framesWritten++;
      if (audio) {
        LONGLONG endpoint = 0;
        if (!r.rate.Endpoint(frame + 1, fmt.sampleRate, endpoint)) { fail("audio timing overflow", E_INVALIDARG); break; }
        if (frame + 1 == r.frameCountReported) endpoint = r.streamLength;
        endpoint = (std::min)(endpoint, r.streamLength);
        while (ok && r.samplesWritten < endpoint) {
          if (!poll(frame)) break;
          LONG want = (LONG)((std::min)(endpoint - r.samplesWritten, (LONGLONG)4096));
          std::vector<BYTE> samples((size_t)want * fmt.blockAlign);
          SFMEMORYTOKEN at{};
          at.pData = (ULONGLONG)(uintptr_t)samples.data();
          at.cbData = at.cbAlloc = want * fmt.blockAlign;
          at.pid = GetCurrentProcessId();
          LONG got = 0;
          t = NowMs();
          hr = audio->Read(r.samplesWritten, &at, want, &got);
          r.msAudio += NowMs() - t;
          r.reads++;
          if (FAILED(hr) || got <= 0 || got > want) {
            fail("audio Read failed or returned an invalid/early-zero count", FAILED(hr) ? hr : E_UNEXPECTED); break;
          }
          if (got < want) r.shortReads++;
          samples.resize((size_t)got * fmt.blockAlign);  // S_FALSE with data is consumed
          if (!encoder_->Submit(true, std::move(samples), keepGoing)) {
            if (r.status != "cancelled") fail(encoder_->Reason().c_str(), encoder_->Error());
            break;
          }
          r.samplesWritten += got;
        }
      }
    }
    if (ok && encoder_) {
      auto finalPoll = [&] { return poll(r.frameCountReported); };
      if (!encoder_->Finish(finalPoll)) {
        if (r.status != "cancelled") fail(encoder_->Reason().c_str(), encoder_->Error());
      }
    }
    if (encoder_) {
      if (!ok) encoder_->Abort();
      r.encoder = encoder_->Stats();
    }
    r.elapsedMs = NowMs() - start;
    if (ok) { r.status = "ok"; r.returned = S_OK; r.encodedFile = BaseName(path_); }
    else r.returned = r.status == "cancelled" ? SF_E_RENDER_STOPPED : (FAILED(r.stopHr) ? r.stopHr : E_FAIL);
    WriteManifest(r, fmt);
    BestEffortDiagnostic([&] { Log("FFmpeg render: %s hr=%s frames=%lld samples=%lld exit=%lu published=%d", r.status.c_str(),
        Hr(r.returned).c_str(), r.framesWritten, r.samplesWritten, r.encoder.exitCode, r.encoder.published); });
    if (!ok && r.status != "cancelled" && cfg.showEncoderErrors) {
      std::wstring message = L"FFmpeg render failed: " + Widen(r.stopReason) + L"\n" + Widen(Hr(r.stopHr)) +
        L"\nEncoder log: " + r.encoder.stderrPath + L"\nManifest: " + r.manifestPath;
      MessageBoxW(nullptr, message.c_str(), L"Vegas Encoder", MB_OK | MB_ICONERROR);
    }
    return r.returned;
  }

  HRESULT DoRender(ISfProgress* progress) {
    Report r;
    r.index = InterlockedIncrement(&g_renderCount);
    double t0 = NowMs();
    const Config& cfg = Cfg();
    BestEffortDiagnostic([&] { Log("Render #%d begin (file %p, progress %p, %zu stream slots)", r.index, (void*)this, (void*)progress,
        streams_.size()); });
    ReadTemplate(r);

    std::wstring out = path_;
    if (out.empty()) {
      wchar_t name[64];
      swprintf_s(name, L"\\render-%lu-%d.ffdiag", GetCurrentProcessId(), r.index);
      out = cfg.logDir + name;
      BestEffortDiagnostic([&] { Log("no output path from host; using %s", Utf8(out.c_str()).c_str()); });
    }
    r.manifestPath = out;

    ISfReadVideoRenderStream* video = nullptr;
    ISfReadAudioStream* audio = nullptr;
    for (size_t i = 0; i < streams_.size(); i++) {
      ISfReadStream* s = streams_[i];
      if (!s) continue;
      if (!video && SUCCEEDED(s->QueryInterface(__uuidof(ISfReadVideoRenderStream), (void**)&video))) {
        BestEffortDiagnostic([&] { Log("stream %zu: video render stream %p", i, (void*)video); });
        continue;
      }
      if (!audio && SUCCEEDED(s->QueryInterface(__uuidof(ISfReadAudioStream), (void**)&audio))) {
        BestEffortDiagnostic([&] { Log("stream %zu: audio stream %p", i, (void*)audio); });
        continue;
      }
      BestEffortDiagnostic([&] { Log("stream %zu: neither video render nor audio stream", i); });
    }
    r.videoPresent = video != nullptr;
    r.audioPresent = audio != nullptr;

    // Audio format comes from our conformed template (+0x48).
    SFAUDIORECORD fmt = r.tplAudio;
    if (audio && (!fmt.sampleRate || !fmt.channels || !fmt.blockAlign)) {
      fmt = Float32Record(48000, 2);
      r.audioAssumed = true;
      BestEffortDiagnostic([&] { Log("template audio record empty; assuming float32 stereo 48000"); });
    }

    OutFile vfile;
    WavFile wav;
    OutFile rawAudio;
    FILE* csv = nullptr;
    bool ok = true;
    if (video && cfg.writeVideo) {
      r.videoFile = BaseName(out) + ".video.raw";
      ok = vfile.Open(out + L".video.raw");
    }
    if (ok && audio && cfg.writeAudio) {
      bool isFloat = fmt.format == SFAUDIO_FORMAT_FLOAT32, isPcm16 = fmt.format == SFAUDIO_FORMAT_PCM16;
      if (isFloat || isPcm16) {
        r.wavFormat = isFloat ? "ieee_float32" : "pcm16";
        r.audioFile = BaseName(out) + ".audio.wav";
        ok = wav.Open(out + L".audio.wav", isFloat, fmt.channels, fmt.sampleRate, fmt.blockAlign);
      } else {
        r.wavFormat = "raw";
        r.audioFile = BaseName(out) + ".audio.raw";
        ok = rawAudio.Open(out + L".audio.raw");
      }
    }
    if (ok && _wfopen_s(&csv, (out + L".frames.csv").c_str(), L"wb") == 0 && csv) {
      r.csvFile = BaseName(out) + ".frames.csv";
      fprintf(csv,
              "frame,video_hr,get_ms,token_handle,token_cb,token_alloc,token_offset,token_mode,lock,"
              "cb_out,info_index,checksum,audio_pos,audio_req,audio_got,audio_hr,audio_ms\n");
    }
    if (!ok) {
      DWORD err = vfile.Error() ? vfile.Error() : wav.Error() ? wav.Error() : rawAudio.Error();
      Stop(r, "failed", "cannot create output files", HRESULT_FROM_WIN32(err));
    }
    if (ok && !video && !audio) {
      Stop(r, "failed", "no video render or audio stream", E_UNEXPECTED);
      ok = false;
    }

    if (ok && cfg.probeGetters) ProbeGetters(r, video, audio);

    LONGLONG total = 0;
    HRESULT hr = S_OK;
    if (ok && video) {
      hr = video->GetFrameCount(&total);
      r.frameCountReported = total;
      BestEffortDiagnostic([&] { Log("GetFrameCount -> %s %lld", Hr(hr).c_str(), total); });
      if (FAILED(hr)) {
        Stop(r, "failed", "GetFrameCount failed", hr);
        ok = false;
      }
    } else if (ok) {
      // Audio-only: the length getter is the only candidate source.
      total = r.streamLength > 0 ? (r.streamLength + fmt.sampleRate / 10 - 1) / (fmt.sampleRate / 10) : 0;
      if (total <= 0) {
        Stop(r, "failed", "audio-only render without a reported stream length", E_UNEXPECTED);
        ok = false;
      }
    }
    if (ok && progress) {
      hr = progress->SetTotal(total);
      r.progressTotal = total;
      if (hr != S_OK) r.nonOk.push_back({5, -1, hr});
    }

    std::vector<BYTE> abuf;
    LONGLONG audioPos = 0;
    bool audioDone = false;
    double loopStart = NowMs();
    for (LONGLONG i = 0; ok && i < total; i++) {
      double tp = NowMs();
      bool go = CheckProgress(r, progress, i);
      r.msProgress += NowMs() - tp;
      if (!go) {
        ok = false;
        break;
      }
      char row[512];
      int k = snprintf(row, sizeof row, "%lld", i);
      if (video) {
        SFMEMORYTOKEN tok{};
        LONG_PTR lock = 0;
        BYTE info[frameinfo::size] = {};
        LONG cb = 0;
        double t = NowMs();
        hr = video->GetRenderFrame(i, &tok, &lock, info, &cb);
        double dt = NowMs() - t;
        r.msGet += dt;
        if (FAILED(hr)) {
          snprintf(row + k, sizeof row - k, ",%s,%.3f\n", Hr(hr).c_str(), dt);
          if (csv) fputs(row, csv);
          Stop(r, "failed", "GetRenderFrame failed", hr);
          ok = false;
          break;
        }
        r.locksOutstanding++;
        const BYTE* data = (const BYTE*)(uintptr_t)(tok.pData + (ULONGLONG)(LONG)tok.offset);
        LONG size = tok.cbData;
        LONGLONG infoFrame;
        memcpy(&infoFrame, info + frameinfo::frame, 8);
        if (!r.haveInfo) {
          r.haveInfo = true;
          memcpy(r.firstInfo, info, sizeof info);
          BITMAPINFOHEADER h;
          memcpy(&h, info + frameinfo::bih, sizeof h);
          r.fourcc = FourCC(h.biCompression);
          r.width = h.biWidth;
          r.height = h.biHeight;
          r.bitCount = h.biBitCount;
          memcpy(&r.fps, info + frameinfo::fps, 8);
          memcpy(&r.pixelAspect, info + frameinfo::pixelAspect, 8);
          memcpy(r.planeFields, info + frameinfo::planeFields, sizeof r.planeFields);
          r.frameBytes = size;
          r.tokenMode = tok.mode;
          BestEffortDiagnostic([&] { Log("first frame: token {h=0x%llx data=%p cb=%ld alloc=%ld off=%ld res=%ld mode=%ld pid=%lu} lock=0x%llx cb=%ld",
              tok.hHandle, (const void*)data, tok.cbData, tok.cbAlloc, tok.offset, tok.reserved, tok.mode, tok.pid,
              (unsigned long long)lock, cb); });
          BestEffortDiagnostic([&] { Log("first frame: %s %ldx%ld bits=%u fps=%.17g par=%.17g planes {%lu,%lu,%lu,%lu,%lu,%lu}",
              r.fourcc.c_str(), r.width, r.height, r.bitCount, r.fps, r.pixelAspect, r.planeFields[0],
              r.planeFields[1], r.planeFields[2], r.planeFields[3], r.planeFields[4], r.planeFields[5]); });
          LogHex("first frame info", info, sizeof info);
        } else {
          if (memcmp(info + 8, r.firstInfo + 8, sizeof info - 8) != 0 && r.infoChanges++ < 3) {
            BestEffortDiagnostic([&] { Log("frame %lld: frame info differs from frame 0", i); });
            LogHex("frame info", info, sizeof info);
          }
          if (size != r.frameBytes && r.sizeChanges++ < 3) BestEffortDiagnostic([&] { Log("frame %lld: size %ld != %ld", i, size, r.frameBytes); });
        }
        if (infoFrame != i && LogDetail("render.infoframe")) BestEffortDiagnostic([&] { Log("frame %lld: info +0x00 reports %lld", i, infoFrame); });
        t = NowMs();
        uint64_t sum = (data && size > 0) ? Fnv1a64(data, (size_t)size) : 0;
        r.msChecksum += NowMs() - t;
        if (vfile.IsOpen() && ok) {
          t = NowMs();
          if (!data || size <= 0 || !vfile.Write(data, (size_t)size)) {
            Stop(r, "failed", "video write failed", HRESULT_FROM_WIN32(vfile.Error()));
            ok = false;
          } else {
            r.framesWritten++;
          }
          r.msWriteVideo += NowMs() - t;
        } else if (data && size > 0) {
          r.framesWritten++;  // counted, not stored (WriteVideo=0)
        }
        t = NowMs();
        HRESULT rh = video->ReleaseRenderFrame(lock);
        r.msRelease += NowMs() - t;
        if (SUCCEEDED(rh)) r.locksOutstanding--;
        else BestEffortDiagnostic([&] { Log("frame %lld: ReleaseRenderFrame(0x%llx) -> %s", i, (unsigned long long)lock, Hr(rh).c_str()); });
        k += snprintf(row + k, sizeof row - k, ",%s,%.3f,0x%llx,%ld,%ld,%ld,%ld,0x%llx,%ld,%lld,%016llx",
                      Hr(hr).c_str(), dt, tok.hHandle, tok.cbData, tok.cbAlloc, tok.offset, tok.mode,
                      (unsigned long long)lock, cb, infoFrame, (unsigned long long)sum);
        if (i < 3 || (i & (i - 1)) == 0) BestEffortDiagnostic([&] { Log("frame %lld: %.3f ms size %ld checksum %016llx", i, dt, size,
                                             (unsigned long long)sum); });
      } else {
        k += snprintf(row + k, sizeof row - k, ",,,,,,,,,,,");
      }

      if (ok && audio && !audioDone) {
        double fps = r.fps > 0 ? r.fps : r.tplFps;
        LONGLONG end = video ? (fps > 0 ? llround((double)(i + 1) * fmt.sampleRate / fps) : audioPos + fmt.sampleRate / 30)
                             : (r.streamLength < (i + 1) * (fmt.sampleRate / 10) ? r.streamLength
                                                                                 : (i + 1) * (fmt.sampleRate / 10));
        LONG want = (LONG)(end - audioPos);
        LONG got = 0;
        HRESULT ah = S_OK;
        double t = NowMs();
        if (want > 0) {
          size_t bytes = (size_t)want * fmt.blockAlign;
          if (abuf.size() < bytes) abuf.resize(bytes);
          SFMEMORYTOKEN tok{};  // exporter-filled local token (F-031)
          tok.pData = (ULONGLONG)(uintptr_t)abuf.data();
          tok.cbData = (LONG)bytes;
          tok.cbAlloc = (LONG)bytes;
          tok.mode = 0;
          tok.pid = GetCurrentProcessId();
          ah = audio->Read(audioPos, &tok, want, &got);
          r.reads++;
          if (r.reads <= 2) BestEffortDiagnostic([&] { Log("audio read %lld: pos %lld want %ld -> %s got %ld", r.reads, audioPos, want,
                                Hr(ah).c_str(), got); });
        }
        double dt = NowMs() - t;
        r.msAudio += dt;
        if (FAILED(ah)) {
          Stop(r, "failed", "audio Read failed", ah);
          ok = false;
        } else if (want > 0) {
          if (got < 0 || got > want) {
            BestEffortDiagnostic([&] { Log("audio read at %lld: got %ld outside 0..%ld; treating as %ld", audioPos, got, want, want); });
            got = want;
          }
          if (got < want) r.shortReads++;
          if (got == 0) {
            audioDone = true;
            BestEffortDiagnostic([&] { Log("audio read at %lld returned 0 samples; no further audio reads", audioPos); });
          }
          size_t bytes = (size_t)got * fmt.blockAlign;
          t = NowMs();
          bool w = true;
          if (cfg.writeAudio) w = r.wavFormat == "raw" ? rawAudio.Write(abuf.data(), bytes) : wav.Write(abuf.data(), bytes);
          r.msWriteAudio += NowMs() - t;
          if (!w) {
            Stop(r, "failed", "audio write failed", E_FAIL);
            ok = false;
          }
          audioPos += got;
          r.samplesWritten += got;
        }
        snprintf(row + k, sizeof row - k, ",%lld,%ld,%ld,%s,%.3f\n", audioPos - got, want, got, Hr(ah).c_str(), dt);
      } else {
        snprintf(row + k, sizeof row - k, ",,,,,\n");
      }
      if (csv) fputs(row, csv);
    }
    r.msLoop = NowMs() - loopStart;

    if (video) video->Release();
    if (audio) audio->Release();
    if (ok) {
      r.status = "ok";
      r.returned = S_OK;
    } else {
      // Voukoder Pro returns this for every in-loop stop (F-038).
      r.returned = SF_E_RENDER_STOPPED;
    }
    double fps = r.fps > 0 ? r.fps : r.tplFps;
    if (r.audioPresent && fps > 0 && r.videoPresent)
      r.samplesExpected = llround((double)r.framesWritten * fmt.sampleRate / fps);
    else if (r.audioPresent)
      r.samplesExpected = r.streamLength;
    if (!wav.Finish()) BestEffortDiagnostic([&] { Log("WAV header update failed: %lu", wav.Error()); });
    rawAudio.Close();
    vfile.Close();
    if (csv) fclose(csv);
    r.elapsedMs = NowMs() - t0;
    WriteManifest(r, fmt);
    BestEffortDiagnostic([&] { Log("Render #%d end: %s returned %s frames %lld/%lld samples %lld (expected %lld) %.1f ms", r.index,
        r.status.c_str(), Hr(r.returned).c_str(), r.framesWritten, r.frameCountReported, r.samplesWritten,
        r.samplesExpected, r.elapsedMs); });
    return r.returned;
  }

  void WriteManifest(const Report& r, const SFAUDIORECORD& fmt) {
    std::string j;
    char s[512];
    auto add = [&j](const std::string& x) { j += x; };
    auto str = [](const std::string& x) { return "\"" + JsonEscape(x) + "\""; };
    auto opt = [&str](const std::string& x) { return x.empty() ? std::string("null") : str(x); };
    std::string dll = ModulePath(g_module), host = ModulePath(nullptr);
    add("{\n  \"schema\": \"ffbridge-diag/1\",\n");
    add("  \"plugin\": {\"name\": \"vegas-encoder\", \"version\": " + str(kVersion) + ", \"dll\": " + str(dll) +
        ", \"dll_sha256\": " + str(Sha256File(Widen(dll))) + "},\n");
    snprintf(s, sizeof s, ", \"pid\": %lu},\n", GetCurrentProcessId());
    add("  \"host\": {\"exe\": " + str(host) + ", \"version\": " + str(FileVersion(host)) + s);
    snprintf(s, sizeof s, "  \"render\": {\"index\": %d, \"status\": %s, \"returned_hresult\": \"%s\", ", r.index,
             str(r.status).c_str(), Hr(r.returned).c_str());
    add(s);
    snprintf(s, sizeof s, "\"stop_reason\": %s, \"stop_hresult\": \"%s\", \"elapsed_ms\": %.3f},\n",
             str(r.stopReason).c_str(), Hr(r.stopHr).c_str(), r.elapsedMs);
    add(s);
    add("  \"files\": {\"manifest\": " + str(BaseName(r.manifestPath)) + ", \"video\": " + opt(r.videoFile) +
        ", \"audio\": " + opt(r.audioFile) + ", \"frames_csv\": " + opt(r.csvFile) +
        ", \"encoded\": " + opt(r.encodedFile) + "},\n");
    if (r.encoded) {
      add("  \"encoder\": {\"profile\": \"ffv1-pcm-f32-mkv\", \"exe\": " + str(Utf8(Cfg().ffmpegPath.c_str())) +
          ", \"exe_sha256\": " + str(Sha256File(Cfg().ffmpegPath)) + ", \"command\": " + str(Utf8(r.encoder.command.c_str())) +
          ", \"stderr\": " + str(Utf8(r.encoder.stderrPath.c_str())) + ", \"temporary_output\": " + str(Utf8(r.encoder.tempPath.c_str())) + ", ");
      snprintf(s, sizeof s, "\"pid\": %lu, \"exit_code\": %lu, \"published\": %s, \"fps_num\": %lu, \"fps_den\": %lu, "
               "\"video_bytes\": %llu, \"audio_bytes\": %llu, \"video_queue_high_water\": %llu, \"audio_queue_high_water\": %llu},\n",
               r.encoder.pid, r.encoder.exitCode, r.encoder.published ? "true" : "false", r.rate.num, r.rate.den,
               (unsigned long long)r.encoder.videoBytes, (unsigned long long)r.encoder.audioBytes,
               (unsigned long long)r.encoder.videoHighWater, (unsigned long long)r.encoder.audioHighWater);
      add(s);
    }
    snprintf(s, sizeof s,
             "  \"template\": {\"cb_struct\": %lu, \"name\": %s, \"preset_id\": %lu, \"render_fourcc\": %s, "
             "\"render_width\": %ld, \"render_height\": %ld, \"render_bit_count\": %u, \"fps\": %.17g, ",
             r.tplCb, str(r.tplName).c_str(), r.tplId, str(r.tplFourcc).c_str(), r.tplWidth, r.tplHeight, r.tplBits,
             r.tplFps);
    add(s);
    snprintf(s, sizeof s,
             "\"audio_format_code\": %lu, \"audio_rate\": %lu, \"audio_channels\": %u, \"audio_block_align\": %u},\n",
             r.tplAudio.format, r.tplAudio.sampleRate, r.tplAudio.channels, r.tplAudio.blockAlign);
    add(s);
    snprintf(s, sizeof s,
             "  \"video\": {\"present\": %s, \"frame_count_reported\": %lld, \"frames_written\": %lld, "
             "\"frame_bytes\": %ld, \"fourcc\": %s, \"width\": %ld, \"height\": %ld, \"bit_count\": %u, ",
             r.videoPresent ? "true" : "false", r.frameCountReported, r.framesWritten, r.frameBytes,
             str(r.fourcc).c_str(), r.width, r.height, r.bitCount);
    add(s);
    snprintf(s, sizeof s, "\"fps\": %.17g, \"pixel_aspect\": %.17g, \"plane_fields\": [%lu, %lu, %lu, %lu, %lu, %lu], ",
             r.fps, r.pixelAspect, r.planeFields[0], r.planeFields[1], r.planeFields[2], r.planeFields[3],
             r.planeFields[4], r.planeFields[5]);
    add(s);
    add("\"first_frame_info_hex\": " + str(r.haveInfo ? HexBytes(r.firstInfo, sizeof r.firstInfo) : "") + ", ");
    snprintf(s, sizeof s,
             "\"frame_info_changes\": %lld, \"frame_size_changes\": %lld, \"token_mode\": %ld, "
             "\"locks_outstanding\": %lld},\n",
             r.infoChanges, r.sizeChanges, r.tokenMode, r.locksOutstanding);
    add(s);
    snprintf(s, sizeof s,
             "  \"audio\": {\"present\": %s, \"format_assumed\": %s, \"format_code\": %lu, \"sample_rate\": %lu, "
             "\"channels\": %u, \"block_align\": %u, \"wav_format\": %s, ",
             r.audioPresent ? "true" : "false", r.audioAssumed ? "true" : "false", fmt.format, fmt.sampleRate,
             fmt.channels, fmt.blockAlign, opt(r.wavFormat).c_str());
    add(s);
    std::string length = r.streamLength >= 0 ? std::to_string(r.streamLength) : "null";
    snprintf(s, sizeof s,
             "\"samples_written\": %lld, \"samples_expected\": %lld, \"reads\": %lld, \"short_reads\": %lld, "
             "\"stream_length_reported\": %s},\n",
             r.samplesWritten, r.samplesExpected, r.reads, r.shortReads, length.c_str());
    add(s);
    snprintf(s, sizeof s, "  \"progress\": {\"total_set\": %lld, \"non_ok\": [", r.progressTotal);
    add(s);
    for (size_t i = 0; i < r.nonOk.size() && i < 64; i++) {
      snprintf(s, sizeof s, "%s{\"slot\": %d, \"frame\": %lld, \"hresult\": \"%s\"}", i ? ", " : "", r.nonOk[i].slot,
               r.nonOk[i].frame, Hr(r.nonOk[i].hr).c_str());
      add(s);
    }
    add("]},\n  \"probes\": [");
    for (size_t i = 0; i < r.probes.size(); i++) {
      snprintf(s, sizeof s, "%s\n    {\"stream\": %s, \"slot\": %d, \"hresult\": \"%s\", \"value\": ", i ? "," : "",
               str(r.probes[i].stream).c_str(), r.probes[i].slot, Hr(r.probes[i].hr).c_str());
      add(s);
      add(str(r.probes[i].value) + "}");
    }
    add(r.probes.empty() ? "],\n" : "\n  ],\n");
    snprintf(s, sizeof s,
             "  \"timing_ms\": {\"get_frame\": %.3f, \"release_frame\": %.3f, \"audio_read\": %.3f, "
             "\"write_video\": %.3f, \"write_audio\": %.3f, \"checksum\": %.3f, \"progress\": %.3f, "
             "\"loop\": %.3f}\n}\n",
             r.msGet, r.msRelease, r.msAudio, r.msWriteVideo, r.msWriteAudio, r.msChecksum, r.msProgress,
             r.msLoop);
    add(s);
    OutFile f;
    if (f.Open(r.manifestPath) && f.Write(j.data(), j.size()))
      BestEffortDiagnostic([&] { Log("manifest written: %s", Utf8(r.manifestPath.c_str()).c_str()); });
    else
      BestEffortDiagnostic([&] { Log("manifest write failed: %lu", f.Error()); });
  }

  LONG ref_ = 1;
  Tpl tpl_;
  std::wstring path_;
  std::vector<ISfReadStream*> streams_;
  ISfReadMeta* meta_ = nullptr;
  std::unique_ptr<FfmpegEncoder> encoder_;
};

}  // namespace

HRESULT CreateRenderFile(const SFTEMPLATE* t, ISfRenderFile** out) {
  if (!out) return E_POINTER;
  *out = nullptr;
  return NativeBoundary([&]() -> HRESULT {
    *out = new RenderFile(Tpl::Copy(t));
    BestEffortDiagnostic([&] { Log("RenderFile %p created", (void*)*out); });
    return S_OK;
  });
}

}  // namespace vegas_encoder
