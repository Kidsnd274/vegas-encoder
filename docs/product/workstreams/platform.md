# Platform workstream

Updated: 2026-10-15 (Asia/Singapore). Worktree `L:\repos\vegas-encoder-platform`,
branch `ws/platform`. **B6 template recipes work in the owner's 0.1.5 renders;
the owner confirms improved editor startup with installed 0.1.6.** B1–B4 and app F4 are merged. Continued
from `659fe02`; F3 master `0be99dc` was fast-forwarded before the B1 commit.
B2 is already merged (`bbcbe91`).
The app owns its NativeVeCore/provider switches and UI mapping. WindowsServices
now composes the real C3 providers without implicit scans/probes/writes.

## 0.1.7 close handoff fixed offline; owner qualification and B7 inputs

Continued from clean `ws/platform` checkpoint **6dd7833**, rechecked as a
handoff-only commit. Main checkout's untracked `.claude/` is preserved. The owner
explicitly authorized the narrow frontend runner/test exception for this task;
other app paths and the app handoff remain untouched.

`Win32Window::MessageHandler(WM_CLOSE)` now captures foreground **before** enabling
the valid original owner, enables it, and calls `SetForegroundWindow(owner_)`
before destruction only for a foreground close. Flutter's accepted-close routing
is unchanged; rejected/discard-confirmation paths do not reach this handoff.
Background close stays passive. Native crash/teardown fallback, the parallel
startup worker and all Render caller-thread/frame-release/no-app-wait rules remain.

The same existing window probe now has `-Checks close`, exercising actual Apply
clicks and Cancel/Escape against a fake owner/full-screen other window, without
a native page poll/post-exit activation masking the result. Preserved old frontend
0.1.5+1: **3/7 passed**, with accepted normal and before-open Apply/Cancel returning
to another window; switch-back happened to pass that run. New frontend: **7/7
passed**, including both switch sequences and background WM_CLOSE/Cancel. All
foreground prerequisites were established in these compared runs. This supports
the suspected close-time gap; **real VEGAS focus confirmation remains pending**.
Interactive probe prerequisites are intermittent: the final repeat passed four
cases and could not establish foreground for three (no close attempted in those
three). Those are unverified attempts, not additional focus passes or product
close failures; the probe exits nonzero. Owner should run the real repro with an
idle desktop. The complete seven-case comparison above is the accepted valid run.
Observed same-DPI process-age `shown` marks: **435.7–462.7 ms**. Existing owner
placement/modality/minimize/restore and crash fallback checks also pass, including
other-DPI placement (centre within 4 px, shown 667–776 ms). No renderer/startup
architecture change or new process/thread investigation.

Validation: release frontend build **0.1.7+1**, clean Flutter analysis, **44** popup
widget/light+dark golden tests, optimized native build, **162** snapshots, **95**
transport/task, **107** native-page/owner, **19** C7 runtime checks and existing
writer monitor-launch/two-Hz checks pass. The staged native DLL's discovery check
passes with balanced fake-host allocations. These use fakes/fake windows/files,
not real VEGAS. Background crash focus is still handled by native fallback;
the runner cannot re-enable an owner after it is killed.
The full existing Flutter suite also passes **553** checks. B7's final focused
packaging/detection suite passes **65** checks, and the retained fake-installer
install/update/uninstall/refusal suite passes. The deliberate nonexistent filter
was accepted by the current core and separately rejected by the supplied FFmpeg
without publishing media; that prepares the owner step, not real recovery proof.

Matched **0.1.7-recipe-proof / app 0.1.7+1** is prepared separately at
`build/b6-candidate-0.1.7`, not installed. Native preflight now requires 0.1.7.1.
The candidate copies the old trial data and preserves exact installed 0.1.6
DLL/PDB/INI/manifest/discovery rollback with hashes. Old candidates, backups and
installed files are unchanged. [B6_TRIAL.md](../../B6_TRIAL.md) has focused owner
focus, controlled cancellation/encoder-failure recovery, bounded capacity and
six-run on/off monitor instructions. The toggle is in the separate desktop app;
the 0.1.6 launcher default is retained, so pass the new CandidateRoot explicitly.
Four capacity presets are prepared/round-tripped through existing core/repository
code and seeded into the **copied** trial library only. No host capacity claim.

B7 preparation: `Prepare-B7.ps1` stages the full runtime/notices, native files,
renderable INI/discovery inputs and a complete file/version/hash manifest.
Native now has PE version metadata (0.1.7.1 for this candidate). Read-only registry/
PE discovery identifies 2026.0.3.189 and older 13/21/22/23 installs; older hosts
remain detection only. Focused bundle/detection/refusal checks and the existing
installer's fake-tree suite pass. `dumpbin` confirms runner VC++ runtime imports;
none was downloaded/executed. [B7_INSTALLER_INPUTS.md](../../B7_INSTALLER_INPUTS.md)
specifies shared/per-host destinations, closure, manifests, all-target update,
durable rollback and preservation rules for the owner's Inno Setup implementation.
No Inno installer or release qualification is claimed. A5–A7 capacity/recovery/
overhead limits remain explicit; normal saved-template persistence is confirmed.

## Prior owner feedback and close-handoff request (superseded offline above)

The owner confirms saved templates persist across restarts on the installed
0.1.6 trial. Combined with the prior distinct FFV1/libx264 renders, normal recipe
persistence is owner-confirmed for the tested templates. Do not keep requesting
that same basic restart check. Maximum private-payload capacity, controlled real
cancellation/failure recovery and measured monitor overhead remain unqualified;
this feedback does not fully pass A5–A7.

**Needs app:** foreground return remains faulty. Repro: open the template editor,
switch to another full-screen app, return via VEGAS to the editor, then Apply.
The previous app reappears; the owner described this as minimization, but actual
iconic state has not been established. Also test the variant where the other app
was foreground before opening the editor, as the reported ordering is ambiguous.
In `app/windows/runner/win32_window.cpp`, `Win32Window::MessageHandler` currently
only calls `EnableWindow(owner_, TRUE)` in `WM_CLOSE`, then destroys the editor.
The native 100 ms poll samples foreground ownership and attempts activation only
after child exit; it cannot reliably prevent the close-time activation choice,
and Windows may deny a later foreground request. This is a code-based suspected
handoff gap, not a reproduced real-host root-cause proof.

