# Platform workstream

Updated: 2026-10-12 (Asia/Singapore). Worktree `L:\repos\vegas-encoder-platform`,
branch `ws/platform`. **B0 complete; stop for owner merge/app review.**

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

## Validation

- Windows x64, installed Dart 3.13.5: both packages analyze cleanly; 95 core and
  40 service checks pass. **Fakes only**: unknown nested fields/default/null round
  trips, immutable copies, no stale compile results, payload buffer copies,
  per-listener stream snapshots, concurrent revision conflicts, 20-revision bound,
  probe/hardware cancellation, live sequence and session mismatch/apply/cancel.
- 163 offline fixture structure/bounds checks; sample envelope lengths/CRC;
  generated data consistency. Design-time Linux option facts are explicitly
  illustrative, **not Windows qualification**.
- C/C++17 draft ABI header compiles under MSVC x64 `/W4 /WX`, with layout assertions.
  Existing default and opt-in configuration-proof native builds also pass `/W4 /WX`.
- Existing 24 host-helper, 9 boundary and 67 native configuration checks pass with
  **fakes/offline windows**. Default `Test-VegasEncoder.ps1` passes decoded repeats,
  fractional timing, short audio, video-only, cancellation/error cleanup,
  destination preservation, Unicode and negative checker with the **fake host**.
  Opt-in Test-ConfigurationProof passes 11 cases / 20 render attempts, including
  seven same-DLL stop/recovery pairs (**fake host**, gyan FFmpeg 5.1.2). Fake-tree
  installer suite passes; outputs in this worktree's ignored build/test-results/.
- **No real VEGAS validation in B0.** Installed 0.1.2-config-proof and its main
  checkout backups remain untouched. Prior real evidence remains limited to its
  recorded VEGAS 2026.0.3.189 tests; controlled real failure recovery and real
  two-template/restart persistence remain unverified. A5–A7 features stay gated.

## Needs / decisions for owner and app

- Owner merge B0; app uses path dependencies and provider injection, and reviews
  C1–C7. Use FakeVeCore.fixtures contexts or inject results for edited widget/golden
  states; the fake never computes domain rules in Dart.
- Owner reconciliation in TECH_ARCHITECTURE/SETTINGS_AND_COMMANDS: C6 uses one
  `%LOCALAPPDATA%\VegasEncoder\jobs` root; origin is `{presetId,revision,name}`;
  C API session file IO is in ve_services/adapter (C++ core serializes only); recipe
  audio is a one-element list. These owner-owned documents were not edited.
- B1 needs approval before acquiring current gyan.dev/BtbN static/shared builds.
  Current PATH FFmpeg is gyan 5.1.2. No downloads/installations started.

## Next

After owner merge/review, B1 Windows recapture/profiles/golden fixtures, then B2 core
and native build hook, B3 real services, B4 engine argv/progress/jobs. B5 status-line
probe and B6 gated adapter/progress performance check need the owner at real VEGAS.
