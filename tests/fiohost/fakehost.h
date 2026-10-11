// fakehost.h - stand-in VEGAS render host for offline exporter tests.
#pragma once

#include "../../src/vegas/abi/sfio_abi.h"

#include <string>

struct RenderTestOptions {
  std::wstring hostTemplate;  // 540-byte host project template (.tpl)
  std::wstring outDir;
  LONG preset = 1;  // ffbridge 0.1.1: 1 = P010, 2 = BI_RGB (0 is the hidden id-0 probe)
  LONG width = 0, height = 0;  // 0 = keep the host template's size
  double fps = 0;              // 0 = keep the host template's fps
  double deliveredFps = 0;     // 0 = template fps; mismatch regression (F-041)
  LONGLONG frames = 90;
  LONGLONG cancelAt = -1;  // progress slot 6 returns the actual F-045 cancel code
  int progressFailureSlot = 0;  // 6/7 inject E_ACCESSDENIED, not user cancellation
  LONGLONG progressFailureAt = 45;
  int progressFailureCall = 1;  // which progress poll at that frame fails (e.g. Submit's poll)
  bool progressFailureAfterAudioRead = false;  // gate on the read counter, independent of queue repolls
  bool recover = false;  // stop only the first render; later renders must succeed in the same loaded DLL
  int renders = 1;
  std::wstring extension = L"ffdiag";
  bool videoOnly = false, expectFailure = false;
  LONG shortRead = 0;
  LONG configurationProof = -1;  // -1 off; 0/1 edits the opt-in native page and reloads its saved bytes
};

// Replays the template calls VEGAS 2026 made before Create (F-036), then
// Create/SetStreamReader/SetMetaReader/SetFile/Render/GetFileName/CloseFile
// with fake streams that deliver the baseline fixture. Returns 0 on success.
int RunRenderTest(sfio::ISfRenderFileClass* rc, sfio::ISfHostAllocator* alloc, const RenderTestOptions& o);
