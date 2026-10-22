# Vegas Encoder status

Updated: 2026-10-23 (Asia/Singapore). No exporter currently installed: the owner
requested removal of the development trial and a clean state for installer testing.

## Current progress

**Expanded starter presets (owner request, 2026-10-23):** the shared catalog now
provides 16 app built-ins and 16 fixed VEGAS starters, plus the preserved general
settings template. Added quick-review H.264, H.264/AV1 NVIDIA GPU, ProRes LT/Proxy,
VP9/WebM, x264 CRF 16, x265 CRF 16 and NVENC H.264 720p at a 3500 kbps video
target; the existing NVIDIA HEVC app recipe is now also a VEGAS starter. All
seven previous app recipes and six previous VEGAS GUIDs/slots remain unchanged;
new VEGAS entries append at slots 8-17. The [settings table](STARTER_PRESETS.md)
records exact defaults. The 720p starter fits/pads to 1280x720 without stretching
at the source frame rate, with AAC 160 kbps additional to the video target.
Other presets, including ProRes Proxy, retain project dimensions/rate.

Focused validation: optimized native release build; **357** actual-DLL fake-host
enumeration/origin/compile/conformance/naming/allocation checks; **154** real-file
repository checks; **99** library-watch/cache checks at 500 presets; **39** app
preset/popup/widget/golden regressions, with eight light/dark images reviewed;
and app/service analysis. All pass. With user-supplied gyan FFmpeg **5.1.2**,
**93** runtime checks pass, including **17** core-generated synthetic encodes,
readbacks and full decodes. The AV1 NVENC encoder is absent from this build:
the test confirms pre-encode refusal, not an AV1 GPU encode pass. Additional
direct core-generated encodes verify 1280x720 output from widescreen, 4:3 and
portrait fixtures; decoded pixels confirm black pillarboxing for the latter two.
New metadata uses the library's required UTC timestamp format. The watch fixture
keeps 500 total entries regardless of bundled count; runtime reporting separates
successful encodes from unavailable-encoder refusals.

This is offline synthetic media/real core/files/GPU plus fake-host/UI validation,
not new real-VEGAS qualification. Expanded starter visibility/save/restart and
AV1 GPU encoding remain unqualified. No installation, source commit or new
installer bundle was performed by the starter expansion; previous bundles and
rollback backups remain intact. Owner-deferred host trials stay deferred.

**Installer modes and multiple VEGAS versions (owner decisions, 2026-10-23):**
implemented the behaviour in [INSTALLER.md](INSTALLER.md).
- **Modes:** the wizard picks install, update, maintenance (Modify / Repair /
  Uninstall) or blocked from the installed app version, and refuses downgrades.
- **Integrations page:** the old Components and folder pages are replaced by one
  checklist row per detected VEGAS version. Only VEGAS Pro 2026 is supported;
  other versions are listed disabled. All installed exporters always update with
  the app. A warning dialog appears when nothing is ticked.
- **Records:** the ProgramData installation records are authoritative.
- **Lighter ownership:** setup overwrites or removes its own exporter files instead
  of refusing when they were changed by hand. A hand-deleted DLL counts as removed.
- **Running programs:** listed by name, with Retry.
- **Theme:** `WizardStyle=modern dynamic polar` follows Windows light/dark.
- **Silent installs:** `/VEGAS=` and `/VEGASDIR<version>=` replace `/COMPONENTS`
  and `/VEGASDIR`.
- **Unchanged:** the per-VEGAS `install-manifest.json` format the Settings
  dashboard reads.

Focused checks pass:
- **38** confined helper fixtures;
- the unprivileged Inno harness, which uses real read-only detection, builds the
  page in install, update and maintenance variants, and aborts before installing;
- an Inno 6.7.1 compile of the product script into a scratch folder against an
  existing staged bundle.

The production helper's read-only detection on this machine finds VEGAS Pro
2026.0.3.189 (supported) and VEGAS Pro 23/22/21/13 (listed as unsupported), with
no installation records.

A full Build-Release run compiled the native code, the helper and the app, then
stopped at its source-freshness guard. The starter-preset sources were being
edited concurrently, so no new installer was packaged. Setup was not run, nothing
was installed and nothing was committed. Real install/update/repair/uninstall,
page layout and light/dark rendering remain unqualified.

**Shared starter presets (owner approval, 2026-10-18):** the exporter now supplies
H.264/MP4, software H.265/HEVC 10-bit/MP4, AV1 10-bit/MKV, ProRes 422 HQ/MOV,
DNxHR HQ/MXF and lossless FFV1/MKV, plus the preserved general settings template.
A shared `schema/builtin-presets.v1.json` generates app recipes and native rows;
the original six app recipes retain their exact settings/metadata, with software
HEVC added as the seventh. Native snapshot recipes are normalized by the C++ core
and carry matching origin IDs/revisions. Stable GUIDs/indices distinguish supplied
templates; project dimensions/rate remain inherited. Setup deploys defaults with
the binaries, without copying `.sft2` files, changing user library presets or
refreshing saved settings. Explicit popup Update from library adopts new revisions.
User pinning remains outside this fixed-list implementation.

Focused checks pass: **180** actual-DLL fake-host enumeration/origin/GUID/container/
conformance/allocation checks, including native-target compilation of all six
starters; **3,104** native core checks; **154** real-file library repository checks;
**99** library watch/cache checks at 500 presets; app/service analysis; and **45**
popup/widget/golden regressions, including five new widget cases and six reviewed
light/dark images. A newer bundled revision leaves saved local settings unchanged
until explicit update in the popup. Historical B0 fakes remain unchanged. These
checks use the real core/files and fake host/UI services, not real VEGAS; new
starter-list visibility and save/restart remain unqualified. No installer was run
and no installed files were changed by this implementation. The prior clean-state
backup remains intact.

The complete native/helper/Windows-app rebuild and Inno **6.7.1** compilation pass
into `build/release-inputs-default-presets` (**32** file records), with **81**
packaging/detection checks and **5** frozen-input refusals passing. Installer:
`dist/VegasEncoder-0.1.7.1-windows-x64-setup-20261018-223603890.exe`
(12,634,949 bytes), SHA-256
`CC59797F9C2042777FF4F0155FF6012ABE5EFA334B909D0CCA6CB785B7E54974`.
Its sidecar records source `8bc962b` plus `sourceDirty:true`, `installed:false`
and `releaseQualified:false`. The source-freshness guard correctly refused the
initial build while new golden files were being written; the final run held source
steady. No commit or installation. Real installer and new-starter host checks
remain open; owner-deferred trials are not resumed.

**Clean installer-test state (owner request, 2026-10-18):** uninstalled the
containers/dashboard development exporter from VEGAS 2026.0.3.189 using the
manifest/hash-checked development uninstaller. Archived all six saved Vegas
Encoder `.sft2` test templates, normal roaming settings, local cache/sessions
and legacy diagnostic logs outside their active paths. Exact installed files,
ownership manifest and discovery config were backed up and hash-verified first.
Backup and restoration instructions:
`C:\Users\Samuel Tee\AppData\Local\VegasEncoderInstallerTestBackup\20261018-clean-start\RESTORE.txt`;
the adjacent `reset-manifest.json` records the original paths. All six active
installation/data/template paths are confirmed absent; the 12 unrelated VEGAS
templates/favorites files are hash-verified unchanged. No setup app/uninstaller
registration or ProgramData product catalog was found. Other four registered
VEGAS hosts had no Vegas Encoder installation. Existing candidate builds, isolated
trial profiles and earlier rollback files remain intact. This was real installed
filesystem cleanup with VEGAS closed; no installer run or render qualification.
The prepared installer remains in `dist/` for the owner's test. Nothing committed.

**Scripts organization (owner request, 2026-10-18):** the installer/source
checkpoint was committed and pushed as `392493d`. Routine human entry points
remain at the top of `scripts/`: `Build-Release.ps1`, `Build-Installer.ps1`,
`export_app_icons.bat`, `Get-VegasTargets.ps1` and the development-only
`Install-VegasEncoder.ps1`. **52** supporting build/generator/test/trial scripts
now live under `scripts/etc/`. [scripts/README.md](../scripts/README.md) describes
the commands. Repository-root calculations, sibling calls, Dart native-hook
imports, generated-source provenance and active documentation follow the move.
Historical experiment/component-handoff commands and frozen bundles retain
their recorded paths. The raw checker self-test now defaults to ignored
`build/test-results/` rather than creating another evidence tree.

Focused checks pass: **8** version tests, **15** fake-file receipt guards,
**36** confined setup helper fixtures, the manual installer's fake-tree checks,
**295** B0 fixture checks, **180** B1 data checks, core argv golden freshness,
B0/service built-in freshness, raw-render checker self-test, icon `--check`,
read-only VEGAS detection and PowerShell parsing. The old B3 parser-fixture
generator could not run because its historical
`build/ffmpeg-b1/capture-old/version.txt` input is absent; no capture was
regenerated or historical source changed. No app UI behavior, live installed
exporter or real-VEGAS qualification changed.

The full native/helper/Flutter release build and Inno **6.7.1** compilation
pass through the reorganized scripts into `build/release-inputs-scripts-layout`
(32 files). All **81** packaging/detection checks, **5** frozen-input refusal
checks and the relocated non-installing wizard harness pass. New compiled
artifact: `dist/VegasEncoder-0.1.7.1-windows-x64-setup-20261018-140036555.exe`,
with its hash/provenance sidecar; it is not installed or release-qualified.
No runtime dependencies or Flutter UI changed, so widget/golden suites were
not repeated for this path refactor.

The full native/helper/Flutter release build and Inno **6.7.1** compilation
pass through the reorganized scripts into `build/release-inputs-scripts-layout`
(32 files). All **81** packaging/detection checks, **5** frozen-input refusal
checks and the relocated non-installing wizard harness pass. New compiled
artifact: `dist/VegasEncoder-0.1.7.1-windows-x64-setup-20261018-140036555.exe`,
with its hash/provenance sidecar; it is not installed or release-qualified.
No runtime dependencies or Flutter UI changed, so widget/golden suites were
not repeated for this path refactor.

**Setup startup fix and component identity (owner request, 2026-10-18):**
the owner-reported `app`-constant error came from `InitializeWizard` calling
the common helper request initializer before Inno had resolved the app path.
Detection/validation now use path-independent requests; install/uninstall use
an explicit app request. A compiled, unprivileged Inno harness runs the actual
wizard scripts and production helper's read-only detection, then aborts before
installation. Wizard initialization passes on Inno **6.7.1**.

The current combined setup and Windows AppId are retained. Separate app and
per-host core instance GUIDs, independent version metadata, paths and app/core
links now live in the protected ProgramData component catalog and existing
ownership manifests. Updates retain IDs; hash-verified legacy manifests are
adopted; another app's core is refused. Exact catalog bytes participate in
backup/rollback/restore/uninstall. **36** confined helper fixtures pass using
real Windows file/INI/process APIs and fake, never-loaded app/host/payload bytes.
They cover custom/separate paths, identity/version persistence, legacy adoption,
catalog tamper/path guards, component removal, rollback and unrelated records.
The launch harness is a non-installing fixture, not a product installation test.

