# Bundled starter presets

The app library and VEGAS Render As list share 16 recipes from
`schema/builtin-presets.v1.json` (owner-approved expansion, 2026-10-23).
VEGAS also retains its general settings template and reserved hidden probe.

| Starter | Video settings | Audio / container |
| --- | --- | --- |
| H.264 | x264, CRF 18, slow, 8-bit | AAC 320 kbps / MP4 |
| H.265 (HEVC) - 10-bit | x265, CRF 22, medium, 10-bit | AAC 320 kbps / MP4 |
| AV1 - 10-bit | SVT-AV1, CRF 32, preset 6, 10-bit | Opus 160 kbps / MKV |
| ProRes 422 HQ | prores_ks, HQ, 10-bit | PCM 24-bit / MOV |
| DNxHR HQ | dnxhd, DNxHR HQ, 8-bit | PCM 16-bit / MXF |
| Lossless - FFV1 | FFV1, 10-bit | Float PCM / MKV |
| H.264 - quick review | x264, CRF 23, veryfast, 8-bit | AAC 160 kbps / MP4 |
| H.264 - NVIDIA GPU | NVENC H.264, CQ 21, p5, HQ, 8-bit | AAC 192 kbps / MP4 |
| HEVC 10-bit - NVIDIA GPU | NVENC HEVC, CQ 20, p5, HQ, 10-bit | AAC 320 kbps / MP4 |
| AV1 10-bit - NVIDIA GPU | NVENC AV1, CQ 28, p5, HQ, 10-bit | Opus 160 kbps / MKV |
| ProRes 422 LT | prores_ks, LT, 10-bit | PCM 24-bit / MOV |
| ProRes Proxy | prores_ks, Proxy, 10-bit | PCM 24-bit / MOV |
| VP9 - WebM | libvpx-vp9, CRF 31, good, CPU-used 2, 10-bit | Opus 192 kbps / WebM |
| H.264 CRF 16 (x264) | x264, CRF 16, slow, 8-bit | AAC 320 kbps / MP4 |
| HEVC CRF 16 (x265) | x265, CRF 16, slow, 10-bit | AAC 320 kbps / MP4 |
| H.264 720p 3500kbps (NVENC) | NVENC H.264, VBR 3500 kbps target, p5, HQ, 8-bit | AAC 160 kbps / MP4 |

All retain project frame rate. All except the 720p starter retain project
dimensions, including ProRes Proxy. The 720p starter uses Basic Extra arguments
to fit square-pixel source video inside 1280x720, preserve aspect ratio and add
black padding; it neither crops nor stretches. Its audio bitrate is additional
to the video target; VBR does not promise an exact file size. MP4 starters enable
faststart. Audio sample rate and channel layout follow the delivered source.
These are SDR BT.709 recipes; a 10-bit encoder does not imply HDR support.

Hardware starters require the named encoder in the selected user-supplied FFmpeg
and a compatible GPU/driver. Availability comes from existing discovery/test
services. The expansion reuses the existing NVIDIA HEVC app recipe unchanged.
All seven prior app recipes and all six prior VEGAS slot/GUID identities remain
unchanged; new entries append at slots 8-17. Saved user templates remain snapshots
and are not updated automatically. Future changes to a recipe increment its
revision. Setup does not copy user `.sft2` files.

Current validation and host/installer qualification limits are in
[STATUS.md](STATUS.md). Source changes do not update existing installer bundles or
install the new starters.
