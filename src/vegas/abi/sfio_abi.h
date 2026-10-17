// sfio_abi.h - VEGAS FileIO exporter ABI as recovered by this project.
//
// Vtable order and parameter shapes come from the host's MIDL proxy/stub
// (FileIOProxyStubx64.dll, F-026) and were confirmed at runtime for the
// methods marked [rt] (F-030/F-031, VEGAS 23 and 2026.0.3). Method names
// follow DebugMode FrameServer's adapter source (GPL-2.0, names only) where
// the shape matches; names marked '?' are hypotheses. Do not rely on any
// method not marked [rt] without validating it.
//
// This header is an evidence-backed seed for a future SDK; it is not the
// original Sony/Magix SDK.
#pragma once

#include <windows.h>
#include <unknwn.h>
#include <ocidl.h>  // IPropertyPage

namespace sfio {

// --- Identifiers -------------------------------------------------------------

// Host asks every FileIO plug-in DLL for this class first (F-033; FrameServer
// CLSID_SfMediaGetUnsharedTypeInfo; present in 29 built-in 2026 plug-ins).
// {F6E48972-515B-4A5E-B316-A46A03C9C3C0}
inline constexpr GUID CLSID_SfMediaGetUnsharedTypeInfo = {
    0xf6e48972, 0x515b, 0x4a5e, {0xb3, 0x16, 0xa4, 0x6a, 0x03, 0xc9, 0xc3, 0xc0}};

// Host allocator queried from the SetHostInterface object (F-033).
// {AD52D82C-5406-41A8-998C-4A38755234ED}
inline constexpr GUID IID_SfHostAllocator = {
    0xad52d82c, 0x5406, 0x41a8, {0x99, 0x8c, 0x4a, 0x38, 0x75, 0x52, 0x34, 0xed}};

// Reader class the host also requests from plug-ins that report access 0x30
// (F-033). Not declared here: render-only exporters refuse it (F-038).
// {E16F92BF-5D01-4325-8475-479F44A316CE}
inline constexpr GUID IID_ISfReadFileClass = {
    0xe16f92bf, 0x5d01, 0x4325, {0x84, 0x75, 0x47, 0x9f, 0x44, 0xa3, 0x16, 0xce}};

// GetFilterInfo values (F-038). Voukoder Pro (render + read classes) reports
// access 0x30, stream types 0x0B, flags 1; Voukoder Classic (render only)
// reports access 0x20, stream types 0x3, flags 1. Bit names are hypotheses
// matched to FrameServer's SFFIO_FILTER_TYPE_RENDER / SFFIO_STREAM_TYPE_*.
inline constexpr DWORD SFFIO_FILTER_ACCESS_RENDER = 0x20;
inline constexpr DWORD SFFIO_FILTER_ACCESS_READ = 0x10;
inline constexpr DWORD SFFIO_STREAM_AUDIO_VIDEO = 0x3;

// Render returns this when progress or frame acquisition fails in Voukoder Pro
// (connector RVA 0x1162E, F-038). FrameServer maps the same case to
// SF_E_CANCEL; whether the names match is a hypothesis.
inline constexpr HRESULT SF_E_RENDER_STOPPED = (HRESULT)0x8004E017L;

// VEGAS 2026 cancel signal: ISfProgress::SetPosition (slot 6) returned this
// after the user pressed Cancel (F-045, two renders). The SDK name is unknown.
inline constexpr HRESULT SF_E_PROGRESS_CANCELLED = (HRESULT)0x8004E00CL;

// --- Memory token (F-018, F-022, F-026, F-031) --------------------------------

// 40 bytes, 8-aligned. Exporter-filled tokens (audio Read) use mode 0 and
// hHandle 0; host-filled tokens (video GetRenderFrame) use mode 1 with a
// per-session handle. In-process, data = pData + offset.
struct SFMEMORYTOKEN {
  ULONGLONG hHandle;  // +0x00  0 (exporter) / constant per session (host)
  ULONGLONG pData;    // +0x08  buffer pointer
  LONG cbData;        // +0x10  byte count
  LONG cbAlloc;       // +0x14  observed equal to cbData
  LONG offset;        // +0x18  observed 0
  LONG reserved;      // +0x1C  observed 0
  LONG mode;          // +0x20  enum32: 0 local, 1 host-mapped (meaning: hypothesis)
  DWORD pid;          // +0x24  owning process id
};
static_assert(sizeof(SFMEMORYTOKEN) == 40, "token is 40 bytes");

// Opaque template (SFTEMPLATEx). First dword = total size in bytes; layout in
// namespace tpl below (F-033, F-036). Allocated with the host allocator.
struct SFTEMPLATE;

// --- Template layout (F-033, F-036) -------------------------------------------

// Byte offsets into a template. All offsets are observed in plug-in, host and
// Create templates; names follow FrameServer where position and size match.
namespace tpl {
inline constexpr size_t cbStruct = 0x000;        // DWORD total size
inline constexpr size_t dwVer = 0x004;           // plug-in 0x02020000, host 0x02000000
inline constexpr size_t id = 0x00C;              // preset id
inline constexpr size_t iidOwner = 0x018;        // GUID; plug-in render class type ID
inline constexpr size_t guidPreset = 0x028;      // GUID
inline constexpr size_t audioCb = 0x038;         // DWORD 200
inline constexpr size_t audioStreams = 0x03C;    // DWORD 1
inline constexpr size_t audioRender = 0x048;     // SFAUDIORECORD (32 bytes), zero = project
inline constexpr size_t audioCodec = 0x090;      // SFAUDIORECORD (32 bytes)
inline constexpr size_t videoCb = 0x100;         // DWORD 200
inline constexpr size_t videoStreams = 0x104;    // DWORD 1
inline constexpr size_t videoRenderBih = 0x108;  // BITMAPINFOHEADER; compression selects delivery
inline constexpr size_t videoRenderVex = 0x130;  // 64-byte video extension
inline constexpr size_t vexFps = 0x140;          // double, 0 = project
inline constexpr size_t vexPixelAspect = 0x148;  // double
inline constexpr size_t videoCodecBih = 0x170;   // BITMAPINFOHEADER
inline constexpr size_t keyFrameEvery = 0x1B0;   // DWORD? (hypothesis)
inline constexpr size_t cchAllocText = 0x210;    // DWORD wchar count of name\0notes\0
inline constexpr size_t cbExtra = 0x214;         // DWORD
inline constexpr size_t abExtra = 0x218;         // plug-in private bytes, then the text
inline constexpr size_t fixedSize = 0x218;
inline constexpr DWORD versionPlugin = 0x02020000;
inline constexpr DWORD sectionCb = 200;
inline constexpr size_t vexSize = 64;
}  // namespace tpl

// 32-byte audio format record at template +0x48 (render) and +0x90 (codec).
// Not a WAVEFORMATEX (F-036). Field semantics come from Voukoder's conform
// stores; +0x10..+0x18 are zero in every observed record.
struct SFAUDIORECORD {
  DWORD cbRecord;        // +0x00  32 (size? hypothesis)
  DWORD format;          // +0x04  0x11 PCM16, 0x20 IEEE float32 (only codes seen)
  DWORD sampleRate;      // +0x08
  WORD channels;         // +0x0C
  WORD blockAlign;       // +0x0E  bytes per sample frame
  DWORD unknown10;       // +0x10
  DWORD unknown14;       // +0x14
  DWORD unknown18;       // +0x18
  DWORD avgBytesPerSec;  // +0x1C
};
static_assert(sizeof(SFAUDIORECORD) == 32, "audio record is 32 bytes");
inline constexpr DWORD SFAUDIO_FORMAT_PCM16 = 0x11;
inline constexpr DWORD SFAUDIO_FORMAT_FLOAT32 = 0x20;

// 176-byte frame info filled by GetRenderFrame (F-030, F-031, F-036).
namespace frameinfo {
inline constexpr size_t size = 176;
inline constexpr size_t frame = 0x00;        // hyper, equals the requested frame
inline constexpr size_t dataSize = 0x18;     // hyper, payload bytes
inline constexpr size_t vex = 0x20;          // same 64-byte block as template +0x130
inline constexpr size_t fps = 0x30;          // double
inline constexpr size_t pixelAspect = 0x38;  // double
inline constexpr size_t bih = 0x60;          // BITMAPINFOHEADER of the delivered data
// Six DWORDs after the header. P010 1920x1080 gave {3840, 4147200, 3840, 0, ...}:
// plane-0 stride, plane-1 offset, plane-1 stride (interpretation: hypothesis).
// BI_RGB 32 1920x1080 gave {7680, 0, ...} with rows bottom-up (F-041).
inline constexpr size_t planeFields = 0x88;
}  // namespace frameinfo

// 184-byte stream format filled by video slots 10/11 and audio slots 11/12.
// Runtime-observed once each (F-041: BI_RGB 1080p video, float32 48 kHz
// stereo audio); unlisted bytes were zero and are unknown.
namespace streamfmt {
inline constexpr size_t size = 184;
inline constexpr size_t cbStruct = 0x00;     // 0xB8
inline constexpr size_t type = 0x04;         // 1 audio, 2 video
inline constexpr size_t length = 0x08;       // hyper; audio: sample count; video: 0
inline constexpr size_t vex = 0x18;          // video: same 64-byte block as template +0x130
inline constexpr size_t fps = 0x28;          // video: double (30000/1001 observed)
inline constexpr size_t pixelAspect = 0x30;  // video: double
inline constexpr size_t media = 0x58;        // video: BITMAPINFOHEADER; audio: SFAUDIORECORD
}  // namespace streamfmt

// --- Host allocator (local interface, not in the stub) ------------------------

struct ISfHostAllocator : IUnknown {
  virtual void* STDMETHODCALLTYPE Alloc(SIZE_T cb) = 0;  // [rt] slot 3
  // Configuration static check: sharedk 2026.0.3.189 RVA 0x315B20 passes p
  // straight to the same UCRT free paired with Alloc's calloc. See
  // docs/NATIVE_CONFIGURATION.md; other host builds remain unqualified.
  virtual void STDMETHODCALLTYPE Free(void* p) = 0;      // slot 4, void return
};

// --- Plug-in discovery ------------------------------------------------------

struct __declspec(uuid("404E18A7-C288-4499-8E42-33FECFA1642C"))
ISfUnsharedFIOPluginInfo : IUnknown {
  virtual HRESULT STDMETHODCALLTYPE Init(LPCWSTR key, LONG appGrade, LONG demo) = 0;
  virtual HRESULT STDMETHODCALLTYPE GetFilterCount(LONG* count) = 0;  // [rt]
  virtual HRESULT STDMETHODCALLTYPE GetFilterInfo(LONG index, GUID* clsid, LPWSTR name,
                                                  LONG cchName, DWORD* access,
                                                  DWORD* streamTypes, DWORD* appLevel,
                                                  DWORD* appLevel2, DWORD* appLevel3,
                                                  DWORD* appLevel4, DWORD* expireDate,
                                                  DWORD* flags) = 0;  // [rt]
};

// --- Streams -----------------------------------------------------------------

struct __declspec(uuid("60FD1C41-7825-11D3-A483-00105A24AA37"))
ISfReadStream : IUnknown {
  // F-041 values are from one VEGAS 2026 render: 182 frames at 30000/1001,
  // 291,491 samples at 48 kHz.
  virtual HRESULT STDMETHODCALLTYPE GetFile(IUnknown** ppFile) = 0;          // 3
  virtual HRESULT STDMETHODCALLTYPE Slot4(LONG* p) = 0;                       // 4 [rt] 0
  virtual HRESULT STDMETHODCALLTYPE Slot5(LONG* p, LONG* a, LONG* b) = 0;     // 5
  // Returned 60727333 for both streams: duration in 100 ns units (6.0727333 s).
  virtual HRESULT STDMETHODCALLTYPE GetStreamLength(LONGLONG* p) = 0;         // 6 [rt]
  virtual HRESULT STDMETHODCALLTYPE Slot7(LONGLONG* p) = 0;                   // 7 [rt] 0
  virtual HRESULT STDMETHODCALLTYPE Slot8() = 0;                              // 8
};

struct __declspec(uuid("6E362EA8-F473-4167-B85F-074EAB3290CE"))
ISfReadAudioStream : ISfReadStream {
  virtual HRESULT STDMETHODCALLTYPE GetSampleCount(LONGLONG* p) = 0;          // 9 [rt] 291491
  virtual HRESULT STDMETHODCALLTYPE Slot10(LONG* p) = 0;                      // 10 [rt] 8 = block align?
  virtual HRESULT STDMETHODCALLTYPE GetFormat11(void* fmt184) = 0;            // 11 [rt] streamfmt
  virtual HRESULT STDMETHODCALLTYPE GetFormat12(void* fmt184) = 0;            // 12 [rt] streamfmt
  virtual HRESULT STDMETHODCALLTYPE SetFormat13(void* fmt184) = 0;            // 13
  virtual HRESULT STDMETHODCALLTYPE Read(LONGLONG pos, const SFMEMORYTOKEN* token, LONG count,
                                         LONG* got) = 0;                      // 14 [rt]
  // F-041: the final read, which ended exactly at the stream length, returned
  // S_FALSE with the full count; all earlier reads returned S_OK.
  virtual HRESULT STDMETHODCALLTYPE Slot15(LONGLONG* a, LONGLONG* b, LONG* c) = 0;  // 15
  virtual HRESULT STDMETHODCALLTYPE Slot16(LONG v) = 0;                       // 16
};

struct __declspec(uuid("68EFE083-5F0C-4415-9334-F6CE84487829"))
ISfReadVideoRenderStream : ISfReadStream {
  virtual HRESULT STDMETHODCALLTYPE GetFrameCount(LONGLONG* frames) = 0;      // 9 [rt]
  virtual HRESULT STDMETHODCALLTYPE GetFormat10(void* fmt184) = 0;            // 10 [rt] streamfmt
  virtual HRESULT STDMETHODCALLTYPE GetReadVideoFormat(void* fmt184) = 0;     // 11 [rt] streamfmt
  // 2026 adds the second argument (F-027); VEGAS 23 has only the first.
  virtual HRESULT STDMETHODCALLTYPE SetRenderFrameFormat(void* fmt184, const void* ext128) = 0;  // 12 ?
  virtual HRESULT STDMETHODCALLTYPE Slot13(void* fmt184, LONG v) = 0;         // 13
  virtual HRESULT STDMETHODCALLTYPE GetRenderFrame(LONGLONG frame, SFMEMORYTOKEN* token,
                                                   LONG_PTR* lock, void* frameInfo176,
                                                   LONG* cb) = 0;             // 14 [rt]
  virtual HRESULT STDMETHODCALLTYPE ReleaseRenderFrame(LONG_PTR lock) = 0;    // 15 [rt]
  virtual HRESULT STDMETHODCALLTYPE Slot16(LONGLONG frame, const void* fmt184,
                                           const SFMEMORYTOKEN* token, void* frameInfo176,
                                           LONG* cb) = 0;                     // 16
};

struct __declspec(uuid("D6EBCEC1-766C-11D3-9627-00C04F68BE42"))
ISfProgress : IUnknown {
  // F-026/F-027 shapes. B5 exact CSfRenderProgress (2026.0.3.189): slot 3
  // borrows text, sets total and zeroes position; slot 4 only borrows text.
  // Neither copies/frees text or draws UI. Visible consumption is unverified.
  // Keep numeric names: these are recovered effects, not original SDK names.
  // Details/lifetime and opt-in procedure: docs/NATIVE_PROGRESS.md.
  virtual HRESULT STDMETHODCALLTYPE Slot3(LPCWSTR text, LONGLONG total) = 0;  // 3 [static]
  virtual HRESULT STDMETHODCALLTYPE Slot4(LPCWSTR text) = 0;                  // 4 [static]
  virtual HRESULT STDMETHODCALLTYPE SetTotal(LONGLONG total) = 0;             // 5 [rt]
  virtual HRESULT STDMETHODCALLTYPE SetPosition(LONGLONG pos) = 0;            // 6 [rt]
  virtual HRESULT STDMETHODCALLTYPE CheckCancel() = 0;                        // 7 [rt] ?
  virtual HRESULT STDMETHODCALLTYPE Slot8(LONG v) = 0;                        // 8
};

struct __declspec(uuid("001420E1-938C-11D3-A483-00105A24AA37")) ISfReadMeta : IUnknown {};

// --- Render file / class ----------------------------------------------------

struct __declspec(uuid("02589F93-A1D1-4550-9CBF-861026600F21"))
ISfRenderFile : IUnknown {
  virtual HRESULT STDMETHODCALLTYPE CloseFile() = 0;                          // 3 [rt]
  virtual HRESULT STDMETHODCALLTYPE IsFileOpen() = 0;                         // 4
  virtual HRESULT STDMETHODCALLTYPE OpenFile(LONG createFlags, LONG shareFlags) = 0;  // 5
  virtual HRESULT STDMETHODCALLTYPE SetFile(LPCWSTR path) = 0;                // 6 [rt]
  virtual HRESULT STDMETHODCALLTYPE GetFileName(LPWSTR path, LONG cch) = 0;   // 7 [rt]
  virtual HRESULT STDMETHODCALLTYPE GetStreamCount(LONG* count) = 0;          // 8
  virtual HRESULT STDMETHODCALLTYPE GetStreamFormatInfo(void* aFmt184, LONG a, LONG b) = 0;  // 9
  virtual HRESULT STDMETHODCALLTYPE SetStreamFormatInfo(const void* aFmt184, LONG c) = 0;    // 10
  virtual HRESULT STDMETHODCALLTYPE SetStreamReader(ISfReadStream* s, LONG index) = 0;       // 11 [rt]
  virtual HRESULT STDMETHODCALLTYPE SetMetaReader(ISfReadMeta* meta) = 0;     // 12 [rt]
  virtual HRESULT STDMETHODCALLTYPE GetTemplate(SFTEMPLATE** tpl, LONG reserved) = 0;  // 13
  virtual HRESULT STDMETHODCALLTYPE EstimateFileSize(LONGLONG* cb) = 0;       // 14
  virtual HRESULT STDMETHODCALLTYPE Render(ISfProgress* progress) = 0;        // 15 [rt]
  virtual HRESULT STDMETHODCALLTYPE UpdateMetaData(LONG sampleRate, LONG encode) = 0;  // 16
};

struct __declspec(uuid("2F0205B1-7103-4E87-9F03-17A481FB8F28"))
ISfRenderFileClass : IUnknown {
  virtual HRESULT STDMETHODCALLTYPE SetHostInterface(IUnknown* host) = 0;     // 3 [rt]
  // Slots 4-7 (F-038): Voukoder Pro's render slot 4 equals its read class's
  // slot 7 and vice versa, so 4 = own type ID, 7 = counterpart class (FrameServer:
  // GetReadClassGuid returns GUID_NULL). Slot 5 equals GetFilterInfo's stream
  // types. Slot 6 = caps by elimination. Names: FrameServer, positions: evidence.
  virtual HRESULT STDMETHODCALLTYPE GetTypeID(GUID* g) = 0;                   // 4 [rt]
  virtual HRESULT STDMETHODCALLTYPE GetAllowedStreamTypes(DWORD* v) = 0;      // 5 [rt]
  virtual HRESULT STDMETHODCALLTYPE GetCaps(DWORD* v) = 0;                    // 6 [rt] ?
  virtual HRESULT STDMETHODCALLTYPE GetReadClassGuid(GUID* g) = 0;            // 7 [rt]
  virtual HRESULT STDMETHODCALLTYPE GetStrings(const LONG* ids, LONG count,
                                               BSTR* strings) = 0;            // 8 [rt]
  virtual HRESULT STDMETHODCALLTYPE Open(ISfRenderFile** file, LONG h, LPCWSTR path) = 0;  // 9
  virtual HRESULT STDMETHODCALLTYPE Create(ISfRenderFile** file, LPCWSTR path, LONG cStreams,
                                           ISfReadStream** streams,
                                           const SFTEMPLATE* tpl) = 0;        // 10 [rt]
  virtual HRESULT STDMETHODCALLTYPE GetPresetCount(LONG* count) = 0;          // 11 [rt]
  virtual HRESULT STDMETHODCALLTYPE GetPreset(SFTEMPLATE** tpl, LONG index) = 0;  // 12 [rt]
  virtual HRESULT STDMETHODCALLTYPE GetPresetIndexFromGuid(const GUID* g, LONG* index) = 0;  // 13
  virtual HRESULT STDMETHODCALLTYPE ChooseBestPreset(const SFTEMPLATE* tpl, LONG rules,
                                                     LONG* index) = 0;        // 14
  virtual HRESULT STDMETHODCALLTYPE ConformTemplate(SFTEMPLATE** out, const SFTEMPLATE* src,
                                                    LONG reason) = 0;         // 15 [rt]
  virtual HRESULT STDMETHODCALLTYPE ConformTemplateToSource(SFTEMPLATE** io,
                                                            const SFTEMPLATE* base,
                                                            const SFTEMPLATE* source,
                                                            LONG reason) = 0;  // 16 [rt]
  // Selector 11: UTF-16 wildcard, capacity in WCHARs. Static-observed in the
  // 2026.0.3.189 host and mp4plug3 writer; see NATIVE_CONTAINER_PLAN.md.
  virtual HRESULT STDMETHODCALLTYPE GetTemplateInfo(const SFTEMPLATE* tpl, BYTE* info, LONG cch,
                                                    LONG type) = 0;           // 17 [rt]
  virtual HRESULT STDMETHODCALLTYPE GetPropertyPageCount(LONG* a, LONG* b, LONG* c) = 0;  // 18 [rt]
  virtual HRESULT STDMETHODCALLTYPE GetPropertyPage(LONG index, IPropertyPage** page) = 0;  // 19 [rt]
  virtual HRESULT STDMETHODCALLTYPE BuyPropertyPages(HWND parent) = 0;        // 20
  virtual HRESULT STDMETHODCALLTYPE HasAboutBox() = 0;                        // 21 [rt]
  virtual HRESULT STDMETHODCALLTYPE ShowAboutBox(HWND parent) = 0;            // 22
  virtual HRESULT STDMETHODCALLTYPE GetStatus(LONG* hr, BSTR* text) = 0;      // 23 [rt]
};

}  // namespace sfio
