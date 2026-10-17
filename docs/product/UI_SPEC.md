# UI behaviour specification

Updated: 2026-10-17 (Asia/Singapore). App/platform integration follows one queue
in the original checkout; use [NEXT_AGENT](../NEXT_AGENT.md) for current work.
Status: behaviour reference, updated for the chosen
direction; §1, §9, §10 and §11 record what the app workstream built in F0 and F1, §2
what F2 built, §3 F4, §4 the popup (F5), and §5, §6 and §6a what F3 built, refined by the
B3/B4 follow-ups of 2026-10-15 (installation health, History from the index with the full
log and error tokens, Test this preset, export and share strings). Since 2026-10-14
the editor runs on the native core (B2) and Windows services (B3, F7). Actual
real-VEGAS evidence and limits are in [STATUS](../STATUS.md); old workstream
handoffs are historical, not current prerequisites or ownership boundaries.

This document covers the behaviour Flutter will implement: states, flows, the signal
path, the size card, theme, keyboard, copy and the token structure. The chosen
direction is Signal Flow, round 2 ([design/signal-flow.html](design/signal-flow.html)).
The vocabulary is fixed in the brief §2.

## 1. Windows

| Window | Default | Minimum | Notes |
| --- | --- | --- | --- |
| Desktop app | 1440×900 | 1100×700 | Remembers size, position and maximized (C7 `uiState`; clamped to a current monitor on restore); single instance per data profile, including preset/job navigation handoff |
| Popup editor | 1120×740 | 960×640 | Owned by the VEGAS dialog its session names and centred on it, on that monitor's DPI; resizable. Remembers physical outer size through C7 `popupWindowSize`, never position; clamps to the current monitor and minimum size |
| Native page | Host-defined | — | Win32 inside VEGAS; see the mock |

Below 1280 px width the desktop app collapses the library to an icon rail (library and
Ctrl+K buttons; the library opens over the editor and closes on a choice, Esc or a click
outside). Below 1040 px the popup docks its side column (library and command) at the
bottom as a collapsible "Library and command" strip, collapsed, with a one-line summary
("Library has revision 6. No errors."), so the signal path keeps its width.

### Theme

- Light and dark token sets (§10). Both windows follow the Windows app theme
  (Settings > Personalization > Colors, "Choose your app mode") by default and switch
  live when it changes. Verified on Windows 11 (F0 spike, 2026-10-12): Flutter's
  embedder watches `AppsUseLightTheme` and the app followed a change in about 0.1 s.
  The runner reports "Animation effects" itself, because Flutter's Windows embedder
  does not (see §9).
- Settings > Theme offers **Follow Windows** (default), **Light** and **Dark**. The
  popup uses the same choice, read from the app settings.
- VEGAS's own dialogs keep their look; only Vegas Encoder windows change.
- Every screen gets golden tests in both themes.

## 2. Presets screen (S1)

### Library

- **Groups:** Built-in, then Mine, each sorted by category then name. Favorites
  float to the top of their group. Search matches name, tags, encoder and codec
  (e.g. "nvenc", "prores", "youtube").
- **Each item:** name, a one-line summary (codec and quality, audio, container) and
  marks for favorite, built-in, Advanced mode, a small wire glyph for 10-bit or
  8-bit output, and **availability** (an
  error-coloured mark plus a tooltip such as "Needs x264: not in FFmpeg 8.0 LGPL").
- **Context menu:** Duplicate, Rename, Export…, Copy share string, Delete (user
  presets only), Show in folder. As built: Duplicate, Rename… / Export…, Copy share string,
  Show in folder / Delete… (destructive last). Export… opens the Windows Save dialog
  (`name.vepreset`, asks before replacing) and the library writes the saved version
  (C3 `exportTo`); Copy share string copies `vepreset:1:…`; Show in folder shows the file
  in Explorer (off for built-ins: "Built-in presets are part of the app."). For an edited
  preset the menu says these carry the saved version.
- **Add menu (`+` beside the search):** New preset; Import share string… (the field starts
  with the clipboard when it holds a `vepreset:` string; the preset lands in Mine, keeps
  its name and is selected); Import file… opens the Windows `.vepreset` picker and
  delegates bounded validation to C3 `PresetTransfer.importFrom`. A successful import
  creates a new preset in Mine, selects it and clears filters/search. Cancelling the
  picker or refusing invalid input leaves the current selection unchanged.
- **Empty search:** "No presets match 'xyz'." plus a **New preset** action (a preset in
  Mine started from the first built-in, named "New preset") and **Show all presets**.
- **Error mark:** a preset the core finds errors in, for the chosen FFmpeg, shows an
  error icon whose tooltip lists the core's messages.

### Editor states

