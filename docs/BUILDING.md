# Windows x64 build and output map

Build from `L:\repos\vegas-encoder` using the existing MSVC x64 / Windows SDK,
PowerShell 7, Python and Flutter SDK (`L:\flutter`). Builds do not install or
replace the VEGAS exporter. FFmpeg/FFprobe are user-supplied runtime tools;
they are not bundled product components.

The [scripts guide](../scripts/README.md) lists the top-level commands intended
for routine use. Supporting builds, generators and test runners live in
`scripts/etc/`; the release and icon entry points invoke them automatically.

## Components

| Component | Source | Built output |
| --- | --- | --- |
| Flutter app: desktop, VEGAS editor popup and progress window in one executable | `app/lib`, `app/windows/runner` | `build/release/vegas-encoder/app/VegasEncoder.exe`, with compiled Dart code in `data/app.so` |
| Portable C++ core: compile, validation, lint, completion and recipe/payload logic | `src/core`, Dart interface in `packages/ve_core` | App-bundled `ve_core.dll`; standalone `build/release/vegas-encoder/core/ve_core.dll` and `ve_core_static.lib` |
| Windows services: file operations, GPU information and read-only VEGAS inspection | `src/services`, Dart interface in `packages/ve_services` | App-bundled `ve_windows_services.dll` |
| VEGAS exporter: Render As integration and FFmpeg render engine | `src/vegas`, `src/engine`, `src/support` | `build/release/vegas-encoder/plugin/vegas-encoder.dll` |
| Installer support helper | `setup/native` | `build/release/vegas-encoder/setup/ve-install.exe` |

The exporter links `ve_core_static.lib` into its DLL. It does not load the app's
`ve_core.dll`. The engine has no separate runtime DLL. The desktop, editor popup
and monitor use the same app executable, selected by launch arguments.

## Configure versions once

Edit **`version.json`** at the repository root. This is the authoritative input:

| Field | Controls |
| --- | --- |
| `release.version` / `release.build` | App version, exporter numeric file version, staging versions and setup include |
| `release.exporterSuffix` | Optional exporter product suffix, currently `recipe-proof`; empty removes it |
| `core.version` / `core.packageVersion` | Core runtime stamp / Dart package metadata |
| `core.abi` / `core.schemaMax` / `core.contracts` | Implemented compatibility levels; not release counters |
| `services.packageVersion` | Windows services Dart package metadata |
| `legacyExporters` | Retained historical proof variants; normal product builds do not use these |

For example, release `0.1.7` and build `1` produce app `0.1.7+1` and Windows
numeric version `0.1.7.1`. The exporter suffix adds `-recipe-proof` to its product
label. Ordinary release bumps do not require bumping ABI/schema/contracts;
those values must reflect actual implemented interface/format support.

`scripts/etc/Generate-Versions.py` projects this input into `src/version.generated.h`,
the core's Dart ABI constant, all three pubspec version fields, and
`setup/version.generated.iss`. These are derived outputs, not separate settings.
The core's API, native preflight, exporter resources and staging all consume these
values. Core/services DLLs still have no separate Windows PE version resource;
the core reports its runtime stamp through its API.

## Build and package with one command

Run in PowerShell:

```powershell
Set-Location L:\repos\vegas-encoder

.\scripts\Build-Release.ps1
```

The default `-Action All` validates/synchronizes versions, generates core data,
resolves the pinned Flutter dependencies, builds the core and recipe-enabled
exporter, builds the app/core/services bundle with matching version flags, writes
a build receipt, stages a fresh installer-input directory, and compiles Inno Setup
into `dist/`. It stops on failure.
It does not upgrade tools, install, launch VEGAS, run an installer or execute tests.

```powershell
# Compile only, retaining the output folders below.
.\scripts\Build-Release.ps1 -Action Build

# Repackage the recorded product and compile Setup without recompiling the app/core.
.\scripts\Build-Release.ps1 -Action Package -OutputDir "$PWD\build\my-fresh-bundle"

# Build, stage to an explicit fresh directory, and compile Setup into dist/.
.\scripts\Build-Release.ps1 -OutputDir "$PWD\build\my-other-fresh-bundle"
```

Without `-OutputDir`, staging chooses a new timestamped directory under
`build/releases/`. Existing bundles are never replaced. Package-only requires
`build/product-build.json`: it refuses changed versions, tracked build-input
patches/commits, changed new-source path metadata, missing/added runtime files
or changed runtime hashes. The receipt covers the complete app runtime and native
DLL/INI/PDB and setup helper. New untracked source files are tracked by path/size/mtime; commit
source before the final release build for a stable source identity.

Tool paths are configurable with `-FlutterPath`, `-PythonPath`, `-VcVarsPath` and
`-IsccPath`. Inno Setup 6.7.1 is the verified compiler; install it separately if
missing. The default compiler is `%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe`.
Flutter defaults to the existing `L:\flutter\bin\flutter.bat` when present,
otherwise `flutter.bat` on PATH. MSVC uses the existing build script's detection
or `VEGAS_ENCODER_VCVARS`. No tool installation or upgrade is performed.

