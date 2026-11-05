# Native integration evidence and implementation limits

Current continuation uses the original checkout and one app/platform queue;
see [NEXT_AGENT](NEXT_AGENT.md) and [STATUS](STATUS.md) for present implementation,
installed candidate and qualification. The imported evidence and older unresolved
sections below are historical scope, not a separate workstream or current queue.

This is a practical imported evidence summary. It is not the original Sony/MAGIX
SDK and does not claim new Vegas Encoder runtime compatibility. The header
`src/vegas/abi/sfio_abi.h` retains per-method/field finding annotations. Source origin
and exact input hashes are in [ORIGIN.md](../ORIGIN.md) and
[import manifest](import-manifest.json). The local investigation location is
`L:/repos/vegas-ffmpeg-frameserver`; it is not a build dependency.

## Established subset

**Automatic legacy naming candidate, 2026-11-05:** owner continuation of F-063's
Classic method adds explicit `LegacyAutoNames=1`. One original class advertises
nominal MP4. SetFile resolves the actual suffix using the immutable recipe's
existing core outputExtension before admission/reservation. The actual path feeds
strict suffix/collision/publication checks, job records and GetFileName; no new
host interface, recipe/C4 field or copied reference implementation is introduced.
Default modern naming is unchanged. The candidate passes actual-DLL/fake-host/
real-FFmpeg checks and installed in 23 build 278 with approval at 2026-11-05
12:04:43 +08:00. Installed hashes verify; real-23 rendering remains unqualified. See
[policy, trial and rollback](LEGACY_NAMING.md). Older 22/21/13 ABI gates remain open.

F-063 compares the exact installed Classic connector 1.0.0.0 x64
(`41FC1427…E8D7940`) and core 13.4.0.1 x64 (`CC440228…935B1E5`) with published
source and author explanations. The connector advertises MP4 and retains/passes
the nominal host path. The core rebuilds the actual filename from the chosen
muxer's extension before writing; the connector getter still reports its nominal
path. This does not establish per-template UI naming or a new host ABI. No runtime
test or copied GPL implementation. See the
[Classic comparison](../../vegas-ffmpeg-frameserver/docs/experiments/2026-11-05-voukoder-classic-naming.md).
At F-063, the exact-destination policy was unchanged. A legacy path-resolution policy must
preserve admission/collision/no-overwrite/publication protections on one actual
path and qualify 23 filename reporting. The opt-in implementation above now
provides that path resolution; real 23 qualification is pending. F-062 installation
remains held/unapproved.

F-062 traces the exact 23 managed Render As dialog (RenderAsDialog.dll SHA-256
`39254AF7…F447CC`, ScriptPortal.Vegas.dll `4E831635…9DB68B`). RenderTemplate's
FileExtensions property calls IRenderTemplateCOM slot 26; RTTI-validated EXE table
`0xDF0200` maps that slot to `0x585A80`. The row takes the first extension and
RenderButton_Click calls UpdateFileExtension at IL `0x00D3..0x00DA`, before
filename/existence checks. Empty extension branches around Path.ChangeExtension
at UpdateFileExtension IL `0x0021..0x0027`. This explains why forcing `.mp4` failed.
Opt-in `LegacyManualNames=1` now returns an allocated empty class-extension BSTR,
retaining one class and exact-path checks. The new candidate passes offline checks;
empty File-column/manual suffix behavior and rendering still need a real 23 trial.
It is a manual-name alternative, not established automatic per-template naming.

F-061 traces VEGAS 23 build 278's filename path at EXE RVA `0x2CF736`:
`SfFio_Template_GetFileExtOverride` first, then `SfFio_GetDefaultRendererExtension`.
The former in sharedk (`50C1FA42…757CE377`) at `0x6BFD30` is a closed switch on
eight built-in template-owner GUIDs. Our owner matches none. The latter at
`0x39B1A0` requests class string ID 4, keeps the first semicolon-delimited wildcard
and removes its `*`. This supplies a concrete reason for the observed MKV fallback;
it is not evidence for a new general per-template extension field.

The product now has opt-in `LegacyContainers=1`: five container-specific classes
with unique authored filter/type identities (MKV retains the original), one
advertised extension each, catalog-preserving starter grouping and shared C2/C4
container binding. Default mode remains one modern class. New declaration shapes
are not needed. The candidate is fake-host tested and installed with approval at
2026-11-05 09:51:27 +08:00, but not real-23 render qualified; see STATUS and the
investigation's legacy trial record. It remains an experimental fallback.

F-059 adds a VEGAS 23 build-278 text-reader constraint: names/notes start at
`0x218 + round_up(cbExtra, 4)`, as observed in the copied EXE at RVA `0x2DCC80`.
Current native recipe placement uses 0–3 zero bytes outside the core envelope to
satisfy this boundary while reading old unpadded/WORD-padded snapshots. The
standalone 12-starter candidate passes offline checks; no new visual/real-render
pass or installed replacement follows from those tests. A separate real 23 render
failed because an MP4 recipe received an MKV filename, before acquiring frames.

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

The owner-authorized 2026-10-17 container implementation adds shared C2 native
target preflight, C4 target propagation, exact suffix/path enforcement, retained
temporary suffixes and C6 demuxer-family readback. Core/engine/fake-host checks
establish implementation behavior only. The recipe class now advertises all five
extensions using the exact 2026 MP4 writer's semicolon ID-4 contract. Slot 17,
selector 11 supplies the template's core-derived UTF-16 wildcard (capacity in
WCHARs); its MP4 writer/host static chain and exact-module identities are in the
[container plan](product/NATIVE_CONTAINER_PLAN.md). Other selectors stay unknown.
Real Render As defaults/filtering, switching, new-container renders and two-container
template restart remain unqualified. See that plan
and current STATUS for results. Existing imported observations retain their scope.

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