| State | Trigger | Behaviour |
| --- | --- | --- |
| Clean | Loaded or just saved | Save disabled |
| Dirty | Any change | Title shows "Edited" and the library row a dot; Save, Revert (with Undo) enabled. Other presets can be opened meanwhile; each keeps its changes. Closing the window asks "Save changes to '<name>'?" (Save / Don't save / Cancel), or "Save changes to N presets?" (Save all) |
| Built-in | Built-in preset selected | Editing allowed as a draft; Save becomes **Save as new preset**; a note says "Built-in presets can't be changed. Your changes will be saved as a new preset." |
| Errors | Validation has errors | Save still allowed (presets can be work in progress); the preset shows an error mark in the library |
| Updated elsewhere | File changed by the popup or another window | Banner: "This preset changed in another window." **Reload** / **Keep editing** (save then asks to overwrite or save as new) |
| Core failure | The core returns an error for this recipe (for example `JSON-LIMIT`, input over 1 MiB) | The command column says "The core couldn’t build the command: <message>" and Checks wait for it; the File node says "The core couldn’t work out an estimate: <message>". No earlier result is shown |
| Core not loaded | The core's DLL is missing or doesn't match (`NATIVE-LOAD`, `ABI-MISMATCH`) | The desktop window keeps its title bar and shows "Vegas Encoder couldn’t load its core", what it is for, and the code and message, in place of every screen. Nothing falls back to the fake core |

### Signal path

The diagram is the editor's navigation. Its nodes are **From VEGAS**, **Video
encoder**, **Audio encoder**, **Container** and **File**. Selecting a node opens its
settings below it; arrow keys move between nodes.

| Where | Size | Content |
| --- | --- | --- |
| Desktop | Full width, about 216 px tall | Title row with the context and the legend; nodes with a label row, a name and one detail line; wire labels for bit depth, codec and conversions |
| Popup | One row, about 100 px tall | Small nodes; one line per encoder (name and quality); conversion pips with short labels such as "10 to 8-bit"; no legend or codec labels |

- **Wire thickness is bit depth**: thick for 10-bit, thin for 8-bit. Audio uses the same
  rule for float, 24-bit and 16-bit samples.
- **An amber pip marks each format conversion**, labelled with what changes
  ("p010le to yuv420p", "4:2:0, precision lost").
- **Node marks:** availability problems turn a node red with the state; "Changed" and
  "Revision 6" marks show local and library differences in the popup.
- **Advanced mode** draws the nodes dashed, read back from the command. They don't
  open settings; clicking one focuses the editor. Only the core's facts for the active
  command fill them; the inactive Basic settings never show, and unknown facts stay
  unknown (§3).
- **Audio off** leaves a dashed audio node ("Audio is off. The file has video only.").
  It still opens the audio settings, where audio is turned back on.
- **Only the core's facts.** Pips, notes, bits and broken wires come from the core's
  signal facts (C2 `signalPath`): a pip wherever `conversion` is true, video and audio
  alike ("flt to fltp" for AAC's planar input). When the core gives none (a core
  failure, or an edit the test fake has no fixture for), the wire keeps VEGAS's depth
  and claims neither a pip nor "No conversion".

### Basic editor

Each node opens one panel: From VEGAS (read-only facts), Video encoder, Audio
encoder, Container, and File. Every panel must:

- Hide controls the encoder doesn't have. Keep their recipe values; they are only
  ignored by compile.
- Keep invalid-but-selectable choices. An unavailable encoder can still be selected,
  then shows its error inline, so a preset made on another PC stays editable.
- Show messages at the field they belong to (`field` in validation output), plus a
  summary list near the command. Clicking a summary item focuses its field.
- Show units and meaning: "CRF 18, visually lossless", "8 Mb/s average, 12 Mb/s peak",
  "2 s (60 frames at 29.97 fps)".
- **Keyframes** read out the interval the core emits (C2 `resolved.gopFrames`, after
  Extra arguments and fixed GOPs) at the delivered frame rate: "**2 s** (60 frames at
  29.97 fps)" for the seconds typed; "**120 frames** at 29.97 fps" when Extra arguments
  set `-g` or no seconds are typed; nothing when no interval is emitted (encoder
  default). The app never rounds seconds into frames itself. Keyframes has a row of its
  own in the Video panel so the read-out fits; Bit depth and Color tags each take the
  column's width.

Basic has no list of every FFmpeg option and no cross-setting search. The curated
controls cover the common settings; anything else goes in Extra arguments.

Profile-based encoders use the shared `VideoPanel` / `VeSelect` list in both the
desktop and VEGAS popup, rather than a row of truncated segments. ProRes keeps
the encoder name `prores_ks`. Its six profiles have full labels and short
descriptions in the list, paraphrased from [Apple](https://support.apple.com/en-us/102207)
and authored once in the core catalog. Profile IDs, encoding and input precision
are unchanged; format descriptions do not promise additional source color detail
or alpha. Keyboard selection, modified state and Reset use the existing controls.

### Extra arguments

- One field per stream, in a monospace font. It is the place for any option without a
  control.
- An option typed here replaces the generated option of the same name
  (SETTINGS_AND_COMMANDS §3), and the replaced control shows the note "Set in Extra
  arguments." under it, before the core's messages for that field. Which controls were
  replaced comes from the core (C2 `overriddenFields`); the app parses no option names.
  The control keeps its recipe value (it is only ignored by compile) and its Reset.
- Options are checked against the encoder's options parsed from the selected FFmpeg,
  plus the generic list. An unknown option shows a warning under the field: "-foo isn't
  an option of x264 in FFmpeg 8.1 full. FFmpeg stops with an error if it doesn't know
  an option." It never blocks saving.

### Size and quality (File node)

The estimate appears only in the File node's panel, never in the command column.

- **Length field.** The total is for a length the user types (m:ss or h:mm:ss).
  - Desktop: starts at the last length used, 10:00 the first time.
  - Popup: starts at the project length when VEGAS shares it with the native page
    (**gated** on A5); otherwise it is empty and says "Type a length".
- **Figures.** The total ("About 537 MB"), the rate per minute, and for quality modes a
  typical range. Bitrate modes give a plain figure. Every figure is the core's (see
  SETTINGS_AND_COMMANDS §7); the card works out none. With a typed length the range is
  the core's range for that length (C2 `minTotalBytes`/`maxTotalBytes`): "About 53.7 MB
  per minute. Typically 322 MB to 859 MB for 10:00." Without a length it is the core's
  range per minute: "About 53.7 MB per minute, typically 32.2 MB to 85.9 MB." When a
  length is typed but the core gives no total, the figure reads "Total not available
  yet".
- **No estimate.** When the core returns none (`available` false, for example filters
  or conflicting rate options in Extra arguments), the panel shows the core's
  explanation in place of the card ("No reliable size estimate for these Extra
  arguments.").
- **Split bar** for video and audio bitrate, then plain-language consequences of the
  rate mode and bit depth (from D5's card).
- **Advanced mode** shows no estimate: a custom command can do anything.
- **Learning from renders (v1+).** "Your last 5 renders with this preset averaged
  21 Mb/s" once History has data.

### Quality control

The quality control is a slider plus a numeric field, with labelled marks from the
encoder profile.

- **Right always means higher quality**, whatever the scale's direction (HandBrake's
  convention). Lower-is-better scales such as CRF, CQ and QP are drawn reversed: CRF 51
  at the left, 0 at the right. The ends read "Smaller file" and "Higher quality". The
  field shows the native value and unit name ("CRF 18").
- **v1 owner decision (2026-10-17):** keep the current numeric profile marks, with no
  additional shaded recommendation band. Curated quality recommendations are deferred.
- Arrow keys step by 1; Page Up and Page Down step by 5.
- Bitrate modes switch the control to Mb/s with common values (2 to 80 Mb/s; any value
  can be typed), and an optional peak. The read-out says "8 Mb/s average, 12 Mb/s
  peak", "no peak cap", or "8 Mb/s constant".

### Defaults, changes and reset

- "Default" means what the encoder would do with the chosen speed preset. It is not
  FFmpeg's global default (StaxRip's rule).
