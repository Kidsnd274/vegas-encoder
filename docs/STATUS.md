# Vegas Encoder status

Updated: 2026-10-16 (Asia/Singapore). Owner-installed version: 0.1.7-recipe-proof
(frontend 0.1.7+1; template-name-fix variant installed on VEGAS 2026.0.3.189).

## Current progress

**Owner-authorized commit/merge (2026-10-16):** committed the platform snapshot
as `fd4edb3`, preserving its 34 changed/new files. Verified that all of its runtime,
package and test source changes already match the unified original checkout;
its patch also matches the earlier consolidation backup exactly. Commit the
unified workflow/documentation/Advanced-golden version and join that platform
history without replacing the already consolidated tree. Final development is
on local `master` in `L:\repos\vegas-encoder`; the retained platform branch is
advanced to the same merged result so both folders are clean. No remote push,
installed replacement, worktree deletion or new qualification. Existing 558 app
tests/native build/3,055 core checks cover the unchanged implementation; only
workflow/commit-status docs and the local scratch ignore rule changed afterward.

**Unified development (2026-10-16):** owner consolidated app and platform under
one agent in the original `L:\repos\vegas-encoder` checkout, on local branch
`codex/unified-integration`. Master `86aefaf` already included committed app
`493f146` and platform `7a8493a`; the clean app worktree had no missing edits.
The platform's 32 modified files and two new goldens were transferred and
byte-verified before updating workflow docs. Source patch/new-file backup is
under ignored `build/consolidation-backup/`. Old worktrees, `.claude/`, installed
candidate/data/log paths and exact rollback files are retained. No commit, push,
master merge, installation or real-host gate pass is part of consolidation.
New development/builds use the original checkout. One current queue is in
[NEXT_AGENT.md](NEXT_AGENT.md); old app/platform handoffs are historical.

Validation from the original checkout: existing dependency lock unchanged,
clean app analysis, **558 app tests passed**, optimized native /W4 /WX build,
**3,055 native core checks**, and current B1 argv goldens check passed. The first
full app run found ten Advanced screenshots still showing `stats_period 0.5`.
All differences were confined to that digit (7x10 bounding boxes); reviewed
light/dark output and refreshed only those intended 0.2 command-text baselines.
The 14 Advanced golden tests and subsequent full suite pass. **184 local Markdown
file links** resolve and all **26 transferred non-document code/data/test files**
remain byte-identical to the preserved platform source. Restored incidental
generated-file line endings; no dependency/tool upgrade. These are offline checks,
not a real-VEGAS run. Earlier candidate/rollback hashes and trial paths are unchanged.

**Owner defers progress trial (2026-10-16):** leave faster-progress installation/
real-host review and the monitor performance comparison for next time. The candidate
remains prepared; no new installation or qualification pass is inferred. Other
useful work is app adoption of delivered file import, popup-size storage, Advanced
metadata/macro catalogue/encoder IDs and monitor bit-depth facts. Desktop-launch
actions additionally need a platform launcher and running-instance coordination;
the prior blanket claim that all three services were ready was too broad. These
follow-ups precede review/consolidation and the owner's installer.

**Faster progress candidate (2026-10-16, prepared, not installed):** owner wants
the monitor to update faster before measuring overhead. Core-owned FFmpeg
`-stats_period` changes from 0.5 to 0.2 seconds in Basic and Advanced; the independent
C5 writer coalesces ordinary samples every 200 ms (formerly 500 ms), and the C3
live reader polls every 100 ms (formerly 250 ms). Phase/terminal updates still
bypass coalescing, and Render never waits on the monitor/writer. No schema change.
Official FFmpeg docs retrieved with Context7 confirm `-stats_period` controls
`-progress` reporting. An actual two-second FFmpeg run produced 10 intermediate
reports with a 202.7 ms median gap; this is not a real-VEGAS UI latency measurement.

Checks passed: 3,055 native core checks and reviewed argv goldens, 5 Hz writer
wake/coalescing/phase checks with a fake child, 150 real-file C3 repository checks,
24,477 engine checks / 23 fake-host real-FFmpeg and controlled-child cases,
138 adapter checks / 11 fake-host real-FFmpeg cases, 216 snapshot/session,
95 transport, 124 page checks, clean app/service analysis, 50 monitor unit/widget/
light-dark golden tests, and 65 packaging checks. Native optimized /W4 /WX build
passes. Flutter release compilation finished but its final copy was blocked by an
open development app's DLL. The same generated Release install script was directed
to a fresh build folder; assembly succeeded and compiled DLL/AOT inputs were
hash-verified, leaving the running app untouched.

Staged `build/b6-candidate-0.1.7-faster-progress`, same 0.1.7 / 0.1.7+1 stamps,
native SHA-256 `918C22A4F961D4E41883210B37FAF27A4326AE8AEADB26ED0B8C1C1FAA916B0D`.
Trial settings/library/history are copied (active edit sessions excluded), with
five verified exact installed-template-name-fix rollback files. No commit or
installation. Next: owner installs, checks one normal render's responsiveness,
then the existing monitor time/memory comparison. Overhead and real UI cadence
remain unqualified; the earlier deferred/unconfirmed checks keep their scope.

**Large-preset immediate reopen fix (2026-10-16, installed, owner-confirmed):**
owner hit `S-REQUEST, templateName` after Load/Apply/reopen of capacity 16000,
before restart. The draft's native display name is empty; an otherwise accepted
recipe cannot form C4. This does not establish payload corruption or a host size
limit. The native fix uses native name → captured page name → validated recipe
name for C4 display, preserving native text and strict CRC/version/size checks.
The old code reproduces the same error with an intact large unnamed snapshot.
Fixed **216** snapshot/session checks cover exact 4096/8192/12288/16000/16383/16384
envelopes, immediate reopen, missing names, precedence and corrupt CRC refusal.
**124** native-page, **95** transport, **138 / 11** actual-adapter fake-host
real-FFmpeg cases, writer checks, optimized build and **65** packaging checks pass.
These do not establish real-host capacity. Page diagnostics record only label
source and declared byte/text counts; why native text is absent remains open.

