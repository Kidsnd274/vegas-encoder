# Development workflow: one agent, one checkout

Updated: 2026-10-16 (Asia/Singapore). The owner consolidated app and platform work.
The filename remains stable for existing links.

## Working location and ownership

- Work in **`L:\repos\vegas-encoder`**, the original repository folder. The current
  local branch is **`master`**; no new worktree is needed.
- One agent can edit the app, packages, native code, tests, scripts and product
  documentation together. The former app/platform path ownership split is retired.
- Do not delegate or restart parallel agents unless the owner requests it.
- Commit only with owner authorization. Do not push, merge into master, publish,
  install or replace the installed exporter without owner authorization.
- Current facts/qualification: [STATUS.md](../STATUS.md). Current implementation
  queue and continuation: [NEXT_AGENT.md](../NEXT_AGENT.md).
- [workstreams/app.md](workstreams/app.md) and
  [workstreams/platform.md](workstreams/platform.md) retain history. Their old
  ownership rules, queues and working locations are superseded by this workflow.

## Consolidation and retained artifacts

Original master `86aefaf` already included both committed workstream tips
(`ws/app` at `493f146`, `ws/platform` at `7a8493a`). App had no outstanding edits.
The platform's 32 modified files and two new monitor goldens were brought into the
original folder and byte-verified before workflow documentation edits. The owner
then authorized staging/committing both snapshots and merging into master.
Platform checkpoint `fd4edb3` preserves its original changes; the unified version
includes the workflow updates and reviewed Advanced goldens. Both histories are
merged locally, and the retained platform branch is advanced to the same result.
No history was rewritten or pushed.

The original checkout passes analysis, all 558 app tests, the native build and
3,055 core checks. STATUS records the reviewed command-text golden refresh and
link/source-transfer checks. No real-host or installed-binary change was made.

`build/consolidation-backup/` preserves the original binary patch and new goldens.
Do not overwrite it, unrelated `.claude/`, historical evidence or build outputs.
Old worktrees remain for reference and operational rollback, not development.
The installed trial still references files under
`L:\repos\vegas-encoder-platform\build\b6-candidate-0.1.7-template-name-fix`.
The separate faster-progress candidate is prepared there and its owner trial is
deferred. Moving source work does not move installed paths or qualify a new build.
Keep those candidates, manifests, isolated profiles and exact rollback files in
place. Do not delete their folders or silently rewrite the installed INI.

Build source and run checks from the original folder. Do not transplant
`.dart_tool`, Flutter/CMake outputs or native build caches from a sibling.
Legacy trial launchers still accept an explicit absolute CandidateRoot.

## Architecture boundaries remain

| Layer | Responsibility |
| --- | --- |
| `src/core/` | Sole normalize/validate/compile/lint/completion/payload implementation; portable C++17, no Windows/VEGAS headers |
| `packages/ve_core/` | Typed Dart models and FFI to the same core |
| `packages/ve_services/`, `src/services/` | Files, settings, FFmpeg discovery/probes/processes, library, jobs, edit sessions and system access |
| `src/engine/`, `src/vegas/`, `src/support/` | Encoding, host integration, lifetime, transport and diagnostics |
| `app/` | Presentation, state, navigation and Windows runner; consume domain/system facts through the packages |
| `schema/`, `tests/`, `scripts/`, `docs/` | Shared schemas, checks, build/install tools and product documentation |

Host calls stay on Render's caller thread; release host frames before waits.
Render never waits on Flutter, the monitor or a status writer. Single ownership
preserves these process, lifetime and package boundaries.

## Contracts and validation

Keep [CONTRACTS.md](CONTRACTS.md) in step with implementations and fakes:
C1 recipe/profiles, C2 core API, C3 services, C4 edit sessions, C5 live status,
C6 job records/index and C7 settings. Implement producer, consumer and focused
checks together; preserve backwards-compatible unknown fields and facts.

Windows x64 only, using existing MSVC and `L:\flutter`. Read relevant specs and
native integration docs before changes. Follow AGENTS.md for current library
documentation and Context7.

Use focused native/service tests for affected ownership, bounds, timing,
cancellation, persistence and scripts. App changes need widget tests and light/dark
goldens; inspect intended visual changes. Run relevant window probes for runner
changes. Distinguish fakes, a fake host and real VEGAS. Do not repeat passing
checks without a new change, failure or unresolved concern.

Real-host gates remain at their actual evidence level. The owner deferred extra
encoder-failure recovery, faster-progress trial and monitor measurements. Installer
implementation remains the owner's Inno Setup work with agent guidance/inputs.
Consolidation selects no new license/tool version or compatibility claim.

## Milestone history

B0–B7 (core/platform/installer inputs) and F0–F7 (app) remain useful historical
labels for components, not separate agents. B5 status text was dropped. B6 basic
integration works with qualification limits. B7 inputs exist, not a completed
installer. App integration follow-ups are in NEXT_AGENT.md.
