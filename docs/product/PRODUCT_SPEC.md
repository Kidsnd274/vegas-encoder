# Vegas Encoder product specification

Updated: 2026-10-11 (Asia/Singapore). Status: proposal for review.

What the product does for its users, feature by feature, and the flows that tie it
together. The architecture is in [TECH_ARCHITECTURE.md](TECH_ARCHITECTURE.md), the
settings rules in [SETTINGS_AND_COMMANDS.md](SETTINGS_AND_COMMANDS.md), and the
visual exploration in [design/](design/DESIGN_BRIEF.md).

## 1. Principles

1. **FFmpeg, unhidden.** Every setting maps to visible FFmpeg arguments, and the full
   command is always one glance away. Power users can type anything; the product only
   insists on owning the VEGAS inputs and the output file.
2. **Video and audio are separate, equal streams.** Each has its own encoder,
   rate-control mode, quality or bitrate, and options. Neither hides inside the other.
3. **Templates are self-contained.** A VEGAS template renders the same way tomorrow,
   even if its library preset was edited, renamed or deleted.
4. **Say it where the choice is made.** Encoder availability, container limits,
   bit-depth loss and chroma interpolation appear next to the control that causes them.
5. **Fast in, fast out of VEGAS.** The popup opens in about a second, applies in one
   click, and never makes VEGAS wait during a render.

## 2. Feature list

Priority labels:

- **v1:** needed for a usable first release.
- **v1+:** the first follow-up release.
- **Later:** needs research or new adapter evidence.

**Gated** means the feature depends on a pending adapter milestone in [ADAPTER_PLAN.md](../ADAPTER_PLAN.md).

### 2.1 Encoding settings (shared editor)

| Feature | Priority | Notes |
| --- | --- | --- |
| Container choice (MP4, MKV, MOV, WebM, MXF) with fast start for MP4 | v1 | Matrix-checked compatibility messages |
| **Video stream:** encoder picker grouped by codec (H.264, HEVC, AV1, VP9, intermediates, lossless), hardware vendor and availability shown | v1 | Curated: x264, x265, SVT-AV1, VP9, NVENC H.264/HEVC/AV1, QSV HEVC, AMF H.264, ProRes, DNxHR, FFV1 |
| Rate-control mode per encoder: constant quality, target bitrate, constant bitrate, fixed quantizer, set by profile, lossless | v1 | Only the modes the encoder supports are offered |
| Quality value with meaning (e.g. CRF 18 "Visually lossless"); bitrate with peak; fixed QP | v1 | Scale marks come from encoder profiles |
| Speed preset (ultrafast…placebo, p1…p7, SVT-AV1 0…13), tune, profile, multipass (NVENC) | v1 | |
| Bit depth (8/10) mapped to the right pixel format; keyframe interval in seconds; BT.709 color tags | v1 | Bit-depth loss and chroma interpolation explained inline |
| **Audio stream:** encoder (AAC, Opus, FLAC, ALAC, PCM 16/24/32f, AC-3, E-AC-3, MP3), bitrate / VBR quality / lossless level, sample rate, channels (source, stereo, mono) | v1 | Opus restricted to 48 kHz, etc. |
| Turn video or audio off | v1 | Audio-only renders blocked until the adapter supports them |
| **All options** per encoder: every private option the FFmpeg reports, typed editors, defaults shown, changed values marked, searchable | v1 | Parsed from `-h encoder=X`; works for uncurated encoders too |
| **Extra arguments** per stream | v1 | Appended verbatim; linted |
| Live command preview, copyable, grouped by stream | v1 | Same compiler as the render |
| Size estimate for the project duration (exact for bitrate modes, "about" for quality modes) | v1 | |
| **Test this preset**: run FFmpeg on synthetic frames at the project's format, then verify the output | v1 | Finds failing GPU encoders and bad arguments before a VEGAS render (Voukoder Pro Scene Test precedent) |
| Modified dots, per-field reset, Reset to preset; "default" relative to the encoder speed preset | v1 | StaxRip and HandBrake precedents |
| Search across every setting | v1+ | D4 Inspector's hero; useful in any direction |
| "From VEGAS" panel: delivered size, rate, pixel format, audio format | v1 (read-only) | Overrides (frame size, rate, input format) are **gated** |
| Filters (scale, deinterlace, LUT) as structured controls | Later | Command mode and Extra arguments cover them meanwhile |

### 2.2 Command mode

