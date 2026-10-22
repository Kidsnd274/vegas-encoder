# Future features: resolution, filters and VEGAS preset summary

Requested by the owner on 2026-10-23 (Asia/Singapore).
Status: future feature writeup; no implementation or release date is committed.
These requests refine two previously skipped enhancements in
[PRODUCT_SPEC.md](PRODUCT_SPEC.md). The current release and qualification queue
remain unchanged.

## 1. Resolution, upscaling and an optional Filters section

### Goal

Choose the encoded output resolution and scaling algorithm without writing
FFmpeg arguments. Leave room to add other filters through the same UI.
The owner's Voukoder 13.4.1 screenshot is the interaction reference: a filter
list with Add, Edit and Remove actions, and a scale editor with width, height
and an algorithm picker. It does not require copying Voukoder's layout or
exposing every FFmpeg option.

### Proposed experience

Add a **Filters** disclosure/dropdown section to the shared Video settings panel
in both the desktop app and the VEGAS popup. It starts collapsed. Expanding it
shows an ordered list and an **Add filter** menu. Begin with **Resize / Upscale**;
add other curated filters later.

- No filters: the collapsed header says **Filters: None**.
- Active resize: for example, **Filters: Resize to 3840 × 2160 · Lanczos**.
- Several filters: show their count and a short summary, so processing remains
  visible even when the section is collapsed.
- Offer enable/disable, Edit and Remove per filter. Once several types are
  supported, provide keyboard-accessible reorder actions. Display order equals
  processing order.
- Collapsing the section never disables its filters. Expansion is a UI
  preference; enabled filters and their settings belong to the recipe.

This extends Basic's curated controls, consistent with the decision against an
all-options editor. Advanced mode continues to use its active command; inactive
Basic filters must not silently change an Advanced render.

### Resize / Upscale controls

| Control | Proposed behaviour |
| --- | --- |
| Output resolution | Default: **Same as input from VEGAS**. Common sizes: 1280 × 720, 1920 × 1080, 2560 × 1440 and 3840 × 2160, plus Custom width/height. Distinguish UHD from DCI sizes. |
| Aspect ratio | Preserve by default. Linked dimensions calculate the other value when input facts are known. For a fixed canvas, offer Fit with padding, Fill with crop, or explicit Stretch. Show resulting dimensions and crop/padding before Apply. |
| Scaling algorithm | A small supported dropdown, initially Bicubic, Bilinear, Lanczos and Nearest neighbour. Proposed starting selection: Bicubic, to validate during implementation; no universal best-quality claim. |
| Scaling backend | Start with FFmpeg's software `scale` filter. Later, offer `zscale` and its spline choices when supported by the selected FFmpeg. Backend and algorithm remain distinct. |
| Source/output information | **From VEGAS → Encoded output**, including whether it is upscaling, downscaling or unchanged. Unknown source size stays **Set by VEGAS**; never substitute sample-preview dimensions. |
| Reset | Remove resizing and return to the dimensions supplied by VEGAS. |

Resolution means the size encoded by FFmpeg **after VEGAS supplies the frames**.
For example, delivered 1920 × 1080 frames can become 3840 × 2160 before encoding.
This does not change the project or ask VEGAS to render effects at a different
size. If VEGAS already resized the source, describe the delivered size; do not
imply access to the original media.

Upscaling increases pixel dimensions without promising recovered detail. AI
upscaling and GPU scaling are separate possible investigations. A hardware
encoder selection must not silently select a GPU scaling backend.

### Room for more filters

Use an extensible ordered recipe representation rather than a permanent single
resize field. Later candidates include crop/pad, denoise, sharpen, deinterlace
and LUT/color processing. These are candidates, not a promise to support every
filter. Timing-changing and color filters need their own verification before
being offered. External LUTs need a missing-file and preset-portability policy.

Start with simple filters on the existing video stream. This request does not
require extra inputs, arbitrary maps or complex multi-stream graphs.

### Extra arguments and Advanced mode

The current [C2 contract](CONTRACTS.md) permits simple stream filters through
Basic Extra arguments and supported Advanced commands. Native rendering still
rejects complex graphs and the other restricted stream/input scopes. This is an
existing manual route, not evidence that all resize/filter combinations have
been qualified in real VEGAS.

For the new controls, the core owns one effective video filter chain. If Extra
arguments supply a video filter, show **Filters set in Extra arguments** and
make structured filter controls inactive while retaining their values. Do not
silently concatenate, discard or reorder handwritten and generated filters.
Any later merge/import needs explicit rules and user review. Advanced seeding
includes the structured chain; switching back retains Basic settings under the
existing mode-switch policy.

### Implementation requirements and acceptance

- Save filters in library presets, exports and complete VEGAS template snapshots.
  Recipes without filters retain current behaviour. Define schema/version handling
  so older consumers cannot silently drop enabled processing and change output.
