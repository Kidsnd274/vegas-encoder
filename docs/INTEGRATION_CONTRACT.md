# Native integration contract

The exporter targets Windows x64. Native declarations live in src/vegas/abi.
The VEGAS-facing implementation lives in src/vegas. The portable recipe
core lives in src/core and has no Windows or VEGAS headers.

- Preserve discovery, renderer and preset identities. Saved templates carry
  recipe snapshots and render independently of the app.
- Select the layout for the exact host before calling native interfaces.
- Check template sizes and text boundaries. Use matching host copy and free
  routines for host-owned returns and independent holder copies.
- Keep host callbacks on Render's caller thread. Copy and release frames
  before waiting on FFmpeg, and honor valid short and final audio reads.
- Use delivered video and audio timing. Check frame and token bounds before
  reading pixels. Preserve cancellation and failure HRESULTs.
- Resolve the actual destination before admission and publication.
  See [legacy naming](LEGACY_NAMING.md).

See [adapter data flow](ADAPTER_DATA_FLOW.md), [native configuration](NATIVE_CONFIGURATION.md)
and [qualification status](STATUS.md). Detailed host observations and binary
evidence live in the private investigation repository.
