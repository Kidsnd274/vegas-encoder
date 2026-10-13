# App workstream

Updated: 2026-10-14 (Asia/Singapore). Branch `ws/app`. Status: **F0 and F1 done; F2
and F3 done except the parts waiting on platform** (listed under Needs). F2 and F3 run
on the platform fakes (B0). Master through B2 (`659fe02`) is merged; the app still
selects `FakeVeCore`, so the editor reacts to edits only after the switch to
`NativeVeCore` (see Handoff).

Nothing here ran inside VEGAS. Window behaviour was checked against a fake host (a
WinForms window standing in for VEGAS); screens and components were checked with
widget and golden tests on the platform fakes and local sample data.

## Done

**F0: project, runner, modes, theme, fonts, spikes.**

- `app/` is a Windows-only Flutter app (`VegasEncoder.exe`) on Flutter 3.47.7 / Dart
  3.13.5 from `L:\flutter`, with Riverpod 3.4.3. Runtime dependencies are Riverpod and
  its transitive packages (MIT/BSD), plus the platform's `ve_core` and `ve_services`
  (path dependencies, no third-party packages).
- Mode dispatch (`lib/app/launch.dart`, `windows/runner/launch_options.cpp`): desktop,
  `--edit-session <dir>`, `--render-monitor <file>`; the first mode flag wins in both.
  A flag without its path shows the problem in that window.
- Runner (`windows/runner/`): app-drawn title bar on a caption-less frame that keeps the
  system resize borders, snap and shadow; popup ownership and centring on the owner
  before first show; progress window that never activates (`WS_EX_NOACTIVATE`,
  `SW_SHOWNOACTIVATE`, `MA_NOACTIVATE`), keep on top, bottom-right of the foreground
  window's monitor; desktop single instance; owner re-enabled before the popup closes;
  reduced-motion reporting; startup trace (`VEGAS_ENCODER_STARTUP_TRACE`); renderer
  switch (`VEGAS_ENCODER_RENDERER`). Channel `vegas_encoder/window`.
- Theme follows Windows live; Windows "Animation effects" off zeroes motion.
- Instrument Sans and JetBrains Mono bundled with their OFL texts and provenance
  (`app/assets/fonts/README.md`).

**F1: design system** (`app/lib/design/`), from `design/signal-flow.html`: tokens light
and dark on a `ThemeExtension`, and the components listed in UI_SPEC §11. The
design-system gallery (`features/gallery/`) stays as the F1 reference: Ctrl+Shift+D in
debug builds, and the goldens use it.

**F2: Presets screen and Basic editor** (`lib/features/presets/`, `lib/state/`):

- Providers for `VeCore` and the C3 services, defaulting to the fakes
  (`state/services.dart`); tests override them. The desktop previews against the
  documented sample (`state/preview.dart`), labelled as such.
- Library: Built-in then Mine, favorites first, then categories, then names; search
  over name, tags, encoders and summary; All/Built-in/Mine and Favorites only; rows with
  the core's summary line, output-depth glyph, Advanced tag, unsaved dot, and "Needs
  x264: not in this FFmpeg" for the chosen FFmpeg; an error mark (with the core's
  messages as a tooltip) when the core finds errors for that FFmpeg. Context menu
  (right-click, Shift+F10, Menu key): Duplicate, Rename…, Delete… (Mine only). An empty
  search offers New preset (a preset in Mine started from the first built-in) and
  Show all presets. Below 1280 px the library is a rail; it opens over the editor.
- Header: name with Edited, Built-in/Mine, category, revision; Basic/Advanced (Advanced
  says it arrives in F4); the FFmpeg the checks are for; Duplicate, Revert (with Undo),
  Save preset or Save as new preset. Built-ins save as a new preset in Mine with origin
  `builtin/<id>`.
