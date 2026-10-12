# Recipes and FFmpeg command compilation

Updated: 2026-10-12 (Asia/Singapore). Status: proposal (schema v1 draft). Basic and
Advanced are the round 1 Guided and Command modes, renamed by the owner.

This document specifies:

- what a recipe contains;
- how the product core turns it into an FFmpeg command;
- how Advanced mode works;
- which validation messages exist;
- how the size estimate is worked out.

The executable prototype is [design/shared/model.js](design/shared/model.js). Every
mockup uses it, so the commands shown in the designs follow these rules. The product
implementation is the C++ core ([TECH_ARCHITECTURE.md](TECH_ARCHITECTURE.md) §4).

## 1. Recipe schema v1

```jsonc
{
  "schema": 1,
  "id": "yt-h264",                    // stable preset id (library); kept in template snapshots as origin
  "name": "YouTube upload, H.264",
  "notes": "",
  "tags": ["YouTube"],
  "category": "web",                  // web | edit | master | review | social | custom
  "container": { "format": "mp4", "faststart": true },
  "video": {
    "enabled": true,
    "encoder": "libx264",             // FFmpeg encoder name
    "mode": "crf",                    // crf | cq | abr | cbr | cqp | profile | lossless (per encoder profile)
    "quality": 18,                    // crf/cq value; null = profile default
    "bitrateK": 12000, "maxrateK": null, // abr/cbr
    "qp": null,                       // cqp
    "speed": "slow",                  // encoder speed preset value; null = default
    "tune": null, "profile": "high", "multipass": null,
    "depth": 8,                       // output bit depth; mapped to a pixel format by the encoder profile
    "gopSec": 2,                      // keyframe interval in seconds; null = encoder default
    "color": "bt709",                 // tag policy: bt709 | none (more after color qualification)
    "extra": ""                       // Extra arguments: appended (tokenized); replaces same-name options
  },
  "audio": {
    "enabled": true,
    "encoder": "aac",
    "mode": "bitrate",                // bitrate | vbr | lossless (per encoder profile)
    "bitrateK": 320, "vbr": null, "level": null,
    "sampleRate": "source",           // source | 44100 | 48000 | 96000
    "channels": "source",             // source | stereo | mono
    "extra": ""
  },
  "command": {
    "mode": "structured",             // structured (Basic) | template (Advanced)
    "template": ""                    // kept even while inactive
  },
  "vegas": {                          // VEGAS-facing preferences — gated, read-only until qualified
    "frame": "project",               // project | WxH
    "inputFormat": "p010"             // what to request from VEGAS; only P010 is qualified
  },
  "extensions": {}                    // unknown keys from newer versions are preserved here
}
```

### Rules

- **Absent or null means "encoder default"**, as defined by the encoder profile.
  `normalize` fills nothing in the saved file. It resolves defaults only at compile
  time, so changing a profile default changes recipes that never set the field. That
  is deliberate.
- **Library metadata lives outside the recipe.** Revision, favorite, pinned, updated and
  builtin are stored in the `.vepreset` wrapper:
  `{ "vepreset": 1, "revision": 6, "favorite": true, "recipe": {…} }`.
  Template snapshots never carry library metadata. They carry only `origin`.
- **Machine-local values are never stored:** no FFmpeg path, GPU index or HWND.
- **No per-option map.** Basic has no "All options" editor (owner decision,
  2026-10-12), so v1 has no `options` field. Options without a control live in
  `extra`. The design prototype still carries an `options` map; the product schema
  drops it. Adding a structured map later is an additive change.
- **Audio is a list in the product schema.** v1 stores `"audio": [ {…} ]` with exactly
  one element, the single stereo stream VEGAS delivers today. Multi-track is then an
  additive change, not a migration (HandBrake and Resolve model audio as rows). The
  design prototype keeps a single object for brevity.
- **Requirements travel with presets.** The `.vepreset` wrapper records `requires`:
  encoders and minimum FFmpeg version, derived when the preset is saved. Import and
  library sync compare it with the default installation.
- **The schema is additive within v1.** Removing or renaming a field needs schema 2 and
  a migration in core. Migrations are pure functions `vN → vN+1`, covered by
  fixtures. A failed migration preserves the original payload and reports
  "Can't read this template's settings".

## 2. Delivered media description (render-time input)

```jsonc
{ "video": { "width": 3840, "height": 2160, "fps": [30000, 1001], "pixfmt": "p010le", "sar": "1:1" },
  "audio": { "rate": 48000, "channels": 2, "sampleFmt": "f32le" } | null,
  "durationSec": 763.2 }
```

- **At render**, the DLL builds this from actual stream and frame information. That is
  existing behaviour: delivered timing wins over template nominal rates (F-041).
