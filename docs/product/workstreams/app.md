# App implementation history

**Superseded workflow, 2026-10-16:** the owner consolidated app and platform into
one agent in `L:\repos\vegas-encoder` on `master`. This file
retains app implementation/spike history and decisions, not an active workstream
queue. Follow [workflow](../WORKSTREAMS.md), [STATUS](../../STATUS.md) and the one
current [NEXT_AGENT](../../NEXT_AGENT.md) queue. Old ownership boundaries and
instructions to continue on `ws/app` no longer apply.

**Owner-directed monitor follow-up, 2026-10-16 (in `ws/platform`):** the owner
explicitly requested clearer error display and no automatic close on failure.
The bottom-right monitor now gives the authoritative C5/C6 cause a prominent
error panel, with long-message scrolling from the beginning, a visible stay-open
label and explicit Close. Trailing stderr warnings no longer replace the cause;
Show log retains access to the full log. Failure display no longer waits for C6,
and a failure cancels a previously started close countdown. This narrow frontend
change follows the owner's request; it does not change general workstream
ownership. Focused widget/unit/light+dark golden checks pass (50); updated normal
and long-error images in both themes were visually inspected. Release staging and
full app checks are recorded in the platform handoff. Real-host screenshot now
confirms the prior native fix reaches VEGAS's error dialog; same-session
post-error recovery and the new frontend's real-host retest remain open.

Owner subsequently installed the error-ui variant and approved its appearance
("looks good"); the real VEGAS screenshot shows the cause panel, stay-open label
and Close action. Platform verified the installed trial and new failed C6 record.
Presentation is accepted; timed/manual-dismissal behavior and successful
same-session post-error recovery are not inferred from that screenshot.
The owner subsequently chose to skip the extra same-session recovery render
and proceed on the working assumption; that check is owner-deferred/unverified,
not a pass or an active request. Payload and monitor checks are next.

Updated: 2026-10-15 (Asia/Singapore). Branch `ws/app`. Status: **F0, F1, F4, F5 and F6
done; F2 and F3 done except the parts waiting on platform** (listed under Needs). **The
app runs on the native core (B2) and the platform's Windows services (B3)** (F7's
service part, `0d33d43`), with the §9.3 budgets measured on real data (Tests). Master
through `1e14d64` (B1, B3, B4, B5 and the offline B6 preparation) is merged, with no C2, C4 or C5
change; the native core carries B1's Windows FFmpeg
data and its goldens are regenerated (`4829f8e`). **F5, the VEGAS popup, is built** (`fe248b5`)
(`--edit-session`, UI_SPEC §4, S3): the C4 request and result through
`EditSessionService`, the template header and origin line, the one-row strip, Load preset,
Show changes, Update from library, Save to library, Apply and Cancel, and Advanced mode
in a compact layout. **F6, the render progress window, is built** (`--render-monitor`,
UI_SPEC §12, S6): the C5 live file, placement on VEGAS's monitor from `hostHwnd`, the
remembered pin, the figures, and the done, failed and cancelled states from the C6
record. **The F2/F3 follow-ups platform unblocked are built** (2026-10-15, uncommitted for
review): installation health, History from the index with the full log, error tokens and
Open folder, Test this preset, Export…/share strings/Show in folder, and the small display
fixes. Next: what Needs and Open items list.

Nothing here ran inside VEGAS. Window behaviour was checked against a fake host (a
WinForms window standing in for VEGAS); screens and components were checked with
widget and golden tests on the platform fakes and the native core; the Windows services
with unit tests on temporary folders. No FFmpeg ran for this work. The popup's sessions
in tests come from the platform's `FakeEditSessionService`; no VEGAS page wrote a
request, and A5–A7 (page exchange, template persistence) are not claimed. The progress
window read hand-written live files, never one the exporter wrote; its performance
check in VEGAS (TECH_ARCHITECTURE §5.6) is B6 work.
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
- Header: name with Edited, Built-in/Mine, category, revision; Basic/Advanced (working
  since F4); the FFmpeg the checks are for; Duplicate, Revert (with Undo),
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

**F4: Advanced mode** (UI_SPEC §3; `lib/design/components/command_editor.dart`,
`lib/features/advanced/`, `state/editor.dart`, `state/presets.dart`, `presets_page.dart`):

- **Switching** (SETTINGS_AND_COMMANDS §5): Basic | Advanced and Ctrl+M. The first switch
  starts the command from the core's `advancedTemplate`; with a command saved, the seed
  question ("Use your saved command", the default; "Replace it with the current
  settings"; Cancel). Both settings stay in the recipe (`command.mode`,
  `command.template`). Back in Basic, a quiet banner says the command is kept and offers
  Switch to Advanced. `PresetsController.setMode`/`setTemplate`; `EditorData` gains
  `advanced`, `lint`, `basic` (the recipe compiled as Basic) and `capabilities`.
- **`CommandEditor`** (design component): `EditableText` with
  `TextSelectionGestureDetectorBuilder` (selection, context menu), `buildTextSpan`
  highlighting from a display model (`CommandEditorModel`: words, chips, marks), a gutter
  with line numbers, per-line stripes and the most severe message after each line, lock
  badges and chip backgrounds painted from the laid-out text (padding of the platform's
  `BoxWidthStyle.max` selection boxes trimmed, `glyphRects`), hover bubbles, and a chip
  guard (`TextInputFormatter`) that refuses partial edits and selects the chip; the
  controller keeps the caret out of chips. Autocomplete overlay with keyboard (arrows,
  Tab/Enter, Esc, Ctrl+Space) seen before the text-editing shortcuts.
- **Mapping** (`features/advanced/display.dart`), from the core only: chips from the
  compile's `input`/`output` token spans; words from token `sourceStart`/`sourceEnd` (option
  names bold by the command view's display rule; stage and macro roles honoured when the
  core gives them); marks from `VeCore.lint` plus compile issues on the text lint doesn't
  repeat (such as `L-GOP`), whole-command ranges listed but not underlined; diagnostics
  with lines and Go to; the resolved command grouped by the user's lines; the macro list
  from `VeCore.complete` after "{" with values from a compile of the names alone (stub
  until platform supplies macros, Needs); suggestions from `VeCore.complete`, opened by
  the spec's rule (after "-", after an option with values, after "{"; Ctrl+Space always).
- **Elsewhere:** the signal path in Advanced mode uses only the core's facts and summary
  for the active command (`_commandSignalPath`): unknown output formats claim no
  conversion, no wire label and no availability (`SignalStream.availability` is now
  nullable); "From file name" when no `-f`. Nodes focus the editor. No estimate. The
  library's Advanced tag leads the summary line and follows the draft ("x264, your
  command"); the depth glyph uses the core's signal facts. Copy (Ctrl+Shift+C) copies the
  core's command line. Dialog actions wrap when they don't fit (the seed question).
