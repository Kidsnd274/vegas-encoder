# Continue the unified Vegas Encoder implementation

Updated: 2026-10-18 (Asia/Singapore).

Work in **`L:\repos\vegas-encoder`**, currently on **`master`**.
The original folder remains the only development checkout. The earlier explicitly
requested parallel pass is complete; default to one agent here unless the owner
requests delegation again. Preserve existing changes and this single queue.
No separate worktree or permanent ownership split was introduced. Read [AGENTS.md](../AGENTS.md),
[workflow](product/WORKSTREAMS.md), [product decisions](product/README.md),
[status](STATUS.md) and relevant contracts/specs. Former workstream handoffs are
history; their old locations, ownership splits and queues do not apply.

## Selected app icon

The owner selected option A. Source: `app/assets/icon/app_icon.svg`; regenerate
the Windows ICO/PNG and Markdown PNG using `scripts\export_app_icons.bat`.
`--check` verifies freshness. See [icon workflow](../app/assets/icon/README.md)
and STATUS for checks. The title-bar mark already matches A and keeps its theme
colours. No `flutter_launcher_icons` dependency is needed. README icon/layout
changes await the owner's later instructions; installed candidates remain intact.

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

**Current owner-requested build consolidation:** root `version.json` and generated
native/Dart/pubspec/setup projections are the version source. Use
`scripts/Build-Release.ps1` (All/Build/Package) and [BUILDING.md](BUILDING.md).
Current exporter output is **`build/release/vegas-encoder`**, using the `release`
build argument. The legacy `recipe-proof` argument aliases that same output;
old folders/candidates/rollback stay intact. Packaging/receipts/tests use the
new path. This folder change does not change version labels or host behavior.
The unified release build/stage passes into `build/release-inputs-release-folder`
(25 verified files); 11 receipt guards and 62 naming checks pass with a fake
host. Receipts validate the new output and the legacy folder remains preserved.
The owner's `setup/setup_script.iss` now includes the generated config version
definitions for AppVersion and numeric VersionInfoVersion. Actual compiler
validation with output disabled passes for current and changed-JSON fixtures;
no installer executable was built or run. Compile Setup separately after the
product build; automatic setup compilation is not part of the unified command.
The owner explicitly added this workflow request after committing the retained
features as `b5d66de`. Preserve installed/old staged variants and owner-added
icon assets/scripts/runner icon; new workflow changes are uncommitted. The full
All command passed and staged `build/release-inputs-central-versions` (25 files),
with 8 version tests, 11 receipt guards, 66 packaging checks, 5 core/version unit
checks, 2 unchanged About light/dark goldens and clean app/core/services analysis.
That initial bundle predated concurrent icon changes, and Package-only correctly
refused the stale source receipt. The final rebuild included the current icon
and staged `build/release-inputs-central-versions-current` (all 25 hashes verified);
Package-only then passed into `build/release-inputs-central-versions-repack`
without recompilation. Do not rewrite receipts or mutate old bundles. See STATUS for
the built hash and exact validation scope.
This does not reopen other feature work or skipped/deferred host trials.

The owner reduced the remaining scope on 2026-10-17 to native multi-container
support and the read-only VEGAS installation/status dashboard. Both now have
producer/consumer implementation and focused offline checks. Everything else
unfinished remains skipped; the owner builds the finished installer.

The owner additionally requested a shared Profile list with descriptions on
2026-10-18. It reuses `VideoPanel` / `VeSelect` in desktop and popup, with six
Apple-based ProRes descriptions authored in the core catalog. **Keep the encoder
name `prores_ks`**, per the owner's correction. This source/build refinement is
not deployed into the installed trial. Preserve that candidate and all rollback
paths; another replacement still requires owner direction. STATUS records focused
checks and light/dark review.

