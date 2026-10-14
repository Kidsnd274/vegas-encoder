# Platform workstream

Updated: 2026-10-14 (Asia/Singapore). Worktree `L:\repos\vegas-encoder-platform`,
branch `ws/platform`. **B3 and B4 implemented and validated; owner-authorized commit/merge.** B1 complete. Continued
from `659fe02`; F3 master `0be99dc` was fast-forwarded before the B1 commit.
B2 is already merged (`bbcbe91`).
The app owns its NativeVeCore/provider switches and UI mapping. WindowsServices
now composes the real C3 providers without implicit scans/probes/writes.

## B4 delivered

- `src/engine/recipe_job.*` links into the development DLL and compiles immutable
  recipe/media/C3-installation/capability snapshots through the C++ core. The
  engine allocates unique input pipes/temporary output; core inputStreams select
  audio input and expectedStreams drive output checks. No Dart command logic.
- Bounded fragmented FFmpeg progress parsing, C5 states/metrics, and asynchronous
  atomic live/record writes with the same byte/index lock as B3. Latest metrics
  coalesce at <=2 Hz; phases/terminal changes are immediate. Render does not join
  publication, launch a monitor or wait for readers. A worker retains the native
  module until its final write; denied publication is logged and nonfatal.
- Exact selected FFmpeg/shared-library/FFprobe hashes are checked without fallback.
  Hash reads and slow Windows process launches poll on the caller thread. Host
  interfaces never enter workers. Copied frames are released before all waits.
- Encoder exit and output verification precede publication. FFprobe readback is
  bounded to 1 MiB/120 s by default, checks kinds/count/known codecs/readable video,
  and records unknown Advanced scope explicitly. Failed checks retain an explicit
  unique partial; cancelled probes remove it. Destination races preserve old bytes.
  C6 records include canonical recipe hash, actual argv/core command/summary,
  timings, verification, HRESULT, full-log basename and native argv error indexes.
  An interrupted index tail is discarded under the index lock before appending.
- **33,269 checks / 30 cases** pass using the measured fake host, 12 recipe cases
  across gyan 5.1.2, gyan git `615b07170e` and BtbN git `24e860f6d3`, plus controlled
  child/probe fakes. Covers Basic FFV1/PCM, H.264/AAC, video-only, Advanced,
  cancellation/failure recovery/publication, slow/blocked pipes, probe mismatch/
  malformed/oversize/timeout/cancel, short final audio reads, fractional 1080p,
  and file readers/index locks. Optimized maximum poll gap **110 ms**, parent
  working-set growth **35.9 MiB**, video queue **29.7 MiB**, audio queue **154.6 KiB**,
  blocked-pipe cancellation **375 ms**. These are synthetic limits, not render
  throughput or real-host monitor measurements.
- ASan instruments engine, core and fake host: **23,053 checks / 22 cases** pass
  on gyan 5.1.2. Its /Od timings are not release performance results. B3 readers
  pass **350 checks / 29 native jobs**; one deliberately unwritable root has no
  persisted job, logs the failure, and still renders successfully. Core normal/
  ASan each pass **2,965**, real native-asset FFI **196**, and both packages analyze
  cleanly. Default DLL/fiohost/helper builds pass `/W4 /WX`; helper/boundary/page
  tests pass **24 / 9 / 67**. Existing exporter fake-host regression also passes.

Reproduce with `scripts/Test-B4.ps1 -Asan -FFmpegPaths <supplied paths>`. Final
optimized/ASan summaries are under ignored `build/test-results/b4-final-all/`
and `b4-final-asan/`. No app-owned paths, installed exporter, user settings, PATH or
SDK were changed. Existing B3 implementation remains in the working tree.

App/B6 handoff: F7's existing FileLiveRenderStatusReader/FileJobRepository/JobLogs
consume C5/C6 unchanged. inputStreams is an additive native fact (historical fakes
return null). Runtime compile context uses liveInputs/overwriteOutput; existing
previews retain their defaults. B6 must supply the saved recipe/origin, immutable
C7 selection/verify preference, C3 capabilities, actual media/frame count and main
HWND; no library lookup is needed. Native template exchange, monitor launch and
status-line calls remain B5/B6, gated by A5–A7. Real two-template/restart persistence,
controlled real failure recovery and monitor performance remain **unverified**.
Output readback is not a general media-quality/full-decode guarantee; broad source
formats, arbitrary Advanced scopes and audio-only host delivery are not qualified.

## B3 delivered

- Real preset/settings/capability-cache/job/live-status/edit-session services in
  packages/ve_services, with bounded UTF-8 JSON, atomic replace, cross-process
  Windows byte locks and revision checks. Watchers replay per listener, pause and
  wait for their current read on cancellation. No app-owned paths changed.
- Built-in favorite/pinned overlays; 20 old preset revisions; duplicate origins
  `builtin/<id>` / `preset/<id>@<revision>`; History origin `job/<id>`; export to a
  selected path; versioned share strings; location/reveal APIs and fakes.