Full native/helper/Flutter release rebuild and Inno **6.7.1** compilation pass
into fresh `build/release-inputs-setup-identity` (**32** file records). All **81**
packaging/detection checks and **5** frozen-input refusal checks pass. The corrected
artifact is `dist/VegasEncoder-0.1.7.1-windows-x64-setup-20261018-132157171.exe`
(12,632,367 bytes), SHA-256
`4A0246E29E096C4784B4112A2CD003C3D4F1F47203450468112F117421308C41`.
Its provenance sidecar records `sourceDirty:true`, `installed:false` and
`releaseQualified:false`. No product Setup was run. Full real install/update/
uninstall and clean-machine prerequisite/locked-file qualification remain open.

The current wizard still targets one VEGAS 2026 installation per app. Multiple
simultaneous targets, other host binaries and split installers remain future
work; their ownership/dependency migration is described in [INSTALLER.md](INSTALLER.md).
No Flutter UI or native exporter behavior changed. Existing installed trial,
candidate/rollback paths and owner-deferred VEGAS checks remain untouched.

**Grouped release outputs and modular installer (owner request, 2026-10-18):**
pre-work changes were committed as `586c7c6`. Finished outputs now share
`build/release/vegas-encoder/{app,core,plugin,setup}`. Flutter retains its normal
intermediates; the unified script publishes its complete runtime, retaining the
previous published copy. Core/native wrappers, receipts and staging use the new
paths. Existing trial/candidate/rollback/worktree paths are preserved.

All Inno sources, including generated versions, now live in `setup/`. Setup
offers the required app and optional VEGAS 2026 plug-in, registry detection plus
manual Browse, x64/2026 executable validation, process closure, runtime prerequisite
checks, ownership/hash/reparse guards and exact file backups. It preserves the
existing per-host manifest format consumed by the read-only dashboard. One
recorded 2026 target is updated/moved/removed with the shared app; older VEGAS
versions remain unsupported. Unknown/modified files cause refusal. User settings,
libraries/jobs/templates/FFmpeg stay intact. See [installer/recovery](INSTALLER.md)
for scope, silent switches, pending-transaction recovery and retained backup paths.

All/Package compile a verified frozen bundle through Inno Setup into `dist/`,
with a hash/provenance JSON sidecar. Build remains compile-only. Setup sources and
the helper are covered by build/staging freshness checks. The final complete All
run passes into `build/release-inputs-setup-final` (**32** file records, **80**
packaging/detection checks). Package-only also passes into
`build/release-inputs-setup-repack` without rebuilding app/core/plug-in.
That earlier installer was
`dist/VegasEncoder-0.1.7.1-windows-x64-setup-20261018-033807001.exe`, with SHA-256
`CC10E2460459BFEC2D06D650C4DEC73083DB00C07B958A0A8D5181A2B8713A8D`;
its JSON sidecar records source commit `6a8e837`, `sourceDirty:true`, bundle/input
hashes and `releaseQualified:false`. No installer was run and the installed trial
was not changed; its DLL retains SHA-256 `9799B6CD...266707`.

Focused checks: **26** native helper fixtures pass using real Windows file/INI/
process APIs with fake app/host/payload bytes confined under build/test-results;
**15** fake-file receipt/publishing guards, **5** frozen-bundle refusal checks,
**8** version fixtures and actual Inno **6.7.1** no-output compilation pass.
The rebuilt plug-in also passes **62** naming checks with a fake host. The actual
production helper's read-only registry/executable check detects one eligible
VEGAS **2026.0.3.189** installation; it does not mutate or qualify that host.
These checks do not establish real installer or VEGAS compatibility. No Flutter
UI changed, so existing app light/dark goldens and passed encoding suites were
not repeated. Real Inno install/update/uninstall, clean-machine prerequisite/
locked-file behavior, signing/project licensing and release signoff remain open.
Owner-skipped/deferred VEGAS trials remain skipped/deferred. This supersedes
earlier owner-only setup scope and previous output-layout notes below.

**README refresh (owner request, 2026-10-18):** the root README now leads with
the app, requirements, actual VEGAS compatibility scope, encoder profiles and
GitHub installer download instructions (Setup is still being prepared). It uses
the selected icon and two compact
light/dark previews from existing Flutter golden captures, labelled as test data.
Developer setup, build/version/test instructions, repository layout and a simple
architecture diagram follow at the bottom. Local links/anchors and referenced
script names pass checks; both preview images were visually inspected and
`git diff --check` passes. No app code, runtime tests, installation or real-host
qualification changed.

**Release output folder (owner request, 2026-10-18):** the product exporter now
builds into `build/release/vegas-encoder`, selected by `build.cmd "" release`.
The unified build, packaging defaults, receipts and naming runner use this path.
The old `recipe-proof` argument is a compatibility alias that also writes to
`release`; no existing legacy folder, installed candidate or rollback was moved
or deleted. Runtime version values are unchanged. The unified native/app release
build and staging pass. All **25** staged sizes/hashes verify in
`build/release-inputs-release-folder`, with the packaged DLL matching the new
release output. New receipts contain only the new path and pass validation;
**11** fake-file receipt guards and **62** candidate-DLL naming checks (fake
host, no real VEGAS) pass. The old folder remains intact. Native SHA-256:
`84AFD4D18A7FFFB6B6D4913E70BCA0CC7B7278BDB6324C2C3869558951118ACF`.
No UI/encoding behavior changed, so passed UI/engine suites were not repeated.
No installation or existing bundle/rollback mutation was performed.

**Setup version wiring (owner request, 2026-10-18):**
`setup/setup_script.iss` now includes `config/version.generated.iss` from the
central JSON build projection. Its display `AppVersion` uses `VeReleaseVersion`
and Windows `VersionInfoVersion` uses `VeFileVersion`; the wizard's hardcoded
`1.5` is removed. The installed Inno Setup compiler accepts the actual script
with output disabled. Isolated copies also resolve current `0.1.7` / `0.1.7.1`
and changed JSON `2.3.4` / `2.3.4.17` correctly. No installer executable was
created or run. This only wires versions into the owner's existing setup script;
it does not qualify installer/deployment behavior or change installed files.

**Selected app icon and generation workflow (owner request, 2026-10-18):**
option A is maintained at `app/assets/icon/app_icon.svg`. One command,
`scripts\export_app_icons.bat`, uses existing Inkscape and Python's standard
library to export a 256 px PNG, `docs/assets/app-icon.png` (512 px, ready for
Markdown), and the runner's Windows ICO with nine directly rendered sizes
(16/20/24/32/40/48/64/128/256). `--check` regenerates temporarily and detects stale
outputs. No Flutter dependency was added: existing `Runner.rc` embeds the ICO.
The already-matching title-bar painter retains its light/dark theme behaviour.
The main README's icon edit awaits the owner's instructions.

Validation: actual Inkscape generation and reproducibility check pass; missing
renderer reports a nonzero error. All nine frames decode and load using real
Windows `LoadImageW`; PNG dimensions/alpha and ICO offsets/payload bounds pass.
The 512 px Markdown image was visually reviewed. **47** existing icon/window/
design-system tests pass with fake core/services, including unchanged light/dark
goldens. Windows release app build passes; resource readback confirms all nine
embedded PNG frames match the generated ICO byte-for-byte. No app/VEGAS launch,
installed candidate replacement, release staging or new real-host qualification
was performed for this icon change. Generation details: [icon workflow](../app/assets/icon/README.md).

**Central versions and release workflow (owner request, 2026-10-18):**
`version.json` now owns release/build/exporter labels, core runtime/package/ABI/
schema/contract stamps, services package metadata and retained legacy proof labels.
Generation feeds native/Dart constants, pubspecs and a setup include. The unified
`Build-Release.ps1` supports All/Build/Package, configured tool paths, fresh output
directories and build receipts that reject changed version/source/output inputs.
It never installs, replaces a candidate or runs setup. Current version values are
preserved; this is not a new real-host compatibility result. Validation passes:
**8** Python version/projection tests (including a changed release/core/ABI and
invalid/stale inputs), **11** fake-file receipt/output guards, **66** packaging/
detection checks, **5** native-core/version compatibility unit checks and **2**
unchanged About light/dark goldens. App/core/services analysis is clean. The
end-to-end default command completed native + release app builds and staged
`build/release-inputs-central-versions` with **25** hash-covered inputs, including
`installer/version.iss` and resolved version metadata. Native SHA-256:
the final rebuilt handoff's hash is
`4280015FA103274D34D949791BBFC52BC64BA3ADF6CAF2901A5E4AA3B5D8036C`.
Manifest records `b5d66de`, `sourceDirty:true`, no installation/release qualification.
The subsequent Package-only attempt correctly refused changed source after
concurrent icon work added files and changed the runner icon; it created no output
directory. The All path exercised the same receipt check/staging successfully
before that source change. A subsequent full rebuild incorporated the current
icon and staged **`build/release-inputs-central-versions-current`**, followed by
a successful Package-only run into `build/release-inputs-central-versions-repack`
without recompilation. All 25 final staged sizes/hashes verify. The current build
receipt reflects that final build; do not rewrite it to bypass future source/
output changes. Existing owner-skipped/deferred
trials remain unchanged. New changes are uncommitted after checkpoint `b5d66de`;
the concurrent icon work (`docs/product/design/icon-options/`, `app/assets/icon/`,
runner icon and icon-export scripts) is preserved. No broad engine/host render
suites were rerun. Installed trial/candidate/rollback files remain intact.

**Owner-requested source checkpoint (2026-10-18):** the owner requested committing
all current source changes, including containers, dashboard, Profile-list UI,
tests/goldens and documentation. This changeset records that local checkpoint;
no push or installed-file change is authorized by it. Existing bundle manifests
remain the original `c8e6e39` / `sourceDirty:true` staging records. A fresh staging
directory is needed to record the new clean commit. [BUILDING.md](BUILDING.md)
maps component responsibilities, exact commands and finished output locations.

**Owner closes the container test queue (2026-10-18):** the owner reports checking
every supported container and confirms the correct values are passed to VEGAS.
This is real-host owner confirmation for MKV/MP4/MOV/WebM/MXF value handoff on
the installed 2026.0.3.189 trial. The owner elects to skip the remaining MXF render
and MKV regression; these are **skipped, not passed**. MP4/MOV/WebM successful
render/readback evidence below remains at its actual recipe scope. The distinct
two-container save/restart sequence remains unconfirmed; do not automatically
request it or resume deferred tests. No further container test is queued. The
fresh matched handoff is prepared below; next is the owner's installer build.
All installed trial and rollback files stay intact.