- **In the desktop app**, preview uses a sample context: 1080p 29.97, P010, 48 kHz
  stereo. The user can switch it to 4K 59.94 to see the effect. The size estimate uses
  the length typed on the File node (§7), not a sample duration.
- **In the popup**, preview uses the project facts the page supplies; anything unknown
  falls back to the sample.

## 3. Compilation (Basic mode)

The order is fixed so commands are predictable and diff cleanly:

| # | Group | Tokens (example) | Source |
| --- | --- | --- | --- |
| 1 | Executable | `ffmpeg` | machine default (never in recipe) |
| 2 | Globals | `-hide_banner -nostdin -loglevel info -stats_period 0.5 -progress pipe:1` | product-owned |
| 3 | Video input | `-f rawvideo -pix_fmt p010le -s 3840x2160 -r 30000/1001 -thread_queue_size 64 -i \\.\pipe\vegas-encoder-<id>-video` | product-owned, from delivered media |
| 4 | Audio input | `-f f32le -ar 48000 -ac 2 -thread_queue_size 64 -i \\.\pipe\vegas-encoder-<id>-audio` | product-owned, only if audio enabled |
| 5 | Maps | `-map 0:v:0 -map 1:a:0` | product-owned |
| 6 | Video | `-c:v <enc>`, speed, tune, rate control, multipass, profile, `-pix_fmt`, `-g`, color tags, Apple tag, extra | encoder profile + recipe |
| 7 | Audio | `-c:a <enc>`, bitrate/VBR/level, `-ar`, `-ac`, extra | encoder profile + recipe |
| 8 | Container | `-movflags +faststart` (MP4 only), `-f <muxer>` | container profile |
| 9 | Output | temp path with the final extension | product-owned |

### Rate-control mapping (from the encoder profiles)

| Mode | x264 / x265 | NVENC | SVT-AV1 | VP9 | QSV | ProRes / DNxHR | FFV1 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Constant quality | `-crf N` | `-rc vbr -cq N -b:v 0` | `-crf N` | `-crf N -b:v 0` | `-global_quality N` | — | — |
| Target bitrate | `-b:v R [-maxrate M -bufsize 2M]` | `-rc vbr -b:v R [-maxrate…]` | `-b:v R` | `-b:v R` | `-b:v R` | — | — |
| Constant bitrate | `-b:v R -minrate R -maxrate R -bufsize 2R` | `-rc cbr -b:v R …` | — | same as x264 | same | — | — |
| Fixed quantizer | `-qp N` | `-rc constqp -qp N` | `-qp N` | — | — | — | — |
| Set by profile | — | — | — | — | — | `-profile:v P` (+ `-vendor apl0` for ProRes) | — |
| Lossless | — | — | — | — | — | — | `-level 3 -g 1 -slices 16 -slicecrc 1` |

Option names, ranges and enum values were checked against FFmpeg 8.1.3 help text.
Examples: NVENC `-preset` p1–p7 with default p4, `-tune` hq/uhq/ll/ull/lossless,
`-rc` constqp/vbr/cbr; SVT-AV1 `-crf` 0–63 and `-preset` −2–13. See `design/shared/avoptions.js`.

### Pixel formats

VEGAS delivers `p010le` (10-bit 4:2:0). The encoder profile maps `depth` to a
format the encoder accepts:

| Encoder | 8-bit | 10-bit | Note |
| --- | --- | --- | --- |
| libx264 | yuv420p | yuv420p10le | 10-bit H.264 plays on few devices; warn |
| libx265, libsvtav1, libvpx-vp9 | yuv420p | yuv420p10le | |
| hevc_nvenc, av1_nvenc | yuv420p | **p010le** (no conversion) | fastest path from VEGAS |
| h264_nvenc | yuv420p | — | |
| prores_ks | — | yuv422p10le (4444: yuv444p10le) | chroma interpolated from 4:2:0; info |
| dnxhd | yuv422p (LB/SQ/HQ) | yuv422p10le (HQX), yuv444p10le (444) | `-pix_fmt` is mandatory: auto-selection from p010le makes `dnxhr_hq` fail (matrix evidence) |
| ffv1 | — | yuv420p10le | lossless baseline |

### Other rules

- **Keyframe interval.** Seconds are converted with the delivered rate,
  `round(gopSec × fps)`. For example, 2 s at 30000/1001 is 60 frames.
- **Color tags.** `bt709` writes `-color_primaries bt709 -color_trc bt709 -colorspace bt709 -color_range tv`.
  This is a tagging policy, not a conversion. Color metadata from VEGAS is
  unqualified (ADAPTER_DATA_FLOW), so HDR and other primaries stay Advanced-mode
  territory until a color qualification exists.
- **Apple HEVC tag.** HEVC in MP4/MOV adds `-tag:v hvc1`, because FFmpeg's default
  `hev1` doesn't play in Apple software (matrix evidence).