- Fields the user changed show a modified dot and a per-field reset.
- **Reset to preset** restores the loaded preset or revision.

### Test this preset

**Test this preset** is desktop-only in v1 (owner, 2026-10-17). It runs the selected
FFmpeg on 60 generated 320×180 P010 frames at 30 fps plus two seconds of stereo sine,
without starting a VEGAS render. Output goes to a temporary file, then through
ffprobe verification and a full synthetic-output decode. The log streams into a
panel. This is a lightweight check of those settings on that input; it does not
establish project-resolution or real VEGAS behavior.

This catches failing hardware encoders and bad extra arguments early. Voukoder Pro's
"Scene Test" is the precedent.

As built (desktop, on C3 `PresetTests`): a **Test** button beside the header's FFmpeg
picker (an icon below 1080 px) tests the editor's current settings, unsaved changes
included, with that FFmpeg. It is off, with the reason, without an FFmpeg, without a
command from the core, or with errors. A dialog shows the phase ("Encoding: frame 30 of
60"), a video-wire bar, the result ("Passed": "FFmpeg encoded the test frames and the file
checked out: h264 and aac."; "Failed" with the service's reason), the output check
(Expected / Found), and FFmpeg's output as it streams (last 400 lines, opening at the
end), with Show log, Show file, Stop test and Test again. Closing stops a running test.
The service retains the lightweight input instead of the project's size; no popup
Test action or project-sized test is required for v1. This resolves the old app
handoff's placement/input-size questions without increasing test resource use.

### Command preview

- Always reachable; visible by default on the desktop.
- `{inputs}` is collapsed into a "VEGAS video + audio" chip; it expands on click.
- Supports copy (Ctrl+Shift+C) and a toggle between single-line and grouped multi-line
  layouts ("One line" / "Grouped" beside Copy). In the multi-line layout each `^`
  continuation stays at the end of its line. A long line wraps only between arguments,
  never between an option and its value (`-profile:v high`), and its wrapped part is
  indented four spaces (two in the one-line layout) so it reads as a continuation.
- Figures carry a no-break space before their unit ("859 MB", "320 kb/s"), so no line
  wraps between them.
- The group for the selected node is highlighted. Clicking a token focuses the control
  that produced it; hovering or focusing a control highlights its tokens (StaxRip's
  click-to-jump). Both use the core's `CommandToken.field`; tokens an error issue points
  at (`tokenIndices`) are underlined in the error colour.
- Options replaced by Extra arguments show a small "Set in Extra arguments." note at
  their control (`overriddenFields`); in the command, the Extra tokens that replaced
  them are drawn in the Extra colour where Extra arguments put them.

## 3. Advanced mode (S2)

Built in F4 (desktop) on the native core; the popup reuses it in F5. Every highlight,
range, check, suggestion and expansion is the core's (C2): the app tokenizes nothing.

