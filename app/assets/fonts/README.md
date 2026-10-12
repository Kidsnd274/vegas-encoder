# Bundled fonts

Both families are licensed under the SIL Open Font License 1.1. Each folder keeps the
licence text (`OFL.txt`) next to the font, and the installer must ship it with the app.
Neither licence declares a Reserved Font Name, so subset builds may keep the family names.

| File | Family | Source in google/fonts | Upstream | SHA-256 |
| --- | --- | --- | --- | --- |
| `InstrumentSans/InstrumentSans-Variable.ttf` | Instrument Sans, axes `wdth` 75–100 and `wght` 400–700 | `ofl/instrumentsans/InstrumentSans[wdth,wght].ttf` at `0b58fb370093f9a9f4ff785d94405710b79de67c` | github.com/Instrument/instrument-sans `7fa22308a3d0` | `b24f1812584816958afcf22e22d08e44318c5e51651e25d2438efdde389b33b1` |
| `JetBrainsMono/JetBrainsMono-Variable.ttf` | JetBrains Mono, axis `wght` 100–800 | `ofl/jetbrainsmono/JetBrainsMono[wght].ttf` at `6e4b84c976cadb3c49a40fd9a1c203e4f7fcf2da` | github.com/JetBrains/JetBrainsMono `19371302b95d` | `48715a42ec242c21e9f02692891e147d022299a52e48d5e413e1a942193ffeda` |
| `JetBrainsMono/JetBrainsMono-Italic-Variable.ttf` | JetBrains Mono Italic, for Advanced-mode macros | `ofl/jetbrainsmono/JetBrainsMono-Italic[wght].ttf` at the same commit | as above | `85ae2a5cd3f56baf1ce1c21a851322c58e3d8fbe8e8ad4a4d090a820dd7fe558` |

The files are the upstream variable fonts, renamed only (square brackets removed so
asset keys stay plain). They are not subset yet: the start-time measurement in
`docs/product/workstreams/app.md` decides whether subsetting is worth it. Flutter maps
`FontWeight` onto the `wght` axis, so the mockup's weights (550, 620, 650…) render
exactly.
