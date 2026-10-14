# Vegas Encoder status

Updated: 2026-10-14 (Asia/Singapore). Installed version: 0.1.2-config-proof.

## Current progress

**Product design (2026-10-12):** the `product-ui-design` branch is merged into master,
and the owner has reviewed it. Decisions are in
[docs/product/README.md](product/README.md#decisions): the Signal Flow direction
(round 2 mockup in `docs/product/design/signal-flow.html`), Basic/Advanced modes,
Flutter, Windows x64 only, a theme that follows Windows, no proof-template migration,
and render progress through a VEGAS status line (if a real-host test allows it) plus a
small progress window. The project license is still open. The platform B0 contracts,
draft recipe schema/C ABI and pure Dart packages with fakes are now implemented;
see [contracts](product/CONTRACTS.md) and [platform handoff](product/workstreams/platform.md).
The B2 native product core is now implemented below. Real services and adapter
integration remain later milestones; the VEGAS gates below are unchanged.

**B2 core/FFI (2026-10-13):** master through F2 (`ab7e7ab`) is in ws/platform.
The later F2 platform-fact/UI-state merge (`230c724`) is also incorporated.
Portable C++17 normalize/validate/compile/lint/complete/estimate/diff/payload and
pure session checks are implemented, with a Dart `NativeVeCore()` facade and native
asset hook, DLL/static builds, token/stream facts and the additive F2 result fields.
The app owns switching its fake provider after merge. B1 replaces the native
bootstrap profiles/options with qualified Windows data below; B0 fakes remain
historical design samples.

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

**Next:** B2 is merged into master (`bbcbe91`), and ws/platform is synchronized.
B1 Windows recapture is complete and ready for owner merge, then
B3 real services, including the remaining F2 requests. Approved B1 downloads stay
in this worktree's ignored build/; existing `C:\ffmpeg` gyan 5.1.2 is untouched.
No installation or PATH change. Workstream split:
[docs/product/WORKSTREAMS.md](product/WORKSTREAMS.md).

**Scope boundary:** product work is now authorized on ws/app and ws/platform.
The owner asks platform to commit each milestone and stop for merging. The deferred real
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
| A5/A6 native page and saved-setting proof | Ownership, fake persistence and real on/off render effects work; user deferred real two-template/restart qualification; Apply/Cancel remains fake-host tested |
| A7 versioned recipe snapshots | Deferred to app design implementation; current small versioned proof is sufficient for foundation plumbing |
| A8 foundation qualification | Implementation/scaffolding checkpoint complete; real normal/cancel/recovery pass; controlled failure, deferred persistence and broader support matrix remain qualification limits |

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

Platform B1 is complete and ready for owner merge; B2 is already merged. App switches
its provider/mappings to the real core through its own workstream. Next is B3
services, including full-capability transfer performance and remaining F2 needs,
then B4 engine integration. No installation or PATH change. Order and rationale are in
[platform.md](product/workstreams/platform.md).
B5/B6 require the owner at the real host. Controlled failure/recovery and deferred
persistence qualification remain open per [VEGAS_RUNTIME.md](VEGAS_RUNTIME.md).
