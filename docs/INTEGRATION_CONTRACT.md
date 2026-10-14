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
the evidenced host allocator. The configuration follow-up establishes its Free
slot on the exact inspected host module, paired with the holder's calloc copies;
see [native ownership contract](NATIVE_CONFIGURATION.md). Private bytes
are copied through conformance, but arbitrary UI/save/reload persistence is unproven.

Internal helpers check declared spans, owned-field bounds, text terminators and
arithmetic. Pointer-only entry points still trust host memory readability. Token modes
and plane layouts are limited to the existing evidenced in-process path. Do not
treat declarations of unused methods as support, unknown flags as semantic names,
or a third-party capture as qualification of our current binary.

## New implementation versus native evidence

B5 establishes the exact `CSfRenderProgress` text effects on the unchanged
2026.0.3.189 executable: slot 3 borrows a description pointer, sets the total and
resets position; slot 4 only borrows the pointer. An internal helper forwards it
to a scripting render-status description/title; public SetPosition passes a null
description. The authorized slot-4 trial returned S_OK with guarded calls but
showed no useful text switching. The owner dropped custom dialog text and retained
the healthy `0.1.3-progress-text-proof` candidate; results and rollback information
are in [NATIVE_PROGRESS.md](NATIVE_PROGRESS.md). This does not qualify A5–A7,
persistence, controlled real failure recovery or monitor performance.

Extracted checked templates, frame leases, HRESULT exception containment, product
identity, generated fixtures and installer checks are authored implementation changes.
Their helper/fake tests establish code behavior. The configuration work adds
previously decoded page/holder declarations and ownership semantics established
from the exact host/connector copies. Its opt-in native bridge is tested with
fakes; the corrected page's on/off settings also reach real VEGAS renders.

Preserve host ownership, caller-thread reads/progress, frame release before transport
waits, actual delivered timing, valid short/final audio reads and distinct encoder
failure/cancellation results. The new uninstalled foundation candidate classifies
only the observed progress cancellation code as user cancellation in the encoded
path and preserves other failed HRESULTs. Fake recovery checks and real
cancellation/recovery pass; controlled real error recovery remains open.
Raw diagnostic behavior is unchanged.

## Unresolved work

The default exporter reports zero property pages. The installed opt-in
build implements one technical proof page using the measured native ownership
contract. Its first real UI attempt displayed a blank page; the corrected build
shows the window during activation and its on/off settings reach Render. Actual
Apply/Cancel and save/restart behavior remain fake-host tested; the user deferred
real two-template/restart qualification. Generic COM docs and fake tests do not
provide it. Multiple-container
extensions, general color/HDR, full token variants, additional hosts, long/slow
stability and simultaneous jobs remain unqualified.

Use [ADAPTER_PLAN.md](ADAPTER_PLAN.md) for remaining A0–A8 gates and
[VEGAS_RUNTIME.md](VEGAS_RUNTIME.md) for first product host qualification.
