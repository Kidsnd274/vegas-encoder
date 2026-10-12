# App workstream

Updated: 2026-10-12 (Asia/Singapore). Branch `ws/app`. Status: **F0 and F1 done**; F2–F6
wait for platform milestone B0 merged into this branch.

Nothing here ran inside VEGAS. Window behaviour was checked against a fake host (a
WinForms window standing in for VEGAS); components were checked with widget and golden
tests using local sample data.

## Done

**F0: project, runner, modes, theme, fonts, spikes.**

- `app/` is a Windows-only Flutter app (`VegasEncoder.exe`) on Flutter 3.47.7 / Dart
  3.13.5 from `L:\flutter`, with Riverpod 3.4.3. Runtime dependencies are Riverpod and
  its transitive packages (MIT/BSD).
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
- Theme follows Windows live; Settings choice (Follow Windows / Light / Dark) is in
  memory until machine settings exist. Windows "Animation effects" off zeroes motion.
- Instrument Sans and JetBrains Mono bundled with their OFL texts and provenance
  (`app/assets/fonts/README.md`).

**F1: design system** (`app/lib/design/`), from `design/signal-flow.html`:

- Tokens: every `:root` colour, light and dark, on a `ThemeExtension`; type scale,
  spacing, radii, shadows, motion (UI_SPEC §10).
- Components: buttons, icon buttons, link, key caps, text and number fields, segmented
  control, switch, slider, quality control, select, encoder picker with availability,
  popover listbox, status tags, messages and check list, field with read-out, title
  bar, signal path (full and strip, `CustomPainter` wires, pips, ports, marks, keyboard
  navigation, animated wire widths), size and quality card, command view (role colours,
  inputs chip, group tint, lit tokens, click-to-field, copy), the app mark and wire glyph.
- A design-system gallery is the desktop Presets page until F2.

## Tests

`flutter test` in `app/`: 152 tests, all passing. `flutter analyze`: no issues.

- Unit: launch parsing, display formatting, tokens (mockup values, lerp) and contrast
  in both themes, icon path parsing.
- Widget: controls (activation, keyboard, semantics), signal path (selection, arrow
  keys, audio off, mux problem, Advanced, strip, spoken names, reduced motion), size
  card, command view (chip, token clicks, copy), app (live theme, Settings override,
  reduced motion, title bar, Ctrl+1–4, drag and double-click, popup and progress shells).
- Golden: 17 views × light and dark = 34 images in `app/test/golden/goldens/`. Real
  fonts are loaded in `test/flutter_test_config.dart`. Regenerate with
  `flutter test --update-goldens test/golden`.

## Spike results (F0)

Release build, Windows 11 Pro 26300, 125% scaling, three monitors, fake host. Run with
`app/tool/spikes/run_window_spikes.ps1` (report and screenshots go to the ignored
`app/build/spikes/results/`).

| Spike | Result |
| --- | --- |
| Start time | Process creation to window shown, warm, median of 10: **popup 341 ms**, desktop 455 ms (the desktop draws the full gallery) with Skia. With Impeller: popup 1,287 ms, desktop 1,338 ms; about 1 s of it is engine start-up before Dart runs. A true cold start (empty file cache) was not measured. Budget: popup ≤ 1.0 s cold, ≤ 0.7 s warm |
| Renderer | Flutter 3.47.7 defaults to Impeller on Windows, OpenGL ES with SDF text (`Using the Impeller rendering backend (OpenGLESSDF)`). The runner now defaults to **Skia** for start time; `VEGAS_ENCODER_RENDERER=impeller` opts in. Text side by side at 1:1 looked the same. Not checked with VEGAS holding the GPU |
| Owner window | Owner set before first show (`GWLP_HWNDPARENT`), centred on the owner within 4 px, foreground on show, hidden and restored with the owner, owner re-enabled and foreground again after Close. After a kill (crash) the owner did not get the foreground back by itself, but its process could take it with `SetForegroundWindow` after re-enabling |
| Live theme | Flipping `AppsUseLightTheme` switched the running app in about 0.1 s and back again; the engine watches the registry key itself |
| No-activate window | Progress window shown and clicked while the fake VEGAS stayed foreground; `WS_EX_NOACTIVATE` and topmost set; 20 px (16 logical) from the work-area corner |
| Single instance | A second desktop launch exits with code 0; the first stays and closes cleanly |

