# App workstream

Updated: 2026-10-13 (Asia/Singapore). Branch `ws/app`. Status: **F0 and F1 done; F2
done except the parts waiting on platform** (listed under Needs). F2 runs on the
platform fakes (B0); the editor reacts to edits only once the real core (B2) lands.

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
- Signal path from the core's compile result: conversion pip from the resolved pixel
  format, notes from V-DEPTH-DOWN / V-CHROMA-UP, availability from the installation,
  "can't mux" from the catalog's codec-to-container table. Without a compile result it
  is drawn from the recipe and catalog and claims no conversion either way. The
  audio-off node stays selectable so audio can be turned back on.
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
- Keyboard: Ctrl+K opens a preset by name; Ctrl+F searches the library; Ctrl+S saves;
  F6 / Shift+F6 move between library, diagram, settings and command.
- Drafts per preset; "changed in another window" banner (Reload / Keep editing), then
  Replace it / Save as new preset on save. Closing with unsaved changes asks Save /
  Don't save / Cancel however the window is closed (title bar, Alt+F4, taskbar): the
  Windows engine sends an exit request first, answered by an `AppLifecycleListener`.
- The diagram and header grow with the Windows text size (heights; node text that
  doesn't fit ends in an ellipsis).
- When the fake core has no answer (`B0-FIXTURE-MISSING`), the command, checks and
  estimate say the real core (B2) is needed instead of showing a stale result.
- Settings > Theme is stored in C7 `theme`. New components: `showVeDialog`,
  `showVeTextDialog`, `VeToast`; `VeField` draws its Reset; `SizeQualityCard` shows the
  core's figures and no longer works out a size.

## Tests

`flutter test` in `app/`: 218 tests, all passing. `flutter analyze`: no issues. All on
fakes: platform fakes (B0) and a fake window controller.

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
  rail).
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

From the B0 review (sent; additive):

| Need | Request |
| --- | --- |
| Command view | The recipe field per display token (click-to-field, lit tokens), and which tokens an error issue points at |
| Signal path | Per-stream facts: audio output sample format and bits, chroma change, conversion yes/no and its note, "container can't hold this stream" as data, and display labels for what VEGAS delivers. F2 reads pips from the resolved pixel format, notes from V-DEPTH-DOWN/V-CHROMA-UP and labels P010/f32le itself until then |
| Progress window placement | VEGAS's main HWND in the C5 launch arguments or live file |
| App UI state | A place for desktop window bounds and the last length typed in the size card |

New from F2 (additive):

| Need | Request |
| --- | --- |
| Favorites on built-ins | C3 saves are READ-ONLY for built-ins, so a star on a built-in lasts the session. Built-in favorite/pinned need a stored place |
| Estimate range for a length | `SizeEstimate` has min/max per minute but a total only for the middle figure. The card shows "typically X to Y" per minute until the core gives the range for the typed length |
| Keyframes in frames | The resolved `-g` in frames, for "2 s (60 frames at 29.97 fps)" (UI_SPEC §2); not shown until then |
| FakeVeCore matching | Fixtures match exact JSON, so a model constructor's `extensions: {}` misses them. The app builds the sample media and paths from JSON; treating `{}` and absent alike would make this unnecessary |
| Duplicate origin | C3 defines `builtin/<id>` for copies of built-ins; copies of Mine presets get no origin until a form is defined |
| Test this preset | UI_SPEC §2: encode 60 synthetic frames (testsrc2 + sine) with the selected FFmpeg, verify with ffprobe, stream the log. No C3 service covers it; HardwareTests is per encoder. Needs a service that runs it and streams progress and the log |
| Export, Show in folder, share string | Export… needs `PresetLibrary` to write the exported preset to a path the user picks (the app shows the file dialog); Show in folder needs the preset's file location or a "reveal" call; Copy share string needs a defined format. The app does no file or Explorer access of its own (AGENTS.md) |

## Open items

Waiting on platform (see Needs): live results for edits (B2); click-to-field, lit tokens
and "set in Extra arguments" (token fields); audio conversion pips (signal facts); the
size range for a typed length; keyframes in frames; the recommended quality band (B1
profiles); remembered window size and length (app UI state); favorites on built-ins;
Test this preset; Export…, Show in folder, Copy share string.

App side, later milestones: Advanced mode and Ctrl+M (F4); the popup's collapsible
command strip (F5).

## Handoff for the next app agent

Start from `ws/app`. Read AGENTS.md, WORKSTREAMS.md, CONTRACTS.md, this file and
UI_SPEC first. Next is **F3: FFmpeg, History and Settings** on the service fakes
(`FakeFFmpegDiscovery`, `FakeFFmpegProbe`, `FakeHardwareTests`, `FakeJobRepository`,
`FakeMachineSettingsRepository`); add their providers next to the ones in
`state/services.dart`.

- Mapping from core and service results is display work in `features/*/display.dart`
  style files; never derive domain facts. Where a fact is missing, show less and add a
  request above.
- `CoreResult` (`state/editor.dart`) keeps a core failure explicit; the editor says
  what's missing instead of showing an old result.
- Before each commit: `flutter analyze`, `flutter test`; regenerate goldens only for
  intended visual changes and look at them. Window or runner changes: rebuild release
  and run `tool/spikes/run_window_spikes.ps1`.