- Signal path from the core's signal facts (C2 `signalPath`, platform's app-review
  additions): bits, formats, chroma and conversion for video and audio ("p010le to
  yuv420p, 4:2:0, precision lost"; "flt to s32, 24-bit integer, precision lost"), and
  a broken wire when `containerSupport` is `no`. Availability from the installation.
  Without a compile result the recipe and catalog name the stages and the wires claim
  no conversion either way. The audio-off node stays selectable so audio can be turned
  back on.
- Panels: From VEGAS (facts), Video (encoder picker, rate control, quality by mode,
  speed, tune/profile/multipass, bit depth, keyframes, color tags, Extra arguments),
  Audio (on/off, encoder, rate control, bitrate/VBR/level, sample rate, channels, Extra
  arguments), Container (options with what each can hold, fast start, Apple tag), File
  (size card from the core's estimate, file name, how it is worked out). Hidden controls
  keep their recipe values; a new encoder resets its own controls to null (encoder
  default, resolved by the core). Changed fields show a dot and Reset; the core's issues
  show at their field and in Checks, where "Show setting" opens the node, scrolls to the
  control and focuses it. Bitrate modes take Mb/s with common values and read "8 Mb/s
  average, 12 Mb/s peak".
- Command column: the core's tokens grouped by stage or on one line, the inputs chip,
  the selected node's group tinted, Copy and Ctrl+Shift+C; Checks for the chosen FFmpeg.
  Clicking a token opens and focuses the control that produced it (`CommandToken.field`);
  pointing at or focusing a control lights its tokens; tokens an error points at
  (`Issue.tokenIndices`) are marked.
- Keyboard: Ctrl+K opens a preset by name; Ctrl+F searches the library; Ctrl+S saves;
  F6 / Shift+F6 move between library, diagram, settings and command.
- Drafts per preset; "changed in another window" banner (Reload / Keep editing), then
  Replace it / Save as new preset on save. Closing with unsaved changes asks Save /
  Don't save / Cancel however the window is closed (title bar, Alt+F4, taskbar): the
  Windows engine sends an exit request first, answered by an `AppLifecycleListener`.
- The diagram and header grow with the Windows text size (heights; node text that
  doesn't fit ends in an ellipsis).
- C7 `uiState`: the size card keeps the length exactly as typed (written after a short
  pause, re-applied on a revision conflict); the desktop window's restored bounds and
  maximized state are saved on close and restored before the first frame, clamped to a
  current monitor's work area and the minimum size (runner `getBounds`, `configure`
  with `bounds`). With B0's in-memory settings fake neither survives a restart; B3's
  real repository makes them persist.
- When the fake core has no answer (`B0-FIXTURE-MISSING`), the command, checks and
  estimate say the real core (B2) is needed instead of showing a stale result.
- Settings > Theme is stored in C7 `theme`. New components: `showVeDialog`,
  `showVeTextDialog`, `VeToast`; `VeField` draws its Reset; `SizeQualityCard` shows the
  core's figures and no longer works out a size.

**F3: FFmpeg, History and Settings** (UI_SPEC §5, §6, §6a; `lib/features/ffmpeg/`,
`history/`, `settings/`, `lib/state/ffmpeg.dart`, `history.dart`, `settings.dart`):

- Providers next to F2's (`state/services.dart`): `ffmpegDiscoveryProvider`,
  `hardwareTestsProvider`, `jobRepositoryProvider` (fakes by default),
  `discoveredInstallationsProvider`, `jobsProvider`, `jobRecordProvider`.
- `MachineSettingsWriter` (`state/settings.dart`): every C7 write copies the latest
  settings, changes its own fields, saves with `expectedRevision` and reapplies on a
  conflict. UI state, the default FFmpeg, the installation list and the Settings
  switches all go through it. `desktopSectionProvider` moves between sections.
- FFmpeg: installation cards (default, build/license/source, path, checked, counts,
  probe progress or failure, presets it can't render), Add FFmpeg… through a native
  Open dialog (runner `pickFile`, `windows/runner/file_dialog.cpp`), Scan again, Set as
  default, Copy path, Remove…; capability list by codec with Video/Audio, All/Only
  problems/Hardware, search and Ctrl+F; encoder detail with the test-encode diagram,
  FFmpeg's stderr line, presets that use it (opens them), Test again. Discovery's list
  is written to C7 `installations`; a default discovery no longer lists keeps its
  record. New availability state "Not checked yet" (C3 `unknown`; F2 showed it as
  Testing…).
- History: status filter, list with encoder, length, time taken, × realtime (finished
  renders only) and size; detail with the result sentence, stderr tail, exit code and
  HRESULT, output, FFmpeg identity, output check and the command; Copy command
  (Ctrl+Shift+C), Open settings as new preset (`PresetsController.createFromRecipe`),
  Open folder disabled until a reveal service exists.
- Settings: Theme; Default FFmpeg with Manage installations; progress window, keep on
  top (disabled while the window is off), check each file; About with the core version
  and that services are fakes.
- `VePageHeader`, `VeToastHost`, public `VeDotGridPainter`; `encodersNeeded` shared by
  the library's marks and FFmpeg's "Used by".
- The master merge brought B2's build hook into `ve_core`; `pubspec.lock` now resolves
  its pinned Dart-team packages (`hooks`, `code_assets`, `native_toolchain_c` and their
  BSD dependencies). Without that `flutter test` failed building native assets.
- Built with two parallel agents (History, Settings) on files each owned; the parent
  reviewed their goldens and code.

## Tests

`flutter test` in `app/`: 319 tests, all passing (225 after F2). `flutter analyze`: no
issues. All on fakes: platform fakes (B0), a fake window controller, and for F3 two
test doubles (`test/ffmpeg_doubles.dart`: a probe and hardware tests that stall).

F3 added:

- Unit (`ffmpeg_test.dart`, 20): which fact wins for an encoder's state, unknown vs
  missing, capability groups, filters and search, the not-ready summary, installation
  cards (line, checked, counts, blocked presets, probe progress), encoder detail; the
  controller's Set as default (next revision), Add (recorded, probed, cached,
  selected), a refused Add, Remove (not the default), Scan again keeping a vanished
  default and writing nothing when unchanged, a failed probe, hardware results, and
  cancelling running work on dispose. History display (13): sentences, speed, Windows
  quoting, the encoder for Advanced recipes; and `createFromRecipe`.
- Widget: FFmpeg (15: cards and default, row detail and arrow keys, installation,
  audio, only problems, search and Ctrl+F, Set as default saved, Add with the Open
  dialog faked and cancelled, a refused Add, Remove… with confirm, Copy path, Testing…,
  test results and Test again, probe progress and failure, Scan again, opening a preset
  from "Used by", no installations, the 1100 px window); History (10: list, filter,
  detail, copy, open as new preset, live publish, empty states, keyboard); Settings
  (11: each control saved at revision + 1, keep on top disabled, default FFmpeg,
  theme, live change from elsewhere, conflict reapplied, failed save, no installations,
  Manage installations, About). The app shell test now walks Ctrl+2…4.
- Golden: FFmpeg (default, failed hardware encoder, LGPL with only problems, audio,
  probing, 1100 px), History (default, failed job, narrow), Settings (default, About,
  no FFmpeg), each light and dark: 24 new images, 74 in all. History shows local times,
  so its goldens assume this machine's time zone (Asia/Singapore), as F2's dates do.

- Unit: launch parsing, formatting, tokens and contrast; recipe edits (canonical
  comparison, encoder changes, field paths, new names and IDs); mapping (command
  grouping, signal path with and without a compile result, availability, mux problems,
  encoder groups, library rows, grouping, search and filters); the Presets controller
  (drafts, save as new, save to the next revision, conflicts, favorites, rename,
  delete, checks per FFmpeg, theme stored in C7).
- Widget: controls, signal path, size card, command view, app shell, and the Presets
  screen (node panels, edit/Revert/Undo/Reset, save as new, search and filters, an
  FFmpeg without x264, Show setting focusing the control, audio off and on, context
  menu, changed in another window, close with unsaved changes through the exit request,
  copy, Ctrl+K, F6 panes, bitrate, New preset, error marks, command layout, the narrow
  rail, token click and lighting, the remembered length, bounds saved on close).
- Unit additions: token fields and error tokens, signal facts (ProRes chroma, PCM
  24-bit precision, container support), and searching 500 presets under the 150 ms
  budget (fakes only).
- Golden: 25 views × light and dark = 50 images in `app/test/golden/goldens/`,
  including the Presets screen on the video, file, audio and container nodes, an edit,
  bitrate mode, an FFmpeg without x264, the 1100 px window with the library open, and
  150% text. Regenerate with `flutter test --update-goldens test/golden`.
- Release build: `flutter build windows --release` succeeds. A launch showed its first
  frame and closed with exit code 0 on WM_CLOSE (what Alt+F4 sends) with nothing
  unsaved. The unsaved-changes question on a real close is covered by widget tests
  only, not clicked through in the running app.

## Spike results (F0)

Release build, Windows 11 Pro 26300, 125% scaling, three monitors, fake host. Run with
`app/tool/spikes/run_window_spikes.ps1` (report and screenshots go to the ignored
`app/build/spikes/results/`).

| Spike | Result |
| --- | --- |
| Start time | Process creation to window shown, warm, median of 10: **popup 341 ms**, desktop 455 ms (the desktop drew the full gallery) with Skia. With Impeller: popup 1,287 ms, desktop 1,338 ms; about 1 s of it is engine start-up before Dart runs. A true cold start (empty file cache) was not measured. Budget: popup ≤ 1.0 s cold, ≤ 0.7 s warm |
| Renderer | Flutter 3.47.7 defaults to Impeller on Windows, OpenGL ES with SDF text (`Using the Impeller rendering backend (OpenGLESSDF)`). The runner now defaults to **Skia** for start time; `VEGAS_ENCODER_RENDERER=impeller` opts in. Text side by side at 1:1 looked the same. Not checked with VEGAS holding the GPU |
| Owner window | Owner set before first show (`GWLP_HWNDPARENT`), centred on the owner within 4 px, foreground on show, hidden and restored with the owner, owner re-enabled and foreground again after Close. After a kill (crash) the owner did not get the foreground back by itself, but its process could take it with `SetForegroundWindow` after re-enabling |
| Live theme | Flipping `AppsUseLightTheme` switched the running app in about 0.1 s and back again; the engine watches the registry key itself |
| No-activate window | Progress window shown and clicked while the fake VEGAS stayed foreground; `WS_EX_NOACTIVATE` and topmost set; 20 px (16 logical) from the work-area corner |
| Single instance | A second desktop launch exits with code 0; the first stays and closes cleanly |

**F2 recheck (2026-10-13), after the runner change for window bounds.** Same machine
and spike harness; the F0/F1 build (`c56c2e5`) rebuilt as a baseline and run alternately
with the current build, because this desktop session is busier than F0's.

| Check | Baseline | Current |
| --- | --- | --- |
| Start, Skia, warm, 10 runs | desktop shown 517 ms (Dart main to first frame 33 ms); popup 398 ms | desktop 688 ms (Dart main to first frame 252 ms); popup 439 ms |
| Owner window | Owner set, centred, hidden and restored with the owner, re-enabled, foreground after Close | Same |
| No-activate progress window | `WS_EX_NOACTIVATE`; topmost (keep on top was on) | `WS_EX_NOACTIVATE`; not topmost (off by default, owner decision) |

The desktop's extra ~220 ms is Dart work before the first frame: B0's fake core decodes
its fixture JSON and the library compiles each preset; the native core (B2) replaces
it. The popup path does no new work (it differs from baseline only by machine noise).
The progress window's "VEGAS stays foreground" check is inconclusive in this session:
the harness could not make its fake VEGAS foreground for either build.

**F3 recheck (2026-10-14), after the runner change for the Open dialog.** Release build
(42.7 s, no C++ warnings or errors), same machine and harness, theme check skipped,
fake host. The first start run overlapped with `flutter test`; the second is the
comparison.

| Check | Result |
| --- | --- |
| Start, Skia, warm, 10 runs | desktop 660 ms (Dart main to first frame 248 ms); popup 410 ms. Impeller: 1,627 / 1,349 ms. No change from F2 (688 / 439 ms): only Presets draws at start |
| Owner window | Owner set, centred within 4 px, foreground, hidden and restored with the owner, owner re-enabled and foreground after Close; after a kill the owner can take the foreground back. Same as F0/F2 |
| No-activate progress window | **Conclusive this time:** the fake VEGAS stayed foreground when the window appeared and after a click on it; `WS_EX_NOACTIVATE`, not topmost, 20 px from the work-area corner |
| Desktop launch | Window shown, WM_CLOSE exits with code 0 |
| Open dialog (`pickFile`) | Compiled in; not clicked or automated |

## Owner decisions (2026-10-12)

- **Renderer: deferred.** The runner defaults to Skia for start time;
  `RendererFromEnvironment` in `windows/runner/main.cpp` is the one place to change, and
  `VEGAS_ENCODER_RENDERER=impeller` tries Impeller. Re-measure on each Flutter upgrade
  and with VEGAS running.
- **Flutter 3.47.7** at `L:\flutter` is intended. ROADMAP and WORKSTREAMS say so.
- **Light tokens accepted as the mockup has them**, including UI_SPEC §9's figures.
- **Keep on top off by default**, matching C7 `keepOnTop=false`. The progress window
  starts unpinned; F6 reads the remembered value.
- **Fake core limits: go to the real core.** Platform adds the four contract requests
  below, keeps B1 short and builds B2 next; no fixture sweep of edited states.

## Needs from platform

Delivered by platform's app-review additions (merged `a0d9b39`) and used in F2: token
fields and issue token indexes, signal-path facts, C7 `uiState`. C5 `hostHwnd` is for
the progress window (F6).

Delivered in B2 (merged `bbcbe91`), **not yet mapped by the app** (next app task, with
the `NativeVeCore` switch): `CompileResult.overriddenFields` for "set in Extra
arguments"; `SizeEstimate.minTotalBytes`/`maxTotalBytes` for the typed length's range;
`ResolvedSettings.gopFrames` for "2 s (60 frames at 29.97 fps)"; FakeVeCore treating
`{}` and absent `extensions` alike.

Open (additive):

| Need | Request |
| --- | --- |
| Favorites on built-ins | C3 saves are READ-ONLY for built-ins, so a star on a built-in lasts the session. Built-in favorite/pinned need a stored place |
| Duplicate origin | C3 defines `builtin/<id>` for copies of built-ins; copies of Mine presets get no origin until a form is defined. The same applies to History's "Open settings as new preset" (saved with no origin; a form such as `job/<id>` would do) |
| Installation health (F3) | UI_SPEC §5 states Changed on disk, Missing and No ffprobe have no fact in `FFmpegInstallation`. Needs a per-installation status from discovery/read (unchanged / changed since checked / executable missing / ffprobe missing), without probing |
| Discovery vs machine.json (F3) | Which is the source of truth for installations? The app shows `FFmpegDiscovery.watch()` and writes its list to C7 `installations` after Scan again, Add and Remove, keeping a default discovery no longer lists. If B3's discovery persists C7 itself, the app drops that write |
| Probe results on the installation (F3) | After a probe, does discovery's record update (`probedAt`, `probeMs`, `counts`, `availability`)? The app shows this session's probe from `ProbeProgress.capabilities` and caches it with `CapabilityCache.write`; it would rather read one updated record |
| Hardware results persisted (F3) | `HardwareTests.test` streams results, but nothing says where they are kept. The app holds them for the session. Does the service write them to the cache / installation availability, or should the app call `CapabilityCache.write`? |
| Job index summary (F3) | `JobIndexEntry` has no encoder, project, duration, elapsed or size, so History reads every record to fill the list. Long histories need these in the index |
| Full log (F3) | C6 carries only `stderrTail`. The full FFmpeg log needs a path or a read service |
| Error tokens in a job (F3) | UI_SPEC §6 highlights the option FFmpeg names. Needs the argv indexes in the job record; the app won't parse stderr |
| Job command line (F3) | The record should carry the core's `commandLine`; History quotes argv with standard Windows quoting until then. A recorded realtime figure would also replace History's length ÷ elapsed |
| Test this preset | UI_SPEC §2: encode 60 synthetic frames (testsrc2 + sine) with the selected FFmpeg, verify with ffprobe, stream the log. No C3 service covers it; HardwareTests is per encoder. Needs a service that runs it and streams progress and the log |
| Export, Show in folder, share string | Export… needs `PresetLibrary` to write the exported preset to a path the user picks (the app shows the file dialog); Show in folder needs the preset's file location or a "reveal" call; Copy share string needs a defined format. The app does no file or Explorer access of its own (AGENTS.md). History's Open folder needs the same reveal call |

## Open items

Waiting on platform (see Needs): the recommended quality band (B1 profiles); settings,
window bounds and length surviving a restart (B3's real settings repository); real
discovery, probes and hardware tests (B3); favorites on built-ins; Test this preset;
Export…, Show in folder / Open folder, Copy share string; installation health; the job
index summary, full log, error tokens and command line.

App side: switch `veCoreProvider` to `NativeVeCore` and map B2's delivered fields
(above); Advanced mode and Ctrl+M (F4); the popup's collapsible command strip (F5).
The Open dialog (`pickFile`) is built and covered with a fake controller; it was not
clicked through in the running app.

## Handoff for the next app agent

Start from `ws/app`. Read AGENTS.md, WORKSTREAMS.md, CONTRACTS.md, this file and
UI_SPEC first. F3 is done on the fakes. Next, in this order:

1. **The real core.** Platform asks the app to switch `veCoreProvider`
   (`state/services.dart`) from `FakeVeCore()` to `NativeVeCore()` now that B2 is
   merged, keeping explicit `FakeVeCore` overrides in widget and golden tests (the
   goldens were made with the fake). Then map B2's fields: `overriddenFields` ("set in
   Extra arguments" at the control), the typed length's `minTotalBytes`/`maxTotalBytes`,
   and `gopFrames` ("2 s (60 frames at 29.97 fps)"). Measure the desktop's start again
   (the fake core's fixture decoding was ~220 ms of it). Part of F7, but it unblocks
   edits in the editor.
2. **F4: Advanced editor** (UI_SPEC §3).

- Mapping from core and service results is display work in `features/*/display.dart`
  style files; never derive domain facts. Where a fact is missing, show less and add a
  request above.
- Machine settings writes go through `machineSettingsWriterProvider`
  (`state/settings.dart`); don't call `save` directly.
- Riverpod 3 retries a failed provider; while it retries, the value is loading with the
  error, so check `hasError` rather than matching `AsyncError`. Guard state writes after
  an await with `ref.mounted`.
- `CoreResult` (`state/editor.dart`) keeps a core failure explicit; the editor says
  what's missing instead of showing an old result.
- Before each commit: `flutter analyze`, `flutter test`; regenerate goldens only for
  intended visual changes and look at them. Window or runner changes: rebuild release
  and run `tool/spikes/run_window_spikes.ps1`.
