# Continue the unified Vegas Encoder implementation

Updated: 2026-10-16 (Asia/Singapore).

Work in **`L:\repos\vegas-encoder`**, currently on **`master`**.
The owner requested one agent for app and platform, using this original folder
without a separate development worktree. Read [AGENTS.md](../AGENTS.md),
[workflow](product/WORKSTREAMS.md), [product decisions](product/README.md),
[status](STATUS.md) and relevant contracts/specs. Former workstream handoffs are
history; their old locations, ownership splits and queues do not apply.

## What is here

Master `86aefaf` already contained the earlier app/platform milestones. The latest
changes were copied from platform and verified before updating docs:
actionable FFmpeg failure propagation, clear persistent failure UI, large-preset
editor name fallback and faster progress (FFmpeg/writer 200 ms, live reader 100 ms),
with tests/goldens/status. The owner subsequently authorized committing both
snapshots and merging into master. Platform checkpoint `fd4edb3` preserves its
original work; the main checkout holds the unified result. No push, installation
or new real-host qualification was performed. STATUS records validation.

Original-folder validation passes: clean analysis, all 558 app tests, native build,
3,055 core checks and argv goldens. Ten stale Advanced screenshots were refreshed
for the already-intended `stats_period 0.2` text after reviewing their isolated
digit changes in both themes. Dependency locks and preserved trial builds did not
change. Current work starts with the integration queue below, not more migration.

## Implementation queue

1. **Selected-file import:** connect the picker and disabled Import file action to
   `PresetTransfer.importFrom`; handle errors, refresh/select the new preset. The
   bounded validated service and fake exist.
2. **Desktop navigation:** implement a service-backed launcher, preset/job launch
   routing and handoff to an already-running desktop instance. Connect the null
   `desktopAppLauncherProvider` for Open in Vegas Encoder and Show in History.
   This needs platform/runner work, not just provider wiring. Preserve isolated
   profiles and keep Render independent of the app.
3. **Popup size:** consume `AppUiState.popupWindowSize`; remember physical outer
   dimensions, centre/clamp on the owner monitor and retry revision conflicts.
   Do not persist popup position or break desktop window settings.
4. **Advanced editor:** adopt core option/stage/macro metadata and `VeCore.macros`
   using actual recipe/media/path context; show availability from nullable summary
   encoder IDs. Existing stage colours work; replace remaining option heuristics
   and synthetic macro probes.
5. **Monitor precision:** use C5 output depth/reduction facts for the header glyph/
   pip. Unknown stays unknown. Preserve failure UI/stay-open behavior and no core/
   library reads while rendering.
6. Review combined changes and focused app/native/service checks, then prepare
   release/installer guidance. Owner builds/tests Inno Setup; do not silently
   take over installation or choose runtime/license policy.

These are next implementation items, not changes already made by consolidation.
No separate app/platform request or relay is needed now.

Optional enhancements need backend work or product decisions: Speed in History's
index, actual Render As path if exposed by the host, popup Test button placement
and tests at project dimensions. Do not guess host facts. Library-watch and
capability-transfer optimizations are delivered; do not redo them.

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