- The mode switch reads "Basic | Advanced"; **Ctrl+M** toggles it.
- **Switching to Advanced** follows SETTINGS_AND_COMMANDS §5. The first time, the command
  starts from the Basic settings (the core's `advancedTemplate`). The seed question
  appears only if a command already exists: "Use your saved command" (the default, last
  and focused), "Replace it with the current settings", or Cancel (Esc). The caret goes to
  the editor. **Back in Basic**, a banner says "Your command is saved. Renders use these
  settings until you switch back." with Switch to Advanced; it shows whenever a Basic
  preset keeps a command. Long dialog actions wrap to a second row.
- **Layout:** the dashed diagram, then the editor column (bar, editor, Diagnostics,
  Resolved command) beside a side column with "Switching back to Basic" (what renders in
  each mode, from the core's summary; Switch to Basic; Replace with Basic settings, with
  Undo) and the Macros panel.
- **Editor bar:** "FFmpeg command", then the message at the caret (or "{inputs} and
  {output} are locked."), "Line 3, column 12", and the Ctrl Space hint.
- **Highlighting** comes from the compile's token spans (`sourceStart`/`sourceEnd`).
  Option names are bold from C2 `isOption`; stage colours/stripes and embedded or
  quoted macro styling follow the core's `stage`/`macros` metadata. Missing metadata
  does not turn a leading dash into an option or invent a command stage.
- **Locked chips:** `{inputs}` and `{output}` (the core's `input`/`output` token spans)
  are drawn as chips with a lock badge at the top-right corner, kept inside the chip's
  line so it never covers the line above. The caret never rests inside one (a click goes to
  the nearer edge, an arrow step carries on). Typing inside or deleting part of a chip is
  refused with "{inputs} is locked. Vegas Encoder puts the VEGAS video and audio pipes
  here. Cut and paste moves it." and selects the chip, so a second Backspace deletes it
  whole; the lint then says what is missing. Cut, paste and whole deletion work.
- **Lint** (`VeCore.lint` with the chosen FFmpeg's capabilities, plus compile issues on
  the text that lint doesn't repeat, such as an out-of-range `{gop:Ns}`): errors are
  underlined red (wavy), warnings amber (wavy), hints dotted. Each line's number takes its
  most severe level's colour and its message is written after the line's end. Pointing at
  an underline shows a bubble; the caret's message shows in the bar. A finding whose range
  is the whole command (extra outputs) is listed, not underlined. An unterminated quote is
  underlined from the quote to the end.
- **Diagnostics** under the editor: counts ("1 error, 2 warnings, 1 hint, 1 note") and the
  FFmpeg checked; each finding with its icon, "Line N" and **Go to** (selects the range and
  focuses the editor); then whole-command findings; then the compile's recipe notes ("Not
  tested with VEGAS yet."). These are Advanced mode's Checks.
- **Autocomplete** (`VeCore.complete`): typing opens it after `-` (options of the encoders
  named in the command and FFmpeg's general options), after an option that takes values,
  and after `{` (macros). Ctrl+Space opens whatever the core offers at the caret. Arrows
  move; Tab or Enter inserts the entry and a space (an option with values then opens its
  values); Esc closes; a click inserts; moving the caret closes it. Entries show the value,
  description, type and default; encoders after `-c:v`/`-c:a` show Ready, Not in this
  FFmpeg or Failed test from the core. Header: "Options" or "Values for -tune" and where
  they come from; footer "Tab or Enter inserts".
- **Macros panel:** `VeCore.macros` supplies the catalogue, descriptions and values
  using the active recipe, media and paths (the desktop preview uses its labelled
  sample: "1920", "30000/1001", `{gop:2s}` "60"). Click to
  insert at the caret, with a space either side where needed. `{inputs}` and `{output}`
  say "Required, locked"; when the command has lost one it says "Required, missing:
  insert" and inserts.
- **Preview:** "Resolved command" (open on the desktop) shows the core's compile for the
  sample context laid out like the user's lines: what Vegas Encoder adds first, real pipe
  names, the output path and macros expanded (`{gop:2s}` → 60), errors underlined. Copy
  (and Ctrl+Shift+C) copies the core's command line. The output is the sample Render As
  path; the engine's temporary name isn't in C2 yet. Both this path and the diagram's
  File node use the active command's core-produced `outputExtension`; an unknown
  container leaves the sample extensionless, without borrowing the Basic suffix.
- **Signal path** (§2): dashed nodes from the core's facts for the active command only:
  the encoder and codec it names ("From command" when none), "From command, slow", the
  muxer `-f` names or "From file name" without one. Unknown formats claim no conversion,
  no wire label; availability uses only established summary encoder IDs, and unknown
  IDs show no availability. The wire keeps VEGAS's depth. Nodes open no settings;
  selecting one puts the caret in the editor.
- **No size estimate** in Advanced mode. The library row's **Advanced** tag leads its
  summary line ("[Advanced] x265, your command") and follows the draft.
- **Errors** block Apply in the popup (F5: Basic checks and Advanced lint). Desktop
  drafts may hold errors while you edit, but **a preset with errors isn't saved, and the
  app warns first** (owner decision, 2026-10-15). This covers Save, Duplicate, "Save all"
  when closing, and the popup's Save to library:
  - Errors in the settings themselves (the core's `validate`, with no FFmpeg): "Fix the
    errors before saving" lists them (the first three, then "and N more"). Show setting
    opens the first one; Keep editing (the default) closes the warning. Nothing is
    saved; the changes stay. On closing the window, it stays open on that preset. The
    library refuses these too (C3 `RECIPE-INVALID`), and its reason shows if a save
    reaches it anyway.
  - Errors only for the FFmpeg the checks are for (an encoder that FFmpeg lacks):
    "“Name” can’t render with FFmpeg X" explains that the settings are fine for another
    FFmpeg, with Save anyway or Cancel (the default). The library marks such a preset.

## 4. VEGAS popup (S3)

Built in F5 (`--edit-session <dir>`, C4) on the native core and the services; checked
with the platform's fake session only. The page in VEGAS that writes the request and
commits the result on VEGAS's own Apply/OK is B6 work behind A5–A7.

### Opening

- The app reads the session's `request.json` (C4) before the window shows, and the VEGAS
  dialog the request names (`ownerHwnd`) owns the window. It is centred on that dialog at
  the remembered physical outer size (or that monitor's DPI-scaled default), clamped
  to its work area and current minimum. Apply, Cancel and window close save only size
  through revision-checked settings writes; a settings failure never prevents closing.
- A request that is missing or can't be read: "Vegas Encoder couldn’t open this template:
  <reason>. Closing this window leaves the template as it was." Apply is off; closing
  writes nothing, which VEGAS treats as Cancel.
- Plug-in/app release or core-stamp mismatch shows a warning beneath the titlebar
  with the actual stamps and guidance to use one release. Missing stamps say the
  versions could not be verified. The warning does not disable Apply. It compares
  version stamps, not development-build hashes.
- Sessions carrying the native target show core admission errors before Apply and
  the active container's required Render As suffix in the footer. Actual destination
  is unknown here; no mismatch or automatic rename is inferred from the sample path.

### Header

- The template name. VEGAS has its own name field, so the line under it ends with
  "Rename in VEGAS to change the saved template name."
- The origin line, then **Load preset**, **Save to library ▾** and **Basic | Advanced**:

| Origin state | Line | Where its action is |
| --- | --- | --- |
| Unchanged from origin | From preset **X**, revision 5. | Load preset, Save to library |
| Local changes | From **X**, revision 5. 2 changes in this template (Show changes). | Show changes, in the line |
| Library is newer | (as above) and the side column: "Library has revision 6" | Update from library, in the side column |
| Origin deleted | Preset **X** no longer exists in your library. This template still has all its settings. | Save as new preset…, in the side column and the menu |
| No origin | Made in VEGAS. | Save to library |
| Library unreadable | From **X**, revision 5. The library couldn’t be read: <reason>. | — |

The count of changes is the core's diff from the origin revision's own settings (C2
`diff`). Without a copy of that revision (`baseRecipe` null) the line gives no count.
Switching mode or editing the command counts as a change.

### Signal path

- The one-row strip. A dot marks each node this template changed from its origin
  revision; "Rev. 6" marks each node the library changed since. Both come from the core's
  diff.
- **From VEGAS** shows the project's facts from the request ("3840×2160", "29.97 fps,
  10-bit", "48 kHz float"). When VEGAS didn't share them, the node reads "Set by project",
  "Sample: 29.97 fps" and "Sample: 48 kHz float", and its panel says "Set by the project"
  for each fact: "VEGAS didn’t share this project’s settings. The command and checks use a
  sample: 1920×1080, 29.97 fps, 48 kHz stereo."
- The panels are the desktop's, without the fields' explanations. Reset goes back to the
  template as it opened. Checks are for the default FFmpeg, from what was last checked
  (the popup never runs a check). The File node starts with the project's length when
  VEGAS shared it; it never changes the desktop's remembered length.

### Side column

- **Library**: "Library has revision 6" (amber) with "The library changed “X” after
  revision 5." and **Update from library**; "Not in the library" with **Save as new
  preset…**; "Made in VEGAS. Save it to the library to use it in other templates.";
  otherwise "Up to date with the library preset." **Open in Vegas Encoder** opens the
  desktop app on the origin preset, for library work. It starts or hands off to the
  desktop in the same data profile; a removed preset or failed launch is explained.
- **Command** and **Checks**, as on the desktop (Basic). In Advanced mode: "N diagnostics.
  Edit it below the diagram."
- Below 1040 px the side column is the collapsible "Library and command" strip (§1).

### Show changes

A dialog, "Changes in this template": "What this template changed from “X”, revision 5."
and a table Setting | Rev. 5 | This template ("Quality | CRF 18 | **CRF 17**").

### Update from library dialog

The dialog has two lists, each a table of the settings the core's diff names:

- **Changes in the library since revision 5** (what you get): Setting | Rev. 5 | Rev. 6.
- **Your changes in this template** (what you lose if you replace): Setting | Rev. 5 | This
  template, or "None."

Actions:

- **Replace with revision 6** (the default): the library's settings; the template keeps
  its name.
- **Take library changes, keep mine**: each setting the library changed takes the
  library's value; the template's own changes stay. Enabled only when no setting is in
  both lists; otherwise disabled with "Some settings changed in both places."
- **Cancel**

Either one makes revision 6 the origin and shows an Undo bar ("Replaced with revision 6.",
"Took the revision 6 changes and kept yours."). Without a copy of revision 5 there is no
three-way choice: the dialog says "This template doesn’t carry a copy of revision 5, so
its own changes can’t be told apart from the library’s. Replacing takes all of revision
6.", lists "This template and revision 6", and offers only Replace and Cancel.

### Load preset

A list of the library's presets (Built-in, then Mine), each with its encoders ("x264,
AAC") or what it needs on this PC, and the footnote "Loading replaces the template’s
settings right away. You can undo it." Choosing a preset replaces the template's settings
**immediately**; the template keeps its name and the preset becomes its origin. An Undo
bar ("Loaded “Lossless master, FFV1”. Undo") stays 8 seconds. There is no separate "apply
the preset" step. Voukoder Classic's preset-then-Apply confused users.

### Save to library

A menu under **Save to library ▾**:

- **Save as new preset…** "Adds it to Mine." Asks for a name (the template's name to
  start), saves the template's settings as a new preset and makes it the origin.
- **Update “X” (revision 5 → 7)**: the preset takes the template's settings at the
  library's next revision and keeps its own name. Disabled for built-in origins
  ("Built-in presets can’t be changed.") and when the template has no preset in the
  library.

### Footer and closing

- Note: "Apply updates this render template. Save it in VEGAS to keep it for next time."
  When Apply is off, the note gives the reason instead: "Fix the errors first. The
  template can’t render with them." (Basic checks and Advanced lint), or that the core
  couldn't check the settings.
- **Cancel** (Esc), the title bar's close (×, labelled Cancel), Alt+F4 and the taskbar ask
  only if something changed: "Discard changes to this template?" with **Keep editing** and
  **Discard changes**. Discarding writes a cancel result and closes.
- **Apply to template** (Ctrl+Enter) writes the complete settings and their origin as the
  session's result and closes. One final result per session. If it can't be written, the
  reason shows and the popup stays open.
- VEGAS changes the template only on its own Apply/OK (TECH_ARCHITECTURE §5.2).

### Advanced mode

Ctrl+M or the switch, with the desktop's question when a command is already saved. The
editor, Diagnostics and **Resolved command** (closed to start) sit under the strip; there
is no Macros panel or "Switching back" card (macros come from autocomplete after "{").
Lint errors turn Apply off.
## 5. FFmpeg screen (S4)

| State | Display |
| --- | --- |
| Probing | Per-installation progress ("Reading encoders… 18 of 25"); results stream in |
| Ready | Version, build, license class, source, path (copyable), probe time, ffprobe present |
| Changed on disk | "This FFmpeg changed since it was checked." **Scan again** |
| Missing | "C:\ffmpeg\bin\ffmpeg.exe isn't there any more." **Remove** / **Locate…** |
| No ffprobe | "ffprobe.exe must be next to ffmpeg.exe so renders can be checked." |
| Hardware test failed | Encoder row shows **Failed test on this PC**, the reason, and the raw stderr line on expand |
| LGPL build | License class "LGPL: no x264/x265"; affected presets are listed |

The capability list is grouped by codec family, with a filter ("Only usable", "Hardware", "Search").

**Built in F3** (`app/lib/features/ffmpeg/`, on the platform fakes):

- **Header:** Add FFmpeg… (the Windows Open dialog through the runner's `pickFile`; the
  path goes to `FFmpegDiscovery.add`), Scan again (`scan`, then a probe of each
  installation with no cached capabilities), Test hardware encoders (the selected
  installation, `force: true`). A refusal shows as a toast with discovery's message.
- **Cards** on dotted paper, three across, more scroll sideways: name, Default, build,
  license and source ("Installed with winget"), the path (tooltip with ffmpeg.exe and
  ffprobe.exe), when it was checked, encoder and muxer counts, and "Can't render 1
  preset: needs x264" (tooltip lists the presets). A running probe replaces the
  checked line with its phase and count and a bar; a failed probe says why. Every card
  has Set as default (not on the default), Copy path and Remove… (not on the default:
  choose another default first); keeping them on every card keeps the strip's height
  steady.
- **Installations and the default** live in C7: Scan again, Add and Remove write
  discovery's list to `machine.json` (skipped when unchanged), and a default that
  discovery no longer lists keeps its record rather than switching to another
  installation. Set as default saves `defaultFFmpegId` through
  `save(expectedRevision)`, reapplied on a revision conflict.
- **Capability list:** Video / Audio encoders, All / Only problems / Hardware (video
  only), a search over name, FFmpeg name, codec, group and device (Ctrl+F), and a
  summary ("FFmpeg 8.0 LGPL: 4 video and 1 audio encoders not ready"). Columns: codec,
  encoder, FFmpeg name, bit depth, runs on (the device a passed test ran on), state,
  reason; under 760 px the FFmpeg name and reason give way to the detail panel. A click
  or focus selects a row; Up and Down move.
- **States:** Ready, Not in this FFmpeg, Failed test on this PC, Testing…, and Not
  checked yet (C3 `unknown`). The newest fact wins: a test running now, this session's
  test result, this session's probe, then the installation's recorded availability.
- **Detail** (450 px, 380 px below 1240 px): name, state, what it means and what to do,
  the test failure class and 10-bit result, the test-encode diagram (testsrc2 → encoder
  → null, dashed past an encoder that can't run), FFmpeg's stderr line, the presets that
  use it (click opens the preset in Presets), and Test again for hardware encoders.
- **Health** (C3 `health`, follow-ups 2026-10-15): Changed on disk, Missing and No ffprobe
  show on the card as the table above says, with an amber or red icon, the service's
  `healthMessage` in the tooltip, and the fix as the card's first action: Scan again
  (changed, no ffprobe) or Locate… (missing: the Open dialog, then discovery adds the file
  chosen; a missing default hands its role to it). A missing default says "Renders fail
  until you locate it or choose another default." `unknown` and `unchanged` show nothing.

## 6. History screen (S5)

- **List:** status, time, project, template, encoder, duration, elapsed time, speed
  (× realtime), size. Filter by status.
- **Detail:**
  - result sentence ("Rendered 12:43 in 24:46, 0.51× realtime, 9.84 GB");
  - FFmpeg identity;
  - the command, with error tokens highlighted when FFmpeg names an option;
  - stderr tail and full log;
  - output verification result.
- **Actions:** Open folder, Copy command, Open settings as new preset.

**Built in F3** (`app/lib/features/history/`, on the platform fakes). There is no S5
mock; History uses S4's layout: the list on surface at the left, a 450 px detail on
panel at the right (380 px below 1280 px).

- **List** (from the index only since the follow-ups, 2026-10-15; no record per row):
  status with icon and word; start time (local); template over project; encoder (the
  engine's summary, "x264 CRF 18, slow / AAC 320 kb/s", full text in a tooltip); length;
  time taken; speed from the index's recorded `realtime`; size ("No file" when nothing
  was published). A summary an older index line lacks shows a dash; speed is never
  derived from length/time. Filter: All / Succeeded / Failed / Cancelled, with a
  count. Below 860 px the length, time-taken and speed columns drop.
- **Detail order:** result sentence; actions; FFmpeg said (stderr tail); how it stopped
  (exit code, HRESULT); output path; FFmpeg identity (shortened hash, full value in a
  tooltip); output check; the command, with the arguments FFmpeg's error points at
  (C6 `errorTokenIndices`) underlined in the error colours and "FFmpeg's error points at
  “-preset 14”, underlined above."; then **FFmpeg log**: Show log reads the whole log
  (C3 `JobLogs`) as it streams and shows its last 1,000 lines in a box that opens at the
  end ("The last 1,000 of 12,345 lines."), Show in folder for the file; "FFmpeg left no
  log for this render." when there is none.
- **Actions:** Copy command (also Ctrl+Shift+C) copies the core's recorded command line;
  Open settings as new preset makes a Mine preset and switches to Presets; Open folder
  shows the published file in Explorer (else a kept unfinished file; off with "This render
  left no file to show." otherwise).
- **Keyboard:** Up and Down move the selection and focus. An empty history and a filter
  with no matches each have their own message; a missing or unreadable record says so
  in its row and in the detail.

## 6a. Settings screen

**Implemented (2026-10-18): VEGAS installation/status dashboard.**
The read-only VEGAS integration card follows Rendering. Hosts and exporter files
are inspected through ve_services and its native Windows service DLL on a worker
isolate; widgets do not access registration/files. No PowerShell or inspected
host/exporter process is started. The contract is in CONTRACTS C3.

- Show each detected host's name, actual version and executable path, plus the
  exporter/discovery paths checked and the actual DLL version when readable.
- Distinguish **Not installed**, **Installed, verified**, **Installed, unverified**
  (missing/unsupported manifest), **Files missing or changed**, and **Could not
  check**. Show the relevant manifest path and concrete error/detail. Only say
  verified for bytes/paths actually covered by the supported installed manifest;
  version equality is not an integrity check. Unknown app/shared-runtime coverage
  stays unknown rather than implying a whole installation was verified.
- Keep supported/tested host scope separate from detection and file integrity;
  finding an older VEGAS executable does not establish compatibility.
- Include explicit Refresh and readable loading, empty and partial-error states.
  An unreadable host/manifest must not prevent other rows from being shown.
  Refresh hides old verification claims while checking; a failed scan remains
  visible until explicit Refresh (no automatic retry). Each row offers Show/Hide
  paths and details, with selectable full paths and concrete verification errors.
- This section reports status and gives installer guidance. No install, repair,
  uninstall, download or automatic replacement action is part of this task. The
  owner builds the installer; support current recorded manifests and show other
  formats as unverified without inventing that installer's future schema.

Scope/test details are in NEXT_AGENT. Other unfinished Settings/log-management
and expanded About features are skipped; the existing cards below remain.

Built in F3 (`app/lib/features/settings/`). Settings (Ctrl+4) is one centred column,
at most 720 px wide, of surface cards. Every control saves at once to C7 `machine.json`
through `MachineSettingsRepository.save(expectedRevision)`; a revision conflict is read
again and reapplied, and a change saved elsewhere shows live. A failed save says so in a
toast.

- **Appearance:** Theme (Follow Windows / Light / Dark); the editor that opens from VEGAS
  uses the same choice.
- **FFmpeg:** Default FFmpeg, a list of the registered installations with the path under
  it, plus Manage installations (opens FFmpeg). With none registered it warns that
  renders need one and offers "Open the FFmpeg page". A default that names a missing
  installation is an error, never a quiet switch to another one.
- **Rendering:** show a progress window, keep it on top (off by default, disabled while
  the progress window is off, the same setting as the window's pin), and check each file
  after rendering. A note says VEGAS reads these when a render starts.
- **About:** app, core version (marked "preview core (fake)" for the fake), recipe schema
  and contracts, and whether the services are the platform's sample fakes.

## 7. Keyboard

| Keys | Action | Where |
| --- | --- | --- |
| Ctrl+K | Open preset… (palette) | Desktop |
| Ctrl+F | Search the library; on FFmpeg, search the encoders | Desktop |
| Ctrl+S | Save preset | Desktop |
| Ctrl+Enter | Apply to template (when Apply is off, says why and writes nothing) | Popup |
| Esc | Cancel (asks first when something changed); closes an open popover, dialog or suggestions first | Popup, popovers |
| Ctrl+Shift+C | Copy command | Everywhere |
| Ctrl+M | Switch Basic / Advanced | Editor, popup |
| Ctrl+Space | Suggestions at the caret | Advanced editor |
| Arrows, Tab / Enter, Esc | Move, insert, close the suggestions | Advanced editor, while open |
| Arrow keys | Move between signal path nodes | Diagram |
| Ctrl+1…4 | Presets, FFmpeg, History, Settings | Desktop |
| F6 / Shift+F6 | Move between panes | Desktop |

All controls are reachable by Tab, with a visible focus ring (2 px, contrast ≥ 3:1).
Sliders support arrows, Page Up/Down, and Home/End.

## 8. Copy rules (in addition to the brief)

- Use the same name for an action throughout. "Apply to template" in the button
  becomes "Applied to template" in the confirmation.
- Messages state the consequence and the fix. Never say "invalid" without naming what
  is invalid and what is valid.
- Numbers carry units and meaning: "60 frames (2 s at 29.97 fps)".
- Quote paths exactly; never abbreviate them in messages (truncate visually with a tooltip).

## 9. Accessibility

- Text contrast ≥ 4.5:1 (body) and ≥ 3:1 (large text, UI glyphs). Validation colour is
  always paired with an icon and text.
- Flutter `Semantics` labels on custom controls: slider (value plus meaning), chips,
  and signal path nodes (role, name, state, and "Show size and quality" on File).
- Contrast is checked in both themes (`app/test/unit/tokens_test.dart`). The dark set
  passes everywhere. Measured shortfalls of the light set, kept as the mockup has them
  (owner accepted, 2026-10-12):
  - `muted` on `paper` is 4.39:1, so the app never puts muted text on paper (it uses
    `text2` there);
  - `faintText` is 3.4–3.7:1; it is used for placeholders and slider tick numbers;
  - `pip` on `paper` is 2.0:1; every pip carries a text label;
  - control borders (`line2`) are 1.6–1.7:1 in both themes, under the 3:1 guideline for
    component boundaries.
- Reduced motion (Windows "Animation effects" off) disables decorative transitions.
  State changes still update instantly. The runner reads `SPI_GETCLIENTAREAANIMATION`
  and reports changes; the app sets `MediaQuery.disableAnimations`, and every
  duration goes through `VeTokens.motion`.
- Text scales up to 150% without clipping, within each window's minimum size. The
  diagram's height and node heights follow the text scale (F2); node widths stay so the
  wire labels keep their room, and node text that doesn't fit ends in an ellipsis. The
  header grows too.

## 10. Design tokens (Flutter `ThemeExtension`)

The light and dark values are the `:root` token sets in
[design/signal-flow.html](design/signal-flow.html), implemented in `app/lib/design/`
(built in F1):

```dart
// palette.dart: every CSS token by name, light and dark (presentation-only
// --canvas and --pres-muted left out). CSS name → Dart field, for example:
//   --paper paper, --surface surface, --surface-2 surface2, --panel panel,
//   --ink ink, --text2 text2, --muted muted, --nd-text nodeText, --faint-text faintText,
//   --line line, --line2 line2, --fill fill, --fill-sel fillSelected, --lit lit,
//   --vw videoWire, --vw-text videoText, --aw audioWire, --cont containerWire, --pip pip,
//   --err error, --errbg errorBackground, --warnt warning, --ok success, --macro macro,
//   --vwl videoTint, --awl audioTint, --contl containerTint, --sel selection, --shadow-rgb shadow
class VePalette { /* 57 colours, light and dark constants, lerp */
  // UI_SPEC role names, as getters:
  Color get roleInput, roleVideo, roleAudio, roleContainer, roleOutput, roleExtra, focus;
}

// tokens.dart
class VeTokens extends ThemeExtension<VeTokens> {
  final Brightness brightness;
  final VePalette colors;
  final VeTextStyles text; // body 13, small 12.5, caption 12, micro 11.5, label, button,
                           // panelTitle 15, popupTitle 18, pageTitle 19, headline 22,
                           // nodeTitle 17, figure 26, display 34, mono 12.5/1.7, monoEditor 14/23
  List<BoxShadow> get raisedShadow, restingShadow, segmentShadow, popoverShadow, toastShadow;
  static Duration motion(BuildContext, Duration); // zero when reduced motion
}
abstract final class VeSpace { s1..s6 = 4, 8, 12, 16, 24, 32 }
abstract final class VeRadius { xs 3, sm 5, md 6, lg 8, xl 10 }
abstract final class VeDurations { short 150 ms, medium 300 ms, wire 400 ms, wireCurve }
```

- Role colours are used consistently across the command preview, node stripes and
  diagram wires. Signal Flow adds `pip` (conversion marker) and the wire widths
  (video 10/4 px for 10-bit/8-bit; audio 6/5/2.5 px for float/24/16-bit; ×0.6 in the
  strip).
- `VeTokens.light` and `VeTokens.dark` are both registered; `ThemeMode` follows the
  setting in §1. `ThemeData.platform` is fixed to Windows.
- Fonts: Instrument Sans (UI) and JetBrains Mono (commands), OFL, bundled as the
  upstream variable fonts (`app/assets/fonts/README.md`). Flutter maps `FontWeight` to
  the `wght` axis, so the mockup's 550/620/650 weights are exact. Not subset yet: the
  start-time measurement does not need it (see `workstreams/app.md`).
- Components are Vegas Encoder's own, built on Flutter's base widgets, not the Material
  look. Material is used only for `ThemeData`, `TextField` internals and tooltips, all
  themed from the tokens. No headless kit.

## 11. Component inventory (Flutter)

Built in F1 (`app/lib/design/components/`), with sample data in the design-system
gallery and goldens in both themes: `VeButton`, `VeIconButton`, `VeLinkButton`, `VeKbd`,
`VeTextField`, `VeNumberField`, `VeSegmented`, `VeSwitch`, `VeSlider`, `VeSelect`,
`VePopover`/`VeListbox`, `VeStatusTag`, `VeField`/`VeReadout` (with the modified dot and
Reset since F2), `VeTitleBar`, and the rows marked F1 below. F2 added `showVeDialog`
and `showVeTextDialog` (modal questions and names), `VeToast` (confirmations, with
Undo), and in `features/presets/`: the Ctrl+K palette, `BitrateField`, and
`FieldAnchor` (how "Show setting" finds a field's control). Components take display models; values come from `ve_core` and
`ve_services` through the app state, never computed in the design layer.

| Component | Notes |
| --- | --- |
| `EncoderPicker` | F1 (`VeEncoderPicker`). Grouped by codec; hardware vendor; availability state with reason; search still to come |
| `RateModeSwitch` | F1 as `VeSegmented`. Segmented; only the encoder's modes |
| `QualityControl` | F1 (`VeQualityControl`): slider, field and numeric profile marks; no extra recommended band in v1 (owner, 2026-10-17). Bitrate and profile-steps variants in F2 |
| `SignalPath` | F1. Full and strip layouts; nodes, wires sized by bit depth, conversion pips, marks; keyboard navigation (`CustomPainter` for wires) |
| `ExtraArgumentsField` | F2 (`features/presets/panels/extra_field.dart`): mono field per stream; the core's warnings for the field show under it |
| `CommandView` | F1. Tokens with roles; collapsed inputs chip; copy; multi-line |
| `CommandEditor` | F4 (`design/components/command_editor.dart`): `EditableText` with the selection gestures, `buildTextSpan` highlighting from a display model, painted locked chips, gutter, per-line messages and hover bubbles, the chip guard, the autocomplete overlay. The Advanced feature (`features/advanced/`) maps the core's results onto it |
| `MessageList` / `InlineMessage` | F1 (`VeCheckList`, `VeMessage`). Levels, field focus |
| `SizeQualityCard` | F1, reworked in F2 to take the core's figures (per minute, total for the typed length, range). Length field; video/audio split; consequences |
| `OriginBanner` | Popup origin states and actions |
| `DiffList` | Field label, from → to |
| `InstallationCard`, `CapabilityTable` | F3 (`features/ffmpeg/`), with `EncoderDetail` and its test-encode diagram |
| `JobList`, `JobDetail`, `LogView` | F3 (`features/history/`); the stderr tail and, since the follow-ups, the full log's last lines (`_FullLog`) show in the detail |
| `VePageHeader`, `VeToastHost` | F3 (`design/components/page_header.dart`): a section's heading and actions; one toast per screen |
| `RenderMonitor` | F6 (`features/monitor/`, `state/monitor.dart`): the progress window (§12). `VeWireProgress` (`design/components/wire_progress.dart`) is its bar |

## 12. Render progress window

Mock: S6 in [design/signal-flow.html](design/signal-flow.html). Architecture and the
performance rule: TECH_ARCHITECTURE §5.6. Built in F6; as built:

| Item | Behaviour |
| --- | --- |
| Size | 380×340 (the mockup's content; the earlier "about 380×250" didn't fit it); not resizable; 16 px in from the bottom-right corner of the work area of the monitor VEGAS's main window is on (C5 `hostHwnd`), at that monitor's DPI. Without a usable handle: the foreground window's monitor |
| Showing | Appears when a render starts **without taking focus**, and a click on it doesn't take it either. Keep on top is a pin in the title bar, remembered in C7 `keepOnTop` (the same setting as in Settings) and applied before the first frame; **off by default** (owner, 2026-10-12). Mockup S6 shows it pinned |
| Title | "Rendering, 42%"; "Starting the render", "Finishing the file", "Checking the output"; "Rendered", "Render failed", "Render cancelled"; "Waiting for the render" until the file appears |
| Header | Output file name, then the encoder summary as the engine writes it; the folder once done. A wire glyph shows known C5 encoder-input depth, with an amber pip only for explicit precision reduction. Unknown conversion has a gap and explanatory tooltip/semantics; unknown depth omits the glyph. These are compiled input facts before codec compression, not measured file precision |
| Progress | A video-wire bar with a round head; percentage (rounded down, so 100% means every frame went to FFmpeg) and "Frame 9,607 of 22,873". With no total: no fill, "Rendering", "Frame 9,607" |
| Figures | Encoding fps, speed (× realtime), bitrate, size so far, final size ("about"; the engine's estimate, `estimatedFinalBytes`) and time left with the total. A figure the engine hasn't written shows a dash; the app computes none of them |
| Finishing | "Finishing" then "Checking", with the frame count. The engine doesn't say whether a fast-start index is being written, so the window doesn't either |
| Done | The result sentence as in History, plus the output check: "Rendered 12:43 in 4:07, 3.09× realtime, 2.93 GB. Output checked: h264 and aac, as set." (from the job record, C6). Without the record, "Rendered in 4:07, 2.06× realtime." **Open folder** (Explorer, file selected) and **Close**. "Closes in 10 s", counting; while the pointer is over the window, "Stays open while the pointer is here", and the count resumes when it leaves |
| Failed | A prominent error-coloured **Why it failed** panel with the engine's causal message (for example, "FFmpeg: No such filter: '…'"). Shows C5 immediately, then the matching C6 message when available; never infers a cause from stderr or replaces it with trailing warnings. Long messages scroll from the beginning without truncation. **Show in History** opens the desktop app on that job; launch errors appear separately from the render cause. **Show log** reveals the full FFmpeg log in Explorer (disabled when unavailable). **Close** dismisses the window. Explicitly says **Stays open until you close it**; a failure cancels any existing auto-close countdown (owner, 2026-10-16) |
| Cancelled | "Cancelled in VEGAS after 1:12."; closes after 5 s, with the same pointer rule |
| No news | While starting or encoding, 30 s without a new status: the footer says "No news from the render for 30 s. If VEGAS stopped, close this." It never ends the render or closes the window; a new status clears it. Not shown while checking the output (ffprobe can take minutes) |
| Cancel | Not offered: rendering is cancelled in VEGAS's own dialog, and the footer says so |
| Updates | Redraws only when the status changes (ordinary samples at most five times a second, phase changes immediate); no animation beyond the bar moving. Reduced motion changes nothing else. Real-host cadence/overhead remain unqualified |
| Reading | While VEGAS renders it reads the live file and machine settings only: no core, no library. After the end it reads the job record, which loads the core |

B5's outcome: the owner dropped custom text in VEGAS's render dialog, so this window
is the only place the encode statistics show.
