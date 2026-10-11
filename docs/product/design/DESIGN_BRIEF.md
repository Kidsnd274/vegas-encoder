# Vegas Encoder design brief

Updated: 2026-10-11 (Asia/Singapore). Status: brief for the first design round.
Mockups are review material; no Flutter UI exists yet and nothing here was run in VEGAS.

## 1. Subject, audience, job

**Subject.** Vegas Encoder makes VEGAS Pro render through FFmpeg. VEGAS hands the
exporter rendered frames and audio; FFmpeg encodes them with settings the user chose.
The product UI is where those settings are made, saved and trusted.

**Audience.** VEGAS editors who outgrew the built-in render templates: YouTubers,
wedding/event editors, small studios, and encoding enthusiasts who know StaxRip,
HandBrake or Voukoder. Most know what CRF, NVENC and ProRes are; fewer want to type
FFmpeg commands; a few want nothing else.

**Primary jobs, in order of frequency.**

1. In VEGAS, pick or tweak an encode quickly, apply it and render. (VEGAS popup)
2. Build and maintain a library of encodes that work every time. (Desktop app)
3. Write any FFmpeg command, with rails that catch mistakes before a 40-minute render. (Command mode)
4. Know which FFmpeg is used and what it can actually do on this PC. (FFmpeg page)
5. Find out why a render failed. (History)

## 2. Vocabulary (identical in every direction)

