# Design review: eight directions

Reviewed: 2026-10-11 (Asia/Singapore). Each direction implements S1–S4. D4 adds
`#s1b` (search active) and D5 adds `#s1d` (dark theme). Every page uses the shared
model and showed no console errors in headless Chromium. Screenshots are in
`screenshots/`. These are HTML mockups only: no Flutter code exists yet, and nothing
ran in VEGAS.

## Summary

| Direction | Best at | Weak at | Fit |
| --- | --- | --- | --- |
| D1 Command Deck | Trust: the command is always visible, grouped by stream, linked both ways to its controls | Long commands push the editor down; dense for beginners | Power users. Closest to the StaxRip spirit |
| D2 Channel Strips | Video and audio as equal, side-by-side streams; meaningful faders | Strips are tall and the popup has to fold them; a novel metaphor needs learning | Distinctive, audio/video-minded users |
| D3 Signal Flow | Shows **what happens to the pixels**: the 10-bit wire thins to 8-bit at a conversion pip | Diagram takes ~40% of the height; command `^` breaks wrap badly | Explaining conversions; strong as a component |
| D4 Inspector | Completeness and speed: one search across 138 settings, changed values marked, Extra-argument overrides shown | Generic dark-pro look; least welcoming | Daily driver for experts; matches VEGAS |
| D5 Mica | Calm and native; the size and quality card answers "how big, how good" | Least distinctive; needs Segoe UI (system font) and fluent_ui | Broad audience; lowest learning curve |
| D6 Tape Shelf | Library identity: presets recognisable by colour and position | Spine text is small; the shelf costs vertical space on every visit | Users with many presets |
| D7 Destination | Beginners: intent first, with the triangle proposing a concrete recipe | The triangle mapping is opinionated and hides the encoder choice until fine-tune | Onboarding and "new preset" flow |
| D8 Bars and Tone | Status at a glance: the bar strip shows which section is broken | Busy; the quality marks crowd; the command panel overlaps the Speed row | Memorable branding; status strip as a component |

## Recommendation

**D1 Command Deck as the base,** completed with three borrowed components.

1. **From D4:** the cross-setting search (curated fields, parsed AVOptions and generic
   options), plus changed-value marks and per-row reset. This is what makes "All options"
   usable rather than a wall of fields.
2. **From D3:** a compact **signal path strip** (VEGAS, then video/audio encoders, then
   container and file) above the editor, or in the popup header. Wire thickness and the
   conversion pip make bit-depth and chroma changes visible where they happen.
3. **From D5:** the **size and quality card** for the estimate, with its
   plain-language consequences.

Why D1:

- The owner's two core asks are separate video/audio configuration and freedom to type
  any FFmpeg arguments. D1 is the only direction where both modes are the same surface:
  the tokens *are* the command, and Command mode edits them in place.
- It stays clean: one accent per role, Recursive for both UI and command, generous
  spacing.
- It scales down to the popup without changing its structure.

**Alternatives:**

- **Native over distinctive:** D5 as the base, with D1's command panel and D4's search.
- **Raw density:** D4 as the base, with D3's strip.
- **D7's triangle** is worth keeping as the optional "New preset from a destination"
  flow in any base.
- **D8's bar strip** could serve as a compact status indicator in the popup title bar.

## Known issues to fix when the chosen direction moves to Flutter

| Direction | Issue |
| --- | --- |
| D1 | Hover-to-token linking is not wired in the popup; the S4 hardware test output is illustrative |
| D2 | Library button sits at the left of the scene row (spec says right) |
| D3 | `^` continuation characters wrap onto their own lines in the command panel |
| D4 | No Ctrl+K palette; long commands break at hyphens |
| D5 | "All options" and "Save to library" open nothing |
| D6 | Long spine titles wrap to two condensed lines; consider a tooltip or shorter titles |
| D7 | A saved-preset diamond overlaps the "NVENC HEVC" area label |
| D8 | Quality marks collide in two rows; the editor scrolls under the fixed command panel; encoder pickers are plain dropdowns |

## Contrast adjustments made by builders

The brief's muted and error colours failed AA on some surfaces, so builders adjusted them:

- **D4:** muted `#8A9099` → `#959BA4`, error text `#E5534B` → `#F0706A`.
- **D6:** muted → `#575D58`, editing green → `#277A4C`.
- **D7:** vertex colours are kept for shapes; darker variants are used for text.
- **D2:** muted, master and ok colours were adjusted.

Fold these into the chosen token set.

## Shared model fixes made during the review

Builders reported model problems. These were fixed in `shared/model.js` and checked
against every built-in preset:

- Extra arguments override generated options instead of duplicating them.
- Stale values are dropped when the encoder changes (speed, tune, profile, private options).
- NVENC multipass default is `disabled`, matching FFmpeg.
- Command-mode lint checks encoders against the selected FFmpeg, and `-x265-params`
  is checked against the encoder.
- No size estimate is shown for custom commands.
- The QP value is used in fixed-quantizer estimates.
- Quality labels read CRF/CQ/ICQ/QP.
- A three-way `updatePreview` separates library changes from local edits.
- Speed lists are marked slowest-first where they are ordered that way.
- Messages point to the FFmpeg page.

Two known gaps remain: Command-mode templates return generic `extra` roles (no
per-stream colouring), and x265 tune values have no descriptions.
