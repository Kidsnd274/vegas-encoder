# App workstream

Updated: 2026-10-14 (Asia/Singapore). Branch `ws/app`. Status: **F0 and F1 done; F2
and F3 done except the parts waiting on platform** (listed under Needs). **The app runs
on the native core (B2)**: edits update the command, checks, signal path and estimate
(the core part of F7), and the desktop starts in ~540 ms (runner fix, 2026-10-14).
The services are still the platform fakes (B3). Master through F3 (`0be99dc`) is
merged. Next: F4, the Advanced editor.

Nothing here ran inside VEGAS. Window behaviour was checked against a fake host (a
WinForms window standing in for VEGAS); screens and components were checked with
widget and golden tests on the platform fakes, the native core and local sample data.
The native core's profile data is B0/Linux bootstrap, not Windows-qualified (B1).

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

**Native core (2026-10-14; the core part of F7):**

- `veCoreProvider` (`state/services.dart`) creates `NativeVeCore()`, one per isolate
  (one `ProviderScope`); ve_core's build hook bundles `ve_core.dll` beside
  `VegasEncoder.exe` (release build checked). If it can't load, the provider returns
  `UnavailableCore`, which throws the load `CoreException` from every call, and the
  desktop window shows "Vegas Encoder couldn’t load its core" with the code and message
  in place of every screen (`features/shell/core_unavailable.dart`). Nothing falls back
  to the fake.
- `CoreResult` keeps native failures explicit: the command column says "The core
  couldn’t build the command: <message>", the File node "The core couldn’t work out an
  estimate: <message>" or "…the total: <message>". The "needs the real core (B2)"
  notices remain for `B0-FIXTURE-MISSING` only, which only the fake (tests) returns.
- B2 fields mapped, with no parsing or arithmetic in the app:
  - `CompileResult.overriddenFields`: "Set in Extra arguments." under each replaced
    control, before its issues (`PanelScope.messages`), for video and audio alike.
  - `SizeEstimate.minTotalBytes`/`maxTotalBytes`: "About 53.7 MB per minute. Typically
    322 MB to 859 MB for 10:00." for the typed length (`SizeQualityCard`); the
    per-minute range stays when no length is typed. An unavailable estimate shows the
    core's explanation.
  - `ResolvedSettings.gopFrames`: the Keyframes read-out "**2 s** (60 frames at 29.97
    fps)", or "**120 frames** at 29.97 fps" when Extra arguments set `-g`
    (`keyframesReadout` in `features/presets/display.dart`). Keyframes now has its own
    row in the Video panel so the read-out fits; Color tags moved below it.