The owner-requested pre-work checkpoint is **`c8e6e39`** (all pre-existing tracked
and untracked source changes). The owner subsequently requested committing all
naming/dashboard/Profile-list changes and documentation on 2026-10-18; this
changeset is that local source checkpoint (see Git history).
One agent worked in this original checkout; no new worktree or delegation. The
owner subsequently authorized installation of the new trial (2026-10-18); its
installed files/manifest/path hashes verify. No live platform candidate, old
worktree or prior rollback was changed.
The `.claude/worktrees/agent-ade5b8ae1674a5f3d` worktree has no unique commits but
contains four modified Windows runner files and untracked `app/STARTUP_HANDOFF.md`
for an unfinished startup fix. It is **not safe to delete without preserving or
explicitly discarding those edits**. This inspection did not resume that skipped work.

1. **Container test queue is closed at owner direction.** On 2026-10-18 the owner
   reports checking every supported container and confirms correct values passed
   to VEGAS on the installed 2026.0.3.189 trial. Remaining MXF render and MKV
   regression are owner-skipped, not passed. The separate two-container template
   restart is unconfirmed and must not be requested automatically. No more manual
   container testing is queued. Five-extension writer advertising
   and the core-derived per-template wildcard (slot 17 / selector 11) are implemented
   from the exact 2026 MP4 writer/host static chain in
   [NATIVE_CONTAINER_PLAN.md](product/NATIVE_CONTAINER_PLAN.md). The actual built
   DLL passes 62 fake-host naming assertions. Prior core/engine/FFmpeg container
   suites remain passed and were not repeated. Owner confirmation is limited to
   the reported all-container value handoff plus the actual renders below;
   the historical checklist does not create another test request.
   See [CONTAINER_TRIAL.md](CONTAINER_TRIAL.md); do not
   guess a second mechanism or repeat broad investigation. The owner authorized
   installation, which is complete and verified. VEGAS was launched with the
   isolated container profile. Owner confirms `.mp4` filename updates. Initial
   attempts failed: existing `test.mp4` was preserved; a second modified-default
   H.264/float-PCM recipe was rejected by FFmpeg's MP4 muxer. C5/C6 contain the
   actionable message; the disabled monitor left only VEGAS's generic HRESULT UI.
   The owner then changed audio to AAC and rendered successfully. Job
   `C24475AA-4C26-420B-9D5C-C4E1C5D81795` is published/S_OK; agent full decode and
   readback pass (182 frames, 1920×1080, 30000/1001, H.264 10-bit + stereo AAC).
   Faststart was enabled; agent box inspection confirms moov before mdat.
   The owner also confirms successful MOV; job
   `0DA59B34-CD66-4153-A21B-08267D4CA81E` publishes `test_mov.mov`. Agent full decode
   passes: ProRes **LT**, 10-bit 4:2:2, 182 frames at 1920×1080 / 30000/1001,
   48 kHz stereo 24-bit PCM. Qualify this actual modified-default LT recipe, not
   the prepared HQ preset or all ProRes profiles. WebM also succeeded: C6 job
   `67F333E0-FE7A-4024-A9EA-BCB27C14E98E` published `test_vp9.webm`, FFmpeg exit 0,
   sampled verification passed, C5 done at 182/182. Agent full video/audio decode
   passes: VP9 Profile 2, 10-bit 4:2:0, 1920×1080 / 30000/1001, 182 frames,
   48 kHz stereo Opus. This was the owner's structured default edited to VP9 CRF 31,
   deadline good / Opus 192k / `-f webm`, not the prepared Advanced realtime preset.
   FFprobe establishes only the shared Matroska/WebM demuxer family.
   No preset-load bug or complete qualification is established. Do not resume
   MXF/MKV/filter/switching/template restart testing without new owner direction.
   Progress window is enabled again in isolated C7 (revision 7), as requested.
   Owner left encoder-error integration into VEGAS separate; do not continue that
   investigation. Deferred performance comparison and extra recovery stay deferred.
