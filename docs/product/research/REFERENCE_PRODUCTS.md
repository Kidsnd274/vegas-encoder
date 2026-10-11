# Reference products for Vegas Encoder UI/UX

Status: research note, complete (2026-10-11). Written for the Vegas Encoder product layer design.
Access date for all sources: 2026-10-11.

Labels used for each claim:

- **documented**: stated in official docs, wiki, README or vendor site.
- **seen in source**: read directly from the product's public source code.
- **user-reported**: forum posts, issues, reviews; not verified.
- **inferred**: our reasoning from the above; not stated anywhere.

No installer or binary was downloaded or executed for this note. No VEGAS
runtime test was performed.

## 1. Voukoder Classic and Voukoder Pro

Source situation: the original `github.com/Vouk/voukoder` repository now returns
HTTP 404 from the GitHub API. Code was read from the unmodified-looking mirror
`alinsavix/voukoder` (master). Its README says "Voukoder has reached its
end-of-life phase. No further development or bug fixes will be done" and points
to Voukoder Pro (documented, [S1]). The VEGAS connector was shipped only as
MSI files in `voukoder-connectors` (mirror `virare/voukoder-connectors`); its
source is not published, so VEGAS-side UI details for Classic come from forum
posts (user-reported). Voukoder Pro documentation source is the public repo
`Vouk/voukoderpro.github.io` (`index.md`, `changelog.md`), which renders at
docs.voukoderpro.com [S4][S5].

Architecture (documented, [S3]): since 2.3, Voukoder Classic is split into a
system-wide COM server ("Voukoder Core") that owns the encoding engine **and the
UI**, plus thin per-host "connectors" (Premiere, After Effects, Resolve, VEGAS,
VirtualDub 2). The COM interface has `SetConfig`, `GetConfig`,
`ShowVoukoderDialog(video, audio, ...)`, `Open`, `SendVideoFrame`,
`SendAudioSampleChunk`, `Close` (seen in source, [S2]). This is structurally
close to Vegas Encoder: one shared settings UI reachable from a host adapter.

### 1.1 Reaching configuration from VEGAS

- Classic: user picks the Voukoder format in Render As, opens the custom
  template dialog, and from there opens the Voukoder dialog; a forum helper
  describes it as "In the Vegas render dialog, you clicked on Voukoder. Then in
  Voukoder you selected custom template show voukoder dialog ... click on [the
  preset] and hit apply" (user-reported, [S6]). The exact button caption in the
  VEGAS-side page could not be verified (connector source unpublished).
  Inferred: the connector's VEGAS template page hosts a button that calls
  `ShowVoukoderDialog`, and the returned `VKENCODERCONFIG` is persisted in the
  VEGAS template blob.
- Classic limitation: Voukoder does not appear in VEGAS "Render to New Track"
  or "Selectively Prerender" (user-reported, [S7]).
- Pro: the user designs "scenes" in the separate **Designer** app, then in the
  NLE selects "Voukoder Pro" as output format and chooses the saved scene;
  "VEGAS Pro requires to open any modify a template first" (documented, [S4]).
  For Resolve the docs show a scene picker plus an "Open Scene Designer ..."
  button inside the host UI (documented, [S4]).