| Feature | Priority | Notes |
| --- | --- | --- |
| Write the whole command; `{inputs}` and `{output}` required; value macros (`{fps}`, `{gop:2s}`, `{project}`…) | v1 | |
| Syntax highlighting by role; locked macro chips | v1 | |
| Lint in place: missing macros, invalid enum values, unknown options, `-y`, extra inputs/outputs | v1 | Warnings never block; errors block Apply |
| Autocomplete for options and values from the selected FFmpeg | v1 | |
| Seed from Guided settings; switching back keeps both | v1 | |
| Extra inputs (logo, LUT file) via `-i` | v1 | Indexed from 2 |
| "Import fields from command" (reverse mapping) | v1+ | StaxRip offers Import Command Line; map the curated subset, list what couldn't be mapped |

### 2.3 Presets library (desktop app)

| Feature | Priority | Notes |
| --- | --- | --- |
| Built-in presets (read-only) and user presets; Duplicate to edit | v1 | Built-ins: the 6 in `model.js` |
| Categories, tags, favorites, search | v1 | |
| Availability marks per preset for the default FFmpeg | v1 | "Needs x264: not in FFmpeg 8.0 LGPL" |
| Revisions with last-20 history, restore, and diff | v1 | Powers "Update from library" |
| Import/export `.vepreset` and a share string | v1 | Validated on import; unknown encoders flagged, not dropped |
| Presets record their requirements (encoders, minimum FFmpeg version); unmet ones are listed on import | v1 | Makes the FFmpeg build part of the preset contract |
| Show in Render As (pinned presets as exporter presets) | Later, **gated** | Research gate in TECH_ARCHITECTURE §5.5 |
| Per-preset FFmpeg override (machine-local) | Later | |

### 2.4 VEGAS integration

| Feature | Priority | Notes |
| --- | --- | --- |
| Vegas Encoder in Render As with a default template | Exists | Current fixed FFV1 profile |
| Native page in Custom Template: summary, origin, Edit settings…, Load preset | v1, **gated A5** | Mock: `design/shared/vegas-native-page.html` |
| Popup editor (separate owned window): template header, From VEGAS, shared editor, Apply/Cancel | v1, **gated A5/A6** | Session files; crash-safe |
| Template stores the full recipe snapshot plus origin | v1, **gated A7** | Versioned envelope |
| Update from library (diff preview), Save to library (new or origin), Load preset | v1 | |
| Render using the template's recipe and the machine's default FFmpeg | v1, **gated A4–A7** | Output verification before publish |
| Progress and cancel as today; actionable error messages with FFmpeg's last error line | v1 | Existing engine behaviour extended |

### 2.5 FFmpeg management

| Feature | Priority | Notes |
| --- | --- | --- |
| Discover installations (PATH, winget, Scoop, Chocolatey, INI path); Add FFmpeg… | v1 | |
| Identify version, build, license class, ffprobe; content-hash identity | v1 | |
| Capability probe with cache; parsed options for curated encoders, on demand for others | v1 | ~1–2 s per installation |
| Hardware test encodes (8-bit and 10-bit) with reasons on failure | v1 | Keyed by GPU fingerprint |
| Default installation used by all renders | v1 | Recorded per job |
| Get FFmpeg helper (winget command or consented download) | Later | Licensing decision first |

### 2.6 History and diagnostics

| Feature | Priority | Notes |
| --- | --- | --- |
| Render list (succeeded, cancelled, failed) with project, template, encoder, duration, speed, size | v1 | From `jobs.jsonl` written by the DLL |
| Job detail: exact command, FFmpeg identity, stderr tail and full log, output verification | v1 | |
| Open output folder, copy command, re-open the template's settings as a new preset | v1 | |
| Actual average bitrate per preset to improve estimates | v1+ | |

### 2.7 App settings

- **Theme:** system, light or dark.
- **Logs:** retention in days and Open log folder. Every job log starts with a
  system-information header: CPU, GPU and driver, FFmpeg path, version and hash.
- **VEGAS integration:**
  - detected VEGAS installs;
  - exporter status per install: installed version, the file path checked, and
    whether the files match the installer manifest;
  - help for finding Vegas Encoder in Render As, such as VEGAS's "Show all formats"
    and Components checks, which confused Voukoder Pro users;
  - reinstall and uninstall through the reversible installer. It never replaces
    another exporter silently.
- **About:** versions of the app, core, DLL and schema.

## 3. Key flows

### F1 First run

1. The installer places the app, exporter DLL and config. It is reversible and
   manifest-based.
2. The app opens on **FFmpeg** if no default exists. It shows candidates found
   automatically, with version and license class, and a progress strip as it probes.
3. The user picks the default. Hardware tests run in the background and badges fill in.
4. **Presets** shows the built-ins, already marked for availability (e.g. NVENC presets
   say "Ready on RTX 4070").

### F2 Render in VEGAS with a library preset (gated)

