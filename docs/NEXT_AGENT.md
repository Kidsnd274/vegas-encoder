# Continue the unified Vegas Encoder implementation

Updated: 2026-10-17 (Asia/Singapore).

Work in **`L:\repos\vegas-encoder`**, currently on **`master`**.
The original folder remains the only development checkout. The owner explicitly
requested bounded parallel agents for this integration pass; their changes share
this checkout and one queue. No separate worktree or permanent ownership split was
introduced. Read [AGENTS.md](../AGENTS.md),
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

1. **Audit v1 scope against the actual product.** Follow PRODUCT_SPEC's user flows,
   classify implementation gaps separately from qualification, and keep this one
   queue current. Do not revive superseded workstream Needs tables.
2. **Resolve native output-format scope early.** The current recipe candidate
   explicitly refuses non-MKV output and general/ambiguous Advanced output. The
   product's v1 container scope is broader. Investigate host filename/extension
   behavior and the safe adapter/core changes before implementation; do not claim
   MP4/MOV/WebM/MXF support from desktop previews or fake-host tests. Audio-only and
   older-host support retain their existing gates.
3. **Finish release validation and inputs.** Review remaining user-flow gaps and
   affected app performance budgets, then prepare a clean matched release bundle
   and installer guidance. This integration pass did not rerun full performance
   budgets or establish real-host behavior for the new UI/window paths.
4. **Owner release decisions and installer.** The owner builds/tests Inno Setup;
   runtime deployment policy and project licensing remain owner decisions. Keep
   install/update/rollback/uninstall validation and final release signoff explicit.

Deferred real-host checks below stay deferred. New integration implementation does
not close A5–A8 or authorize installation, commits, publishing or support claims.

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
