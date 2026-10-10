# Source origin

Vegas Encoder starts from authored source in the investigation at
`L:/repos/vegas-ffmpeg-frameserver`, HEAD `791baa32a3358d1b9c93bada45be2aeca07caf6b`, plus uncommitted work.
Import date: 2026-10-10 (Asia/Singapore). HEAD alone does not identify this baseline.
[import-manifest.json](docs/import-manifest.json) identifies exact input file bytes,
source hashes and newly assigned product identities. Original source snapshots are
preserved in the investigation's ignored bootstrap evidence.

The exporter prototype is ffbridge 0.2.0; its fixed FFmpeg path passed fake-host
tests (F-048) and one VEGAS 2026 fixture (F-050). Those results do not validate a
rebuilt Vegas Encoder DLL. ABI evidence comes from F-026/F-027/F-030/F-031/F-033/
F-036/F-038/F-041/F-044/F-045. See the product's integration contract for scope.

Mappings: src/sdk -> src/vegas/abi; plugin/render -> src/vegas/adapter;
checked template/lifetime mechanics -> src/vegas/host; encode -> src/engine;
diagnostics -> src/support; fiohost -> tests/fiohost; checkers -> scripts.
New host-helper tests, synthetic template generation and product build/installation
scripts are authored for this extraction. Production code is maintained here.

No third-party connector binaries, decompiler data, installers, raw host captures,
FFmpeg binaries or FrameServer source files are imported. Original method-name
provenance references FrameServer revision ab841f3be72c9e9d99b64ff0f0d4b592e738b359
as documented in the recovered header; preserve those annotations. No project
license or reuse/legal conclusion is selected by this import.

The diagnostic JSON schema deliberately remains `ffbridge-diag/1` so existing
decoded/raw validators remain usable. The DLL, INI, logs, sidecars, pipe prefixes,
plugin GUIDs and private marker are independently branded Vegas Encoder.
Proof templates are not automatically migrated to the new product identity.
