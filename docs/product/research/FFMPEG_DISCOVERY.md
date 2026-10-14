# FFmpeg discovery, capability probing and qualification

Updated: 2026-10-11. Research for the Vegas Encoder configurator (Flutter) and exporter DLL.

**Note (2026-10-12):** the product targets Windows only. The [L] results below are a
design-time record; P1 recaptures them with Windows FFmpeg builds, and those captures
become the fixtures. Linux-only paths (VAAPI, `mkfifo`) are kept for reference only.

**B1 update (2026-10-13):** [Windows recapture](FFMPEG_WINDOWS.md) now provides the
measured gyan/BtbN facts used by the native core. It supersedes the Linux-derived
defaults/compatibility/timing assumptions where they differ. Labels and results
below remain the original design research; no native VEGAS gate changed.

**Evidence labels used below**

- **[L]** = verified with FFmpeg 8.1.3 on Linux (Fedora build `/usr/bin/ffmpeg`, `--enable-shared --enable-gpl
  --enable-version3`, libavcodec 62.28.103; AMD Ryzen AI MAX+ 395 / Radeon 8060S iGPU, no NVIDIA/Intel GPU).
- **[W]** = documented for Windows builds or derived from FFmpeg behavior, **not tested on Windows here**.
- **No real VEGAS test and no Windows test ran for this research.**

Raw evidence (git-ignored):

| Folder | Contents |
| --- | --- |
| `evidence/2026-10-11-product-design/ffmpeg-probe/` | `-version`, `-encoders`, `-muxers`, `-pix_fmts`, `-h encoder=` (24 encoders), `-h muxer=` (5), first hardware probes |
| `evidence/2026-10-11-product-design/container-matrix/` | `matrix.py` (exact script), `matrix-results.json` (commands, stderr, ffprobe readback), `matrix-summary.tsv`, `matrix-run.log` |
| `.../container-matrix/supplementary/` | `hwprobe.py` + `hwprobe-results.json`/`-summary.tsv`/`-run.log`; `probe-cost.sh` + `probe-cost.tsv`; `hfull-census.txt`, `hfilter-census.txt`; `progress-pipe-pixfmt.txt` (progress keys, `-ch_layout`, FIFO, hw pix_fmts) |

---

## 1. Installation discovery on Windows

### 1.1 Where to look [W]

Search in this order; de-duplicate by the *resolved real path* (see shims below).

| Source | Location(s) | Notes |
| --- | --- | --- |
| User choice ("Browse…") | any `ffmpeg.exe` | Always offered; the only option guaranteed to work. Store the absolute path. |
| `PATH` | `SearchPathW`/`where.exe ffmpeg` over the *configurator's* environment | The VEGAS process inherits PATH from when VEGAS started. A newly installed PATH entry is invisible to an already-running VEGAS, so the DLL must use the stored absolute path, never PATH. |
| winget (portable packages, user scope) | `%LOCALAPPDATA%\Microsoft\WinGet\Links\ffmpeg.exe` (symlink placed on PATH) → `%LOCALAPPDATA%\Microsoft\WinGet\Packages\<PackageId>_<source>\…\bin\ffmpeg.exe` | Machine scope uses `%ProgramFiles%\WinGet\Links` / `%ProgramFiles%\WinGet\Packages`. gyan.dev documents `winget install ffmpeg` (full), `winget install "FFmpeg (Essentials Build)"`, `winget install "FFmpeg (Shared)"`. Package IDs seen in winget-pkgs (`Gyan.FFmpeg`, `Gyan.FFmpeg.Essentials`, `BtbN.FFmpeg.*`) are **unverified here**; glob `Packages\*FFmpeg*\**\ffmpeg.exe` instead of hard-coding IDs. |
| Scoop | `%SCOOP%\apps\<app>\current\bin\ffmpeg.exe` (default `%USERPROFILE%\scoop`); global `%SCOOP_GLOBAL%` (default `%ProgramData%\scoop`) | `<app>` = `ffmpeg`, `ffmpeg-essentials`, `ffmpeg-shared`, `ffmpeg-gyan-nightly` (gyan.dev list). `%SCOOP%\shims\ffmpeg.exe` is a launcher shim; its `ffmpeg.shim` text file holds `path = "…"` to the real exe. |
| Chocolatey | `%ChocolateyInstall%\bin\ffmpeg.exe` (shim; default `C:\ProgramData\chocolatey`) → `%ChocolateyInstall%\lib\ffmpeg*\tools\**\bin\ffmpeg.exe` | Packages `ffmpeg` (essentials) and `ffmpeg-full` per gyan.dev. |
| Manual unzip | `C:\ffmpeg\bin`, `%ProgramFiles%\ffmpeg\bin`, `%USERPROFILE%\ffmpeg\bin`, `%LOCALAPPDATA%\Programs\ffmpeg\bin` | Convention only; scan cheaply (existence check), never recursively scan drives. |

Shims: hash/identify the **real target**, not the shim. A shim spawns a child `ffmpeg.exe`; Vegas Encoder's process ownership (job object) and stderr capture must apply to the real process. Resolve: winget `Links` entries are symlinks (`GetFinalPathNameByHandleW`); Scoop/Chocolatey shims → read the `.shim` file (Scoop) or, failing that, ask the user to browse to the real binary.

### 1.2 Identifying an installation

| Field | How | Example [L] |
| --- | --- | --- |
| Version string | `ffmpeg -hide_banner -version`, line 1 `ffmpeg version <V> Copyright …` | `ffmpeg version 8.1.3 Copyright (c) 2000-2026 the FFmpeg developers` |
| Version forms [W] | release `8.1.3`; gyan release `8.0-full_build-www.gyan.dev`; gyan git `2026-10-09-git-<hash>-full_build-www.gyan.dev`; BtbN `n8.1-…` or `N-<n>-g<hash>-<date>` | Parse leniently; keep the raw string. Treat libavcodec/libavformat versions as the reliable compatibility key. |
| Configure flags | `-version` line `configuration: …` or `ffmpeg -hide_banner -buildconf` (one flag per line) | `--enable-gpl`, `--enable-version3`, `--enable-nonfree` (absent here), `--enable-nvenc`, `--enable-libvpl`, `--enable-libsvtav1`, `--enable-shared` |
| Library versions | `-version` lines `libavcodec     62. 28.103 / 62. 28.103` (compiled / runtime) | Mismatch between the two numbers indicates a shared build loading different DLLs. |
| Structured version | `ffprobe -v error -of json -show_versions` | JSON `program_version.version`, `.configuration`, `library_versions[].{name,major,minor,micro,ident}` [L] |
| Cache identity | SHA-256 + size + mtime of the real `ffmpeg.exe`; for shared builds add SHA-256 of `av*.dll`, `sw*.dll`, `postproc*.dll` in the same folder | Shared builds keep codecs in DLLs, so the exe hash alone does not identify them. |
| License class | configure flags: `--enable-nonfree` → nonfree; `--enable-gpl` → GPL (v3 if `--enable-version3`); neither → LGPL | Shown in the UI next to the installation. |

`ffprobe`: look for `ffprobe.exe` in the same directory as the resolved `ffmpeg.exe`. Accept it only if
`ffprobe -show_versions -of json` reports the same `version` and `configuration` as `ffmpeg -version`;
otherwise mark "ffprobe missing/mismatched" (readback verification degrades to ffmpeg-only checks).

