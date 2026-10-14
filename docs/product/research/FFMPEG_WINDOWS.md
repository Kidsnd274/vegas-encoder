# Windows FFmpeg facts — B1

Measured 2026-10-13 (Asia/Singapore), Windows 11 Pro 10.0.26300 x64. These are synthetic offline
FFmpeg/core checks, not VEGAS qualification. No installer, PATH change or installed
exporter replacement occurred. Downloaded tools/media/logs stay in the platform
worktree's ignored `build/ffmpeg-b1/`; binaries are not shipped by the product.

## Tested builds and sources

| Case | Exact `ffmpeg -version` identity | Linking | libavformat |
| --- | --- | --- | --- |
| Existing `C:\ffmpeg\bin` | `5.1.2-full_build-www.gyan.dev` | shared | 59.27.100 |
| Current gyan full | `2026-10-12-git-615b07170e-full_build-www.gyan.dev` | static | 63.9.100 |
| Current BtbN GPL shared | `N-127507-g24e860f6d3-20261013` | shared | 63.10.100 |

Current download sources:

- [gyan full git archive](https://www.gyan.dev/ffmpeg/builds/ffmpeg-git-full.7z),
  advertised by [gyan's builds page](https://www.gyan.dev/ffmpeg/builds/).
- [BtbN win64 GPL shared archive](https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl-shared.zip),
  identified through [BtbN's latest-release API](https://api.github.com/repos/BtbN/FFmpeg-Builds/releases/latest).

Both floating archive URLs were checked against their publishers' SHA-256 values
before extraction. The exact runtime versions above identify the tested builds;
re-downloading a floating URL later may produce different bytes. The old build
was already installed; its original acquisition was not repeated or authenticated
by B1. Its catalog source URL is a vendor reference; the original archive URL/
identity are unknown.
FFprobe beside each executable reports the matching FFmpeg version. Current GPL
builds omit FDK AAC; B1 makes no FDK runtime/sample-format claim.
The older installation's shared linking is confirmed by its `--enable-shared`
configuration and PE imports of the sibling avcodec/avformat/avutil/filter/device,
swscale/swresample and postproc DLLs; its banner alone does not identify linking.

## What is committed

- `schema/ffmpeg/windows-builds.v1.json`: exact versions/configurations/library
  versions, encoder/muxer lists, parsed help for 28 named encoders and five muxers,
  isolated generic codec AVOptions, sample formats, timings and measured matrices.
- `schema/encoder-options.windows.v1.json`: current gyan private options as the
  embedded unprobed baseline. Supplied installation capabilities remain authoritative.
- `schema/encoder-profiles.v1.json`: curated controls qualified against Windows
  help/formats; sampled libavformat 59/63 compatibility rules and conservative
  consensus for unknown versions. Product defaults/ranges/marks/estimates remain
  product policy, separately labelled from reported encoder defaults.
- Five bounded help fixtures exercise duplicate declarations, aliases, symbolic
  bounds, old/new enums and unknown-name exit-zero behavior.
- `schema/fixtures/b1/core-argv.json` and the generated Dart test constant: the six
  original recipes plus the existing popup context through the real compiler. B0 FakeVeCore fixtures remain
  historical design samples; there is no edited-state fake sweep.

Help counts: older/current gyan/BtbN list **214/243/235 total encoders**,
**176/188/188 muxers**, and **396/568/568 private options** across the 28 names.
One missing name still exits zero: header recognition, not exit code alone, decides
whether its help is usable. Current help drops some old aliases and adds enum
values; old 5.1.2 has no `av1_nvenc`. Generic codec options are captured separately
because per-encoder help lists private options only.

## Probe costs

One serial pass and one four-worker pass over the same 28 help names, on this busy
development machine. These are samples, not cold-start guarantees or matched
performance experiments; file caching and process contention can differ.

| Build | Median serial per-encoder help | Serial 28-name pass | Four-worker pass |
| --- | --- | --- | --- |
| gyan 5.1.2 | 71.8 ms | 2.06 s | 0.47 s |
| current gyan static | 508.5 ms | 14.48 s | 1.03 s |
| current BtbN shared | 80.8 ms | 2.30 s | 0.57 s |

B3 must stream probe results in the background, bound concurrency and hard-kill
stalled processes. These measurements do not establish app first-frame budgets.

Native option validation shares lint's rule helpers and borrows immutable
capabilities instead of copying the entire catalog per emitted option. A 50-call
warm full-map sample (152,474 capability JSON characters) measured about **8.9 ms
through Dart FFI**, including transport/parsing, after removing the repeated
native-copy regression (about 57 ms in a Python C-ABI sample beforehand). This is
not a matched benchmark. It remains above the architecture's 4 ms edit budget;
B3/F7 need a smaller or cached core capability transfer and app frame measurements.
Unprobed small-request timing does not establish the full-capability budget.

## Container measurements

Each build ran **85 cases**: seven video families × five containers, and ten
available audio encoders × five containers with a companion video. Source is
P010 320×180 at 25 fps (three frames) plus 48 kHz float32 stereo (0.12 s).
Software encodes produce reference MKV streams, then each case stream-copies into
the target, checks FFprobe stream types/codecs and completely decodes. MXF remuxes
explicitly retain 25 fps; failure to do that exposes MKV's time base rather than
the intended frame rate. Success counts are **47/54/54** (old/current gyan/BtbN).
Refusals require an explicit codec/mux/profile diagnostic; environmental and
unknown failures remain unqualified and are rejected by promotion. Runners check
the executable and companion FFprobe against the captured version/configuration/
library identity before output creation. Refusals are recorded separately; no timeout/data-stream-only output was promoted
as a compatibility fact.

The two current builds agree on these settings. Key changes from the Linux
bootstrap and older Windows build:

- 5.1.2 refuses **FFV1 and PCM in MP4** and FFV1 in MXF. Current builds mux/read/
  decode them; MP4 FFV1/PCM retain a player-interoperability warning.
- 5.1.2 FLAC/MP4 requires experimental permission. It remains a warning requiring
  an explicit test, not a claim that the default Basic command works there.
- H.264/MXF is profile-dependent; the old build rejects the sampled High stream,
  while current builds accept it. The family rule stays a warning.
- Among tested codecs, all three refuse ProRes/DNxHR in MP4; AV1/VP9/Opus/FLAC
  in MOV; other than VP9/AV1 + Opus in WebM; and HEVC/AV1/VP9 or non-PCM audio in MXF.
- ProRes/DNxHR with 16/24-bit PCM work in MXF. Float PCM does not.
- `hvc1` is read back after requesting the HEVC tag, and faststart puts `moov`
  before `mdat`. No Apple/player/NLE playback test ran.

Tables cover the recorded codec/profile/rate settings. A family-level warning is
deliberately weaker than a blanket support claim. Unknown library majors use
cross-build consensus; versions not sampled within a major can still differ.

## Formats and compiled flags

**184 real-core plans**: 58 older + 63 per current build. Every advertised rate
mode, alternate curated depth and ProRes/DNxHR profile is compiled against that
build's capabilities, executed with a hard timeout, read back and decoded.
**163 pass** (51/56/56); the remaining 21 are the same seven Intel/AMD runtime
initialization failures per build. NVIDIA passes are local 320×180 observations,
including 10-bit HEVC/AV1 where present, on an NVIDIA GeForce RTX 5070 Ti with
Windows-reported driver 32.0.16.1692; neither help nor these small tests qualify
other PCs, drivers, sizes or real VEGAS renders. B3 still needs per-PC hardware tests.

Verified encoder input negotiation from P010: x264/x265/SVT/VP9 use planar 10-bit;
ProRes HQ uses 10-bit 4:2:2; DNxHR HQ fails without explicit 8-bit 4:2:2. FFV1 auto
selection differs: old 5.1.2 chooses `yuv420p16le`, current builds choose
`yuv420p10le`. The compiler always requests its profile's explicit pixel format.

Float32 stereo encoder-side formats agree across the tested builds: AAC/AC-3/
E-AC-3/MP3 `fltp`; Opus/PCM float `flt`; FLAC and PCM 24-bit `s32`; ALAC `s32p`;
PCM 16-bit `s16`. FLAC/ALAC use 24 useful bits with this source. These are raw
encoder-input facts, not a promise that compressed readback reports the same
format/precision (e.g. ProRes 4444 readback can be 12-bit).

Corrections made by B1:

- Unset x264 profile follows depth (`high` / `high10`); explicit 8-bit-only
  profiles with 10-bit output are errors. Extra pixel/profile overrides are checked.
- AMF supports the common old/new modes ABR (`vbr_peak`), CBR (`cbr`) and CQP
  (`cqp` with I/P/B quantizers). The old `qp_i`-only CQ mode was not a valid
  portable constant-quality mapping and is removed from Basic; saved values are
  preserved but flagged, and Advanced can use newer build-specific QVBR options.
  Local AMF runtime is missing, so B1 qualifies its argument syntax, not output.
- Profile/depth checks use effective Extra replacements. FFmpeg `+pixel_format`
  is preserved in argv and normalized for validation/facts; lone `+` remains
  unknown. The valid exact-format command is also replayed through real 5.1.2.
- Generated private values and pixel formats are checked against supplied help.
  Sample-rate choices follow reported rates when available.
- Basic color tags are applied to raw input and output, including Extra tag
  replacements. Current FFmpeg changed pixels when only output BT.709 tags were
  supplied; matching input metadata restores bit-exact P010-to-planar conversion.
  The Advanced seed explicitly carries those input tags before `{inputs}`;
  arbitrary Advanced text does not inherit inactive Basic controls. This labels
  samples according to the chosen policy, not measured VEGAS source color metadata.
- Explicit input `-thread_queue_size` is omitted: both current builds list it as
  output-only and reject the old input placement. The resulting commands pass all
  three builds. B4 must measure named-pipe/backpressure behavior; offline files do
  not establish the changed command's pipe memory/timing limits.
- Extra option/value tokens expose `replacedField` as well as the result-level
  `overriddenFields`. No FFmpeg option-name interpretation belongs in the app.

## Reproduction and limits

Run `scripts/Capture-FFmpegFacts.py <exe> <source-url> <fresh-build-folder>`, then
`scripts/Test-FFmpegMatrix.py <exe> <capture-folder>` per build.
`Generate-WindowsFFmpegData.py` takes older gyan, current gyan and current BtbN
folders in that order; `Generate-CoreData.py` embeds the promoted data.
After `build-core.cmd`, `Test-CoreFFmpegProfiles.py` exercises native-generated
plans; `Generate-CoreGoldens.py --check` checks the six recipes and popup argv goldens.
`Test-B1Data.py` checks parser/catalog/identity/refusal regressions; `Test-B2.ps1` runs core/FFI
checks, with optional ASan/AOT/60-frame encode checks. Tools are supplied by the
caller; these scripts never download/install them or change PATH.

Current primary documentation was fetched through Context7's FFmpeg documentation
index. [FFmpeg's option documentation](https://ffmpeg.org/ffmpeg-all.html) explains
generic/private AVOptions and QSV rate control, but its indexed queue-option prose
still describes input/output scope; the tested current executables' help and
execution errors establish the newer scope difference recorded above.

A5–A7, real two-template/restart persistence and controlled real failure recovery
remain unverified. The installed exporter/engine is unchanged. B3 services are
delivered below; the app owns provider wiring and UI mapping. B4 engine work follows.

## B3 service qualification

The Windows services use the same three supplied builds on Windows 11 Pro 26300,
RTX 5070 Ti, DXGI driver 32.0.16.1692. `Test-B3Runtime.ps1` performs full real
probes and eight synthetic native-compiled preset tests per build: six built-ins,
video-only FFV1 and seeded Advanced FFV1. All **24** encode/readback/full-decode
cases pass (**138** assertions). No fake host or real VEGAS is used. Tests run at
320x180/30 fps; this is not another resolution, HDR or throughput qualification.

The service parser uses committed raw help/version/list fixtures and retains B1
option literal/alias behavior. Canonical muxer counts are **176 / 189 / 188**;
lookup entries including aliases are **178 / 190 / 189**. The current gyan count
includes the `caca` device with joined `Ed` flags, missed by the historical B1
capture parser's spaced-column assumption. Historical captures remain unchanged.

Hardware qualification uses one 320x192 frame, strict pixel format and a separate
10-bit input test when advertised. Media Foundation is forced with
`-hw_encoding 1`; its documented default can select software, so unforced successes
are not reused. Vulkan/D3D12 surface encoders receive explicit device initialization
and hwupload. Production parser/cache version **2** invalidates earlier smoke
commands. Eight-bit success survives a failed ten-bit test; all errors retain a
bounded diagnostic rather than becoming general hardware incompatibility rules.
GPU/driver/binary identity and a 30-day TTL scope reuse. Local NVIDIA, MF and several
Vulkan/D3D12 smoke paths pass; Intel/AMD and other failures are command/device-specific.
These are not all-device, HDR, performance or VEGAS claims.

The standalone B3 service suite also checks parser goldens, fake process failures,
concurrent cache updates, cancellation and changed-binary checks. Its real Windows
subtests check shell-free literal argv, timeout/output bounds, four-child pool
release and stable DXGI enumeration. The helper returns three DXGI entries here;
that is not a claim of three physical GPUs. Explorer reveal remains implemented
but unexercised against the desktop (FakeFileReveal covers its app contract).

Use `Test-B3Services.ps1` and `Test-B3Repositories.ps1` sequentially, then
`Test-B3Runtime.ps1 -FFmpegPaths @(...)` with explicit executable paths. All writes
stay in isolated ignored build/test-results roots, and output/log artifacts are
retained for inspection. No user settings, supplied FFmpeg or installed exporter
is changed. Complete app frame/scroll/search budgets and B4 named-pipe/progress/job
qualification remain separate work.

Final cached Basic views omit unused hardware diagnostic text while retaining
native availability state/reason and active option facts. **61** parity/reuse
checks cover built-ins, Extra arguments and disabled audio on all three caches.
Warm end-to-end compile means (50 calls/build) are **2.52 / 2.91 / 2.91 ms** for
27,343 / 32,586 / 31,674-byte Basic maps, versus **10.47 / 13.24 / 12.81 ms** for
156,163 / 236,118 / 234,172-byte full maps. These are the FFI portion on this busy
machine, not a complete app edit/frame budget pass. Full probe times in the final
run are **9.3 / 54.5 / 21.0 s**, including listed hardware smoke tests and identity
hashing; streamed progress does not promise a two-second cold full probe.
The retained runtime summary is under ignored
`build/test-results/b3-runtime-cc92c463/summary.json`; final projection timings are
in `view-timings.json`. `Test-B3Runtime.ps1 -CachedViewRoot <that-root>` repeats
parity/timing without invoking FFmpeg. User files/installed binaries are untouched.
