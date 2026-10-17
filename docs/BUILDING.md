# Windows x64 build and output map

Build from `L:\repos\vegas-encoder` using the existing MSVC x64 / Windows SDK,
PowerShell 7, Python and Flutter SDK (`L:\flutter`). Builds do not install or
replace the VEGAS exporter. FFmpeg/FFprobe are user-supplied runtime tools;
they are not bundled product components.

## Components

| Component | Source | Built output |
| --- | --- | --- |
| Flutter app: desktop, VEGAS editor popup and progress window in one executable | `app/lib`, `app/windows/runner` | `app/build/windows/x64/runner/Release/VegasEncoder.exe`, with compiled Dart code in `data/app.so` |
| Portable C++ core: compile, validation, lint, completion and recipe/payload logic | `src/core`, Dart interface in `packages/ve_core` | App-bundled `ve_core.dll`; standalone `build/core/ve_core.dll` and `ve_core_static.lib` |
| Windows services: file operations, GPU information and read-only VEGAS inspection | `src/services`, Dart interface in `packages/ve_services` | App-bundled `ve_windows_services.dll` |
| VEGAS exporter: Render As integration and FFmpeg render engine | `src/vegas`, `src/engine`, `src/support` | `build/recipe-proof/vegas-encoder/vegas-encoder.dll` |

The exporter links `ve_core_static.lib` into its DLL. It does not load the app's
`ve_core.dll`. The engine has no separate runtime DLL. The desktop, editor popup
and monitor use the same app executable, selected by launch arguments.

## Build the current exporter and app

Run in PowerShell:

```powershell
Set-Location L:\repos\vegas-encoder

# Embed the current committed schema/catalog into the C++ header.
python -I scripts/Generate-CoreData.py

# Builds the native core, then the current recipe-enabled VEGAS exporter.
cmd /d /c 'scripts\build.cmd "" recipe-proof'

# Builds the app AND its core/services DLLs through package build hooks.
Push-Location app
L:\flutter\bin\flutter.bat pub get
L:\flutter\bin\flutter.bat build windows --release --build-name 0.1.7 --build-number 1
Pop-Location
```

Stop if a command fails. The empty first argument to `build.cmd` lets the script
find this machine's existing MSVC tools. To override, pass `vcvars64.bat` as the
first argument or set `VEGAS_ENCODER_VCVARS`.

Use **`recipe-proof`** for the current product integration; invoking `build.cmd`
without that argument produces the older fixed-profile development variant.
The current exporter is `0.1.7-recipe-proof`, numeric `0.1.7.1`, and requires
the app build stamped `0.1.7+1`. Keep the explicit app version flags: the current
`app/pubspec.yaml` default is still `0.1.0+1`.

Flutter supports these version overrides in its
[Windows build documentation](https://docs.flutter.dev/deployment/windows).
The actual x64 paths here are verified against this checkout's build output.

## Build just the native core

```powershell
Set-Location L:\repos\vegas-encoder
python -I scripts/Generate-CoreData.py
cmd /d /c scripts\build-core.cmd
```

Outputs are `build/core/ve_core.dll` and `build/core/ve_core_static.lib`.
`ve_core.lib` is the DLL import library. The app's package hook independently
builds its own core DLL from the same source; building only this standalone
core does not update an already-built app or exporter. Rebuild the affected
consumer to incorporate core changes.

## Runtime files and installer inputs

The complete app runtime is under
`L:\repos\vegas-encoder\app\build\windows\x64\runner\Release\`:

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
source; use the finished Release directory.

The exporter build folder also contains `vegas-encoder.ini`, a matching
`vegas-encoder.pdb` and compiler/linker intermediates (`.obj`, `.lib`, `.exp`,
`.ilk`, `.res`). Intermediates are not runtime inputs; PDB symbols are optional
diagnostic files. The development INI must be rendered for the intended app path.

The latest prepared bundle is
`L:\repos\vegas-encoder\build\release-inputs-profile-list\`:

| Directory/file | Purpose |
| --- | --- |
| `app/` | Complete app runtime plus dependency/font notices |
| `plugin/` | Exporter DLL, matching optional PDB and development INI |
| `installer/vegas-encoder.ini.in` | Installer INI template; substitute the final `{app}` path |
| `installer/VegasEncoder-x64.fio2007-config` | VEGAS discovery file |
| `installer-inputs.json` | Exact file hashes, versions and source state at staging time |

See [installer handoff](B7_INSTALLER_INPUTS.md) for staging commands and final
destinations. The per-host exporter goes under
`{vegasDir}\FileIO Plug-Ins\vegas-encoder\`; the shared app has its own directory.
Do not ship worktree paths from the development INI.

Build/staging output is ignored by Git. Existing staged manifests remain records
of their creation state even after a source commit; create a fresh bundle to
record a newer commit. Preserve the currently installed trial at
`build/release-inputs-containers-dashboard` and its rollback; no build command
above updates it or installs anything.