1. In VEGAS: Render As, Vegas Encoder, choose the default template, then Customize Template.
2. The native page shows the current settings. **Load preset**: pick
   "YouTube upload, H.264".
3. The summary updates. Name the template in VEGAS and save it with VEGAS's save button.
4. Render. VEGAS progress and cancel work as usual. Afterwards the job appears in History.

### F3 Tweak a template in the popup (gated)

1. On the native page, click **Edit settings…**. The page shows "Vegas Encoder window
   is open" and VEGAS is disabled behind the window.
2. The popup opens with the template name, "From VEGAS: 3840×2160, 29.97 fps, 10-bit
   4:2:0, 48 kHz stereo", and the origin "From YouTube upload, H.264 (revision 5)".
3. The user changes CRF 18 to 17 and the speed from slow to slower. The command and
   size estimate update; "2 changes from the preset" appears.
4. **Apply to template.** The window closes and the page summary updates. The footer
   reminds the user to save the template in VEGAS to keep it.

### F4 Update a template from the library (gated)

1. The popup header says "Library has revision 6".
2. **Update from library** shows the differences. Their own edits that would be lost
   (quality 17 → 18, slower → slow) appear separately from the library's change
   (audio 256 → 320 kb/s).
3. Options: **Replace with revision 6**, **Keep my changes and take only library
   changes**, or **Cancel**. The second is a three-way merge on field paths: allowed
   when the fields don't overlap, disabled otherwise.

### F5 Create a preset (desktop)

1. **Presets**, then **New preset** (from blank or from a built-in).
2. The Guided editor opens:
   - choose the container;
   - turn on video and pick an encoder (unavailable ones are marked, with reasons);
   - pick a mode and set quality;
   - turn on audio, pick an encoder and set the bitrate.
3. Messages appear beside fields. The command is visible.
4. **Save preset.** It appears in the library and in the native page's Load preset menu.

### F6 Write a command (desktop or popup)

1. Switch to **Command**. The template is seeded from the current settings.
2. Edit. Highlighting, lint and autocomplete come from the selected FFmpeg's real options.
3. Errors (e.g. missing `{output}`) disable Save/Apply with a clear message. Warnings don't.
4. Switching back to Guided keeps the command saved but inactive, and says so.

### F7 Diagnose a failed render

1. **History** marks the job as failed: "FFmpeg exited with code 1 before reading any frames."
2. The detail shows the stderr tail: "Error setting preset 14: must be between −2 and 13". The command highlights `-preset 14`.
3. **Open settings** opens the template's recipe as a new preset, so the user can fix it
   and apply it to the template again.

### F8 Share a preset

**Export** writes a `.vepreset` file, or **Copy share string** copies it to the clipboard.
On the other PC, **Import** validates the file. Encoders that aren't available there
are flagged, not removed.

### F9 Switch FFmpeg

1. On the FFmpeg page, set "FFmpeg 8.0 LGPL" as the default.
2. Presets that need x264/x265 are marked "Not in this FFmpeg".
3. VEGAS templates that use them show the same message on their native page. Renders
   with them fail fast, before VEGAS starts rendering, with an actionable message.

## 4. Limits inherited from the adapter (shown honestly in the UI)

| Limit | Source | UI treatment |
| --- | --- | --- |
| VEGAS delivers P010 (10-bit 4:2:0) only on the encoded path | ADAPTER_DATA_FLOW | "From VEGAS" shows it; bit-depth/chroma messages |
| One stereo float audio stream at 48 kHz (qualified) | ENCODING_BASELINE | Channels: source/stereo/mono; no multi-track |
| No audio-only renders | STATUS limits | Video can't be turned off while audio is on |
| Color metadata unknown; HDR unqualified | ADAPTER_DATA_FLOW | BT.709 tagging only; HDR via Command mode with a warning |
| Single-pass only: frames stream once | Pipe design | No two-pass modes; "two-pass via lossless intermediate" listed as Later |
| One container extension per exporter class (`*.mkv`) until per-template extensions are proven | ADAPTER_PLAN §2 | Popup notes when VEGAS's filename extension differs from the container; the engine writes the right extension (**to verify**: how VEGAS names the file) |
| Untested encoder/container combinations with VEGAS | Qualification gates | "Not tested with VEGAS yet" info, never blocking |

## 5. Not in v1

- Free-form node graphs (Voukoder Pro style). The fixed pipeline covers VEGAS's single
  video + single audio delivery.
- Bundled or auto-downloaded FFmpeg.
- Multiple audio tracks or stems.
- Two-pass and target-file-size encodes.
- Render queue/batch inside the desktop app. VEGAS owns rendering.
- A public SDK (unchanged from ARCHITECTURE §9).
