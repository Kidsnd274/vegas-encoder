# UI behaviour specification

Updated: 2026-10-12 (Asia/Singapore). Status: proposal, updated for the chosen
direction; §1, §9, §10 and §11 record what the app workstream built in F0 and F1, and
§2 what F2 built (on the platform fakes; open items are in workstreams/app.md).

This document covers the behaviour Flutter will implement: states, flows, the signal
path, the size card, theme, keyboard, copy and the token structure. The chosen
direction is Signal Flow, round 2 ([design/signal-flow.html](design/signal-flow.html)).
The vocabulary is fixed in the brief §2.

## 1. Windows

| Window | Default | Minimum | Notes |
| --- | --- | --- | --- |
| Desktop app | 1440×900 | 1100×700 | Remembers size and position; single instance |
| Popup editor | 1120×740 | 960×640 | Centred on its VEGAS owner; resizable; remembers size, not position |
| Native page | Host-defined | — | Win32 inside VEGAS; see the mock |

Below 1280 px width the desktop app collapses the library to an icon rail, and the
popup moves the command preview into a collapsible bottom strip.

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
  presets only), Show in folder.
- **Empty search:** "No presets match 'xyz'." plus a **New preset** action.

### Editor states

| State | Trigger | Behaviour |
| --- | --- | --- |
| Clean | Loaded or just saved | Save disabled |
| Dirty | Any change | Title shows "Edited" and the library row a dot; Save, Revert (with Undo) enabled. Other presets can be opened meanwhile; each keeps its changes. Closing the window asks "Save changes to '<name>'?" (Save / Don't save / Cancel), or "Save changes to N presets?" (Save all) |
| Built-in | Built-in preset selected | Editing allowed as a draft; Save becomes **Save as new preset**; a note says "Built-in presets can't be changed. Your changes will be saved as a new preset." |
| Errors | Validation has errors | Save still allowed (presets can be work in progress); the preset shows an error mark in the library |
| Updated elsewhere | File changed by the popup or another window | Banner: "This preset changed in another window." **Reload** / **Keep editing** (save then asks to overwrite or save as new) |

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
  open settings; clicking one focuses the editor.
- **Audio off** leaves a dashed audio node ("Audio is off. The file has video only.").
  It still opens the audio settings, where audio is turned back on.
- **Only the core's facts.** Pips, notes and depths come from the core's compile result.
  When the core gives none (an edit beyond the B0 fake core), the wire keeps VEGAS's
  depth and claims neither a pip nor "No conversion".

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

Basic has no list of every FFmpeg option and no cross-setting search. The curated
controls cover the common settings; anything else goes in Extra arguments.

### Extra arguments

- One field per stream, in a monospace font. It is the place for any option without a
  control.
- An option typed here replaces the generated option of the same name
  (SETTINGS_AND_COMMANDS §3), and the replaced control shows "set in Extra arguments".
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
  SETTINGS_AND_COMMANDS §7); the card works out none. Until the core gives the range
  for a typed length, the range is per minute: "About 53.7 MB per minute, typically
  32.2 MB to 85.9 MB." When a length is typed but the core gives no total, the figure
  reads "Total not available yet".
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
- Mark a recommended band per resolution where the encoder profile provides one (for
  example x264 CRF 18–23 at 1080p).
- Arrow keys step by 1; Page Up and Page Down step by 5.
- Bitrate modes switch the control to Mb/s or kb/s with common values, and an
  optional peak.

### Defaults, changes and reset

- "Default" means what the encoder would do with the chosen speed preset. It is not
  FFmpeg's global default (StaxRip's rule).
- Fields the user changed show a modified dot and a per-field reset.
- **Reset to preset** restores the loaded preset or revision.

### Test this preset

**Test this preset** (desktop and popup) runs the selected FFmpeg on synthetic frames,
without starting a VEGAS render. The input is `lavfi` testsrc2 plus a sine tone, at the
sample or project context's size, rate and pixel format, for 60 frames. Output goes to
a temp file, then through the same ffprobe verification as a render. The log streams
into a panel.