2. **Dashboard implementation is complete at checked scope.** Settings consumes
   `VegasInstallations.inspect()` through `ve_services`, with direct Windows API
   inspection on a worker isolate and no PowerShell/host/exporter launch. It reports
   actual host/DLL versions and paths, supported installed-manifest byte coverage,
   unknown/unreadable/changed states and Refresh. App/shared-runtime coverage and
   detected-host compatibility stay separate. 26 real Windows API fixture checks,
   12 existing Settings widget tests, 1 display unit check, 3 new widget tests and 24 light/dark golden
   checks pass; intended images were reviewed. App/service analysis is clean.
   No install/repair/uninstall feature or future installer schema was added.
3. **Latest matched installer handoff is prepared.**
   `build/release-inputs-profile-list` includes the Profile-list refinement.
   Optimized native and Windows release app builds pass, with matching 0.1.7/1
   stamps. All 24 staged sizes/hashes verify; native SHA-256 is
   `8B9DB29B9A8DEC012A6C6A908B849F79327946B2107BBBDEE64C6044CFB9D201`.
   It records source `c8e6e39` plus `sourceDirty:true`, not release qualification;
   no installation or new real-host result is claimed. Prior 63 packaging and
   functional/UI checks are reused rather than rerun. The installed
   `build/release-inputs-containers-dashboard` remains intact with its exact
   five-file rollback, isolated data and logs; its DLL still matches its old hash.
   Progress window remains enabled at owner request. Old platform
   data/candidates/logs/rollback remain intact. The owner builds/tests Inno Setup;
   runtime deployment policy, project licensing and release signoff remain open.

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

Read the current scope above, STATUS, CONTRACTS C3, UI_SPEC §6a,
NATIVE_CONTAINER_PLAN and CONTAINER_TRIAL. The owner closed the active container
test queue after confirming all-container value handoff. Fresh matched inputs,
including Profile-list UI and central versions, were staged in
`build/release-inputs-central-versions-current`; subsequent source changes require
another unified build before the owner's installer build. The owner requested the current local source
checkpoint; future commits still require owner authorization. Existing bundle
manifests retain their earlier `c8e6e39` / `sourceDirty:true` creation state; do not
rewrite them after committing. Re-stage to a fresh directory when a clean-source
installer input is needed. Build/output instructions are in [BUILDING.md](BUILDING.md).
Do not report skipped/static/fake checks as real VEGAS support. No further feature implementation is queued unless
a material defect appears in these two retained features. Preserve the new
work, the checkpoint, all installed/trial/rollback files and old
worktrees. No installer build, new general enhancement, deferred trial, commit,
push or installation without its required owner direction.

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
| VEGAS installation/status dashboard | Implemented and checked through service/native/UI/fake paths. See STATUS and CONTRACTS C3. Installer remains owner-owned; shared-runtime and host compatibility are not implied by manifest verification. |

Historical sources: [app Needs](product/workstreams/app.md#needs-from-platform),
[app Open items](product/workstreams/app.md#open-items),
[platform handoff](product/workstreams/platform.md#limits--app-handoff) and
[installer inputs](B7_INSTALLER_INPUTS.md). Old manual file-dialog observations,
IME/autocomplete placement notes, log-opening preferences and library-load UI
observations remain review references, not newly reproduced bugs. Full app budget
qualification and owner-deferred monitor measurements retain their recorded scope.

## Owner scope and operational continuity

- Installed trial: containers/dashboard 0.1.7 on VEGAS 2026.0.3.189, authorized
  2026-10-18. Its INI points to `build/release-inputs-containers-dashboard` here.
  The exact previous template-name-fix INI/binaries/manifest/discovery are in the
  new trial's `rollback/`; its referenced platform app/log/data paths remain intact.
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
  Future commits/merges still follow owner authorization. Current trial installation
  was separately authorized; further replacement still needs owner direction. No
  push, machine-tool upgrade, AV exclusion, sanitizer or old process/thread investigation.
