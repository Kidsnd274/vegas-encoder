# Platform workstream

Updated: 2026-10-14 (Asia/Singapore). Worktree `L:\repos\vegas-encoder-platform`,
branch `ws/platform`. **B5 committed/merged; B6 owned snapshot/session checkpoint
validated offline (95 optimized/95 ASan checks).** B1–B4 and app F4 are merged. Continued
from `659fe02`; F3 master `0be99dc` was fast-forwarded before the B1 commit.
B2 is already merged (`bbcbe91`).
The app owns its NativeVeCore/provider switches and UI mapping. WindowsServices
now composes the real C3 providers without implicit scans/probes/writes.

## Master integration (2026-10-14)

The owner authorized commit and merge. B3/B4 are committed as `0fc89a2`; master
integration `8513ecc` includes B1 (`1849990`), B3/B4 and app F4 (`5b96a07`, via
`5bc4b77`). Both workstream tips are ancestors of master; no source conflict.
Merged app analysis and **307 unit/widget tests pass** on the existing SDK.
Golden tests were not regenerated: the app handoff explicitly requires refreshing
the native/Advanced light and dark images after B1's Windows data. Flutter's
generated app-file/lockfile rewrites from this check were restored; app F7 should
refresh its path dependency lock (ve_services 0.3.0) in its own workstream.
Nothing was pushed or installed; the main checkout's existing `.claude/` remains
untouched.

For B5, the worktree was clean before the requested fast-forward to current master
`a0d33c4`; no local changes needed stashing/restoring and no merge conflict occurred.
App-owned files arrived through that merge only. No app-owned files were edited
or app tests/goldens regenerated during B5. The owner then authorized commit and
master merge: **`2bdb44d`**, fast-forwarded into master with `.claude/` preserved.
No push, installation or real-host test followed that Git authorization.

App handoff: merge master into ws/app; wire WindowsServices (F7), remove duplicate
discovery/probe/cache persistence, use recipe-specific reusable capability views,
refresh/review affected goldens and measure the app budgets. Then proceed with
F5 popup and F6 live progress against C4/C5, without declaring real-host gates.

## B6 owned snapshot/session boundary (offline checkpoint)

- `recipe_template.*` places the core's `VEnc` envelope in owned native template
  bytes, resizes without losing fixed host fields/raw text/padding/trailers, and
  rejects foreign, damaged, future and historical proof templates. Fresh creation
  requires an empty product template; no proof migration. The 16 KiB envelope
  budget and odd/even byte layouts remain unqualified at the actual saved host.
- `RecipeTemplateDraft` supplies C4's transaction boundary on its creator UI
  thread: actual snapshot/name in requests, one terminal result, missing/invalid/
  mismatched/crashed-editor cancellation, core domain/lint/capability checks,
  editor Apply as draft only, and host Apply accepting a baseline only after
  S_OK. Preallocation precedes host commit; failure/S_FALSE/exception stays dirty
  and retryable. Prior Apply survives later Cancel/Discard. Immutable render
  snapshots require no library or app lookup.
- The focused tests exposed an object-insertion-order mismatch against existing
  canonical payload JSON; setting comparisons now use core canonical values so
  reordering keys does not create a false edit. Unknown values/preferences remain
  intact. **C2/C4/C5 shapes unchanged**; app-owned files are untouched.
- `Test-B6.ps1 -Asan` passes **95 optimized + 95 instrumented checks**, x64
  `/W4 /WX`, including six authored recipes, both payload parities, native spans/
  allocation limits, core/C4 limits, saved-byte independence, invalid editor
  results, Apply retry and existing fake holder/allocator balance. The runner's
  PowerShell syntax is checked. Tests use owned bytes/fakes, no real VEGAS,
  application process, UI, user state or exporter installation.
- These helpers have **no exporter discovery/page/Render call sites**. Details,
  API ownership, deferred transport and owner gate checklist:
  [NATIVE_RECIPE_BOUNDARY.md](../../NATIVE_RECIPE_BOUNDARY.md). B6 is not complete.
  Next implementation is C4 file/process transport with fake children, then the
  gated page/recipe/monitor bridge. App F5/F6 readiness must be coordinated here;
  do not modify its files. A5–A7, real persistence, controlled real failure
  recovery and monitor performance stay **unverified**.

## B5 delivered (`2bdb44d`, merged to master)

- Static inspection uses the unchanged VEGAS **2026.0.3.189** executable in
  TARGET.md, RTTI and the captured `CSfRenderProgress` identity. Slot 3 stores a
  borrowed description pointer, sets total and resets position; slot 4 only stores
  the pointer. The internal helper forwards it into a scripting description/title;
  public SetPosition supplies a null description. **Visible status-line behavior
  is unverified.** Details/addresses, retained-string lifetime and the concrete
  owner keep/drop/cancel/rollback checklist are in
  [NATIVE_PROGRESS.md](../../NATIVE_PROGRESS.md).
- Isolated `progress-text-proof` build (`0.1.3-progress-text-proof`), default off.
  `B5ProgressText=4` alternates immutable module-lifetime markers at <=2 Hz;
  `=3` initializes once with the real total before frames, never updates via slot
  3. Exact host hash/version/vtable required. Caller-thread/zero-lock guards,
  nonfatal disable after a text failure, normal numeric cancellation unchanged.
  No host interfaces enter workers; no app/monitor launch or reader wait.
