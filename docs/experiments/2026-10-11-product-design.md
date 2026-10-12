# Experiment: product layer plan and UI directions

- Date: 2026-10-11 (Asia/Singapore).
- Status: complete for owner review. Documentation and mockups only.
- Question: What should the product layer look like, and how should it be built?
  The layer covers the desktop app, presets, the shared Guided/Command editor and the
  VEGAS popup.
- Success condition: a reviewable architecture and specification grounded in FFmpeg
  behaviour measured on real FFmpeg, plus several distinct, interactive UI directions
  using real content.

## Inputs

- Product docs: ARCHITECTURE, ADAPTER_PLAN, INTEGRATION_CONTRACT, ADAPTER_DATA_FLOW.
- Investigation findings: F-032/F-033 (property pages and template layout) and F-017
  (the user's Voukoder workflow).
- Local FFmpeg 8.1.3 (Linux, Fedora shared build).
- Flutter 3.47.2 / Dart 3.13.2.
- Context7 and pub.dev for current Flutter/Dart facts.
- Web sources for Voukoder, StaxRip, HandBrake, Shutter Encoder and Resolve (listed in
  research notes).

## Results

**Plan** (`docs/product/`):

- README, PRODUCT_SPEC, TECH_ARCHITECTURE, SETTINGS_AND_COMMANDS, FFMPEG_INTEGRATION,
  UI_SPEC, ROADMAP.
- research/ notes: REFERENCE_PRODUCTS, FFMPEG_DISCOVERY, FLUTTER_DESKTOP.

**Key proposals:**

- a shared portable C++ core for compile/validate, used by both the DLL and Flutter (FFI);
- the popup as a separate, owned editor process exchanging session files;
- a versioned template payload holding a full recipe snapshot (gated on A5–A7);
- machine-level default FFmpeg;
- hardware encoders qualified by real test encodes.

**FFmpeg measurements** (Linux, not Windows):

- Each probe call costs about 80 ms.
- `-h encoder=` for 25 encoders takes 1.67 s serially, or 0.41 s with 4 workers.
- The container matrix covered 226 cases: MOV rejects AV1/VP9/Opus/FLAC; MP4 rejects
  ProRes/DNxHR; MPEG-TS exits 0 while writing unreadable data streams; HEVC needs
  `-tag:v hvc1` for Apple players.
- `libsvtav1` hung at 16×16, so probes must use a hard kill and sizes ≥ 256×144.

**Design** (`docs/product/design/`):

- brief, shared model and real option data, native-page mock;
- eight directions with S1–S4 each, screenshots and a review.
- Recommendation: D1 Command Deck as the base, with D4's search, D3's signal-path strip
  and D5's size card.

**Process notes:**

- A quota guard stopped the first agent wave; second-wave agents were relaunched.
- One agent's write was refused once, then succeeded after the owner changed the
  permission mode.
- A hung FFmpeg probe from the first wave was killed by PID.

## Limits and next task

- **No real VEGAS test ran.** No Windows build ran, no Flutter code exists, and nothing
  was installed.
- Popup ownership, start time, console-window behaviour and the Impeller backend are
  Windows spikes for P2.
- Template exchange and persistence remain A5–A7.

Next: owner review (P0), then P1 (core and schema with engine parity), per
docs/product/ROADMAP.md.

Commands and identities are in the ignored `evidence/2026-10-11-product-design/README.md`.