### 1.3 Well-known Windows builds [W]

| Build | Linking | License | Notes (from vendor pages) |
| --- | --- | --- | --- |
| gyan.dev release/git **essentials** | static exe | GPLv3 | includes libx264, libx265, libxvid, zimg…; hardware: amf, cuda, cuvid, d3d11va, d3d12va, dxva2, libvpl (QSV), nvdec, nvenc |
| gyan.dev **full** | static exe | GPLv3 | adds e.g. libsvtav1 and many more libraries |
| gyan.dev **full shared** | exe + DLLs | GPLv3 | release only |
| BtbN `gpl` / `gpl-shared` | static / shared | GPL | "Includes all dependencies, even those that require full GPL" |
| BtbN `lgpl` / `lgpl-shared` | static / shared | LGPL | "Lacking libraries that are GPL-only. Most prominently libx264 and libx265." |
| BtbN `nonfree` / `nonfree-shared` | static / shared | nonfree | "Includes fdk-aac in addition to all the dependencies of the gpl variant." |

BtbN targets: `win64`, `winarm64` (auto-builds), Windows 7+ with UCRT; release-branch variants (`7.1`, `8.0`, …) or master; a floating `latest` release.

### 1.4 Licensing implications

| Product behavior | Implication |
| --- | --- |
| **User-supplied FFmpeg only** (current baseline; STATUS: "no binaries are distributed") | Vegas Encoder runs FFmpeg as a separate process and passes arguments/pipes; it does not link FFmpeg. The user obtained and is responsible for the build. Lowest obligation. Any build (including GPL and the user's own nonfree build) can be used. |
| **App downloads FFmpeg for the user** | Becomes (or facilitates) distribution. FFmpeg legal checklist (LGPL): build *without* `--enable-gpl`/`--enable-nonfree`, ship/host the matching source "on the same webserver as the binary", configure line, notices in About/EULA. GPL builds (gyan, BtbN gpl) carry GPL source-offer duties for the binary. **Never** download/redistribute `--enable-nonfree` builds: FFmpeg states nonfree "will cause the resulting binary to be unredistributable" (e.g. Fraunhofer FDK AAC). |
| Pointing users to vendor pages | Lowest-risk "assisted" option: open the vendor URL/winget command; the user performs the install. |

Not legal advice; a project license is not yet selected (AGENTS.md).

---

## 2. Capability probing and parsing specification

All commands [L]; always pass `-hide_banner`. Help/listing output goes to **stdout**; logs go to stderr.

| Purpose | Command | Notes |
| --- | --- | --- |
| Build/version | `-version`, `-buildconf` | |
| Encoders | `-encoders` | 6-char flags |
| Muxers | `-muxers` (or `-formats` for both directions) | 3-char flags |
| Pixel formats | `-pix_fmts` (text) or `ffprobe -of json -show_pixel_formats` (JSON, preferred) | |
| Sample formats | `-sample_fmts` | `name depth` table |
| Channel layouts | `-layouts` | "Individual channels" + "Standard channel layouts" |
| HW methods / device types | `-hwaccels`, `-init_hw_device list` | lists *compiled-in* types only (here: vdpau cuda vaapi qsv drm opencl vulkan amf) |
| Encoder detail | `-h encoder=<name>` | spec below |
| Muxer detail | `-h muxer=<name>` | same option grammar; flags column `E..........` |
| Filter detail | `-h filter=<name>` | same option grammar, plus Inputs/Outputs blocks |
| Everything | `-h full` | includes generic `AVCodecContext AVOptions` (`-b`, `-g`, `-bf`, `-maxrate`…) |

**Help-mode quirks [L]:** every `-h …` output ends with a blank line and `Exiting with exit code 0` on stdout,
even with `-loglevel error`. Unknown names also exit **0**: `Codec 'prores_videotoolbox' is not recognized by FFmpeg.` /
`Unknown format 'nonexistent_y'.` → detect failure from the first line, never from the exit code.

### 2.1 `-encoders`

```
Encoders:
 V..... = Video            A..... = Audio            S..... = Subtitle
 .F.... = Frame-level multithreading   ..S... = Slice-level multithreading
 ...X.. = Codec is experimental        ....B. = Supports draw_horiz_band
 .....D = Supports direct rendering method 1
 ------
 V..... libsvtav1            SVT-AV1(Scalable Video Technology for AV1) encoder (codec av1)
 VFS..D dnxhd                VC3/DNxHD
 V..X.D avui                 Avid Meridien Uncompressed
```

(Legend lines abbreviated above; the real output prints one legend entry per line.) 235 encoders are listed in this build [L].

Rules: skip until the line ` ------`. Entry regex: `^ ([VAS.])([F.])([S.])([X.])([B.])([D.]) (\S+)\s+(.*)$`.
Codec id = trailing `\(codec (\S+)\)$` when present, else the encoder name (`dnxhd` → codec `dnxhd`;
`libsvtav1 … (codec av1)`). `X` = requires `-strict experimental` to use.

### 2.2 `-muxers`

Legend `D.. = Demuxing supported`, `.E. = Muxing supported`, `..d = Is a device`, then ` ---`.
Entries ` %c%c%c %-15s %s`, e.g. `  E  mp4             MP4 (MPEG-4 Part 14)`, `  Ed alsa            ALSA audio output`.
Regex `^ ([D ])([E ])([d ]) (\S+)\s+(.*)$`; exclude devices (`d`). `-h muxer=X` adds
`Common extensions: mkv.`, `Mime type: …`, `Default video codec: h264.`, `Default audio codec: vorbis.` (trailing `.`).

### 2.3 `-pix_fmts`, `-sample_fmts`, `-layouts`

- `-pix_fmts`: legend `I.... input`, `.O... output`, `..H.. hardware`, `...P. paletted`, `....B bitstream`; columns
  `FLAGS NAME NB_COMPONENTS BITS_PER_PIXEL BIT_DEPTHS` (e.g. `IO... yuv420p 3 12 8-8-8`). Prefer
  `ffprobe -of json -show_pixel_formats` (267 formats here) which gives `log2_chroma_w/h`, `flags.{rgb,alpha,hwaccel,planar}`
  and per-component `bit_depth` — exactly what bit-depth/chroma warnings need (§6).
- `-sample_fmts`: `u8 8`, `s16 16`, `s32 32`, `flt 32`, `dbl 64`, planar `…p`, `s64`.
- `-layouts`: names may contain parentheses (`3.0(back)`, `5.1(side)`, `7.1(wide)`).

### 2.4 `-h encoder=X` grammar

```
Encoder libx264 [libx264 H.264 / AVC / MPEG-4 AVC / MPEG-4 part 10]:     <- header
    General capabilities: dr1 delay threads                              <- note trailing space
    Threading capabilities: other
    Supported hardware devices: cuda cuda                                <- (hw encoders) duplicates possible
    Supported pixel formats: yuv420p yuvj420p … gray gray10le
    Supported sample rates: 96000 88200 … 7350                           <- audio
    Supported sample formats: fltp
    Supported channel layouts: mono stereo … 5.1
libx264 AVOptions:                                                       <- AVClass name, NOT the encoder name
  -preset            <string>     E..V....... Set the encoding preset (cf. x264 --fullhelp) (default "medium")
  -aq-mode           <int>        E..V....... AQ method (from -1 to INT_MAX) (default -1)
     none            0            E..V.......
     autovariance-biased 3            E..V....... Auto-variance AQ with bias to dark scenes
```

| Element | Rule | Real examples [L] |
| --- | --- | --- |
| Header | `^Encoder (\S+) \[(.*)\]:$` | `Encoder hevc_nvenc [NVIDIA NVENC hevc encoder]:` |
| Not found | `^Codec '(.*)' is not recognized by FFmpeg\.$` (exit 0) | `prores_videotoolbox` on Linux |
| General capabilities | split on spaces, trim; tokens seen: `dr1 delay threads small hardware hybrid variable` | `delay hybrid` (QSV), `dr1 variable` (pcm), `threads` (prores_ks) |
| Threading | one of `none`, `frame`, `slice`, `frame and slice`, `other` | `frame and slice` (dnxhd) |
| HW devices | split + de-duplicate | `qsv qsv qsv` |
| Pixel formats | split; includes hw surface formats (`cuda`, `qsv`, `vaapi`) — drop `..H..` formats for system-memory input | `h264_vaapi`: only `vaapi` → needs `hwupload` |
| Sample rates/formats | split | `aac` rates end `7350`; `libfdk_aac`: `s16` only |
| Channel layouts | **do not split on spaces**: tokens like `2 channels (FC+LFE)`, `4 channels (FL+FR+LFE+BC)`. Use regex `\d+ channels \([^)]*\)\|\S+` | ac3/eac3 lines |
| Line absent | means "not restricted/not declared", not "none" | `libsvtav1` has no sample/rate lines |
| AVOptions header | `^(.+) AVOptions:$` | `AAC encoder AVOptions:`, `alacenc AVOptions:`, `ProRes encoder AVOptions:` |
| No options | header missing entirely | `pcm_s24le` |
| End | blank line, then `Exiting with exit code 0` | |

**Option line** (two-space indent, leading `-`). Tokenize by whitespace, **not fixed columns** — long names break
alignment: `  -min_prediction_order <int>        E...A...... (from 1 to 30) (default 4)`,
`  -single-slice-intra-refresh <boolean>    E..V....... Use single slice intra refresh (default false)`.

1. `name` = token 1 without `-`; `type` = `<…>` or array form `[<…>]`; `flags` = the next 11 chars.
   Array types can be **glued to the flags with no space**: `  -view_ids_available [<unsigned>].D.V..XR... Array of available view IDs is exported here`,
   `   sample_fmts       [<sample_fmt>]..F.A...... A '|'-separated list of sample formats.` [L]. Use the regex
   `^\s+-?(\S+)\s+(\[?<[^>]+>\]?)\s*([E.][D.][F.][V.][A.][S.][X.][R.][B.][T.][P.])\s?(.*)$`.
2. Rest = help text. Parse **from the right**: strip `\s*\(default (.*)\)$`, then `\s*\(from (\S+) to (\S+)\)$`.
   Descriptions themselves contain parentheses (`Use A53 Closed Captions (if available) (default true)`,
   `Set the encoding preset (cf. x264 --fullhelp)`), so left-to-right parsing fails.
3. Help may be empty: `  -speed <int> E..V.......  (from -16 to 16) (default 1)`; `-store_user_comments <boolean> E..........  (default true)`.
4. Help may have a trailing space (NVENC constants `E..V....... `). Trim.

**Flags column (11 chars)** [L — every position observed with its letter in `-h full` or filter help, §2.6]:

| Pos | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Char | `E` encoding | `D` decoding | `F` filtering | `V` video | `A` audio | `S` subtitle | `X` export | `R` read-only | `B` bsf | `T` runtime-settable | `P` deprecated |

Encoder options show `E..V.......` / `E...A......`; muxer options `E..........`; filter options `..FV.....T.`.
`P` marks deprecated options (`-dc <int> E..V......P deprecated; use intra_dc_precision …`) — hide them in the
structured editor. `X`/`R` (export/read-only) options are outputs, never arguments.

**Filter help differs** [L]: `-h filter=scale` prints `Filter scale`, a description, `Inputs:`/`Outputs:` blocks
(`#0: default (video)`), then `scale AVOptions:` with option lines indented **three spaces and without `-`**
(`   w                 <string>     ..FV.....T. Output video width`); constants keep the five-space indent.

**Enum constant lines** (five-space indent, no `-`): `name`, optional integer `value`, flags, optional help.
Identify the flags token by regex `^[E.][D.][F.][V.][A.][S.][X.][R.][B.][T.][P.]$`; anything between name and flags is the value.

| Case | Example [L] | Rule |
| --- | --- | --- |
| Numeric names | `     1.0             30           E..V.......` (hevc_nvenc `-level`) | name is a string even if numeric |
| Aliases (same value) | `ll_2pass_quality 8388609`, `vbr_hq 8388609`; `cavlc 0`/`vlc 0` | keep all; display first, accept all |
| Negative values | `default -1`, `auto -1` | |
| No value (flags-type or boolean consts) | `     faststart                    E.......... Run a second pass…`; `     auto                         E..V.......` (libx265 `-dolbyvision`) | value = null; for `<flags>` the constant name is the bit |
| Long names push alignment | `     autovariance-biased 3            E..V.......` | token-based parsing |
| "(default)" inside help | `     notindicated    0            E...A...... Not Indicated (default)` | not the option default |
| Help absent | `     none            0            E..V.......` | |

**Defaults / ranges** — values are not always numbers:

| Form | Examples [L] | Interpretation |
| --- | --- | --- |
| Quoted string | `(default "medium")`, `(default "Lavc")` | string default |
| Constant name | `(default twoloop)`, `(default p4)`, `(default main)`, `(default good)` → `1000000`, `(default default)` | resolve via the option's constants |
| Boolean | `(default true)`, `(default false)`, `(default auto)` | `auto` = -1 (unset) |
| Flags | `(default 0)`, `(default identifier+timing+recovery_point+a53_cc)` | `+`-joined constants |
| Limits | `INT_MIN`, `INT_MAX`, `I64_MAX`, `FLT_MAX` (e.g. `(from -1 to FLT_MAX)`, `(default INT_MIN)`, `(default INT_MAX)`) | map to numeric limits; treat as "unbounded" in UI |
| Float notation for ints | `(from 0 to 2.68435e+08)` (h264_vaapi `-max_frame_size <int>`) | parse as double, then clamp/round |
| Fractional bound on `<int>` | `(from -31.75 to 0)` (libfdk_aac `-drc_target_ref <int>`) | do not assume integer bounds |
| No default printed | `-tune <string>`, `-x264-params <dictionary>` | unset/null |

**Type tokens** — full list observed in this build in §2.6. Seen in the captured encoder/muxer files:
`int`, `int64`, `float`, `string`, `boolean`, `flags`, `dictionary`, `binary`. UI mapping:

| Type | Widget | Argument form |
| --- | --- | --- |
| `int`/`int64` with constants | dropdown (+ numeric if range allows) | `-opt name` or `-opt value` |
| `int`/`int64`/`unsigned`/`float`/`double` | numeric with range | `-opt 23` |
| `boolean` | tri-state (default/true/false) when default is `auto` | `-opt 1`/`0` |
| `flags` | multi-select | `-opt +a+b` / `-opt -a` |
| `string` | text (may have curated choices, e.g. libx264 `preset`) | |
| `dictionary` | key=value list editor (`k=v:k2=v2`) | |
| `rational`, `video_rate`, `image_size`, `pix_fmt`, `sample_fmt`, `channel_layout`, `color`, `duration`, `binary` | specialized or advanced-only | |

### 2.5 Private vs generic options; curated knowledge required

- `-h encoder=X` lists only the encoder's **private** options. Generic `AVCodecContext` options (`-b:v`, `-maxrate`,
  `-bufsize`, `-g`, `-bf`, `-qmin`, `-qmax`, `-threads`, `-profile`, `-level`, …) appear only in `-h full`, and FFmpeg
  does not report which generic options a given encoder honors. Name collisions exist: libx264 private
  `-profile <string>` vs hevc_nvenc private `-profile <int>` enum vs dnxhd `-profile <int>`.