Separate `build/b6-candidate-0.1.7-template-name-fix` preserves the byte-identical
error-ui frontend, copied trial data and five exact installed-error-ui rollback
files. Native SHA-256:
`BBB01B74CB88F3CF4A33D0E86B72A9AFC595C1D86DC66E42C8369B3892C606EA`.
Same version labels, hash-distinct variant; installed DLL hash matches. The owner
confirms Load → Apply → reopen now works in real VEGAS. No commit was made.
The latest reopened request (`EAFB2258-877B-4274-9FBB-D13AA08D8821`) has all
15,088 UTF-8 notes bytes, ending `END 容量`, exactly matching the seeded preset,
and FFV1/PCM-float/MKV settings. Notes are not shown in the popup; inspect session
data instead of asking the owner to find them. Confirmation that this reopen
followed saving and restarting is still pending; immediate reopen alone does
not establish the complete persistence sequence.
Encoder-failure recovery remains owner-deferred; other qualification limits stand.

The owner subsequently confirms the preset is visible and appears to work
correctly. Accept this functional check and move to monitor performance without
repeating the notes request. The exact large-template save/restart sequence was
not explicitly confirmed; keep that qualification limit separate from the observed
intact reopened request and owner acceptance.

**Owner qualification scope (2026-10-16):** the owner explicitly skips the
additional same-session good render after encoder failure as excessive for this
stage and proceeds on the working assumption. Record that check as owner-deferred,
not passed; do not request it again without a new relevant failure. Real failure
return/presentation and earlier cancellation/recovery evidence stand. Next is a
lean large-payload persistence check using the prepared 16000-byte input, followed
by monitor overhead/memory and installer work. One intact large sample establishes
a tested lower bound, not an absolute host capacity limit.

**Error UI accepted in real VEGAS (2026-10-16):** the owner installed the
error-ui variant and says it "looks good." The screenshot shows the prominent
missing-filter cause, stay-open label and Close action beside VEGAS's error
dialog. New C6 job `9A1785F2-5243-440D-8C7F-B942F8C807CD` is failed with no
publication; installed manifest/INI and staged frontend hashes match this trial.
Record real-host failure presentation as owner-approved. This feedback does not
establish timed retention/manual dismissal or a successful post-error render;
same-session encoder-failure recovery is still next, followed by capacity and
monitor time/memory. No implementation change or test rerun was needed.

**Error monitor UI follow-up (2026-10-16, prepared, not installed):** the owner
retested the native error fix. Screenshot and C6 job
`16005680-443B-4979-9BBA-DD374003F054` show real FFmpeg failure/no publication,
the concrete missing-filter cause and VEGAS's own error dialog (0x8007006d).
This confirms failure reaches VEGAS; same-session recovery is not yet reported.
At the owner's request the monitor now highlights the authoritative C5/C6 cause
in a prominent error panel instead of trailing stderr warnings. It shows errors
immediately, scrolls long messages, says it stays open until closed, and has an
explicit Close action. Failure cancels any prior auto-close countdown.

Clean app analysis, **558** full app tests (**50** focused monitor checks),
light/dark normal+long-error visual inspection, release build and **65** package
checks pass. UI validation uses fakes/goldens, not real VEGAS. Fresh
`build/b6-candidate-0.1.7-error-ui` keeps the tested native fix and updated
0.1.7+1 frontend, copied trial data and exact installed-error-fix rollback.
Manifests identify this hash-distinct development variant. Installed files and
prior candidates are unchanged; new UI still needs the owner's real-host retest.

**0.1.7 encoder-failure reporting fix (2026-10-16, prepared, not installed):**
the real invalid-filter job `76568149-62D3-43A8-B566-5C62B756BE3C` is failed,
FFmpeg exit 1, no publication. Its stderr identifies the deliberately nonexistent
filter, but the monitor summarized a secondary broken-pipe error and the owner
reports VEGAS remained waiting. Recipe Render opened an unowned modal error box
before returning the failing HRESULT. The source fix removes that blocking box
for recipe renders and selects a bounded causal FFmpeg diagnostic for C5/C6,
preserving the original HRESULT, full stderr, cancellation and host/probe errors.
No frontend source changed. Optimized build and engine checks pass (24,487 /
23 cases); actual adapter checks pass (138 / 11 fake-host real-FFmpeg cases),
including the bad filter, no publication, error return with ShowEncoderErrors=1,
matching C5/C6 messages and subsequent recovery. Snapshot/transport/page/monitor
and 65 packaging checks pass. These fixes still need real VEGAS retesting.

Separate `build/b6-candidate-0.1.7-error-fix` has copied trial data and exact
installed-0.1.7 rollback. It retains the existing 0.1.7 version stamps/frontend;
DLL SHA-256 **CE46036DC5A7ACC3A296BF91B610A7B04DF6367F3BC6BD7989AA0982FB75D017**
distinguishes it from installed **0A5D6F74…**. Manifest marks dirty source and
records a source patch hash; it is not release-qualified. Nothing installed or
committed by this continuation. See [retest/rollback](B6_TRIAL.md). Actual real
encoder-failure recovery, capacity and monitor overhead remain open.

**0.1.7 real cancellation/recovery (2026-10-16):** the owner reports the requested
cancel-and-render-again sequence worked. C6 job `17E0A52A-F34A-4B9B-A887-9868150ABD49`
is cancelled by the host after 605/1470 frames; no final output was published,
no partial was retained, and `017_test_cancel.mkv` is absent. The following job
`BD533179-4D29-47B7-B4A1-93C30C4D1FD4` uses the identical recipe hash, succeeds
with 1470 frames, publishes `unchaed_render.mkv` (19,312,208 bytes) and passes
sampled H.264/AAC FFprobe readback. Owner feedback supports the requested
same-session recovery sequence; records establish cancellation then success,
but do not independently identify the VEGAS PID/session or measure cancel-click
latency. Installed 0.1.7 DLL identity is unchanged. This is real VEGAS trial data,
not a fake-host result. Next: actual encoder-failure recovery, then bounded
capacity and monitor time/memory; broader qualification remains open.

**0.1.7 real-host focus retest (2026-10-16):** after the requested focus trial,
the owner reports the issue "seems like it has been fixed." The installed DLL
matches the staged 0.1.7 candidate; the real-host log identifies VEGAS
2026.0.3.189 and native 0.1.7-recipe-proof. Record the reported focus repro as
owner-confirmed fixed, without claiming every Apply/Cancel/switch-order or passive
background variant was individually observed. Two frontend traces show the window
at **698.2 / 536.4 ms** after process creation; native CreateProcess took
**168.7 / 36.2 ms**. These are observations, not click-to-visible guarantees.
The 65-check packaging rerun and exact installed-0.1.6 rollback verification pass.
Next: controlled real cancellation and encoder-failure recovery, then bounded
payload capacity and monitor time/memory. No 0.1.7 render/recovery or full A5–A7
qualification follows from this focus feedback.

