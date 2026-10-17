# Product roadmap

Updated: 2026-10-16 (Asia/Singapore). Phase plan; actual completion/qualification
is in STATUS. One agent now owns implementation in the original checkout; the
current queue is [NEXT_AGENT.md](../NEXT_AGENT.md).

**Owner scope override (2026-10-17):** retain working features and finish only
native MP4/MOV/WebM/MXF support alongside MKV, and a read-only VEGAS installation/
status dashboard. The owner builds the installer. Other unfinished enhancements
in this historical phase plan are skipped for this release, not follow-up tasks.
See [current scope](PRODUCT_SPEC.md#current-release-scope-owner-2026-10-17).
Historical phase exits do not authorize repeating passed or owner-deferred trials.

The product phases run alongside the adapter gates in [ADAPTER_PLAN.md](../ADAPTER_PLAN.md);
gate state is tracked in [STATUS.md](../STATUS.md). No calendar estimates are given,
for the same reason as ADAPTER_PLAN §7: real-host access and native-exchange recovery
set the pace.

Each phase is reviewable. Use focused checks and update STATUS; preserve historical
evidence without requiring a new experiment ledger for routine work.

```mermaid
flowchart LR
    P0[P0 Review<br/>direction + decisions] --> P1[P1 Core + schema<br/>engine argv parity]
    P1 --> P2[P2 Flutter skeleton<br/>library, Basic, FFmpeg]
    P2 --> P3[P3 Advanced mode,<br/>history]
    A4[A4 real-host parity] --> P4
    A5[A5 page exchange] --> P4[P4 VEGAS page,<br/>popup, payload]
    A6[A6 one-setting proof] --> P4
    A7[A7 versioned payload] --> P4
    P3 --> P4
    P4 --> P5[P5 Installer, signing,<br/>pinned presets]
```

## P0: Review

- **Done 2026-10-12.** The owner chose Signal Flow with a list of changes, built as
  [design/signal-flow.html](design/signal-flow.html), and recorded the decisions in
  [README.md](README.md#decisions): Basic/Advanced, Flutter, Windows only, a theme
  that follows Windows, Riverpod, user-supplied FFmpeg, no proof-template migration,
  and render progress through a VEGAS status line plus a small progress window.
- Still open: the project license. T1 and T2 stand as plan defaults.
- The initial parallel app/platform split was consolidated on 2026-10-16.
  [WORKSTREAMS.md](WORKSTREAMS.md) now describes one agent in the original checkout.
  The phases below describe scope, not separate agents or current completion.

## P1: Product core and schema (no VEGAS, no Flutter)

1. Recapture the FFmpeg facts on Windows: `-h encoder=`, `-encoders`, `-muxers` and the
   container matrix with gyan.dev and BtbN builds (static and shared), plus probe
   timings. The design-time captures came from a Linux build.
2. Write `schema/recipe.v1.schema.json` and `schema/encoder-profiles.v1.json` from the
   prototype data in `design/shared/model.js`. Encoder option facts come from the
   Windows help captures; container rules come from the Windows matrix.
3. Add `src/core`: normalize, validate, compile, lint, payload envelope, session formats
   and the C ABI. C++17, no Windows or VEGAS headers.
4. Golden fixtures. Every built-in preset plus edge cases (template mode, missing
   macros, unknown encoder, ProRes 4444, DNxHR pixel format, CBR in MP4) map to
   expected argv. The compile path for the current fixed profile must reproduce the
   existing FFV1/PCM command.
5. Engine change: accept argv plus input specs instead of the fixed profile. Add
   `-progress pipe:1` parsing, the live render status file (TECH_ARCHITECTURE §5.6) and
   ffprobe output verification before publish.
6. Extend the fake-host suite to render several compiled recipes through FFmpeg
   (x264/MP4, ProRes/MOV, FFV1/MKV), decode them, and run the existing checkers where
   they apply.

**Independent track: VEGAS status line.** Static analysis of `ISfProgress` slots 3 and 4
in VEGAS 2026.0.3.189 (sibling investigation), then an opt-in test build that writes a
status line during a real render, run with the owner. Keep it or drop it on the result.

**Exit:**
- Core tests pass on Windows.
- Parser and lint fixtures come from Windows FFmpeg builds.
- Fake-host suite passes with recipes.
- Fixed-profile decoded output is unchanged.
- Measured compile time is recorded.
- No real VEGAS claim.

## P2: Flutter skeleton

1. `app/` on the installed Flutter (3.47.7 / Dart 3.13.5 at `L:\flutter`, the version
   the owner intends; upgrading is the owner's call). Core is built through
   `packages/ve_core` build hooks, with the CMake fallback if the C++ spike fails. Run
   the TECH_ARCHITECTURE §9.4 Windows spikes:
   - start time;
   - console flash;
   - owner HWND;
   - renderer;
   - file watching;
   - theme: platform brightness follows the Windows app theme live;
   - a window that shows without taking focus.
2. Design system from Signal Flow's light and dark tokens (`ThemeExtension`), with
   Instrument Sans and JetBrains Mono bundled. Components:
   - signal path, full and strip layouts;
   - encoder picker with availability;
   - mode switch;
   - quality control;
   - Extra arguments field with option checks;
   - size and quality card;
   - command preview;
   - message list.
3. Presets: library repository (files, revisions, watch); built-ins; list, search,
   favorites; duplicate, save, import/export.
4. Basic editor for every curated encoder; live command, validation and estimate via FFI.
5. FFmpeg page: discovery, identity, probe, cache, hardware tests; the default is written
   to `machine.json`.
6. Golden screenshots of each screen in light and dark.

**Exit:**
- Windows release build measured against the §9.3 budgets.
- Golden tests pass.
- Presets round-trip through core.

## P3: Advanced mode and history

1. Advanced editor:
   - highlighting;
   - locked macro chips;
   - lint in place;
   - seed from Basic and switch back;
   - macros panel and resolved command.
2. History from `jobs.jsonl` and job records: detail, stderr, command, verification,
   and "open settings as new preset".
3. Render progress window (`--render-monitor`), driven by a fake live status file.
4. **Last:** autocomplete from parsed options. It reuses lint's data; the work is the
   popover. It can move to v1+ without blocking the phase.

**Exit:** Advanced-mode recipes compile and render in the fake host, and lint fixtures
pass. Autocomplete is either done or explicitly deferred.

## P4: VEGAS integration (gated)

**Prerequisites:**

- A4: the product DLL is qualified on the exact host.
- A5: the page exchange is recovered.
- A6: one setting persists across save and restart.

1. Native property page: summary, Edit settings…, Load preset; and the open-editor state
   (mock: `design/shared/vegas-native-page.html`).
2. Session protocol v1 and popup mode: owner, modality, crash-safe result, Apply/Cancel.
3. A7 payload envelope in `abExtra`. Measure the size limit. Proof-template markers are
   not migrated (owner decision).
4. Popup size card: fill in the project length if the page exchange exposes it;
   otherwise leave the length empty.
5. The render path uses the template's recipe:
   - "follow project" choices resolved;
   - errors before render for missing or failed encoders;
   - job records;
   - the progress window launched at render start, and the VEGAS status line if the
     P1 track kept it.
6. Progress window performance check (TECH_ARCHITECTURE §5.6): three real renders with
   it and three without. Over about 2% slower, or visible disturbance to VEGAS, drops it.
7. Real-host checklist on 2026.0.3.189:
   - render each qualified recipe;
   - repeat, cancel and failure renders;
   - two templates, unapplied cancel, save and restart;
   - recipe edited or deleted in the library, with the template still rendering;
   - editor crash recovery;
   - owner and focus behaviour.
8. Publish the first **qualified matrix**, for example x264/MP4, NVENC HEVC/MP4,
   ProRes/MOV and FFV1/MKV with AAC/PCM, each with evidence.

**Exit:**
- ADAPTER_PLAN A8 foundation checklist complete.
- Popup checklist passes.
- Exact identities and hashes recorded.

## P5: Retained release foundations

1. Signed installer with reversible plug-in placement, upgrade policy that preserves
   config, and uninstall. The owner builds it with Inno Setup from platform's inputs
   (owner, 2026-10-15): one release installed together, every recorded VEGAS target
   updated by default, plus version checks between plug-in and app. Choosing older
   VEGAS versions waits on per-version platform research.
2. Read-only VEGAS installation/status dashboard in Settings, backed by services:
   detected hosts, checked paths/versions, installed-manifest integrity where
   verifiable, refresh and unknown/error states. No installer mutations.
3. Finish native multi-container naming/filter integration and qualify retained
   behavior; the core/engine pipeline is already implemented and offline-tested.
4. Pinned presets in Render As, FFmpeg helpers, update checks and diagnostic bundle
   export are owner-skipped. Existing internal fields/data need no removal.

## Risks

| Risk | Effect | Mitigation |
| --- | --- | --- |
| A5 can't recover the template exchange | No in-VEGAS editing | Pinned presets in Render As (§5.5 fallback); edit in the desktop app |
| `abExtra` size limit is small | Snapshot doesn't fit | Compact encoding or compression; drop optional fields such as notes; measure first |
| VEGAS names output files by class extension (`*.mkv`) | Filename/filter workflow incomplete for other retained containers | Establish writer naming syntax/behavior; preserve exact destination and reject suffix mismatch. Never silently rename the host-selected final path. |
| Cross-process owner window misbehaves in VEGAS | Editor hides behind VEGAS or steals focus | P2 spike; fall back to an unowned topmost window with a native page reminder |
| Flutter cold start too slow for the popup | Sluggish feel | Measure; pre-warm on page creation (spawn hidden, then show) as a v2 option |
| Encoder behaviour differs across FFmpeg builds | Lint or compile mismatches | Capability cache per build; fixtures from Windows builds; FFmpeg stderr is authoritative |