Requested small app fix: in the accepted `WM_CLOSE` path capture whether the
editor HWND is foreground **before** re-enabling its owner, then re-enable the
valid original owner and explicitly `SetForegroundWindow(owner_)` **before**
destroying the editor when that captured condition is true. Background closure
must only re-enable, without raising VEGAS over the user's current app. Keep
cancelled/rejected Flutter close requests open, do not alter recipe/session
semantics, and do not change Render. Keep native fallback for crash/teardown.
Test foreground Apply/Cancel after switching away/back, normal foreground close,
and background close while another app stays foreground, including a maximized
or full-screen other window. Frontend code remains unchanged under the path split.

Documentation checked with the current Windows [EnableWindow](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-enablewindow)
and [SetForegroundWindow](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setforegroundwindow)
rules. Context7 resolution returned UWP/WinRT/binding results, without an appropriate
Win32 conceptual reference, so those direct Microsoft primary references were used.

Monitor performance needs no new harness: trial Settings already has **Show a
progress window during renders**, and C6 `elapsedSec`/phase timings already record
each render. [B6_TRIAL.md](../../B6_TRIAL.md) now gives an alternating three-on /
three-off comparison with fresh filenames and the same project/template/range.
No real performance claim or new test run follows from this documentation-only
checkpoint; native close behavior was inspected, not changed or fixed here.

## 0.1.6 real-host startup confirmation

The owner installed 0.1.6-recipe-proof on VEGAS 2026.0.3.189 and reports opening
is "a lot better now". Three frontend process-age traces reach `shown` at
**748.6 / 533.3 / 526.8 ms**. Native CreateProcess durations are
**153.1 / 32.8 / 31.8 ms**; UI request/scheduling takes **3.7 / 0.4 / 0.4 ms**.
These measurements cover three observed launches, not a general performance
guarantee; process-age and native launch intervals overlap and must not be added
as an exact click-to-visible time.

The normal B6 edit/Apply/template-recipe/render/progress flow is implemented and
has real-host smoke evidence. Explicit Apply/minimize confirmation remains open;
the startup feedback alone does not establish that focus regression passed.
Next work is a bounded real-host qualification pass for two-template restart
persistence/capacity, controlled cancellation/failure recovery and monitor
overhead. A5–A7 remain unverified. No additional feature scaffolding is needed
for this startup fix. Documentation-only recording of the owner result; checked
against native version/launch logs and frontend startup traces, with no code/test
or installation changes in this checkpoint.

## 0.1.5 template confirmation and 0.1.6 parallel launch/owner return

Owner reports that two separate templates now render with different intended
codecs and the template corruption/request bugs appear solved. C6 confirms FFV1
and libx264 success on VEGAS 2026.0.3.189, sampled readbacks **0.719 s / 0.187 s**.
Keep full A5–A7, restart/capacity, controlled failure recovery and monitor overhead
unverified; this is additional successful recipe-render evidence.

The remaining report is intermittent ~6 s editor opening (some instant), plus
VEGAS minimizing on popup Apply. The 0.1.5 native log captures **12,367.6 / 7,029.2 /
7,893.1 ms** in its spawn section, versus about **33–37 ms** on fast launches.
Preflight is 2–3 ms and files/validation 6–8 ms. The section creates/assigns/resumes
a suspended process. That localizes the spike to native launch but does not
separate creation from resume or child work overlapping resume. The unchanged
runner already defaults to **Skia**, not Impeller; a shader cause is not established.
The exact variable operation remains open pending the new per-call/first-frame data.

Implemented **0.1.6-recipe-proof**, bundled with the unchanged **0.1.5+1 frontend**:
`EditorSessionTask` copies C4/path/argv values and owns the existing transport on
one independent worker. File/process setup runs in parallel with VEGAS's UI,
without UI message pumping, joins, host/draft/allocator/window access on the
worker, or a new launch-cancel UI. Page lifetime and late startup remain safe via
owned task state, existing child job ownership and a retained DLL reference.
Result validation/draft/native Apply and all window calls stay on the page thread.
The goal is actual click-to-visible speed; moving the wait alone is **not** claimed
to remove the OS delay. The owner retest above records the observed improvement.

Owner return now follows explicit `GW_OWNER` links, because `GA_ROOTOWNER` can
stop at an owned `WS_OVERLAPPED` window (reproduced in the window regression).
Normal Apply/Cancel from the foreground editor restores an iconic host and its
settings dialog before returning focus. Background/crashed completion only
re-enables the original owner. This guards the minimize/activation symptom;
the exact real-host trigger and fix remain pending owner verification. The native
code never minimizes a host. Frontend WM_CLOSE currently also re-enables its owner;
app-owned close behavior should be reviewed if the symptom remains.

Launch timings now split job setup, CreateProcess and ownership/resume. The trial
launcher enables the existing frontend startup trace (by PID) at
`logs/frontend-startup.txt`, allowing process launch versus first frame to be
separated without a debugger. No shader/backend switch, AV exclusion, machine
tool change or old process/thread debugging workflow was introduced.

Validation: optimized DLL build; **162 snapshot**, **95 transport/parallel task**,
**107 native-page/owner-window** checks; **19 C7 runtime** and monitor cadence
checks pass. Task tests hold startup deliberately, prove scheduling/polling return,
owned result/cleanup and late-page-lifetime safety; normal/failure/repeated Apply
preservation tests remain. Owner-window tests retain an iconic host on background
completion and restore its explicit owner chain on foreground return. These are
fake child/window tests, not a real VEGAS latency/focus pass.

Staged `build/b6-candidate-0.1.6` with a copied 0.1.5 data root and exact installed
0.1.5 rollback. Preparation did not install, push or merge master; the owner later
installed it for the retest above. Existing working 0.1.5 templates
remain compatible; do not repeat the codec trials just to prove them again.
Opening has now been retested; explicit confirmation that Apply leaves VEGAS
restored remains pending. See [B6_TRIAL.md](../../B6_TRIAL.md).