- `Inspect-VegasProgress.py` independently checks exact bytes/RTTI/consumer;
  `Prepare-B5StatusLine.ps1` stages three review candidates without installation;
  `Test-B5.ps1` runs fake interfaces and negative host-gating renders. They use
  existing tools/standard-library Python and need no investigation checkout or
  real host for fake tests (`-HostPath` is an explicit read-only static check).
- Review candidates: `build/b5-owner-review/mode-{0,4,3}/`, identities in
  `build/b5-owner-review/review.json`. DLL SHA-256
  `BB3447D10A689895DB8A7652B8397F8B62F03A79BD0CE3D44F8022AECC4F72BF`.
  Installed DLL/PDB/INI and discovery still match their manifest; all three
  payloads also match the main checkout's preserved `candidate-0.1.2-config-proof`
  rollback. B5 source is now committed/merged by owner request; nothing was
  installed, replaced or pushed.
- Focused checks: default/proof MSVC x64 `/W4 /WX` builds; **30** native fake
  progress checks (borrowed lifetime, 500 ms boundary/repolls, slot-3 non-reset,
  thread/lock guards, exact-object rejection, failures and exception containment);
  **three fake-host gated modes with full decoded fixture checks**; retained
  helper/boundary/configuration **24/9/67** and default exporter fake-host
  regression (repeat/fractional/short-read/video-only/cancel/failure/destination/
  Unicode and checker rejection). All pass. Static inspector checks pass against
  the exact host, with eight changed/truncated/unbacked-span rejections. Changed
  PowerShell scripts parse; staging rejects escaped/existing output directories;
  three owner-candidate manifests match actual bytes; `git diff --check` passes.
  Latest fake output: `build/test-results/b5-fabae044/` and
  `build/test-results/b5-default-regression/`. **No new real VEGAS run.**

Next: owner reviews the candidates and separately authorizes the B5 installed
trial, or drops the line based on the static limitation. B6 stays gated on A5–A7.
Real two-template/restart persistence, controlled real failure recovery and
monitor performance remain **unverified**. No monitor performance conclusion
follows from text markers or the existing B4 async-file checks.

## F4 core metadata coordination (queued; C2 unchanged in B5)

The app's outstanding requests in app.md were read after the master merge.
Continue its documented reduced display/fallbacks until native facts land;
do not infer stages, encoder IDs or macro semantics in the app.

| Request | Platform handoff / next implementation |
| --- | --- |
| Advanced stage/macro roles and option/value marker | Add core-authored roles/marker while preserving UTF-16 source spans and argv. A macro word needs both macro identity and stage, so use additive metadata rather than losing its stage when role becomes `macro`. General/ambiguous scopes stay unknown. Cover quoted/expanded macros, stream specifiers and literal values starting with `-`. |
| Macro catalogue | Add a core API/C ABI plus Dart model for name, description, required flag and expanded value in the supplied media/paths context. Keep completion and expansion on the same C++ definitions; update fakes with the contract. No app-only macro expansion. |
| Advanced encoder IDs | Add optional native video/audio IDs where the active command establishes them. Preserve unknown for ambiguous/general output scopes; never read inactive Basic selections or reverse-map display labels. |
| Temporary output preview | C2 already takes `CompilePaths.output`; B4 passes its uniquely allocated temp path before core compile, and C6 records actual argv. Naming belongs to the engine, not portable compile. Keep the current selected/sample preview path explicitly labelled as a preview; no invented collision-free runtime filename in C2. Coordinate a services/context helper only if the owner wants an illustrative temp preview. |
| Partial highlighting with an open quote | Add trustworthy prefix spans/quote diagnostic position without treating an invalid command as renderable or emitting partial executable argv. Preserve UTF-16 offsets, macro guards and the error that blocks Apply/render. |

These changes are queued after B5 review, with focused core/FFI/fake tests and
CONTRACTS updates together. App owns adoption/widget/light-dark goldens through
its workstream. No C2 shape, core compile semantics or app-owned source changed
for B5. Owner-owned TECH_ARCHITECTURE §5.6 can now link NATIVE_PROGRESS.md and
replace the earlier "unmapped meaning" with the precise borrowed-description
effects; this workstream proposes that update, without editing the owner's file.

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
SDK were changed. B3/B4 are now committed and merged as recorded above.

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
Next agent: continue on ws/platform and recheck status/master before new work.
B5 `2bdb44d` is committed and merged under the owner's latest authorization;
B6's offline boundary checkpoint is described above. Preserve any later local
changes and the main checkout's existing `.claude/`/ignored candidates/backups.
B4's engine/C5/C6 writers are delivered above; app F7 consumes them through the
existing readers. B5 static/probe preparation is delivered above; its real-host
trial and gated B6 adapter/monitor integration need the owner.

B5/B6 status-line/adapter/progress performance needs the owner with real VEGAS and
gated evidence. The owner authorized source commit/master merge, with no push.
The prepared B5 installation/trial approval is pending; installed exporter and
user state remain unchanged. B6 activation is not authorized or qualified by a
B5 trial. Deferred persistence is not reopened automatically.
