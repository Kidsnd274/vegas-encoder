# Vegas Encoder status

Updated: 2026-10-10 (Asia/Singapore). Version: 0.1.0-dev.

## Implemented baseline

- User-created independent Git repo at `L:/repos/vegas-encoder`; named Vegas Encoder.
- Authored source imported from the ffbridge 0.2.0 working tree with SHA-256 source
  identities, import map and distinct filter/type/preset GUIDs.
- Internal ABI, checked template/frame-lease helpers, adapter, encoder and diagnostics.
- Product-native build scripts and test host; engine's diagnostic header has no
  indirect dependency on VEGAS interfaces.
- Synthetic project-template generation, raw/decoded fixture checkers, product
  FFmpeg test runner and conservative reversible installer/fake-tree tests.
- Native exception containment and best-effort scoped-lock diagnostics hardening.

Validation: x64 /W4 /WX builds; 24 host-helper and 9 boundary checks; generated FFmpeg suite including 1080p; raw-checker and fake-installer tests; independent source-copy build all pass. Exact final DLL SHA-256 is 9FE5587A49F7A65AE3DC62DBB54D6B4AB392B67447D1D21C9DDC307325EEF5B2.

Validation results are recorded in the [bootstrap experiment](experiments/2026-10-10-bootstrap.md)
and ignored evidence. The source/research import is documented in [ORIGIN.md](../ORIGIN.md).

## Gate state

| Gate | State |
| --- | --- |
| A0 real-host baseline qualification | Pending broader ffbridge repeat/cancel/error observations; short fixture proof F-050 plus real 1080p/fractional/cancel evidence F-052 |
| A1 independent product import/build | Implemented; generated fake-host tests are self-contained |
| A2 internal host helpers | Template/lease separation and targeted checks implemented; further stream/allocator extraction and real-host qualification remain |
| A3 adapter/engine boundary | Internal dependencies and owned-buffer transport retained; broader job/settings and cancellation hardening remain |
| A4 Vegas Encoder real-host parity | Pending: this DLL has not run or been installed in VEGAS |
| A5/A6 native page and saved-setting proof | Pending; zero property pages currently exposed |
| A7 versioned recipe snapshots | Pending; current 64-byte private marker is not a configurable recipe payload |
| A8 foundation qualification | Pending real-host/persistence gates and broader support matrix |

## Limits

Fixed lossless MKV profile only. P010/square-pixel/supported constant rates, optional
48 kHz float32 stereo. No general HDR/color/alpha, hardware encode, audio-only encode,
arbitrary codec/container or VEGAS-version guarantee. Color metadata is not qualified.
Raw mode remains a research-style diagnostic path with narrower defensive guarantees.

Host calls stay on the Render caller thread; no simultaneous-render/thread-safety
claim. Progress failure classification and formally bounded Abort completion under
stalled clients remain inherited hardening questions. The proof runner models
cancellation but does not establish real-host cancel while a pipe is stalled.

Installed INI edits cause conservative hash-drift refusal during update/uninstall.
User-supplied FFmpeg remains a machine preference; no binaries are distributed.
No real VEGAS installation changed; installed ffbridge 0.2.0 remains the research proof.

## Source checkpoint

The user requested local Git commits of current progress. The initial authored implementation is checkpointed; generated builds/media/evidence remain ignored. See [checkpoint note](experiments/2026-10-10-implementation-checkpoint.md). This does not change runtime qualification.

## Next task

Run the new product DLL through the [real-host procedure](VEGAS_RUNTIME.md) on the
exact selected host: discovery, fixture, repeat, cancel/recovery, encoder failure
and cleanup. Preserve DLL/host/encoder identities and decoded results. Continue the
small native configuration exchange/persistence experiment after render parity.