- Context7 (via the `.unsloth` Node runtime; Node isn't on PATH) returned little for
  `EditableText`/`RenderEditable`; the APIs were checked against the Flutter 3.47.7 SDK
  source in `L:\flutter`.

**F7, services part: the app on the Windows services (B3)** (2026-10-14;
`state/services.dart`, `main.dart`, `state/presets.dart`, `state/ffmpeg.dart`,
`state/editor.dart`, `features/presets/library_model.dart`):

- **One composition.** `servicesProvider` builds `WindowsAppServices`, the platform's
  `WindowsServices(core:, paths:)`, on first use (the progress window never loads the core
  or the library). Every service provider (library, machine settings, discovery, probe,
  hardware tests, capability cache, jobs, live status, edit sessions) derives from it;
  `presetPreferencesProvider` and `presetTransferProvider` derive from the library.
  `main` makes one `ProviderContainer` before `runApp` (`UncontrolledProviderScope`), so
  the remembered desktop bounds come from the same machine settings the app then uses.
- **Tests never reach real data.** Under `flutter test` the real services refuse to build
  (`FLUTTER_TEST`); `servicesOverride()`/`FakeAppServices` in `test/helpers.dart` give
  every test the platform fakes (`pumpApp`, `pumpThemed`, `testContainer`).
  `VEGAS_ENCODER_DATA_ROOT=<folder>` moves the data to `<folder>\Roaming` and `\Local`
  for development and spike runs; the exporter doesn't read it.
- **Duplicate persistence removed** (CONTRACTS C3 "C7 ownership"): the app no longer
  copies discovery's list into C7 or writes probe results to the cache; Set as default
  writes only `defaultFFmpegId`. Probes and hardware tests invalidate the editor's
  capabilities, which re-read the cache.
- **Capability views.** `capabilitiesProvider` returns the cached `FFmpegCapabilities`
  (selected by the installation's identity key, so unrelated settings writes don't
  re-read a 200–330 KB cache file); the editor and library pass the recipe's reusable view
  (`toCoreCapabilities(recipe:)`, ~43K characters instead of ~236K). Only the desktop probes
  an uncached installation; the popup reads the cache only.
- **Budgets** (measured below): an edit compiles once, shared by the editor and the
  edited preset's library row (`compileSample`, keyed by the recipe object); other rows
  are reused (`_LibraryRowCache`); one `Recipe` object per preset (`presetRecipe`,
  `presetId`) since `Preset.recipe` deep-copies; size estimates are worked out when the
  File node reads them; `LibraryEntry` works out its search text once.
- **Library writes** (`PresetsController`): stars on built-ins persist through
  `PresetPreferences` (the session-only built-in stars are gone); copies carry C3 origins
  (`builtin/<id>`, `preset/<id>@<revision>` with the revision the edit started from; a
  copy starts unstarred); History's "Open settings as new preset" uses
  `PresetTransfer.fromJob` (origin `job/<id>`). After each write the controller re-reads
  the library before changing selection or drafts: the file library polls every 250 ms,
  and without this a new copy's selection fell back to the first preset and a saved draft
  showed the old recipe for a moment (found by the file-based tests). A refused write
  (`RECIPE-INVALID`, `STORE-BUSY`, `FILE-WRITE`…) shows "Couldn’t save the preset: <the
  library's reason>" and keeps the draft; closing with unsaved changes that can't be saved
  says so and stays open.
- **History**: the recorded `commandLine` and `realtime` (B4) replace the app's own
  quoting and division; older records keep the fallback.
- Settings > About names the data folders ("This PC. Settings and presets are in …").

**F5: the VEGAS popup** (2026-10-15; UI_SPEC §4, S3 in `design/signal-flow.html`;
`state/popup.dart`, `features/popup/`, `main.dart`, `windows/runner/`):

- **Launch.** `--edit-session <dir>`: `main` reads the C4 request through
  `EditSessionService` (`editSessionRequestProvider`, the same container the app then
  uses) before `configure`, and takes the owner from the request's `ownerHwnd`
  (`ownerHwndOf`; the provisional `--owner` argument is gone). A missing or invalid request
  leaves the window unowned and the popup says "Vegas Encoder couldn’t open this template:
  <reason>. Closing this window leaves the template as it was."; closing writes nothing
  (C4: no result means cancel). The session file is read once, with no retries (Riverpod's
  default retry would hold the popup in loading). A core that didn't load makes the real
  session service refuse (`CORE-CONTRACT`), shown the same way.
- **Header.** The template name, then the origin line with the preset's name in bold and
  "Rename in VEGAS to change the saved template name." (`originLine`,
  `features/popup/display.dart`): "From preset X, revision 5." (unchanged); "From X,
  revision 5. 2 changes in this template (Show changes)." (the count is the core's diff from
  the origin revision); the library's newer revision in the side column with Update from
  library; "Preset X no longer exists in your library. This template still has all its
  settings."; "Made in VEGAS."; and "From X, revision 5. The library couldn’t be read:
  <reason>." Load preset, Save to library ▾ and Basic | Advanced on the right.
- **Strip.** `SignalPathLayout.strip` with origin marks from C2 `diff`
  (`originMarks`): a dot on nodes this template changed, "Rev. 6" on nodes the library
  changed since the template's revision. From VEGAS shows the project's facts from the
  request ("3840×2160 / 29.97 fps, 10-bit / 48 kHz float"). When VEGAS didn't share them
  (`context.media` null) the node reads "Set by project" (the strip's short title;
  `SignalSource.stripTitle`), "Sample: 29.97 fps", "Sample: 48 kHz float"; the From VEGAS
  panel says "Set by the project" for each fact and that the command and checks use a
  sample (`PreviewMedia.projectUnknown`). The preview compiles with the project's media
  when known, else the documented sample.
- **Editing.** The node panels and the command column are the desktop's, on
  `popupEditorProvider` (a fresh compile of the template, the default FFmpeg's cached
  capabilities only: the popup never probes). The panels hide the fields' explanations
  (S3). Reset goes back to the template as it opened. The File node's length starts at the
  project's length from the request and is never written to C7's remembered length.
- **Load preset.** A list of the library's presets (Built-in, then Mine), read once each
  time it opens (`popupLibraryListProvider`, not a watch), each with its recipe-based
  line ("x264, AAC", or "Needs …: not in this FFmpeg"; no compile per row). Choosing one
  replaces the settings at once, keeps the template's name and makes the preset the
  origin; the Undo bar ("Loaded “X”. Undo") lasts 8 seconds.
- **Show changes / Update from library** (`popup_dialogs.dart`), both from C2 `diff`
  with settings named as the controls name them (`fieldLabel`, `fieldValue`: "CRF 17",
  "320 kb/s", "x264"). Update from library lists "Changes in the library since revision
  5" (Rev. 5 | Rev. 6) and "Your changes in this template" (Rev. 5 | This template);
  "Take library changes, keep mine" is enabled only when no setting is in both lists
  (otherwise disabled, "Some settings changed in both places.") and takes the library's
  value for each of its paths with the existing `resetField`; "Replace with revision 6"
  takes the library's settings and keeps the template's name. Both have Undo. Without a
  `baseRecipe` there is no three-way offer: the dialog lists "This template and revision
  6" and offers only Replace, and the origin line gives no change count.
- **Save to library ▾.** "Save as new preset…" asks for a name (the template's name;
  made unique), saves to Mine with origin `builtin/<id>` or `preset/<id>@<revision>` and
  makes the new preset the origin. "Update “X” (revision 5 → 7)" saves the template's
  settings to the origin at the library's next revision (the preset keeps its own name);
  disabled for built-ins ("Built-in presets can’t be changed.") and without an origin in
  the library. A revision conflict re-reads the library and says so.
- **Open in Vegas Encoder** (side column) waits for a platform service: no C3 service
  starts the desktop app, so `desktopAppLauncherProvider` is null and the button is
  disabled with that reason (Needs). Tests supply a launcher to check the action.
- **Footer and closing.** "Apply updates this render template. Save it in VEGAS to keep it
  for next time." Cancel (Esc), the title bar's close (labelled Cancel), Alt+F4 and the
  taskbar ask "Discard changes to this template?" (Keep editing / Discard changes) only
  when the settings or the origin changed. Apply to template (Ctrl+Enter) is disabled
  while the core finds errors (Basic checks, Advanced lint) or couldn't compile, and the
  footer shows why ("Fix the errors first. The template can’t render with them."). Apply
  writes `{action: apply, recipe, origin}`, Cancel `{action: cancel}`, once per session
  (`PopupState.finished`); then the window closes and a second close request exits at
  once. A result the service refuses (for example `RECIPE-INVALID`) is shown and the popup
  stays open; a cancel that can't be written still closes.
- **Advanced mode** (Ctrl+M or the switch, with the same seed question as the desktop):
  `AdvancedWorkspace(compact: true)`: the editor, Diagnostics and the resolved command
  (closed) under the strip, no desktop side column; the popup's side column keeps the
  library and says "N diagnostics. Edit it below the diagram."
- **Narrow popup.** Below 1040 px (the minimum is 960) the side column docks at the bottom
  as a collapsible "Library and command" strip, collapsed, with a summary such as "Library
  has revision 6. No errors." (UI_SPEC §1).
- **Shared editor pieces** generalised for the popup: `RecipeEditor` (what the panels
  edit; `PresetsController` and `PopupController` implement it); `EditorData.saved`,
  `.paths` and `.preview`; `PanelScope` on `RecipeEditor`; `AdvancedWorkspace`
  `onTemplateChanged` and `compact`; `CommandColumn` `width` and `leading`;
  `NodePanelHeader` moved to `panel_kit.dart`; the seed question as `askAdvancedStart`
  (`features/advanced/mode_switch.dart`). Design system: `VeDialogAction` `enabled` and
  `tooltip`, `showVeDialog` `width`, `VeBlurbs` (hides field explanations),
  `SignalPathModel.withMarks`, `SignalSource.stripTitle`.