This catches failing hardware encoders and bad extra arguments early. Voukoder Pro's
"Scene Test" is the precedent.

### Command preview

- Always reachable; visible by default on the desktop.
- `{inputs}` is collapsed into a "VEGAS video + audio" chip; it expands on click.
- Supports copy (Ctrl+Shift+C) and a toggle between single-line and grouped multi-line
  layouts. In the multi-line layout each `^` continuation stays at the end of its line.
- The group for the selected node is highlighted. Clicking a token focuses the control
  that produced it; hovering a control highlights its tokens (StaxRip's click-to-jump).
- Options replaced by Extra arguments show a small "set in Extra arguments" note at
  their control.

## 3. Advanced mode (S2)

- The mode switch reads "Basic | Advanced".
- **Switching to Advanced** follows SETTINGS_AND_COMMANDS §5. The seed question appears
  only if a template already exists.
- **Locked chips:** `{inputs}` and `{output}` are inline chips. They can be moved with
  cut and paste. They cannot be edited internally; deleting one shows its lint error.
- **Lint:** errors are underlined red, warnings amber, hints dotted. Hover or caret
  shows the message. A diagnostics list sits under the editor with "Go to" for each.
- **Autocomplete:** opens after `-` or after an option that takes values. Tab or Enter
  accepts; Esc closes. Ctrl+Space opens it manually. Entries show type, default and
  description, and are filtered by the selected FFmpeg's real options. It is built
  last in P3: the data is the same parsed option list lint already uses, so the cost is
  the popover (caret placement, keyboard and focus). If it slips, Advanced mode ships
  with highlighting, lint and the macros panel.
- **Macros panel:** lists the macros with descriptions. Click to insert at the caret.
- **Preview:** a "Resolved command" toggle shows the expanded result for the current
  context: real pipe names, temp output, and `{gop:2s}` → 60.
- **Errors** block Save in the popup (Apply) and are allowed in desktop drafts (marked).

## 4. VEGAS popup (S3)

### Header

- Template name (editable; VEGAS also has its own name field, so a hint says
  "Rename in VEGAS to change the saved template name").
- **From VEGAS** facts, shown in the strip's first node.
- Origin line:

| Origin state | Line | Actions |
| --- | --- | --- |
| Unchanged from origin | From preset **X**, revision 5 | Load preset, Save to library |
| Local changes | From **X**, revision 5. 2 changes in this template. | + Show changes |
| Library is newer | Library has revision 6 | + Update from library |
| Origin deleted | Preset **X** no longer exists in your library. This template still has all its settings. | Save to library (as new) |
| No origin | Made in VEGAS | Save to library |

### Update from library dialog

The dialog has two lists:

- **Changes in the library since revision 5** (what you get).
- **Your changes in this template** (what you lose if you replace).

Actions:

- **Replace with revision 6**
- **Take library changes, keep mine** (enabled only when no field appears in both lists)
- **Cancel**

### Load preset

Choosing a preset replaces the template's settings **immediately**, with an Undo bar
("Loaded 'Client review, 1080p 8 Mbps'. Undo"). There is no separate "apply the preset"
step. Voukoder Classic's preset-then-Apply confused users.

**Open in Vegas Encoder** opens the desktop app on the origin preset, for library work.

### Footer

- **Cancel** (Esc). Asks only if there are changes: "Discard changes to this template?"
- **Apply to template** (Ctrl+Enter). Disabled with a reason when errors exist.
- Note: "Apply updates this render template. Save it in VEGAS to keep it for next time."

**Save to library** (split button): "Save as new preset…" or "Update '<origin>'
(revision 5 → 7)". The second is disabled for built-in origins.

**Close (×)** behaves as Cancel, with the same question.

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

## 7. Keyboard

| Keys | Action | Where |
| --- | --- | --- |
| Ctrl+K | Open preset… (palette) | Desktop |
| Ctrl+F | Search the library | Desktop |
| Ctrl+S | Save preset | Desktop |
| Ctrl+Enter | Apply to template | Popup |
| Esc | Cancel / close popover | Popup, popovers |
| Ctrl+Shift+C | Copy command | Everywhere |
| Ctrl+M | Switch Basic / Advanced | Editor |
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
- Text scales up to 150% without clipping, within each window's minimum size. Known
  gap: signal path nodes have fixed sizes from the mockup, so their text clips at large
  scales (F2 sizes the diagram from the text scale).

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
and `showVeTextDialog` (modal questions and names) and `VeToast` (confirmations, with
Undo). Components take display models; values come from `ve_core` and
`ve_services` through the app state, never computed in the design layer.

| Component | Notes |
| --- | --- |
| `EncoderPicker` | F1 (`VeEncoderPicker`). Grouped by codec; hardware vendor; availability state with reason; search still to come |
| `RateModeSwitch` | F1 as `VeSegmented`. Segmented; only the encoder's modes |
| `QualityControl` | F1 (`VeQualityControl`): slider, field, marks, recommended band. Bitrate and profile-steps variants in F2 |
| `SignalPath` | F1. Full and strip layouts; nodes, wires sized by bit depth, conversion pips, marks; keyboard navigation (`CustomPainter` for wires) |
| `ExtraArgumentsField` | F2 (`features/presets/panels/extra_field.dart`): mono field per stream; the core's warnings for the field show under it |
| `CommandView` | F1. Tokens with roles; collapsed inputs chip; copy; multi-line |
| `CommandEditor` | `TextEditingController.buildTextSpan` highlighting, macro chips, lint underlines; autocomplete overlay last |
| `MessageList` / `InlineMessage` | F1 (`VeCheckList`, `VeMessage`). Levels, field focus |
| `SizeQualityCard` | F1, reworked in F2 to take the core's figures (per minute, total for the typed length, range). Length field; video/audio split; consequences |
| `OriginBanner` | Popup origin states and actions |
| `DiffList` | Field label, from → to |
| `InstallationCard`, `CapabilityTable` | FFmpeg screen |
| `JobList`, `JobDetail`, `LogView` | History |
| `RenderMonitor` | Progress window (§12): wire progress bar, figures, done and failed states; reads the live status file through `ve_services` |

## 12. Render progress window

Mock: S6 in [design/signal-flow.html](design/signal-flow.html). Architecture and the
performance rule: TECH_ARCHITECTURE §5.6.

| Item | Behaviour |
| --- | --- |
| Size | About 380×250; not resizable; placed at the bottom-right of the monitor VEGAS is on |
| Showing | Appears when a render starts **without taking focus**. Keep on top is a pin in the title bar (remembered in C7 `keepOnTop`); **off by default** (owner, 2026-10-12). Mockup S6 shows it pinned |
| Header | Wire glyph for 10-bit or 8-bit output, output file name, encoder summary |
| Progress | A video-wire bar with a round head; percentage and "Frame 9,607 of 22,873" |
| Figures | Encoding fps, speed (× realtime), bitrate, size so far, final size (about, extrapolated from bytes so far), time left and total |
| Finishing | "Writing the file index" (fast start), then "Checking the output" |
| Done | Result sentence, as in History; **Open folder** and **Close**. Closes itself after 10 s unless the pointer is over it |
| Failed | The reason and FFmpeg's error line; **Show in History** and **Open log**. Stays open |
| Cancelled | "Cancelled in VEGAS"; closes after 5 s |
| Cancel | Not offered: rendering is cancelled in VEGAS's own dialog, and the footer says so |
| Updates | At most twice a second; no animation beyond the bar moving. Reduced motion changes nothing else |

If VEGAS's render dialog can show a status line, it carries the same figures as one
sentence: "x264: 61.8 fps, 2.06× realtime, 30.7 Mb/s, 1.23 GB so far".