The first cancellation attempt was blocked before encoding by missing default
FFmpeg selection (zero frames/samples, no published output). The trial profile
already selects the existing `C:\ffmpeg\bin\ffmpeg.exe`; the normal user profile
has no installations/default. This is consistent with a non-trial VEGAS launch.
The subsequent trial retry above succeeded. Ordinary launches need their own
desktop-app default selection; the two profiles remain separate.

**0.1.7 focus fix / B7 inputs (preparation checkpoint):** the owner-authorized
narrow frontend change captures foreground before re-enabling the valid owner,
then explicitly activates it before destruction for foreground closes only.
Same existing fake-window probe: old frontend **3/7**, new **7/7** close cases,
covering Apply/Cancel, both full-screen switch orders and passive background close.
New same-DPI process-age visible traces are **0.436–0.463 s**; native parallel
startup and renderer are unchanged. Real VEGAS focus/startup retest remains pending.
Frontend analysis and **44** popup widget/light+dark golden checks pass; native
optimized snapshot/transport/page/C7/writer checks and staged DLL fake-host
discovery pass. Matched **0.1.7-recipe-proof / app 0.1.7+1** is staged separately
with copied trial data, bounded capacity presets and exact installed-0.1.6 rollback.
Both PE file versions are 0.1.7.1, with native frontend-version enforcement.
B7 supplies complete runtime/notices/hash inputs, read-only VEGAS detection and
installer closure/update/rollback rules; no Inno installer or installation is done.
See [owner checks](B6_TRIAL.md), [installer inputs](B7_INSTALLER_INPUTS.md) and
[validation/handoff](product/workstreams/platform.md). Owner-confirmed normal
template persistence stands. Controlled real cancellation/encoder-failure recovery,
payload capacity and monitor overhead/memory remain unqualified; A5–A7 stay open.

**Prior 0.1.6 owner feedback:** saved templates persist across VEGAS restarts; record
normal persistence for the tested recipes as owner-confirmed, rather than still
deferred. This does not measure maximum private-payload capacity. The focus bug
remains: switch to another full-screen app, return to VEGAS/the editor, then
Apply; the other app reappears. Actual minimization has not been established.
The frontend close handler enables the native owner but does not explicitly
activate it before destroying the foreground popup. Native polling/activation
after exit is not sufficient to establish correct handoff. App-owned close fix
and regression request are in the [platform handoff](product/workstreams/platform.md).
No frontend code or installed files were changed. Controlled real cancellation/
failure recovery, capacity and measured monitor overhead remain open; subjective
normal performance is not the prescribed on/off measurement. A5–A7 are not fully
qualified. See [B6_TRIAL.md](B6_TRIAL.md) for the existing-toggle comparison.

**0.1.6 owner retest:** the owner reports editor opening is "a lot better now".
Three frontend traces show the window visible **748.6 / 533.3 / 526.8 ms after
process creation**; native CreateProcess took **153.1 / 32.8 / 31.8 ms**, with
UI request/scheduling **3.7 / 0.4 / 0.4 ms**. These are observed real-host runs,
not a general latency guarantee or a precise click-to-visible total. B6's normal
popup/template/recipe-render/progress path is implemented, supported by this
startup retest and the distinct-codec renders below. Subsequent owner feedback
above confirms normal restart persistence and clarifies the remaining focus bug.
Capacity, controlled real failure recovery and monitor overhead remain outstanding.

**0.1.5 owner retest / 0.1.6 startup work:** the owner reports both templates
render with different intended codecs and template bugs appear resolved. C6
confirms FFV1 and libx264 outputs succeeded, with sampled verification **0.719 s /
0.187 s**. This strengthens recipe-render evidence; it does not by itself pass
all persistence/capacity/recovery/performance gates. New reports: intermittent
6-second editor opening and VEGAS minimizing after popup Apply.

Native logs isolate the large spike to the grouped process launch/resume stage: fast
33–37 ms versus slow **7.0–12.4 s**, with file/validation ~6–8 ms and preflight
~2–3 ms. The old grouping cannot distinguish process creation from resume or
overlapping child work; it does not establish a shader cause. The app already
defaults to Skia. **0.1.6-recipe-proof**
starts the existing transport in parallel with VEGAS's UI, using copied C4 values
and a retained DLL lifetime. It adds explicit same-thread owner-chain restore on
return from the foreground editor, keeping background completion passive. The
unchanged 0.1.5+1 frontend is included. The owner subsequently confirmed faster
opening (above); the real Apply/minimize fix still needs explicit confirmation.
Offloading alone is not claimed to eliminate every Windows delay. No new user
launch-cancel flow.

**First real B6 trial and fixes (2026-10-15):** owner reports popup edits and a
successful render/progress window on VEGAS 2026.0.3.189. Native C6 confirms FFV1,
PCM float, 182 frames of 1920×1080 P010 input, success/publication and passed
FFprobe readback. This is a real smoke result, not persistence/recovery/performance
qualification. The trial exposed byte-shifted template names/notes, intermittent
invalid edit requests, about three-second popup startup and Explorer opening Documents.

The **0.1.5-recipe-proof / app 0.1.5+1** candidate aligns the native UTF-16 suffix
with at most one zero byte outside the strict payload; old intact odd envelopes
still read, but corrupted names cannot be reconstructed. No template-index change:
the historical hidden id-0 workaround was already present. Explorer now receives
its switch separately from quoted paths. Progress no longer adds a periodic idle
wait, keeping the two-Hz budget. Sampled readback replaces a full recount: on the
owner's output, the same FFprobe fell from **9.897 s to 0.743 s**. All stream/codec/
positive-video and publication/cancellation/error guards remain. Late-file corruption
is outside this sampled check. Popup startup gets immediate status/timings; its
three-second cold latency remains **unresolved pending measured retest**.

