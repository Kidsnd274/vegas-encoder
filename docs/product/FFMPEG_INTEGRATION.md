# FFmpeg integration: which FFmpeg, and what it can do

Updated: 2026-10-12 (Asia/Singapore). Status: proposal. Distribution is decided:
user-supplied FFmpeg, with no download offer for now (owner, 2026-10-12).

This answers the owner's open question: "how the program knows what codecs are
available and which FFmpeg instance to use."

Supporting material:

- Measurements and parsing rules: [research/FFMPEG_DISCOVERY.md](research/FFMPEG_DISCOVERY.md).
- Raw evidence in the ignored `evidence/2026-10-11-product-design/` folder (`ffmpeg-probe/`, `container-matrix/`).
- All design-time checks used FFmpeg 8.1.3 on a Linux machine. The product is
  Windows-only, so P1 recaptures the help text, container matrix and probe timings
  with Windows builds (gyan.dev and BtbN, static and shared). Those become the
  fixtures; the numbers below are indicative until then.

## 1. Choosing the FFmpeg

**The user supplies FFmpeg.** Vegas Encoder ships no FFmpeg binaries (current
policy, STATUS.md). The app finds candidates and the user picks a default.

| Source checked on first run and on "Scan again" | Typical path |
| --- | --- |
| Previous Vegas Encoder INI `FFmpegPath` | `C:\ffmpeg\bin\ffmpeg.exe` |
| `PATH` entries | any |
| winget (Gyan.FFmpeg, BtbN) | `%LOCALAPPDATA%\Microsoft\WinGet\Packages\Gyan.FFmpeg_*\ffmpeg-*\bin\` and `…\WinGet\Links\` |
| Scoop | `%USERPROFILE%\scoop\apps\ffmpeg\current\bin\`. Resolve the `.shim` file to the real exe. |
| Chocolatey | `%ProgramData%\chocolatey\lib\ffmpeg*\tools\…\bin\`. Resolve the `bin\` shim. |
| Manual | **Add FFmpeg…** file picker. `ffprobe.exe` must sit beside it (the existing engine requirement). |

Each candidate is identified by:

- **version banner and build** (`-hide_banner -version`): version, compiler, the
  `--enable-*` configuration, library versions, and license class (GPL / LGPL / nonfree);
- **content identity:** SHA-256 of `ffmpeg.exe`, plus the sorted SHA-256 of sibling
  `av*`/`sw*`/`postproc*` DLLs for shared builds; file size and mtime for a fast
  unchanged check;
- **ffprobe** beside it: present, with a matching version.

The **default installation** is stored in `machine.json` and used by every render.
A preset never names a path. History records which FFmpeg actually ran (path,
version, hash), so "it worked yesterday" questions have answers.

**Why not download FFmpeg for the user (yet).** GPL builds bundle x264/x265.
Distributing or auto-downloading them couples the product to GPL obligations.
Builds with `libfdk_aac` are non-free and not redistributable. The project license
is still undecided.

A later "Get FFmpeg" helper could show the winget command, or download a chosen build
with explicit consent, once licensing is settled. This is a review item, not a v1 feature.

## 2. Knowing what it can do

### 2.1 Probe steps

| Step | Command | Cost (measured locally) | Result |
| --- | --- | --- | --- |
| Identity | `ffmpeg -hide_banner -version` | 82 ms | version, configuration, libraries |
| Lists | `-encoders`, `-muxers`, `-pix_fmts`, `-sample_fmts`, `-layouts` | ~80 ms each | 138 video + 88 audio encoders in the local build |
| Curated encoder details | `-h encoder=X` for the 25 curated encoders | 81 ms each; 1.67 s serial, 0.41 s with 4 in parallel | pixel/sample formats, private options with types, ranges, defaults and constants |
| Other encoders | `-h encoder=X` on demand, when the user opens it | ~80 ms | same |
| Muxer details | `-h muxer=X` for curated containers | ~80 ms | default codecs, extensions, options |
| Hardware qualification | 1-frame test encode per hardware encoder (§2.3) | 80–140 ms each locally; driver init can be slower on Windows | Ready / Failed test on this PC + reason |

Each FFmpeg invocation costs ~80 ms here, almost all process start-up and library
loading. Measured on a 32-thread Linux machine with Fedora's shared build; Windows static
builds will differ. A full curated probe (identity, lists, 25 encoders, 5 muxers,
~10 hardware tests) is therefore roughly 1–2 s with 4 workers. Results stream to the
UI as they arrive.

### 2.2 Parsing (text, because FFmpeg has no structured encoder listing)

- `ffprobe -of json` covers versions, configuration and pixel formats only.
  Encoders, muxers and AVOptions must be parsed from help text.
- The parser is versioned. Its fixtures are captured help outputs, kept with their
  FFmpeg identity.

Rules verified against FFmpeg 8.1.3 output:

- Help goes to stdout and ends with `Exiting with exit code 0`. Unknown encoders
  *also* exit 0, printing "Codec 'X' is not recognized". Detect the text, not the exit code.
- Option lines: `  -name  <type>  E..V....... description (from A to B) (default X)`.
  Constant lines are indented five spaces.
- Tokenize by whitespace, not columns. Long constant names overflow their column
  (`autovariance-biased 3`), and some constants have no value (x265 `dolbyvision` → `auto`).
- Options can repeat: dnxhd prints `-profile` twice, and its constants follow the
  second line. Merge repeats.
- Range and default literals include `INT_MIN`, `INT_MAX`, `FLT_MAX`, `I64_MAX`,
  scientific notation, and enum names as defaults (`p4`, `twoloop`, `auto`).
- Some options appear twice under alias names (NVENC `spatial_aq` and `spatial-aq`).
  Merge entries with the same type, range, default and description into one option
  with aliases, so lint and autocomplete don't show duplicates.
- `-h encoder=X` lists **private** options only. Generic codec options (`-b`, `-g`,
  `-bf`, `-maxrate`, `-compression_level`, …) come from a curated list, or from
  `-h full` if ever needed.
- Encoder parameter strings (`-x264-params`, `-x265-params`, `-svtav1-params`) are
  opaque dictionaries. Their keys need curated knowledge; the UI treats them as text
  with a help link.

The design prototype parser is [design/tools/build_avoptions.py](design/tools/build_avoptions.py).
It turned 24 captured encoders into 471 options for the mockups.

### 2.3 Hardware encoders: listed is not working

The local build lists `h264_nvenc`, `hevc_qsv` and others. On this machine they fail
with "Cannot load libcuda.so.1" (no NVIDIA driver) or "Error creating a MFX session: -9"
(no Intel device). This is the normal case on Windows too: every FFmpeg build lists
NVENC/QSV/AMF whether or not the hardware exists.

**Test encode per hardware encoder:**

```text
ffmpeg -hide_banner -nostdin -loglevel error -f lavfi -i color=c=black:s=256x144:r=30:d=0.1
       -frames:v 1 [-pix_fmt p010le for the 10-bit test] -c:v <encoder> -f null -
