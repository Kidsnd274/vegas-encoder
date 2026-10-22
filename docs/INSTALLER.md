# Windows x64 setup

Build from the repository root with `scripts/Build-Release.ps1`. The default All
action builds the product, publishes `build/release/vegas-encoder/{app,core,plugin,setup}`,
stages a fresh frozen bundle and compiles its installer into `dist/`. Build only
uses `-Action Build`; Package stages the existing receipted build and compiles
Setup. Neither command runs the installer. Inno Setup **6.7.1** is the verified
compiler; `-IsccPath` overrides its location. Tool installation is separate.

All Inno sources live under `setup/`: `setup_script.iss`, `version.generated.iss` and
`includes/{helper,hosts,wizard,lifecycle}.iss`:

- `helper.iss` runs the native helper with UTF-16 INI requests and results;
- `hosts.iss` holds the detected VEGAS versions and the VEGAS integrations page;
- `wizard.iss` picks the mode and drives the welcome, maintenance, ready and
  finished pages;
- `lifecycle.iss` prepares, commits, rolls back and uninstalls.

The generated include comes from root `version.json`. `native/install.cpp` is a
small Windows installer helper using the existing MIT-licensed JSON header; its
notice ships with the app. It does not execute PowerShell, VEGAS, the Flutter app
or FFmpeg. The behaviour below was agreed with the owner on 2026-10-23.

## Components and versions

- **App**: exactly one per machine, always installed. It owns the Windows
  uninstall entry and the existing Inno `AppId`.
- **Core**: the VEGAS exporter. At most **one per VEGAS version**, installed in
  that VEGAS folder. Each supported VEGAS version has its own core binary in the
  bundle; today only VEGAS Pro 2026 is supported.
- **Everything moves together.** The exporter refuses to render with any app build
  other than its own (`AppReady` in `src/vegas/adapter/recipe_runtime.cpp`). After
  every successful run, every installed core has the app's version: updating the
  app always updates every installed core. There is no "keep the old core" choice.

## Modes

Setup asks the helper for the installed app's version before the wizard opens and
picks the mode from it:

| Installed app | Mode | Offered |
| --- | --- | --- |
| None | Install | App location; VEGAS integrations, all unticked |
| Older | Update | App location fixed; installed cores update (or untick to remove); other VEGAS versions can be ticked to add |
| Same | Maintenance | Modify integrations, Repair, or Uninstall (opens the registered uninstaller) |
| Newer | Blocked | "Vegas Encoder X is installed. Uninstall it before installing this older version." |

Versions compare by their numeric parts, then a release ranks above its
prerelease, then the `+build` number (`0.1.7+1` < `0.1.7+2` < `0.1.8+1`).
Downgrades are not supported. Anyone who needs one can replace the DLL by hand;
the next setup run will simply overwrite it. The helper also refuses a downgrade
during preparation, so a scripted install cannot bypass the check.

**Repair** reinstalls the app files and every recorded core from the bundle,
overwriting changed or missing files. It does not add or remove integrations and
skips the integrations and tasks pages.

## VEGAS integrations

- One row per detected VEGAS version. Detection reads the Windows uninstall
  entries whose display name contains "VEGAS ... Pro", the `vegas*.exe` App Paths
  registrations, the default VEGAS Pro 2026 folders and every recorded core
  folder. It reads each `vegas<digits>.exe` file version without running it; the
  major version decides the row (`vegas2026`, `vegas23`). A recorded folder wins
  over a newly detected one for the same version.
- Unsupported versions are shown disabled ("Not supported by this release") so the
  user can see they were found. A supported version that was not detected is
  listed as "Not found"; ticking it, or **Locate…**, asks for its folder.
- Fresh install: every row unticked; the user ticks where the core goes.
  Update/Modify: rows with an installed core start ticked, other rows unticked.
  Unticking an installed row removes that core.
