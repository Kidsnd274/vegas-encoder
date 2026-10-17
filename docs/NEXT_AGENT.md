# Continue the unified Vegas Encoder implementation

Updated: 2026-10-17 (Asia/Singapore).

Work in **`L:\repos\vegas-encoder`**, currently on **`master`**.
The original folder remains the only development checkout. The earlier explicitly
requested parallel pass is complete; default to one agent here unless the owner
requests delegation again. Preserve its uncommitted changes and this single queue.
No separate worktree or permanent ownership split was introduced. Read [AGENTS.md](../AGENTS.md),
[workflow](product/WORKSTREAMS.md), [product decisions](product/README.md),
[status](STATUS.md) and relevant contracts/specs. Former workstream handoffs are
history; their old locations, ownership splits and queues do not apply.

## Consolidation baseline (2026-10-16)

Master `86aefaf` already contained the earlier app/platform milestones. The latest
changes were copied from platform and verified before updating docs:
actionable FFmpeg failure propagation, clear persistent failure UI, large-preset
editor name fallback and faster progress (FFmpeg/writer 200 ms, live reader 100 ms),
with tests/goldens/status. The owner subsequently authorized committing both
snapshots and merging into master. Platform checkpoint `fd4edb3` preserves its
original work; the main checkout holds the unified result. No push, installation
or new real-host qualification was performed. STATUS records validation.

That consolidation passed original-folder validation: clean analysis, all 558 app tests, native build,
3,055 core checks and argv goldens. Ten stale Advanced screenshots were refreshed
for the already-intended `stats_period 0.2` text after reviewing their isolated
digit changes in both themes. Dependency locks and preserved trial builds did not
change. These are prior baseline results; current integration validation is in STATUS.

## Integration pass implemented

All five former integration items now have producer/consumer implementation:
selected-file import with validation/error/selection handling; package-backed
desktop preset/job launch and profile-scoped instance handoff; popup physical
outer-size persistence; Advanced token/macro/availability metadata adoption; and
C5 monitor precision display. External navigation waits for modal actions and
complete asynchronous writes/pickers, preserving drafts and destination order.
STATUS records the focused checks and remaining qualification limits. The owner
authorized a local commit of this integration checkpoint afterward. No installed
candidate was replaced; push and installation remain separate authorizations.

## Implementation queue

The current container/integration implementation pass is complete at its offline
scope, including final optimized native and app builds. STATUS records focused
checks and the remaining qualification limits. These new changes are uncommitted;
the previously authorized integration commit is `df1ff9a`. All three current
agents completed after resuming interrupted verification; no installed trial or
rollback files were changed.

The owner reduced the remaining feature scope on 2026-10-17: **keep native
multi-container support and a VEGAS installation/status dashboard; skip the other
unfinished enhancements. The owner makes the finished installer.** This supersedes
the former revision-history and Advanced-extra-input implementation tasks. Preserve
existing working features and internal plumbing; this is not a code-removal task.

1. **Finish MP4/MOV/WebM/MXF in VEGAS alongside MKV.** Shared target preflight, adapter/
   engine adoption, exact suffix enforcement and Advanced preview guidance are
   implemented. The class still advertises `*.mkv`; establish exact writer ID-4
   extension-list syntax before changing it. Built-in wildcard strings alone are
   insufficient evidence. Per-template default/filter behavior and new-container
   real VEGAS renders remain unqualified. The owner retained these formats; an
   MKV-only release is not the selected final scope. Follow
   [NATIVE_CONTAINER_PLAN.md](product/NATIVE_CONTAINER_PLAN.md); do not repeat the
   broad investigation, guess a delimiter or claim qualification from fakes.
2. **Implement the read-only VEGAS installation/status dashboard in Settings.**
   First inspect `scripts/Get-VegasTargets.ps1`, the recorded
   `vegas-encoder-install/1` manifest in `scripts/Install-VegasEncoder.ps1`, and
   [B7 installer inputs](B7_INSTALLER_INPUTS.md). Plan the package-backed producer
   and app consumer together; the app reaches the filesystem/registry only through
   ve_services. Report detected host name/version/path, expected exporter and
   discovery paths, actual DLL version, manifest path and verification result.
   Distinguish not installed, verified, unverified/no supported manifest,
   missing/changed files and unreadable status. A matching version alone does not
   prove integrity; a detected older host is not a supported host. Include refresh,
   useful empty/error states and path/error details. Existing development manifests
   are a starting point; do not invent the owner's future installer format or make
   the dashboard depend on a finished installer. No install/repair/uninstall writes
   or automatic file replacement. UI behavior is in UI_SPEC §6a.
3. **Prepare the retained scope for owner handoff.** Use focused checks for changed
   producer/consumer paths and light/dark goldens for changed app UI. Reuse passed
   container/core/service checks unless new changes justify repeating them. Finish
   matched build inputs and keep installer guidance current; the owner builds/tests
   Inno Setup. Runtime deployment policy and project licensing remain owner choices.
   Installation, new real-host trials and release signoff remain separate steps;
   do not resume existing owner-deferred trials. This pass established no new
   full performance-budget or real-VEGAS qualification.

Deferred real-host checks below stay deferred. New integration implementation does
not close A5–A8 or authorize installation, commits, publishing or support claims.

