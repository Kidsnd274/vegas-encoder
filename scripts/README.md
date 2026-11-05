# Scripts

Run these commands from the repository root in PowerShell 7. The top level
contains the entry points for routine builds, packaging and manual maintenance.

| Command | Purpose |
| --- | --- |
| `Build-Release.ps1` | Build the app/core/exporter, stage a matched bundle and compile Setup. `-Action Build` compiles only; `-Action Package` packages an unchanged receipted build. |
| `Build-Installer.ps1 -BundleDir <bundle>` | Compile an existing verified frozen installer bundle. |
| `export_app_icons.bat` | Regenerate app icons from the selected SVG. Use `--check` to verify freshness. |
| `Get-VegasTargets.ps1` | Inspect registered/manually supplied VEGAS locations without installing anything. |
| `Install-VegasEncoder.ps1` | Advanced development-only manual exporter install/removal, with ownership manifests and backups. Normal product installation uses Setup. |

```powershell
.\scripts\Build-Release.ps1
.\scripts\Build-Release.ps1 -Action Build
.\scripts\Build-Installer.ps1 -BundleDir "$PWD\build\my-frozen-bundle"
.\scripts\export_app_icons.bat --check
.\scripts\Get-VegasTargets.ps1
```

`etc/` contains supporting build scripts, shared version/receipt functions,
generators, test runners and retained trial/diagnostic utilities. Developers
can still invoke them explicitly; they are not routine entry points. For example:

```powershell
python -I scripts/etc/Test-Versions.py
.\scripts\etc\Test-ReleaseInputs.ps1
python -I scripts/etc/Test-Setup.py
.\scripts\etc\Test-LegacyContainers.ps1
```

The legacy-container runner builds into a fresh ignored directory, then checks
the portable core, actual DLL in modern/container-fallback/manual/automatic-name modes, native snapshots and popup
context/Apply. It reads a compiled matching app's version resource; it does not
launch the app/VEGAS, install anything or qualify an older host. Its output and
optional `-AppPath` are documented in the script parameters. With an explicit
`-FFmpegPath`, it additionally runs the actual adapter over fake host streams and
that supplied FFmpeg across five containers in modern/automatic modes, including
actual-path records, cancellation, recovery and collision checks. It does not
launch VEGAS or the app. General Setup still
supports only the already-qualified target.

See [building](../docs/BUILDING.md) and [installer/recovery](../docs/INSTALLER.md)
for requirements, options and qualification limits. Historical experiment and
component-handoff documents retain their originally recorded script paths;
supporting scripts referenced there now live under `scripts/etc/`.