- A row's folder can be changed to an unregistered location with **Change…**; it
  must contain that version's x64 executable. Changing the folder of an installed
  row moves the core and keeps its installation ID.
- If no row is ticked when the user clicks Next, a task dialog asks "Install
  without a VEGAS integration?" (**Continue without VEGAS** / **Go back**), or
  "Remove the exporter from every VEGAS version?" (**Remove and continue** /
  **Go back**) when installed integrations were unticked. Silent installs skip the
  dialog and continue.

## Screens

The visual reference is [installer.html](product/design/installer.html), an
interactive light/dark approximation, not an Inno capture.

- `WizardStyle=modern dynamic polar`: setup follows the Windows light/dark setting.
- Update mode shows the version summary and the list of installed exporters on the
  Welcome page; there is no separate status page.
- Maintenance mode skips Welcome and opens on a Modify / Repair / Uninstall choice.
- The VEGAS integrations page replaces the old Components and folder pages. Each
  checklist row shows its status on the right ("Update 0.1.7+1 → 0.1.8+1",
  "Installed", "Exporter will be added", "Exporter will be removed", "Exporter will
  move here", "Not installed", "Not found", "Not supported by this release").
  Below the list, a read-only field shows the selected row's folder.
- The Ready page lists the app action and one line per VEGAS action. The Finished
  page says which VEGAS versions to restart and offers to launch the app.
- Programs still using the app or a selected VEGAS folder are named in a dialog
  with **Retry** and **Cancel** before anything is changed.

## Light ownership

Setup does not police the exporter folder. It overwrites or removes its own file
names without refusing when they were changed or deleted by hand, and leaves any
unrecognized extra files alone (the folder stays if it is not empty). An
exporter folder that setup did not record is taken over when its row is ticked.
If a recorded core's DLL is missing, the row is treated as not installed and its
record is cleaned up on the next run, so deleting the DLL by hand counts as
removing it. If a recorded VEGAS folder no longer exists, its record is removed
on the next run. If a user moves the DLL somewhere else, setup does not follow
it. The per-run rollback transaction stays, so a failed run still restores what
it replaced.

Setup still refuses, before changing anything:

- installing into a non-empty app folder that has no setup manifest;
- a payload file that would overwrite an app file setup did not install;
- reparse points (junctions or symbolic links) in any app, VEGAS or record path;
- a VEGAS folder whose core is recorded for another app installation;
- an installation record that is not valid for its component;
- an interrupted earlier setup that still needs rollback.

## Uninstall

Uninstall from Windows removes the app and every recorded core, because a core
cannot work without the app. It checks running programs first, saves another
rollback transaction, removes setup's own file names from each recorded VEGAS
folder, then lets Inno remove its registered app files. Unknown files are kept.
User settings, libraries, jobs, caches, VEGAS templates and user-supplied FFmpeg
are kept. To remove a single integration, run setup again and untick it under
Modify, or delete its DLL by hand.

## How setup tracks installations

Setup keeps track of where things are installed in these places:

1. **Installation records (authoritative).** One JSON file per installed component
   in `%ProgramData%\VegasEncoder\Installations\{instance-guid}.json`
   (readable and writable only by administrators and SYSTEM). There is one record
   for the app and one per VEGAS version with a core. A core record holds the
   VEGAS version (`hostFamily`, e.g. `vegas2026`), the VEGAS folder (`hostDir`),
   the plug-in folder (`installDir`), the core version and the app record it
   belongs to (see the field table below). Setup finds every installed core by
   reading these records, not by scanning disks.
2. **Files written into each VEGAS folder**, in each `{vegasDir}`:
   - `FileIO Plug-Ins\vegas-encoder\vegas-encoder.dll`, the exporter;
   - `vegas-encoder.ini`, holding the app path;
   - `install-manifest.json`, a copy of the record plus file hashes, which the
     app's Settings dashboard reads (`vegas-encoder-install/1`, unchanged);
   - `VegasEncoder-x64.fio2007-config` at the VEGAS root, which tells VEGAS to
     load the exporter.
3. **The app's manifest**, `{app}\vegas-encoder-setup.json`, which lists the app's
   files for Repair and uninstall and embeds the app record.

VEGAS detection is separate (see VEGAS integrations): it says which VEGAS versions
exist and where, and the records say which of those already have a core. If a
record and the files in a VEGAS folder disagree, the record wins and the files are
rewritten, or removed when the row is unticked.

Installs made before the catalog existed named their single VEGAS 2026 folder in
the app manifest's `host` field. Setup reads that field once, records the core
under the catalog and no longer writes it. The Inno `Vegas2026Dir` previous-data
value is retired for the same reason: it cannot represent more than one VEGAS
version.

### Record fields

| Field | Meaning |
| --- | --- |
| `schema` | `vegas-encoder-component/1` |
| `componentId` | `vegas-encoder.app.windows-x64` or `vegas-encoder.core.<hostFamily>.windows-x64` |
| `instanceId` | Stable GUID for this installation, kept across updates and folder moves |
| `version` | App version or exporter release version, recorded independently |
| `installDir`, `manifest` | Absolute component and ownership-manifest paths |
| `bundleId`, `architecture` | Current owning bundle's AppId and `x64` |
| `appInstanceId` | Core's linked app installation GUID |
| `hostDir`, `hostFamily` | Core's VEGAS root and family, e.g. `vegas2026` |

Here **core** means the host exporter DLL with its statically linked engine.
The app's `ve_core.dll` remains part of the app runtime. Each record is also
embedded as `installation` in its component's manifest; the catalog copy wins.
Catalog changes participate in the same backup, rollback, restore and uninstall
transaction as the payload.

Keep **one bundled setup**. Its Inno `AppId`
`{0CF24E60-C0F5-4242-96AD-13FF2F9BF313}` remains the Windows program/update/
uninstaller identity; do not change it for a new release or VEGAS version.

**Adding a VEGAS version:** build its exporter, ship it in the bundle, and mark the
family supported in the helper (`supported()` in `setup/native/install.cpp`, which
today maps every supported family to `vegas-encoder.dll`). Detection, records and
the wizard already handle several versions. Split installers are not implemented;
a future split must migrate uninstaller ownership and protect app dependencies
rather than assigning new AppIds that leave two uninstallers owning the same files.

## Requirements and unattended installs

Setup requires administrator rights, Windows x64, and the x64 Microsoft Visual
C++ runtime already installed (`vcruntime140`, `vcruntime140_1`, `msvcp140`).
It reports a missing prerequisite rather than downloading or installing tools.
Setup does not kill processes or schedule partial file replacement on reboot.
Updates keep the existing app directory; uninstall first to relocate it.
Detection does not qualify a new build: the tested host remains 2026.0.3.189.

The installed exporter goes under `{vegasDir}\FileIO Plug-Ins\vegas-encoder`, with
its discovery file at the VEGAS root. Setup renders a UTF-16 INI with the final app
path; it never ships development app/log paths. PDBs stay in the private build
bundle, not the public install, and a development PDB found in the folder is
removed (and kept in the rollback transaction).

Startup detection and folder validation deliberately omit the app directory from
their helper requests. Inno has not initialized the `app` constant during
`InitializeSetup` or `InitializeWizard`; only lifecycle requests expand it.

For unattended deployment:

```text
setup.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /VEGAS=2026 /VEGASDIR2026="C:\Program Files\BorisFX\Vegas Pro 2026"
```

- `/VEGAS=existing` (the default) keeps exactly the installed integrations;
  `/VEGAS=none` installs or updates the app only and removes installed exporters;
  `/VEGAS=2026,23` ticks the listed versions (unsupported ones are ignored).
- `/VEGASDIR<version>="path"` sets the folder for one version, for example
  `/VEGASDIR2026=`. Without it, the detected or recorded folder is used.
- A ticked version with no valid folder fails preparation, including in silent
  mode. No post-install app launch occurs in silent mode.

The old `/COMPONENTS` and `/VEGASDIR` switches are gone with the Components page.

## Default presets and saved templates

With VEGAS integration selected, a newly rebuilt exporter supplies 16 fixed Render
As starters, plus Vegas Encoder settings. The [starter list](STARTER_PRESETS.md)
records all software/hardware recipes and the explicit 720p option. The
general template retains its existing GUID/index; the reserved id-0 entry remains
the historical hidden probe. All retain project frame rate; the 720p starter
fits/pads to 1280x720 while the others follow project dimensions.

`schema/builtin-presets.v1.json` is the shared source for app/exporter recipe
settings and origin ID/revision. Software and NVIDIA hardware recipes are named
separately in both consumers. Required encoders must exist in the user's FFmpeg.
Setup installs the app/exporter, never user `.sft2` files. A successful install,
update or repair supplies the defaults bundled with that version. Saved VEGAS
templates and user library presets retain their own settings; adopting newer
library settings requires explicit Update from library in the popup. No live
library lookup occurs during rendering. New starter-list visibility/persistence
still needs real-host verification; fake-host enumeration does not qualify it.

## Recovery

Before app replacement or uninstall, Setup saves exact owned app, plug-in,
manifest and discovery bytes in a protected administrator/SYSTEM directory:

```text
%ProgramData%\VegasEncoder\Setup\{transaction-guid}\
  transaction.json
  0.bak, 1.bak, ...
```

Backups are retained after success. A handled failure invokes rollback. An
interrupted pending transaction blocks the next setup attempt and reports its
path. Close affected processes and use a known helper from the same frozen
bundle in an **elevated** terminal to recover. Create a UTF-16 INI request:

```powershell
$request = "$env:TEMP\ve-recovery-request.ini"
$result = "$env:TEMP\ve-recovery-result.ini"
"[setup]`r`ntransaction=C:\ProgramData\VegasEncoder\Setup\{transaction-guid}`r`n" |
  Set-Content -LiteralPath $request -Encoding unicode
& 'L:\path\to\bundle\installer\ve-install.exe' rollback $request $result
Get-Content -LiteralPath $result
```

Use `rollback` for a pending transaction, or `restore` for a committed one.
Committed restore refuses files changed since setup; resolve those edits
manually rather than overwriting them. The journal records target paths,
old/new hashes and corresponding backup names. Restore covers payload files,
not Inno's registry/shortcut/uninstaller metadata; after undoing an uninstall,
rerun the matching setup to restore that registration. Keep backups until the
new installation has been accepted. Do not delete old candidates or trial
rollback folders as installer cleanup.

## Validation scope

`scripts/etc/Build-SetupHelper.cmd test` builds a separate test-only executable.
`python -I scripts/etc/Test-Setup.py` confines all mutations to a new fixture root
under `build/test-results`; its fake app/DLL/host bytes are never loaded. It
covers install, update, repair-style replacement, moving and removing cores,
pre-catalog migration, detection rows and version relations, downgrade refusal,
running programs, rollback/restore and uninstall. The production helper has no
test-root, version-bypass or failure-injection switch. Junction creation requires
running the test outside a restricted sandbox.

`python -I scripts/etc/Test-SetupWizard.py` compiles and runs an unprivileged Inno
harness using the actual helper, hosts and wizard scripts and the production
helper's read-only detection. It builds the integrations page from real detection
and the update and maintenance variants of the wizard, then aborts in
`InitializeWizard`, before any install lifecycle or file deployment.

Compiler checks, the harness and helper fixtures do not qualify real Inno install/
update/uninstall behavior, page layout at different DPI settings, or the real
light/dark rendering. That deployment trial, missing-runtime/locked-file behavior
on a clean Windows machine, and release signing/licensing remain release gates.
The existing owner-deferred VEGAS render/progress trials stay deferred.