- **Encoder-library parameter strings are opaque**: `-x264-params`, `-x265-params`, `-svtav1-params` (type
  `<dictionary>`), `-qsv_params`, `-x264opts`. Their keys come from x264/x265/SVT-AV1 documentation, not AVOptions.
- Rate-control modes are encoder-specific and not described structurally (libx264 `-crf <float>`, libsvtav1
  `-crf <int> 0–63`, libvpx-vp9 `-crf` + `-b:v 0`, NVENC `-rc` enum + `-cq`, VAAPI `-rc_mode`, QSV via generic
  options). The structured editor therefore needs a **curated recipe table** per encoder (modes → arguments),
  validated against the parsed options (option exists, value within range, constant exists) at probe time.

### 2.6 Full option-type, range-literal and flags census [L]

From `ffmpeg -hide_banner -h full` (1,282,833 bytes, 17,652 lines, 0.07 s) plus `-h filter=` for every filter
(`supplementary/hfull-census.txt`, `hfilter-census.txt`):

| Item | Values observed (count in `-h full`) |
| --- | --- |
| Type tokens | `int` 1922, `boolean` 655, `string` 401, `float` 171, `flags` 97, `video_rate` 75, `int64` 66, `image_size` 56, `channel_layout` 45, `binary` 37, `duration` 28, `dictionary` 27, `rational` 19, `double` 18, `sample_fmt` 13, `pix_fmt` 9, `unsigned` 6, `color` 1; arrays `[<unsigned>]`, `[<int>]`, `[<sample_fmt>]`, `[<channel_layout>]`, `[<pix_fmt>]` (filters) |
| Symbolic range literals | `INT_MAX`, `INT_MIN`, `FLT_MAX`, `-FLT_MAX`, `I64_MAX`, `I64_MIN`, `DBL_MAX`, `-DBL_MAX`, `DBL_MIN`, `UINT32_MAX` |
| Numeric range forms | integers, decimals (`0.015625`), exponents (`1e-05`, `1.07374e+09`, `2.68435e+08`, `1.84467e+19`) |
| Flags letters by position | 1 `E`, 2 `D`, 3 `F` (filters only), 4 `V`, 5 `A`, 6 `S`, 7 `X`, 8 `R`, 9 `B`, 10 `T` (filters), 11 `P` |

