# Platform workstream

Updated: 2026-10-13 (Asia/Singapore). Worktree `L:\repos\vegas-encoder-platform`,
branch `ws/platform`. **B2 merged into master (`bbcbe91`); ready for B1.** Master through `ab7e7ab`
(F2) was merged before continuing. After B2 commit `d7f0605`, master through
`230c724` (F2 token/fact/UI-state integration) was also merged into this branch.
The app still selects FakeVeCore until its provider switch after B2 merge.

## Delivered

- Portable C++17 core and C ABI: structural normalize (preserves unknown fields and
  absent/null defaults), validate, Basic compile with Extra overrides, Advanced CRT
  parsing/macros/lint/completion, estimates, field diff, payload bounds/CRC, pure C4
  session shape checks. No filesystem, process, Windows or VEGAS calls in the core.
- DLL/static build from the same sources; `NativeVeCore()` with counted-buffer FFI,
  paired frees on success/error and a Windows x64 native-asset build hook. Fakes stay
  explicit; no automatic fallback after a native error. Dependency/source notices
  are included (pinned MIT/BSD packages, nlohmann/json 3.12.0 MIT).
- F2 core additions: `SizeEstimate.minTotalBytes/maxTotalBytes`, final
  `ResolvedSettings.gopFrames`, source format/bit/chroma labels and conversion notes,
  `CompileResult.overriddenFields` for "set in Extra arguments". Existing B0 token
  provenance/issue indexes, mux facts, C5 host HWND and C7 UI state remain additive.
- Fake matching tolerates absent vs empty `extensions` without changing stored JSON;
  real changes still need injected fixtures. Existing six presets/popup only: no
  edited-state sweep or Dart domain compiler. Models and fixtures expose new fields.
- `schema/encoder-profiles.v1.json` and embedded options are explicitly **B2 bootstrap
  B0/Linux design facts, not Windows-qualified**. B1 replaces/recaptures them. Real
  supplied capabilities drive installation availability and private option checks.

## Validation

- `scripts/Test-B2.ps1 -Asan -Aot -Encoder`: MSVC x64 C++17 `/W4 /WX`, DLL/static
  parity; **2,900 native checks** (ownership, malformed/UTF-8/duplicate/deep/overflow
  inputs, payload damage, quoting, concurrency), also passing AddressSanitizer.
- **171 checks per route** through real FFI: native asset, explicit DLL, standalone
  bundled AOT. Live CRF edits, defaults, Extra overrides/provenance/spans, media and
  macro bounds, UTF-16 offsets, source/mux facts, size ranges, diff, payload, sessions
  and four isolate-local consumers. Warm end-to-end compile mean about **0.6–0.95 ms**
  over 500 calls in each sample; no cold-start or app frame-time claim.
- Both packages analyze cleanly; retained fakes/models: **173 core / 57 service /
  281 fixture checks** and C/C++ ABI layout checks. Core-data/fixture generation
  consistency and changed Python/PowerShell scripts checked.
- Existing `C:\ffmpeg\bin\ffmpeg.exe`, **5.1.2-full_build-www.gyan.dev**: native-generated
  FFV1/PCM and H.264/AAC argv encode 60 synthetic 256x144 frames at 30000/1001 with
  48 kHz stereo; FFprobe checks pass. All meaningful 10-bit P010 samples and PCM
  float bytes survive the lossless path. P010's unused low six storage bits are
  excluded from pixel comparison. **Offline files, no fake host or real VEGAS.**
- No app/design/engine/adapter edits; no installation or PATH changes. Prior native
  exporter/fake-host suites were not rerun because their implementation is unchanged.
  Installed 0.1.2-config-proof and main-checkout rollback backups remain untouched.
  A5–A7 gates, two-template/restart persistence and controlled real failure recovery
  remain unverified. B2 payload/session tests do not pass those real-host gates.

## App handoff / needs

- After merge, run pub get in app and change `veCoreProvider` in
  `app/lib/state/services.dart` from `FakeVeCore()` to `NativeVeCore()`; keep explicit
  fake overrides for widget/golden tests. App paths are owned by the app agent, so
  this switch and UI mapping are not made here. Real services still wait for B3.
- Map C2 fields directly: token field/indexes, overriddenFields, signalPath source/
  streams/labels, final GOP frames, typed-length range. No option/pixel-format/message
  parsing or size arithmetic in the app. `resolved` can be null for unknown final
  formats; source facts remain available. Core errors must stay visible.
- Remaining F2 service requests are queued for B3: persisted built-in favorite/pinned
  preferences; origin for Mine duplicates; a separate Test-this-preset stream for
  60 synthetic frames + FFprobe + log; export-to-selected-path, reveal location and
  a versioned share-string format. C3 service APIs are unchanged in B2.
- Owner architecture follow-up: build hook uses hand-authored bindings for the small
  C ABI and `native_toolchain_c`, rather than requiring ffigen. Standalone native
  assets use `dart build cli`; plain `dart compile exe` omits build hooks/assets.

## Next

Keep **B1 tight**, then B3 services (including F2 requests), B4 engine argv/progress/
jobs. B1 downloads are already approved: current gyan.dev and BtbN into this
worktree's ignored build/ only, recording source URLs/versions; existing gyan 5.1.2
is the older case. Current downloads have not started. No installer/PATH change.
B5 status-line and B6 gated adapter/progress performance tests need the owner with
real VEGAS. Next agent continues with B1, commits to ws/platform at that milestone,
then stops for owner merge. B2 merge was explicitly requested by the owner.
