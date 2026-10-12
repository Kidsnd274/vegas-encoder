# Workstreams: building in parallel

Updated: 2026-10-12 (Asia/Singapore). Status: agreed split for the first build.

Two agents build the product at the same time. Each owns a set of paths and a branch;
they meet at written contracts. The owner relays between them and merges.

| Workstream | Agent | Owns |
| --- | --- | --- |
| **App** | Claude Code, Opus | The Flutter app: design system, every screen and window, state, app tests |
| **Platform** | ChatGPT agent | Everything under the app: C++ core, engine, adapter, schema, Dart packages for the core and services, FFmpeg facts, installer, real-host work |

## 1. Branches and worktrees

Each agent works in its own git worktree on its own branch, created from master after
the design commit:

| Workstream | Branch | Worktree (suggested) |
| --- | --- | --- |
| App | `ws/app` | `L:\repos\vegas-encoder-app` |
| Platform | `ws/platform` | `L:\repos\vegas-encoder-platform` |

- Agents commit to their own branch at milestones, and only when the owner's prompt
  allows it. They never push, merge into master, rebase master, or touch the other
  branch.
- The owner merges a milestone into master, and the other agent merges master into
  its own branch when it needs that milestone.
- Builds write to each worktree's ignored `build/`, so the two never share outputs.

## 2. Path ownership

| Path | Owner | Notes |
| --- | --- | --- |
| `app/` (including `windows/runner/`, tests and goldens) | App | |
| `docs/product/design/` (mockups, screenshots) | App | `design/shared/model.js` and `avoptions.js` are reference prototypes; neither agent changes them |
| `docs/product/UI_SPEC.md` | App | |
| `docs/product/workstreams/app.md` | App | Status, needs, decisions |
| `src/` (core, engine, vegas, support), `tests/`, `scripts/`, `config/` | Platform | |
| `schema/` | Platform | Recipe schema, encoder profiles, fixtures |
| `packages/ve_core/`, `packages/ve_services/` | Platform | Pure Dart; the app's only way into the core and the system |
| `docs/product/CONTRACTS.md` | Platform | The seams below, in exact shapes |
| `docs/product/SETTINGS_AND_COMMANDS.md`, `FFMPEG_INTEGRATION.md`, `research/` | Platform | |
| `docs/STATUS.md`, adapter docs (`ADAPTER_PLAN.md`, `INTEGRATION_CONTRACT.md`, `NATIVE_CONFIGURATION.md`…) | Platform | |
| `docs/product/workstreams/platform.md` | Platform | Status, needs, delivered |
| `AGENTS.md`, `docs/product/README.md`, `PRODUCT_SPEC.md`, `TECH_ARCHITECTURE.md`, `ROADMAP.md`, this file | Owner | Agents propose changes in their workstream file; the owner applies them |

If you need a change in a path you don't own, write it under "Needs" in your
workstream file and carry on with a stub. Don't edit the other side's files.

## 3. Contracts (the seams)

Platform writes these first, in `docs/product/CONTRACTS.md` and as code. App reviews
them before building on them.

| ID | Contract | Lives in | Used by |
| --- | --- | --- | --- |
| C1 | Recipe schema v1 and encoder/container profiles | `schema/` | Core, app (through C2) |
| C2 | `VeCore` Dart API: normalize, validate, compile, lint, complete, profiles, payload, version; typed models for recipe, issue, compile result, diagnostic and suggestion; `FakeVeCore` | `packages/ve_core/` | App |
| C3 | `ve_services` Dart API: FFmpeg installations, probe progress stream, capabilities, hardware tests; preset library (list, watch, save with revisions, import/export); machine settings; job records; live render status; edit-session request/result. A fake for each | `packages/ve_services/` | App |
| C4 | Edit session files (`--edit-session <dir>`): `request.json`, `result.json` | CONTRACTS.md, TECH_ARCHITECTURE §5.2 | DLL, app |
| C5 | Live render status file and the `--render-monitor <file>` launch | CONTRACTS.md, TECH_ARCHITECTURE §5.6 | DLL, app |
| C6 | Job record and `jobs.jsonl` | CONTRACTS.md | DLL, app (History) |
| C7 | Settings the DLL reads from the app (default FFmpeg, progress window on/off, keep on top) | CONTRACTS.md (`machine.json`) | App writes, DLL reads |