`-h full` contains every AVClass's options (1093 `… AVOptions:` sections), but **no** `Encoder …` headers and no
`Supported …` capability lines, and class names are ambiguous (`ProRes encoder AVOptions:` appears 3 times).
Per-encoder `-h encoder=X` is therefore required for capabilities and for unambiguous option attribution;
`-h full` is useful once for the generic `AVCodecContext AVOptions:` and muxer-generic sections.

---

## 3. Hardware encoder qualification

`-encoders` lists what was **compiled in**, not what works. This Linux build lists `h264_nvenc`, `hevc_qsv`,
`av1_amf`, `h264_vaapi`, `h264_vulkan` … on a machine with no NVIDIA or Intel GPU. Qualify by a test encode.

### 3.1 Probe command

```
ffmpeg -hide_banner -nostdin -v error [device setup]
       -f lavfi -i color=c=black:s=256x144:r=30:d=1 -frames:v 1
       -pix_fmt nv12 | p010le      (or -vf format=…,hwupload for hw-frame-only encoders)
       -c:v <encoder> [-profile:v main10] -f null -
```

| Rule | Value / reason |
| --- | --- |
| Size | **≥ 256x144.** VAAPI reported minimums `width 128-4096 height 128-4096` (h264), `width 130-8192 height 128-4352` (hevc), `width 128-8192` (av1) [L] — a 128x128 probe would falsely fail hevc_vaapi. NVENC exposes driver-reported minimums via `NV_ENC_CAPS_WIDTH_MIN`/`NV_ENC_CAPS_HEIGHT_MIN` (added with SDK 9.1 headers, per a GStreamer commit). No official per-codec table was found; NVIDIA developer-forum reports give Turing+ minimum width 145 (H.264) / 129 (HEVC) and minimum height 32 — **unverified, user/forum-reported**. 256x144 clears all reported minimums. |
| Frames | 1 frame, `-f null -` (no file I/O). |
| 10-bit | separate probe with `-pix_fmt p010le` (+ `-profile:v main10` for HEVC). Listing `p010le` in "Supported pixel formats" does not prove the GPU can encode 10-bit for that codec (h264_nvenc lists `p010le` [L]). |
| Timeout | hard kill at **10 s** (job object `TerminateJobObject` on Windows; SIGKILL on Linux). Normal probes took 0.08–0.14 s [L]. **`libsvtav1` at 16x16 hung until the outer timeout** [L]; a SIGTERM-based `timeout 40` loop over tiny sizes did not finish within 200 s and the process had to be killed externally. Probes must use a hard kill, not a polite signal. |
| Concurrency | serial per GPU vendor (driver init contention; NVENC session limits on consumer GPUs [W]); software probes may run in parallel. Locally 4-way parallel gave no benefit for ~0.1 s probes. |
| Pre-render preflight | before opening pipes, re-run the probe with the job's real `WxH`, pix_fmt and profile (≈0.1 s here) to catch size/profile limits that the 256x144 probe cannot. |

### 3.2 Measured results [L] (`supplementary/hwprobe-summary.tsv`, 1 frame 256x144 unless noted)

| Probe | Result | Seconds | Key stderr line | Class |
| --- | --- | --- | --- | --- |
| libx264 yuv420p | OK | 0.085 | — | software |
| libsvtav1 yuv420p | OK | 0.141 | — | software |
| h264_nvenc / hevc_nvenc p010le main10 / av1_nvenc | FAIL rc 255 | 0.078–0.081 | `[h264_nvenc] Cannot load libcuda.so.1` | driver/library missing |
| h264_qsv / hevc_qsv p010le / av1_qsv | FAIL rc 171 | 0.081–0.084 | `[hevc_qsv] Error creating a MFX session: -9.` | no device/runtime (MFX_ERR_NOT_FOUND) |
| h264_amf / hevc_amf p010le / av1_amf | FAIL rc 171 | 0.078–0.082 | `[AMF] DLL libamfrt64.so.1 failed to open` | driver/library missing |
| h264_vaapi, hevc_vaapi, av1_vaapi (nv12 + hwupload) | **OK** | 0.095–0.123 | — | usable |
| hevc_vaapi, av1_vaapi **p010le** + hwupload | **OK (10-bit)** | 0.094–0.095 | — | usable 10-bit |
| h264_vaapi without hwupload | FAIL rc 218 | 0.087 | `Impossible to convert between the formats supported by the filter 'Parsed_null_0' and the filter 'auto_scale_0'` | wrong pipeline (config error, not capability) |
| h264/hevc/av1_vulkan (nv12 + hwupload) | **OK** | 0.107–0.128 | — | usable |
| h264_vaapi 16x16 | FAIL rc 234 | 0.090 | `Hardware does not support encoding at size 16x16 (constraints: width 128-4096 height 128-4096).` | unsupported resolution |
| hevc_vaapi 64x64 | FAIL rc 234 | 0.096 | `… size 64x64 (constraints: width 130-8192 height 128-4352).` | unsupported resolution |
| libsvtav1 16x16 | **hang → killed** | 15.0 (timeout) | — | timeout |
| libx264 / libx265 16x16 | OK | 0.08 / 0.12 | — | |
| h264_mf | FAIL rc 8 | 0.078 | `Unknown encoder 'h264_mf'` | not in build |