**Previous installer inputs, before version consolidation (2026-10-18):**
`build/release-inputs-profile-list` contains the containers/dashboard implementation
and shared Profile-list refinement. Native optimized rebuild and release app build
pass, matched at 0.1.7-recipe-proof / 0.1.7+1 (numeric 0.1.7.1). Staging's version
guard rejected an initial app build with its default 0.1.0+1 stamp; rebuilding with
the documented 0.1.7/1 flags resolved that before any bundle was created.
All **24** staged file sizes/SHA-256 hashes verify. Native SHA-256:
`8B9DB29B9A8DEC012A6C6A908B849F79327946B2107BBBDEE64C6044CFB9D201`.
Manifest records checkpoint `c8e6e39`, `sourceDirty:true`,
`installedByPreparation:false`, `releaseQualified:false`, and the actual skipped/
unconfirmed/deferred checks. Earlier 63 packaging, functional and UI checks remain
reused; no broad suites were repeated for this metadata/staging pass. The installed
trial's DLL still matches its prior hash. This new bundle is **not installed** or
newly real-host qualified, and carries no trial data/rollback. Source remains
uncommitted at staging time; owner installer/runtime policy/license/release signoff remain open.

**Owner-requested Profile refinement (2026-10-18):** the desktop and VEGAS popup
share `VideoPanel` and the existing `VeSelect` / `VeListbox`. Profile-based encoders
now use a list instead of cramped segments. All six ProRes profiles have readable
labels and short descriptions paraphrased from [Apple](https://support.apple.com/en-us/102207),
authored once in the core catalog and reused by design fixtures. At the owner's
correction the encoder name remains **`prores_ks`**. Encoder/profile IDs, defaults,
argv and input precision are unchanged. This refinement is not installed in the
current trial; its paths and files remain intact. **Six** focused widget tests
pass on the native core with fake platform services: desktop/popup selection,
Reset and keyboard editing retain the generated profile value; DNxHR also uses
the shared list when descriptions are absent. **Ten** light/dark golden images
pass and were visually reviewed (including minimum popup/narrow desktop). The
two existing ProRes audio goldens remain unchanged and pass. App/core-package
analysis, generated-data freshness and Windows release app build pass. Package
analysis initially lacked local dependency configuration; offline cached restore
resolved it without a tracked lockfile/dependency or SDK change. No real-host UI
qualification or new installation is claimed from these tests.

**Owner-authorized installation (2026-10-18):** installed
`build/release-inputs-containers-dashboard` using the reversible development
installer after confirming VEGAS/Encoder were closed. All 24 candidate inputs,
five exact rollback/baseline files and the unchanged target host hash were checked
before mutation. Installed DLL/INI/PDB now match the candidate; installed-manifest
and discovery hashes verify. INI app/log paths select this original-checkout
candidate. The direct Windows service reports the installed covered files verified.
The prior platform template-name-fix candidate/data/logs and all rollback files
remain intact. VEGAS was launched with the new isolated, progress-window-off
profile. Owner confirms the Render As filename changes to **`.mp4`**. First two
attempts did not qualify a successful MP4 render: `test.mp4` already existed
(0x80070050, preserved); `test_mp4.mp4` used a modified default recipe (`vegas-mkv`,
H.264 plus `pcm_f32le`, not the prepared H.264/AAC trial preset). FFmpeg 5.1.2
rejected PCM float in MP4 and exited 1; C6/C5 record the actionable codec message,
HRESULT 0x8007006D and `published:false`. No final second output was left. Since
the isolated profile disables the progress window, only VEGAS's generic error
was visible; this does not qualify live failure presentation for this trial.
The owner then changed audio to AAC and reports success. C6 job
`C24475AA-4C26-420B-9D5C-C4E1C5D81795` records S_OK, successful publication and
passed sampled verification for `C:\Users\Samuel Tee\Desktop\test_video\test_mp4.mp4`.
Agent readback counts **182 video frames, 1920×1080, 30000/1001 fps**, H.264
10-bit 4:2:0 and 48 kHz stereo AAC; full video/audio decode passes without errors.
This used the modified default recipe with **faststart:true**. The output has
`moov` at byte 32 before `mdat` at byte 8106, confirming faststart for this render. The owner requested keeping the progress window: isolated C7 now
has `progressWindow:true` (revision 7), with other settings preserved and its
prior snapshot saved in the candidate rollback folder. VEGAS error-text integration
is left separate at the owner's direction. Performance comparison and extra
failure-recovery trials remain deferred. The owner also confirms MOV rendered
correctly. C6 job `0DA59B34-CD66-4153-A21B-08267D4CA81E` published
`C:\Users\Samuel Tee\Desktop\test_video\test_mov.mov`; agent full video/audio
decode passes. Readback is **ProRes LT**, 10-bit 4:2:2, 1920×1080, 30000/1001 fps,
182 frames, with 48 kHz stereo 24-bit PCM (6.073 seconds). This was the owner's
modified-default recipe, not the prepared HQ preset; other ProRes profiles are
not thereby qualified. The owner also confirms WebM completed. C6 job
`67F333E0-FE7A-4024-A9EA-BCB27C14E98E` succeeded and published
`C:\Users\Samuel Tee\Desktop\test_video\test_vp9.webm`; FFmpeg exited 0,
sampled verification passed and C5 ended `done` at 182/182 frames. Agent full
video/audio decode passes. Readback: **VP9 Profile 2, 10-bit 4:2:0**, 1920×1080,
30000/1001 fps, 182 frames, 48 kHz stereo Opus, 6.080 seconds, 726,231 bytes.
This used the owner's structured modified-default recipe (`libvpx-vp9`, CRF 31,
`-deadline good`, `libopus` 192 kb/s, `-f webm`), not the prepared Advanced
realtime preset. FFprobe identifies the shared Matroska/WebM demuxer family;
this readback alone does not distinguish those two container identities.
The later owner confirmation above closes the active test queue. No complete naming
or all-container qualification is claimed from these MP4/MOV/WebM results.

**Retained features implemented at offline scope (2026-10-18):** pre-existing
changes were committed at the owner's request as `c8e6e39`; the subsequent naming
and dashboard work was initially uncommitted in this original checkout and is
included in the later owner-requested checkpoint above. The later installation
is recorded separately above. No push, new worktree or old-worktree deletion.

- Recipe writer advertising is now `*.mkv;*.mp4;*.mov;*.webm;*.mxf` (MKV first).
  The exact 2026 MP4 writer's ID-4 table establishes semicolon syntax. Its slot-17
  selector **11**, corroborated by host callers, returns a template-specific
  UTF-16 wildcard with capacity in WCHARs. Our callback uses the shared core's
  active-command suffix, including Advanced; it performs no machine-settings or
  library reads. Other selectors and historical fixed-profile proofs keep their
  prior behavior. See [static ABI chain](product/NATIVE_CONTAINER_PLAN.md).
- Settings now includes a read-only **VEGAS integration** dashboard: detected host
  name/version/executable, exporter version/paths, discovery and installed-manifest
  paths, hash verification, expandable selectable details and explicit Refresh.
  Missing/changed, unverified/unsupported manifest, unreadable and empty/partial
  discovery states stay distinct. Old verified claims disappear during refresh;
  errors wait for explicit retry. The package calls direct Windows APIs on a worker
  isolate, with no PowerShell/host/exporter launch or install/repair writes.
  Only recorded DLL/INI/optional PDB/discovery bytes are verified; app/shared-runtime
  coverage and host compatibility stay separate. Current-machine read-only scan:
  five hosts; the installed 2026 trial's recorded hashes match its manifest,
  four older hosts have no exporter; stale registration problems remain visible.
- Focused checks pass: **62** actual candidate-DLL naming assertions with a fake
  allocator/host; **26** real Windows API/temporary-installation service checks
  (including same-version changed bytes, malformed/escaping/duplicate manifests,
  missing/unrecorded files, locked-manifest isolation/recovery and input bounds);
  **12** existing Settings widget tests and **1** display unit check, plus
  **3** new dashboard widget tests;
  **24** golden checks (18 new dashboard states and six Settings, light/dark).
  All new dashboard images and the two changed Settings About images were
  visually reviewed. Final app/service analysis is clean. Optimized native and
  Windows release app builds pass; prior passed core/engine/fake-host FFmpeg
  container suites were reused because their pipeline did not change.
- Matched candidate: `build/release-inputs-containers-dashboard`, native
  0.1.7-recipe-proof / app 0.1.7+1 (numeric 0.1.7.1). **63** packaging checks pass.
  Native SHA-256:
  `9799B6CD65528101788658F4CCE59354BC8BAC6D4796A6670D0A18D2D0266707`.
  Manifest records `sourceCommit:c8e6e39`, `sourceDirty:true` and
  `releaseQualified:false`. Five exact installed rollback files are hash-checked
  under its `rollback/`; new isolated trial settings and five validated container
  presets are prepared. The profile initially disabled the progress window; the
  owner requested it enabled again. This does not resume the deferred performance
  comparison. Installed paths now
  select this candidate; platform candidates/data/logs and prior rollback are intact.

**Qualification limits after owner acceptance:** the owner confirms all five
containers pass the correct values to VEGAS. MXF render/MKV regression are
owner-skipped; two different containers saved/reopened after restart remain
unconfirmed. No new pass is inferred from static inspection, mocks or FFmpeg/fake-host
checks. These are recorded limits, not an active test request. The installer
remains owner-owned. Existing deferred recovery/progress trials, exact large-template
restart uncertainty and broader A5–A8/performance/support limits below stay unchanged.
See [focused owner checklist](CONTAINER_TRIAL.md).

