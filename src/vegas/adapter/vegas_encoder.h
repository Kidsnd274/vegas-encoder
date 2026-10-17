// vegas_encoder.h - diagnostic exporter and fixed-profile FFmpeg proof (phases 2/3).
//
// Implements only the calls VEGAS 2026.0.3 made to a working exporter in the
// F-031/F-036 captures, using declarations from src/vegas/abi/sfio_abi.h. Render
// either writes raw diagnostic files or streams P010/float stereo to external
// FFmpeg. The tested phase-2 host interface remains centralized in sfio_abi.h.
#pragma once
#include "../../version.generated.h"

#include "../abi/sfio_abi.h"
#include "../host/template.h"
#include "../host/frame_lease.h"
#include "../../support/diagnostics.h"
#include "../../support/native_boundary.h"

#include <cstdint>
#include <string>
#include <vector>

#if !defined(_M_X64)
#error Vegas Encoder's measured native adapter requires the MSVC x64 target.
#endif
static_assert(sizeof(void*) == 8 && sizeof(LONG_PTR) == 8, "VEGAS x64 pointer width required");

namespace vegas_encoder {

#if defined(VEGAS_ENCODER_B6_RECIPE_PROOF)
inline constexpr const char* kVersion = VE_EXPORTER_VERSION;
#elif defined(VEGAS_ENCODER_PROGRESS_TEXT_PROOF)
inline constexpr const char* kVersion = VE_LEGACY_PROGRESS_TEXT_VERSION;
#elif defined(VEGAS_ENCODER_CONFIGURATION_PROOF)
inline constexpr const char* kVersion = VE_LEGACY_CONFIGURATION_VERSION;
#else
inline constexpr const char* kVersion = VE_LEGACY_DEFAULT_VERSION;
#endif

// Own identities (never reuse another plug-in's IDs).
// Filter CLSID reported by GetFilterInfo and served by DllGetClassObject.
inline constexpr GUID CLSID_VegasEncoderFilter = {0xc509cfd5, 0xe4ee, 0x446c, {0x88, 0x8b, 0x81, 0x4b, 0xa0, 0xbd, 0x7b, 0x8d}};
// Render class type ID; also the owner GUID in every template we build.
inline constexpr GUID GUID_VegasEncoderType = {0xebad5c8d, 0x4b9e, 0x4f3f, {0x8e, 0x44, 0x22, 0xfc, 0x50, 0x2c, 0xd5, 0xdd}};

// Settings from vegas-encoder.ini next to the DLL (section [vegas-encoder]).
struct Config {
  std::wstring iniPath;
  std::wstring logDir;
  DWORD access = sfio::SFFIO_FILTER_ACCESS_RENDER;  // GetFilterInfo
  DWORD streamTypes = 0x0B;                         // GetFilterInfo + class slot 5
  DWORD caps = 0x100006;                            // class slot 6
  DWORD pluginFlags = 0x1;                          // GetFilterInfo flags
  bool writeVideo = true;
  bool writeAudio = true;
  bool probeGetters = true;  // call out-only stream getters once per render
  int detailCalls = 12;      // full template dumps per method
  bool encode = true;
  bool validMode = true;
  bool showEncoderErrors = true;
  std::wstring ffmpegPath = L"C:\\ffmpeg\\bin\\ffmpeg.exe";
  DWORD pipeTimeoutMs = 10000, finishTimeoutMs = 120000;
#if defined(VEGAS_ENCODER_B6_RECIPE_PROOF)
  std::wstring appPath;
#endif
#if defined(VEGAS_ENCODER_PROGRESS_TEXT_PROOF)
  int progressTextProbe = 0; // 0 off, 4 text only, 3 one-time initialization.
#endif
};
const Config& Cfg();

extern HMODULE g_module;

using host::Tpl;
using host::Float32Record;
using host::FrameLease;
using host::ComRelease;

void LogTemplate(const char* label, const sfio::SFTEMPLATE* t, bool dump) noexcept;

// Render file object created by ISfRenderFileClass::Create.
HRESULT CreateRenderFile(const sfio::SFTEMPLATE* tpl, sfio::ISfRenderFile** out);

}  // namespace vegas_encoder