- Pro discoverability: VEGAS Pro 23 users must tick "Show all formats" in the
  Render dialog to see Voukoder Pro; the installer cannot autodetect the VEGAS
  path and the user must pick the right per-version plugin; diagnosis is via
  VEGAS Help > About > Components, which should list
  `voukoderproplug-vegas22.dll` under `FileIO Plug-Ins\voukoderproplug\`
  (documented, [S4]).
- Pro VEGAS template fields: frame rate etc. show as 0 in the template because
  they are "taken from the current project"; the developer's fix for a freeze
  was "create a new template based on the voukoder pro template"
  (user-reported, [S8]).

### 1.2 Configuration dialog layout (Classic)

All seen in source ([S2]: `wxVoukoderDialog.cpp`, `wxEncoderPage.cpp`,
`wxOptionEditor.cpp`, `translations/en.json`).

| Level | Pages / controls |
|---|---|
| Top-level category notebook (with icons) | **Video** (only if host enabled video), **Audio** (only if host enabled audio), **Output**, **Settings**, **About** |
| Video / Audio page sub-tabs | **Encoder**, **Options**, **Side data** (only if side data defined), **Filters** |
| Encoder sub-tab | "Codec" group (encoder combobox); "Presets" group (list) with **Apply** button; confirmation box "The selected preset has been loaded." |
| Options sub-tab | wxPropertyGrid with one category per option group; every property has a leading **checkbox**: unchecked = option not sent, text drawn grey; buttons **Reset** and **Clear**; checkbox **Show advanced options** (persisted in registry) |
| Side data sub-tab | property grid of video side data: spherical/projection (yaw, pitch, roll, bounds), stereo3d (type, view), mastering display (mdcv) and similar HDR metadata |
| Filters sub-tab | list with columns **Filter** / **Parameters**, buttons **Add**, **Edit ...**, **Remove**; edit opens "Edit filter" dialog with its own option grid; about 250 FFmpeg filter definitions ship as JSON |
| Output page | "Muxers / Formats" group: **Container** combobox, **Enable faststart** checkbox |
| Settings page | "Localization (Change requires restart)" > Language; "Logging" > "Create a log file next to the export file", "Enable low-level logging" |
| Buttons | **OK**, **Cancel**; optional sponsor banner in the button row |

Option model (seen in source, `libx264.json`): each encoder is a JSON file with
`defaults`, `presets`, `parameterGroups` and `groups`. x264 groups are
`basic` (pixel format), `standard` (preset, profile per chroma format, tune,
**strategy** = rate control, bitrate/minrate/maxrate, multipass, slow first
pass, crf, qp), and advanced groups `ratecontrol`, `frames`, `analysis`,
`misc`. Rate-control choice uses `OnSelection` filters that show/hide dependent
options (e.g. choosing `crf` hides bitrate fields). This is a good data-driven
pattern for a Guided editor.

No command-line preview exists in Classic: options are a key/value map passed
to libavcodec (seen in source; the option string is stored in a 8192-byte
`options` field).

### 1.3 Presets vs VEGAS templates

- Classic presets are **per-encoder, read-only JSON** shipped with the app
  (`presets.json` and the `presets` array inside each encoder file, e.g.
  "4:2:0 General purpose, 8bit projects (Recommended if you are not sure)" by
  iAvoe). A preset only populates the option grid when **Apply** is pressed
  (seen in source, [S2]). There is no user-preset save in the dialog (seen in
  source: no save control exists).
- The user's actual settings live in the host's template. The COM config struct
  `VKENCODERCONFIG` holds one `video` and one `audio` `VKTRACKCONFIG`
  (`encoder[16]`, `options[8192]`, `filters[8192]`, `sidedata[8192]`) plus
  `format.container[16]` and `format.faststart` (seen in source, [S2]).
  Inferred: VEGAS's own "Save template" is the only way to name and reuse a
  Voukoder configuration in VEGAS.
- Users found that saving a VEGAS template to store encoder settings also
  captured unrelated project settings (user-reported, [S9]).
- Pro inverts this: the **scene** (stored by the Designer, shareable across all
  supported NLEs) holds "all non-NLE relevant settings"; the host template holds
  only the scene selection plus host fields (documented, [S4]). The changelog
  mentions a `scenes.json` file and multi-select open/delete/rename of scenes
  (documented, [S5]).

### 1.4 Voukoder Pro: encoding graph and scenes

Documented in [S4] unless noted.

- A scene is a node graph "from input of raw frames to the output". "Scene >
  New > Simple" creates the minimal graph; "Scene > New > Filters" adds a chain
  of 1-in/1-out filters.
- Node types: **Input** (assign which NLE track it reacts to, set colour
  values), **Encoder** (e.g. ProRes + ALAC in the default, change to x264 +
  AAC), **Multiplexer/Muxer** (container: MOV, MKV, MP4), **Output** ("File"
  plus other outputs, usable in parallel; network outputs were added from
  FFmpeg protocol auto-detection, [S5]), **Post Processing** (run external
  scripts after the export finishes).
- Double-click or right-click > "Properties ..." to configure a node.
  "Invalid combinations of encoders and muxers will be shown as a red box in
  the muxer node." The check was later removed "for now to make ProRes in MXF
  work" (documented, [S5] 2026.1.5): an example of a compatibility check that
  was too strict.
- **Scene Test** (Tools > Perform Test ... or the Play toolbar icon): runs the
  real engine on synthetic frames. Settings: Video Tracks / Audio Tracks lists
  with Add / Edit / Delete; per-video track Width, Height, Timebase, Pixel
  Aspect Ratio, Field Order, Format, Color Range, Color Space, Primaries,
  Transfer; per-audio track Channel Layout, Sample Frequency, Sample Format;
  Frames / Iterations; Output File Name (default `NUL` or `/dev/null`). A log
  window streams the real log while it runs.
- Other components: a **Transkoder** app that applies scenes (changelog,
  [S5]); FFmpeg 8 shared libraries are a separate install (LGPL or GPL MSI from
  `Vouk/ffmpeg`, or a custom build on PATH) [S4].

### 1.5 Encoders and containers

- Classic encoders (seen in source, one JSON per encoder, [S2]): video
  `libx264`, `libx264rgb`, `libx265`, `h264_nvenc`, `hevc_nvenc`, `av1_nvenc`,
  `h264_amf`, `hevc_amf`, `av1_amf`, `h264_qsv`, `hevc_qsv`, `av1_qsv`,
  `vp9_qsv`, `mpeg2_qsv`, `libsvt_av1`, `libsvt_hevc`, `libsvt_vp9`,
  `libvpx`, `libvpx-vp9`, `prores_ks`, `prores_aw`, `cfhd`, `ffv1`, `hap`,
  `utvideo`, `qtrle`, `mpeg2video`, image `png`, `tiff`, `bmp`, `gif`; audio
  `aac`, `libfdk_aac`, `ac3`, `eac3`, `dca`, `truehd`, `alac`, `flac`,
  `libmp3lame`, `mp2`, `libopus`, `libvorbis`, `wavpack`, `pcm_s16le`,
  `pcm_s24le`, `pcm_s32le`.
- Classic muxers (seen in source): `mp4`, `mov`, `mkv`, `webm`, `avi`,
  `mpegts`, `vob`, `ogg`, `m4a`, `wav`, `flac`, `mp3`, `mp2`, `opus`, `wv`,
  raw `h264`, `hevc`, `mpeg2video`, `aac`, `ac3`, `eac3`, `dts`, `gif`,
  `image2-png|tiff|bmp`.
- Hardware encoders only appear when the driver/GPU supports them; "I don't see
  nvenc option in voukoder. Only qsv" was answered with "update your NVIDIA
  drivers" (user-reported, [S6]).
- Pro uses whatever the installed FFmpeg 8 shared build provides; GPL encoders
  (x264, x265) need the GPL FFmpeg package (documented, [S4]). Pro adds HDR
  (PQ/HLG) export for Premiere, MKV attachments, ProRes qscale, chapters
  (documented, [S5]).

### 1.6 Multi-audio-track handling

- Classic: one audio stream per export (seen in source: a single `audio`
  `VKTRACKCONFIG`). The VEGAS connector changelog 0.4.4 adds "Supporting 5.1
  surround audio", i.e. multichannel within one stream (documented, [S3]).
- Pro: each Input node can be bound to an NLE track; "If you are sending
  multiple audio tracks from your NLE (currently only possible with DaVinci
  Resolve Studio) ... more than one input node might be necessary" (documented,
  [S4]). So in VEGAS, Pro is effectively single mixed audio too.
- Changelog: "Disabling a track doesn't cause Voukoder Pro to create an empty
  track anymore"; "Ignore all input nodes that are not connected to any output
  node" (documented, [S5]).

### 1.7 Logging and diagnostics

- Classic (seen in source, `Log.cpp`): daily log at
  `%LOCALAPPDATA%\Voukoder\Logs\YYYY-MM-DD.log`, auto-deleted after 7 days;
  header with version, CPU name, logical cores, memory, displays/GPUs; ISO-time
  prefixed lines; optional extra log "next to the export file" and optional
  "low-level" (libav) logging.
- Pro (documented, [S4][S5]): log phases `PRE-INIT`, `INIT`, `PRE-OPEN`,
  `OPEN`, `PRE-CLOSE`, `CLOSE`, with levels info/debug/trace; dumps the FFmpeg
  filter graph per NLE track and muxer settings; menu option to open the log
  directory; log level dropdown; logging on/off; retention days; system info at
  the top of each log; coloured log view in Scene Test; a user-friendly message
  when FFmpeg is not found. The docs walk through an annotated sample log line
  by line, which is a useful support pattern.

### 1.8 Common user complaints

All user-reported unless noted.

- Plugin not visible in VEGAS Render As, especially after VEGAS upgrades, and
  version-specific plugin selection in the installer ([S4] documents the
  workaround; [S10] forum threads).
- Hardware encoders missing until driver updates ([S6]).
- Template behaviour: VEGAS template fields empty/0, freezes fixed by recreating
  the template from the stock one ([S8]); templates storing unrelated project
  settings ([S9]).
- Licensing/transition confusion between free Classic, Pro V2 and "Voukoder
  2026", worry about subscription-only pricing ([S10]).
- Inferred: a node graph is powerful but heavier than "fill out some dropdown
  boxes" (the docs' own words for Classic); Classic's option grid had no
  command preview and no way to type raw arguments.

## 2. StaxRip

Source: `github.com/staxrip/staxrip`, branch `master` (last push 2026-09-27),
files under `Source/` and `Docs/` read via raw.githubusercontent.com [S11].
StaxRip is a VB.NET WinForms front end that runs encoder CLIs (x264, x265,
NVEncC, QSVEncC, VCEEncC, SvtAv1EncApp and forks, aomenc, rav1e, vvencFFapp,
ffmpeg) as external processes, which is the same execution model as Vegas
Encoder's external FFmpeg.

### 2.1 Encoder options dialog

One generic form, `CommandLineForm`, renders every CLI encoder from a
declarative parameter list (seen in source, `Source/Forms/CommandLineForm.vb`,
`Source/Video/VideoEncoderCommandLine.vb`).

Layout (seen in source):

- Title: `"<Encoder> (<N> options) - <app version details>"`, so the user sees
  which binary build the options target.
- Left: a `TreeView` of pages (`SimpleUI.Tree`); right: the page's controls
  (checkboxes, numeric edits with labels, dropdown "menu blocks", text boxes).
  Page names containing `" | "` become nested tree nodes (e.g.
  NVEnc `VPP | Denoise 2`).
- Bottom: a **command line preview** (`CommandLineRichTextBox`), a **Search**
  combobox (cue text "Search"), a **Menu** button, **OK** / **Cancel**.

Pages (exact group names, seen in source):

| Encoder | Pages |
|---|---|
| x265 (`x265Enc.vb`) | Input, Output, Basic, Quad-Tree, Analysis, Coding Tool, Temporal / Motion Search, Spatial / Intra, Slice Decision, Slice Decision 2, Rate Control, Rate Control 2, Rate Control 3, Rate Control 4, Foveated Encoding, Loop Filter, VUI, VUI 2, Bitstream, Bitstream 2, Statistic, Reconstructed Video, Performance, Custom, Other |
| x264 (`x264Enc.vb`) | Basic, Analysis, Analysis 2, Rate Control, Rate Control 2, Rate Control 3, Motion Search, Slice Decision, Slice Decision 2, Statistic, VUI, Input/Output, Input/Output 2, Input/Output 3, Misc, Custom, Other |
| NVEncC (`NVEnc.vb`) | Input/Output, Basic, Rate Control, Slice Decision, Analysis, VPP \| Misc (1-3), VPP \| Colorspace, VPP \| Colorspace \| HDR2SDR, VPP \| Ngx-TrueHDR, VPP \| Deband, VPP \| Deinterlace (+ AFS 2), VPP \| Denoise (1-3), VPP \| LibPlacebo \| Deband / Shader / Tonemapping (1-2), VPP \| Resize, VPP \| Sharpness, VUI, VUI 2, Performance, Statistic, Misc, Other |
| SvtAv1EncApp (`SvtAv1Enc.vb`) | Input/Output, Basic, Rate Control, GOP size/type, AV1 Specific 1, AV1 Specific 2, Color Description, Variance Boost Options, Custom, Other |
| ffmpeg (`ffmpegEnc.vb`) | single "Main" page: Codec (grouped "AMD \| ...", "Intel \| ...", "Nvidia \| ...", "VP \| ..."), Mode, ... Custom |

x265 "Basic" page contents: Mode, Preset, Tune, Output Depth, Profile (three
variants shown only for the matching bit depth via `VisibleFunc`), Level, High
Tier, Quant, Bitrate, Ultra HD Blu-ray, Allow non conformance (seen in source).

Behaviour (seen in source unless noted):

- **Changed vs default**: a parameter emits its switch only when
  `Value <> DefaultValue` (or `AlwaysOn`) and it is visible, so the preview
  shows only changed options. Defaults are re-based on the selected preset and
  tune (`ApplyPresetDefaultValues`, `ApplyTuneDefaultValues`), so "default"
  means "what x265 would do with this preset". There is no separate visual
  "modified" marker on controls in the code read; the preview is the diff.
- **Reset**: double-click a label to reset that value to default; the in-app
  help says "Numeric values and dropdown menu options can be reset to their
  default value by double clicking on the label."
- **Search**: "The Search dropdown field at the dialog bottom left lists
  options ... it searches command line switches, labels and dropdowns.
  Multiple matches can be cycled by pressing enter." Matching control is shown
  bold.
- **Preview interaction**: context menu on the preview offers Copy Selection,
  Copy Command Line, and "Search <switch>" for the switch under the cursor;
  **Preview Mouse-Up Search** (Ctrl+P) "Clicking on an option in the preview
  navigates directly to the UI control"; **Command Line Highlighting**
  (Ctrl+H) colours the preview.
- **Menu button**: Execute Command Line (Ctrl+E), Copy Command Line
  (Ctrl+Shift+C), Show Command Line... (F4), **Import Command Line...**
  (Ctrl+I, parses clipboard back into controls), **Save Profile...** (Ctrl+S),
  Help about this dialog (F1), Help about <encoder> (Ctrl+F1).
- **Per-option help**: "The context help is shown by right-clicking a label,
  dropdown or checkbox." Help text is assembled from switch, no-switch,
  min/max for numbers, URLs and description. The F1 help page embeds the
  encoder's own console help (e.g. "x265 Console Help" from running the binary
  with its help switch) and an online-help link.
- **Custom free-form arguments**: page **Custom** with multi-line, code-font
  text boxes **Custom**, **Custom First Pass**, **Custom Last Pass**,
  **Custom Nth Pass** (NVEnc/SVT have Custom First/Second Pass variants). The
  `IsCustom(pass, switch)` check suppresses any generated switch that also
  appears in the custom text, so **custom text overrides the GUI** instead of
  producing duplicates. This is the single most transferable idea.
- **Override Target File Name** option on the encoder plus `%--crf%`-style
  encoder macros (2.3).

### 2.2 Profiles

Documented in `Docs/Usage/User-Interface/Main.md` [S12] unless noted.

- Main window Encoder/Container panel: a button showing the current encoder
  name opens a **menu of all encoder profiles**; `Edit Profiles...` opens the
  profiles dialog. A second button shows the target extension (MKV/MP4 or other
  with "No Muxing"). Buttons `Options`, `Target Name Override` (toggle),
  `Container Options`.
- Profiles dialog buttons (seen in source, `ProfilesForm.vb`): **Add...**,
  **Remove**, **Rename**, **Edit...**, **Clone**, **Load**, **Restore**, **OK**,
  **Cancel**.
- Audio rows: each audio track has a button with the current audio profile;
  clicking it lists profiles and `Edit Profiles...`; an `Edit` button opens the
  current profile.
- Project **templates** (whole-job settings) are separate from encoder
  profiles, support subfolders for opening, but the Save Template dialog cannot
  save into subfolders (documented, [S12]).

### 2.3 Macros

Documented in `Docs/Usage/Macros.md` [S13].

- Global macros include `%source_file%`, `%source_name%`, `%target_file%`,
  `%target_dir%`, `%target_name%`, `%temp_dir%`, `%working_dir%`,
  `%script_file%`, `%encoder%`, `%encoder_codec%`, `%encoder_ext%`,
  `%encoder_out_file%`, `%encoder_profile%`, `%audio_bitrate%`,
  `%current_date%`, `%current_time24%`, `%pos_frame%`, `%empty%`.
- Parameter macros: `%app_path:x265%`, `%app_dir:name%`, `%app_version:name%`,
  `%audio_file:track%`, `%audio_codec:track%`, `%eval:expression%`
  (PowerShell), `%random:digits%`, `%source_mi_v:property%` (MediaInfo).
- Interactive macros (seen in source, `Macro.vb`; the docs table is empty):
  `$browse_file$`, `$enter_text$`, `$enter_text:prompt$`,
  `$select:param1;param2;...$`.
- Encoder macros: `%--crf%`, `%--preset%` with modifiers `_D` (is default),
  `_L`, `_T`, `_U`, `_V` (index), `_Z` (active/visible). Example
  `%source_name%_CRF%--crf%_AQ-Mode%--aq-mode%` gives
  `%source_name%_CRF23_AQ-Mode2`.
- Function macros: `<if('%--preset%' = 'Medium'; Default; %--preset%)>` with
  DataColumn expression syntax.
- While-processing macros `%commandline%`, `%progress%`, `%progressline%` for
  event hooks; audio macros `%input%`, `%output%`, `%bitrate%`,
  `%channels%`, `%delay%`, `%language%`, `%streamid0%`.
- The macro editor (`MacroEditorDialog`) offers a macro picker and
  "Restore Defaults..." (seen in source, `CommandLineControl.vb`).

### 2.4 "Command Line" encoder

Seen in source (`CommandLineVideoEncoderForm.vb`, `CommandLineControl.vb`):
a generic video encoder whose whole definition is user text. Controls:
**Output File Type:** (extension), **Quality Mode** checkbox, a multi-line
**Command Line** editor with macro expansion (`Macro.ExpandGUI`) and a macro
editor, **Compressibility Check** with **Aimed Quality (%):**, **OK**,
**Cancel**. The audio counterpart (`CommandLineAudioEncoderForm.vb`) has
**Name:**, **Supported Input File Types:**, **Output File Type:**,
**Bitrate:**, **Channels:**, **Language:**, **Delay:**, **Track Name:**,
**Default** / **Forced** / **Commentary** flags, and a **Command Lines**
editor. This is the StaxRip equivalent of our Command mode.

### 2.5 Audio profiles

Seen in source (`AudioProfile.vb`, `AudioForm.vb`):

- Profile classes: `GUIAudioProfile` (form-driven), `BatchAudioProfile`
  (command lines), `MuxAudioProfile` (copy), `NullAudioProfile` (no audio).
- GUI encoders: Automatic, deezy, eac3to, fdkaac, ffmpeg, opusenc, qaac.
  Codecs: AAC, AC3, AC4, EAC3, DTS, FLAC, MP3, Opus, Vorbis, W64, WAV, None.
  Rate modes: CBR, ABR, VBR.
- Audio dialog "Basic" box: **Profile Name:**, **Codec:**, **Encoder:**,
  **Bitrate:**, **Quality:**, **Channels:**, **Sample Rate:**, **Gain:**,
  **Normalize**, **Center/Speech optimized Stereo**, **Delay:**,
  **Language:**, **Track Name:**, **Decoder:**, **Custom:**, flags **Default
  Track**, **Forced Track**, **Commentary Track**. "Advanced" box with a
  SimpleUI page tree (pages such as General, ffmpeg, "ffmpeg | loudnorm" =
  EBU R128 Loudness Normalization, "ffmpeg | dynaudnorm") behind **More...**,
  and the same command line preview.
- Encoder-specific fields appear dynamically: Stereo Downmix, Dynamic Range
  Comp., Rate Mode, Samples Per Frame, Atmos Mode, Frame Rate mode (Keep /
  Apply PAL speedup), Convert to 16-bit, Extract DTS core, Keep Temp Files.

### 2.6 Rate-control modes per encoder

Seen in source (the `Mode` / rate-control `OptionParam` in each class).

| Encoder | Modes exposed | Notes |
|---|---|---|
| x264 | Bitrate, Quantizer, Quality, Two Pass, Three Pass | Quality = `--crf`; Quantizer = `--qp` |
| x265 | Bitrate, Quantizer, Quality, Two Pass, Three Pass | default index 2 = Quality (CRF); `Quant` maps to `--crf`/`--qp` by mode |
| NVEncC | QVBR: Constant Quality Mode, CQP: Constant QP, CBR: Constant Bitrate, VBR: Variable Bitrate | Mode hidden when **Lossless** is ticked |
| SvtAv1EncApp | Quality (default), Variable Bitrate, Constant Bitrate | `--rc` |
| ffmpeg (generic) | Quality, One Pass, Two Pass | Mode hidden for prores, prores_ks, utvideo, cfhd, ffv1 |

## 3. HandBrake

Sources: HandBrake Windows WPF source (`win/CS/HandBrakeWPF`, `master`) for
exact labels [S21], and the docs repo `HandBrake/handbrake-docs` [S14][S15][S16].
"Seen in source" below refers to [S21].

**Video tab, quality** (seen in source, `VideoView.xaml`, `Resources.resx`,
`VideoViewModel.cs`):

- Radio choice **Constant Quality:** vs **Avg Bitrate (kbps):**; the
  constant-quality row shows the numeric value plus a bold rate-control name
  (`Rfqp`, i.e. "RF" or "QP" depending on encoder), then a slider bounded by
  encoder-specific `QualityMin`/`QualityMax`.
- Slider end labels: left **"| Lower Quality"**, right **"Placebo Quality |"**
  for x264 or **"Higher Quality |"** for other encoders.
- Bitrate mode adds **Multi-Pass Encoding** and **Turbo analysis pass**.
- "Lower RF means higher quality" for x264, x265, SVT-AV1; VideoToolbox is
  reversed, but "moving the control right increases quality" in all cases
  (documented, [S14]). Recommended ranges are given per resolution, e.g.
  1080p: RF 20-24 (x264/x265), RF 25-35 (SVT-AV1); "Always use constant
  quality unless you have a specific reason not to" (documented, [S14]).

**Video tab, encoder options** (seen in source): **Encoder Preset:** is a
**slider** (0..`VideoPresetMaxValue`) with the preset name shown beside it
(ultrafast ... placebo for x264), then **Encoder Tune:** dropdown,
**Fast Decode** checkbox, **Encoder Profile**, **Encoder Level**, and
**Advanced Options:** free text in `option1=value1:option2=value2` form
(CLI `--encopts`). The docs warn that available options "may vary with the
graphics driver/SDK version you have installed" (documented, [S16]).
"Lossless encoding only." appears for lossless-only encoders.

**Audio tab** (seen in source, `AudioView.xaml`): toolbar **Add Track**
(**Add New Track**, **Add All Remaining Tracks**, **Add All Remaining Selected
Languages**), **Reload**, **Configure Default Behaviours**, **Expand All** /
**Collapse All**. Each track row: **Source**, **Codec** (includes per-format
passthru and "Auto Passthru"), **Quality** with a mode switch between
**Audio Track Bitrate** and **Audio Encoder Quality Mode**, **Mixdown**,
**Samplerate**, **Gain**, **DRC**, remove button.

**Audio defaults** (documented, [S15]): presets store **rules**, not tracks:
Track Selection Behaviour (None / First matching selected Language / All
matching selected languages), Languages, **Auto Passthru** with "Allow
passthru of:" checkboxes, **Fallback Encoder** (used when passthru is
impossible), and a Track Layout list. Passthru rows' bitrate/mixdown/samplerate
apply to the fallback encoder.

**Presets** (documented [S15], seen in source):

- Built-in categories: General, Web, Devices, Matroska, Hardware, Production
  (plus Legacy/removed lists in docs). User presets live in their own
  category; "Built in presets can not be modified." (seen in source).
- Main window: **Save New Preset**; preset menu items **Edit Preset**,
  **Delete Preset**, **Import from file**, **Export to file**, "Set Current as
  Default" (Windows) / "Make Default" (macOS).
- When the current settings diverge from the selected preset the name shows
  **"(Modified)"** (seen in source, `MainView_ModifiedPreset`).
- Import/export single or many presets "for backup or sharing purposes";
  stored in `%AppData%\HandBrake\presets.json` on Windows (documented, [S15]).

## 4. Shutter Encoder and DaVinci Resolve Deliver page

### 4.1 Shutter Encoder

Documented in the official documentation page [S17]. Shutter Encoder is an
FFmpeg front end built around one **"Choose Function"** combobox whose entries
are grouped (AI Tools, Without Conversion, Sound Conversions, Editing Codecs,
Output Codecs, Broadcast Codecs, Old Codecs, Archiving Codec, Images Creation,
Burn & Rip, Analysis, Download). Typing filters the list, and the same field
accepts **a direct FFmpeg command without input and output**, with the
extension picked in the second combobox: a neat "Command mode in the same
control" idea. Settings are task-grouped collapsible panels (Image/Scale,
Bitrates Adjustment, Audio Settings, Colorimetry & Color Grading, Corrections,
Advanced Features with "Force profile", "Force preset", "Force tune / quality
/ speed", "Set GOP"). **Hardware acceleration** is a single off-by-default
option covering Nvidia/AMD/Intel, with separate GPU decoding (auto/none) and
GPU filtering (AUTO, CUDA, AMF, QSV, VULKAN, VIDEOTOOLBOX). Audio has an
"Audio 1-16" mapping (remove, reorder), "Mix audio files", "Separate audio
tracks", "Add a mute audio track". Presets are saved with Ctrl+S and opened
from a star icon; "Load at startup" applies one at launch. **"Use local
ffmpeg"** points at a user binary; "Show console" and right-click on
"Progress status" expose the full FFmpeg log. No per-job command preview is
documented.

### 4.2 DaVinci Resolve Deliver page

Official manual pages could not be fetched (mirrors returned 403/404). The
details below come from third-party guides and from search-result snippets
that quote the Resolve 18 manual, so treat all of it as user-reported and
unverified against Resolve 20 [S18][S19][S20]. The Deliver page puts **Render Settings** on the left:
a scrollable row of **render preset** icons at the top (with "Custom" exposing
everything), file name and **Browse** location, **Single clip** vs
**Individual clips**, then **Video**, **Audio**, **File** tabs ([S18] quotes
the manual's "four general sections" and the Single clip definition). The
Video tab has an **Export Video** checkbox; the Audio tab an **Export Audio**
checkbox, Format/Codec/Bit Depth, and an **Output Track 1** dropdown (Bus 1
(Stereo), Timeline Track N, All Timeline Tracks) with a **"+"** button adding
Output Track 2..n, plus "Render One Track per Channel" [S20]. Settings are
saved via the "..." menu next to the Render Settings title, "Save As New
Preset" [S18]. **Add to Render Queue** snapshots the current settings and range
as a job; the **Render Queue** at top right lists jobs, which can be selected
and started with **Render All**; users stress re-adding after any settings
change because a queued job is a snapshot [S18][S19]. Inferred relevance:
VEGAS already has its own queue (Render As, batch scripts), so Vegas Encoder
should not build a queue, but the "job = frozen snapshot of settings" and the
per-output-track audio mapping rows are good models.

## 5. Implications for Vegas Encoder

Opinionated, all **inferred** from the evidence above. Cross-check against
`docs/product/PRODUCT_SPEC.md` and `SETTINGS_AND_COMMANDS.md` (v1 has one
stereo audio stream, Guided and Command modes, a library plus template popup).

**Copy**

1. **Custom arguments override, never duplicate** (StaxRip `IsCustom`). Each
   stream in Guided mode gets an "Extra arguments" box; any option it names
   removes the generated one, and the preview marks the generated token as
   overridden. This removes the most common error when mixing GUI and raw
   flags.
2. **Always-visible live command preview that shows only changes** (StaxRip).
   Generate it from the same compiler the DLL uses, show only non-default
   options, highlight syntax, and support click-to-jump from a token to its
   control and "Copy command". As far as their source and docs show,
   neither Voukoder edition nor HandBrake shows a command; this is our
   clearest advantage over Voukoder.
3. **Defaults relative to the encoder preset** (StaxRip
   `ApplyPresetDefaultValues`). "Changed" means "differs from what this
   encoder preset would do". Unlike StaxRip, also put a visible modified dot
   on changed fields, a per-field reset (StaxRip: double-click the label) and
   a "Reset to preset" button (Voukoder: Reset/Clear).
4. **Data-driven encoder profiles with rate control first** (Voukoder JSON
   `groups` + `OnSelection`; StaxRip `VisibleFunc`). The first decision is
   the mode: Quality / Bitrate / Constant QP / Lossless, with the
   encoder-native name as secondary text ("Quality (CRF)", "QVBR", "CQ").
   Hide irrelevant fields instead of greying them out. Keep basic and
   advanced groups apart, as Voukoder's "Show advanced options" did.
5. **HandBrake's quality slider semantics.** Right always means better quality,
   whatever the scale direction. Show the value and its unit name
   (CRF/CQ/QP/qscale) and the encoder's range, and mark a recommended band
   per resolution (HandBrake gives RF 20-24 at 1080p for x264/x265).
6. **Encoder speed preset as a named slider** (HandBrake) mapped per encoder
   (x264 ultrafast..placebo, NVENC p1..p7, SVT-AV1 numeric presets), with tune
   as a dropdown beside it.
7. **Search across labels, switch names and option values** (StaxRip Search
   box). Pressing Enter cycles through matches. The help for each option
   comes from the selected FFmpeg build's own `-h encoder=<name>` output
   (StaxRip embeds x265's console help), so the help always matches the
   binary.
8. **Built-in vs user presets, "(Modified)", import/export** (HandBrake).
   Built-ins are read-only and "Clone" makes an editable copy (StaxRip
   ProfilesForm). Show "(Modified)" when the editor diverges from the loaded
   preset. Import/export one or many presets as one JSON file per preset so
   they are easy to share or keep in git.
9. **A "test this preset" button** (Voukoder Pro Scene Test). From the desktop
   app, run the real FFmpeg on synthetic frames (choose resolution, frame rate,
   pixel format and audio layout; N frames; output to `NUL` or a file) and
   stream the log. This lets users find failing hardware encoders and bad
   flags without starting a VEGAS render.
10. **Logging like Voukoder** with a system-info header (CPU, GPU/driver,
    FFmpeg path, version and hash), phase markers, a retention period in days,
    "Open log folder", and an optional log next to the output file. Annotated
    sample logs in the docs (Voukoder Pro) help with support.
11. **An "Open in Vegas Encoder" button in the popup** (Resolve's "Open Scene
    Designer ..."). The popup stays small, and the desktop app is one click
    away for library work.

**Avoid**

12. **Voukoder Classic's two-level tab maze** (category notebook > Encoder /
    Options / Side data / Filters sub-tabs) and its preset-then-**Apply** step.
    In the popup, use one Video / Audio / Output / Command strip. Choosing a
    preset applies it straight away and can be undone.
13. **Making the VEGAS template the only store** (Classic), or making it depend
    on an external scene file (Pro). The template should hold a complete recipe
    snapshot, so it renders on another machine without the library, plus an
    optional link (preset id and revision). The popup then shows "linked to X;
    the library has a newer revision: Update / Detach" (flows F3/F4). Never
    write VEGAS project settings into the recipe. Users complained about
    templates capturing unrelated settings.
14. **Hard-blocking compatibility checks.** Voukoder Pro's red "invalid
    combination" muxer box had to be removed to allow ProRes in MXF. Use
    amber warnings with a reason ("Opus in MP4 needs a recent player"), keep
    the matrix in data, and block only on combinations known to fail with the
    selected FFmpeg build, ideally confirmed by a probe.
15. **A node graph in v1** (Voukoder Pro). It costs a lot to build and learn
    ("instead of filling out some dropdown boxes"). Command mode covers the
    long tail (filter chains, `tee`, multiple outputs), and post-render scripts
    can come later.

**Gaps none of them solve well**

16. **Hardware encoder availability that users can trust.** An encoder that
    `ffmpeg -encoders` lists can still fail on the user's GPU or driver
    (Voukoder users: "only qsv" until a driver update). Probe each hardware
    encoder with a short test encode, cache the result per FFmpeg hash and
    driver version, and show Available / Listed but failing (with the error
    line) / Not in this build (for example LGPL builds without x264).
17. **The FFmpeg build is part of the preset contract.** Show the build in the
    editor header (StaxRip's title shows the app version). Presets record the
    encoders and minimum FFmpeg version they require, and on import or
    library sync the app lists any unmet requirements.
18. **Command mode with the pipe plumbing hidden.** As in Shutter Encoder,
    users type an FFmpeg command "without input and output", and StaxRip-style
    macros (`%target_file%`, `%target_name%`, `%encoder_ext%`) fill in the
    rest. Our extra step is linting before render. The engine owns the input
    pipes and the output path, so a user command cannot break the host
    contract. "Import command line" (StaxRip Ctrl+I) converts a pasted
    command into Guided settings where possible.
19. **Install discoverability in VEGAS.** Voukoder Pro users repeatedly could
    not find the plugin. They had to pick per-version plugin paths by hand, and
    on VEGAS 23 Voukoder Pro only appears after ticking "Show all formats". The
    desktop app should detect VEGAS installs, show the plugin status, explain
    the Components-tab check, and record reversible install steps. It must
    never replace an installed exporter silently.
20. **Plan for multi-track audio without shipping it.** v1 is one stereo
    stream. Model audio as a list of rows (HandBrake: per-track codec,
    bitrate, mixdown; Resolve: Output Track 1 plus "+") so a later version
    can add tracks without a schema break. Show the current limit plainly;
    even Voukoder Pro supports multi-track input only from Resolve.

Unknowns worth checking in a real VEGAS run (none ran for this note): whether
VEGAS 2026 lists Vegas Encoder in Render to New Track and Selectively
Prerender. Voukoder did not appear in either (user-reported, [S7]).

## Sources

All accessed 2026-10-11. "Fetched" means the page or file content was read;
"snippet" means only a search-engine summary was seen, so the claim is weaker.

| ID | Source | How used |
|---|---|---|
| S1 | https://github.com/alinsavix/voukoder (README; mirror of the now-404 `github.com/Vouk/voukoder`) | fetched |
| S2 | https://github.com/alinsavix/voukoder/tree/master/Core: `src/wxVoukoderDialog.cpp`, `src/wxEncoderPage.cpp`, `src/wxEncoderPanel.cpp`, `src/wxOptionEditor.cpp`, `src/wxFilterPanel.cpp`, `src/Log.cpp`, `resources/presets.json`, `resources/encoders/libx264.json`, `resources/translations/en.json`, `resources/video_side_data.json`; and https://github.com/alinsavix/voukoder/blob/master/Voukoder/VoukoderTypeLib.idl | fetched (raw) |
| S3 | https://github.com/virare/voukoder-connectors (README.md, vegas/README.md) | fetched |
| S4 | https://docs.voukoderpro.com/, source https://github.com/Vouk/voukoderpro.github.io/blob/master/index.md | fetched (raw) |
| S5 | https://github.com/Vouk/voukoderpro.github.io/blob/master/changelog.md | fetched (raw) |
| S6 | https://www.voukoder.org/forum/thread/669-will-voukoder-be-ready-for-vegas-pro-18/?pageNo=3 | fetched |
| S7 | https://voukoder.org/forum/thread/766-voukoder-encoder-in-render-to-new-track-and-selectively-prerender-video-options | snippet |
| S8 | https://www.voukoder.org/forum/thread/1731-voukoder-pro/ | fetched |
| S9 | https://www.voukoder.org/forum/thread/934-option-to-set-encoder-to-nvidia-nvenc-by-default/ | snippet |
| S10 | https://www.voukoder.org/forum/thread/1736-voukoder-2026-not-appearing-in-vegas-pro-23, https://www.voukoder.org/forum/thread/1657-confusion-about-the-voukoder, https://www.voukoder.org/forum/thread/1711-voukoder-pro-2026/ | snippet |
| S11 | https://github.com/staxrip/staxrip (master): `Source/Forms/CommandLineForm.vb` (+ `.Designer.vb`), `Source/Video/VideoEncoderCommandLine.vb`, `Source/Encoding/x265Enc.vb`, `x264Enc.vb`, `NVEnc.vb`, `SvtAv1Enc.vb`, `ffmpegEnc.vb`, `Source/Forms/CommandLineVideoEncoderForm.vb`, `CommandLineAudioEncoderForm.vb`, `AudioForm.vb`, `ProfilesForm.vb`, `Source/General/AudioProfile.vb`, `Macro.vb`, `Source/Controls/CommandLineControl.vb`, `Source/UI/SimpleUI.vb` | fetched (raw) |
| S12 | https://github.com/staxrip/staxrip/blob/master/Docs/Usage/User-Interface/Main.md, `Save-Template.md`, `Template-Selection.md` | fetched (raw) |
| S13 | https://github.com/staxrip/staxrip/blob/master/Docs/Usage/Macros.md | fetched (raw) |
| S14 | https://handbrake.fr/docs/en/latest/workflow/adjust-quality.html | fetched |
| S15 | https://github.com/HandBrake/handbrake-docs, `source/docs/en/latest/advanced/custom-presets.markdown`, `workflow/select-preset.markdown`, `advanced/audio-subtitle-defaults.markdown`, `technical/official-presets.markdown` | fetched (raw) |
| S16 | https://github.com/HandBrake/handbrake-docs/blob/master/source/docs/en/latest/technical/video-presets-tunes.markdown | fetched (raw) |
| S17 | https://www.shutterencoder.com/documentation/ | fetched |
| S18 | https://www.steakunderwater.com/VFXPedia/__man/Resolve18-6/DaVinciResolve18_Manual_files/part3921.htm (Resolve 18 manual mirror; 404 on fetch), https://www.miracamp.com/learn/davinci-resolve/how-to-render | snippet |
| S19 | https://blog.raw.film/how-to-work-with-davinci-resolve-render-settings/ | fetched |
| S20 | https://beginnersapproach.com/davinci-resolve-export-single-multiple-audio-timeline-tracks/ | fetched |
| S21 | https://github.com/HandBrake/HandBrake/tree/master/win/CS/HandBrakeWPF: `Views/VideoView.xaml`, `Views/AudioView.xaml`, `Views/MainView.xaml`, `ViewModels/VideoViewModel.cs`, `Properties/Resources.resx` | fetched (raw) |

Not done: no installer, MSI or binary from any of these projects was
downloaded or run, and no VEGAS, Voukoder, StaxRip, HandBrake, Shutter Encoder
or Resolve UI was run or screenshotted. Screenshots on the Voukoder Pro docs
and StaxRip docs pages were not inspected (text only).