- **Extra arguments override.** An option typed in a stream's Extra arguments replaces
  the generated option of the same name in that stream, together with its value. It is
  not duplicated: `-preset slower` as an extra removes the generated `-preset slow`.
  This matches StaxRip's "Custom" behaviour (research/REFERENCE_PRODUCTS.md), and the
  preview marks replaced fields as "set in Extra arguments". The encoder itself
  (`-c:v`/`-c:a`) can't be overridden this way; use the picker.
- **Output.** The engine writes `<dir>\<name>.ve-partial-<job>.<ext>`. It always passes
  `-f <muxer>` explicitly, then publishes by rename after exit 0 and successful output
  verification.

## 4. Advanced mode

Advanced mode replaces groups 5–9 with the user's text. Groups 1–4 still come from
the product. The user places them with `{inputs}`:

```text
ffmpeg -hide_banner {inputs}
  -map {v} -map {a}
  -c:v libx265 -preset slow -crf 18 -pix_fmt yuv420p10le
  -x265-params "hdr10=1:repeat-headers=1:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc:master-display=G(13250,34500)B(7500,3000)R(34000,16000)WP(15635,16450)L(10000000,1):max-cll=1000,400"
  -c:a aac -b:a 320k
  {output}
```

### Macros

| Macro | Expands to | Required |
| --- | --- | --- |
| `{inputs}` | Groups 3–4: the VEGAS pipe inputs. Options typed before it apply as input/global options (e.g. `-hwaccel`). | yes |
| `{output}` | Temp output path (final extension kept) | yes |
| `{v}` / `{a}` | `0:v:0` / `1:a:0` | |
| `{width}` `{height}` `{fps}` `{sample_rate}` | Delivered values | |
| `{gop:Ns}` | `round(N × fps)` | |
| `{project}` | VEGAS project name without extension | |

### Parsing and safety

- **Tokenizing.** Core tokenizes the template with Windows CRT rules: whitespace
  separates arguments, double quotes group them, and a backslash before a quote
  escapes it. A leading `ffmpeg`/`ffmpeg.exe` is ignored because the executable comes
  from machine settings. `-hide_banner`/`-nostdin` are de-duplicated.
