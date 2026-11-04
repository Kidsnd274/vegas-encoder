# Bundled starter presets

The app library and VEGAS Render As list share 12 recipes from
`schema/builtin-presets.v1.json` (owner simplification, 2026-11-05).
Web Upload contains one CPU and one NVENC preset each for H.264, HEVC and AV1,
plus CPU VP9. Editing and lossless presets remain. The app and VEGAS use the same
names: codec plus `(CPU)` / `(NVENC)` for delivery presets; codec/profile for
editing and lossless presets. VEGAS also retains the general settings template
and reserved hidden probe.

| Starter | Video settings | Audio / container |
| --- | --- | --- |
| H.264 (CPU) | x264, CRF 18, slow, 8-bit | AAC 320 kbps / MP4 |
| HEVC (CPU) | x265, CRF 22, medium, 10-bit | AAC 320 kbps / MP4 |
| HEVC (NVENC) | NVENC HEVC, CQ 20, p5, HQ, 10-bit | AAC 320 kbps / MP4 |
| AV1 (CPU) | SVT-AV1, CRF 32, preset 6, 10-bit | Opus 160 kbps / MKV |
| ProRes 422 HQ | prores_ks, HQ, 10-bit | PCM 24-bit / MOV |
| DNxHR HQ | dnxhd, DNxHR HQ, 8-bit | PCM 16-bit / MXF |
| FFV1 | FFV1, 10-bit | Float PCM / MKV |
| H.264 (NVENC) | NVENC H.264, CQ 21, p5, HQ, 8-bit | AAC 192 kbps / MP4 |
| AV1 (NVENC) | NVENC AV1, CQ 28, p5, HQ, 10-bit | Opus 160 kbps / MKV |
| ProRes 422 LT | prores_ks, LT, 10-bit | PCM 24-bit / MOV |
| ProRes Proxy | prores_ks, Proxy, 10-bit | PCM 24-bit / MOV |
| VP9 (CPU) | libvpx-vp9, CRF 31, good, CPU-used 2, 10-bit | Opus 192 kbps / WebM |

All retain project dimensions and frame rate, including ProRes Proxy. MP4 starters
enable faststart. Audio sample rate and channel layout follow the delivered source.
These are SDR BT.709 recipes; a 10-bit encoder does not imply HDR support.
Hardware starters require the named encoder in the selected user-supplied FFmpeg
and a compatible GPU/driver. Availability comes from existing discovery/test services.

The quick-review, H.264/HEVC CRF 16 and H.264 720p/3500 kbps variants are no longer
built-ins. Personal exports/imports and saved VEGAS snapshots keep their settings;
no user files are deleted or rewritten. The previous YouTube-named recipes become
the generic H.264 CPU and HEVC NVENC defaults with their encoding settings unchanged.
Retained library IDs, VEGAS GUIDs and numeric template IDs stay stable. Catalog
`vegas[].index` is the persistent template ID; enumeration positions can close gaps.
`retiredVegas` reserves removed IDs/GUIDs against reuse. Display-name/metadata edits
increment retained revisions to 2; updates remain explicit. Setup does not copy user
`.sft2` files or refresh saved templates.

A frozen 720p revision-2 export under `schema/fixtures/retired-presets/` verifies
personal import, resize persistence and old-core compatibility independently of
the built-in list. It is test data, not a shipped starter.

Current validation and host/installer qualification limits are in
[STATUS.md](STATUS.md). Source changes do not update existing installer bundles or
install the new starters.