- Core normalize supplies optional requiredEncoders (Basic enabled streams;
  Advanced unknown). Services do not parse commands or use inactive Basic fields
  to infer Advanced requirements. No FFmpeg minimum version is invented.
- Job index summaries, command/realtime/log/error-index fields, streamed full logs
  and explicit index reconstruction. B4 now supplies native records/error writers.
- Windows discovery across INI/PATH/package roots, canonical/shim resolution,
  x64 executable/FFprobe checks and binary/shared-library identities. Health reads
  do not execute FFmpeg. Discovery/probe/hardware own C7 installation updates,
  preserve preferences/defaults and guard against stale identities/removals.
- Version-2 parser, four-child hidden shell-free pool, streamed curated probe and
  lazy encoder details; atomically merged cache. DXGI GPU/driver fingerprint and
  30-day hardware TTL; forced MF hardware and Vulkan/D3D12 upload smoke paths.
  Eight-bit success remains usable when a separate ten-bit input test fails.
- Test-this-preset stream: 60 synthetic P010 frames/stereo sine, core-compiled argv
  and optional expectedStreams facts, FFprobe stream checks/full decode, bounded
  persisted logs, cancellation and input cleanup. No History publication.
- **110** passing AOT checks on real Windows files and OS locks with the native
  core and synthetic records, including process races, crash-owned lock release,
  cancellation, malformed/future data, failed-write preservation and recovery.
  **2,955** native checks, including ASan; **194** native-asset FFI; retained
  **173 core / 58 service** fake checks. **4,456** service checks cover captured
  parser text/fake FFmpeg, real Windows child lifecycle and DXGI. All **24** real
  preset encodes/readbacks/full decodes across three supplied builds pass (**138**
  checks), including video-only/seeded Advanced. Both packages analyze cleanly.
- Real FFmpeg on Windows 11 Pro 26300, RTX 5070 Ti / driver 32.0.16.1692; no new
  fake-host or real VEGAS run. Hardware smoke is 320x192; presets are 320x180/30 fps.
  Default-command success/failure is not HDR, other resolutions or all-device
  qualification. A5–A7 stay gated.
  Installed exporter, user data, PATH/SDK and rollback backups are untouched.

App handoff: use PresetPreferences for built-in stars/pins, PresetLocations plus
FileReveal for reveal actions, PresetTransfer for export/share/copy/History, and
JobLogs for full logs. Index summaries are optional for older records. Inject one
WindowsServices composition root for real providers, keeping explicit fakes in UI
tests. **Remove app discovery-to-machine copies and manual capability writes**;
services own installation records. Default/theme/UI preference writes still
re-read/reapply on revision conflicts. Use PresetTests and its fake for Test this
preset, and toCoreCapabilities(recipe: recipe) for reusable Basic views. Details
and roots are in [CONTRACTS.md](../CONTRACTS.md). Explorer reveal is implemented
but not exercised against the desktop; tests use FakeFileReveal.

**61** native compact/full parity/reuse checks also pass on the three real caches,
including Extra arguments and disabled audio. Final Basic views are 27–33 KiB;
warm FFI compile mean is **2.5–2.9 ms**, versus full **10.5–13.2 ms** (50 calls/build).
The ignored `build/test-results/b3-runtime-cc92c463/summary.json` records real runs;
`view-timings.json` records final projection timings. Reproduce the latter with
`Test-B3Runtime.ps1 -CachedViewRoot <completed-runtime-root>` without FFmpeg execution.

Limits: app 500-preset scroll/search and complete edit/frame budgets are not measured.
Full Advanced transfer remains above 4 ms. Dart file reads briefly deny Windows delete sharing;
repository writers retry only sharing violations for <=500 ms. B4's separate live
writer treats sharing/access failures as nonfatal and keeps retries off Render. No monitor
performance or native persistence claim follows from repository tests.

## Delivered

- B2 portable C++17 core/C ABI and NativeVeCore FFI remain the sole domain
  implementation: normalize, validate, compile, lint, completion, estimates, diff,
  payload and pure session checks. No host/filesystem/process calls in the core.
- B2 F2 results remain available: token fields/issue indexes, source/stream facts,
  `overriddenFields`, final GOP frames, typed-length size ranges. C7 UI state and
  empty/absent extension-tolerant fake matching are unchanged.
- B1 captures existing gyan shared **5.1.2**, current gyan static
  **2026-10-12-git-615b07170e-full_build-www.gyan.dev**, and BtbN GPL shared
  **N-127507-g24e860f6d3-20261013**. Approved downloads are only in ignored build/,
  publisher checksums verified; source URLs, exact versions and qualifications are
  in [Windows facts](../research/FFMPEG_WINDOWS.md).
- Windows encoder/muxer lists, 28-name private help, generic codec options,
  format negotiation, matrix and probe timings are committed as B3 parser inputs.
  Embedded core options now use Windows data; B0 design files/fakes stay historical.
- Sampled libavformat 59/63 container tables and conservative unknown-version
  consensus. C2/C3 `libavformatMajor` is additive; services preserve it in the core
  view. Generated private values/pixel formats use supplied build capabilities.
