# B7 inputs for the owner's Inno Setup installer

Matched trial: **0.1.7-recipe-proof / frontend 0.1.7+1**, Windows x64.
Both now have numeric PE file version **0.1.7.1**. Native preflight requires that
exact frontend version. The native core remains statically linked into the
exporter; the app loads its own core DLL. These are a matched set, not interchangeable
downloads. B6 qualification remains pending; this is installer preparation, not
a release or an implemented Inno Setup installer.

## Rebuild and stage

Use the existing MSVC and Flutter SDKs without upgrading them:

```powershell
Set-Location L:\repos\vegas-encoder-platform
cmd /d /c 'scripts\build.cmd "" recipe-proof'
Push-Location app
L:\flutter\bin\flutter.bat build windows --release --build-name 0.1.7 --build-number 1
Pop-Location
.\scripts\Prepare-B7.ps1 -OutputDir "$PWD\build\b6-candidate-0.1.7"
.\scripts\Test-B7.ps1 -BundleDir "$PWD\build\b6-candidate-0.1.7"
```

The prepared candidate already exists in this worktree. Choose a **fresh** output
name on a repeat; the script refuses replacement. It checks x64 PE headers, both
product/numeric versions, required runtime files and reparse paths. It copies the
whole release runtime, writes deployment-specific INI inputs, and hashes every
packaged file in `installer-inputs.json`. It does not execute a payload, install,
elevate, close VEGAS or modify the source bundle. `sourceCommit` plus `sourceDirty`
describe the source state; a clean release build must have `sourceDirty:false`.
The manifest records open checks and `releaseQualified:false` explicitly.

## File and destination map

| Input | Destination / rule |
| --- | --- |
| `app\VegasEncoder.exe`, `flutter_windows.dll`, `ve_core.dll`, `ve_windows_services.dll` | One shared `{app}` directory, proposed `%ProgramFiles%\Vegas Encoder`; owner chooses setup's application directory |
| Entire `app\data\` | `{app}\data\`; keep AOT `app.so`, ICU, asset manifests, fonts, shaders and Flutter `NOTICES.Z` together |
| `app\licenses\*` | `{app}\licenses\`; full native/Dart notices and both font OFL texts are supplied |
| `plugin\vegas-encoder.dll` | Each selected `{vegasDir}\FileIO Plug-Ins\vegas-encoder\` |
| `plugin\vegas-encoder.pdb` | Optional matching diagnostic symbols, same plug-in directory; omit from public setup if desired, retain privately |
| `installer\vegas-encoder.ini.in` | Render `{app}` to setup's actual absolute directory; write as `vegas-encoder.ini` beside each DLL; hash the **rendered bytes** |
| `installer\VegasEncoder-x64.fio2007-config` | Each selected VEGAS root, with that exact name |
| `installer-inputs.json` | Build/verification input; not a per-target installed manifest |

The candidate's `plugin\vegas-encoder.ini` is for the manual owner trial: it points
at this candidate's app/logs. **Do not ship those worktree paths in setup.** The
installer template omits a custom LogDir so native logs use their existing default.
Never package trial `data`, logs, capacity inputs or rollback backups. App runtime
`app\data` is a different directory and is required. No FFmpeg/FFprobe is bundled;
the user configures their own installation through C3/C7.

Read-only `dumpbin /DEPENDENTS` on this build shows the runner requires
`MSVCP140.dll`, `VCRUNTIME140.dll`, `VCRUNTIME140_1.dll` and the Windows UCRT.
Setup needs an appropriate x64 Microsoft VC++ runtime prerequisite. No redistributable
has been downloaded, bundled or executed here; owner selects its licensed deployment
policy. Preserve bundled notices; the project's own release license is still undecided.

## VEGAS discovery and support

`Get-VegasTargets.ps1` reads HKLM/HKCU uninstall/App Paths registration and explicit
candidate directories, then reads actual `vegas<digits>.exe` PE/version metadata.
It deduplicates trailing separators and ignores helpers such as VegasCapture.
`Prepare-B7` includes the resulting snapshot in its manifest. Detection never
loads a host or establishes ABI compatibility. Re-detect on the owner's machine
at setup time; do not hardcode these local paths as universal destinations.

| Local detected host | x64 | Installer eligibility now |
| --- | --- | --- |
| Boris FX 2026.0.3.189 | yes | Only current owner-trial target; B6 gates still open |
| VEGAS 23 build 278 | yes | Detection only, older-host adapter research pending |
| VEGAS 22 build 248 | yes | Detection only |
| VEGAS 21 build 108 | yes | Detection only |
| Sony VEGAS 13 build 453 | yes | Detection only; discovered in registration |

## Close, update, rollback and uninstall rules

These are inputs/requirements for setup. The existing development installer only
manages **one target's plug-in**, not the shared app or a multi-target transaction.

1. Before mutation, require every affected VEGAS and every VegasEncoder desktop,
   popup and monitor process to close. Verify actual executable paths, including
   helpers under each target root, rather than only matching process names.
   Do not terminate a render or schedule a partial replacement on reboot.
2. Keep one shared app version with all target DLLs. Setup must record every
   successfully installed target and update all those targets by default, as the
   owner decided. An unavailable/moved/changed target needs explicit resolution;
   do not silently leave an old DLL pointing to a replaced incompatible app.
3. Preserve the current development installer's safeguards: exact owned paths,
   no reparse traversal, recorded file hashes including INI/discovery, refusal of
   unknown/unrecorded files or locally changed bytes, staging before replacement,
   and restoration on failure. Its `vegas-encoder-install/1` manifests contain
   absolute target/plugin/config paths, host version and hashes of DLL/INI/optional
   PDB plus discovery. Write them from final installed bytes if retaining this
   development-tool interoperability. Do not copy the build manifest as one.
4. Setup needs its own durable transaction journal for the shared app and **all**
   selected targets. Before changing anything, preserve exact app files, per-host
   DLL/INI/discovery and prior manifests. On any failed target, restore the entire
   previous matched set. Retain a rollback copy after success until the owner
   accepts the update. The existing script cleans its temporary previous files
   after success; the owner's separately preserved rollback is therefore required.
5. Leave unrelated exporters, master's `.claude/`, all candidate folders and backups
   alone. Keep user `%APPDATA%\VegasEncoder` and `%LOCALAPPDATA%\VegasEncoder`
   settings/library/cache/jobs, saved VEGAS templates and trial overrides through
   updates and default uninstall. No proof-template migration or library rewrite.
6. Uninstall removes only registered owned files after validation. Remove the
   shared app only when no recorded target needs it, with its processes closed.
   Changed/unrecorded files cause refusal/preservation, not recursive deletion.

The manual trial install/rollback remains in [B6_TRIAL.md](B6_TRIAL.md). Release
signoff still needs real focus, cancellation/failure recovery, payload capacity
and monitor time/memory evidence. The owner builds and tests the Inno installer;
no installer, installation or compatibility claim for another host is produced here.