Flutter supports these version overrides in its
[Windows build documentation](https://docs.flutter.dev/deployment/windows).
The actual x64 paths here are verified against this checkout's build output.

Native hooks also register the version inputs as incremental build dependencies
and refuse stale projections, using Dart's [build-hook dependency tracking](https://dart.dev/tools/hooks).

## App icon assets

The selected option A SVG is `app/assets/icon/app_icon.svg`. After editing it,
run `scripts\export_app_icons.bat` from the repository root (or invoke that batch
file by absolute path from another folder). It exports a 256 px PNG alongside
the source, a 512 px Markdown PNG at `docs/assets/app-icon.png`, and a multi-size
Windows ICO directly to `app/windows/runner/resources/app_icon.ico`.
`scripts\export_app_icons.bat --check` verifies generated files without replacing
them. Generation needs Python and Inkscape; normal builds use the checked-in ICO.
See [icon workflow](../app/assets/icon/README.md) for tool overrides and details.

Flutter's existing `Runner.rc` embeds the ICO on the next Windows app build.
No `flutter_launcher_icons` dependency or separate generation step is needed.
The in-app title-bar mark already has the selected geometry and retains its
light/dark theme colours. The main README awaits the owner's later icon instructions.

## Lower-level builds and checks

```powershell
Set-Location L:\repos\vegas-encoder
python -I scripts/etc/Generate-Versions.py
python -I scripts/etc/Generate-CoreData.py
cmd /d /c scripts\etc\build-core.cmd
```

Outputs are `build/release/vegas-encoder/core/ve_core.dll` and `build/release/vegas-encoder/core/ve_core_static.lib`.
`ve_core.lib` is the DLL import library. The app's package hook independently
builds its own core DLL from the same source; building only this standalone
core does not update an already-built app or exporter. Rebuild the affected
consumer to incorporate core changes.

For a manual exporter build, use `cmd /d /c 'scripts\etc\build.cmd "" release'`;
without `release` it builds the historical fixed-profile variant. The old
`recipe-proof` argument is retained as an alias for `release`, using the same new
output folder. Existing legacy folders/candidates are preserved. The native
script and Flutter hooks check that generated version outputs are fresh. The
unified command handles generation automatically. Freshness/fixture checks:

```powershell
python -I scripts/etc/Generate-Versions.py --check
python -I scripts/etc/Test-Versions.py
.\scripts\etc\Test-ReleaseInputs.ps1
```

## Runtime files and installer inputs

The complete app runtime is under
`L:\repos\vegas-encoder\build\release\vegas-encoder\app\`:

```text
VegasEncoder.exe
ve_core.dll
ve_windows_services.dll
flutter_windows.dll
data/
  app.so
  icudtl.dat
  flutter_assets/...
```

Keep this directory together; `VegasEncoder.exe` alone is not the app bundle.
`flutter_windows.dll` is Flutter's engine runtime. Native-asset intermediates
and caches under `app/build/native_assets` / `.dart_tool` are not the packaging
source. Flutter still builds into its usual `app/build/windows/x64/runner/Release`
folder; the unified script publishes a complete copy into the product `app/` folder.
Previous published runtimes are retained under `build/previous-app-*`; old
candidates and installed paths are never relocated.

The exporter build folder also contains `vegas-encoder.ini`, a matching
`vegas-encoder.pdb` and compiler/linker intermediates (`.obj`, `.lib`, `.exp`,
`.ilk`, `.res`). Intermediates are not runtime inputs; PDB symbols are optional
diagnostic files. The development INI must be rendered for the intended app path.

The latest prepared bundle is
`L:\repos\vegas-encoder\build\release-inputs-scripts-layout\`
(earlier bundles are preserved):

| Directory/file | Purpose |
| --- | --- |
| `app/` | Complete app runtime plus dependency/font notices |
| `plugin/` | Exporter DLL, matching optional PDB and development INI |
| `installer/vegas-encoder.ini.in` | Installer INI template; substitute the final `{app}` path |
| `setup/` | Frozen modular `.iss` files, generated version include and setup icon |
| `installer/ve-install.exe`, `payload.json` | Installer helper and exact expected installed payload hashes |
| `installer/VegasEncoder-x64.fio2007-config` | VEGAS discovery file |
| `installer-inputs.json` | Exact file hashes, versions and source state at staging time |

See [installer handoff](B7_INSTALLER_INPUTS.md) for staging commands and final
destinations. The per-host exporter goes under
`{vegasDir}\FileIO Plug-Ins\vegas-encoder\`; the shared app has its own directory.
Do not ship worktree paths from the development INI.

The manifest includes the resolved versions and the SHA-256 of `version.json`,
alongside all app/plugin/helper/setup hashes. Setup consumes the frozen bundle,
never the live Flutter output. `setup/version.generated.iss` supplies AppVersion
and numeric VersionInfoVersion. All `.iss` sources remain under `setup/`.

`Build-Installer.ps1` verifies the frozen file set/hashes before and after compiling.
It writes a uniquely named `dist/VegasEncoder-<numeric-version>-windows-x64-setup-<timestamp>.exe`
and a JSON provenance/hash sidecar. It never runs Setup. To recompile an existing
verified bundle independently:

```powershell
.\scripts\Build-Installer.ps1 -BundleDir "$PWD\build\release-inputs-setup"
```

The native helper is built at `build/release/vegas-encoder/setup/ve-install.exe`
and installed under `{app}\setup-support`. It is only used by Setup; it is not
an app service. See [installer behavior and rollback](INSTALLER.md).

Build/staging output is ignored by Git. Existing staged manifests remain records
of their creation state even after a source commit; create a fresh bundle to
record a newer commit. Preserve the currently installed trial at
`build/release-inputs-containers-dashboard` and its rollback; no build command
above updates it or installs anything.
