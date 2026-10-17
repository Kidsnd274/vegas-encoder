# Vegas Encoder product specification

Updated: 2026-10-17 (Asia/Singapore). Status: product scope, updated with the owner's
decisions ([README.md](README.md#decisions)).

What the product does for its users, feature by feature, and the flows that tie it
together. The architecture is in [TECH_ARCHITECTURE.md](TECH_ARCHITECTURE.md), the
settings rules in [SETTINGS_AND_COMMANDS.md](SETTINGS_AND_COMMANDS.md), and the
chosen design in [design/signal-flow.html](design/signal-flow.html). The product runs
on Windows x64 only, because VEGAS Pro does.

## 1. Principles

1. **FFmpeg, unhidden.** Every setting maps to visible FFmpeg arguments, and the full
   command is always one glance away. Power users edit the command within the
   native adapter's established input, stream and single-output scope.
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

### Current release scope (owner, 2026-10-17)

Keep the working product. Only two unfinished product features remain in scope:

1. **MP4, MOV, WebM and MXF in VEGAS, alongside MKV.** Finish native extension
   advertising/filter/default naming integration and qualify the retained workflow;
   the shared core/engine pipeline is already implemented and tested offline.
2. **VEGAS installation/status dashboard.** Read-only detected-host and exporter
   status, checked paths/versions and manifest integrity when verifiable. Discovery
   is not compatibility evidence. Installation, repair and uninstall belong to the
   owner's installer, which the owner will build.

**Skip the other unfinished enhancements for this release:** preset history
browsing/restore, native extra inputs/general maps/complex graphs, new edit-time
project/destination extraction, richer native-page summary/direct Load shortcut,
pinned Render As presets, per-preset FFmpeg override, log retention/richer system
headers, command-to-Basic import, learned size estimates, structured filter/input
override controls, FFmpeg download helpers, update checks/diagnostic bundles,
additional host/media support and live-edit/prewarm enhancements. There is no
automatic follow-up commitment for these items.

Preserve existing revision counters/history storage, conflict handling, snapshots,
base-recipe copies/diff, logs, schema fields and sample/unknown fallbacks. Existing
Update from library does not depend on a history browser. Keep native restrictions
for skipped command scope; do not remove working Basic/Advanced functionality.
This scope decision neither passes qualification gates nor resumes owner-deferred
trials. Current queue and evidence remain NEXT_AGENT and STATUS.

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
| **Signal path** diagram as the editor's navigation: wire thickness for bit depth, pips for conversions | v1 | Full on the desktop, a one-row strip in the popup |
| **Extra arguments** per stream, for any option without a control | v1 | Replaces same-name generated options; unknown options warn, checked against `-h encoder=X` |
| Live command preview, copyable, grouped by stream | v1 | Same compiler as the render |
| **Size and quality** behind the File node: rate per minute, total for a typed length, range for quality modes | v1 | The popup fills in the project length only if VEGAS shares it (**gated** A5) |
| Light and dark themes, following Windows | v1 | Settings can force either |
| **Test this preset**: desktop-only lightweight synthetic check, then verify the output | v1 | Owner decision 2026-10-17: retain 320×180 P010 at 30 fps; catches encoder/argument failures at that test scope, without claiming project-resolution or real VEGAS qualification |
| Modified dots, per-field reset, Reset to preset; "default" relative to the encoder speed preset | v1 | StaxRip and HandBrake precedents |
| "From VEGAS" panel: delivered size, rate, pixel format, audio format | v1 (read-only) | Overrides (frame size, rate, input format) are **gated** |
| Filters (scale, deinterlace, LUT) as structured controls | Skipped | Existing supported simple filters through Advanced/Extra remain; no new structured controls |

**Dropped (owner, 2026-10-12):** an "All options" editor for every private option
FFmpeg reports, and a search across every setting. Basic keeps curated controls;
anything else goes in Extra arguments or Advanced mode.

### 2.2 Advanced mode

| Feature | Priority | Notes |
| --- | --- | --- |
| Write the whole command; `{inputs}` and `{output}` required; value macros (`{fps}`, `{gop:2s}`, `{project}`…) | v1 | |
| Syntax highlighting by role; locked macro chips | v1 | |
| Lint in place: missing macros, invalid enum values, unknown options, `-y`, extra inputs/outputs | v1 | Warnings never block; errors block Apply |
| Autocomplete for options and values from the selected FFmpeg | v1, built last | Uses lint's parsed options; can slip to v1+ without blocking |
| Seed from Basic settings; switching back keeps both | v1 | |
| Extra media inputs via `-i`, general maps and complex filter graphs | Skipped for native rendering | Retain native admission restrictions and existing portable editor behavior; no stream-ownership expansion |
| "Import fields from command" (reverse mapping) | Skipped | No command-to-Basic import work in this release |

### 2.3 Presets library (desktop app)

| Feature | Priority | Notes |
| --- | --- | --- |
| Built-in presets (read-only) and user presets; Duplicate to edit | v1 | Built-ins: the 6 in `model.js` |
| Categories, tags, favorites, search | v1 | |
| Availability marks per preset for the default FFmpeg | v1 | "Needs x264: not in FFmpeg 8.0 LGPL" |
| Internal revisions/history and existing template diff/update | Exists; retain | History browser/restore UI is skipped. Update from library uses the copied base recipe; it does not require that UI. |
| Import/export `.vepreset` and a share string | v1 | Validated on import; unknown encoders flagged, not dropped |
| Presets record their requirements (encoders, minimum FFmpeg version); unmet ones are listed on import | v1 | Makes the FFmpeg build part of the preset contract |
| Show in Render As (pinned presets as exporter presets) | Skipped | Preserve stored pin metadata; no native list integration |
| Per-preset FFmpeg override (machine-local) | Skipped | Keep the global render default and desktop FFmpeg-for-checks selector |

### 2.4 VEGAS integration

| Feature | Priority | Notes |
| --- | --- | --- |
| Vegas Encoder in Render As with a default template | Exists | Current fixed FFV1 profile |
| Native page in Custom Template: Edit settings and status/suffix guidance | Exists; retain | Richer native summary/origin and direct Load preset shortcut are skipped; Load preset works in the popup |
| Popup editor (separate owned window): template header, From VEGAS, shared editor, Apply/Cancel | v1, **gated A5/A6** | Session files; crash-safe |
| Template stores the full recipe snapshot plus origin | v1, **gated A7** | Versioned envelope |
| Update from library (diff preview), Save to library (new or origin), Load preset | v1 | |
| Render using the template's recipe and the machine's default FFmpeg | v1, **gated A4–A7** | Output verification before publish |
| Progress and cancel as today; actionable error messages with FFmpeg's last error line | v1 | Existing engine behaviour extended. VEGAS's own progress bar is already driven frame by frame |
| Live encode statistics: a status line in VEGAS's render dialog | Dropped | Owner decision 2026-10-15; no further work |
| Live encode statistics: small progress window (encode fps, speed, bitrate, size so far, final size, time left; done and failed states) | v1, on by default, can be turned off | Separate process reading a status file; never takes focus. Dropped if it costs more than about 2% of render time (TECH_ARCHITECTURE §5.6). Mock: design S6, UI_SPEC §12 |

### 2.5 FFmpeg management

| Feature | Priority | Notes |
| --- | --- | --- |
| Discover installations (PATH, winget, Scoop, Chocolatey, INI path); Add FFmpeg… | v1 | |
| Identify version, build, license class, ffprobe; content-hash identity | v1 | |
| Capability probe with cache; parsed options for curated encoders, on demand for others | v1 | ~1–2 s per installation |
| Hardware test encodes (8-bit and 10-bit) with reasons on failure | v1 | Keyed by GPU fingerprint |
| Default installation used by all renders | v1 | Recorded per job |
| Get FFmpeg helper (winget command or consented download) | Skipped | Keep user-supplied FFmpeg discovery and manual addition |

### 2.6 History and diagnostics

| Feature | Priority | Notes |
| --- | --- | --- |
| Render list (succeeded, cancelled, failed) with project, template, encoder, duration, speed, size | v1 | From `jobs.jsonl` written by the DLL |
| Job detail: exact command, FFmpeg identity, stderr tail and full log, output verification | v1 | |
| Open output folder, copy command, re-open the template's settings as a new preset | v1 | |
| Actual average bitrate per preset to improve estimates | Skipped | Existing core estimates remain |

### 2.7 App settings

- **Theme:** Follow Windows (default), Light or Dark.
- **Rendering:** "Show a progress window during renders" (on by default) and "Keep it
  on top".
- **Logs:** keep existing History log viewing/reveal and recorded FFmpeg identity.
  Retention controls and richer CPU/GPU/driver headers are skipped.
- **VEGAS integration:**
  - detected VEGAS installs;
  - exporter status per install: installed version, the file path checked, and
    whether the files match the installer manifest;
  - help for finding Vegas Encoder in Render As, such as VEGAS's "Show all formats"
    and Components checks, which confused Voukoder Pro users;
  - read-only status and guidance; installation/repair/uninstall are performed
    through the owner's installer, not new dashboard mutation endpoints.
- **About:** retain existing information. Dashboard version facts are part of its
  status reporting; a separate expanded About inventory is not additional scope.

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
2. On the native page, **Edit settings…**, then **Load preset** in the popup: pick
   "YouTube upload, H.264".
3. The summary updates. Name the template in VEGAS and save it with VEGAS's save button.
4. Render. VEGAS progress and cancel work as usual. Afterwards the job appears in History.

### F3 Tweak a template in the popup (gated)

1. On the native page, click **Edit settings…**. The page shows "Vegas Encoder window
   is open" and VEGAS is disabled behind the window.
2. The popup opens with the template name, "From VEGAS: 3840×2160, 29.97 fps, 10-bit
   4:2:0, 48 kHz stereo", and the origin "From YouTube upload, H.264 (revision 5)".
3. The user changes CRF 18 to 17 and the speed from slow to slower. The command
   updates, the Video encoder node shows "Changed", and "2 changes in this template"
   appears. Clicking the File node shows the new size estimate.
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
2. The Basic editor opens:
   - choose the container;
   - turn on video and pick an encoder (unavailable ones are marked, with reasons);
   - pick a mode and set quality;
   - turn on audio, pick an encoder and set the bitrate.
3. Messages appear beside fields. The command is visible.
4. **Save preset.** It appears in the library and in the native page's Load preset menu.

### F6 Write a command (desktop or popup)

1. Switch to **Advanced**. The template is seeded from the current settings.
2. Edit. Highlighting, lint and autocomplete come from the selected FFmpeg's real options.
3. Errors (e.g. missing `{output}`) disable Save/Apply with a clear message. Warnings don't.
4. Switching back to Basic keeps the command saved but inactive, and says so.

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
| Color metadata unknown; HDR unqualified | ADAPTER_DATA_FLOW | BT.709 tagging only; HDR via Advanced mode with a warning |
| Single-pass only: frames stream once | Pipe design | No two-pass modes; "two-pass via lossless intermediate" listed as Later |
| Current class advertises `*.mkv`; broader extension-filter/default behavior remains unqualified | NATIVE_CONTAINER_PLAN | Native target accepts known MP4/MKV/MOV/WebM/MXF recipes and shows the required suffix. Render refuses a mismatched destination, preserves the exact selected path and never silently renames it. The popup has no actual Render As path to compare. Real-VEGAS qualification for new containers is pending. |
| Untested encoder/container combinations with VEGAS | Qualification gates | "Not tested with VEGAS yet" info, never blocking |

## 5. Not in v1

- Free-form node graphs (Voukoder Pro style). The fixed pipeline covers VEGAS's single
  video + single audio delivery.
- Bundled or auto-downloaded FFmpeg.
- Multiple audio tracks or stems.
- Two-pass and target-file-size encodes.
- Render queue/batch inside the desktop app. VEGAS owns rendering.
- A public SDK (unchanged from ARCHITECTURE §9).