Rules:

- **The C++ core is the only implementation** of compile, validate, lint and
  completion (TECH_ARCHITECTURE T1). The app never reimplements them in Dart. Until the
  real core lands, `FakeVeCore` returns fixture results for the built-in presets.
- **Fakes ship with the contract.** Every C2/C3 service has a fake the app can use in
  widget and golden tests, and to run screens before the real code exists.
- **Contract changes are versioned.** Additive changes are fine; breaking ones go
  through the owner and both workstream files.

## 4. Order

The early milestones are chosen so neither side waits.

**Platform**

| # | Milestone | Unblocks |
| --- | --- | --- |
| B0 | `CONTRACTS.md`; draft `schema/recipe.v1.schema.json`; draft `ve_core.h`; `packages/ve_core` and `packages/ve_services` with the Dart API, models and fakes; a sample live status file | App screens on fakes |
| B1 | Windows FFmpeg recapture (help text, encoders, muxers, container matrix, probe timings) with gyan.dev and BtbN builds; `encoder-profiles.v1.json`; golden recipe fixtures | Real option data for lint and Extra arguments |
| B2 | C++ core (normalize, validate, compile, lint, complete, payload, session) with tests; FFI through the `ve_core` build hook; `FakeVeCore` kept for tests | Live command, checks and estimates in the app |
| B3 | `ve_services`: discovery, probe, parser, hardware tests, cache, library repository, machine settings, jobs, live status reader, sessions | Real FFmpeg page, library and History |
| B4 | Engine: argv input, `-progress` parsing, live status writer, ffprobe verification, job records; fake-host suite with recipes | Progress window on real data (fake host) |
| B5 | VEGAS status line track: static analysis of `ISfProgress` slots 3/4, then an opt-in real-host test with the owner | Keep or drop the status line |
| B6 | Adapter (gated A5–A7): template payload, native page launching the editor, render from recipe, progress window launch; real-host checklist and the progress-window performance check with the owner | Popup and progress window in VEGAS |
| B7 | Installer for app, DLL and config; reversible, manifest-based | Release |

**App**

| # | Milestone | Needs |
| --- | --- | --- |
| F0 | Flutter project in `app/`; Windows runner; mode dispatch (desktop, `--edit-session`, `--render-monitor`); Riverpod; theme following Windows; bundled fonts; the P2 spikes that are app-side (start time, owner HWND, renderer, live theme, no-activate window) | Nothing |
| F1 | Design system from `design/signal-flow.html`: tokens light and dark, buttons, inputs, segmented controls, pickers, slider, messages; signal path (full and strip) with `CustomPainter` wires; size and quality card; command view; goldens in both themes | Nothing |
| F2 | Presets screen and Basic editor | B0 fakes |
| F3 | FFmpeg, History and Settings screens | B0 fakes |
| F4 | Advanced editor: highlighting, lint display, locked chips, macros, resolved command; autocomplete last | B0 fakes (B2 for real data) |
| F5 | Popup mode: template header, strip, origin and update-from-library flows, Apply/Cancel through C4 | B0 fakes; B6 for VEGAS |
| F6 | Render progress window from C5 | B0 sample file; B4 for real data |
| F7 | Switch from fakes to the real core and services as B2–B4 land; measure the §9.3 budgets | B2–B4 |

## 5. Shared rules

- Windows x64 only. Flutter at `L:\flutter` (3.44.6 when this was written); upgrading
  the SDK is the owner's call.
- The visual reference is `design/signal-flow.html` (light and dark); behaviour is
  `UI_SPEC.md`; settings rules are `SETTINGS_AND_COMMANDS.md`.
- Say what was verified where: fake host, fake services, or real VEGAS with the build
  and host identity. Gated features stay gated until real-host evidence exists.
- Real-host steps (installing a DLL, running VEGAS) are done with the owner, using the
  reversible installer. Never replace the installed exporter without asking.
- Keep each workstream file short: what's done, what's next, what you need from the
  other side, and any decision the owner must make.
- Either side may add `.gitignore` rules for its own paths (for example `app/build/`,
  `.dart_tool/`); leave the other rules alone.
- The main checkout `L:\repos\vegas-encoder` keeps the ignored `build/` folder with the
  installed candidate and rollback backups, and `evidence/`. Worktrees don't have
  them; don't delete or rebuild over them.
