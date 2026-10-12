# Platform workstream

Updated: 2026-10-12 (Asia/Singapore). Worktree `L:\repos\vegas-encoder-platform`,
branch `ws/platform`. **B0 app-review additions complete; stop for owner merge.**
Merged master through `c4edb57` (B0 and F0/F1) by fast-forward before this work.

## Delivered

- C1–C7 exact shapes in [CONTRACTS.md](../CONTRACTS.md); draft recipe JSON Schema
  and portable `src/core/capi/ve_core.h` (no runtime core/build hook until B2).
- Pure Dart ve_core: immutable models with unknown-field preservation, synchronous
  VeCore API, FakeVeCore and injectable fixtures. Six built-in presets plus popup;
  normalize/compile/validate, per-minute estimates, seeded lint/completion, identical
  diffs and payload round trips. Unmatched edited-state requests fail explicitly.
- Pure Dart ve_services: ten service APIs, models and a fake for each. Mockup's three
  FFmpeg installations/options/hardware availability; six library presets with
  revisions; machine preferences; five History records; popup Apply/Cancel; all
  seven live render states as JSON files and injectable reader snapshots.
- `scripts/Test-B0.ps1`: offline contract runner. Fixture generator reads design
  files without editing them; `--check` checks reproducibility. No third-party Dart
  dependency, SDK upgrade, FFmpeg download, real-host install, or app/design edit.
- App-review additions, all additive in contract v1:
  `CommandToken.field` and `Issue.tokenIndices` (zero-based display indexes);
  `CompileResult.signalPath` with raw video/audio format, useful bits, conversion,
  chroma change and `containerSupport=ok|warn|no|unknown`; C5 `hostHwnd` as a decimal
  string for VEGAS's main window; C7 `uiState` with physical restored desktop bounds,
  maximize state and exact last size-card length text. KeepOnTop remains false.
- Models, existing six preset/popup fixtures and service fakes expose those fields.
  Capability-specific compile highlights use `CoreFixture.compileIssues`; standalone
  validations carry no indexes. No edited-state fixture sweep or Dart domain rules.
- Owner-approved reconciliation applied to TECH_ARCHITECTURE/SETTINGS_AND_COMMANDS:
  one jobs root, `{presetId,revision,name}` origin, session file I/O outside core,
  one-element recipe audio list. Native implementation/FFI remains B2.

## Validation

- Current app-review milestone: `scripts/Test-B0.ps1` passes on Windows x64 with
  installed Dart 3.13.5: both packages analyze cleanly; **170 core / 57 service /
  281 fixture checks**, plus C/C++17 ABI header x64 `/W4 /WX`. New checks cover
  token field/index bounds, capability-specific highlights, unknown/disabled facts,
  P010 and float no-conversion paths, 24-bit PCM in a 32-bit carrier, per-stream mux
  facts, HWND string precision, UI-state watch/revision conflicts and old JSON.
- Prior B0 foundation checks: **fakes only** unknown nested fields/default/null round
  trips, immutable copies, no stale compile results, payload buffer copies,
  per-listener stream snapshots, concurrent revision conflicts, 20-revision bound,
  probe/hardware cancellation, live sequence and session mismatch/apply/cancel.
- Offline fixture checks include sample envelope lengths/CRC and generated data
  consistency. Design-time Linux option facts and authored signal facts are explicitly
  illustrative, **not Windows qualification**.
- C/C++17 draft ABI header compiles under MSVC x64 `/W4 /WX`, with layout assertions.
  Existing default and opt-in configuration-proof native builds passed in B0;
  they were not rerun for these Dart/model/documentation additions.
- Prior B0: 24 host-helper, 9 boundary and 67 native configuration checks passed with
  **fakes/offline windows**. Default `Test-VegasEncoder.ps1` passed decoded repeats,
  fractional timing, short audio, video-only, cancellation/error cleanup,
  destination preservation, Unicode and negative checker with the **fake host**.
  Opt-in Test-ConfigurationProof passed 11 cases / 20 render attempts, including
  seven same-DLL stop/recovery pairs (**fake host**, gyan FFmpeg 5.1.2). Fake-tree
  installer suite passed; not rerun for this milestone. Outputs in this worktree's
  ignored build/test-results/.
- **No real VEGAS validation in B0.** Installed 0.1.2-config-proof and its main
  checkout backups remain untouched. Prior real evidence remains limited to its
  recorded VEGAS 2026.0.3.189 tests; controlled real failure recovery and real
  two-template/restart persistence remain unverified. A5–A7 features stay gated.

## Handoff / owner decisions

- Owner merges this contract milestone before platform resumes. App can map token
  fields/indexes to its command view and signalPath facts to its display models;
  no format-name/message parsing. Read C2/C5/C7 for exact null/default semantics.
  Fakes still require injected edited states until B2.
- B1 is approved: older case is the existing gyan.dev 5.1.2 at `C:\ffmpeg`; acquire
  current gyan.dev and BtbN builds into this worktree's ignored `build/`, recording
  each source URL and version. No installation or PATH change is authorized.
  Downloads are not needed for this contract milestone and have not started.

## Next

**B2 next, before B1**, to unblock the app's live editor. Implement the real C++ core
and FFI against the now-reviewed C1/C2 shapes using the existing curated profile
fixtures and supplied capabilities; B1's download/recapture data is not needed to
implement that boundary. Keep profile provenance illustrative until B1 replaces it
with Windows facts; B2 tests cannot assert Windows encoder or real-host qualification.
Then keep approved B1 recapture tight (no edited FakeVeCore fixture sweep), B3 real
services, B4 engine argv/progress/jobs. B5 status-line probe and B6 gated
adapter/progress performance check need the owner at real VEGAS.