Staged separately in `build/b6-candidate-0.1.5`, preserving the first candidate,
its data, existing native templates and installed exporter; rollback copies the
currently installed 0.1.4 files/manifest. See [B6_TRIAL.md](B6_TRIAL.md). Focused
checks and app-owned startup follow-up are in the platform handoff. A5–A7, real
save/restart persistence, capacity, controlled real failure recovery and monitor
performance remain unverified.

**B6 connected candidate (2026-10-15):** owner resumed B6 and offered to test
VEGAS. Prepared **0.1.4-recipe-proof** with the existing **0.1.4+1** frontend:
fresh native recipe template → popup draft/Apply → immutable recipe render →
real FFmpeg → C5 monitor/History. Opt-in MKV/P010/square-pixel/48 kHz stereo scope;
general Advanced output remains unsupported/unknown. Default/proof build paths
remain available. Candidate, isolated C7 settings and exact prior-exporter backup
are in `build/b6-candidate`; **nothing was installed**. Owner instructions and
rollback: [B6_TRIAL.md](B6_TRIAL.md).

Focused optimized checks: **3,055 core**, **230 real-FFI**, **95 snapshot**,
**87 transport**, **102 native-page**, **19 C7 runtime**, **94 adapter checks /
9 real-FFmpeg fake-host cases**, plus the actual staged DLL's discovery/conformance/
render fake-host pass and writer-owned monitor launch checks. Existing frontend
release builds; real popup/monitor window checks with the existing fake owner pass
the primary placement/Cancel/no-activate paths. Some secondary foreground checks
had failed foreground prerequisites; these are not claimed as passes. No frontend
source changes. A5–A7, real persistence, controlled real failure recovery, payload
capacity and monitor performance stay **unverified pending owner VEGAS tests**.
Earlier “B6 disabled/on hold” entries below describe their historical checkpoints.

**Selected-file preset import (2026-10-15):** added the C3
PresetTransfer.importFrom(path, newId: ...) service requested by the app. It uses
bounded file reads and existing native validation/create-only Save, preserving the
source and existing presets on failure; a matching in-memory fake is supplied.
**150 repository / 86 fake-service checks** pass; package analysis is clean.
Frontend adoption is app-owned. Focused validation is in the
[platform handoff](product/workstreams/platform.md). No real VEGAS run or installation;
B6 remains disabled and the existing real-host qualification limits are unchanged.

**F6 C5 precision facts (2026-10-15, completed checkpoint):** after committing the library-watch
checkpoint **b6811be**, integrated app 493f146 through **ea4d557** on ws/platform and
fast-forwarded master. No push; master's .claude/ is preserved. The app's old quote
diagnostic assertion/goldens were adopted in its own 493f146 commit.
Additive nullable outputBitDepth/pixelFormatConversionReducesPrecision now travel
from established core signal facts through the native C5 producer, models, disk
reader and fakes. General Advanced scope and unknown precision remain null. A small
core scope correction keeps input/other-stream pixel options and arbitrary filters
from claiming output/conversion certainty; argv is preserved. Optimized core **3,034**,
FFI **208**, C5 facts **59**, repository **131**, fake **79**, fixture **295** and
selected app **65** checks pass. Optimized engine **23,160 checks / 22 fake-host cases**
and native C5/C6 readback **279 checks / 21 jobs** pass. Both packages analyze cleanly.
Details are in the [platform handoff](product/workstreams/platform.md). No frontend edits,
installation or real VEGAS run. B6 remains disabled; A5–A7, real persistence,
controlled real failure recovery and monitor performance remain **unverified**.

**Merge/library-watch continuation (2026-10-15):** reviewed platform checkpoint
fa58338 is integrated with app F6 through **9018965**, now on master; no push and
the main checkout's .claude/ is preserved. At that checkpoint app analysis passed;
394 unit/widget tests passed with one app-owned quote-range assertion outstanding.
Master has since advanced to app 493f146, adopting the precise quote range and
affected native goldens; that request is resolved in the integrated app checkpoint.
The F7 library-watch checkpoint is committed as b6811be and merged through ea4d557:
500 unchanged presets now reuse native metadata/immutable snapshots, with zero
normalization calls (**1.77–3.21 ms median / 2.05–4.03 ms p95**, JIT/AOT runs).
Continuation medians are **1.827 ms JIT / 1.866 ms AOT**; cold reads still cost about
0.5–1.1 s. Review restored FILE-READ for preferences.json directories and verified
authoritative get/Save/CAS despite metadata-preserving external edits.
Focused library **99** (JIT/AOT), retained repository **114**,
service fake **64** and app service-wiring **10** checks pass; service analysis is
clean. Details/limits are in the [platform handoff](product/workstreams/platform.md).
No real VEGAS run, install or exporter update. A5–A7, real persistence, controlled
real failure recovery and monitor performance remain **unverified**.

**Advanced core/FFI checkpoint (2026-10-15, owner-authorized commit/merge):** bounded immutable
capability reuse removes repeated Dart serialization/native lint copies. Additive
F4 token stage/macro/option metadata, macro catalogue, conservative encoder IDs,
partial quote prefix highlighting and C7 popup-size storage are implemented in
platform-owned paths. Optimized native **3,020**, native-asset FFI **208**, core/service
fake **177/64** and Windows repository **114** focused checks pass; both packages
analyze cleanly and B1 argv goldens are unchanged. Full real capability-map edits now measure **2.08–2.10 ms median / 2.14–2.31 ms
p95** (lint + Advanced + Basic compile, JIT; first transfer **12.9–16.1 ms**).
Method, limits and app adoption are in the [platform handoff](product/workstreams/platform.md).
No exporter/app integration or real VEGAS run; A5–A7, real persistence, controlled
real failure recovery and monitor performance remain **unverified**. Existing B6
sanitizer limitation is unchanged; no sanitizer/process/thread debugging resumed.

**B6 editor transport checkpoint (2026-10-15, offline):** fresh UUID session
directories, bounded atomic C4 requests, explicit owned-helper launch, creator-thread
zero-time exit polling and one validated result are implemented. Cancel/crash/
invalid results preserve the prior draft; direct known-file cleanup retains unknown
entries and reports incomplete cleanup. Optimized x64 `/W4 /WX` passes **89**
transport checks with real Windows files/processes and fake children, plus the
retained **95** recipe/draft checks. Current AddressSanitizer validation is
**incomplete**: the boundary run stalled at its thread guard after 87 checks.
The owner reported an antivirus alert during process/thread debugging and asked
to stop that investigation. Temporary diagnostic test edits are removed; the
cause is not established, and no sanitizer pass is claimed for this transport.
There are no exporter/page/Render call sites,
no real app/monitor launch and no new installation/VEGAS run. Remaining work:
connect the native page to the actual F5 popup when ready and the owner resumes
the native gates, then recipe/C5 progress integration. No additional fake-owner
framework is planned. See [native recipe boundary](NATIVE_RECIPE_BOUNDARY.md).
**A5–A7, real persistence, controlled real failure recovery and monitor performance
remain unverified.** B6 is not complete; deferred persistence is not reopened.