Sequential wall time for all 29 probes: 17.65 s, of which 15.0 s is the svtav1 hang (≈2.6 s for 28 probes).
The first capture (`ffmpeg-probe/hwprobe_*.txt`) shows the full NVENC cascade:
`Cannot load libcuda.so.1` → `Error while opening encoder - maybe incorrect parameters such as bit_rate, rate, width or height.` →
`Could not open encoder before EOF` → `Nothing was written into output file…`. Classify on the **first** encoder-tagged line,
not the generic follow-ups.

### 3.3 Failure classification

Exit status = low byte of the negative AVERROR (234 = EINVAL, 255 = EPERM, 218 = ENOSYS, 171 = AVERROR_UNKNOWN,
8 = encoder not found) [L]. Use it only as "non-zero"; classify by stderr pattern:

| Class | Patterns (Linux [L] / Windows [W]) | UI |
| --- | --- | --- |
| Not in build | `Unknown encoder '…'` | hide |
| Driver/runtime missing | `Cannot load libcuda.so.1` / `Cannot load nvcuda.dll`, `Cannot load nvEncodeAPI64.dll` [W]; `DLL libamfrt64.so.1 failed to open` / `amfrt64.dll` [W] | "Driver not installed" |
| Driver too old | `Driver does not support the required nvenc API version` [W] | "Update GPU driver" |
| No capable device | `Error creating a MFX session: -9.`; `No capable devices found`, `OpenEncodeSessionEx failed: unsupported device` [W] | "No compatible GPU" |
| Session/resource limit | `OpenEncodeSessionEx failed: out of memory` [W] | "GPU busy — retry" (transient) |
| Unsupported size | `Hardware does not support encoding at size …` | show constraints parsed from the message |
| Unsupported pix_fmt/profile | `Impossible to convert between the formats…`; `pixel format is incompatible with …` | "8-bit only" etc. |
| Timeout | no exit within 10 s | "Probe hung — not usable" |
| Other | anything else | show first tagged stderr line |

Presentation: per encoder a status chip — *Ready (8-bit)*, *Ready (8/10-bit)*, *Driver missing*, *No device*,
*Not in this FFmpeg* — with the probe date, duration and the raw first error line in a details pane. Results are
machine-specific; re-test on demand and after GPU driver changes (FFmpeg hash does not change).

**Windows note [W]:** VAAPI is Linux-only. On Windows, NVENC/QSV/AMF accept system-memory `nv12`/`p010le` directly
(listed formats [L]), so VEGAS P010 can be passed to `hevc_nvenc`/`hevc_qsv`/`av1_qsv` without `hwupload`.
D3D11/D3D12 (`d3d11va`, `d3d12va` encoders, MediaFoundation `*_mf`) are build-dependent and unqualified.

---

## 4. Machine-readable alternatives

| Interface | Structured? | Coverage [L] |
| --- | --- | --- |
| `ffprobe -of json -show_versions` / `-show_program_version` / `-show_library_versions` | JSON | version, configuration, library versions |
| `ffprobe -of json -show_pixel_formats` | JSON | all pixel formats with chroma shift, flags, per-component depth |
| `ffprobe -of json -show_streams -show_format <file>` | JSON | readback of produced files (used by the matrix) |
| `ffprobe` output formats | `default, compact, csv, flat, ini, json, xml` | only for the sections above; no encoder/muxer/option sections exist |
| `ffmpeg -encoders/-muxers/-h encoder=/-h full` | **text only** | no JSON flag |
| `-progress pipe:1` | `key=value` lines | encode progress (§7) |
| libavcodec API (`av_codec_iterate`, `av_opt_next`) | structured | would require linking the user's FFmpeg DLLs (shared builds only; ABI-version-specific) — not suitable for static user builds |

**Conclusion:** the app must parse text for encoders, muxers, per-encoder capabilities and AVOptions
(§2 grammar) and may use JSON for versions and pixel formats. Parsers must be versioned and tolerant
(unknown lines → retained raw, never fatal).

---

## 5. Codec ↔ container compatibility matrix [L]

Method: `matrix.py` generates raw **p010le** 320x180 video (15 frames, 30/1) and **f32le** 48 kHz stereo (0.5 s)
with lavfi, then feeds them exactly like the exporter (`-f rawvideo -pixel_format p010le -video_size 320x180
-framerate 30/1 -i …`, `-f f32le -ar 48000 -ac 2 -i …`), muxes to real files under `/tmp/claude-1000/ffmpeg-matrix-*`,
reads back with ffprobe and decodes with `-f null`. **PASS** = exit 0 + expected stream types on readback + clean decode.
226 cases, 38.2 s total; each case 0.06–0.19 s. Audio cases include a companion video (libx264; VP9 for WebM;
DNxHR HQ for MXF); audio-only results are identical except where noted (⁸).

Legend: ✓ pass (`tag`), ✗ fail, ⚠ exit 0 but output **invalid** (data stream).

### 5.1 Video codec × container

| Encoder / pix_fmt | mp4 | mov | mkv | webm | mxf | mpegts |
| --- | --- | --- | --- | --- | --- | --- |
| libx264 yuv420p | ✓ `avc1` | ✓ `avc1` | ✓ | ✗¹ | ✓⁴ | ✓ |
| libx264 yuv420p10le | ✓ `avc1` | ✓ | ✓ | ✗¹ | ✓⁴ | ✓ |
| libx265 yuv420p10le | ✓ `hev1`² | ✓ `hev1`² | ✓ | ✗¹ | ✗⁵ | ✓ |
| libsvtav1 yuv420p10le | ✓ `av01` | ✗³ | ✓ | ✓ | ✗⁵ | ⚠⁶ |
| libvpx-vp9 yuv420p / yuv420p10le | ✓ `vp09` | ✗³ | ✓ | ✓ | ✗⁵ | ⚠⁶ |
| prores_ks hq yuv422p10le | ✗⁷ | ✓ `apch` | ✓ | ✗¹ | ✓ | ⚠⁶ |
| dnxhd dnxhr_hq yuv422p | ✗⁷ | ✓ `AVdh` | ✓ | ✗¹ | ✓ | ⚠⁶ |
| dnxhd dnxhr_hqx yuv422p10le | ✗⁷ | ✓ `AVdh` | ✓ | ✗¹ | ✓ | ⚠⁶ |
| ffv1 yuv420p10le | ✓ `FFV1`⁹ | ✓⁹ | ✓ | ✗¹ | ✓ | ⚠⁶ |
| utvideo yuv420p | ✗⁷ | ✓ `ULY0` | ✓ | ✗¹ | ✗⁵ | ⚠⁶ |