**Owner scope reduction (2026-10-17):** keep the implemented product and finish
only two unfinished product features: MP4/MOV/WebM/MXF in VEGAS alongside MKV,
and a read-only VEGAS installation/status dashboard. The owner makes the finished
installer; agents supply matched inputs and documentation. Other unfinished
enhancements are skipped for this release, including revision browsing/restore,
native extra inputs/complex graphs, new popup project/path extraction, richer
native-page shortcuts, pinned Render As presets, per-preset FFmpeg override,
log-management extras and the remaining wishlist. Existing internal history,
conflict handling, template snapshots/diff/update, logs and sample fallbacks remain.
This changes the product queue, not implementation/qualification evidence. No
code, installation or real-host state changed from this documentation update.
See [current scope](product/PRODUCT_SPEC.md#current-release-scope-owner-2026-10-17)
and [next-agent brief](NEXT_AGENT.md#next-agent-execution-brief).

**Containers and carried-forward integration (2026-10-17):** the owner authorized
three bounded implementation agents, with plans reviewed before coding and one
shared original checkout/queue. That checkpoint is now committed as `c8e6e39`. No installed
candidate, trial data, dependency or machine-wide tool was changed.

- Shared core native-target admission now accepts known MP4/MKV/MOV/WebM/MXF
  recipes with established video/codec scope. C4 propagates the target, so the
  popup shows native errors before Apply. Missing muxers, ambiguous output,
  unsupported stream scope and measured incompatibilities are surfaced by core.
  Actual-media compilation checks again before launching FFmpeg.
- Native rendering preserves the exact selected destination and refuses a
  mismatched suffix before acquiring frames. Advanced preview and native-page/
  popup guidance use the active command's core-produced suffix. Actual edit-time
  Render As path remains unknown. Temporary output retains the final suffix;
  exclusive creation, no replacement and existing cleanup/retention remain.
- Output readback records/checks the demuxer family while retaining the sampled
  32-packet scope. It does not distinguish MP4 from MOV or MKV from WebM or claim
  a full-file decode. At that checkpoint the class still advertised `*.mkv`;
  the later naming implementation above resolves writer syntax, while real UI
  filter/default behavior remains unqualified.
  New-container real-VEGAS renders/persistence remain unqualified. Details:
  [container plan](product/NATIVE_CONTAINER_PLAN.md).
- History Speed now comes from nullable C6 index `realtime`, including recovery
  and fakes. Legacy values stay unknown; detail no longer fabricates speed from
  length/time. Monitor polls for late terminal C6 records until arrival/disposal,
  enabling details/log access without active-render C6/core/library reads.
- Popup warns on plug-in/app release or core-stamp mismatch; unreadable stamps
  remain unverified and Apply is unaffected. Same-stamp hash-distinct development
  builds remain indistinguishable. Preset tests expose plain messages and separate
  error codes. Advanced unfinished-quote chip protection was already implemented;
  the added consumer assertion passes.
- Owner decisions are recorded: preset Test stays desktop-only and lightweight
  (320×180 P010, 30 fps, 60 frames); current quality marks remain without a new
  recommended band. These are no longer v1 decision gaps.

Focused app validation passes: **61** History/monitor and **67** popup/Advanced/
service-boundary unit/widget checks; **8** History, **18** monitor and **23** popup/
warning golden checks. Six changed History and four new popup/warning light/dark
images were visually reviewed; existing popup and monitor images are unchanged.
Final Advanced display/widget/golden checks pass (**57**): the diagram File node
and resolved sample command agree on the active suffix, including extensionless
unknowns. Four affected light/dark Advanced images were refreshed/reviewed.
Final app analysis is clean and the Windows release runner builds against the
final source with existing tools. Native validation passes **3,104** core checks,
**233** real Dart FFI/model checks, **87** fake service-contract and **154** isolated
Windows repository checks, **81** verification-fact and **21** native-runtime
checks. The optimized recipe-proof exporter builds/relinks with the final core.
B6 snapshot/session/page regressions pass **216 / 97 / 124** checks and the fake
monitor-writer check passes. Focused adapter validation passes **120** assertions
using supplied FFmpeg 5.1.2: five short format renders (including MP4 faststart and
Advanced WebM), suffix-only basename, mismatch-before-frames and existing-file
preservation. This is fake-host/real-FFmpeg validation, not real VEGAS.
Native C5/C6 Dart-reader checks pass **111** assertions across seven saved jobs,
including nullable prelaunch facts and exact record/index realtime agreement,
without rerendering. No installation or real-VEGAS qualification was performed.
Existing owner-deferred limits remain unchanged.

**Integration completion pass (2026-10-17):** at the owner's explicit request,
three agents planned bounded tasks before implementation in this original
checkout, with parent integration/review and one current queue. No worktree,
dependency/tool upgrade, installation or real-VEGAS test was performed. The owner
subsequently authorized a local commit of this implementation/fix checkpoint;
push and installation remain outside that authorization.

- File import now opens the `.vepreset` picker, delegates bounded validation to
  `PresetTransfer.importFrom`, creates/selects a new ID and clears filters. Cancel
  and rejected files retain the current selection.
- A package-backed launcher opens the matching desktop executable on a preset or
  job. Native instance handoff is bounded and scoped to the normalized data
  profile; startup/live routes keep their order. Missing targets/launch failures
  are explained. Navigation waits for modal dismissal and complete async preset
  writes, pickers, History-to-preset actions and exit/save flows, preserving drafts.
  Review caught and fixed selection changes beneath an open Save warning.
- The popup restores physical outer size before first show and centres/clamps it
  on its current owner monitor. Apply/Cancel/window close save only size through
  revision-conflict retries, preserving desktop state and unknown fields. Settings
  failures do not prevent close.
- Advanced option/stage/macro styling uses core metadata; the macro panel uses
  `VeCore.macros` with actual recipe/media/paths. Availability uses established
  summary encoder IDs. Unknown metadata remains unknown.
- Monitor depth/reduction comes only from C5; no source/file precision is inferred.
  Desktop-launch failure stays separate from the readable render cause and does
  not change failure retention. Review corrected a cramped launch-error layout.

Focused Windows x64 validation: affected unit/widget files (import, Advanced,
popup placement, monitor, shell/History and cold/warm routing) pass; light/dark
goldens were run and changed images visually reviewed. Final targeted follow-up
passes **94** widget/golden checks, then **12** route/import checks after the
native-picker lifetime guard. The launcher passes **15** captured-process checks;
app analysis is clean. The Windows release runner builds with existing tools.
Tests include a real Save warning with a delayed fake write, queued/native-channel
startup ordering, cancellation of idle waits, settings revision conflicts and
no-core/no-library monitor reads. A single selected Windows `integration` probe
passes **17 assertions** with the real Release app runner and a fake WinForms
owner: startup/warm handoff, equivalent/separate profiles, invalid message refusal,
popup ownership, exact physical size at 120 DPI, oversized work-area clamp and
preserved desktop settings. It uses fresh isolated data and does not run theme,
FFmpeg or VEGAS checks. Reproduce with `run_window_spikes.ps1 -Checks integration
-Runs 1` against the current Release build. This is offline/fake-service/fake-owner
validation; full performance budgets and real VEGAS behavior of these new paths
remain unqualified. Installed trial and all owner-deferred checks below stand.

The earlier read-only container investigation distinguished explicit MKV-only
candidate policy from unresolved host filename/extension behavior. The subsequent
implementation above replaces those policy guards; it does not close native
advertising or real-host qualification gates. Current queue: [NEXT_AGENT.md](NEXT_AGENT.md).

**Owner-authorized commit/merge (2026-10-16):** committed the platform snapshot
as `fd4edb3`, preserving its 34 changed/new files. Verified that all of its runtime,
package and test source changes already match the unified original checkout;
its patch also matches the earlier consolidation backup exactly. Unified commit
`bec50ef` records the workflow/documentation/Advanced-golden version; merge
`01c4756` joins the platform history with an identical consolidated tree. Development is
on local `master` in `L:\repos\vegas-encoder`; the retained platform branch is
advanced to the same merged result so both folders are clean. No remote push,
installed replacement, worktree deletion or new qualification. Existing 558 app
tests/native build/3,055 core checks cover the unchanged implementation; only
workflow/commit-status docs and the local scratch ignore rule changed afterward.

**Unified development (2026-10-16):** owner consolidated app and platform under
one agent in the original `L:\repos\vegas-encoder` checkout, on local branch
`codex/unified-integration`. Master `86aefaf` already included committed app
`493f146` and platform `7a8493a`; the clean app worktree had no missing edits.
The platform's 32 modified files and two new goldens were transferred and
byte-verified before updating workflow docs. Source patch/new-file backup is
under ignored `build/consolidation-backup/`. Old worktrees, `.claude/`, installed
candidate/data/log paths and exact rollback files are retained. No commit, push,
master merge, installation or real-host gate pass is part of consolidation.
New development/builds use the original checkout. One current queue is in
[NEXT_AGENT.md](NEXT_AGENT.md); old app/platform handoffs are historical.

Validation from the original checkout: existing dependency lock unchanged,
clean app analysis, **558 app tests passed**, optimized native /W4 /WX build,
**3,055 native core checks**, and current B1 argv goldens check passed. The first
full app run found ten Advanced screenshots still showing `stats_period 0.5`.
All differences were confined to that digit (7x10 bounding boxes); reviewed
light/dark output and refreshed only those intended 0.2 command-text baselines.
The 14 Advanced golden tests and subsequent full suite pass. **184 local Markdown
file links** resolve and all **26 transferred non-document code/data/test files**
remain byte-identical to the preserved platform source. Restored incidental
generated-file line endings; no dependency/tool upgrade. These are offline checks,
not a real-VEGAS run. Earlier candidate/rollback hashes and trial paths are unchanged.

**Owner defers progress trial (2026-10-16):** leave faster-progress installation/
real-host review and the monitor performance comparison for next time. The candidate
remains prepared; no new installation or qualification pass is inferred. Other
useful work is app adoption of delivered file import, popup-size storage, Advanced
metadata/macro catalogue/encoder IDs and monitor bit-depth facts. Desktop-launch
actions additionally need a platform launcher and running-instance coordination;
the prior blanket claim that all three services were ready was too broad. These
follow-ups precede review/consolidation and the owner's installer.

**Faster progress candidate (2026-10-16, prepared, not installed):** owner wants
the monitor to update faster before measuring overhead. Core-owned FFmpeg
`-stats_period` changes from 0.5 to 0.2 seconds in Basic and Advanced; the independent
C5 writer coalesces ordinary samples every 200 ms (formerly 500 ms), and the C3
live reader polls every 100 ms (formerly 250 ms). Phase/terminal updates still
bypass coalescing, and Render never waits on the monitor/writer. No schema change.
Official FFmpeg docs retrieved with Context7 confirm `-stats_period` controls
`-progress` reporting. An actual two-second FFmpeg run produced 10 intermediate
reports with a 202.7 ms median gap; this is not a real-VEGAS UI latency measurement.

Checks passed: 3,055 native core checks and reviewed argv goldens, 5 Hz writer
wake/coalescing/phase checks with a fake child, 150 real-file C3 repository checks,
24,477 engine checks / 23 fake-host real-FFmpeg and controlled-child cases,
138 adapter checks / 11 fake-host real-FFmpeg cases, 216 snapshot/session,
95 transport, 124 page checks, clean app/service analysis, 50 monitor unit/widget/
light-dark golden tests, and 65 packaging checks. Native optimized /W4 /WX build
passes. Flutter release compilation finished but its final copy was blocked by an
open development app's DLL. The same generated Release install script was directed
to a fresh build folder; assembly succeeded and compiled DLL/AOT inputs were
hash-verified, leaving the running app untouched.

Staged `build/b6-candidate-0.1.7-faster-progress`, same 0.1.7 / 0.1.7+1 stamps,
native SHA-256 `918C22A4F961D4E41883210B37FAF27A4326AE8AEADB26ED0B8C1C1FAA916B0D`.
Trial settings/library/history are copied (active edit sessions excluded), with
five verified exact installed-template-name-fix rollback files. No commit or
installation. Next: owner installs, checks one normal render's responsiveness,
then the existing monitor time/memory comparison. Overhead and real UI cadence
remain unqualified; the earlier deferred/unconfirmed checks keep their scope.

**Large-preset immediate reopen fix (2026-10-16, installed, owner-confirmed):**
owner hit `S-REQUEST, templateName` after Load/Apply/reopen of capacity 16000,
before restart. The draft's native display name is empty; an otherwise accepted
recipe cannot form C4. This does not establish payload corruption or a host size
limit. The native fix uses native name → captured page name → validated recipe
name for C4 display, preserving native text and strict CRC/version/size checks.
The old code reproduces the same error with an intact large unnamed snapshot.
Fixed **216** snapshot/session checks cover exact 4096/8192/12288/16000/16383/16384
envelopes, immediate reopen, missing names, precedence and corrupt CRC refusal.
**124** native-page, **95** transport, **138 / 11** actual-adapter fake-host
real-FFmpeg cases, writer checks, optimized build and **65** packaging checks pass.
These do not establish real-host capacity. Page diagnostics record only label
source and declared byte/text counts; why native text is absent remains open.

Separate `build/b6-candidate-0.1.7-template-name-fix` preserves the byte-identical
error-ui frontend, copied trial data and five exact installed-error-ui rollback
files. Native SHA-256:
`BBB01B74CB88F3CF4A33D0E86B72A9AFC595C1D86DC66E42C8369B3892C606EA`.
Same version labels, hash-distinct variant; installed DLL hash matches. The owner
confirms Load → Apply → reopen now works in real VEGAS. No commit was made.
The latest reopened request (`EAFB2258-877B-4274-9FBB-D13AA08D8821`) has all
15,088 UTF-8 notes bytes, ending `END 容量`, exactly matching the seeded preset,
and FFV1/PCM-float/MKV settings. Notes are not shown in the popup; inspect session
data instead of asking the owner to find them. Confirmation that this reopen
followed saving and restarting is still pending; immediate reopen alone does
not establish the complete persistence sequence.
Encoder-failure recovery remains owner-deferred; other qualification limits stand.

The owner subsequently confirms the preset is visible and appears to work
correctly. Accept this functional check and move to monitor performance without
repeating the notes request. The exact large-template save/restart sequence was
not explicitly confirmed; keep that qualification limit separate from the observed
intact reopened request and owner acceptance.

**Owner qualification scope (2026-10-16):** the owner explicitly skips the
additional same-session good render after encoder failure as excessive for this
stage and proceeds on the working assumption. Record that check as owner-deferred,
not passed; do not request it again without a new relevant failure. Real failure
return/presentation and earlier cancellation/recovery evidence stand. Next is a
lean large-payload persistence check using the prepared 16000-byte input, followed
by monitor overhead/memory and installer work. One intact large sample establishes
a tested lower bound, not an absolute host capacity limit.

**Error UI accepted in real VEGAS (2026-10-16):** the owner installed the
error-ui variant and says it "looks good." The screenshot shows the prominent
missing-filter cause, stay-open label and Close action beside VEGAS's error
dialog. New C6 job `9A1785F2-5243-440D-8C7F-B942F8C807CD` is failed with no
publication; installed manifest/INI and staged frontend hashes match this trial.
Record real-host failure presentation as owner-approved. This feedback does not
establish timed retention/manual dismissal or a successful post-error render;
same-session encoder-failure recovery is still next, followed by capacity and
monitor time/memory. No implementation change or test rerun was needed.

**Error monitor UI follow-up (2026-10-16, prepared, not installed):** the owner
retested the native error fix. Screenshot and C6 job
`16005680-443B-4979-9BBA-DD374003F054` show real FFmpeg failure/no publication,
the concrete missing-filter cause and VEGAS's own error dialog (0x8007006d).
This confirms failure reaches VEGAS; same-session recovery is not yet reported.
At the owner's request the monitor now highlights the authoritative C5/C6 cause
in a prominent error panel instead of trailing stderr warnings. It shows errors
immediately, scrolls long messages, says it stays open until closed, and has an
explicit Close action. Failure cancels any prior auto-close countdown.

Clean app analysis, **558** full app tests (**50** focused monitor checks),
light/dark normal+long-error visual inspection, release build and **65** package
checks pass. UI validation uses fakes/goldens, not real VEGAS. Fresh
`build/b6-candidate-0.1.7-error-ui` keeps the tested native fix and updated
0.1.7+1 frontend, copied trial data and exact installed-error-fix rollback.
Manifests identify this hash-distinct development variant. Installed files and
prior candidates are unchanged; new UI still needs the owner's real-host retest.

**0.1.7 encoder-failure reporting fix (2026-10-16, prepared, not installed):**
the real invalid-filter job `76568149-62D3-43A8-B566-5C62B756BE3C` is failed,
FFmpeg exit 1, no publication. Its stderr identifies the deliberately nonexistent
filter, but the monitor summarized a secondary broken-pipe error and the owner
reports VEGAS remained waiting. Recipe Render opened an unowned modal error box
before returning the failing HRESULT. The source fix removes that blocking box
for recipe renders and selects a bounded causal FFmpeg diagnostic for C5/C6,
preserving the original HRESULT, full stderr, cancellation and host/probe errors.
No frontend source changed. Optimized build and engine checks pass (24,487 /
23 cases); actual adapter checks pass (138 / 11 fake-host real-FFmpeg cases),
including the bad filter, no publication, error return with ShowEncoderErrors=1,
matching C5/C6 messages and subsequent recovery. Snapshot/transport/page/monitor
and 65 packaging checks pass. These fixes still need real VEGAS retesting.

Separate `build/b6-candidate-0.1.7-error-fix` has copied trial data and exact
installed-0.1.7 rollback. It retains the existing 0.1.7 version stamps/frontend;
DLL SHA-256 **CE46036DC5A7ACC3A296BF91B610A7B04DF6367F3BC6BD7989AA0982FB75D017**
distinguishes it from installed **0A5D6F74…**. Manifest marks dirty source and
records a source patch hash; it is not release-qualified. Nothing installed or
committed by this continuation. See [retest/rollback](B6_TRIAL.md). Actual real
encoder-failure recovery, capacity and monitor overhead remain open.

**0.1.7 real cancellation/recovery (2026-10-16):** the owner reports the requested
cancel-and-render-again sequence worked. C6 job `17E0A52A-F34A-4B9B-A887-9868150ABD49`
is cancelled by the host after 605/1470 frames; no final output was published,
no partial was retained, and `017_test_cancel.mkv` is absent. The following job
`BD533179-4D29-47B7-B4A1-93C30C4D1FD4` uses the identical recipe hash, succeeds
with 1470 frames, publishes `unchaed_render.mkv` (19,312,208 bytes) and passes
sampled H.264/AAC FFprobe readback. Owner feedback supports the requested
same-session recovery sequence; records establish cancellation then success,
but do not independently identify the VEGAS PID/session or measure cancel-click
latency. Installed 0.1.7 DLL identity is unchanged. This is real VEGAS trial data,
not a fake-host result. Next: actual encoder-failure recovery, then bounded
capacity and monitor time/memory; broader qualification remains open.

**0.1.7 real-host focus retest (2026-10-16):** after the requested focus trial,
the owner reports the issue "seems like it has been fixed." The installed DLL
matches the staged 0.1.7 candidate; the real-host log identifies VEGAS
2026.0.3.189 and native 0.1.7-recipe-proof. Record the reported focus repro as
owner-confirmed fixed, without claiming every Apply/Cancel/switch-order or passive
background variant was individually observed. Two frontend traces show the window
at **698.2 / 536.4 ms** after process creation; native CreateProcess took
**168.7 / 36.2 ms**. These are observations, not click-to-visible guarantees.
The 65-check packaging rerun and exact installed-0.1.6 rollback verification pass.
Next: controlled real cancellation and encoder-failure recovery, then bounded
payload capacity and monitor time/memory. No 0.1.7 render/recovery or full A5–A7
qualification follows from this focus feedback.

The first cancellation attempt was blocked before encoding by missing default
FFmpeg selection (zero frames/samples, no published output). The trial profile
already selects the existing `C:\ffmpeg\bin\ffmpeg.exe`; the normal user profile
has no installations/default. This is consistent with a non-trial VEGAS launch.
The subsequent trial retry above succeeded. Ordinary launches need their own
desktop-app default selection; the two profiles remain separate.

**0.1.7 focus fix / B7 inputs (preparation checkpoint):** the owner-authorized
narrow frontend change captures foreground before re-enabling the valid owner,
then explicitly activates it before destruction for foreground closes only.
Same existing fake-window probe: old frontend **3/7**, new **7/7** close cases,
covering Apply/Cancel, both full-screen switch orders and passive background close.
New same-DPI process-age visible traces are **0.436–0.463 s**; native parallel
startup and renderer are unchanged. Real VEGAS focus/startup retest remains pending.
Frontend analysis and **44** popup widget/light+dark golden checks pass; native
optimized snapshot/transport/page/C7/writer checks and staged DLL fake-host
discovery pass. Matched **0.1.7-recipe-proof / app 0.1.7+1** is staged separately
with copied trial data, bounded capacity presets and exact installed-0.1.6 rollback.
Both PE file versions are 0.1.7.1, with native frontend-version enforcement.
B7 supplies complete runtime/notices/hash inputs, read-only VEGAS detection and
installer closure/update/rollback rules; no Inno installer or installation is done.
See [owner checks](B6_TRIAL.md), [installer inputs](B7_INSTALLER_INPUTS.md) and
[validation/handoff](product/workstreams/platform.md). Owner-confirmed normal
template persistence stands. Controlled real cancellation/encoder-failure recovery,
payload capacity and monitor overhead/memory remain unqualified; A5–A7 stay open.

**Prior 0.1.6 owner feedback:** saved templates persist across VEGAS restarts; record
normal persistence for the tested recipes as owner-confirmed, rather than still
deferred. This does not measure maximum private-payload capacity. The focus bug
remains: switch to another full-screen app, return to VEGAS/the editor, then
Apply; the other app reappears. Actual minimization has not been established.
The frontend close handler enables the native owner but does not explicitly
activate it before destroying the foreground popup. Native polling/activation
after exit is not sufficient to establish correct handoff. App-owned close fix
and regression request are in the [platform handoff](product/workstreams/platform.md).
No frontend code or installed files were changed. Controlled real cancellation/
failure recovery, capacity and measured monitor overhead remain open; subjective
normal performance is not the prescribed on/off measurement. A5–A7 are not fully
qualified. See [B6_TRIAL.md](B6_TRIAL.md) for the existing-toggle comparison.

**0.1.6 owner retest:** the owner reports editor opening is "a lot better now".
Three frontend traces show the window visible **748.6 / 533.3 / 526.8 ms after
process creation**; native CreateProcess took **153.1 / 32.8 / 31.8 ms**, with
UI request/scheduling **3.7 / 0.4 / 0.4 ms**. These are observed real-host runs,
not a general latency guarantee or a precise click-to-visible total. B6's normal
popup/template/recipe-render/progress path is implemented, supported by this
startup retest and the distinct-codec renders below. Subsequent owner feedback
above confirms normal restart persistence and clarifies the remaining focus bug.
Capacity, controlled real failure recovery and monitor overhead remain outstanding.

**0.1.5 owner retest / 0.1.6 startup work:** the owner reports both templates
render with different intended codecs and template bugs appear resolved. C6
confirms FFV1 and libx264 outputs succeeded, with sampled verification **0.719 s /
0.187 s**. This strengthens recipe-render evidence; it does not by itself pass
all persistence/capacity/recovery/performance gates. New reports: intermittent
6-second editor opening and VEGAS minimizing after popup Apply.

Native logs isolate the large spike to the grouped process launch/resume stage: fast
33–37 ms versus slow **7.0–12.4 s**, with file/validation ~6–8 ms and preflight
~2–3 ms. The old grouping cannot distinguish process creation from resume or
overlapping child work; it does not establish a shader cause. The app already
defaults to Skia. **0.1.6-recipe-proof**
starts the existing transport in parallel with VEGAS's UI, using copied C4 values
and a retained DLL lifetime. It adds explicit same-thread owner-chain restore on
return from the foreground editor, keeping background completion passive. The
unchanged 0.1.5+1 frontend is included. The owner subsequently confirmed faster
opening (above); the real Apply/minimize fix still needs explicit confirmation.
Offloading alone is not claimed to eliminate every Windows delay. No new user
launch-cancel flow.

**First real B6 trial and fixes (2026-10-15):** owner reports popup edits and a
successful render/progress window on VEGAS 2026.0.3.189. Native C6 confirms FFV1,
PCM float, 182 frames of 1920×1080 P010 input, success/publication and passed
FFprobe readback. This is a real smoke result, not persistence/recovery/performance
qualification. The trial exposed byte-shifted template names/notes, intermittent
invalid edit requests, about three-second popup startup and Explorer opening Documents.

The **0.1.5-recipe-proof / app 0.1.5+1** candidate aligns the native UTF-16 suffix
with at most one zero byte outside the strict payload; old intact odd envelopes
still read, but corrupted names cannot be reconstructed. No template-index change:
the historical hidden id-0 workaround was already present. Explorer now receives
its switch separately from quoted paths. Progress no longer adds a periodic idle
wait, keeping the two-Hz budget. Sampled readback replaces a full recount: on the
owner's output, the same FFprobe fell from **9.897 s to 0.743 s**. All stream/codec/
positive-video and publication/cancellation/error guards remain. Late-file corruption
is outside this sampled check. Popup startup gets immediate status/timings; its
three-second cold latency remains **unresolved pending measured retest**.

Staged separately in `build/b6-candidate-0.1.5`, preserving the first candidate,
its data, existing native templates and installed exporter; rollback copies the
currently installed 0.1.4 files/manifest. See [B6_TRIAL.md](B6_TRIAL.md). Focused
checks and app-owned startup follow-up are in the platform handoff. A5–A7, real
save/restart persistence, capacity, controlled real failure recovery and monitor
performance remain unverified.

**B6 connected candidate (2026-10-15):** owner resumed B6 and offered to test
VEGAS. Prepared **0.1.4-recipe-proof** with the existing **0.1.4+1** frontend:
fresh native recipe template → popup draft/Apply → immutable recipe render →
real FFmpeg → C5 monitor/History. Opt-in MKV/P010/square-pixel/48 kHz stereo scope;
general Advanced output remains unsupported/unknown. Default/proof build paths
remain available. Candidate, isolated C7 settings and exact prior-exporter backup
are in `build/b6-candidate`; **nothing was installed**. Owner instructions and
rollback: [B6_TRIAL.md](B6_TRIAL.md).

Focused optimized checks: **3,055 core**, **230 real-FFI**, **95 snapshot**,
**87 transport**, **102 native-page**, **19 C7 runtime**, **94 adapter checks /
9 real-FFmpeg fake-host cases**, plus the actual staged DLL's discovery/conformance/
render fake-host pass and writer-owned monitor launch checks. Existing frontend
release builds; real popup/monitor window checks with the existing fake owner pass
the primary placement/Cancel/no-activate paths. Some secondary foreground checks
had failed foreground prerequisites; these are not claimed as passes. No frontend
source changes. A5–A7, real persistence, controlled real failure recovery, payload
capacity and monitor performance stay **unverified pending owner VEGAS tests**.
Earlier “B6 disabled/on hold” entries below describe their historical checkpoints.

**Selected-file preset import (2026-10-15):** added the C3
PresetTransfer.importFrom(path, newId: ...) service requested by the app. It uses
bounded file reads and existing native validation/create-only Save, preserving the
source and existing presets on failure; a matching in-memory fake is supplied.
**150 repository / 86 fake-service checks** pass; package analysis is clean.
Frontend adoption is app-owned. Focused validation is in the
[platform handoff](product/workstreams/platform.md). No real VEGAS run or installation;
B6 remains disabled and the existing real-host qualification limits are unchanged.

**F6 C5 precision facts (2026-10-15, completed checkpoint):** after committing the library-watch
checkpoint **b6811be**, integrated app 493f146 through **ea4d557** on ws/platform and
fast-forwarded master. No push; master's .claude/ is preserved. The app's old quote
diagnostic assertion/goldens were adopted in its own 493f146 commit.
Additive nullable outputBitDepth/pixelFormatConversionReducesPrecision now travel
from established core signal facts through the native C5 producer, models, disk
reader and fakes. General Advanced scope and unknown precision remain null. A small
core scope correction keeps input/other-stream pixel options and arbitrary filters
from claiming output/conversion certainty; argv is preserved. Optimized core **3,034**,
FFI **208**, C5 facts **59**, repository **131**, fake **79**, fixture **295** and
selected app **65** checks pass. Optimized engine **23,160 checks / 22 fake-host cases**
and native C5/C6 readback **279 checks / 21 jobs** pass. Both packages analyze cleanly.
Details are in the [platform handoff](product/workstreams/platform.md). No frontend edits,
installation or real VEGAS run. B6 remains disabled; A5–A7, real persistence,
controlled real failure recovery and monitor performance remain **unverified**.

**Merge/library-watch continuation (2026-10-15):** reviewed platform checkpoint
fa58338 is integrated with app F6 through **9018965**, now on master; no push and
the main checkout's .claude/ is preserved. At that checkpoint app analysis passed;
394 unit/widget tests passed with one app-owned quote-range assertion outstanding.
Master has since advanced to app 493f146, adopting the precise quote range and
affected native goldens; that request is resolved in the integrated app checkpoint.
The F7 library-watch checkpoint is committed as b6811be and merged through ea4d557:
500 unchanged presets now reuse native metadata/immutable snapshots, with zero
normalization calls (**1.77–3.21 ms median / 2.05–4.03 ms p95**, JIT/AOT runs).
Continuation medians are **1.827 ms JIT / 1.866 ms AOT**; cold reads still cost about
0.5–1.1 s. Review restored FILE-READ for preferences.json directories and verified
authoritative get/Save/CAS despite metadata-preserving external edits.
Focused library **99** (JIT/AOT), retained repository **114**,
service fake **64** and app service-wiring **10** checks pass; service analysis is
clean. Details/limits are in the [platform handoff](product/workstreams/platform.md).
No real VEGAS run, install or exporter update. A5–A7, real persistence, controlled
real failure recovery and monitor performance remain **unverified**.

**Advanced core/FFI checkpoint (2026-10-15, owner-authorized commit/merge):** bounded immutable
capability reuse removes repeated Dart serialization/native lint copies. Additive
F4 token stage/macro/option metadata, macro catalogue, conservative encoder IDs,
partial quote prefix highlighting and C7 popup-size storage are implemented in
platform-owned paths. Optimized native **3,020**, native-asset FFI **208**, core/service
fake **177/64** and Windows repository **114** focused checks pass; both packages
analyze cleanly and B1 argv goldens are unchanged. Full real capability-map edits now measure **2.08–2.10 ms median / 2.14–2.31 ms
p95** (lint + Advanced + Basic compile, JIT; first transfer **12.9–16.1 ms**).
Method, limits and app adoption are in the [platform handoff](product/workstreams/platform.md).
No exporter/app integration or real VEGAS run; A5–A7, real persistence, controlled
real failure recovery and monitor performance remain **unverified**. Existing B6
sanitizer limitation is unchanged; no sanitizer/process/thread debugging resumed.

**B6 editor transport checkpoint (2026-10-15, offline):** fresh UUID session
directories, bounded atomic C4 requests, explicit owned-helper launch, creator-thread
zero-time exit polling and one validated result are implemented. Cancel/crash/
invalid results preserve the prior draft; direct known-file cleanup retains unknown
entries and reports incomplete cleanup. Optimized x64 `/W4 /WX` passes **89**
transport checks with real Windows files/processes and fake children, plus the
retained **95** recipe/draft checks. Current AddressSanitizer validation is
**incomplete**: the boundary run stalled at its thread guard after 87 checks.
The owner reported an antivirus alert during process/thread debugging and asked
to stop that investigation. Temporary diagnostic test edits are removed; the
cause is not established, and no sanitizer pass is claimed for this transport.
There are no exporter/page/Render call sites,
no real app/monitor launch and no new installation/VEGAS run. Remaining work:
connect the native page to the actual F5 popup when ready and the owner resumes
the native gates, then recipe/C5 progress integration. No additional fake-owner
framework is planned. See [native recipe boundary](NATIVE_RECIPE_BOUNDARY.md).
**A5–A7, real persistence, controlled real failure recovery and monitor performance
remain unverified.** B6 is not complete; deferred persistence is not reopened.

**B5 owner-authorized real trial (2026-10-14):** control and two slot-4 renders
complete normally on the reviewed `0.1.3-progress-text-proof` DLL / VEGAS
2026.0.3.189. Owner confirms normal advancing control progress. All return S_OK,
encoder exit zero/publication and zero locks. Full decode of control and final
text-test output verifies 182 1080p frames at 30000/1001 and 291,491 48 kHz float32
stereo sample frames. Mode 0 makes zero text calls; both mode-4 renders make eight
successful guarded calls, but the owner sees no switching text. **Drop custom
dialog text**, per the owner's preference, and prioritize useful numeric progress
and the separate frontend window. This candidate's cancel/recovery and mode 3
were not tested. The frontend window has a shell; live figures remain F6, and
the installed proof has no B6 monitor/recipe bridge.
The owner authorized **keeping a healthy candidate, rollback only for issues**;
the exact prior 0.1.2 rollback remains preserved/verified. No rollback or push.
See [progress trial](NATIVE_PROGRESS.md). A5–A7, real persistence, controlled
failure recovery and monitor performance stay unverified. No useful status line
was established; that product track is dropped, not passed.

**B6 offline boundary checkpoint (2026-10-14):** the owner authorized committing
B5 as `2bdb44d` and fast-forwarding master; the main checkout's `.claude/` was
preserved. Work continues on `ws/platform` with owned recipe envelope placement
and C4 per-page draft transactions. Both optimized/ASan x64 `/W4 /WX` builds pass
**95 checks**: byte/text/suffix preservation, bounds, proof/future rejection,
single/invalid/crashed session handling, core validation, Apply failure/retry,
thread guards and fake-holder allocation/reference balance. The helpers have
**no exporter/page/Render call sites** and launch no editor or monitor. See
[native recipe boundary](NATIVE_RECIPE_BOUNDARY.md). B6 is not complete. No new
real VEGAS run or installation; A5–A7, real persistence, controlled real failure
recovery, status-line visibility and monitor performance remain unverified.

**B5 static/probe preparation (2026-10-14, committed/merged `2bdb44d`):** clean
`ws/platform` fast-forwarded to current master `a0d33c4`. Exact VEGAS 2026.0.3.189
bytes/RTTI establish slot 3 as borrowed text + total + position reset, and slot 4
as borrowed text only. The internal consumer is a scripting render-status
description/title; public SetPosition does not forward it. An isolated,
default-off `0.1.3-progress-text-proof` candidate uses immutable markers, exact
host/vtable gating, caller-thread/zero-lock guards and <=2 Hz slot-4 calls;
optional text failure disables the probe. Slot 3 is initialization only.
The concrete opt-in/rollback checklist is in [NATIVE_PROGRESS.md](NATIVE_PROGRESS.md).
Focused results and staged candidate location are in the
[platform handoff](product/workstreams/platform.md). **No real VEGAS test,
installation or monitor launch.** Status-line visibility, A5–A7, real
two-template/restart persistence, controlled real failure recovery and monitor
performance remain unverified.

**Master integration (2026-10-14):** owner-authorized `8513ecc` includes platform
B1/B3/B4 (`1849990`, `0fc89a2`) and app F4 (`5b96a07`, merged through `5bc4b77`).
No source conflicts. Combined app analysis and 307 unit/widget tests pass; native/
Advanced goldens still need the app-owned B1 refresh. No push or installation.
Next: app F7 real-service wiring and the owner-operated B5 progress-text trial;
see [platform handoff](product/workstreams/platform.md). Real-host gates unchanged.

**Product design (2026-10-12):** the `product-ui-design` branch is merged into master,
and the owner has reviewed it. Decisions are in
[docs/product/README.md](product/README.md#decisions): the Signal Flow direction
(round 2 mockup in `docs/product/design/signal-flow.html`), Basic/Advanced modes,
Flutter, Windows x64 only, a theme that follows Windows, no proof-template migration,
and render progress through a VEGAS status line (if a real-host test allows it) plus a
small progress window. The project license is still open. The platform B0 contracts,
draft recipe schema/C ABI and pure Dart packages with fakes are now implemented;
see [contracts](product/CONTRACTS.md) and [platform handoff](product/workstreams/platform.md).
The B2 native product core and B3 Windows services are implemented below. Engine/
progress/job support is now implemented as B4; gated adapter integration follows.
The VEGAS gates below are unchanged.

**B4 complete (2026-10-14, owner-authorized commit/merge from ws/platform):** engine accepts C++ core
argv, parses bounded FFmpeg progress, writes C5 live status and C6 jobs/history
asynchronously, and uses core expectedStreams for bounded FFprobe readback before
publication. Host polling stays on Render's caller thread during hashes, pipe waits
and process creation; host frames are copied/released first. Output failure/cancel
and destination preservation remain distinct. Publication failures are nonfatal
and cannot make Render wait for the app/file readers. No monitor is launched yet.
**33,269 fake-host checks / 30 cases** pass, including 12 recipe runs across the
three B3 FFmpeg builds, fractional 1080p, cancellation/recovery, publication races,
blocked/slow pipes, probe errors and storage backpressure. Optimized maximum poll
gap 110 ms, extra parent working set 35.9 MiB, video/audio queue highs 29.7 MiB /
154.6 KiB, blocked-pipe cancel 375 ms. **23,053 ASan checks / 22 cases** pass on
gyan 5.1.2; ASan timings are not release measurements. B3 readers accept 29 native
jobs (**350 checks**). Core normal/ASan each **2,965**, native-asset FFI **196**,
helper/boundary/configuration **24/9/67** and existing exporter fake-host regression
pass; both packages analyze cleanly. Readback is not broad media/full-decode
qualification. See [platform handoff](product/workstreams/platform.md). Existing
B3 changes are preserved. No app-owned or installed/user state changed; no new
real VEGAS test. **A5–A7, real two-template/restart persistence, controlled real
failure recovery and monitor performance remain unverified.**

**B2 core/FFI (2026-10-13):** master through F2 (`ab7e7ab`) is in ws/platform.
The later F2 platform-fact/UI-state merge (`230c724`) is also incorporated.
Portable C++17 normalize/validate/compile/lint/complete/estimate/diff/payload and
pure session checks are implemented, with a Dart `NativeVeCore()` facade and native
asset hook, DLL/static builds, token/stream facts and the additive F2 result fields.
The app owns switching its fake provider after merge. B1 replaces the native
bootstrap profiles/options with qualified Windows data below; B0 fakes remain
historical design samples.

**B3 complete (2026-10-14, owner-authorized commit/merge from ws/platform):** real Windows discovery,
versioned help parser, streamed curated/lazy probes, bounded four-child process
pool, GPU/driver-qualified hardware cache, installation-health/C7 updates and
native-compiled synthetic preset tests are implemented. File-backed presets,
machine settings, capability cache, job/history reads, live status and edit-session
I/O. Atomic replacement and bounded Windows byte locks protect concurrent saves;
built-in preferences persist separately, preset history retains 20 old revisions,
and transfer/log/location APIs cover the app's storage requests. Core normalize
supplies Basic requiredEncoders; Advanced requirements remain explicitly unknown.
Job summaries/command/error/log fields are additive; B4 now supplies the native writers.
110 real-Windows file/lock/native-core checks pass, including competing processes,
crash lock release, malformed/future files and failed-write recovery. Final native
verification facts pass **2,955** native checks including ASan and **194**
native-asset FFI checks; retained **173 core / 58 service** fake checks pass. Both
packages analyze cleanly. The service suite passes **4,456** captured-parser/
fake-FFmpeg/real-Windows-process/DXGI checks. All **24** native-compiled preset
encodes/readbacks/full decodes pass across the three supplied FFmpeg builds
(**138** checks), including video-only/Advanced. Hardware smoke uses 320x192;
preset tests use 320x180/30 fps on Windows 11 Pro 26300, RTX 5070 Ti, driver
32.0.16.1692. MF is forced to hardware and GPU-only surfaces uploaded explicitly.
This is default-command smoke qualification, not HDR, other resolutions or
all-device compatibility. Parser/cache version 2 invalidates earlier commands.
No new fake-host or real VEGAS run. App-owned files and installed/user state are
untouched. App F7 injects WindowsServices and removes fake-era installation/cache
persistence copies; services own C7 installation updates. **61** further native
checks preserve compact/full compile results for built-ins, Extra arguments and
disabled audio on all three real probe caches. Basic warm compile is 2.5–2.9 ms
versus full Advanced 10.5–13.2 ms (50 calls/build); app frame/search/scroll budgets
remain unqualified. Live
status publication must remain nonfatal and off Render's waits in B4.

**B1 Windows FFmpeg (2026-10-13):** gyan 5.1.2, gyan static git `615b07170e`
(2026-10-12), and BtbN GPL shared git `24e860f6d3` (2026-10-13) are recaptured.
Source URLs, versions, timings and limits are in
[Windows facts](product/research/FFMPEG_WINDOWS.md). 255 measured mux/readback/
decode cases and 184 native-generated mode/depth/profile plans replace or qualify
the bootstrap rules. Windows help is embedded; compatibility uses sampled
libavformat 59/63 tables and conservative consensus for unknown versions.
X264 depth/profile and AMF mappings are corrected, current-build-incompatible
input queue flags are omitted, and Extra tokens expose `replacedField`.
B1 final checks (2026-10-14) are complete and ready for owner merge: 2,937 native checks (also ASan),
191 checks per native-asset/explicit-DLL/AOT route, 180 parser/catalog/identity/refusal regressions
and retained package/fixture checks pass. All three builds pass 60-frame
fractional-rate lossless pixel/audio parity and H.264/AAC FFprobe checks. Basic
input/output color tags preserve pixel samples under the chosen tagging policy;
actual VEGAS source color metadata remains unqualified.
No installed engine/adapter changes or new VEGAS evidence. Full-capability FFI
transfer still exceeds the 4 ms editing budget; B3/F7 must reduce/cache it and
measure app frames. Core-argv named-pipe timing/memory checks remain B4.

**B2 validation:** MSVC x64 `/W4 /WX`; 2,900 native checks, also under AddressSanitizer;
171 real-FFI checks per native-asset, explicit-DLL and bundled-AOT route. Warm
end-to-end compile mean about 0.6–0.95 ms for 500-call samples. Both packages analyze
cleanly; 173 core-fake, 57 service-fake and 281 fixture checks plus ABI layout checks
pass. Native-generated argv also pass 60-frame fractional-rate synthetic FFV1/PCM
and H.264/AAC encodes/FFprobe checks with existing gyan FFmpeg 5.1.2; lossless checks
compare all ten meaningful P010 sample bits and exact PCM float bytes. **Offline
files/real core, no new fake-host or real VEGAS test.** No installed DLL changed.
See [platform handoff](product/workstreams/platform.md) for limits and app wiring.

**B0 app review additions (Windows x64):** master including B0 and F0/F1 is merged
into ws/platform. Contract v1 now includes token field provenance/issue display
indexes, per-stream signal facts, a main host HWND in live status, and app UI state
in machine.json. Models and existing fakes/fixtures expose them. Both packages
analyze cleanly; 170 core, 57 service and 281 fixture checks pass, plus C/C++17 ABI
header compilation x64 `/W4 /WX`. **Fakes/offline only; no new real VEGAS evidence.**
Owner-approved architecture/settings reconciliation is applied. See the
[platform handoff](product/workstreams/platform.md).

**B0 checks (Windows x64):** both pure Dart packages analyze cleanly; 95 core,
40 service and 163 fixture structure/bounds checks pass using fakes/design data.
C/C++ draft-header checks and default/opt-in native builds pass MSVC `/W4 /WX`.
Existing 24 helper, 9 boundary, 67 configuration checks, default fake-host suite,
11-case/20-render proof/recovery suite and fake-tree installer tests pass with
gyan FFmpeg 5.1.2. This is offline/fake-host validation, not a new real VEGAS test.

**Next:** B2 is merged into master (`bbcbe91`). B1 and B3 are ready for owner review;
the owner authorized committing/merging B3/B4 from ws/platform. Next platform work is B5
status-line analysis and gated B6 adapter/monitor integration with the owner.
App F7 wires the real providers and measures its budgets. Approved B1 downloads stay
in this worktree's ignored build/; existing `C:\ffmpeg` gyan 5.1.2 is untouched.
No installation or PATH change. Workstream split:
[docs/product/WORKSTREAMS.md](product/WORKSTREAMS.md).

**Scope boundary:** product work is now authorized on ws/app and ws/platform.
The owner authorized this B3/B4 commit/master merge; push and installation remain separate. The deferred real
two-template/restart test and controlled real failure recovery remain qualification
limits; core/fake/offline tests do not pass A5–A7. No installed DLL or rollback backup changed.

First real Vegas Encoder render passes decoded checks: 182 1080p frames at
30000/1001 and 291,491 float32 stereo sample frames, S_OK/encoder exit zero,
published output and zero outstanding locks. Duration difference is about 0.004 ms.
This baseline is one real-footage render; broader repeat/cancel/recovery/error
and saved-template persistence checks remain pending. The process log is complete; the earlier temporary zero
length does not establish a logging fault.

Legacy FFmpeg Bridge is uninstalled with a restorable copy under
`build/retired-ffbridge-2026-10-11/`. Vegas Encoder, FFmpeg, host and other configs
are unchanged. The **xhigh** configuration agent completed the ownership bridge
and a separate `0.1.0-config-proof` build with 60 passing configuration checks; see
[next-agent handoff](NEXT_AGENT.md). Development uses lightweight status/test
summaries per AGENTS.md, without a mandatory investigation ledger.

The default build still exposes zero pages. The now-installed opt-in proof DLL
exposes one temporary checkbox; its value adds an optional `configuration_proof`
section to the render sidecar. Exact-build native ownership is resolved from
existing code. Both build modes pass `/W4 /WX`; the corrected proof passes 67
configuration, 24 helper and 9 boundary checks. Fake-host on/off saved settings survive Create without
fresh conformance, repeat renders, cancellation and encoder failure. See
[configuration proof and manual test](NATIVE_CONFIGURATION.md).

The first real proof-page attempt showed a tab with an empty body. The dialog
was never shown during Activate, while the measured VEGAS container does not
issue a separate Show call there. The corrected `0.1.1-config-proof` shows it
after successful creation/positioning. Three visibility regression checks fail
before the fix and pass afterward; inset layout, Hide/Show and Move are covered.
The fake-host on/off/save/reload/repeat/cancel/failure suite also passes again at
`build/test-results/configuration-proof-visibility-fix/`.

The user's real `diagnostic_on.mkv` / `diagnostic_off.mkv` renders in
`C:/Users/Samuel Tee/Desktop/test_video/` now verify that the setting reaches
Render on the corrected installed build and VEGAS 2026.0.3.189 (same PID 6692).
Only the on sidecar contains `configuration_proof: {extra_report: true,
proof_version: 1}`; the off sidecar omits it. Both report S_OK, encoder exit zero,
publication, 182 frames, 291,491 audio sample frames and zero outstanding locks.
Both deliberately produce the same three file types; the checkbox adds a JSON
section, not a separate file. These reports were inspected without decoding
these new media files. Save/reopen/restart, independent templates, unapplied
Cancel and render cancel/failure recovery remain unverified.

Foundation closeout now fixes the encoded path's progress-error classification:
only the recorded `0x8004E00C` cancellation code maps to user cancellation.
Other failed progress calls remain failures with their original HRESULT, including
poll failures during video/audio Submit and finalization. The regression reproduced
access denied incorrectly returning render-cancel before the fix. Raw diagnostic
mode retains its narrower inherited error behavior.

Candidate `build/candidate-0.1.2-config-proof/` is built and preserved, DLL
`CA876E05CA4ED6D8A2A84529A573577716CEA650B74384D7B9ED19F4D578EA45`;
it is now installed with the user's explicit approval and matching DLL/PDB/INI/
discovery manifest. Default source version is `0.1.1-dev`. The prior working
`0.1.1-config-proof` installation is preserved in
`build/rollback-before-foundation-closeout/`, with restoration instructions.
Host/sharedk/FFmpeg and other discovery configs are verified unchanged.
This candidate now passes the user's real cancel/recovery check below. Automated checks cover
same-loaded-DLL stop/recovery after cancellation, failures in both progress slots,
video/audio submission, finalization and existing-destination refusal; stopped
jobs leave no owned child/partial or published output, and recovered outputs
are decoded against the synthetic fixture. Audio submission is gated on the
fake audio-read counter and phase counters are asserted, so queue repolls cannot
silently move the failure into another phase. Real-host cancel/error recovery
remains the final qualification task; this is implementation readiness, not a
claim that every real-host gate passed. Both build modes pass `/W4 /WX`; 67
configuration, 24 helper and 9 boundary checks pass. The focused proof suite passes
11 cases / 20 render attempts with seven stop/recovery pairs, under
`build/test-results/foundation-recovery-qualified-phases/`. The default-build
baseline suite passes under `build/test-results/foundation-baseline-final/`.

The real `foundation_cancel.mkv` / `foundation_recovery.mkv` check passes on
`0.1.2-config-proof` / VEGAS 2026.0.3.189 in one session (PID 40788, renders 1/2).
Cancellation returns `0x8004E017` from host progress `0x8004E00C`, after 175 of
1,293 planned frames. No completed MKV or partial file remains; the owned encoder
has exited and host locks are zero. The next render returns S_OK, encoder exit
zero and publication with zero locks. Decoded checks confirm 299 1080p frames
at 30000/1001, 478,878 float32 stereo sample frames at 48 kHz, presentation
timing and complete byte counts. Audio/video duration difference is about 0.008 ms.
Output checks are in `build/test-results/real-foundation-recovery-final/`.
This is real footage, not a counter/click fixture or same-run raw-byte comparison.
Elapsed cancelled-render time is not a measured cancel-button response deadline.
No new controlled-failure report was found; real failure/recovery remains unverified,
with automated early-exit/progress/destination failure and recovery checks passing.

Previous real-tested candidate: `build/candidate-0.1.1-config-proof/`, DLL
`A644B62650B729918EAEF54DBCE24F488F6280753DE283BE645199862BB13FD8`.
The earlier `0.1.0-config-proof` installation is
backed up in `build/rollback-before-page-visibility-fix/`; its candidate remains
preserved. The working 0.1.0-dev installation is backed up in
`build/rollback-before-configuration-proof/` and its preserved candidate is intact.
Host/sharedk/FFmpeg and other discovery configs are unchanged. Actual VEGAS
Apply/Cancel/save/restart behavior and proof-build render recovery remain open.

## Installation

The original 0.1.0-dev candidate's installation and first real render are verified.
It has been reversibly updated to 0.1.2-config-proof for the final recovery check.
All four candidates are preserved. With VEGAS closed, restore the prior working
proof with `-Update -BuildDir build/rollback-before-foundation-closeout`, or the
original baseline with `-Update -BuildDir build/rollback-before-configuration-proof`.

## Implemented baseline

- User-created independent Git repo at `L:/repos/vegas-encoder`; named Vegas Encoder.
- Authored source imported from the ffbridge 0.2.0 working tree with SHA-256 source
  identities, import map and distinct filter/type/preset GUIDs.
- Internal ABI, checked template/frame-lease helpers, adapter, encoder and diagnostics.
- Product-native build scripts and test host; engine's diagnostic header has no
  indirect dependency on VEGAS interfaces.
- Synthetic project-template generation, raw/decoded fixture checkers, product
  FFmpeg test runner and conservative reversible installer/fake-tree tests.
- Native exception containment and best-effort scoped-lock diagnostics hardening.

Validation: x64 /W4 /WX builds; 24 host-helper and 9 boundary checks; generated FFmpeg suite including 1080p; raw-checker and fake-installer tests; independent source-copy build all pass. Exact final DLL SHA-256 is 9FE5587A49F7A65AE3DC62DBB54D6B4AB392B67447D1D21C9DDC307325EEF5B2.

Validation results are recorded in the [bootstrap experiment](experiments/2026-10-10-bootstrap.md)
and ignored evidence. The source/research import is documented in [ORIGIN.md](../ORIGIN.md).

## Gate state

| Gate | State |
| --- | --- |
| A0 real-host baseline qualification | Pending broader ffbridge repeat/cancel/error observations; short fixture proof F-050 plus real 1080p/fractional/cancel evidence F-052 |
| A1 independent product import/build | Implemented; generated fake-host tests are self-contained |
| A2 internal host helpers | Template/lease separation and targeted checks implemented; further stream/allocator extraction and real-host qualification remain |
| A3 adapter/engine boundary | Internal dependencies and owned-buffer transport retained; broader job/settings and cancellation hardening remain |
| A4 Vegas Encoder real-host parity | Normal 1080p/fractional, same-session on/off and current-build cancel/recovery pass; controlled failure/recovery and counter fixture qualification remain open |
| A5/A6 native page and saved-setting proof | Real popup Apply and distinct template renders work; owner confirms saved templates persist across restart and reports the 0.1.7 foreground-return fix works. Detailed focus variants and full qualification remain open |
| A7 versioned recipe snapshots | Implemented in the opt-in B6 candidate; tested recipes render independently and persist per owner. Maximum native payload capacity and broader qualification remain open |
| A8 foundation qualification | Foundation normal/cancel/recovery evidence retained; B6 normal recipe rendering/startup, owner-confirmed persistence and reported 0.1.7 focus fix added. Detailed focus variants, controlled failure, capacity, monitor overhead and broader support matrix remain qualification limits |

## Limits

The [adapter data-flow explanation](ADAPTER_DATA_FLOW.md) describes raw host
media, the P010/FFV1/MKV stages, buffer ownership and input-format evidence limits.
The explanation distinguishes imported observations from qualified product behavior.

Fixed lossless MKV profile only. P010/square-pixel/supported constant rates, optional
48 kHz float32 stereo. No general HDR/color/alpha, hardware encode, audio-only encode,
arbitrary codec/container or VEGAS-version guarantee. Color metadata is not qualified.
Raw mode remains a research-style diagnostic path with narrower defensive guarantees.

Host calls stay on the Render caller thread; no simultaneous-render/thread-safety
claim. The installed candidate corrects encoded progress failure classification;
real cancellation/recovery passes, while other progress failure codes and controlled
error recovery are only fake-host tested. Formally bounded Abort completion under
stalled clients remains a hardening question. The proof runner models
cancellation but does not establish real-host cancel while a pipe is stalled.

Installed INI edits cause conservative hash-drift refusal during update/uninstall.
User-supplied FFmpeg remains a machine preference; no binaries are distributed.
Vegas Encoder is installed; the historical ffbridge exporter is removed with a
rollback backup. The external FFmpeg encoder, host and other exporters are unchanged.

## Source checkpoint

The user requested a local commit of all current foundation source/documentation:
native configuration ownership/page/draft, saved-byte proof, visibility fix,
progress error handling, build/test harnesses and updated qualification/handoff
notes. Generated builds, decoded test output, rollback payloads and media remain
ignored. This implementation checkpoint does not claim that deferred or outstanding
runtime checks passed. Earlier checkpoints are documented in
[checkpoint note](experiments/2026-10-10-implementation-checkpoint.md).

## Product planning (2026-10-11)

The product-layer plan and design exploration for review are in
[product/README.md](product/README.md):

- specification, architecture, recipe and command rules, FFmpeg integration, UI
  behaviour, roadmap and research notes;
- eight interactive HTML design directions with screenshots and a review.

Supporting work:

- 226 real FFmpeg 8.1.3 test muxes and FFmpeg help/probe captures, in ignored
  `evidence/2026-10-11-product-design/`;
- a prototype command compiler/validator used by the mockups.

Documentation and mockups only: no product code, no Windows build, and **no real
VEGAS test ran**. Gate state is unchanged. See the
[experiment note](experiments/2026-10-11-product-design.md).

## Next task

Continue in `L:\repos\vegas-encoder` on `master` with one agent
owning both app and platform. Follow the single ordered queue in
[NEXT_AGENT.md](NEXT_AGENT.md). Preset import and the 16 shared starters are
implemented; rebuild matched installer inputs after source changes settle,
then follow the owner-directed real installer and starter qualification gates.
The owner's deferred trial/recovery checks and recorded qualification limits
above remain unchanged. Real installer testing and release signoff
remain; do not reopen deferred tests or duplicate completed core/service work.
