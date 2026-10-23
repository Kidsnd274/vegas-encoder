# Where Vegas Encoder keeps data

Every place the app, the VEGAS exporter and Setup write to disk, as found in the
code on 2026-10-23. Use it when changing storage, writing support instructions or
deciding what uninstall removes ([INSTALLER.md](INSTALLER.md), Uninstall).

## Per-user data

Two roots hold everything the app and exporter save for a Windows account. Both
the app (`ServicePaths.windows()` in `packages/ve_services/lib/src/storage.dart`)
and the exporter (`Root` in `src/vegas/adapter/recipe_runtime.cpp`) build them the
same way. There is no setting that moves them or the preset library; the Settings
page only shows the two roots.

### Roaming: `%APPDATA%\VegasEncoder\`

| Path | Holds | Written by |
| --- | --- | --- |
| `machine.json` | FFmpeg installations, default FFmpeg, `verifyOutput`, `progressWindow`, theme and window bounds. Per user despite the name. | App (`file_repositories.dart`); the exporter reads it |
| `machine.json.lock` | Write lock for `machine.json` | App |
| `library\<id>.vepreset` | The user's presets | App (`file_repositories.dart`) |
| `library\.history\<id>\...` | Preset revision history | App |
| `library\preferences.json` | Stars and pins | App |
| `library\.write.lock` | Library write lock | App |

### Local: `%LOCALAPPDATA%\VegasEncoder\`

| Path | Holds | Written by |
| --- | --- | --- |
| `cache\<identityKey>.json` (+ `.lock`) | FFmpeg capability cache | App; the exporter reads it |
| `jobs\<jobId>.json`, `jobs\jobs.jsonl` | Render job records and their index | App (`job_files.dart`) and exporter |
| `jobs\<jobId>.live.json` | Live render status | Engine (`src/engine/job_store.cpp`) |
| `jobs\<jobId>.ffmpeg.log` | FFmpeg's error output for a render | Engine (`src/engine/recipe_job.cpp`) |
| `sessions\<uuid>\` | Editor sessions between VEGAS and the app: `request.json` from the exporter, `result.json` and `.result.lock` from the app | Exporter (`editor_session.cpp`) and app |
| `tests\<presetId>-XXXX\` | "Test this preset" runs: `input.p010`, `input.f32`, `output.<ext>`, `ffmpeg.log` | App (`preset_tests.dart`) |

### Exporter logs: `%LOCALAPPDATA%\vegas-encoder\`

Lower case with a hyphen: a different folder from the local root above.

- `vegas-encoder-<host exe>-<timestamp>-<pid>.log`: one diagnostic log per VEGAS
  process (`src/support/diagnostics.cpp`).
- `render-<pid>-<n>.ffdiag`: written here when VEGAS gives no output path
  (`src/vegas/adapter/render.cpp`).

`LogDir=` in the exporter's `vegas-encoder.ini` can point these anywhere. Setup's
INI leaves it unset; development bundles set it to `<bundle>\logs`.

### Development override

`VEGAS_ENCODER_DATA_ROOT=<folder>` moves both roots to `<folder>\Roaming` and
`<folder>\Local`. It is read by the app (`dataRootOverride()` in
`app/lib/state/services.dart`), by the exporter (`Root` in `recipe_runtime.cpp`) and
by the single-instance check (`app/windows/runner/single_instance.cpp`, only to tell
instances apart). It is for development, spikes and isolated trials. It does not
move the exporter logs.

## Next to render output

In the folder the user renders to in VEGAS:

- `<stem>.ve-partial-<nonce><ext>`: the temporary output while rendering
  (`src/engine/encode.cpp`).
- `<output>.ffmpeg.log`: only as a fallback when there is no jobs folder.

## Files the user picks

- Preset export writes a `.vepreset` wherever the user saves it
  (`preset_transfer.dart`). Import only reads.
- VEGAS render templates (`.sft2`): Vegas Encoder never writes them. It keeps a
  recipe snapshot in the template's private payload, and VEGAS saves that into its
  own `.sft2` file when the user saves the template. Setup never copies or changes
  them.

## Machine-wide (Setup, running as administrator)

| Path | Holds |
| --- | --- |
| `%ProgramData%\VegasEncoder\Installations\{instance-guid}.json` | Installation records: one for the app, one per VEGAS version with an exporter |
| `%ProgramData%\VegasEncoder\Setup\{transaction-guid}\` | Rollback backups from each setup or uninstall run: `transaction.json` and `N.bak` |
| App folder, default `%ProgramFiles%\Vegas Encoder` | App files, `setup-support\ve-install.exe`, `vegas-encoder-setup.json` |
| `<VEGAS>\FileIO Plug-Ins\vegas-encoder\` | `vegas-encoder.dll`, `vegas-encoder.ini` (holds the app path), `install-manifest.json` |
| `<VEGAS>\VegasEncoder-x64.fio2007-config` | Tells VEGAS to load the exporter |

The `VegasEncoder`, `Setup` and `Installations` folders under ProgramData are
readable and writable only by administrators and SYSTEM. Setup's request/result
INI files and its helper copy live in Inno's temporary folder and go when Setup
exits. The scripted development installer also writes
`%TEMP%\vegas-encoder-install-<guid>.log`.

## Not written

- No crash dumps.
- Nothing in Documents.
- No registry writes by the app or exporter; they only read registry keys to find
  VEGAS and the Windows theme. Setup's own uninstall entry is Inno's.

## What uninstall removes

Always: the app folder, every recorded exporter (the DLL, INI, manifest and
discovery file in each VEGAS folder) and the installation records.

Only when ticked in the uninstall dialog, or passed to a silent uninstall, and
only for the Windows account running the uninstaller:

| Choice | Removes |
| --- | --- |
| Settings, caches, render logs and setup backups (`/REMOVEDATA`) | Everything in `%APPDATA%\VegasEncoder\` except `library\`; all of `%LOCALAPPDATA%\VegasEncoder\` and `%LOCALAPPDATA%\vegas-encoder\`; finished setup backups under `%ProgramData%\VegasEncoder\Setup\` (a pending one is kept for recovery) |
| Preset library (`/REMOVEPRESETS`) | `%APPDATA%\VegasEncoder\library\` |

Never removed: render outputs, exported `.vepreset` files, VEGAS `.sft2` templates,
the user's FFmpeg, a custom exporter `LogDir`, and folders under
`VEGAS_ENCODER_DATA_ROOT`. Removal never enters a junction or symbolic link, and it
refuses a data root that is one.

## Known inconsistency

`docs/product/research/FFMPEG_DISCOVERY.md` names an `ffmpeg-cache\` folder; the
code uses `cache\` (as `docs/product/FFMPEG_INTEGRATION.md` says). The research
note is historical and left unchanged.