- Keep normalization, compilation, validation and resolved output facts in the
  portable C++ core. The app consumes them through `ve_core`; system access and
  FFmpeg checks go through `ve_services`. Extend contracts and consumers together.
- Discover filter/backend options from the selected FFmpeg; encoder-option
  discovery alone is insufficient. Missing required filters produce actionable
  errors. Never silently substitute algorithms.
- Validate dimensions, aspect/sample-aspect policy, chroma alignment, encoder
  limits and known bit-depth/color consequences. Surface rounding/conversions
  before Apply. Unknown conversion facts remain unknown.
- Keep the raw pipe description at the delivered VEGAS size. Carry encoded
  dimensions separately into summaries, estimates where supported and output
  verification. Do not check a resized output against the input dimensions.
- Disabled filters retain current command behaviour. Enabled filters produce
  the same core-generated chain and order in preview and render.
- Check core compilation/conflicts, recipe round trips, missing capabilities,
  aspect handling and actual FFmpeg output dimensions. Add widget tests and
  reviewed light/dark goldens for desktop and popup. Separately qualify real
  VEGAS with the actual build, host and filter settings; synthetic checks do not
  close that gate.

## 2. Selected-preset summary in VEGAS's native template dialog

### Goal and placement

Confirm the selected preset without opening the full editor. Put a read-only
summary on the existing native Vegas Encoder page in VEGAS's Custom Template/
preset dialog, alongside the button the owner calls **Open settings** (currently
labelled **Edit settings...** in source). This is the page inside VEGAS, before
the separate Flutter popup opens.

The current native page has the settings button and session/status text with
output-suffix guidance. Older architecture/mockup documents describe a richer
summary; that summary was deferred and is not already implemented.

### Proposed summary

Compact rows, with illustrative values:

```text
Preset:       H.265 10-bit · Modified
Video:        libx265 · Main 10 · CRF 18 · Medium
Resolution:   Same as input from VEGAS
Filters:      None
Audio:        AAC · 320 kb/s · Stereo
Container:    MP4 (.mp4)

[Edit settings...]
Settings are stored in this VEGAS template.
```

With resizing, show known source/output sizes, or just the configured output
when the source is unknown. Filters can say **Resize · Lanczos**, or a short
list/count. Until structured filters exist, summarize available facts; this
summary can ship independently.

Show saved origin name/revision when available, with a modified marker only
when supported by stored comparison facts. Without library origin, say
**Custom settings**. Do not infer a reliable comparison when the base snapshot
is unavailable. Distinguish the VEGAS template name from the library preset.

### Behaviour and acceptance

- Read the selected template's embedded snapshot, including local edits. Never
  replace it with the latest library recipe for display. Library changes or
  deletion must not change saved render settings.
- Refresh on selected-template load and accepted editor changes. Mark returned
  changes as still needing VEGAS Apply/OK. Editor cancel, rejected results and
  failed launches retain the prior draft summary. Preserve existing host commit/
  rollback semantics.
- Use effective settings and unknown markers from the shared core, including
  Extra arguments overrides. In Advanced mode summarize established active-command
  facts, label **Advanced command**, and mark other details **Custom / not
  determined**. Do not show inactive Basic values as effective settings.
- Keep session/error text and filename-suffix guidance separate. Long names,
  warnings and filter lists wrap or have an accessible details view. Keep the
  settings button accessible at supported host sizes/DPI.
- Draw locally from the snapshot, without launching Flutter, scanning the preset
  library or probing FFmpeg. Any later readiness display needs current evidence.
- Check core formatting/unknowns, native refresh and Apply/Cancel with a fake
  host, long/Unicode text and DPI/layout. Separately qualify actual selection/
  edit/refresh in real VEGAS. Mockups and fake-host checks do not establish that.

## Suggested delivery order

1. Native preset summary: useful independently of filter UI.
2. Resolution and software scaling in the collapsed Filters section.
3. More curated filters and optional backends after individual validation.

This is a proposed future order, not a replacement for
[NEXT_AGENT.md](../NEXT_AGENT.md) or authorization to resume deferred trials.

## References

- Owner-supplied Voukoder screenshot: filter list and width/height/algorithm editor.
- [Current release scope](PRODUCT_SPEC.md#current-release-scope-owner-2026-10-17),
  [Extra arguments](UI_SPEC.md#extra-arguments) and [contracts](CONTRACTS.md).
- [FFmpeg scale](https://ffmpeg.org/ffmpeg-filters.html#scale),
  [software scaler options](https://ffmpeg.org/ffmpeg-scaler.html) and
  [zscale](https://ffmpeg.org/ffmpeg-filters.html#zscale). Current indexed official
  documentation was retrieved through Context7 for this writeup. Available
  concepts do not establish support in every user-supplied build.