Not done in F0: console flash from `Process.start` and folder watching (both belong to
`ve_services`, B3), the live check of reduced motion against the Windows setting (the
runner path is wired; the app path is tested with a fake), window size and position
memory (needs machine settings).

## Next

F2 Presets screen and Basic editor, then F3, against the B0 fakes once B0 is merged.
Also: size the diagram from the text scale (UI_SPEC §9 gap), Ctrl+Shift+C, and the
command's single-line toggle.

## Needs from platform

1. **C4 edit session: the owner HWND before the first frame.** The window must be owned
   before it shows. The app calls `configure(ownerHwnd)` before `runApp`, so the
   session API in `ve_services` must return the owner from `request.json` without
   waiting on anything slow. Proposal: also pass `--owner <decimal hwnd>` on the
   command line; the app already accepts it (provisional) and it saves reading the file
   first.
2. **C4: closing and crashes.** The editor re-enables its owner just before its window
   closes, so Windows returns activation to VEGAS. After an editor crash the page
   should re-enable the owner and call `SetForegroundWindow` on it (possible in the
   fake-host test).
3. **C5 progress window placement.** The window goes to the monitor of the foreground
   window at launch. Please pass VEGAS's main window (for example `--host-hwnd <hwnd>`
   or a field in the live file) so placement doesn't depend on focus.
4. **C2 display data.** The components take display models (see `lib/design/components`
   and `lib/features/gallery/samples.dart` for the shapes). From `VeCore` the app needs:
   - compile tokens with role (inputs, map, video, audio, mux, output), kind (flag,
     value, macro, locked), the recipe field that produced each token, extra/error
     marks, display quoting, and the copy text (multi-line with `^`);
   - signal-path facts per stream: input and output bit depth or sample bits, the pixel
     or sample formats either side of a conversion, chroma change, codec name,
     availability with reason, and whether the container can hold it;
   - a size estimate (`estimate` is not in the C2 list): video and audio kb/s, whether
     it is approximate, and the typical-range multipliers for quality modes. The app only
     multiplies by the typed length and formats;
   - quality scales from encoder profiles: unit, range, direction, labelled marks, and a
     recommended band per resolution where the profile has one;
   - encoders grouped by codec with hardware vendor, bit depths, availability and reason.
5. **C3/C7 settings the app keeps.** Theme choice (shared by the popup), desktop window
   size and position, the last length typed in the size card, progress window on/off
   and keep on top. Optionally a renderer override for support.

## Decisions for the owner

1. **Renderer.** Default to Skia (0.34 s to a shown popup) instead of Flutter's default
   Impeller (1.29 s)? Implemented as Skia with an Impeller opt-in; easy to flip back.
   Impeller is Flutter's direction, so this is worth re-measuring on each Flutter
   upgrade.
2. **Flutter version.** `L:\flutter` is 3.47.7, not 3.44.6 as README/ROADMAP/WORKSTREAMS
   say. Nothing was upgraded; the owner documents need the correction.
3. **Light-theme contrast.** The mockup's light `muted` on paper (4.39:1), `faintText`
   (3.4–3.7:1, placeholders and tick numbers) and control borders (1.6–1.7:1) miss
   UI_SPEC §9. Keep, or darken those three light tokens slightly?
4. **Progress window.** Keep on top defaults to on (as in S6). It has no taskbar button,
   which is the normal result of never activating.
5. **Fonts.** Bundled unsubset (about 570 KB); start time doesn't need subsetting now.
