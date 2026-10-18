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
colours. No `flutter_launcher_icons` dependency is needed. The owner-requested
README refresh now uses the icon, app-first documentation and two compact UI
previews, with developer instructions at the bottom. Installed candidates remain intact.

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

**Latest installer fix (2026-10-18):** the owner's startup error is fixed by
separating path-independent detection/validation requests from app lifecycle
requests; `InitializeWizard` no longer expands the early `app` constant. An
unprivileged, abort-before-install Inno harness exercises the actual scripts and
read-only detection. All **36** confined native helper fixtures pass. App/core
component records now retain separate instance GUIDs, versions and paths under
protected ProgramData, with exact transactional rollback and cross-app ownership
guards. Keep the combined setup AppId stable. The current wizard still manages
one VEGAS 2026 target; future split/multi-host installers must explicitly migrate
uninstaller ownership and app dependencies (see [INSTALLER.md](INSTALLER.md)).
This does not authorize installation, commits or new host compatibility claims.
The full release rebuild and Inno compile pass into fresh
`build/release-inputs-setup-identity` (32 files); **81** packaging/detection checks
and **5** frozen-input refusal checks pass. Latest corrected installer:
`dist/VegasEncoder-0.1.7.1-windows-x64-setup-20261018-132157171.exe`, with its
hash/provenance sidecar. Product Setup was not run and no live trial was changed.
Next deployment gate remains the controlled real installer trial below, requiring
owner direction; the launch-only harness does not close it.

**Current owner-requested build/installer consolidation:** pre-work changes were
committed as `586c7c6`. Root `version.json` remains authoritative; the generated
Inno include now lives in `setup/version.generated.iss`. Finished builds share
`build/release/vegas-encoder/{app,core,plugin,setup}`. Flutter's intermediate
output stays in its normal folder; the unified command publishes the runtime.
All `.iss` sources are under `setup/`, split into helper, host-selection and
lifecycle modules. App is required; VEGAS 2026 integration is optional, with
registered detection, manual Browse, executable validation, exact ownership/hash
checks and retained rollback transactions. See [installer behavior](INSTALLER.md).

`scripts/Build-Release.ps1` All/Package now compiles a verified frozen bundle to
`dist/` using the existing Inno compiler; it never runs Setup. Build is compile
only. Source/output receipts include setup inputs and the helper. Current work
is uncommitted; do not commit again without owner direction. Preserve concurrent
README work and all old bundles, worktrees, installed candidate and rollback.

Focused checks pass: 26 confined native helper fixtures (including Unicode INI
reads through Windows, update/adoption, rollback, uninstall, running-process and
junction guards); 15 fake-file build/publish receipt guards; 5 frozen-input refusal
checks; 8 central-version tests and actual Inno 6.7.1 no-output script compilation.
The final All build/installer compilation passes into `build/release-inputs-setup-final`
(32 file records; 80 packaging/detection checks). Package-only also passes into
`build/release-inputs-setup-repack` without rebuilding product binaries. That
earlier installer was `dist/VegasEncoder-0.1.7.1-windows-x64-setup-20261018-033807001.exe`,
with its hash/provenance sidecar. Actual production-helper read-only detection
finds the installed 2026.0.3.189 host; this is detection, not installation testing.
The rebuilt plug-in passes 62 naming checks with a fake host.
No Flutter UI changed; existing app light/dark goldens were not repeated.
This does not reopen skipped enhancements or owner-deferred host trials.

The owner reduced the remaining scope on 2026-10-17 to native multi-container
support and the read-only VEGAS installation/status dashboard. Both now have
producer/consumer implementation and focused offline checks. Everything else
unfinished remains skipped. The later installer request above supersedes the
earlier owner-only installer scope.

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
   data/candidates/logs/rollback remain intact. The later installer implementation
   above supersedes the earlier owner-only build scope; real installer qualification,
   project licensing and release signoff remain open.

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

Read the current scope above, STATUS, [BUILDING.md](BUILDING.md) and
[INSTALLER.md](INSTALLER.md). Complete only material defects in the retained
features/build/installer. Next deployment gate is a controlled real Inno
install/update/uninstall trial with fresh and known-owned inputs, a custom
VEGAS 2026 path, closed/running processes and a missing-runtime machine/VM.
Compiler/helper fixtures do not close that gate. Do not run/install Setup,
replace the live trial, publish or request deferred VEGAS trials without new
owner direction. The owner closed the active container test queue.

New installer bundles are not installed or release-qualified. Preserve all prior
candidate manifests as records of their creation state; never rewrite them after
committing. Rebuild/stage a fresh directory for a clean-source release. The
installed `build/release-inputs-containers-dashboard` and its five-file rollback
must remain intact. Future commits require owner direction; no additional
feature implementation is queued.

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