**B5 owner-authorized real trial (2026-10-14):** control and two slot-4 renders
complete normally on the reviewed `0.1.3-progress-text-proof` DLL / VEGAS
2026.0.3.189. Owner confirms normal advancing control progress. All return S_OK,
encoder exit zero/publication and zero locks. Full decode of control and final
text-test output verifies 182 1080p frames at 30000/1001 and 291,491 48 kHz float32
stereo sample frames. Mode 0 makes zero text calls; both mode-4 renders make eight
successful guarded calls, but the owner sees no switching text. **Drop custom
dialog text**, per the owner's preference, and prioritize useful numeric progress
and the separate frontend window. This candidate's cancel/recovery and mode 3
were not tested. The frontend window has a shell; live figures remain F6, and
the installed proof has no B6 monitor/recipe bridge.
The owner authorized **keeping a healthy candidate, rollback only for issues**;
the exact prior 0.1.2 rollback remains preserved/verified. No rollback or push.
See [progress trial](NATIVE_PROGRESS.md). A5–A7, real persistence, controlled
failure recovery and monitor performance stay unverified. No useful status line
was established; that product track is dropped, not passed.

**B6 offline boundary checkpoint (2026-10-14):** the owner authorized committing
B5 as `2bdb44d` and fast-forwarding master; the main checkout's `.claude/` was
preserved. Work continues on `ws/platform` with owned recipe envelope placement
and C4 per-page draft transactions. Both optimized/ASan x64 `/W4 /WX` builds pass
**95 checks**: byte/text/suffix preservation, bounds, proof/future rejection,
single/invalid/crashed session handling, core validation, Apply failure/retry,
thread guards and fake-holder allocation/reference balance. The helpers have
**no exporter/page/Render call sites** and launch no editor or monitor. See
[native recipe boundary](NATIVE_RECIPE_BOUNDARY.md). B6 is not complete. No new
real VEGAS run or installation; A5–A7, real persistence, controlled real failure
recovery, status-line visibility and monitor performance remain unverified.

**B5 static/probe preparation (2026-10-14, committed/merged `2bdb44d`):** clean
`ws/platform` fast-forwarded to current master `a0d33c4`. Exact VEGAS 2026.0.3.189
bytes/RTTI establish slot 3 as borrowed text + total + position reset, and slot 4
as borrowed text only. The internal consumer is a scripting render-status
description/title; public SetPosition does not forward it. An isolated,
default-off `0.1.3-progress-text-proof` candidate uses immutable markers, exact
host/vtable gating, caller-thread/zero-lock guards and <=2 Hz slot-4 calls;
optional text failure disables the probe. Slot 3 is initialization only.
The concrete opt-in/rollback checklist is in [NATIVE_PROGRESS.md](NATIVE_PROGRESS.md).
Focused results and staged candidate location are in the
[platform handoff](product/workstreams/platform.md). **No real VEGAS test,
installation or monitor launch.** Status-line visibility, A5–A7, real
two-template/restart persistence, controlled real failure recovery and monitor
performance remain unverified.

**Master integration (2026-10-14):** owner-authorized `8513ecc` includes platform
B1/B3/B4 (`1849990`, `0fc89a2`) and app F4 (`5b96a07`, merged through `5bc4b77`).
No source conflicts. Combined app analysis and 307 unit/widget tests pass; native/
Advanced goldens still need the app-owned B1 refresh. No push or installation.
Next: app F7 real-service wiring and the owner-operated B5 progress-text trial;
see [platform handoff](product/workstreams/platform.md). Real-host gates unchanged.