- Basic color policy labels raw input and output (including Extra replacements),
  preventing current FFmpeg from turning tag changes into pixel transformations.
  Advanced seeds carry explicit input tags; inactive Basic color settings stay out
  of arbitrary Advanced text. Actual VEGAS source color metadata remains unknown.
- Fixed x264's unset profile for 10-bit (`high10`); explicit incompatible profiles
  are errors. Correct AMF ABR/CBR/CQP flags and I/P/B quantizers; the old qp_i-only
  CQ mapping is removed from Basic. Saved values are preserved and flagged.
- Removed explicit input `thread_queue_size`, rejected in both current builds;
  commands now work across all three. Installed engine/adapter are untouched.
- Added optional `CommandToken.replacedField` on replacing Extra options and values,
  fulfilling the latest F2 request. `field` still targets the Extra box; aggregate
  `overriddenFields` still marks displaced controls. No app option-name parsing.
- Validation follows effective Extra profile/pixel replacements; `+pixel_format`
  keeps its argv syntax and normalized format facts. Unestablished formats stay
  unknown. Capture runners verify executable/FFprobe version/configuration/library
  identity; only explicit mux/codec refusals can become blocking container rules.
- Six original recipes plus the existing popup have real-core argv goldens;
  no edited-state FakeVeCore sweep. Core data is regenerated by Generate-CoreData.py.
  Uncaptured FDK AAC format stays unknown. Defaults/quality marks/estimates are
  labelled product policy, not measured defaults or empirical quality guarantees.

## Validation

- **255** real mux/readback/decode cases (85/build): **47/54/54** passes, explicit
  refusals retained; hvc1/faststart checks pass. No invalid output or timeout was
  promoted into compatibility rules.
- **184** real-core mode/depth/profile plans: **163** encode/readback/decode passes;
  **21** local Intel/AMD runtime failures (seven/build) retained. NVIDIA tests pass
  on RTX 5070 Ti, driver 32.0.16.1692, Windows 11 Pro 26300, at 320x180. No other
  size/driver/host claim. Final optimized compiler reproduces all recorded argv.
- **180** B1 parser/catalog/identity/refusal regressions. **2,937** native C++ checks, also
  passing AddressSanitizer. **191** checks pass per real-FFI route: native asset,
  explicit DLL and bundled AOT. Small-request warm compile means: 0.79–0.99 ms
  over 500 calls, not a full-capability/app frame budget claim.
- B0 retained fakes: **173 core / 58 service / 281 fixture** checks and C/C++ ABI
  checks pass; the service-major preservation/explicit-null assertion is included. Both packages
  analyze cleanly. Generation consistency and changed scripts are checked.
- All three builds pass 60-frame fractional-rate FFV1/PCM and H.264/AAC plans/FFprobe;
  ten meaningful P010 bits and exact PCM float bytes survive the lossless path.
  This detected and verified the corrected current-build input tagging policy.
- **Offline/synthetic files and real core only; no new fake-host or real VEGAS run.**
  Installed 0.1.2-config-proof, installation/PATH and rollback backups are untouched.
  A5–A7, real two-template/restart persistence and controlled real failure recovery
  remain unverified. Offline results do not pass these gates.

## Limits / app handoff

- After owner merge, app selects NativeVeCore (tests keep explicit fakes) and maps
  token/stream facts, replacedField/overriddenFields, GOP and size ranges directly.
  C3 real providers are available above. The fake catalog remains historical; Native
  profiles carry the Windows facts. No B1 work is waiting on app progress.
- B1's full capability transfer was above the 4 ms edit budget: about **8.9 ms**
  for a 152,474-character map through Dart FFI (50 warm calls), versus the initial
  repeated-copy regression around 57 ms in a Python C-ABI sample. Shared validation
  now borrows capabilities; B3 adds cached Basic views, while F7 must measure app frames.
  Small unprobed requests are not proof of the full-capability UI budget.
- Input queue removal is qualified by B4's focused synthetic named-pipe tests
  above. The existing installed engine remains unchanged; real-host timing is open.
- No empirical per-resolution quality band was inferred from tiny synthetic clips.
  UI_SPEC makes bands conditional on profiles providing one; current marks are
  product policy. A desired curated band needs an explicit product-policy choice.

## Next / queued requests

B3 and F3's platform requests are delivered above. App F7 wires providers and
measures its budgets; B4's History/live writers are ready for gated B6 rendering.
Next agent: continue on ws/platform and incorporate the owner's integrated master
before new work. B3/B4 are committed under the owner's merge authorization.
B4's engine/C5/C6 writers are delivered above; app F7 consumes them through the
existing readers. Next platform work is B5 status-line analysis and the gated B6
adapter/monitor integration, with the owner for any real-host test or installation.

B5/B6 status-line/adapter/progress performance
needs the owner with real VEGAS and gated evidence. Current changes remain
committed on ws/platform for the owner's authorized master merge. No push,
installation or exporter replacement is authorized by that merge request.