### 5.2 Audio codec × container (with video)

| Encoder | mp4 | mov | mkv | webm | mxf | mpegts |
| --- | --- | --- | --- | --- | --- | --- |
| aac | ✓ `mp4a` | ✓ `mp4a` | ✓ | ✗¹ | ✗¹⁰ | ✓ |
| libopus | ✓ `Opus` | ✗³ | ✓ | ✓ | ✗¹⁰ | ✓ |
| flac | ✓ `fLaC` | ✗³ | ✓ | ✗¹ | ✗¹⁰ | ⚠⁶ |
| pcm_s16le | ✓ `ipcm`¹¹ | ✓ `sowt` | ✓ | ✗¹ | ✓ | ⚠⁶ |
| pcm_s24le | ✓ `ipcm`¹¹ | ✓ `in24` | ✓ | ✗¹ | ✓ | ⚠⁶ |
| pcm_f32le | ✓ `fpcm`¹¹ | ✓ `fl32` | ✓ | ✗¹ | ✗⁵ | ⚠⁶ |
| ac3 | ✓ `ac-3` | ✓ | ✓ | ✗¹ | ✗¹⁰ | ✓ |
| eac3 | ✓ `ec-3` | ✓ | ✓ | ✗¹ | ✗¹⁰ | ✓ |
| libmp3lame | ✓ `mp4a` | ✓ `.mp3` | ✓ | ✗¹ | ✗¹⁰ | ✓ |
| alac | ✓ `alac` | ✓ `alac` | ✓ | ✗¹ | ✗¹⁰ | ⚠⁶ |
| libfdk_aac (extra; nonfree) | ✓ | ✓ | ✓ | ✗¹ | ✗¹⁰ | ✓ |

Footnotes (key error lines verbatim):

1. `[webm] Only VP8 or VP9 or AV1 video and Vorbis or Opus audio and WebVTT subtitles are supported for WebM.`
2. HEVC defaults to `hev1` in MP4/MOV. `-tag:v hvc1` produced `hvc1` in both (verified tag); Apple players expect `hvc1` (playback not tested). Recommend `-tag:v hvc1` for HEVC in MP4/MOV.
3. `[mov] av1 only supported in MP4 and AVIF.` / `[mov] vp9 only supported in MP4.` / `[mov] opus only supported in MP4.` / `[mov] flac only supported in MP4.`
4. MXF accepted H.264 and FFmpeg reads it back; MXF H.264 interoperability with NLEs (often intra profiles) is not tested.
5. `[mxf] track 0: could not find essence container ul, codec not currently supported in container` (track 1 for pcm_f32le).
6. Exit **0** with `[mpegts] Stream 0, codec av1, is muxed as a private data stream and may not be recognized upon reading.`; ffprobe reads back `bin_data` (`codec_type: data`), decode fails (`Output file does not contain any stream`). Treat as unsupported. This is why every output check must read back stream types.
7. `[mp4] Could not find tag for codec prores in stream #0, codec not currently supported in container` (same for dnxhd, utvideo).
8. Audio-only: MXF rejects all (`[mxf] there must be exactly one video stream and it must be the first one`); mpegts aac/opus/eac3 warn `frame size not set` but pass.
9. FFV1 in MP4/MOV muxes; MOV warns `Using MS style video codec tag, the file may be unplayable!`. Keep FFV1 in MKV (current baseline) or MXF.
10. `[pcm_rechunk] Codec 'aac' (86018) is not supported by the bitstream filter 'pcm_rechunk'. Supported codecs are: pcm_alaw … pcm_s16le … pcm_s24le …` — MXF audio is PCM-only; FFmpeg's MXF muxer accepted pcm_s16le/pcm_s24le only.
11. FFmpeg 8.1 writes PCM in MP4 as ISO/IEC 23003-5 `ipcm`/`fpcm`; FFmpeg reads it back, third-party player support is untested. Prefer MOV/MKV for PCM.

Extra-flag checks:

| Check | Result |
| --- | --- |
| `-movflags +faststart` (mp4) | top-level atoms `ftyp,moov,free,mdat` vs default `ftyp,free,mdat,moov`. Requires a seekable output and rewrites the file after encoding (cost grows with file size; not measured at scale). |
| `-strict experimental` | **never needed** for these combinations in FFmpeg 8.1.3. flac/alac print `encoding as 24 bits-per-sample, more is considered experimental` (only >24-bit needs `-strict`). |
| Legacy DNxHD profile at 320x180 | ✗ `[dnxhd] video parameters incompatible with DNxHD. Valid DNxHD profiles:` — legacy DNxHD needs fixed sizes/bitrates; DNxHR profiles worked at 320x180. |
| `dnxhr_hq` with `yuv422p10le` | ✗ `[dnxhd] pixel format is incompatible with DNxHR LB/SQ/HQ profile` |

Design use: the configurator prototype's `compat` table (`docs/product/design/shared/model.js`) was derived from this
matrix (MOV rejects AV1/VP9/Opus/FLAC; MXF accepts H.264/ProRes/DNxHR/FFV1 with pcm_s16le/s24le only; MPEG-TS
excluded because it writes opaque data streams). Rows for codecs not in that prototype (e.g. utvideo) remain only here.
The matrix is FFmpeg-version-specific: re-run `matrix.py` against each newly added FFmpeg major version and keep
per-version overrides rather than a single global table.

---

## 6. Pixel-format negotiation (VEGAS delivers p010le)

If `-pix_fmt` is omitted FFmpeg auto-selects; measured from p010le input [L] (`negotiate-*` rows in `matrix-summary.tsv`):

| Encoder | 10-bit target | 8-bit target | Auto from p010le | Warning to show |
| --- | --- | --- | --- | --- |
| libx264 | `yuv420p10le` (High 10) | `yuv420p` | `yuv420p10le` | 10-bit H.264 has limited hardware-decoder support |
| libx265 | `yuv420p10le` (Main 10) | `yuv420p` | `yuv420p10le` | — |
| libsvtav1 | `yuv420p10le` | `yuv420p` | `yuv420p10le` | only these two formats exist |
| libaom-av1 / librav1e | `yuv420p10le` | `yuv420p` | `yuv420p10le` | — |
| libvpx-vp9 | `yuv420p10le` (profile 2) | `yuv420p` | `yuv420p10le` | — |
| prores_ks | `yuv422p10le` (proxy…hq), `yuv444p10le`/`yuva444p10le` (4444/xq) | none | `yuv422p10le` | chroma upsampled 4:2:0→4:2:2: larger file, no quality gain. **Couple pix_fmt to profile**: `-profile:v 4444 -pix_fmt yuv422p10le` exits 0 but writes an `ap4h` stream that ffprobe reports as `yuv422p12le` [L] — use `yuv444p10le` for 4444/4444xq |
| dnxhd | `dnxhr_hqx` → `yuv422p10le`; `dnxhr_444` → `yuv444p10le`/`gbrp10le` | `dnxhr_lb/sq/hq` → `yuv422p` | **fails** for dnxhr_hq (must set `-pix_fmt yuv422p`); `yuv422p10le` for hqx | LB/SQ/HQ: **10→8-bit reduction** |
| ffv1 | `yuv420p10le` (lossless vs P010) | `yuv420p` | `yuv420p10le` | — |
| utvideo | none | `yuv420p`/`yuv422p`/`yuv444p`/`gbrp`/`gbrap` | **`yuv420p` silently** | **10→8-bit reduction** |
| hevc_nvenc / av1_nvenc | `p010le` (direct, no conversion) | `nv12` | not tested (no GPU) | 10-bit needs GPU support; probe it |
| h264_nvenc | lists `p010le` [L]; GPU support unverified | `nv12` | — | probe before offering 10-bit |
| hevc_qsv / av1_qsv | `p010le` | `nv12` | — | |
| h264_qsv | none (`nv12`, `qsv` only) | `nv12` | — | 10→8-bit reduction |
| h264_amf / hevc_amf / av1_amf | `p010le` listed for all three [L]; H.264 10-bit GPU support unverified | `nv12` | — | probe 10-bit per codec |
| *_vaapi / *_vulkan (Linux) | `format=p010le,hwupload` | `format=nv12,hwupload` | — | n/a on Windows (Vulkan unqualified) |