| Term | Meaning |
| --- | --- |
| Preset | A recipe saved in the Vegas Encoder library (desktop app). Built-in presets are read-only; duplicate to change. |
| Render template | A VEGAS Render As template. It holds a complete copy of the settings, so it renders even if the preset is later edited or deleted. |
| Guided | The structured editor: controls for container, video and audio. (The owner's "normal/basic" mode.) |
| Command | Write the whole FFmpeg command yourself. (The owner's "advanced" mode.) |
| Extra arguments | Free text appended to one stream's arguments in Guided mode (StaxRip's "Custom"). |
| All options | Every private option the selected FFmpeg reports for the encoder, parsed from `ffmpeg -h encoder=X`. |
| Apply | In the VEGAS popup: write the edited settings into the render template and close. |
| Save to library | Copy settings into a preset (new, or the preset it came from). Never automatic. |
| Update from library | Replace a template's settings with the newer revision of the preset it came from, after showing the differences. |
| Ready / Not in this FFmpeg / Failed test on this PC | Encoder availability states. |

Sentence case everywhere. Buttons say what happens ("Save preset", "Apply to template",
"Add FFmpeg…"). No "→" on buttons, no all-caps labels, no middle-dot meta strings.
Errors say what happened and how to fix it, without apology.

## 3. Information architecture

```text
Desktop app (VegasEncoder.exe)
├── Presets      library list + the shared editor for the selected preset
├── FFmpeg       installations, default choice, capabilities, hardware tests
├── History      renders read from exporter logs: status, command, FFmpeg log
└── Settings     theme, log retention, VEGAS integration status, about

VEGAS popup (VegasEncoder.exe --edit-template <session>)
└── one window: template header (origin, changes) + the shared editor + Apply/Cancel

VEGAS native page (inside VEGAS Custom Template dialog, Win32, in the DLL)
└── summary of the template + "Edit settings…" + "Load preset" (shared mock, not per direction)
```

The shared editor is one component used by both the desktop app and the popup:

```text
Editor
├── Mode: Guided | Command
├── Guided
│   ├── Output       container, fast start, file extension note
│   ├── Video        on/off, encoder, rate control + value, speed, tune, profile,
│   │                bit depth, keyframe interval, color tags, all options, extra arguments
│   ├── Audio        on/off, encoder, bitrate / VBR / lossless, sample rate, channels,
│   │                all options, extra arguments
│   └── From VEGAS   what VEGAS delivers (size, rate, pixel format) — read-only today
├── Command          full command with locked {inputs}/{output}, macros, lint, autocomplete
└── Always visible   live FFmpeg command, validation messages, size estimate
```

## 4. Screens every direction must deliver

Use the real content in `shared/model.js` (presets, encoders, installations, history,
template session) and `shared/avoptions.js` (real FFmpeg 8.1.3 options). Do not invent
other presets or encoders.

| ID | Screen | Window | Must show |
| --- | --- | --- | --- |
| S1 | Presets + Guided editor | Desktop, 1440×900 | Library (built-in vs mine, search, categories, favorites, availability problems), selected preset in Guided mode with video and audio configured separately, live command, validation messages, size estimate, Save/Duplicate |
| S2 | Command mode | Desktop, 1440×900 | The `hdr-template` preset: editable command with highlighting, locked `{inputs}`/`{output}`, macro list, lint diagnostics in place, an autocomplete popover (e.g. after `-tune ` for hevc_nvenc), the switch back to Guided and what happens to each mode's settings |
| S3 | VEGAS popup | 1120×740, over a dimmed VEGAS dialog | `VE.templateSession()`: template name, "From VEGAS" project facts, origin preset + revision, local changes, "library has revision 6" with an Update from library preview (diff), Load preset, Save to library, Cancel / Apply to template, footer note that the template still needs saving in VEGAS |
| S4 | FFmpeg | Desktop, 1440×900 | Three installations (default, LGPL missing x264/x265), probe time, capability list grouped by codec with Ready / Not in this FFmpeg / Failed test on this PC and reasons, Add FFmpeg…, Scan again, Test hardware encoders |
| S5 | History (optional) | Desktop, 1440×900 | `VE.history`: succeeded/cancelled/failed renders, the failed job's FFmpeg log and command, Open folder |

Minimum interactivity, wired to `VE.compile`/`VE.validate`/`VE.estimate`:
selecting a preset; changing video encoder, rate-control mode, quality/bitrate, speed,
container, audio encoder and bitrate; Guided/Command toggle; command text re-linting
on input in S2. Everything else may be static.

## 5. Constraints that shape the design

- **Flutter on Windows.** Every visual must be buildable with Flutter widgets and
  painters without heavy per-frame effects. Avoid backdrop blur except where Windows
  provides Mica natively. All fonts must be OFL (bundled with the app) or Windows system fonts.
- **Two densities.** The popup sits over VEGAS's own dialog and must work at 1120×740
  (and degrade to ~960×640). The desktop app is roomier.
- **Fields change with the encoder.** x264 has CRF/preset/tune/profile; NVENC has CQ,
  p1–p7, tune and multipass; ProRes has only a profile; FFV1 has nothing to tune.
  Layouts must not depend on a fixed set of fields.
- **Honesty about the pipeline.** VEGAS delivers 10-bit 4:2:0 (P010) and float stereo
  today. Bit-depth reduction, chroma interpolation, availability failures and container
  limits must be visible where the choice is made, not only in a log.
- **The command is a first-class citizen.** Power users read the command to trust the
  settings. Keep it visible in Guided mode, but don't let it dominate beginners.
- **Quality floor.** Visible keyboard focus, reduced motion respected, WCAG AA text
  contrast, 13 px minimum UI text (12 px only for dense secondary data), hit targets ≥ 28 px
  desktop.

## 6. Design directions

Eight directions, each with a different layout idea, not just a different palette.
Each direction spends its boldness in one place, named below as "the memorable thing".

### D1 Command Deck: the command is the interface

- **Idea.** The live FFmpeg command sits at the top as large, grouped, clickable tokens
  (inputs, video, audio, container, output). Clicking a group opens its controls below.
  Switching to Command mode turns the same tokens into editable text in place.
- **Color.** Ink `#1A2230`, panel `#222C3C`, raised `#2B3749`, line `#39475C`, text
  `#E6EBF2`, muted `#93A1B5`. Token roles: inputs `#7E8EA6`, video `#63C5F2`, audio
  `#86D28A`, container `#BBA2FF`, user extras `#F2A65A`, error `#FF6B6B`, warning `#F2D45C`.
- **Type.** Recursive (OFL variable): Sans Linear for UI, Mono Linear for the command,
  the same family bridging both. Command 15 px / 1.6.
- **Layout.**
  ```text
  ┌ preset switcher ───────────── Guided | Command ── Save ┐
  │ ffmpeg [VEGAS video+audio] [-c:v libx264 -preset slow   │
  │        -crf 18 …] [-c:a aac -b:a 320k] [MP4] [file]     │  ← the deck
  ├──────────────┬──────────────────────────────────────────┤
  │ library      │ controls for the selected token group     │
  └──────────────┴──────────────────────────────────────────┘
  ```
- **Memorable thing.** The tokenized command that becomes editable in place.

### D2 Channel Strips: streams are channels

- **Idea.** A mixing-console structure: each stream is a vertical strip; the container
  is the master strip. Quality is a vertical fader whose scale carries the encoder's
  meaning ("Visually lossless" at CRF 18). Presets are scene-recall buttons across the top.
  Metaphor in structure only: no metal textures, screws or fake LEDs.
- **Color.** Faceplate `#DFE3E6`, strip `#ECEFF1`, divider `#C5CBD0`, ink `#1C2126`,
  muted `#5D6872`, video cap `#2F6FE4`, audio cap `#E5A400`, master cap `#D8443A`, ok `#2F9E58`.
- **Type.** Barlow for UI, Barlow Condensed for strip names and scale numbers, tabular figures.
- **Layout.**
  ```text
  ┌ scene recall: [YouTube H.264] [HEVC GPU] [ProRes HQ] … Library ┐
  ├────────────┬──────────┬ ─ ─ ─ ─ ┬──────────┬──────────────────┤
  │ Video      │ Audio    │ + audio │ Master   │ Command rail      │
  │ x264       │ AAC      │ (later) │ MP4      │                   │
  │ ▮ fader    │ ▮ fader  │         │ output   │                   │
  └────────────┴──────────┴─────────┴──────────┴──────────────────┘
  ```
- **Memorable thing.** The vertical quality fader with a meaningful scale.

### D3 Signal Flow: see the path from timeline to file

- **Idea.** A fixed (not free-form) pipeline drawn as a diagram: VEGAS → video encoder →
  container → file, with audio joining the container. Selecting a node opens the inspector
  below. **Wire thickness encodes bit depth** and a conversion pip marks a pixel-format
  change, so "10-bit becomes 8-bit here" is visible at a glance.
- **Color.** Paper `#F4F6F8`, grid dots `#D9DEE4`, ink `#1F2933`, muted `#64748B`,
  video wire `#0E7C86`, audio wire `#B5446E`, conversion pip `#E8A33D`, container `#3E4C59`.
- **Type.** Instrument Sans for UI and labels; JetBrains Mono only for the command.
- **Layout.** Library rail left; diagram top (≈40%); inspector bottom with the command at right.
- **Memorable thing.** Wires that thin where precision is lost.

### D4 Inspector: a pro panel that belongs beside VEGAS

- **Idea.** Dense, dockable, keyboard-first. Library tree, a property grid with
  collapsible groups (StaxRip-style: changed-from-default values are marked, one search
  filters every option including parsed AVOptions), and an output pane with command,
  warnings and size. Matches VEGAS's dark gray UI.
- **Color.** App `#1F2124`, panel `#26292D`, header `#2E3237`, border `#3A3F45`, text
  `#D7DADF`, muted `#8A9099`, selection `#2D6CDF`, changed marker `#E3B341`, error `#E5534B`, ok `#3FB950`.
- **Type.** Roboto Flex (OFL, width axis ~88 for grid labels), JetBrains Mono for command. 13 px base.
- **Layout.** Three panes (260 / flexible / 400) plus a status bar.
- **Memorable thing.** One search box that filters across every setting, with changed values marked.

### D5 Mica: native Windows 11, calm and roomy

- **Idea.** The approachable baseline that looks like it shipped with Windows: navigation
  pane, Mica window, settings-card rows with expanders. Its distinctive element is a
  **size and quality card** that updates as you move the quality slider.
- **Color.** Light: base `#F3F3F3`, card `rgba(255,255,255,0.7)`, stroke `#E5E5E5`, text
  `#1B1B1B`, secondary `#616161`, accent `#005FB8`, success `#0F7B0F`, caution `#9D5D00`,
  critical `#C42B1C`. Provide the dark variant too (`#202020`, card `#2B2B2B`, accent `#60CDFF`).
- **Type.** Segoe UI Variable (Windows system); mock fallback Noto Sans. Command: Cascadia Mono, fallback JetBrains Mono.
- **Memorable thing.** The live size/quality card.

### D6 Tape Shelf: presets you can see on a shelf

- **Idea.** The library is a shelf of tape spines, colored by purpose (web, editing,
  master, review, social, custom), each with a short codec sticker. The selected tape
  slides out; below it, a label-like summary card and the editor tabs. Flat color,
  no wood or texture.
- **Color.** Wall `#E8EAE6`, shelf `#D5D8D2`, ink `#1C1F1D`, muted `#6A706B`, label `#FBFBF8`;
  spines web `#2F5DA8`, editing `#2E8B57`, master `#B8322E`, review `#D99A1E`, social `#7E4BB5`, custom `#3A3F3C`.
- **Type.** Archivo (variable width): condensed for spines, normal for body; Fragment Mono for the command.
- **Memorable thing.** The spine shelf; preset identity by color and position.

### D7 Destination: start from where the video goes

- **Idea.** Intent first. Pick a destination (YouTube, review link, editing handoff,
  archive, social vertical, custom), then drag a puck inside a **quality / small file /
  fast encode** triangle. The app proposes a concrete recipe ("x265 slower, CRF 19, about
  2.1 GB") and the full Guided editor sits one click below for fine-tuning.
- **Color.** Background `#F7F8FA`, surface `#FFFFFF`, ink `#14171C`, muted `#5F6B7A`,
  quality vertex `#4C6FFF`, small-file vertex `#00A389`, fast vertex `#F07C2E`.
- **Type.** Bricolage Grotesque (variable optical size) for everything; Geist Mono for the command.
- **Memorable thing.** The trade-off triangle with a live outcome.

### D8 Bars and Tone: broadcast identity as status

- **Idea.** "Bars and tone" is the broadcast test signal of color bars plus a reference
  tone: video and audio together. The bar colors become a functional identity: each
  editor section owns one bar color (video cyan, audio green, container magenta, command
  yellow), and the bar strip in the window header doubles as **live section status**:
  a section's bar dims and hatches when it has an error.
- **Color.** Graphite `#24262A`, panel `#2C2F34`, raised `#34383E`, text `#E8E8E6`,
  muted `#9A9DA3`; bars yellow `#D8C21A`, cyan `#1FB5C1`, green `#2FA84F`, magenta `#B5389F`,
  red `#C7372F`, blue `#2B4DC2`, white `#BFBFBF`.
- **Type.** Jost (geometric, broadcast-graphics heritage) for UI; Azeret Mono for the command.
- **Memorable thing.** The bar strip that reports section health.

## 7. Plan review against the brief

Checked each direction against generic defaults before building:

- **D1** first used near-black with one acid accent (a common dark-tool default). Changed to
  a blue ink base with a *role-coded* token palette, so color carries meaning (which part of
  the command you're looking at) instead of decoration.
- **D2 and D6** risked skeuomorphic kitsch (brushed metal, wood shelves). Rule added:
  the metaphor lives in structure and color only.
- **D4** is the closest to a generic dark pro tool. Kept deliberately because it matches
  VEGAS and StaxRip users' expectations; its distinct contribution is cross-setting search with
  changed-value markers, so the mockup must make that the hero.
- **D5** is intentionally the native baseline, not a novelty; the size/quality card is what
  it must prove.
- **D8** originally used the full SMPTE palette as decoration. Restricted bar colors to
  section identity and status, so color carries meaning.
- Dropped a "spec sheet" direction: it converged on the broadsheet/hairline default and
  overlapped D4's density goal.
- Vocabulary, content and behaviour are shared (`model.js`) so differences between
  directions are design differences, not content differences.

## 8. How to review

Open `design/index.html`. Each direction page shows S1–S4 (and S5 where built) as
window frames with a one-line purpose caption. Things to judge:

1. Can you configure video and audio separately without hunting?
2. Is the command visible enough to trust, without crowding beginners?
3. Do availability and conversion warnings appear where the choice is made?
4. Does the popup feel like part of VEGAS's flow (fast in, Apply, out)?
5. Which memorable thing would you keep, even if another direction wins overall?

Mixing is expected: e.g. D4's search with D3's wires and D1's command deck.