- Tests stay on explicit `FakeVeCore` overrides (`coreOverride` in `test/helpers.dart`,
  used by `pumpApp`/`pumpThemed`, and the unit tests' containers), so the F2/F3 goldens
  keep the fake's fixtures. The tests that need the native core pass `core:
  NativeVeCore()`.
- Desktop start: the runner replies to `configure` before restoring remembered bounds,
  which removed ~220 ms of engine waits (649 → 537 ms; see Spike results).
- Built with parallel agents: one wrote the native goldens and unit tests (the parent
  reviewed every image and fixed the layout bug it found in the new notice); one found
  the start-time cause and wrote the runner fix in its own worktree; a third verified
  that fix here.

## Tests

`flutter test` in `app/`: **348 tests, all passing** (319 after F3). `flutter analyze`:
no issues. Platform fakes (B0) for services everywhere; the fake core for the F0–F3
tests and the native core (B2, through `dart:ffi`, in the `flutter test` VM) for the
new core tests below; a fake window controller; for F3 two test doubles
(`test/ffmpeg_doubles.dart`: a probe and hardware tests that stall).

Native core additions (29):

- Widget, on `NativeVeCore` (`native_core_test.dart`, 9): the app's core is native and
  loaded; a CRF edit changes the command (`-crf 26`), the node's summary and the core's
  total; 8 to 10-bit changes `-pix_fmt`, the wire's output bits, and the checks (the
  core's `video.depth` issues show at Bit depth and in Checks); `-preset fast -g 120` in
  Extra arguments marks exactly Encoder speed and Keyframes, reads "120 frames at
  29.97 fps", and clearing Extra gives the controls back; `-b:a 192k` marks the audio
  Bitrate; 4 s of keyframes reads "4 s (120 frames at 29.97 fps)" and `-g 120`, no
  seconds emits no `-g` and no read-out; 25:00 gets the core's total range; `-vf` shows
  the core's no-estimate explanation; a recipe over the 1 MiB transport limit shows
  `JSON-LIMIT`'s message in the command and File node with no fake-core notice; an
  `UnavailableCore` shows the notice on every screen without an exception.
- Unit (`core_mapping_test.dart`, 11): `keyframesReadout` (seconds, overridden, no
  seconds, 1 frame, thousands, 25 fps, 0.5 s, null) and `CoreResult` (only
  `B0-FIXTURE-MISSING` is the fake's notice; `JSON-LIMIT`, `NATIVE-LOAD`,
  `ABI-MISMATCH` stay failures; other exceptions aren't swallowed).
- Widget: the size card's range for a typed length and back to per minute (1).
- Golden (`native_golden_test.dart`, 8 images): the Presets screen on the native core
  (video node, Extra arguments replacing speed and keyframes, File node with the total
  range) and the core-not-loaded window, light and dark. **These use the native core's
  bootstrap data: regenerate them when B1 changes profiles or wording.** Twelve F2
  images were regenerated for the Keyframes row and read-out (`presets_edited`,
  `bitrate`, `lgpl`, `narrow`, `text150`, `window_desktop`, both themes); each was
  looked at. 82 images in all.

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

**Native core recheck (2026-10-14).** Release build (35 s, `ve_core.dll` bundled beside
the exe), same machine and harness, `-Checks start`, fake host, nothing else running.

| Check | Result |
| --- | --- |
| Start, Skia, warm, 10 runs | desktop **649 ms** (Dart main to first frame 253 ms); popup **379 ms**. Impeller: 1,664 / 1,370 ms. Within noise of F3 (660 / 410 ms) |

**The F2 explanation above was wrong.** Removing the fake core changed nothing, so a
temporary Dart stopwatch (5 runs, reported through the startup trace, then removed)
timed each step from Dart main: settings read 0.5 ms; **`await window.configure(...)` in
`main.dart` returns after 217–250 ms**; window state 0.1 ms; native core load 1 ms;
profiles 1 ms; library and editor providers (six compiles) ~8 ms; first frame ~10 ms
later. The core costs about 10 ms in all. The desktop's extra time is the runner's
`configure` reply, which F2's window-bounds change introduced (F2's baseline had 33 ms
from Dart main to first frame); the popup's `configure` returns at once.

**Cause and fix (2026-10-14).** B0's settings fixture remembers desktop bounds at
(-1280, 80), 1200×800, which on this PC is a 100% monitor beside the 125% primary.
`RestoreBounds` moved, then sized the hidden window; each resize reached the Flutter view,
and the engine (`FlutterWindowsView::OnWindowSizeChanged`) blocked the platform thread up
to ~100 ms waiting for a frame of the new size. That frame couldn't come, since Dart
awaits the `configure` reply before `runApp`, so both waits timed out (113 ms and 212 ms
in a per-message trace). Any real remembered size that differs from the default costs one
wait; another-DPI monitor costs two. The runner now replies first, then restores
(`ClampBounds` / `RestoreBounds` in `win32_window.cpp`); a first frame that arrives while
the window is being placed waits for placement before Show. No Dart or channel change.

| Start, warm, median of 10 (125% primary + 100% left monitor) | Before | After |
| --- | --- | --- |
| Skia desktop shown (Dart main to first frame) | 649 ms (253) | **537 ms (32)** |
| Skia popup shown | 379 ms | 351 ms |
| Impeller desktop / popup shown | 1,664 / 1,370 ms | 1,413 / 1,297 ms |

- Owner window (3 runs): owner set, centred within 4 px, hidden and restored with the
  owner, re-enabled after Close; "owner foreground after Close" missed once in 3 (the
  popup doesn't use the changed code; likely focus noise, unproven). No-activate progress
  window: fake VEGAS stayed foreground, `WS_EX_NOACTIVATE`, not topmost, 20 px from the
  corner. `flutter test` 348 passing; release build without C++ warnings (`/W4 /WX`).
- A scratch probe (outside the repo) recorded the window's rect and visibility and
  captured the screen after show: the window is placed while hidden, appears only at its
  final rect and never moves (7 Skia, 3 Impeller runs); no stretched frame on restore.
  The old build showed a white window for 33–150 ms on Skia; the fix shortens it.
- A same-DPI remembered size (temporary override, reverted) takes one wait, which now
  runs while Dart starts; shown in place.
- The monitor layout changed during these checks (the 125% monitor went away), so the
  fixture's bounds now miss every monitor and later desktop runs take the bounds-ignored
  path (default placement, `boundsSet: false`).
- Still about 150 ms between desktop and popup: the desktop's first frame reaches the
  screen 90 or 205 ms after Dart draws it (popup ~42 ms), with or without a restore.
  Cause not established.

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

Delivered in B2 (merged `bbcbe91`) and **used since 2026-10-14**: `NativeVeCore` with
its bundled DLL (the app's core); `CompileResult.overriddenFields` for "Set in Extra
arguments."; `SizeEstimate.minTotalBytes`/`maxTotalBytes` for the typed length's range;
`ResolvedSettings.gopFrames` for "2 s (60 frames at 29.97 fps)"; FakeVeCore treating
`{}` and absent `extensions` alike (the tests still use it). No new core request came up.
When B1 replaces the bootstrap profiles, the app needs nothing new, but the native
goldens (`native_golden_test.dart`) will need regenerating and a look.

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

App side: Advanced mode and Ctrl+M (F4); the popup's collapsible command strip (F5).
The Open dialog (`pickFile`) is built and covered with a fake controller; it was not
clicked through in the running app. Small display points seen on the native core:

- The size card can wrap between a figure and its unit ("…to 859 / MB for 10:00.");
  a non-breaking space in `VeFormat.bytes` would fix it (tests match its strings).
- The command view's wrapped lines have no hanging indent, and an option can wrap away
  from its value (`-profile:v` | `high`). F1 component behaviour, more visible now that
  the core's lines are longer.
- A control replaced by Extra arguments keeps showing its own value with the note
  (UI_SPEC §2 as written). If that reads as contradictory in use, dimming the control is
  a later design choice.
- The native core loads at the first build of the desktop shell; a load failure is
  shown, not retried (it is permanent for the process).

Window start (runner), unverified or not fixed:

- **Popup over a VEGAS window on another-DPI monitor** (F5): `PlaceOnOwner` likely pays
  the same ~100 ms engine wait before its `configure` reply, and centres with the size
  from before the DPI change, so it could land off-centre. Split it like
  `ClampBounds`/`RestoreBounds`, reuse the deferred show, re-centre after the change.
- **Restoring maximized** shows a stretched first frame for ~20–40 ms (the restored-size
  frame scaled up). Present before the fix too. Sizing the hidden window to the maximized
  client size before the first frame may avoid it (untested).
- The remaining ~150 ms desktop-only first-frame delay (Spike results); cold start.

## Handoff for the next app agent

Start from `ws/app`. Read AGENTS.md, WORKSTREAMS.md, CONTRACTS.md, this file and
UI_SPEC first. F3 is done; the app runs on the native core (B2) with fake services.
Next: **F4, the Advanced editor** (UI_SPEC §3): highlighting from the core's tokens, lint
display (`VeCore.lint`, UTF-16 ranges), locked `{inputs}`/`{output}` chips, macros, the
resolved command, then autocomplete last (`VeCore.complete`). The native core answers
any text, so F4 can be built and tested on `NativeVeCore` directly; keep goldens on the
fake or on the native core knowing B1 will move the latter.

- Tests default to the fake core: `pumpApp`/`pumpThemed` take `core:`; pass
  `NativeVeCore()` (one per test file, `setUpAll`) for live results. `native_core_test.dart`
  shows the pattern, including reading `editorProvider` through
  `ProviderScope.containerOf`.
- Core failures: `UnavailableCore` (load) and `CoreResult` (per call) keep them explicit;
  `notInPreviewCore` is the fake's `B0-FIXTURE-MISSING` only.

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
