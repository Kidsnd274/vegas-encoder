# App icon selection concepts

Open `index.html` for the comparison gallery, or `preview.png` for the contact sheet.

| Option | File | Direction |
| --- | --- | --- |
| A | `01-current-signal.svg` | Faithful current title-bar mark, fixed dark palette |
| B | `02-signal-bold.svg` | Bolder version of the current signal mark |
| C | `03-stream-merge.svg` | Video/audio merge into one output |
| D | `04-ve-monogram.svg` | VE lettermark |
| E | `05-encode-frame.svg` | Video frame and play symbol |

All five are standalone, editable SVGs with vector geometry only, no fonts, embedded raster images, external assets or dependencies. Nominal size is 256 × 256; they scale through their viewBox. The area outside each rounded tile is transparent. Their tile and mark colours are fixed, so the gallery shows the same asset on both light and dark UI backgrounds.

Option A reproduces `VeLogo` / `_LogoPainter` in `app/lib/design/icons.dart`, using the dark palette from the current app. This is the app-drawn title-bar mark in the owner's screenshot, separate from the Windows executable's `app/windows/runner/resources/app_icon.ico`. B–E are original vector alternatives authored for this selection.

The owner selected **A**. Its maintained source is now
[`app/assets/icon/app_icon.svg`](../../../../app/assets/icon/app_icon.svg), with
[generation instructions](../../../../app/assets/icon/README.md). The Windows
runner ICO and Markdown PNG are generated there; this folder preserves the
original selection gallery. B–E remain unselected concepts. No installation or
real-host qualification is implied by icon selection/generation.
