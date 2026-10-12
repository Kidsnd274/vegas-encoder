# App workstream

Updated: 2026-10-12 (Asia/Singapore). Branch `ws/app`. Status: **F0 and F1 done**; B0
reviewed (below). F2–F6 continue on a branch that contains both F0/F1 and B0.

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

## Owner decisions (2026-10-12)

- **Renderer: deferred.** Impeller is Flutter's direction; decide later, since it
  changes nothing in current work. The runner still defaults to Skia because of the
  start time above; `RendererFromEnvironment` in `windows/runner/main.cpp` is the one
  place to change, and `VEGAS_ENCODER_RENDERER=impeller` tries Impeller meanwhile.
  Re-measure on each Flutter upgrade and with VEGAS running.
- **Flutter 3.47.7** at `L:\flutter` is intended (newest). ROADMAP and WORKSTREAMS
  now say so (applied with the owner's approval).
- **Light tokens accepted as the mockup has them**, including the contrast figures in
  UI_SPEC §9.
- **Keep on top off by default**, matching C7 `keepOnTop=false`. The pin is remembered
  in C7; mockup S6 just shows the pinned state. `main.dart` now starts the progress
  window unpinned; F6 reads the remembered value.
- **Fake core limits: go to the real core.** Platform adds the four contract requests
  below, keeps B1 short and builds B2 next; no fixture sweep of edited states. App
  builds F2 with injected fixtures and F3 on the service fakes meanwhile.

## B0 review, app side

Reviewed `docs/product/CONTRACTS.md` (platform B0, branch `ws/platform` at 5fa0a20)
against what the components need. No breaking change is needed; the gaps below are
additive requests.

| Need | B0 | Gap |
| --- | --- | --- |
| Popup owner before first frame | C4 `request.json` has `ownerHwnd` (decimal string); `EditSessionService.readRequest` | None. The provisional `--owner` argument stays for the spike harness only |
| Crash recovery | Adapter task, gated on real-host evidence | Pass on the spike finding: after an editor crash the page should re-enable the owner and bring it forward |
| Progress window placement | C5 has no host window | **Request:** VEGAS's main HWND in the launch arguments or live file |
| Command view | `CompileResult.display` tokens with role; `commandLine` for copy | **Request:** the recipe field per token (click-to-field, lit tokens), and which tokens an error issue points at |
| Signal path | `ResolvedSettings` (depth, pixfmt), media, profiles, compatibility, issues | **Request:** per-stream facts the app must not derive: audio output sample format and bits, chroma change, conversion yes/no, and "container can't hold this stream" as data rather than message text |
| Size and quality | `estimate(…, durationSec)`: per-minute, total, min/max per minute, approx | None. F2 changes `SizeQualityCard` to show these figures instead of multiplying kb/s by the length itself |
| Quality control | `NumericControl` with direction and marks | Recommended band per resolution (B1 profiles), optional |
| Encoder picker | `videoOrder` groups, `EncoderProfile.hw/depths`, installation availability | None |
| Settings | C7 `theme` (system/light/dark), `progressWindow`, `keepOnTop` | **Request:** a place for app UI state (desktop window bounds, last length in the size card). Keep on top: off by default, as C7 has it (owner decision above) |

**Main constraint for F2:** `FakeVeCore` only answers its fixtures (the six built-ins
and the popup snapshot). Any edit (CRF 18 to 17, another encoder) throws
`B0-FIXTURE-MISSING` until the native core (B2). F2 can build the Presets screen and
the Basic editor and test edited states with injected fixtures, but the running app's
editor won't update live until B2. Options: platform does B2 next, and/or adds a
fixture sweep of common edits for the built-ins.

## Handoff for the next app agent

Start from the merged branch that contains both F0/F1 (this branch) and B0. Read
AGENTS.md, WORKSTREAMS.md, CONTRACTS.md, this file and UI_SPEC first.

1. Add path dependencies in `app/pubspec.yaml`: `ve_core: {path: ../packages/ve_core}`
   and `ve_services: {path: ../packages/ve_services}`. Both are pure Dart with no
   third-party dependencies; SDK `>=3.10`.
2. Add providers in `app/lib/state/` for `VeCore` and each C3 service, defaulting to
   the fakes until B2/B3; tests override them. Keep `windowControllerProvider`.
3. Map core results to the existing display models (don't change the components'
   inputs without updating goldens): `CompileResult.display` to `CommandDisplay`,
   `ResolvedSettings` plus media to `SignalPathModel`, `SizeEstimate` to the size card,
   `NumericControl` to `VeQualityScale`, `videoOrder` plus availability to
   `VeEncoderGroup`. Mapping is display work; never derive domain facts (no pixel-format
   parsing, no compatibility rules, no estimate maths).
4. Back `themePreferenceProvider` with C7 `theme` (`system` = Follow Windows).
5. Handle `CoreException` (`B0-FIXTURE-MISSING`) in the editor with a clear message
   until B2.
6. `features/gallery/` and `samples.dart` are the F1 reference. Keep them as the
   design-system page (or under a debug flag) once Presets replaces it; the goldens use
   them.
7. Before each commit: `flutter analyze`, `flutter test`; regenerate goldens only for
   intended visual changes and look at them. Window or runner changes: rebuild release
   and run `tool/spikes/run_window_spikes.ps1`.
8. Open items carried over: diagram size from the text scale (UI_SPEC §9), Ctrl+Shift+C,
   the command's single-line toggle, window size and position memory (needs the
   settings request above).