```

- **Size.** At least 256×144: hardware encoders have minimum sizes (VAAPI reports
  128–130 px). Never probe tiny sizes: `libsvtav1` hung at 16×16 in research.
- **Kill.** Each probe has a hard kill after 10 s (not only a polite timeout). At most
  4 run in parallel.
- **10-bit.** A second test with `-pix_fmt p010le` for encoders that claim it,
  because 10-bit support depends on the GPU generation.
- **Failure classes, from stderr patterns:**
  - Driver or runtime missing: "Cannot load …", "DLL … failed".
  - No device: "MFX session", "No device available".
  - Unsupported format/size: "unsupported pixel format", "Frame size … out of range".
  - Unknown: anything else; keep the first error line verbatim.
- **Keying.** Results are keyed by installation identity *and* a GPU fingerprint
  (DXGI adapter names and driver versions). They re-run when either changes, when the
  user clicks **Test hardware encoders**, or after 30 days.

### 2.4 Containers and codecs

Validation uses a measured matrix, not assumptions: 226 test muxes with
raw `p010le` / `f32le` input, like the VEGAS pipes. Highlights:

- **MP4** rejects ProRes, DNxHR and UT Video. FLAC, PCM and FFV1 mux, but few players
  open them, so they get warnings.
- **MOV** rejects AV1, VP9, Opus and FLAC.
- **WebM** takes only VP9/AV1 and Opus.
- **MXF** needs exactly one video stream, first. It accepts H.264, ProRes, DNxHR and
  FFV1, with 16/24-bit PCM audio only.
- **MPEG-TS** exits 0 while writing VP9/AV1/ProRes/FFV1/FLAC/PCM as opaque data
  streams, so it is excluded from the curated containers. This is also why output
  verification exists (TECH_ARCHITECTURE §7).
- **HEVC in MP4/MOV** defaults to the `hev1` tag; Apple playback needs `-tag:v hvc1`.
  Fast start moves `moov` ahead of `mdat`.
- **Errors need evidence.** Container rules that block Apply are limited to
  combinations where FFmpeg refused to mux in a real test. "Muxes but few players open
  it" is a warning.

  Voukoder Pro removed its own compatibility check after it wrongly blocked ProRes in
  MXF (research/REFERENCE_PRODUCTS.md). Rules are kept per FFmpeg major version. A
  v1+ "Check this combination" action can run the real test mux (~0.1 s) against the
  selected installation.
- **Automatic pixel format selection** from `p010le` input can fail (`dnxhr_hq` needs
  `yuv422p`) or silently drop precision (UT Video becomes 8-bit). The compiler
  therefore always sets `-pix_fmt` explicitly.

## 3. Cache and invalidation

`%LOCALAPPDATA%\VegasEncoder\cache\ffmpeg\<identity-key>.json`:

```jsonc
{ "cache": 1, "parser": 3, "identity": { "path": "…", "sha256": "…", "libs": ["…"], "size": 0, "mtime": "…" },
  "version": { "ffmpeg": "8.1", "configuration": ["--enable-gpl", "…"], "license": "GPL v3" },
  "encoders": { "libx264": { "kind": "video", "flags": "V....D", "pixfmts": ["…"], "options": [ … ] } },
  "muxers": { "mp4": { "extensions": ["mp4"], "defaultVideo": "h264" } },
  "hardware": { "fingerprint": "…", "testedAt": "…", "results": { "hevc_nvenc": { "state": "ok", "tenBit": true } } } }
```

- Recomputed when the identity key or parser version changes.
- Size is roughly 200–500 KB for a full build. It is parsed in a background isolate.
  The popup starts without it and fills availability badges when it loads.
- The DLL may read the cache (read-only) to warn before a render, but never probes.

## 4. What the user sees

- **FFmpeg page:**
  - installations, with the default, source, version, license class and probe time;
  - capabilities grouped by codec family, each marked Ready / Not in this FFmpeg /
    Failed test on this PC, with the reason and the raw stderr line on expand;
  - actions: **Add FFmpeg…**, **Scan again**, **Set as default**, **Test hardware encoders**.
- **Encoder pickers** show the same states inline. Unavailable encoders stay visible but
  marked, so a preset that needs them explains itself instead of disappearing.
- **Preset list** marks presets whose encoders aren't usable with the current default
  FFmpeg ("Needs x264: not in FFmpeg 8.0 LGPL").
- **Render failures** in History show the exact command, the FFmpeg stderr tail and the
  identity of the FFmpeg that ran.