- **Line breaks** are whitespace. A trailing `^` or `\` continuation is accepted and
  removed, so commands pasted from cmd/PowerShell/bash work.
- **No shell.** Pipes (`|`), redirections and environment expansion are literal
  characters passed to FFmpeg.
- **Extra inputs** (`-i logo.png`) are allowed. They are numbered from 2, because the
  VEGAS inputs are 0 and 1. A lint hint says so.

### Lint (live, in the editor; repeated by the DLL before render)

| ID | Level | Condition | Message |
| --- | --- | --- | --- |
| L-INPUTS | error | `{inputs}` missing | Add {inputs}. Vegas Encoder needs it to connect the VEGAS video and audio pipes. |
| L-OUTPUT | error | `{output}` missing | Add {output} where the output file goes, usually at the end. |
| L-ENCODER | warn | `-c:v X` not in the selected FFmpeg | X isn't in the selected FFmpeg's encoder list. |
| L-VALUE | error | enum value outside the option's constants/curated list | p9 isn't a preset for hevc_nvenc. Use p1–p7. |
| L-OPTION | warn | option unknown to the referenced encoders and to the generic option list | -foo isn't a known option for hevc_nvenc in FFmpeg 8.1. |
| L-OVERWRITE | hint | `-y` / `-n` | Not needed. Vegas Encoder writes to a temporary file and handles overwrite itself. |
| L-GLOBAL | hint | `-hide_banner`, `-nostdin` | Always added by Vegas Encoder. |
| L-INPUT | warn | `-i` | Extra inputs are allowed; they start at index 2. |
| L-OUTPUTS | warn | more than one output file | Only {output} is published and cleaned up. Other outputs are left as FFmpeg writes them. |

**Known limits.** Lint knows only the private options of encoders named in the
template, plus a curated list of generic options. Generic options (`-b:v`, `-g`,
`-maxrate`, `-bf`…) are not listed by `-h encoder=`. Unknown options are therefore
warnings, never errors. FFmpeg remains the final authority, and its exact stderr is
shown in History.

### Autocomplete

- After `-` it offers the referenced encoders' private options (name, type, default,
  description) plus the generic options.
- After an option with constants it offers the values (e.g. `-tune ` → hq, uhq, ll, ull, lossless).
- After `-c:v ` / `-c:a ` it offers encoders, with Ready / Not in this FFmpeg / Failed
  test badges.

**Cost and order.** The suggestions come from the same parsed options and encoder
profiles that lint needs, so they add no separate data to maintain: a new FFmpeg build
brings its own options. The prototype's `complete()` is about 30 lines. The real cost
is the Flutter popover (caret position, keyboard, focus), written once. It is built
last in P3 and can slip to v1+ without blocking Advanced mode.

## 5. Basic ↔ Advanced switching

| Action | Result |
| --- | --- |
| Basic → Advanced, no template yet | Template seeded from the compiled groups 5–9 (one argument group per line), `{inputs}`/`{output}` inserted. Structured fields kept. |
| Basic → Advanced, template exists | Ask: "Use your saved command" (default) or "Replace it with the current settings". |
| Advanced → Basic | Template kept but inactive; banner: "Your command is saved. Renders use these settings until you switch back." |
| Save while in Advanced mode | Both stored; `command.mode` decides what renders. |

No reverse parsing of a command into fields in v1. Round-tripping arbitrary FFmpeg
arguments into controls is lossy and surprising. A later "Import fields from command"
could recognize the curated subset and show what it could not map.

## 6. Validation catalog (Basic mode)

| ID | Level | Condition | Message (prototype wording) |
| --- | --- | --- | --- |
| V-STREAMS | error | video and audio off | Turn on video, audio, or both. |
| V-AUDIO-ONLY | error | video off, audio on | Audio-only renders aren't supported yet. Turn video back on. (Adapter limit.) |
| V-ENC-MISSING | error | encoder not in installation | x264 isn't in FFmpeg 8.0 LGPL. LGPL builds leave out GPL encoders such as x264 and x265. |
| V-ENC-FAILED | error | hardware test failed | NVENC HEVC is listed by FFmpeg 8.1 full but failed its test encode on this PC. … |
| V-CONTAINER-VIDEO | error/warn | matrix `no` / `warn` | QuickTime (MOV) can't hold AV1 video. Use MP4, Matroska or WebM. |
| V-CONTAINER-AUDIO | error/warn | matrix `no` / `warn` | FLAC audio in MP4 muxes, but many players won't play it. AAC is the safe choice for MP4. |
| V-DEPTH-DOWN | info | output depth < delivered depth | VEGAS delivers 10-bit frames. This encode stores 8-bit, which can show banding in smooth gradients. |
| V-CHROMA-UP | info | 4:2:2/4:4:4 output from 4:2:0 | ProRes stores 4:2:2 color. VEGAS delivers 4:2:0, so the extra color resolution is interpolated, not recovered. |
| V-H264-10BIT | warn | libx264 at 10-bit | 10-bit H.264 doesn't play on most phones, browsers or TVs. |
| V-RATE | error | encoder lacks the sample rate | Opus doesn't support 44.1 kHz. Use 48 kHz. |
| V-GOP | warn | gopSec > 10 | Keyframes more than 10 seconds apart make seeking slow. |
| V-EXTRA-OPTION | warn | an option in Extra arguments is unknown to the encoder's parsed options and the generic list | -foo isn't an option of x264 in FFmpeg 8.1 full. FFmpeg stops with an error if it doesn't know an option. |
| V-FASTSTART | info | MP4 + fast start | Fast start rewrites the file once encoding ends… |
| V-UNTESTED | info | outside the qualified VEGAS matrix | Not tested with VEGAS yet. (Planned; not in the prototype.) |

## 7. Size estimate

Shown only on the File node (UI_SPEC §2).

**Where the length comes from:**

- **At render time VEGAS reports it exactly.** The adapter already reads the frame
  count (`GetFrameCount`) and audio length (`GetStreamLength`) before encoding, so job
  records and History always have the real duration and size.
- **While editing, the length is unknown.** The desktop app has no project. The popup
  only knows it if the native page can read the project or render-region length from
  VEGAS; that is unproven and **gated** on A5. The render range can also change in
  Render As after the template is chosen.
- VEGAS's exporter interface has an `EstimateFileSize` method, which the adapter
  doesn't implement (it would log `E_NOTIMPL`). VEGAS 2026.0.3.189 never called it
  during the five real renders in the local adapter logs (checked 2026-10-12), so
  nothing is known about when VEGAS asks or where it shows the answer. Not planned.

**So the card shows:**

- **A rate per minute, always.** It needs no length.
- **A total for the length in the field.** Desktop: the user types it. Popup: the
  project length when VEGAS shares it, otherwise empty.
- **Bitrate modes:** size = (video + audio bitrate) × length, shown as a plain figure.
- **Quality modes, profiles and lossless:** a rough guide from a bits-per-pixel model,
  scaled by codec efficiency and resolution. Always "About …", with a typical range
  (for constant quality, 0.6× to 1.6× of the figure) and the explanation "the size
  depends on how busy the footage is".
- **Advanced mode:** no estimate.
- **History (v1+):** completed jobs record actual sizes per recipe, so the card can show
  "Your last 5 renders with this preset averaged 21 Mb/s", which beats any formula.