- **Runner: placement over the owner** (`win32_window.cpp`, `flutter_window.cpp`).
  `OwnerBounds` sets the owner and works out the window's rect from the owner's monitor:
  its DPI, the default size scaled as `Create` scales it, centred on the owner and kept in
  the work area as `ClampBounds` keeps the desktop window. `configure` replies first and
  then places the window (`RestoreBounds`), with the deferred show, so a VEGAS window on a
  monitor with another DPI no longer centres with the primary monitor's size or blocks the
  reply. Measured in the F5 recheck (Spike results): a fake host on a 96-dpi monitor
  beside the 120-dpi primary gets the popup centred within 4 px at 1120×740 for 96 dpi.
- **Spike harness** (`tool/spikes/WindowProbe.cs`, `run_window_spikes.ps1`): each popup
  launch gets its own session folder with the C4 fixture request (owner set to the fake
  host); the owner check confirms WM_CLOSE leaves a cancel `result.json` and a killed
  editor leaves none; a new check places the fake host on a monitor with another DPI
  when there is one; runs use `VEGAS_ENCODER_DATA_ROOT` on `app\build\spikes\data-root`
  and report whether the user's own folders stayed untouched.

**Saving with errors (owner decision, 2026-10-15)** (`features/presets/save_check.dart`,
`presets_page.dart`, `shell/desktop_shell.dart`, `popup/popup_window.dart`):
`saveErrors` splits the core's errors into the settings' own (`VeCore.validate`, no
FFmpeg) and those only for the chosen FFmpeg (the compile's issues); `checkSave` warns
before Save, Duplicate, "Save all" on closing and the popup's Save to library. Settings
errors stop the save ("Fix the errors before saving", Show setting / Keep editing);
FFmpeg-only errors offer Save anyway. A core that can't check (the fake core in tests)
leaves the decision to the library, whose refusal still shows its reason.

**F6: the render progress window** (2026-10-15; UI_SPEC §12, S6; `state/monitor.dart`,
`features/monitor/`, `design/components/wire_progress.dart`, `main.dart`,
`windows/runner/`):

- **Reading.** `liveRenderStatusProvider` watches the C5 file through
  `LiveRenderStatusReader` (null until it appears; the reader keeps the last good
  snapshot, so a stale or malformed file never reads as an end). Once the status is done,
  failed or cancelled, `monitorJobRecordProvider` reads the C6 record (up to 8 tries,
  250 ms apart; the engine writes it right after the final status) and
  `monitorLogProvider` the log's location. Decoding a record loads the core; nothing
  else does. `WindowsAppServices.machineSettings` is now a `FileMachineSettingsRepository`
  of its own (same file, lock and revision rule), so reading keep on top no longer builds
  `WindowsServices` and the core. Measured on the release build (Spike results):
  `ve_core.dll` not loaded while encoding, loaded after done.
- **Placement.** Before the first frame `monitorPlacement` reads `hostHwnd` from the live
  file (`hostHwndOf`: C5's unsigned 64-bit decimal as the runner's signed 64 bits) and
  C7 `keepOnTop`; `configure` takes `hostHwnd`. The runner's `HostBounds` puts the
  window 16 px in from the bottom-right of the work area of that window's monitor, at its
  DPI, after the reply (as the popup's owner placement); no owner is set. A handle that
  isn't a top-level window keeps `Create`'s placement (the foreground window's monitor).
  The window is 380×340 (`launch_options.cpp`).
- **Window.** Title and headline per state, header (file name; encoder summary, then the
  folder), `VeWireProgress` (video wire, green when done, dashed red when failed, grey
  when cancelled), the six figures with dashes for unknown ones, and the footer.
  Mapping in `features/monitor/display.dart`; the done and failed sentences reuse
  History's `resultSentence`. Done closes after 10 s and cancelled after 5 s, paused while
  the pointer is over the window. Failed stays open with FFmpeg's last lines (a
  three-line box scrolled to the end), Show in History (disabled until a launcher exists:
  `DesktopAppLauncher.openJob`, Needs) and Show log (`JobLogs.logLocation` →
  `FileReveal`). Thirty seconds without a new status while starting or encoding puts
  "No news from the render…" in the footer and nothing else. The pin calls
  `setKeepOnTop` and writes C7 through `machineSettingsWriterProvider`.
- **Services.** `AppServices` gains `jobLogs` and `fileReveal` (`jobLogsProvider`,
  `fileRevealProvider`); the test fakes are `FakeJobRepository` and `FakeFileReveal`.
- **Spike harness.** The monitor check now writes a C5 live file naming the fake host, checks
  the corner placement at the monitor's DPI, starts again with `keepOnTop` true in the
  data root's `machine.json`, and adds a run with VEGAS on another monitor while another
  window is in front, plus a stale handle.

**F2/F3 follow-ups on the B3/B4 services** (2026-10-15; `features/ffmpeg/`, `features/history/`,
`state/history.dart`, `features/presets/`, `state/preset_test.dart`, `state/services.dart`,
`design/format.dart`, `design/components/command_view.dart`, `command_editor.dart`,
`platform/window_channel.dart`, `windows/runner/file_dialog.*`, `flutter_window.cpp`). On the
platform's fakes; no FFmpeg, no VEGAS:

- **FFmpeg health** (C3 `health`): a card whose files changed says so with Scan again; a
  missing one quotes its path with Locate… (the Open dialog, then `discovery.add`; a missing
  default hands its role to the file found); no ffprobe says where to put it, then Scan
  again. `healthMessage` is the tooltip's second line. `unknown`/`unchanged` show nothing.
- **History list from the index** (C6 summaries): rows read no record (a test counts the
  reads); encoder is the engine's `encoderSummary`; length, time taken, size and project
  from the index; an older line without them shows dashes. **Speed left the list**: the
  index has no realtime figure and the app doesn't divide (the engine's `realtime` is
  FFmpeg's speed, not length ÷ time); the detail still shows it (Needs).
- **History detail**: Open folder reveals the published file, else the kept unfinished
  one, else is off with "This render left no file to show."; a failed reveal says why.
  "FFmpeg log": Show log reads `JobLogs.readLog` as it streams, keeps the last 1,000 lines
  (200K characters, whole lines), opens at the end, says "The last 1,000 of 12,345 lines.";
  Show in folder reveals `logLocation`; no log says so; a log gone since (`NOT-FOUND`) says
  so. `errorTokenIndices` underline those argv entries in the command (error colours) with
  "FFmpeg's error points at “-preset 14”, underlined above."
- **Test this preset**: `AppServices.presetTests` (`presetTestsProvider`; the fake in
  `test/helpers.dart`). Header button beside the FFmpeg it uses ("Test", an icon below
  1080 px), off with the reason without an FFmpeg, without a command, or with errors. The
  dialog runs `PresetTests.test(recipe, installation)` (`presetTestProvider`, autoDispose:
  closing stops the run): phase, frame progress, the result with the output check, FFmpeg's
  output as it streams (last 400 lines), Show log / Show file, Stop test, Test again, and a
  "Sample result… nothing ran" line for the fake (`isFixture`). Mapping in
  `features/presets/test_display.dart`.
- **Library**: context menu Duplicate, Rename… / Export…, Copy share string, Show in folder
  / Delete…. Export… opens a new runner **Save dialog** (`saveFile`, `IFileSaveDialog`,
  asks before replacing) and `PresetTransfer.exportTo` writes the saved version; Copy share
  string puts `shareString` on the clipboard; Show in folder reveals `PresetLocations`
  (off for built-ins). A `+` beside the search: New preset, Import share string… (field
  starts with a `vepreset:` clipboard; `importShareString`, new ID `imported-preset`,
  selected), and Import file… (off: Needs).
- **Display fixes**: `VeFormat.bytes`/`rate` put a no-break space before the unit (the
  size card no longer wraps "859 / MB"); `CommandView` breaks lines itself, only between
  units (an option stays with its value) and indents wrapped parts by four spaces (two in
  one-line layout); the Advanced chip's lock badge stays inside its line box.
- Small defaults taken: Locate… on a missing default makes the new file the default;
  export and share strings carry the saved version (the menu says so for an edited
  preset); an imported preset keeps its shared name.

## Tests

`flutter test` in `app/`: **553 tests** (523 before the follow-ups, 477 before F6, 470 before saving with errors, 416 before F5, 403 before F7, 348 before F4).

Follow-ups added (30, six of them golden images), on the platform fakes, no FFmpeg, no
VEGAS: History (widget +5:
the index list and that only the selected record is read, older lines, Open folder for a
file / a kept partial / none, error marks and the note, the full log, a vanished log; unit
+7: index mapping, `commandParts`/`markedArguments`, log summary, `jobLogProvider`
chunking and NOT-FOUND); FFmpeg health (widget +5, unit +3); presets
(`preset_actions_test.dart`, 4: Test this preset passed and stopped/failed, Export… / Copy
share string / Show in folder / Import share string…, the export file name). Strings with
units now expect ` `. Goldens: new `ffmpeg_health`, `history_log`, `presets_test`
(light and dark); regenerated 64 for the header's Test button, the library's `+`, the
command view's wrapping, the size card and History's columns (`advanced_*`, `popup_*`,
`presets_*`, `size_and_command`, `window_desktop`, `history_*`). Looked at: all History
and the three new pairs, plus `advanced_locked`, `presets_native_file`, `presets_narrow`,
`presets_text150`, `popup_video` and `size_and_command`; the rest were not opened one by
one (the owner asked to keep this pass lean), so give them a glance in review.
`flutter analyze`: no issues. Platform fakes for services everywhere except the Windows
services tests below; the fake core for the F0–F3 tests and the native core (B2, through
`dart:ffi`, in the `flutter test` VM) for the core tests; a fake window controller; for
F3 two test doubles (`test/ffmpeg_doubles.dart`: a probe and hardware tests that stall).

F6 added (46), on the platform's fakes (`FakeLiveRenderStatusReader` samples, fixture job
records given the job's ID, `FakeFileReveal`; `test/monitor_doubles.dart`), a fake window
controller, no FFmpeg, no VEGAS:

- Widget (`monitor_test.dart`, 17): waiting, then starting → encoding (figures) →
  finishing → verifying → done through `publish`; an older sequence changes nothing; done
  closes at 10 s, stays open under the pointer and resumes after it leaves; Open folder
  and Close; done without a record; cancelled closes at 5 s; failed stays open with the
  reason and FFmpeg's lines; Show log reveals the log, and is off with its reason when
  there is none; Show in History off without a launcher and calling one; the pin writes C7
  both ways; "No news" after 30 s and cleared by a new status, never while checking;
  `monitorPlacement` with and without a file.
- Unit (`monitor_display_test.dart`, 16): paths, rounding down, unknown totals, titles,
  headlines and frames per state, bar tones, the six figures and dashes, header detail,
  the end sentences with and without a record (and a record for another job), FFmpeg's
  last lines, `hostHwndOf` (64-bit, invalid text).
- Unit (`services_wiring_test.dart`, +1) on the **real Windows services** in a
  temporary folder: the progress window's placement, live status and settings reads build
  no core; `jobLogsProvider` and `fileRevealProvider` are the Windows ones.
- Golden (`monitor_golden_test.dart`, 6 states × light and dark = 12 images, 380×340):
  `waiting`, `encoding`, `verifying`, `done`, `failed`, `cancelled`. Each was looked at.
  `window_progress` (design-system goldens) was regenerated at 380×340: it now shows the
  waiting state instead of the F0 placeholder.

F5 added (54), on the native core (B2) for everything in the popup, the platform's fake
services (`FakeEditSessionService`, `FakePresetLibrary` with `yt-h264` at revision 6), a
fake window controller, no FFmpeg, no VEGAS:

- Widget (`popup_test.dart`, 24): the fake session's name, origin line, strip facts and
  marks (dot on video, "Rev. 6" on audio) and the library banner; unshared project facts
  ("Set by the project", "Sample: …", the panel's sample note, still compiled); a missing
  request shown and closed with no result; `--edit-session` without a directory; the
  narrow (960 px) dock, collapsed then opened; the owner HWND from the request. Apply
  (Ctrl+Enter) writes the complete settings and the request's origin once, closes, and a
  later exit request exits; Cancel with no changes writes a cancel at once; Esc with
  changes asks, Keep editing keeps it open, Discard writes the cancel; Alt+F4 / the title
  bar asks the same and returns cancel until the result is written; an Extra-argument
  error turns Apply off with the reason, and Ctrl+Enter writes nothing. Load preset
  (popover footnote, settings replaced, name kept, origin, Undo bar and Undo); Update from
  library (both lists, "keep mine" enabled, merged result, origin revision 6); Replace
  with revision 6 and Undo; "keep mine" disabled with its reason when a setting changed in
  both places; Replace only without `baseRecipe`; Show changes; made in VEGAS (nothing to
  update); a deleted origin; Save as new preset… (name dialog, `builtin/yt-h264`, becomes
  the origin, Update then offered with "revision 1 → 2"); Update “Client H.264”
  (revision 3 → 4, the preset keeps its name); Open in Vegas Encoder disabled with its
  reason, and calling a supplied launcher. Advanced: Ctrl+M, the compact editor, the
  resolved command closed, "Edit it below the diagram." in the side, no Macros panel, the
  dashed strip, and a lint error (no `{output}`) turning Apply off.
- Unit (`popup_display_test.dart`, 11): the origin line in each state (unchanged, local
  changes and the change sentence, library newer, deleted, made in VEGAS, unreadable) and
  "revision 5 → 7"; setting labels and values ("CRF 17", "320 kb/s", "12 Mb/s",
  "8.5 Mb/s", "x265", "10-bit", "2 s", "Encoder default", "None", "Off", "Advanced", "As
  the project"); the strip's marks; when "Take library changes, keep mine" is possible.
- Golden (`popup_golden_test.dart`, 9 states × light and dark = 18 images, **on the native
  core**): `video` (the fake session), `update` (the dialog), `load` (the popover),
  `unknown` (made in VEGAS, project facts not shared, From VEGAS open), `advanced`,
  `errors` (Apply off with the reason), `deleted`, `discard` (the question) and `min`
  (960×640, docked). Each was looked at. `window_popup` (design-system goldens, fake core)
  was regenerated: its session isn't in the fakes, so it now shows the "couldn’t open this
  template" state instead of the F0 placeholder. The app shell test (`app_test.dart`) now
  opens the fake's `b0-session`; `launch_test.dart` checks `--owner` is no longer read.

F7 added (13):

- Unit (`services_wiring_test.dart`, 9), the **real Windows services on a temporary
  folder** with the native core: the providers are `FilePresetLibrary`,
  `FileMachineSettingsRepository`, `WindowsFFmpegDiscovery` and the rest, and reading
  writes nothing; the six packaged built-ins; a star on a built-in survives a new
  container (`preferences.json`) and its revision stays 1; a copy is a `.vepreset` file
  with origin `builtin/yt-h264` and core-derived requirements; the library refuses a
  recipe the core finds errors in (`RECIPE-INVALID`), keeps revision 1 and the draft; the
  editor's capabilities are the Basic view from the cache file (the recipe's encoder with
  options, others without). On fakes: the real services refuse to build under
  `flutter test`; the popup reads cached capabilities and never probes, the desktop probes
  once; an edit recompiles one library row and search none; the editor and the edited row
  share one compile.
- Unit: copies carry `builtin/<id>`, `preset/<id>@1` and the draft's base revision;
  stars on built-ins go through `PresetPreferences`; History copies get `job/<id>` and use
  the recorded command line and realtime figure (B4). The
  FFmpeg controller tests now check that the app writes nothing to C7 on Add, Remove and
  Scan again (discovery does).
- Widget: a refused save shows the library's reason and keeps "Edited"; About names the
  data folders. The History "Open settings as new preset" test caught a refresh that
  hung while nothing listened to the library (fixed).
- No golden changed: the fakes' screens look the same.

Budgets (TECH_ARCHITECTURE §9.3), `tool/budgets/budgets_test.dart`, run on purpose with
`VE_BUDGET_CACHE` set to a capability cache a real probe wrote on this PC (platform's B3
runs, three builds: gyan git `615b07170e`, BtbN `24e860f6d3`, gyan 5.1.2), the native
core, the Windows services on a temporary folder and a 500-preset file library. Figures
are from the `flutter test` VM (JIT), so an upper bound for the release build; medians:

| Path | Before F7 | After |
| --- | --- | --- |
| Basic edit: command, checks, library row (budget ≤ 4 ms) | 10–14 ms compile with the full map, plus every library row recompiled (1.5–1.7 s with 500 presets) | **3.9–4.3 ms** (compile 3.4–3.7 ms with the 38–43K-character view; rows 0.4 ms) |
| Size estimates (File node only now) | 1.3 ms on every edit | when the File node shows |
| Advanced keystroke: lint, compile, Basic compile (≤ 4 ms) | — | **25–32 ms**: lint and compile each send the full 156–236K-character map |
| Search / group 500 presets (< 150 ms; 60 fps) | — | 0.6 / 0.5 ms |
| File library `list()`, 500 presets (one watch tick) | — | **430–470 ms, repeated every 250 ms** on the UI isolate |

The last two rows are platform requests (Needs). Not measured: frame times in a profile
build with DevTools, memory, cold start.

F4 added (55), on the native core (B2) for everything Advanced, fake services, no FFmpeg
or VEGAS:

- Widget (`advanced_editor_test.dart`, 22): Ctrl+M seeds from the core and keeps both
  settings, the banner; the header switch; the seed question (keep, Esc, replace);
  Replace with Basic settings and Undo; Backspace into a chip refused, chip selected, the
  lock message, then whole deletion and `L-OUTPUT`; typing over part of a chip refused;
  caret snapping; cut and paste moves a chip; the core's lint as marks, counts, Line N
  and Go to; hover bubble; whole-command findings listed only; errors allowed in a draft
  and marked in the library; macro values from the core and insertion at the caret; a
  lost `{output}` put back; the resolved command's pipes, output and `{gop:2s}` → 60, Copy
  and the toggle; the dashed diagram with known and unknown facts and nodes focusing the
  editor; no estimate and the library's Advanced tag; Ctrl+Shift+C. Autocomplete: "-"
  opens the core's options in its order, arrows, Enter inserts and opens values; values
  after `-preset `, Tab, Esc; filtering by typed text, no opening elsewhere, Ctrl+Space;
  click to insert, caret move closes; encoders with their state.
- Unit (`advanced_display_test.dart`, 19): the mapping on hand-built C2 shapes: chips and
  words from spans, stage and macro roles when present, out-of-range spans ignored; marks
  (lint, compile-only, whole command), checks order, counts, lines and columns, mark at a
  caret; resolved lines; macro entries; the Basic summary line; the Advanced signal path
  (unknown facts, known facts, no compile result); the guard's replaced range (repeated
  characters, a paste before a chip); caret snapping; completion open rules, entries,
  availability and titles.
- Golden (`advanced_golden_test.dart`, 14 images): `seeded`, `lint`, `banner`, `narrow`
  (1100 px), `locked`, `suggestions`, `question`, light and dark. **These use the native
  core's data: regenerate them when it changes, and when the core gives Advanced words
  stage and macro roles.** No F0–F3 image changed. 96 images in all; each new one was
  looked at.

Saving with errors added (7), on the native core: widget (`native_core_test.dart`, 3)
settings errors stop Ctrl+S with the warning and nothing saved, Show setting; FFmpeg-only
errors (FFmpeg 8.0 LGPL without x264) warn and Save anyway saves; closing with such a
draft stays open. Popup (`popup_test.dart`, 1): Save to library warns and asks no name.
Unit (`popup_display_test.dart`, 1): the split. Golden (`native_golden_test.dart`,
`presets_native_save_errors`, light and dark), looked at.
B1 merge (2026-10-14): the 18 native-core goldens (14 Advanced, 4 `presets_native`) were
regenerated and each compared with its old image. What changed is B1's data only: the
CRF 18 mark reads "high quality" (was "visually lossless"); the Advanced seed starts with
the explicit input colour tags before `{inputs}` (`-color_primaries bt709 … -color_range
tv {inputs}`), so line 1 wraps; the resolved command has those tags before `-f rawvideo`
and no `-thread_queue_size 64`. Every other test passed unchanged on B1's data.

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

**F7 recheck (2026-10-14), on the Windows services.** Release build (56 s), same machine
and harness, `-Checks start`, fake host, `VEGAS_ENCODER_DATA_ROOT` set to a scratch folder
(the user's `%APPDATA%` and `%LOCALAPPDATA%\VegasEncoder` stayed absent).

| Start, warm, median of 10 | Before (runner fix) | F7 |
| --- | --- | --- |
| Skia desktop shown (Dart main to first frame) | 537 ms (32) | **414 ms (13)** |
| Skia popup shown | 351 ms | 360 ms |
| Impeller desktop / popup shown | 1,413 / 1,297 ms | 1,328 / 1,319 ms |

The desktop's first frame no longer waits for the library: the file library delivers
after it. The 20 desktop runs saved their bounds to the scratch `machine.json`
(revision 20), so window bounds now survive a restart.

**F5 recheck (2026-10-15), the popup's owner from `request.json`.** Release build (31 s)
of `fe248b5`, `-Checks owner` then `-Checks start`, fake host, `VEGAS_ENCODER_DATA_ROOT`
on `app\build\spikes\data-root`; each popup gets the C4 fixture request with the fake
host's HWND. Monitors now: a 2560×1440 primary at 120 dpi and two 1920×1080 at 96 dpi.
`%APPDATA%` and `%LOCALAPPDATA%\VegasEncoder` stayed absent before and after both runs.

| Check | Result |
| --- | --- |
| Owner from `request.json` (same DPI) | Owner set, centred (offset 0,−4 px), foreground, hidden and restored with the owner, owner re-enabled and foreground after WM_CLOSE. Shown 435 ms (trace), `owner_bounds` 4 ms after Dart main |
| Result on WM_CLOSE, nothing changed | `result.json` is a cancel with the request's sessionId; no other files besides the request and the writer's lock (also 10 of 10 popup start runs) |
| Editor killed | No `result.json` (C4: a crash means cancel); the owner doesn't get the foreground back by itself but can take it after re-enabling (as F0–F7) |
| **Owner on a 96-dpi monitor, primary at 120 dpi** (3 runs) | Owner set; window at 96 dpi; centred within 4 px (0,−4) every run; visible size 1122×741 against 1120×740 expected; `owner_bounds` targets the owner's monitor at 96 dpi. Shown 609, 636, 659 ms (trace) |
| Start, Skia, warm, median of 10 | Desktop **445 ms** (Dart main to first frame 15); popup **395 ms** (12, request read included). F7: 414 / 360; the extra time is before Dart starts (window created at 324–330 ms vs ~299), on both windows |
| Start, Impeller | Desktop 1,388 ms, popup 1,403 ms (F7: 1,328 / 1,319) |

Over the other-DPI owner the popup stays within the 0.7 s warm budget but takes about
200 ms longer than over a same-DPI owner: Dart main to `owner_bounds` was 110–140 ms in
those runs (4 ms otherwise), and the move to the other monitor then resizes the view.
Why the request read took longer there is not established.

**Follow-up recheck (2026-10-15), the Save dialog.** Release build (31 s, no C++
warnings), `-Checks start`, fake host, data root on `app\build\spikes\data-root`. Skia warm
medians: desktop shown 427 ms, popup 401 ms (F6: 433 / 413); Impeller 1,431 / 1,360 ms; popup
WM_CLOSE left a cancel `result.json` 10 of 10. `%LOCALAPPDATA%\VegasEncoder` stayed absent;
`%APPDATA%\VegasEncoder` already existed before the run (the harness reports existence only).
The Save dialog
(`saveFile`) is compiled in and covered with the fake controller; it was not clicked or
automated.

**F6 recheck (2026-10-15), the progress window.** Release build (37 s), `-Checks monitor`
three times, then `-Checks start`, fake host, `VEGAS_ENCODER_DATA_ROOT` on
`app\build\spikes\data-root`, the same three monitors. Live files written by the probe
(the encoding sample with the fake host's handle), not by the exporter. The user's
folders were the same before and after.

| Check | Result |
| --- | --- |
| No-activate, VEGAS's monitor = primary (120 dpi) | Fake VEGAS stayed foreground when the window showed and after a click on it; `WS_EX_NOACTIVATE`; not topmost (pin off); 475×425 physical (380×340 at 120 dpi), 20 px (16 logical) from the work-area corner |
| Pin remembered | With `keepOnTop: true` in `machine.json`: topmost from the start, VEGAS still foreground |
| **VEGAS on the right 96-dpi monitor, another window in front on the primary** | Window on VEGAS's monitor at 96 dpi, 380×340, 16 px from the corner; the other window stayed foreground; no owner. `host_bounds` 294–301 ms after start; shown 385–506 ms |
| Stale `hostHwnd` | Falls back to the foreground window's monitor, 20 px from the corner |
| Start, Skia, warm, median of 10 | Desktop 433 ms, popup 413 ms (F5: 445 / 395). Impeller 1,346 / 1,351 ms |

Runs 2 and 3 agree line for line. **Run 1 is not used:** its monitor coordinates
changed partway through (the right monitor reported at x=1920 instead of 2560), so its
own placement checks disagreed with the app's trace, which was right
(`host_bounds target=(4084,693,…)`, 16 px in from that monitor's corner). The cause was
not established.

**Cost while rendering** (release build, a script replacing the live file twice a
second for 20 s, no VEGAS, no FFmpeg): 109 ms of CPU in 20.6 s (0.5% of one core);
working set 99 MB, private 114 MB, under the 120 MB rule; `ve_core.dll` not loaded until
after `done`; the window closed itself after done. One of the script's 41 replaces failed
with "access denied" while the window was reading. The exporter's writer
(`job_store.cpp` `Atomic`) retries that for up to 500 ms on its own thread, never Render's,
so this costs it at most a short wait. The owner's three-renders-with, three-without check
in VEGAS (TECH_ARCHITECTURE §5.6) is still to do (B6).

- **Renderer: deferred.** The runner defaults to Skia for start time;
  `RendererFromEnvironment` in `windows/runner/main.cpp` is the one place to change, and
  `VEGAS_ENCODER_RENDERER=impeller` tries Impeller. Re-measure on each Flutter upgrade
  and with VEGAS running.
- **Flutter 3.47.7** at `L:\flutter` is intended. ROADMAP and WORKSTREAMS say so.
- **Light tokens accepted as the mockup has them**, including UI_SPEC §9's figures.
- **Presets with errors aren't saved; the app warns first** (owner, 2026-10-15). Errors in
  the settings themselves stop Save, Duplicate, "Save all" on closing and the popup's Save
  to library with "Fix the errors before saving"; errors only for the chosen FFmpeg warn
  with Save anyway (the preset may suit another FFmpeg). UI_SPEC §3. The library's own
  refusal (`RECIPE-INVALID`) matches the first rule, so no platform change is needed.
- **F6 goes to another app agent** (owner, 2026-10-15); the handoff below is for it.
- **Plug-in and app versions** (owner, 2026-10-15; not built yet, for a later stage):
  - The exporter keeps its own static copy of the core (TECH_ARCHITECTURE T1). It does
    not load the app's `ve_core.dll`: a render must not depend on the app's folder, and
    sharing the file adds no update guarantee, because updating already replaces the
    locked plug-in and so already needs VEGAS closed.
  - The two stay in step through installation and version checks instead. The popup
    compares the request's `coreVersion`/`dllVersion` (C4) with its own core and warns,
    for example "VEGAS's plug-in is from a different build; run setup". This is an app
    task for a later stage; it is not built. The plug-in should check the app's version
    before launching the popup or the progress window (platform, Needs).
- **Installer** (owner, 2026-10-15; replaces B7's plan of an agent-built installer):
  - The owner builds it with **Inno Setup**, hands-on, guided by AI. Agents supply inputs
    and guidance, not a finished `.iss`. Inputs: the file set per target, install
    locations, version stamps, what must be closed, VEGAS detection, and the existing
    reversible installer's rules to carry over (manifest, backups, refusing files changed
    by hand).
  - **One release, installed together.** Setup updates the app and every plug-in copy
    from the same build, or nothing. It requires VEGAS and the app to be closed (Inno's
    close-applications support or a process check), and never finishes with some targets
    updated and others not.
  - **Later: choosing VEGAS versions.** Only VEGAS 2026 (2026.0.3.189) is tested; older
    versions likely need different plug-in builds (the host interfaces are reverse
    engineered per version). That is platform research first: per-version interface
    checks, real-host tests, and where each version records its install in the
    registry. Setup would then map each VEGAS version to its plug-in build, all sharing
    one core version.
  - **Setup owns the set of targets.** It keeps a record of every VEGAS it installed
    into (VEGAS version, folder, plug-in version), in the registry under its AppId or
    a manifest beside the app. An update updates every recorded target by default;
    unticking a previously installed VEGAS removes the plug-in from it, so no copy is
    left behind stale. Uninstall removes every recorded copy. Check how Inno's uninstall
    log behaves across repeated installs with the same AppId for files placed in
    folders chosen at run time.
  - A stale copy anyway (manual copy, failed install) still renders its saved templates
    with its own core; the version checks above catch it when the template is edited.
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

Delivered in B1 (merged `a0d33c4`, 2026-10-14): the Windows FFmpeg data needed no app
change beyond regenerating the 18 native-core goldens. `CommandToken.replacedField` is
used: pointing at a control that Extra arguments replaced lights the Extra option and
value that replaced it (before, nothing lit). `libavformatMajor` reaches the core through
the services' capability view with no app code.

Used in F4 with no change: `CompileResult.display` token `sourceStart`/`sourceEnd` and
`input`/`output` roles for the Advanced text, `advancedTemplate` for the seed,
`VeCore.lint`, `VeCore.complete`, Advanced `signalPath` facts and summary.

Delivered in B3 and B4 (merged `a0d33c4`) and **used since F7** (2026-10-14):
`WindowsServices` (one composition for every provider); discovery, probes and hardware
tests owning C7 installation records and the cache (the app's copies are gone);
`toCoreCapabilities(recipe:)` views; `PresetPreferences` for stars on built-ins;
C3 copy origins (`builtin/<id>`, `preset/<id>@<revision>`, `PresetTransfer.fromJob`'s
`job/<id>`); real settings, so window bounds and the size card's length survive a restart;
C6 `commandLine` and `realtime` in History. This answers the F3 questions on discovery
vs `machine.json`, probe results on the installation and where hardware results are kept.

Delivered in B3/B4 and **used since the follow-ups** (2026-10-15): `FFmpegInstallation.health`
and `healthMessage`; job index summaries (`encoderSummary`, `project`, `durationSec`,
`elapsedSec`, `sizeBytes`); `JobLogs`; `errorTokenIndices`; `PresetTests`;
`PresetTransfer.exportTo`/`shareString`/`importShareString`, `PresetLocations` and
`FileReveal`. `PresetTransfer.duplicate` copies the source's star; the app keeps its own
copy path so a copy starts unstarred and can hold a draft.

Used in F5 with no change: C4 `EditSessionService` (`readRequest`, `writeResult`, the fake's
`b0-session`), `EditSessionRequest.ownerHwnd`, `origin`, `baseRecipe` and `context`;
C2 `diff` for the origin line, the strip's marks and both dialogs; C3 `PresetLibrary.get`,
`list` and `save` for Load preset and Save to library.

Open (additive):

| Need | Request |
| --- | --- |
| Version checks and installer inputs (owner, 2026-10-15; later stage) | See the owner's "Plug-in and app versions" and "Installer" decisions above. (1) Before launching the popup or the progress window, the plug-in checks the installed app's version against its own build and says "run setup" on a mismatch. (2) An "installer inputs" note for the owner's Inno Setup work: the file set per target, install locations, version stamps, what must be closed, and the current reversible installer's rules. (3) Research before supporting older VEGAS versions: per-version host interfaces and where each version records its install |
| **Library watch cost (F7). Owner priority, 2026-10-15** | `FilePresetLibrary.watch` polls every 250 ms, and each tick calls `list()`, which reads, decodes and normalizes (an FFI call per preset) every preset file on the caller's isolate, the app's UI isolate. Measured with 500 presets: **430–470 ms per tick** (`app/tool/budgets/budgets_test.dart`, real capability caches, JIT), so the poll runs back to back while a screen watches the library; with a handful of presets it is a few ms every 250 ms. Please make an unchanged library cheap to watch: list the folder and compare each file's size and last-write time (and `preferences.json`'s), keep each decoded preset and its requirements, and re-read only added or changed files (or watch the folder with `ReadDirectoryChangesW`, or poll off the caller's isolate). Keep what `watch` promises now: a current snapshot per listener, then a new value only when something changed; added, removed and edited presets and built-in star changes all show, and a malformed file behaves as today. Target: with 500 unchanged presets, a tick costs a few ms at most on the caller's isolate, measured through the real `FilePresetLibrary`. The app needs no change (it re-reads after its own writes, `PresetsController._refresh`) |
| Open in Vegas Encoder (F5), Show in History (F6) | UI_SPEC §4: the popup opens the desktop app on the origin preset; §12: the failed progress window opens it on the job in History. No C3 service starts the desktop app (or hands an existing one a preset or job), and the app starts no processes itself (AGENTS.md). Please add one, for example `DesktopApp.openPreset(presetId)` and `openJob(jobId)` that start `VegasEncoder.exe` with an argument or ask the running single instance to show it. The app's side is ready (`DesktopAppLauncher` in `state/services.dart`); both buttons are disabled with the reason until then (`desktopAppLauncherProvider` is null) |
| Output bit depth in C5 (F6) | S6's header starts with a wire glyph for 10-bit or 8-bit output, with a pip when a conversion lowers it. C5 has no bit-depth fact, so the window shows no glyph rather than guess. An additive `outputBitDepth` (and whether a pixel-format conversion reduces it, as the core's signal facts say) would let it draw one; nothing else changes |
| Popup size (F5) | UI_SPEC §1: the popup remembers its size, not its position. C7 `uiState` has desktop fields only, so the popup opens at its default size every time. Please add an additive `popupWindowSize` (physical width and height, or logical) to `AppUiState`, or the owner decides the popup keeps the default size |
| Render As path in the popup (F5) | C4 `context` carries the project but not the file Render As will write, so the popup's command and Advanced's resolved command use the sample path (`D:\Renders\Sample project.mp4`; the resolved command says "for the sample project"). If the page can know the path, an additive `context.outputPath` would let the preview show it; otherwise nothing changes |
| Capability transfer in Advanced mode (F7) | Lint and compile each serialize the full capability map (156–236K characters) through FFI: **25–32 ms per keystroke** in Advanced mode (budget 4 ms). Please let the core keep a capability map it was given (an ID or handle per identity key) so later calls pass the ID, or offer one call that lints and compiles a template together |
| Advanced token roles (F4) | In Advanced mode every user word comes back as role `extra`, so the editor can't colour options by stage (video, audio, mux, global), draw stage stripes or style macros. Please give Advanced tokens the same stage roles Basic tokens have and role `macro` (already in `TokenRole`) for a word that held a macro, keeping `sourceStart`/`sourceEnd`. An option/value marker per token would replace the app's "starts with -[letter]" bold rule. The app reads these with no change; until then only option names (bold) and the chips stand out. **Delivered (master `fa58338`): stage colours, stripes and macro styling now show with no app change; the option/value marker isn't adopted yet** |
| Macro list (F4) | The macros panel takes names from `VeCore.complete("{")` (generic description "VEGAS media or output macro") and values from a compile of the names alone. A `VeCore.macros(media, paths)` (name, description, required, expanded value) would replace both; the app keeps its own wording only as fallback |
| Encoder IDs in Advanced (F4) | The Advanced summary names the command's encoders by label ("x265", or the raw name), so nodes can't show availability for the chosen FFmpeg (lint's `L-ENCODER` covers a missing one). A `videoEncoderId`/`audioEncoderId` (summary or signal facts) would let the nodes show Ready / Not in this FFmpeg |
| Temporary output name (F4) | "Resolved command" shows the sample Render As path for `{output}`; SETTINGS_AND_COMMANDS §4 says the engine writes a temporary name. If the preview should show it, C2 needs the naming rule (or a `CompilePaths` helper) |
| Realtime in the job index (follow-ups) | History's list reads only `jobs.jsonl` now, which has no realtime figure, so the Speed (× realtime) column is gone from the list (the detail shows the record's). The engine's `realtime` is FFmpeg's speed, not length ÷ time, so the app can't work it out. An additive `realtime` in `JobIndexEntry` brings the column back with no other change |
| Import a `.vepreset` file (follow-ups) | PRODUCT_SPEC F8: "On the other PC, Import validates the file." `PresetLibrary.importPreset` takes JSON text and `PresetTransfer` has no import from a path, and the app reads no files itself. Please add `PresetTransfer.importFrom(path, {newId})` (bounded read, same validation as the share string). The `+` menu's Import file… is shown disabled until then; the Open dialog (`pickFile`) is ready |
| Plain failure text from PresetTests (follow-ups) | A failed test's `message` is the exception's `toString()` ("ServiceException(PROBE-REQUIRED): Probe this installation…"). The app strips that wrapper for display (`serviceMessage`), which depends on Dart's `toString`. Please put the plain message in `message` (and the code in its own field if useful) |
| Test frames at the project's size (follow-ups) | UI_SPEC §2 says Test this preset encodes at the sample or project context's size, rate and pixel format; `PresetTests` always uses 320×180 P010 at 30 fps. The app shows the service's result and claims no size. If the owner wants the spec's behaviour, the service would take a `MediaDescription`; otherwise UI_SPEC keeps the as-built note |
| Partial highlighting (F4) | With an unterminated quote, compile returns no tokens, so the editor loses its chips (and their guard) until the quote is closed; lint reports `L-QUOTE` over the whole text. Spans for the words before the open quote, and the quote's position, would keep them. **Delivered (master `fa58338`): the editor now underlines `L-QUOTE` from the quote to the end; keeping chips before the quote isn't checked yet** |

## Open items

Waiting on platform (see Needs): the recommended quality band (a product-policy choice,
platform.md); the library watch's cost and the Advanced capability transfer (the §9.3
budgets). platform.md's queue of 2026-10-15 has the Advanced latency, the F4 token data,
the popup size, the desktop launch and `context.outputPath`. The library watch's cost was
missing from the table after F5's rewrite; it is back at the top of Needs as the owner's
priority (2026-10-15).

Follow-ups (2026-10-15), points to check in use (everything ran on fakes only):

- **Test this preset** is on the desktop header only. UI_SPEC §2 says desktop and popup;
  the popup has no button yet (its header is full: Load preset, Save to library, Basic |
  Advanced). Owner: where should it go in the popup, or desktop only?
- The real `PresetTests` needs the installation's cached capabilities (`PROBE-REQUIRED`
  otherwise), refuses general extra inputs/maps/filters (`PRESET-TEST-SCOPE`) and leaves
  its output and log in `%LOCALAPPDATA%\VegasEncoder\tests`. None of this ran with a real
  FFmpeg; the failure wording is the service's.
- History's list has no Speed column (Needs: realtime in the index).
- Export… and Copy share string carry the saved version; the menu says so for an edited
  preset. An imported preset keeps its shared name, so a library can hold two presets with
  one name. Import file… waits on platform (Needs).
- The Save dialog and Explorer reveals were not clicked in the running app.
- The command view now chooses its own line breaks from measured widths (a 2 px margin).
  If a font or text-scale change ever made the paragraph wrap a line the view kept, that
  line would wrap without the hanging indent; nothing else breaks.

Waiting on platform for F6: starting the desktop app on a job (Show in History), the
output bit depth in C5 (the header glyph). Gated: the window has only read hand-written
live files; the exporter launching it, real renders, and the owner's with/without
performance check are B6 work.

F6 points to check in use:

- **Private memory is close to the budget:** 114 MB private, 99 MB working set, against
  "under 120 MB" (TECH_ARCHITECTURE §5.6, which doesn't say which figure). Most of it is
  the Flutter engine. If the owner's check counts private bytes, this is the first thing
  to look at (Skia vs Impeller, the font set).
- The record lookup gives up after about 2 s; a record written later than that leaves the
  live file's shorter sentence (no size, no output check) and Show log off.
- "Show log" shows the file in Explorer rather than opening it in an editor: there is no
  service for opening a file with its default app.
- The window can't be moved off the monitor it opened on except by dragging; it doesn't
  follow VEGAS if VEGAS moves during the render.

Waiting on platform for F4: Advanced stage and macro roles, a macro list, encoder IDs
in Advanced mode, the temporary output name, partial highlighting with an open quote.

Waiting on platform for F5: starting the desktop app (Open in Vegas Encoder), a stored
popup size, the Render As path in the session context. Gated: the popup has only met
the platform's fake session; the native page, real requests and VEGAS's own Apply/OK
commit are B6 work behind A5–A7.

F5 points to check in use:

- **Real VEGAS host.** Ownership, focus, modality and placement were checked against a
  WinForms fake host only; the popup's input and focus inside VEGAS's Custom Template
  dialog are part of the P4 checklist (TECH_ARCHITECTURE §5.2).
- **Another-DPI owner**: fixed (`OwnerBounds`, placed after the `configure` reply) and
  measured against a fake host on a 96-dpi monitor beside a 120-dpi primary: centred
  within 4 px at the right size. It shows about 200 ms later than over a same-DPI
  owner (609–659 ms); part of that is an unexplained slower request read.
- **Load preset** reads the library once each time the list opens (no watch), and its
  lines are recipe-based ("x264, AAC") without a compile per preset, so they don't show
  the core's quality summary.
- **Update “X” (revision 5 → 7)** writes the template's settings over the library's
  newer revision 6; the label shows both numbers, but nothing else warns about it.
- The popup's checks use the default FFmpeg's cached capabilities only (never a probe);
  with nothing cached, the core's curated profile data stands in and says so.
- Below 1040 px the "Library and command" dock starts collapsed; its summary line names
  the library state and the error count, so an Update from library offer is one click
  away rather than in view.
- Changing the template's mode or command counts as changes in the origin line (the
  core's diff includes `command.mode` and `command.template`).

F4 points to check in use:

- **Ctrl+Space** is the Windows IME on/off key for some Chinese layouts; with such an
  IME the system may take it first. Not tried on this PC.
- The editor's per-line messages are painted, so screen readers get them from the bar
  (message at the caret, a live region) and the Diagnostics list, not from the line.
- The suggestions popover is placed from the caret after the frame (one frame late when
  the caret moves); it stays where it opened if the page scrolls under it.
- A word typed directly against a chip (`{inputs}x`) joins it, so the core no longer sees
  `{inputs}` and the lint says so; the chip comes back when the space is restored.
- Long Advanced library rows truncate the summary after the tag ("x264, your co…").
- A chip's lock badge sits at its top-right corner but inside the chip's line box (fixed
  in the follow-ups; it used to overlap the row above).
The Open dialog (`pickFile`) is built and covered with a fake controller; it was not
clicked through in the running app. Small display points seen on the native core (the
size card's "859 / MB" wrap and the command view's wrapping were fixed in the follow-ups):

- A control replaced by Extra arguments keeps showing its own value with the note
  (UI_SPEC §2 as written). If that reads as contradictory in use, dimming the control is
  a later design choice.
- The native core loads at the first build of the desktop shell; a load failure is
  shown, not retried (it is permanent for the process).

Window start (runner), unverified or not fixed:

- **Popup over a VEGAS window on another-DPI monitor** (F5): split like
  `ClampBounds`/`RestoreBounds` (`OwnerBounds`, placement after the reply, the deferred
  show) and measured with a fake host (F5 recheck): centred and sized right. Still about
  200 ms slower to show than over a same-DPI owner; cause of the slower request read not
  established.
- **Restoring maximized** shows a stretched first frame for ~20–40 ms (the restored-size
  frame scaled up). Present before the fix too. Sizing the hidden window to the maximized
  client size before the first frame may avoid it (untested; not attempted in the
  follow-ups, since the spike harness can't show a one-frame stretch).
- The remaining ~150 ms desktop-only first-frame delay (Spike results); cold start.

## Historical app handoff (superseded by NEXT_AGENT.md)

The old handoff started from `ws/app`; current work uses the original checkout.
The technical notes below are retained for reference. Read current AGENTS.md,
WORKSTREAMS.md, CONTRACTS.md, NEXT_AGENT.md and the
UI_SPEC section for what you change. F6 and the B3/B4 follow-ups are done (the follow-ups
are uncommitted on `ws/app` for the owner's review); the app runs on the native core (B2)
and the Windows services (B3), with fakes in tests. What's left is waiting on platform
(Needs) or the owner (Test this preset in the popup; Open items).

- Follow-ups live in: `features/ffmpeg/display.dart` (`installationHealth`),
  `features/history/` (index mapping, `commandParts`, the log section) with
  `state/history.dart` (`jobLogProvider`, `jobLogLocationProvider`),
  `features/presets/preset_test_dialog.dart` + `test_display.dart` + `state/preset_test.dart`,
  and the library's actions in `presets_page.dart`. Test doubles: `test/history_doubles.dart`
  (records with summaries, error tokens and logs), `unhealthyInstallations()` in
  `test/ffmpeg_doubles.dart`. History's goldens use those doubles, not the bare B0 index.
- `CommandView` lays out its own line breaks (`_build` takes the width); unit strings
  from `VeFormat` contain ` `, so tests match `'9.84 GB'`, while core and service
  text (node summaries, `encoderSummary`) keeps plain spaces.
- Runner or window changes need a release build and `tool/spikes/run_window_spikes.ps1`
  (`-Checks monitor`, `owner` or `start`; never `all` or `theme`); it sets
  `VEGAS_ENCODER_DATA_ROOT` to a scratch folder. If a run's monitor coordinates disagree
  with themselves, run it again (F6 recheck). Nothing runs in VEGAS until B6.

- The progress window (F6) lives in `state/monitor.dart` (live status, record, log,
  `monitorPlacement`, `hostHwndOf`) and `features/monitor/` (the window; `display.dart`
  for every label and sentence). Its tests use `test/monitor_doubles.dart`. Done closes
  after 10 s and cancelled after 5 s (UI_SPEC §12; the earlier handoff said cancelled
  stays open, but the spec and mockup say it closes); failed stays open. While rendering
  it must keep reading only the live file and settings: `services_wiring_test.dart` fails
  if it loads the core.

- The popup (F5) lives in `state/popup.dart` (session, controller, `popupEditorProvider`,
  `popupChangesProvider`, `applyBlocked`) and `features/popup/` (window, editor, dialogs,
  `display.dart` for the origin line and setting names). Its tests use the native core and
  a `FakeEditSessionService` per test (`resultFor` reads what was written).
- Advanced mode (F4) lives in `features/advanced/` (mapping in `display.dart`, the
  workspace, the macro provider) and `design/components/command_editor.dart`. The editor
  asks its controller's `describe` for the model of any text; the workspace answers from
  `EditorData` or the core. Its goldens use the native core's data.

- Services: one `servicesProvider` (`WindowsAppServices` over the platform's
  `WindowsServices`); every service provider derives from it. Tests get the platform's
  fakes through `servicesOverride()` (`pumpApp`, `pumpThemed`, `testContainer`; pass
  `services:` for another bundle) and the real services refuse to build under
  `flutter test`. Set `VEGAS_ENCODER_DATA_ROOT` to a scratch folder for release runs and
  spikes. File watches poll every 250 ms: after a write, re-read before relying on the
  stream (`PresetsController._refresh`).
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
  error, so check `hasError` rather than matching `AsyncError`. A provider whose failure
  won't fix itself (the session file) passes `retry:` returning null. Guard state writes
  after an await with `ref.mounted`; Riverpod pauses a provider nobody listens to, so
  listen while awaiting a refreshed stream.
- `CoreResult` (`state/editor.dart`) keeps a core failure explicit; the editor says
  what's missing instead of showing an old result.
- Before each commit: `flutter analyze`, `flutter test`; regenerate goldens only for
  intended visual changes and look at them. Window or runner changes: rebuild release
  and run `tool/spikes/run_window_spikes.ps1`.