Everything else unfinished in the feature audit is **skipped for this release**,
not an implicit next queue: revision browser/restore; native extra inputs/general
maps/complex graphs; new popup project/path extraction; richer native page/direct
Load; pinned Render As presets; per-preset FFmpeg override; log retention/richer
headers; command-to-Basic import; learned estimates; structured filter/input
controls; FFmpeg downloads; update/diagnostic bundles; additional host/media
support; live-edit/prewarm features. Existing counters/history, base snapshots,
diff/update, logs, portable fields and sample/unknown fallbacks stay intact.
Owner decisions also close popup Test/project-size/recommended-band questions.
Library-watch and capability-transfer optimizations are delivered; do not redo them.

## Next-agent execution brief

Read the current scope above, PRODUCT_SPEC's current release scope, UI_SPEC §6a,
STATUS and NATIVE_CONTAINER_PLAN. The existing container pipeline is implemented;
plan the remaining naming/host work without repeating that implementation. Also
plan the dashboard's service/model/fake/UI changes before coding. Work on these two
features only, in the original checkout, preserving all uncommitted work. Keep
checks focused and distinguish fakes/offline FFmpeg from real VEGAS. Do not build
the owner's installer or revive skipped features. Update STATUS/NEXT_AGENT with
actual results and concrete remaining gates; no commit/install/push without its
required authorization.

## Carried-forward issues and decisions

Reconciled against the historical app/platform notes on 2026-10-17. These feed
the implementation queue above; they are not separate agent queues. Integration
items completed in `df1ff9a` and delivered library/capability optimizations are
not outstanding. Historical "not built" claims about native app-version preflight
and B7 installer inputs are superseded too.

| Item | Current disposition |
| --- | --- |
| Popup plug-in/core version warning | Implemented and verified: C4 plug-in/app release triplets and exact core stamps; missing stamps warn as unverified. Apply remains enabled. Same-stamp hash-distinct variants cannot be detected. Native PE prelaunch checks already cover popup and monitor. |
| History list Speed | Implemented through native index, storage validation/recovery, models/fakes and UI. Uses recorded nullable `realtime`; legacy missing values stay unknown. No length/time inference. |
| Late monitor job record | Implemented: terminal-only immediate read plus one-second polling until arrival/disposal. No active-render C6/core/library reads; late details/log access update. Failure retention unchanged. |
| Preset-test failure messages | Implemented: plain `message` plus nullable separate `code`, without UI exception-wrapper parsing. |
| Preset-test size and popup action | Resolved by owner 2026-10-17: desktop-only lightweight 320x180 P010 at 30 fps for v1. No popup action or project-sized test is outstanding for v1. |
| Recommended quality band | Resolved by owner 2026-10-17: retain current numeric marks and no additional recommendation band for v1. |
| Actual Render As path / project facts in popup | New edit-time extraction is owner-skipped for this release. Retain labelled sample/unknown facts and manual length; container naming/render-time suffix checks remain in scope. |
| Advanced partial quote/chip behavior | Existing implementation confirmed by focused consumer assertion; preceding input/output chip guards survive an unfinished quote. No implementation change was needed. |
| Window/startup polish | Historical observations are not a feature-development queue. Address a reproduced material defect if relevant; no new general polish/performance programme. |
| Saved revision browsing/restore/diff | Owner-skipped for this release. Preserve internal revisions/history, CAS conflict handling and base-recipe diff/update; no new browser/restore UI. |
| Advanced extra inputs | Owner-skipped for native rendering. Preserve safe input/map/complex-graph restrictions and working supported Advanced commands. |
| VEGAS installation/status dashboard | Retained unfinished feature; implement read-only service plus Settings UI as item 2 above. Installer remains owner-owned. |

Historical sources: [app Needs](product/workstreams/app.md#needs-from-platform),
[app Open items](product/workstreams/app.md#open-items),
[platform handoff](product/workstreams/platform.md#limits--app-handoff) and
[installer inputs](B7_INSTALLER_INPUTS.md). Old manual file-dialog observations,
IME/autocomplete placement notes, log-opening preferences and library-load UI
observations remain review references, not newly reproduced bugs. Full app budget
qualification and owner-deferred monitor measurements retain their recorded scope.

## Owner scope and operational continuity

- Installed trial: template-name-fix 0.1.7 on VEGAS 2026.0.3.189. Its INI still
  points into the platform folder's matching candidate.
- Faster-progress is prepared, **not installation-confirmed**. Owner deferred its
  trial and monitor time/memory measurements until next time. Do not resume them
  automatically or treat preparation as qualification.
- Extra normal render after encoder failure is owner-deferred. Normal renders,
  normal restart persistence, cancellation/recovery, failure presentation and
  immediate large-preset reopen have owner evidence at STATUS's recorded scope.
- Reopened large-preset notes were checked directly and match, including `END 容量`;
  the popup does not display notes. Exact large-template save/restart sequence is
  unconfirmed; no absolute host capacity limit is established.
- Preserve old worktrees, candidate app/log/data files and exact rollback backups.
  Do not relocate installed paths or delete worktrees. Build new work here;
  preserve unrelated ignored outputs and `.claude/`.
- The owner authorized this consolidation's commits and local master merge.
  Future commits/merges still follow owner authorization. No push, installation,
  machine-tool upgrade, AV exclusion, sanitizer or old process/thread investigation.