**Product design (2026-10-12):** the `product-ui-design` branch is merged into master,
and the owner has reviewed it. Decisions are in
[docs/product/README.md](product/README.md#decisions): the Signal Flow direction
(round 2 mockup in `docs/product/design/signal-flow.html`), Basic/Advanced modes,
Flutter, Windows x64 only, a theme that follows Windows, no proof-template migration,
and render progress through a VEGAS status line (if a real-host test allows it) plus a
small progress window. The project license is still open. The platform B0 contracts,
draft recipe schema/C ABI and pure Dart packages with fakes are now implemented;
see [contracts](product/CONTRACTS.md) and [platform handoff](product/workstreams/platform.md).
The B2 native product core and B3 Windows services are implemented below. Engine/
progress/job support is now implemented as B4; gated adapter integration follows.
The VEGAS gates below are unchanged.

**B4 complete (2026-10-14, owner-authorized commit/merge from ws/platform):** engine accepts C++ core
argv, parses bounded FFmpeg progress, writes C5 live status and C6 jobs/history
asynchronously, and uses core expectedStreams for bounded FFprobe readback before
publication. Host polling stays on Render's caller thread during hashes, pipe waits
and process creation; host frames are copied/released first. Output failure/cancel
and destination preservation remain distinct. Publication failures are nonfatal
and cannot make Render wait for the app/file readers. No monitor is launched yet.
**33,269 fake-host checks / 30 cases** pass, including 12 recipe runs across the
three B3 FFmpeg builds, fractional 1080p, cancellation/recovery, publication races,
blocked/slow pipes, probe errors and storage backpressure. Optimized maximum poll
gap 110 ms, extra parent working set 35.9 MiB, video/audio queue highs 29.7 MiB /
154.6 KiB, blocked-pipe cancel 375 ms. **23,053 ASan checks / 22 cases** pass on
gyan 5.1.2; ASan timings are not release measurements. B3 readers accept 29 native
jobs (**350 checks**). Core normal/ASan each **2,965**, native-asset FFI **196**,
helper/boundary/configuration **24/9/67** and existing exporter fake-host regression
pass; both packages analyze cleanly. Readback is not broad media/full-decode
qualification. See [platform handoff](product/workstreams/platform.md). Existing
B3 changes are preserved. No app-owned or installed/user state changed; no new
real VEGAS test. **A5–A7, real two-template/restart persistence, controlled real
failure recovery and monitor performance remain unverified.**

**B2 core/FFI (2026-10-13):** master through F2 (`ab7e7ab`) is in ws/platform.
The later F2 platform-fact/UI-state merge (`230c724`) is also incorporated.
Portable C++17 normalize/validate/compile/lint/complete/estimate/diff/payload and
pure session checks are implemented, with a Dart `NativeVeCore()` facade and native
asset hook, DLL/static builds, token/stream facts and the additive F2 result fields.
The app owns switching its fake provider after merge. B1 replaces the native
bootstrap profiles/options with qualified Windows data below; B0 fakes remain
historical design samples.

**B3 complete (2026-10-14, owner-authorized commit/merge from ws/platform):** real Windows discovery,
versioned help parser, streamed curated/lazy probes, bounded four-child process
pool, GPU/driver-qualified hardware cache, installation-health/C7 updates and
native-compiled synthetic preset tests are implemented. File-backed presets,
machine settings, capability cache, job/history reads, live status and edit-session
I/O. Atomic replacement and bounded Windows byte locks protect concurrent saves;
built-in preferences persist separately, preset history retains 20 old revisions,
and transfer/log/location APIs cover the app's storage requests. Core normalize
supplies Basic requiredEncoders; Advanced requirements remain explicitly unknown.
Job summaries/command/error/log fields are additive; B4 now supplies the native writers.
110 real-Windows file/lock/native-core checks pass, including competing processes,
crash lock release, malformed/future files and failed-write recovery. Final native
verification facts pass **2,955** native checks including ASan and **194**
native-asset FFI checks; retained **173 core / 58 service** fake checks pass. Both
packages analyze cleanly. The service suite passes **4,456** captured-parser/
fake-FFmpeg/real-Windows-process/DXGI checks. All **24** native-compiled preset
encodes/readbacks/full decodes pass across the three supplied FFmpeg builds
(**138** checks), including video-only/Advanced. Hardware smoke uses 320x192;
preset tests use 320x180/30 fps on Windows 11 Pro 26300, RTX 5070 Ti, driver
32.0.16.1692. MF is forced to hardware and GPU-only surfaces uploaded explicitly.
This is default-command smoke qualification, not HDR, other resolutions or
all-device compatibility. Parser/cache version 2 invalidates earlier commands.
No new fake-host or real VEGAS run. App-owned files and installed/user state are
untouched. App F7 injects WindowsServices and removes fake-era installation/cache
persistence copies; services own C7 installation updates. **61** further native
checks preserve compact/full compile results for built-ins, Extra arguments and
disabled audio on all three real probe caches. Basic warm compile is 2.5–2.9 ms
versus full Advanced 10.5–13.2 ms (50 calls/build); app frame/search/scroll budgets
remain unqualified. Live
status publication must remain nonfatal and off Render's waits in B4.

**B1 Windows FFmpeg (2026-10-13):** gyan 5.1.2, gyan static git `615b07170e`
(2026-10-12), and BtbN GPL shared git `24e860f6d3` (2026-10-13) are recaptured.
Source URLs, versions, timings and limits are in
[Windows facts](product/research/FFMPEG_WINDOWS.md). 255 measured mux/readback/
decode cases and 184 native-generated mode/depth/profile plans replace or qualify
the bootstrap rules. Windows help is embedded; compatibility uses sampled
libavformat 59/63 tables and conservative consensus for unknown versions.
X264 depth/profile and AMF mappings are corrected, current-build-incompatible
input queue flags are omitted, and Extra tokens expose `replacedField`.
B1 final checks (2026-10-14) are complete and ready for owner merge: 2,937 native checks (also ASan),
191 checks per native-asset/explicit-DLL/AOT route, 180 parser/catalog/identity/refusal regressions
and retained package/fixture checks pass. All three builds pass 60-frame
fractional-rate lossless pixel/audio parity and H.264/AAC FFprobe checks. Basic
input/output color tags preserve pixel samples under the chosen tagging policy;
actual VEGAS source color metadata remains unqualified.
No installed engine/adapter changes or new VEGAS evidence. Full-capability FFI
transfer still exceeds the 4 ms editing budget; B3/F7 must reduce/cache it and
measure app frames. Core-argv named-pipe timing/memory checks remain B4.

**B2 validation:** MSVC x64 `/W4 /WX`; 2,900 native checks, also under AddressSanitizer;
171 real-FFI checks per native-asset, explicit-DLL and bundled-AOT route. Warm
end-to-end compile mean about 0.6–0.95 ms for 500-call samples. Both packages analyze
cleanly; 173 core-fake, 57 service-fake and 281 fixture checks plus ABI layout checks
pass. Native-generated argv also pass 60-frame fractional-rate synthetic FFV1/PCM
and H.264/AAC encodes/FFprobe checks with existing gyan FFmpeg 5.1.2; lossless checks
compare all ten meaningful P010 sample bits and exact PCM float bytes. **Offline
files/real core, no new fake-host or real VEGAS test.** No installed DLL changed.
See [platform handoff](product/workstreams/platform.md) for limits and app wiring.

**B0 app review additions (Windows x64):** master including B0 and F0/F1 is merged
into ws/platform. Contract v1 now includes token field provenance/issue display
indexes, per-stream signal facts, a main host HWND in live status, and app UI state
in machine.json. Models and existing fakes/fixtures expose them. Both packages
analyze cleanly; 170 core, 57 service and 281 fixture checks pass, plus C/C++17 ABI
header compilation x64 `/W4 /WX`. **Fakes/offline only; no new real VEGAS evidence.**
Owner-approved architecture/settings reconciliation is applied. See the
[platform handoff](product/workstreams/platform.md).

**B0 checks (Windows x64):** both pure Dart packages analyze cleanly; 95 core,
40 service and 163 fixture structure/bounds checks pass using fakes/design data.
C/C++ draft-header checks and default/opt-in native builds pass MSVC `/W4 /WX`.
Existing 24 helper, 9 boundary, 67 configuration checks, default fake-host suite,
11-case/20-render proof/recovery suite and fake-tree installer tests pass with
gyan FFmpeg 5.1.2. This is offline/fake-host validation, not a new real VEGAS test.

**Next:** B2 is merged into master (`bbcbe91`). B1 and B3 are ready for owner review;
the owner authorized committing/merging B3/B4 from ws/platform. Next platform work is B5
status-line analysis and gated B6 adapter/monitor integration with the owner.
App F7 wires the real providers and measures its budgets. Approved B1 downloads stay
in this worktree's ignored build/; existing `C:\ffmpeg` gyan 5.1.2 is untouched.
No installation or PATH change. Workstream split:
[docs/product/WORKSTREAMS.md](product/WORKSTREAMS.md).

**Scope boundary:** product work is now authorized on ws/app and ws/platform.
The owner authorized this B3/B4 commit/master merge; push and installation remain separate. The deferred real
two-template/restart test and controlled real failure recovery remain qualification
limits; core/fake/offline tests do not pass A5–A7. No installed DLL or rollback backup changed.

First real Vegas Encoder render passes decoded checks: 182 1080p frames at
30000/1001 and 291,491 float32 stereo sample frames, S_OK/encoder exit zero,
published output and zero outstanding locks. Duration difference is about 0.004 ms.
This baseline is one real-footage render; broader repeat/cancel/recovery/error
and saved-template persistence checks remain pending. The process log is complete; the earlier temporary zero
length does not establish a logging fault.

Legacy FFmpeg Bridge is uninstalled with a restorable copy under
`build/retired-ffbridge-2026-10-11/`. Vegas Encoder, FFmpeg, host and other configs
are unchanged. The **xhigh** configuration agent completed the ownership bridge
and a separate `0.1.0-config-proof` build with 60 passing configuration checks; see
[next-agent handoff](NEXT_AGENT.md). Development uses lightweight status/test
summaries per AGENTS.md, without a mandatory investigation ledger.

The default build still exposes zero pages. The now-installed opt-in proof DLL
exposes one temporary checkbox; its value adds an optional `configuration_proof`
section to the render sidecar. Exact-build native ownership is resolved from
existing code. Both build modes pass `/W4 /WX`; the corrected proof passes 67
configuration, 24 helper and 9 boundary checks. Fake-host on/off saved settings survive Create without
fresh conformance, repeat renders, cancellation and encoder failure. See
[configuration proof and manual test](NATIVE_CONFIGURATION.md).

The first real proof-page attempt showed a tab with an empty body. The dialog
was never shown during Activate, while the measured VEGAS container does not
issue a separate Show call there. The corrected `0.1.1-config-proof` shows it
after successful creation/positioning. Three visibility regression checks fail
before the fix and pass afterward; inset layout, Hide/Show and Move are covered.
The fake-host on/off/save/reload/repeat/cancel/failure suite also passes again at
`build/test-results/configuration-proof-visibility-fix/`.

The user's real `diagnostic_on.mkv` / `diagnostic_off.mkv` renders in
`C:/Users/Samuel Tee/Desktop/test_video/` now verify that the setting reaches
Render on the corrected installed build and VEGAS 2026.0.3.189 (same PID 6692).
Only the on sidecar contains `configuration_proof: {extra_report: true,
proof_version: 1}`; the off sidecar omits it. Both report S_OK, encoder exit zero,
publication, 182 frames, 291,491 audio sample frames and zero outstanding locks.
Both deliberately produce the same three file types; the checkbox adds a JSON
section, not a separate file. These reports were inspected without decoding
these new media files. Save/reopen/restart, independent templates, unapplied
Cancel and render cancel/failure recovery remain unverified.

Foundation closeout now fixes the encoded path's progress-error classification:
only the recorded `0x8004E00C` cancellation code maps to user cancellation.
Other failed progress calls remain failures with their original HRESULT, including
poll failures during video/audio Submit and finalization. The regression reproduced
access denied incorrectly returning render-cancel before the fix. Raw diagnostic
mode retains its narrower inherited error behavior.

Candidate `build/candidate-0.1.2-config-proof/` is built and preserved, DLL
`CA876E05CA4ED6D8A2A84529A573577716CEA650B74384D7B9ED19F4D578EA45`;
it is now installed with the user's explicit approval and matching DLL/PDB/INI/
discovery manifest. Default source version is `0.1.1-dev`. The prior working
`0.1.1-config-proof` installation is preserved in
`build/rollback-before-foundation-closeout/`, with restoration instructions.
Host/sharedk/FFmpeg and other discovery configs are verified unchanged.
This candidate now passes the user's real cancel/recovery check below. Automated checks cover
same-loaded-DLL stop/recovery after cancellation, failures in both progress slots,
video/audio submission, finalization and existing-destination refusal; stopped
jobs leave no owned child/partial or published output, and recovered outputs
are decoded against the synthetic fixture. Audio submission is gated on the
fake audio-read counter and phase counters are asserted, so queue repolls cannot
silently move the failure into another phase. Real-host cancel/error recovery
remains the final qualification task; this is implementation readiness, not a
claim that every real-host gate passed. Both build modes pass `/W4 /WX`; 67
configuration, 24 helper and 9 boundary checks pass. The focused proof suite passes
11 cases / 20 render attempts with seven stop/recovery pairs, under
`build/test-results/foundation-recovery-qualified-phases/`. The default-build
baseline suite passes under `build/test-results/foundation-baseline-final/`.

The real `foundation_cancel.mkv` / `foundation_recovery.mkv` check passes on
`0.1.2-config-proof` / VEGAS 2026.0.3.189 in one session (PID 40788, renders 1/2).
Cancellation returns `0x8004E017` from host progress `0x8004E00C`, after 175 of
1,293 planned frames. No completed MKV or partial file remains; the owned encoder
has exited and host locks are zero. The next render returns S_OK, encoder exit
zero and publication with zero locks. Decoded checks confirm 299 1080p frames
at 30000/1001, 478,878 float32 stereo sample frames at 48 kHz, presentation
timing and complete byte counts. Audio/video duration difference is about 0.008 ms.
Output checks are in `build/test-results/real-foundation-recovery-final/`.
This is real footage, not a counter/click fixture or same-run raw-byte comparison.
Elapsed cancelled-render time is not a measured cancel-button response deadline.
No new controlled-failure report was found; real failure/recovery remains unverified,
with automated early-exit/progress/destination failure and recovery checks passing.

Previous real-tested candidate: `build/candidate-0.1.1-config-proof/`, DLL
`A644B62650B729918EAEF54DBCE24F488F6280753DE283BE645199862BB13FD8`.
The earlier `0.1.0-config-proof` installation is
backed up in `build/rollback-before-page-visibility-fix/`; its candidate remains
preserved. The working 0.1.0-dev installation is backed up in
`build/rollback-before-configuration-proof/` and its preserved candidate is intact.
Host/sharedk/FFmpeg and other discovery configs are unchanged. Actual VEGAS
Apply/Cancel/save/restart behavior and proof-build render recovery remain open.

## Installation

The original 0.1.0-dev candidate's installation and first real render are verified.
It has been reversibly updated to 0.1.2-config-proof for the final recovery check.
All four candidates are preserved. With VEGAS closed, restore the prior working
proof with `-Update -BuildDir build/rollback-before-foundation-closeout`, or the
original baseline with `-Update -BuildDir build/rollback-before-configuration-proof`.

## Implemented baseline

- User-created independent Git repo at `L:/repos/vegas-encoder`; named Vegas Encoder.
- Authored source imported from the ffbridge 0.2.0 working tree with SHA-256 source
  identities, import map and distinct filter/type/preset GUIDs.
- Internal ABI, checked template/frame-lease helpers, adapter, encoder and diagnostics.
- Product-native build scripts and test host; engine's diagnostic header has no
  indirect dependency on VEGAS interfaces.
- Synthetic project-template generation, raw/decoded fixture checkers, product
  FFmpeg test runner and conservative reversible installer/fake-tree tests.
- Native exception containment and best-effort scoped-lock diagnostics hardening.

Validation: x64 /W4 /WX builds; 24 host-helper and 9 boundary checks; generated FFmpeg suite including 1080p; raw-checker and fake-installer tests; independent source-copy build all pass. Exact final DLL SHA-256 is 9FE5587A49F7A65AE3DC62DBB54D6B4AB392B67447D1D21C9DDC307325EEF5B2.

Validation results are recorded in the [bootstrap experiment](experiments/2026-10-10-bootstrap.md)
and ignored evidence. The source/research import is documented in [ORIGIN.md](../ORIGIN.md).

## Gate state

| Gate | State |
| --- | --- |
| A0 real-host baseline qualification | Pending broader ffbridge repeat/cancel/error observations; short fixture proof F-050 plus real 1080p/fractional/cancel evidence F-052 |
| A1 independent product import/build | Implemented; generated fake-host tests are self-contained |
| A2 internal host helpers | Template/lease separation and targeted checks implemented; further stream/allocator extraction and real-host qualification remain |
| A3 adapter/engine boundary | Internal dependencies and owned-buffer transport retained; broader job/settings and cancellation hardening remain |
| A4 Vegas Encoder real-host parity | Normal 1080p/fractional, same-session on/off and current-build cancel/recovery pass; controlled failure/recovery and counter fixture qualification remain open |
| A5/A6 native page and saved-setting proof | Real popup Apply and distinct template renders work; owner confirms saved templates persist across restart and reports the 0.1.7 foreground-return fix works. Detailed focus variants and full qualification remain open |
| A7 versioned recipe snapshots | Implemented in the opt-in B6 candidate; tested recipes render independently and persist per owner. Maximum native payload capacity and broader qualification remain open |
| A8 foundation qualification | Foundation normal/cancel/recovery evidence retained; B6 normal recipe rendering/startup, owner-confirmed persistence and reported 0.1.7 focus fix added. Detailed focus variants, controlled failure, capacity, monitor overhead and broader support matrix remain qualification limits |

## Limits

The [adapter data-flow explanation](ADAPTER_DATA_FLOW.md) describes raw host
media, the P010/FFV1/MKV stages, buffer ownership and input-format evidence limits.
The explanation distinguishes imported observations from qualified product behavior.

Fixed lossless MKV profile only. P010/square-pixel/supported constant rates, optional
48 kHz float32 stereo. No general HDR/color/alpha, hardware encode, audio-only encode,
arbitrary codec/container or VEGAS-version guarantee. Color metadata is not qualified.
Raw mode remains a research-style diagnostic path with narrower defensive guarantees.

Host calls stay on the Render caller thread; no simultaneous-render/thread-safety
claim. The installed candidate corrects encoded progress failure classification;
real cancellation/recovery passes, while other progress failure codes and controlled
error recovery are only fake-host tested. Formally bounded Abort completion under
stalled clients remains a hardening question. The proof runner models
cancellation but does not establish real-host cancel while a pipe is stalled.

Installed INI edits cause conservative hash-drift refusal during update/uninstall.
User-supplied FFmpeg remains a machine preference; no binaries are distributed.
Vegas Encoder is installed; the historical ffbridge exporter is removed with a
rollback backup. The external FFmpeg encoder, host and other exporters are unchanged.

## Source checkpoint

The user requested a local commit of all current foundation source/documentation:
native configuration ownership/page/draft, saved-byte proof, visibility fix,
progress error handling, build/test harnesses and updated qualification/handoff
notes. Generated builds, decoded test output, rollback payloads and media remain
ignored. This implementation checkpoint does not claim that deferred or outstanding
runtime checks passed. Earlier checkpoints are documented in
[checkpoint note](experiments/2026-10-10-implementation-checkpoint.md).

## Product planning (2026-10-11)

The product-layer plan and design exploration for review are in
[product/README.md](product/README.md):

- specification, architecture, recipe and command rules, FFmpeg integration, UI
  behaviour, roadmap and research notes;
- eight interactive HTML design directions with screenshots and a review.

Supporting work:

- 226 real FFmpeg 8.1.3 test muxes and FFmpeg help/probe captures, in ignored
  `evidence/2026-10-11-product-design/`;
- a prototype command compiler/validator used by the mockups.

Documentation and mockups only: no product code, no Windows build, and **no real
VEGAS test ran**. Gate state is unchanged. See the
[experiment note](experiments/2026-10-11-product-design.md).

## Next task

Continue in `L:\repos\vegas-encoder` on `master` with one agent
owning both app and platform. Follow the single ordered queue in
[NEXT_AGENT.md](NEXT_AGENT.md), starting with selected-file preset import.
The owner's deferred trial/recovery checks and recorded qualification limits
above remain unchanged. Installer implementation/testing and release signoff
remain; do not reopen deferred tests or duplicate completed core/service work.