App handoff if native launch remains slow after parallelizing: prioritize a reusable
editor process/engine or an out-of-process launch path that avoids repeated cold
process creation. That requires app-owned lifecycle/C4 dispatch work; changing
shaders or frontend controls is not justified by the current native-launch data. No
frontend files were edited here, in keeping with workstream ownership.

## First real B6 feedback and 0.1.5 fix candidate

The owner installed **0.1.4-recipe-proof** and tried popup edits/save/restart and a
render. Screenshots show Chinese-looking/byte-shifted names and notes, native/popup
name disagreement and intermittent “Invalid edit-session request/context”. One
successful real render produced C6 job `B5941A06-6823-4AC5-B19F-FF900E22F509`:
VEGAS **2026.0.3.189**, supplied gyan FFmpeg **5.1.2**, FFV1/PCM float, 182 frames,
1920×1080 P010/29.97 input, final publication and passed readback. The owner reports
the monitor works, with slow updates and Open Folder incorrectly opening Documents.
This is real smoke evidence only. Apply/Cancel/persistence and performance gates
are **not** passed; the trial found failures rather than qualifying them.

Fixes staged as **0.1.5-recipe-proof / frontend 0.1.5+1**, with no frontend source
edits. The old candidate/data, saved native templates and installed 0.1.4 files are
preserved; the new candidate has its own copied trial data and exact 0.1.4 rollback.

- Native payload placement now rounds odd private allocations to even and places
  at most one zero byte outside the core VEnc envelope. Real logs show `cbExtra=559`;
  a wchar-indexed regression reproduces the old mismatch and new aligned behavior.
  Core length/checksum validation stays strict, arbitrary padding is refused,
  intact old odd envelopes remain readable, and suffix/unknown bytes are preserved.
  Names/notes already damaged cannot be reconstructed; retest with fresh built-in
  templates and new saved names. Historical id-0 hiding is already present and
  is unchanged; no speculative index/GUID reassignment.
- Invalid C4 requests identify the exact core issue/field instead of a generic
  context message. The name corruption is a plausible cause of intermittent empty
  templateName, but that connection requires real retest rather than an assumed fix.
- Open Folder now passes Explorer `['/select,', path]`. The previous combined token
  was quoted by Dart when the path contained spaces, causing Explorer to ignore
  it and open Documents. Actual Explorer reproduced both failure and corrected
  target selection in isolated test files; those windows were closed.
- The writer wakes for pending idle metrics when its two-Hz budget is free, with
  phase updates immediate. It no longer adds a periodic half-second idle wait.
  Existing coalescing/nonblocking Render rules remain.
