# Windows x64 setup

Build from the repository root with `scripts/Build-Release.ps1`. The default All
action builds the product, publishes `build/release/vegas-encoder/{app,core,plugin,setup}`,
stages a fresh frozen bundle and compiles its installer into `dist/`. Build only
uses `-Action Build`; Package stages the existing receipted build and compiles
Setup. Neither command runs the installer. Inno Setup **6.7.1** is the verified
compiler; `-IsccPath` overrides its location. Tool installation is separate.

All Inno sources live under `setup/`: `setup_script.iss`, `version.generated.iss` and
`includes/{helper,hosts,lifecycle}.iss`. The generated include comes from root
`version.json`. `native/install.cpp` is a small Windows installer helper using
the existing MIT-licensed JSON header; its notice ships with the app. It does
not execute PowerShell, VEGAS, the Flutter app or FFmpeg.

## Installation choices

The app is required; the VEGAS Pro **2026** exporter is optional. The installer
reads 32/64-bit HKLM/HKCU uninstall and App Paths registrations, verifies the
actual x64 `vegas2026.exe` and file-version major, and offers detected folders.
Browse permits unregistered/custom locations. Other VEGAS versions are rejected.
Detection does not qualify a new build: the tested host remains 2026.0.3.189.

There is one selected VEGAS 2026 target per shared app installation. Updating
that installation updates its recorded target; selecting another target moves
the integration, and unchecking the component removes it. The wizard explains
this before installation. Unrelated exporter folders are untouched. A missing
VEGAS executable does not prevent removal of an already-owned integration.

The installed exporter goes under
`{vegasDir}\FileIO Plug-Ins\vegas-encoder`, with its discovery file at the VEGAS
root. Setup renders a UTF-16 INI with the final app path and default log location;
it never ships development app/log paths. PDBs stay in the private build bundle,
not the public install. Existing recognized development installations can be
adopted only when all recorded DLL/INI/PDB/discovery hashes still match.

Setup requires administrator rights, Windows x64, and the x64 Microsoft Visual
C++ runtime already installed (`vcruntime140`, `vcruntime140_1`, `msvcp140`).
It reports a missing prerequisite rather than downloading or installing tools.
Close Vegas Encoder (including popup/progress windows) and the affected VEGAS
installations first. Processes are checked by executable location; Setup does
not kill processes or schedule partial file replacement on reboot.
Updates retain the existing app directory; uninstall first to relocate it.

Startup detection and host validation deliberately omit the app directory from
their helper requests. Inno has not initialized the `app` constant during
`InitializeWizard`; only install/uninstall lifecycle requests expand it.

For unattended deployment, Inno's component/path switches can be used, for example:

```text
setup.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /COMPONENTS="app,vegas2026" /VEGASDIR="C:\Program Files\BorisFX\Vegas Pro 2026"
```

Use `/COMPONENTS="app"` for app only. A selected plug-in with an invalid path
fails preparation, including in silent mode. No post-install app launch occurs
in silent mode.

## Ownership, recovery and uninstall

`{app}\vegas-encoder-setup.json` records app payload hashes and its selected
host. Per-host `install-manifest.json` retains the existing
`vegas-encoder-install/1` format used by the read-only Settings dashboard.
Shared app integrity is still outside that dashboard's existing coverage.

### Component identity and future split installers

Keep **one bundled setup for now**. Its Inno `AppId`
`{0CF24E60-C0F5-4242-96AD-13FF2F9BF313}` remains the Windows program/update/
uninstaller identity. Do not change it merely for a new release or host version.
It is separate from the component catalog now written under the protected,
administrator-readable `%ProgramData%\VegasEncoder\Installations\` directory.
Every installed component has a `{instance-guid}.json` record:

| Field | Meaning |
| --- | --- |
| `schema` | `vegas-encoder-component/1` |
| `componentId` | `vegas-encoder.app.windows-x64` or `vegas-encoder.core.vegas2026.windows-x64` |
| `instanceId` | Stable GUID for this installation, retained across updates |
| `version` | App version or exporter release version, recorded independently |
| `installDir`, `manifest` | Absolute component and ownership-manifest paths |
| `bundleId`, `architecture` | Current owning bundle's AppId and `x64` |
| `appInstanceId` | Core's linked app installation GUID |
| `hostDir`, `hostFamily` | Core's VEGAS root and `vegas2026` compatibility family |

Here **core** means the host exporter DLL with its statically linked engine.
The app's `ve_core.dll` remains part of the app runtime. Core records live
alongside app records, rather than being discoverable only through a single
Windows uninstall entry. Future elevated combined or split installers can
enumerate this catalog to find exact installed paths and versions, then verify
the referenced ownership manifest and file hashes before changing anything.
Catalog presence alone is not proof of file integrity or host compatibility.

Each record is also embedded as `installation` in its component's existing
ownership manifest. Hash-verified pre-catalog installs acquire IDs on update.
Setup checks that embedded and central records agree; it refuses another app's
core. Catalog changes participate in the same exact-byte backup, rollback,
restore and uninstall transaction as the payload. Removing or moving the
current host integration removes its old core record; the app ID survives.

This leaves room for one shared app and separate core instances under each
VEGAS installation's own `FileIO Plug-Ins\vegas-encoder` directory, including
VEGAS roots on different drives. A future host family gets its own component
type and compatible binary; a version update retains its existing instance ID.
No portable path or shared core directory is assumed.

**Current limit:** the bundled wizard still manages one selected VEGAS 2026
target per app. Multiple simultaneous targets, older-host binaries and split
installers are not implemented. A future split must explicitly migrate bundle/
uninstaller ownership and protect app dependencies when cores still reference
the app; it must not simply assign new Inno AppIds and leave two uninstallers
owning the same files. Existing app/core compatibility checks also remain in
force; separate recorded versions do not permit arbitrary version combinations.

Unknown app installs, unknown plug-in files, changed owned files, conflicting
files and reparse points cause refusal before replacement. The helper verifies
the installed app against the frozen payload before committing the plug-in.

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

Uninstall checks ownership/hashes and running processes first, saves another
rollback transaction, removes only the recorded plug-in files, then lets Inno
remove its registered app files. Unknown files are preserved. User settings,
libraries, jobs, caches, VEGAS templates and user-supplied FFmpeg are retained.

## Validation scope

`scripts/etc/Build-SetupHelper.cmd test` builds a separate test-only executable.
`python -I scripts/etc/Test-Setup.py` confines all mutations to a new fixture root
under `build/test-results`; its fake app/DLL/host bytes are never loaded. The
production helper has no test-root, version-bypass or failure-injection switch.
Junction creation requires running the test outside a restricted sandbox.

`python -I scripts/etc/Test-SetupWizard.py` compiles and runs an unprivileged Inno
harness using the actual helper/host scripts and read-only production detection.
It aborts in `InitializeWizard`, before any install lifecycle or file deployment.
This covers the early `app`-constant startup regression without running the
product installer or replacing the installed trial.

Compiler checks and helper fixtures do not qualify real Inno install/update/
uninstall behavior. That deployment trial, missing-runtime/locked-file behavior
on a clean Windows machine, and release signing/licensing remain release gates.
The existing owner-deferred VEGAS render/progress trials stay deferred.
