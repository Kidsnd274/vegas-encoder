# Native integration evidence and implementation limits

This is a practical imported evidence summary. It is not the original Sony/MAGIX
SDK and does not claim new Vegas Encoder runtime compatibility. The header
`src/vegas/abi/sfio_abi.h` retains per-method/field finding annotations. Source origin
and exact input hashes are in [ORIGIN.md](../ORIGIN.md) and
[import manifest](import-manifest.json). The local investigation location is
`L:/repos/vegas-ffmpeg-frameserver`; it is not a build dependency.

## Established subset

| Evidence | What it establishes |
| --- | --- |
| F-026/F-027 | Stub-decoded IIDs/method shapes; video slot 12 differs between 23 and 2026; current path does not call it |
| F-030/F-031 | Working connector render lifecycle, indexed video read/release, sample-position audio reads, progress calls on recorded 23/2026 bytes |
| F-033 | Discovery class/filter sequence, allocator query/Alloc, template fixed part 0x218 with private bytes then text |
| F-036/F-038 | 32-byte audio records, requested float32 format and measured conformance/Create sequence |
| F-041 | Own exporter discovery/BI_RGB render; actual stream/frame timing takes priority over nominal template rate; S_FALSE can contain final audio data |
| F-044 | Index-0/id-0 template hidden in observed exporters; exact index-versus-id rule unknown |
| F-045 | Raw ffbridge 0.1.1 fixture/repeats; slot-6 user cancel 0x8004E00C then renderer 0x8004E017/CloseFile |
| F-048 | ffbridge 0.2.0 fake-host FFmpeg checks and implementation source; all host calls remain on caller thread |
| F-050 | One short decoded ffbridge-to-FFmpeg fixture on the exact VEGAS 2026 target |
| F-052 | Concurrent research result: real ffbridge 1080p/fractional success and user cancel; post-cancel recovery/error UI still open |

Host IIDs and discovery CLSID are retained. Vegas Encoder's own filter/type/preset
IDs are new; proof templates are not automatically imported. Returned templates use
the evidenced host allocator; its unverified Free slot is not guessed. Private bytes
are copied through conformance, but arbitrary UI/save/reload persistence is unproven.

Internal helpers check declared spans, owned-field bounds, text terminators and
arithmetic. Pointer-only entry points still trust host memory readability. Token modes
and plane layouts are limited to the existing evidenced in-process path. Do not
treat declarations of unused methods as support, unknown flags as semantic names,
or a third-party capture as qualification of our current binary.

## New implementation versus native evidence

Extracted checked templates, frame leases, HRESULT exception containment, product
identity, generated fixtures and installer checks are authored implementation changes.
Their helper/fake tests establish code behavior. No new native IID, vtable slot,
structure interpretation or real-host behavior is inferred from them.

Preserve host ownership, caller-thread reads/progress, frame release before transport
waits, actual delivered timing, valid short/final audio reads and distinct encoder
failure/cancellation results. Progress failures beyond the observed cancel code
still need a separately qualified classification change.

## Unresolved work

Our exporter reports zero property pages. The complete VEGAS-specific editable
template exchange, page lifetime and setting persistence require a focused native
experiment; generic COM documentation alone cannot provide them. Multiple-container
extensions, general color/HDR, full token variants, additional hosts, long/slow
stability and simultaneous jobs remain unqualified.

Use [ADAPTER_PLAN.md](ADAPTER_PLAN.md) for remaining A0–A8 gates and
[VEGAS_RUNTIME.md](VEGAS_RUNTIME.md) for first product host qualification.