- The owner's 2.140 s encode spent another **9.015 s verifying**. The old probe
  decoded every output frame to establish only a positive frame count. New
  `-read_intervals %+#32` bounds the sample, retaining all stream metadata, a
  positive decoded count for every video, kind/count/known-codec checks and all
  cancellation/timeout/diagnostic/publication guards. Read-only comparison on that
  output: **9.897 s → 0.743 s**. It samples readability; corruption later in the
  file is not scanned. Full decode qualification remains separate. CLI semantics
  checked against [official FFprobe docs](https://ffmpeg.org/ffprobe.html#Main-options).

Popup startup: the owner observes about three seconds; this remains unresolved.
The native page now paints its status child with “Starting the editor...” before
startup and records preflight/files/spawn durations in the existing log. Launch
still has synchronous OS/file setup on the native UI thread. Replacing it with an
async state/lifetime mechanism without latency evidence would expand scope and
risk cancellation/teardown. Next real click will distinguish native startup from
the helper's first frame. App handoff: use the existing startup trace when native
setup is fast; do not count sample previews as established project facts. No new
debugger, sanitizer, AV exclusions or process/thread investigation was used.

Validation: optimized candidate builds; **162 snapshot/host-text** regressions,
**87 transport**, **102 native-page**, **19 C7 runtime**, writer monitor/cadence
checks, **94 adapter checks / 9 fake-host real-FFmpeg cases**, and **24,502 engine
checks / 23 fake-host/real-FFmpeg + controlled-child cases** pass. The engine adds
an actual owned probe-child test that requires the bounded interval and all-stream
view, plus malformed/absent/zero sample-count regressions; cancellation/error/
timeout/destination/recovery cases retain their guards. **12 reveal service checks**
and targeted analysis pass; release frontend rebuild includes the corrected service.
The AOT repository runner passes **150** checks; package analysis is clean. The
actual staged DLL passes the existing fiohost discovery/conformance/render check
with 24 frames released, six matching allocator frees and `cbExtra=560`; its
UTF-16 preset name reads “Vegas Encoder settings (MKV)” at the aligned offset.

Owner retest and rollback commands: [B6_TRIAL.md](../../B6_TRIAL.md). Keep A5–A7,
real restart persistence/capacity, controlled real failure recovery and monitor
performance unverified. First retest: fresh built-in → two new names → reopen/
restart; render to a new filename and check Open Folder/terminal latency.

## B6 connected candidate ready for the owner's VEGAS trial (0.1.4 checkpoint)

The owner explicitly resumed B6 after clarifying that the antivirus restriction
came from earlier debugging/quarantined builds. Prepared the actual connection,
without resuming sanitizers, debugger/process/thread investigations, machine tool
changes or AV exclusions. Local milestone commits are authorized. No installation,
master merge or push occurred. Earlier B6 hold statements below are historical.

Opt-in `build.cmd "" recipe-proof` produces **0.1.4-recipe-proof**. Its fresh
**Vegas Encoder settings (MKV)** preset has distinct preset GUIDs and the core VEnc
recipe payload; proof bytes are never migrated. Existing holder/allocator storage
backs the native page. Queued UI-thread C4 launch, root-owner disable/restore,
timer polling, retryable native Apply and teardown preserve the prior template.
The complete existing frontend is rebuilt as **0.1.4+1**, with no frontend edits.

Create copies the recipe/origin; Render uses actual delivered media, selected C7
installation and the existing B4 engine. Host calls stay on Render's caller thread
and every frame is copied/released before settings reads, hashing or transport
waits. Unused audio is not read. Native C7/cache reads are bounded to 1 MiB; engine
identity checks remain authoritative. Cached hardware readiness stays unknown.
The existing job writer launches the monitor after atomic initial C5 publication,
with the app parent cwd and no Render wait/acknowledgement. Launch failure is nonfatal.

Additive C2 `outputContainerId` keeps output format decisions inside the core.
Advanced requires a known explicit final muxer; absent/input-only/unknown/general/
partially quoted output stays null. Candidate constraints check that fact and
established video output before spawn, with the same refusal on editor return.
This candidate deliberately supports the evidenced MKV/P010/square-pixel and
48 kHz stereo float input path. General Advanced/audio-only/non-MKV is refused.

Prepared `build/b6-candidate/{app,plugin,data,rollback}`. The data root has a real
C3-registered default `C:\ffmpeg\bin\ffmpeg.exe`, verification/progress enabled,
and no inferred capability qualification. The exact installed DLL/PDB/INI/manifest
and discovery file were copied before any installation; hashes are retained for
rollback verification. `Start-B6Trial.ps1` launches the app/VEGAS with process-local
isolated data and verifies the installed candidate DLL before VEGAS launch.
See [B6_TRIAL.md](../../B6_TRIAL.md) for the owner's steps and rollback command.

Validation: optimized native DLL build and **3,055 core** checks; real FFI **230**;
snapshot **95**, transport **87** (no optional junction fixture), page **102**,
C7 runtime **19**; actual adapter **94 checks / 9 fake-host real-FFmpeg cases**
(immutable Create, video-only, Cancel, host error, Advanced MKV, wrong/unknown muxer,
recovery and preserved existing destination). The staged DLL itself passes the
existing fiohost discovery/conformance/render test with production C7 selection,
balanced frames/allocator references and real FFmpeg. Monitor writer checks cover
initial publication, argv/cwd, stalled child independence and nonfatal refusal.
New trial preparation tool analysis and launcher syntax/refusal checks pass.

The actual staged frontend's existing window probe shows the primary popup owner,
centering, minimize/restore, Cancel result and owner re-enable paths working; the
monitor shows no-activate, remembered pin and placement on the named host monitor.
Secondary multi-monitor/crash foreground observations include NO results where
foreground acquisition prerequisites were also NO; they do not prove focus recovery.
App handoff: confirm secondary foreground behavior in the real host, and update the
stale comment in app/lib/state/services.dart saying the exporter ignores the trial
root (this opt-in candidate honors it). No frontend files changed here.

**Still unverified:** A5–A7, real native Apply/Cancel/save/restart and maximum payload
capacity, real render/cancellation, controlled real failure recovery, and the
three-with/three-without monitor performance comparison. Offline tests do not pass
these gates. Next: owner follows the short first-popup/two-template trial, then
render/Cancel. No more offline scaffolding or B5 custom-text investigation is queued.

## Selected-file preset import (completed service feature)

After F6 precision checkpoint **84de5f4**, added the app-requested
`PresetTransfer.importFrom(selectedPath, newId: ...)`. It reads a selected .vepreset
file through the existing 1 MiB bounded UTF-8/JSON reader and delegates to the
repository's native validation and create-only Save. Unknown data/origins survive,
the imported preset starts at revision 1 with the caller's new ID, and the source
is preserved. Missing/unreadable/oversized/malformed/future/invalid files and ID
collisions return the existing service errors without replacing a preset.
FakePresetTransfer accepts selected-file text fixtures and its captured exports,
with no file I/O. No new dependency or framework.

App handoff: enable the existing Import file action, use pickFile to select the path,
call presetTransfer.importFrom(path, newId: ...), then refresh/select the returned
preset just as Import share string does. This implements the missing service;
the menu remains app-owned and has not been changed here.

Validation: **150 repository checks** pass with real Windows files/locks and native
core validation; **86 fake-service checks** pass. Package analysis and diff checks
are clean. New cases cover Unicode selected paths, metadata/origin preservation,
create-only conflicts, source preservation, missing/directory/oversized/invalid
UTF-8/JSON/future/recipe/ID failures and fake export/import without I/O.
No FFmpeg, fake host or real VEGAS ran for this feature. B6 integration remains on
hold; installation, A5–A7, real persistence, controlled failure recovery and monitor
performance are unchanged.

## F6 C5 video precision follow-up (completed)

Continued after library checkpoint **b6811be** and integration **ea4d557**. Master
and ws/platform include the latest app 493f146; master was fast-forwarded under
the owner's authorization, with its .claude/ preserved. No push. The app-owned
precise unmatched-quote assertion and affected goldens are adopted in 493f146.

Additive C5 fields: `outputBitDepth` (`int?`) and
`pixelFormatConversionReducesPrecision` (`bool?`). RecipeJob publishes the native
core's encoder-input video precision after a valid compile, with a reduction only
when known input bits exceed output bits and conversion is established. Equal or
increased depth/layout-only conversion is false; filters or unknown input precision
leave the reduction unknown. No text/recipe/codec-name inference or encoded-file
precision claim. General Advanced source/output/map/codec scope, stream copy,
disabled/omitted video and unknown formats stay null. Initial/precompile failures
also stay null; known facts survive terminal phases. Existing Render scheduling,
frame release and asynchronous publication rules are unchanged.

A small core reflection correction prevents input-scoped Advanced options and
unsupported pixel-format stream selectors from masquerading as output facts.
Supported selectors are unscoped, `:v` and `:v:0`; absolute `:0` and more general
selectors remain unknown. A pixel-format option in Basic audio Extra can override
earlier video arguments, so that cross-row case also stays unknown. Arbitrary
`-filter:v` aliases mark conversion unknown, as `-vf` already does; unscoped filters
cannot inherit a preceding audio option's scope. Authored argv is preserved.
Current option-scope rules were
checked with Context7's FFmpeg documentation and the official
[FFmpeg options/stream specifiers](https://ffmpeg.org/ffmpeg.html#Options) and
[pixel-format option](https://ffmpeg.org/ffmpeg.html#Advanced-Video-options).

The model, copyWith, persistent reader, fake seed/publish validation and generated
live samples carry both fields. Older absent fields stay absent/unknown; explicit
null clears them. Readers/fakes reject invalid types or nonpositive depth and retain
the previous successful status. Samples remain design fixtures, not real render data.
App handoff: use these getters for the F6 header wire/pip, showing less when unknown.
No frontend files were edited; frontend adoption is app-owned. The owner now
authorizes local commits when a stage or feature is complete, including this F6
checkpoint on ws/platform. Gated B6 activation remains separate.

Validation: optimized DLL/static builds and **3,034 native core checks** pass,
including unchanged B1 argv goldens. **59** focused real-core C5 fact checks pass
without processes/a host; native-asset FFI **208**, service fake **79**, Windows
repository **131**, fixture structural/bounds **295** and selected app compatibility
**65** checks pass. The app checks cover service wiring, monitor display/widget and
Advanced editor (including the adopted precise quote range). Both packages analyze
cleanly; fixture generator --check and diff whitespace checks pass.

The existing optimized B4 suite passes **23,160 checks / 22 cases**, using the
supplied gyan 5.1.2 FFmpeg, synthetic fake-host streams and controlled children.
Its retained ownership, bounds, polling, cancellation/recovery, destination
preservation and nonfatal storage/publication cases pass. New assertions verify
nullable depth facts across live/terminal state and atomic C5 files. The Dart C5/C6
readback passes **279 checks / 21 native jobs**, including P010-to-8-bit reduction
and preserved 10-bit Basic/seeded Advanced cases. These are offline fake-host
checks, not a real VEGAS or monitor performance test. Reproduce with
`scripts/Test-CoreNative.cmd`, `build/b4-tests/recipe-jobs.exe --facts-only schema/fixtures/b0/core-and-services.json`,
`scripts/Test-B3Repositories.ps1` and `scripts/Test-B4.ps1` (without -Asan).
Compact engine output is under ignored build/test-results/b4-b34553b9.
No goldens were regenerated here.
No installed exporter, machine tool, antivirus setting or real VEGAS state changed.
**A5–A7, real persistence, controlled real failure recovery and monitor performance
remain unverified.** No sanitizer/process/thread debugging resumed.

## Merge and library-watch follow-up (2026-10-15)

The owner requested merging the reviewed checkpoint and continuing. Committed it
as **fa58338** on ws/platform, merged current master/app F6 d3b83ce on the workstream
as **9018965**, then fast-forwarded master to 9018965. No conflicts or push; master's
pre-existing untracked .claude/ is preserved. No frontend source was edited.

At 9018965, merged app integration used existing SDK/offline dependencies; app analysis passed and
**394 unit/widget tests passed, one failed**. The assertion was app-owned
advanced_editor_test.dart:299, named "an unterminated quote is about the whole
command: listed, not underlined". It expects wholeCommand=true, while the reviewed
C2 addition deliberately reports the unmatched quote's precise range. The app needed
to adopt that range/prefix contract in this test and its native light/dark goldens.
Do not restore the old whole-command diagnostic in core. **While this continuation
was validating, master advanced through app follow-ups 84acb66 to 493f146**, which
adopts the precise quote range and refreshes the affected native goldens. The request
above is satisfied by that app-owned commit, included in **ea4d557** alongside the
library-watch commit **b6811be**; master fast-forwarded to ea4d557. Generated runner files from
Flutter checks were restored; no app edits or SDK upgrade are retained.

**Library-watch checkpoint reviewed and finished:** the app's F7 library-watch
bottleneck. FilePresetLibrary now caches each current decoded preset and its native
requirements by file metadata, plus built-in requirements/preferences. Warm polls use
one bounded native Windows directory query in the existing ve_windows_services DLL
instead of 500 separate stats/reads/normalizations. An unchanged metadata result
reuses the exact immutable snapshot before Dart parsing/sorting, and watchSnapshots
skips serializing that same snapshot again. No new C3 interface or app adoption is
needed. Native metadata is read-only and synchronous; oversize/reparse-entry
fallback uses a short-lived isolate. There is no persistent watcher/worker or dispose
requirement. Handles and caller buffers are released on success/error/limit paths.

Changed files are validated independently; removed entries are evicted, built-in
star/pin changes still show, and failed reads/unsupported files emit errors while
retaining the last published snapshot. Own writes invalidate immediately; concurrent
lists share work and own-write races retry with a bound. get/CAS/Save remain disk
reads. Cache storage is one current revision per present file plus one metadata/list
snapshot, not per-poll/history accumulation. Metadata-preserving external rewrites
can evade this cache; explicit get/Save remain authoritative. Scope/limits are in C3.

Review fixed one error-parity edge: a directory named preferences.json must report
FILE-READ rather than becoming cached default preferences. Error/snapshot retention
and removal/recovery are covered. A deliberate same-size, timestamp-preserving
external edit also confirms that explicit get and Save/CAS bypass the list cache.

Validation: **99** focused Windows/native-asset library checks in JIT and AOT; **114** retained
Windows file/lock/native-core repository checks; **64** service fake checks; service
analysis clean; **10 app service-wiring tests pass** on the new implementation.
Focused checks include 500 real files, zero warm normalize calls, single-flight
lists, two/late listeners, same-size external edits, add/delete/re-add, preference
changes/removal, malformed/future files and repair, immutable snapshot reuse, ignored
entries, pause/cancel, own-write invalidation, Unicode/dot-segment paths, counted FFI
arguments and output guard bytes. Synthetic recipe records, no FFmpeg execution,
fake host or real VEGAS. No sanitizer or process/thread debugging resumed.

Measured with the existing Dart 3.13.5 / MSVC x64 native asset on this PC's workspace
volume, 500 presets (six built-ins + 494 files), 50 warm lists:

- JIT runs measured **1.77–3.21 ms median / 2.05–4.03 ms p95**. The final 93-check
  run was **3.206 / 4.030 ms**, max 4.204 ms; raw native enumeration median 1.414 ms.
  Continuation JIT: **1.827 / 2.286 ms**, cold **658 ms**, zero warm normalization calls.
  Its prior first full read was **1,081 ms** (earlier runs 592–641 ms). These are measured
  workspace-volume timings, not a universal filesystem latency guarantee.
- Continuation AOT: **1.866 ms median / 2.255 ms p95** (max 2.349 ms), first read **537 ms**.
  Cold loading still decodes every preset; this does not claim a cheap initial load.
- App's prior report was **430–470 ms every 250 ms**. The new repeated-list path makes
  **zero core normalization calls**; data changes alone trigger file reads/validation.

Reproduce: from packages/ve_services,
`dart run test/library_watch_test.dart`; the test builds a temporary 500-preset library
under ignored build/test-results, cleans it on completion, and writes the compact
library-watch-timings.json summary there. AOT was bundled at build/b3-library-watch.
No benchmark inserts timers into product code.

API source checks: Context7 resolution/docs returned no matching Win32 content;
verified directly against Microsoft's [FindFirstFileExW](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-findfirstfileexw),
[FindNextFileW](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-findnextfilew)
and [WIN32_FIND_DATAW](https://learn.microsoft.com/en-us/windows/win32/api/minwinbase/ns-minwinbase-win32_find_dataw)
references, plus the installed SDK's Native asset-id declaration for the focused
FFI test. Reuses the already-attributed MIT JSON header; no new dependency.

No installation, exporter replacement, machine-tool change or antivirus exclusion.
**A5–A7, real two-template/restart persistence, controlled real failure recovery and
monitor performance remain unverified.** Render threading/frame release/no-app-wait
rules remain unchanged. F6's synthetic window figures do not pass its VEGAS render
performance gate. Subsequent platform work: coordinate DesktopApp openPreset/openJob
with app, adopt the output-depth C5 facts above, then version checks/installer inputs under the owner's
recorded decisions. Gated B6 activation remains separate.

## Advanced capability reuse / F4 / popup size (reviewed checkpoint)

Continued on **ws/platform at `1e14d64`**, initially clean. Read the latest ws/app
handoff directly from its worktree (F5 done, F6 next); app.md in this worktree is
older and was not edited or merged. All changes remain platform-owned and
reviewed; the owner subsequently requested committing/merging this checkpoint
and continuing platform work. No app/runner files changed.

- **Capability-transfer bottleneck:** NativeVeCore now automatically stores and
  reuses immutable capability snapshots for validate/compile/lint/complete. No app
  call-site change is required. Identity is the actual immutable CoreCapabilities
  object, not the installation/binary key: lazy options and hardware facts may
  change independently. Native validation borrows the same snapshot into lint
  instead of copying it again. The native C++ compiler/validator remains sole
  authority; direct engine calls still use their own borrowed capabilities.
- **Bounded lifetime:** facade LRU retains four views (full Advanced plus compact
  Basic fit together), releasing old entries; DLL LRU retains eight, each <=1 MiB
  submitted JSON / 65,536 nodes / 64 levels. IDs never recycle within the DLL;
  release is idempotent, eviction yields CAPABILITIES-STALE, and Dart reinstalls
  exact facts with one retry. A synchronous caller pins its immutable snapshot
  without holding the registry mutex during work. Abandoned facades are bounded
  by native eviction; optional clearCapabilitiesCache releases early. Cache limits
  preserve legacy inline semantics. cacheCapabilities:false is the parity/timing
  baseline. No finalizer, host pointer, background thread or new process exists.
- **F4 metadata:** Advanced user tokens have stage, isOption, recognized macro
  identities and typed UTF-16 spans. Ambiguous unsuffixed options stay unknown;
  negative/quoted dash values remain values. Macro role retains separate stage,
  while owned input/output roles remain intact for existing chip guards. Shared
  native macro definitions supply completion, expansion and the new catalogue.
  VeCore.macros(media:...,paths:...,recipe:...) is additive through an optional
  interface/extension, with exact-context FakeVeCore fixtures. Pass the recipe for
  exact generated-input/audio policy; omitted recipe shows available media.
- **Encoder IDs / partial quotes:** summary videoEncoderId/audioEncoderId come
  from established scoped command facts; ambiguous maps/outputs/codec scope,
  nonzero stream selectors, copy, disabled streams and unfinished quotes stay
  null. Complete words/chips before an unfinished quote retain UTF-16 spans;
  L-QUOTE starts at the actual unmatched quote. Incomplete word is omitted;
  argv/commandLine are empty and Apply/render stays blocked.
- **C7 popup size:** optional AppUiState.popupWindowSize stores physical outer
  width/height (1..32768), no position/maximized state. Services/fake share bounds
  checks, preserve desktop/unknown fields and reject invalid writes atomically.
  Frontend owns adoption, clamping/centring and revision-conflict retry.

Focused verification (offline; no FFmpeg execution, fake host or real VEGAS):
**3,020 optimized native/static checks**, C/C++17 ABI header `/W4 /WX`, unchanged
B1 argv goldens; **208 native-asset Dart FFI** and **177 core fake** checks;
**64 service fake** and **114 real Windows file/lock/native-core repository**
checks. Both packages analyze cleanly. Existing repository runner uses synthetic
records/owned test children, without exporter/session changes. No sanitizer run
or process/thread investigation was resumed; the previous B6 sanitizer limitation
remains as recorded.

Timing: the existing capability_views_test.dart now compares inline/snapshot
validate/lint/compile/complete results and times a changing Advanced command's
lint + Advanced compile + Basic compile using all three **full real captured probe
maps** (156,163 / 236,118 / 234,172 bytes), with the same DLL/build and immutable
views. It separates first transfer from 25 warm-ups / 100 measured edits.
Isolated JIT run (Dart 3.13.5, optimized MSVC x64 native asset, Windows on this PC;
320x180/30 P010 + stereo float sample, no overlapping builds/tests):

| Full captured map | Inline median / p95 ms | Snapshot median / p95 ms | First snapshot edit ms |
| --- | --- | --- | --- |
| gyan 5.1.2, 156,163 bytes | 21.985 / 23.887 | **2.087 / 2.314** | 12.906 |
| gyan git 615b07170e, 236,118 bytes | 27.729 / 29.297 | **2.103 / 2.232** | 16.114 |
| BtbN git 24e860f6d3, 234,172 bytes | 27.048 / 28.758 | **2.081 / 2.142** | 15.814 |

Warm snapshot means are **2.091–2.132 ms**, below the 4 ms core-sequence budget;
first transfer is explicitly **12.9–16.1 ms**, outside that budget. Earlier runs
with overlapping builds had isolated >4 ms tails; the table is the final isolated
run, not a universal latency guarantee. The inline baseline uses this same build,
including the native-copy removal, rather than claiming an exact rerun of the
app's old 25–32 ms measurement. These are core/FFI sequence costs, not a qualified
Flutter frame/provider/UI budget; app owns its full F7 rerun.

Reproduce from packages/ve_services with the existing installed Dart:
`dart run test/capability_views_test.dart ../../build/test-results/b3-runtime-cc92c463`.
**73 real-map parity/reuse checks** pass. Output stays in ignored
`build/test-results/b3-runtime-cc92c463/snapshot-timings.json`; no probe executes.
Fake map timings are not substituted. Both native-asset and explicit-DLL FFI
paths pass the focused 208 checks.

App adoption: no changes for snapshot reuse; consume the F4 additions/catalogue
and C7 popup size in app-owned code/tests/goldens. Contracts spell out exact API,
identity, eviction/release and unknown facts. Temporary output naming remains
engine-owned; preview uses CompilePaths.output. DesktopApp.openPreset still needs
app launch/selection coordination. The latest app's library-watch cost request is now
implemented in the uncommitted follow-up above. Do not change invalid desktop save policy.

**A5–A7, real two-template/restart persistence, controlled real failure recovery
and monitor performance remain unverified.** No B6 activation, app/monitor launch,
installation, exporter replacement, commit/push, machine-tool change or antivirus
exclusion was performed. Render caller-thread host calls, copy/release-before-wait
and no wait for app/monitor remain unchanged.

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

The owner subsequently authorized B5 installation/observed testing and directed
**no routine rollback: retain a healthy candidate, rollback only for issues**.
Mode 0 was installed/hash-verified as `0.1.3-progress-text-proof`. Its real
normal render and full decode pass on VEGAS 2026.0.3.189, PID 38892: 182 1080p
frames at 30000/1001, 291,491 48 kHz float32 stereo sample frames, S_OK, encoder
exit zero/publication and zero locks; owner confirms steadily advancing progress.
The first mode-4 elevation request was cancelled before install; the owner
authorized retry, which succeeded with matching hashes. Mode 4 is installed and
VEGAS PID 30000 completed two normal text-test renders: each S_OK, encoder exit
zero/publication, 182 frames, 291,491 sample frames, zero locks and eight successful
guarded slot-4 calls. Final output full decode/count/timing checks pass. The owner
saw no switching text and explicitly drops custom dialog text in favour of useful
progress. Mode 4 remains installed; no rollback. This candidate's cancellation/
recovery and mode 3 were not tested. Installation records/checks:
`build/test-results/b5-host-trial-3cea0e12/`;
details in [NATIVE_PROGRESS.md](../../NATIVE_PROGRESS.md).

App handoff: ws/app now records real WindowsServices (F7) and refreshed native
goldens; merge platform checkpoints when needed. F5 popup and F6 live progress
consume the unchanged C4/C5 contracts, without declaring real-host gates.

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
  API ownership, transport limits and owner gate checklist:
  [NATIVE_RECIPE_BOUNDARY.md](../../NATIVE_RECIPE_BOUNDARY.md). B6 is not complete.
  C4 transport is described below. Next is the native page against the actual F5
  popup when ready and the owner resumes native gates, then recipe/C5 progress.
  App F5/F6 readiness must be coordinated here;
  do not modify its files. A5–A7, real persistence, controlled real failure
  recovery and monitor performance stay **unverified**.

## B6 C4 transport checkpoint (offline)

- `editor_session.*` validates bounded requests through core, creates a fresh UUID
  directory in an explicit existing local root, flushes/atomically publishes the
  request, and launches an explicit executable/argv with no shell or inherited
  handles. Suspended launch is assigned to a kill-on-close job before resume.
- Creator-thread zero-time process polling consumes at most one terminal result,
  after child exit. Stable bounded file reads reject missing, malformed, future,
  mismatched, busy, directory/reparse or hard-linked results. Nonzero exit or Cancel
  discards even a prewritten Apply; `RecipeTemplateDraft` still alone decides
  domain/capability/payload acceptance and host Apply remains a separate step.
- Root/ancestor/session pins reject reparse points and prevent directory rename,
  while allowing child request/result atomic publication. Direct known-file
  cleanup includes the real services' `.result.lock` and interrupted result temps;
  unknown entries are preserved and incomplete cleanup is reported. Teardown
  kills only the owned job, never waits, and can retain a diagnostic session while
  the child exits. The supplied root/unrelated files are never swept.
- Actual app, VEGAS, user state and installed exporter are untouched. There are
  **no discovery/page/Render call sites**. Start is synchronous local setup;
  scheduling/latency, real Flutter launch, HWND validation, owner disable/re-enable,
  graceful close, focus/modality, recipe rendering and monitor launch remain
  deferred to the next bridge work and real gates. No C2/C4/C5 shape changed.
- Focused runner: `Test-B6.ps1 -Asan`, real Windows files/processes with authored
  fake children only. Optimized x64 `/W4 /WX` passes **89 transport + 95 retained
  boundary checks**, including Unicode/quoted argv, redirected roots, atomic
  publication, early results, invalid/crashed helper results, cancellation,
  descendant/teardown ownership and steady-state handle balance. PowerShell AST
  and whitespace checks pass. Final normal output:
  `build/test-results/b6-transport-ba7427949d27474fbd0f0c91b327e731/`.
  **Current ASan validation is incomplete**: the existing boundary thread test
  stalled after 87 checks before the transport suite. Root cause is unknown.
  Owner reported an antivirus alert during thread/process debugging, stopped it,
  and directed continuing without further debugging. Temporary diagnostics/flag
  experiments are removed; no current sanitizer pass or false-positive claim.
  Results and remaining gate checklist:
  [NATIVE_RECIPE_BOUNDARY.md](../../NATIVE_RECIPE_BOUNDARY.md).

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

Next: stop B5 marker trials under the owner's decision below; continue the B6
offline transport work. B6 activation stays gated on A5–A7.
Real two-template/restart persistence, controlled real failure recovery and
monitor performance remain **unverified**. No monitor performance conclusion
follows from text markers or the existing B4 async-file checks.

## Owner progress preference / app coordination

The owner reviewed the real slot-4 trial and screenshot on 2026-10-14: no apparent
switching text, no need to change VEGAS's render dialog, and a request for somewhat
accurate progress. **Drop the custom status-line requirement**; retain ordinary
caller-thread numeric progress/cancellation. Retire probe calls in the next
reviewed normal exporter update, without another install/INI change for this
decision. The healthy candidate remains installed under the existing authorization.

The current fixed-profile adapter reports frames submitted to the encoder; encoding
and flushing can continue after that counter advances. Do not present that as
completed output or promise a precise remaining time. B4 already publishes actual
FFmpeg metrics and separate finishing/verifying/done phases asynchronously; B6
must connect those to rendering without making Render wait for readers or a window.
Completion remains successful encoder exit, required verification and publication.
Any native percentage adjustment needs a separate reviewed implementation and
real-host check; the screenshot alone does not establish an accurate ETA.

Read-only check of ws/app: F7's real-service wiring/budgets are delivered there;
F5 popup is next, F6 live monitor follows. `MonitorWindow` is currently a shell,
not a live progress display. App F6 should consume C5 through the existing service
reader, display measured encoding progress plus finishing/checking phases, and
keep ETA explicitly estimated/unavailable when insufficient. App owns its UI/tests.
Owner-owned TECH_ARCHITECTURE §5.6 / design decisions should reflect dropping
custom dialog text and prioritizing the separate window; this is the request for
those files, not an edit to them. A5–A7, real persistence, controlled failure
recovery and real monitor performance remain **unverified**.

## F4 core metadata coordination (delivered above; unchanged during B5)

The queued requests were implemented in this reviewed continuation; the table
retains their intent and scope. See the additive C2 contract and verification above.
App adopts the metadata/catalogue and refreshes its own light/dark goldens.

| Request | Platform handoff / next implementation |
| --- | --- |
| Advanced stage/macro roles and option/value marker | Add core-authored roles/marker while preserving UTF-16 source spans and argv. A macro word needs both macro identity and stage, so use additive metadata rather than losing its stage when role becomes `macro`. General/ambiguous scopes stay unknown. Cover quoted/expanded macros, stream specifiers and literal values starting with `-`. |
| Macro catalogue | Add a core API/C ABI plus Dart model for name, description, required flag and expanded value in the supplied media/paths context. Keep completion and expansion on the same C++ definitions; update fakes with the contract. No app-only macro expansion. |
| Advanced encoder IDs | Add optional native video/audio IDs where the active command establishes them. Preserve unknown for ambiguous/general output scopes; never read inactive Basic selections or reverse-map display labels. |
| Temporary output preview | C2 already takes `CompilePaths.output`; B4 passes its uniquely allocated temp path before core compile, and C6 records actual argv. Naming belongs to the engine, not portable compile. Keep the current selected/sample preview path explicitly labelled as a preview; no invented collision-free runtime filename in C2. Coordinate a services/context helper only if the owner wants an illustrative temp preview. |
| Partial highlighting with an open quote | Add trustworthy prefix spans/quote diagnostic position without treating an invalid command as renderable or emitting partial executable argv. Preserve UTF-16 offsets, macro guards and the error that blocks Apply/render. |

These additions now include focused core/FFI/fake tests and CONTRACTS updates.
App owns adoption/widget/light-dark goldens through its workstream. No C2 shape,
core compile semantics or app-owned source changed during B5 itself. Owner-owned TECH_ARCHITECTURE §5.6 can now link NATIVE_PROGRESS.md and
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

Continue in `L:\repos\vegas-encoder-platform` on `ws/platform`; recheck all relevant
git status/branches before editing. Preserve existing changes, the main checkout's
`.claude/`, staged candidates, trial data and rollback backups. Current B6 is active
by owner authorization and connected; earlier hold/offline-only statements are
historical. Do not repeat completed library-watch/F6/import or basic B6 wiring.

1. Owner retest of the prepared 0.1.7 close fix. The explicitly authorized narrow
   frontend change is complete offline above; do not redo it or broaden app scope.
   Retain passive background close, native crash recovery and startup improvement.
2. The owner could not find the progress toggle in VEGAS's template popup. It is
   in the separate desktop app: `Start-B6Trial.ps1 -Target App`, then Settings →
   Rendering → **Show a progress window during renders**. The literal label was
   verified in the staged 0.1.6 candidate's `app/data/app.so`, not only in source.
   No reinstall is needed to access it. Retain the isolated trial data launcher.
3. Finish bounded B6 qualification with the owner: focus repro, controlled real
   cancellation/failure recovery, maximum private-payload capacity and the existing
   three-on/three-off monitor comparison. Basic tested-template restart persistence
   is owner-confirmed; do not describe it as still deferred. Keep remaining gates
   open until their own real-host evidence exists.
4. B7 inputs are prepared above; owner implements/tests Inno Setup from the matched
   manifest and destination/update/rollback notes. Release signoff still depends on
   real-host qualification and the owner's runtime/license/deployment decisions.

Commit completed milestones locally on the authorized workstream branch. No push,
master merge, installed-exporter replacement, machine-tool change, AV exclusion,
sanitizer or old process/thread debugging workflow. Owner manually tests VEGAS and
installs prepared candidates. No additional status-line investigation or scaffolding.