Rules:

1. **Always pass `-pix_fmt` explicitly**; never rely on auto-negotiation (utvideo silently drops to 8-bit; dnxhr_hq fails).
2. Choose from the encoder's parsed "Supported pixel formats" intersected with the profile's needs, preferring
   (a) same bit depth, (b) same chroma subsampling, (c) no alpha unless delivered.
3. Warn using `ffprobe -show_pixel_formats` descriptors: target `bit_depth` < source → "Reduces 10-bit to 8-bit
   (banding risk)"; larger `log2_chroma_*` → "Reduces color resolution"; smaller → "Upsamples chroma (no quality gain)".
4. Audio (source float32 stereo 48 kHz), encoder-side formats from FFmpeg's `Output #0` line [L]:
   aac `fltp`, libopus `flt`, ac3/eac3/libmp3lame `fltp` (lossy, no warning); pcm_f32le `flt` (exact);
   flac `s32 (24 bit)`, alac `s32p (24 bit)`, pcm_s24le `s32 (24 bit)` → "float → 24-bit integer; values beyond ±1.0
   clip"; pcm_s16le `s16` and **libfdk_aac `s16`** → "reduced to 16-bit".
5. Future VEGAS inputs are **not qualified**: I420 (8-bit 4:2:0 → `yuv420p` input, no up-conversion should be
   offered as "10-bit"), BI_RGB/BGRA (8-bit packed RGB, bottom-up rows observed → `bgra` input needs a vertical flip
   or negative stride; RGB→YUV matrix choice matters), A410 (10-bit 4:4:4 + alpha; FFmpeg pixel-format mapping
   unknown). Each needs its own layout validation before the configurator offers it.

---

## 7. Named-pipe and process notes (Windows)

Current exporter command (`src/engine/encode.cpp`):

```
ffmpeg -hide_banner -nostdin -y
  -thread_queue_size 8 -probesize 32 -analyzeduration 0
  -f rawvideo -pixel_format p010le -video_size WxH -framerate N/D -i \\.\pipe\vegas-encoder-<pid><nonce>-video
  -thread_queue_size 8 -probesize 32 -analyzeduration 0
  -f f32le -ar 48000 -ac 2 -i \\.\pipe\vegas-encoder-<pid><nonce>-audio
  -map 0:v:0 -map 1:a:0 -c:v ffv1 -pix_fmt yuv420p10le -c:a pcm_f32le -f matroska <out>.<nonce>.partial
```

| Topic | Documentation / finding |
| --- | --- |
| Raw video input | rawvideo demuxer options `framerate` (default 25), `pixel_format` (default `yuv420p`), `video_size` ("must be specified explicitly"), `stride` (per-plane line sizes when padded). Always pass all three explicitly; rational rates like `30000/1001` work. |
| Raw audio input | `-ar`/`-ac` "for input streams … only makes sense for audio grabbing devices and raw demuxers and is mapped to the corresponding demuxer options". With `-ac 2` FFmpeg warns `[aist#0:0/pcm_f32le] Guessed Channel Layout: stereo`; `-ch_layout stereo` instead of `-ac 2` removes the warning and states the layout explicitly [L]. |
| `\\.\pipe\name` | Not documented as a protocol: the `pipe:` protocol is for file descriptors ("UNIX pipe access protocol", `pipe:[number]`). A `\\.\pipe\…` path is opened by the `file` protocol like any Windows path [W]. Predecessor real-host runs used this path form (F-050/F-052, `ADAPTER_DATA_FLOW.md`); not re-tested here. Linux analogue [L]: the same rawvideo input arguments read a `mkfifo` FIFO at `30000/1001` — 15/15 frames, `r_frame_rate=30000/1001`. |
| Input warnings | `Estimating duration from bitrate, this may be inaccurate` is printed for raw inputs [L]; it is benign and should be filtered from user-facing warnings. |
| Non-seekable output | "some formats (typically MOV), require the output protocol to be seekable" — irrelevant for file outputs, but `+faststart` needs a seekable file. |
| `-thread_queue_size` | Input: "maximum number of queued packets when reading from the file or device". For rawvideo one packet = one frame: 8 × 6,220,800 B ≈ 50 MB at 1080p P010. |
| `-nostdin` | "Disabling interaction on standard input is useful … if ffmpeg is in the background process group." Keep, plus stdin = `NUL` (current code). |
| `-hide_banner` | "Suppress printing banner." |
| `-progress pipe:1` | "Send program-friendly progress information to url … made of "key=value" lines … The last key of a sequence … is always "progress" with the value "continue" or "end"." Period via `-stats_period` ("Default is 0.5 seconds"). Use with `-nostats` to stop the CR-updated stderr status line. Captured block [L] (`supplementary/progress-pipe-pixfmt.txt`): `frame=15`, `fps=0.00`, `stream_0_0_q=-0.0`, `bitrate=4288.5kbits/s`, `total_size=268031`, `out_time_us=500000`, `out_time_ms=500000`, `out_time=00:00:00.500000`, `dup_frames=0`, `drop_frames=0`, `speed=48.4x`, `progress=end`. Note `out_time_ms` is in **microseconds** (same as `out_time_us`). Parse unknown keys tolerantly; values can be `N/A`. For Vegas Encoder, frame progress is already known from the host side; `-progress` is useful for encoder-side lag/speed and the final `progress=end`. |
| `-y` / `-n` | `-y` "Overwrite output files without asking"; `-n` "Do not overwrite output files, and exit immediately if a specified output file already exists." The engine pre-creates its own temp file (`CREATE_NEW`), so `-y` is required **only** for that app-owned temp path; the engine itself refuses an existing destination. |
| Explicit `-f <muxer>` | Required because the temp output ends in `.partial` (no extension-based guess). |
| Logging | `-loglevel [flags+]level`; levels `quiet -8, panic 0, fatal 8, error 16, warning 24, info 32 (default), verbose 40, debug 48, trace 56`; flag `level` adds a `[level]` prefix, `repeat` disables "Last message repeated n times". Recommend `-loglevel level+info` into `.ffmpeg.log` so the UI can classify lines by severity. |
| Fail-fast | `-xerror` "Stop and exit on error"; `-abort_on empty_output_stream` ("No packets were passed to the muxer in some of the output streams"). |
| Exit status | 0 = success; otherwise low byte of the AVERROR (§3.3); `-max_error_rate` crossing returns 69. Exit 0 does **not** prove a valid file (mpegts ⁶) → read back with ffprobe. |
| `-report` | writes `ffmpeg-YYYYMMDD-HHMMSS.log` in CWD and implies `-loglevel debug` — avoid in production (CWD inside VEGAS). |

