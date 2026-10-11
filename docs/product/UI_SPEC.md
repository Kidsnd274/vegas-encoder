# UI behaviour specification

Updated: 2026-10-11 (Asia/Singapore). Status: proposal.

This document covers behaviour that every design direction shares: states, flows,
keyboard, copy and the token structure Flutter will implement. Visual
exploration lives in [design/](design/DESIGN_BRIEF.md); the vocabulary is
fixed in the brief §2.

## 1. Windows

| Window | Default | Minimum | Notes |
| --- | --- | --- | --- |
| Desktop app | 1440×900 | 1100×700 | Remembers size and position; single instance |
| Popup editor | 1120×740 | 960×640 | Centred on its VEGAS owner; resizable; remembers size, not position |
| Native page | Host-defined | — | Win32 inside VEGAS; see the mock |

Below 1280 px width the desktop app collapses the library to an icon rail (or a
drawer in directions without a rail), and the popup moves the command preview into a
collapsible bottom strip.

## 2. Presets screen (S1)

### Library

- **Groups:** Built-in, then Mine, each sorted by category then name. Favorites
  float to the top of their group. Search matches name, tags, encoder and codec
  (e.g. "nvenc", "prores", "youtube").
- **Each item:** name, a one-line summary (codec and quality, audio, container) and
  marks for favorite, built-in, command mode, and **availability** (an
  error-coloured mark plus a tooltip such as "Needs x264: not in FFmpeg 8.0 LGPL").
- **Context menu:** Duplicate, Rename, Export…, Copy share string, Delete (user
  presets only), Show in folder.
- **Empty search:** "No presets match 'xyz'." plus a **New preset** action.

### Editor states

| State | Trigger | Behaviour |
| --- | --- | --- |
| Clean | Loaded or just saved | Save disabled |
| Dirty | Any change | Title shows "Edited"; Save, Revert enabled; leaving asks "Save changes to '<name>'?" (Save / Don't save / Cancel) |
| Built-in | Built-in preset selected | Editing allowed as a draft; Save becomes **Save as new preset**; a note says "Built-in presets can't be changed. Your changes will be saved as a new preset." |
| Errors | Validation has errors | Save still allowed (presets can be work in progress); the preset shows an error mark in the library |
| Updated elsewhere | File changed by the popup or another window | Banner: "This preset changed in another window." **Reload** / **Keep editing** (save then asks to overwrite or save as new) |

### Guided editor sections

The sections are Output, Video, Audio and From VEGAS. Every direction must:

- Hide controls the encoder doesn't have. Keep their recipe values; they are only
  ignored by compile.
- Keep invalid-but-selectable choices. An unavailable encoder can still be selected,
  then shows its error inline, so a preset made on another PC stays editable.
- Show messages at the field they belong to (`field` in validation output), plus a
  summary list near the command. Clicking a summary item focuses its field.
- Show units and meaning: "CRF 18, visually lossless", "8 Mb/s average, 12 Mb/s peak",
  "2 s (60 frames at 29.97 fps)".

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
  layouts.
- Clicking a token focuses the control that produced it. Hovering a control
  highlights its tokens. StaxRip's click-to-jump is the precedent; D1 makes it the hero.
- Options replaced by Extra arguments show a small "set in Extra arguments" note at
  their control.

## 3. Command mode (S2)

- The mode switch reads "Guided | Command".
- **Switching to Command** follows SETTINGS_AND_COMMANDS §5. The seed question appears
  only if a template already exists.
- **Locked chips:** `{inputs}` and `{output}` are inline chips. They can be moved with
  cut and paste. They cannot be edited internally; deleting one shows its lint error.
- **Lint:** errors are underlined red, warnings amber, hints dotted. Hover or caret
  shows the message. A diagnostics list sits under the editor with "Go to" for each.
- **Autocomplete:** opens after `-` or after an option that takes values. Tab or Enter
  accepts; Esc closes. Ctrl+Space opens it manually. Entries show type, default and
  description, and are filtered by the selected FFmpeg's real options.
- **Macros panel:** lists the macros with descriptions. Click to insert at the caret.
- **Preview:** a "Resolved command" toggle shows the expanded result for the current
  context: real pipe names, temp output, and `{gop:2s}` → 60.
- **Errors** block Save in the popup (Apply) and are allowed in desktop drafts (marked).

## 4. VEGAS popup (S3)

### Header

- Template name (editable; VEGAS also has its own name field, so a hint says
  "Rename in VEGAS to change the saved template name").
- **From VEGAS** facts.
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
| Ctrl+F | Search settings / library | Desktop, popup |
| Ctrl+S | Save preset | Desktop |
| Ctrl+Enter | Apply to template | Popup |
| Esc | Cancel / close popover | Popup, popovers |
| Ctrl+Shift+C | Copy command | Everywhere |
| Ctrl+M | Switch Guided / Command | Editor |
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
- Flutter `Semantics` labels on custom controls: fader/slider (value plus meaning),
  chips, wire diagram nodes, triangle puck.
- Reduced motion (Windows "Animation effects" off) disables decorative transitions.
  State changes still update instantly.
- Text scales up to 150% without clipping, within each window's minimum size.

## 10. Design tokens (Flutter `ThemeExtension`)

Every direction fills the same roles, so switching or mixing directions is a token change:

```dart
@immutable
class VeTokens extends ThemeExtension<VeTokens> {
  // Surfaces
  final Color canvas, panel, raised, line, text, textMuted, focus;
  // Roles: what part of the command a thing belongs to
  final Color roleInput, roleVideo, roleAudio, roleContainer, roleOutput, roleExtra;
  // Status
  final Color error, warning, info, success;
  // Type
  final TextStyle display, title, body, label, numeric, mono;
  // Shape and space
  final double radiusSmall, radiusLarge, space1, space2, space3, space4; // 4/8/12/16/24/32 scale
  final Duration motionShort, motionMedium; // zero when reduced motion
  // …copyWith / lerp
}
```

- Role colours are used consistently across the command preview, section accents,
  diagram wires (D3), strip caps (D2) and bar status (D8).
- Every font is OFL, bundled and subset. The one exception is Segoe UI Variable, a
  system font, used only for the Mica direction.

## 11. Component inventory (Flutter)

| Component | Notes |
| --- | --- |
| `EncoderPicker` | Grouped by codec; hardware vendor; availability state with reason; search |
| `RateModeSwitch` | Segmented; only the encoder's modes |
| `QualityControl` | Slider, field and marks; bitrate variant; profile-steps variant |
| `OptionRow` / `OptionGrid` | Typed editors for parsed AVOptions: enum, tri-state boolean, number with range, text; changed mark; reset |
| `CommandView` | Tokens with roles; collapsed inputs chip; copy; multi-line |
| `CommandEditor` | `TextEditingController.buildTextSpan` highlighting, macro chips, lint underlines, autocomplete overlay |
| `MessageList` / `InlineMessage` | Levels, field focus |
| `SizeEstimate` | Exact or "about"; video/audio split |
| `OriginBanner` | Popup origin states and actions |
| `DiffList` | Field label, from → to |
| `InstallationCard`, `CapabilityTable` | FFmpeg screen |
| `JobList`, `JobDetail`, `LogView` | History |