---

## 8. Recommended design for Vegas Encoder

### 8.1 Cache

One JSON document per installation, e.g. `%LOCALAPPDATA%\VegasEncoder\ffmpeg-cache\<sha256>.json`:

```json
{
  "schema": "vegas-encoder-ffmpeg-caps/1",
  "parser": "1.0.0",
  "identity": {"path": "C:\\ffmpeg\\bin\\ffmpeg.exe", "size": 0, "mtime": "…", "sha256": "…",
               "sharedLibs": {"avcodec-62.dll": "sha256…"}, "ffprobe": {"path": "…", "sha256": "…", "matches": true}},
  "build": {"version": "8.1.3", "license": "gpl-v3", "configure": ["--enable-gpl", "…"],
            "libs": {"libavcodec": "62.28.103"}},
  "encoders": [{"name": "libx264", "codec": "h264", "type": "video", "flags": "V....D",
                "caps": ["dr1", "delay", "threads"], "pixFmts": ["yuv420p", "…"],
                "options": [{"name": "preset", "type": "string", "flags": "E..V.......", "default": "medium"}]}],
  "muxers": [{"name": "mp4", "extensions": ["mp4"], "defaultVideo": "h264", "options": []}],
  "pixFmts": "<ffprobe -show_pixel_formats JSON>",
  "hardware": [{"encoder": "hevc_nvenc", "test": "256x144 p010le main10", "status": "driver-missing",
                "firstError": "…", "seconds": 0.08, "testedAt": "2026-10-11T03:10:51+08:00"}],
  "compat": "<curated matrix version + per-installation overrides>"
}
```

| Key | Rule |
| --- | --- |
| Fast validity check | real path + size + mtime on each configurator start (no hashing). |
| Strong identity | SHA-256 of `ffmpeg.exe` (+ shared DLLs, + ffprobe) when the fast check changes or on add. The DLL logs the exe SHA-256 per job already (`encode.cpp`). |
| Parser version | bump → re-parse cached raw text (store raw `-h` outputs so re-parsing needs no re-probe). |
| Hardware results | separate validity: re-test on demand, on app start if older than N days, and when the GPU driver changes (Windows driver-version detection is a design item, unverified). |

### 8.2 Scheduling

| Trigger | Work |
| --- | --- |
| Installation added/browsed | identity + `-version`/`-buildconf` + `-encoders` + `-muxers` + ffprobe JSON (sub-second), then `-h encoder=` for the curated encoder allowlist, then hardware probes (serial, 10 s hard kill each). Show progress; UI usable as soon as lists are parsed. |
| Configurator start | fast stat check; re-probe only if changed. |
| User "Re-test hardware" | hardware probes only. |
| Before each render (DLL) | identity check of the selected exe (hash already computed for the log) + optional 1-frame preflight at the job's real size/pix_fmt for hardware encoders. |

### 8.3 Expected probe cost

Measured serially, each call under `timeout -s KILL 10` [L] (`supplementary/probe-cost.sh`, `probe-cost.tsv`):

| Probe | Wall time |
| --- | --- |
| `-h encoder=` for the 25 names in `ffmpeg-probe/` (incl. the not-found `prores_videotoolbox`) | **1.91 s** total (0.05–0.08 s each) |
| `-h encoder=` for all 235 listed encoders | **12.9 s** total |
| `-version`, `-buildconf`, `-encoders`, `-muxers`, `-pix_fmts`, `-sample_fmts`, `-layouts` | 0.056–0.073 s each |
| `-h full` (1.28 MB) | 0.071 s |
| `ffprobe -of json -show_versions -show_pixel_formats` | 0.056 s |
| Hardware probe (1 frame) | 0.08–0.14 s each; a hung encoder costs the full timeout |
| Container-matrix case (encode + mux, 15 frames) | 0.06–0.19 s |

A full first-time probe of a curated ~25-encoder allowlist plus lists plus ~10 hardware probes is ≈3–4 s here.
Windows process creation and loading a ~100+ MB static `ffmpeg.exe` (gyan full) will be slower than this Linux
shared build (≈0.05 s per process) — **not measured**; budget per call conservatively and run the probe in the
background with progressive UI updates.

### 8.4 Precompute for the UI

- Encoder list grouped by codec (`h264`: libx264, h264_nvenc, h264_qsv, h264_amf …) with hardware status chips.
- Per encoder: curated rate-control modes → argument templates, validated option metadata (ranges, enum
  constants, defaults), presets/tunes/profiles from enum constants (or curated lists for `<string>` options like
  libx264 `-preset`), pix_fmt choice for 8-bit and 10-bit targets, and the bit-depth/chroma warnings of §6.
- Container compatibility from §5 (curated, versioned), filtered by the encoders present; required extra flags
  (`-tag:v hvc1`, `+faststart`), and the mpegts/data-stream exclusion.
- Advanced mode: validate free-form arguments only lightly (known option names per encoder/muxer), and always
  read back the result with ffprobe after render.

---

## Sources (accessed 2026-10-11)

- ctx7 `/websites/ffmpeg_documentation` (resolved via `npx ctx7@latest library FFmpeg …`): queries on generic help
  options (`-h encoder=`, `-encoders`, `-muxers`), `-progress`/`-thread_queue_size`, `-y`/`-n`/`-loglevel`,
  rawvideo demuxer / `-ar`/`-ac`. No quota or network errors occurred (one CLI argument-parsing error, retried).
- FFmpeg documentation: https://ffmpeg.org/ffmpeg.html, https://ffmpeg.org/ffmpeg-all.html,
  https://ffmpeg.org/ffmpeg-protocols.html, https://ffmpeg.org/ffmpeg-formats.html#rawvideo
- FFmpeg legal checklist: https://ffmpeg.org/legal.html
- FFmpeg license: https://raw.githubusercontent.com/FFmpeg/FFmpeg/master/LICENSE.md
- gyan.dev builds: https://www.gyan.dev/ffmpeg/builds/
- BtbN builds: https://github.com/BtbN/FFmpeg-Builds
- NVENC minimum sizes (forum/third-party, unverified): https://forums.developer.nvidia.com/t/minimum-width-in-turing-gpus/155566,
  https://forums.developer.nvidia.com/t/nvencoder-error/66099,
  https://git.fasttube.de/FaSTTUBe/GST-Tensordecoder-ov_ep/commit/58a663c1e5ed986ebdb5a166ed45a536e7f4af8e (SDK 9.1 header caps);
  NVENC Application Note: https://docs.nvidia.com/video-technologies/video-codec-sdk/12.0/nvenc-application-note/index.html
- Local evidence: `evidence/2026-10-11-product-design/ffmpeg-probe/`, `…/container-matrix/` (this task).
