# Internal VEGAS adapter implementation plan

Updated: 2026-10-10 (Asia/Singapore). Status: implementation blueprint. This user-created repository is named
Vegas Encoder. Gate completion and pending real-host checks are tracked in
[STATUS.md](STATUS.md); the original research plan is preserved in provenance.

The adapter, internal native helpers and encoding engine belong in one product
repository. The investigation remains a separate sibling. See
[ARCHITECTURE.md](ARCHITECTURE.md) for ownership, future UI/preset
direction and the decision to postpone a public SDK.

## 1. Outcome and first supported path

Deliver a production foundation that:

- Appears in VEGAS Render As through its own exporter discovery and identities.
- Reads timeline video and audio, validates input and balances host references/locks.
- Feeds owned buffers to the existing external FFmpeg transport with bounded waits.
- Reports progress, differentiates success/cancel/failure and cleans up each job.
- Repeats successfully in one VEGAS session after success, cancellation or failure.
- Can save one product setting through a VEGAS template and use it after restart.
- Builds and runs fake-host checks from the product checkout alone.

Start with the exact selected host in [TARGET.md](TARGET.md):
`C:/Program Files/BorisFX/Vegas Pro 2026/vegas2026.exe`, version 2026.0.3.189,
x64, SHA-256 `2B93C6613E1BDD4A435B65F63E3FC0B0EAD9EDB06B45F2458C43B63F784A73AF`.
This is the previously verified identity, not a fresh hash check in this task.

Initial encoded path: P010 video, square pixels, supported constant frame rate,
optional float32 stereo at 48 kHz, FFV1/PCM float in MKV using a user-selected
FFmpeg executable. Retain the current implementation's supported rate list until
new rates are tested. Retain a raw diagnostic sink for comparisons. BI_RGB has
raw-export evidence; it is not yet part of the encoded adapter baseline.

No general VEGAS automation API, reader/import plug-in, video-format negotiation
through untested methods, HDR/alpha guarantee, audio-only encode, codec catalog,
public SDK or richer UI framework is required for this foundation.

## 2. Evidence baseline and unresolved questions

| Area | Existing evidence | Limit / required new proof |
| --- | --- | --- |
| Native declarations | F-026/F-027: proxy/stub IDs, slots and widths; used methods observed in F-030/F-031 | Unused declarations and inferred names are not guaranteed; video slot 12 differs between hosts |
| Discovery and allocation | F-033/F-038/F-041: discovery sequence, host allocator, render-only answers | Cache key and several capability meanings remain unknown |
| Template layout and conformance | F-033/F-036/F-038: fixed part, private bytes, audio records and source-default conformance | Arbitrary product payload persistence and configuration exchange not implemented |
| Timing and end of audio | F-041: stream/frame rate takes priority over template rate; final Read can return S_FALSE with data | Broader frame-rate/format combinations need qualification |
| Native cancellation and repeats | F-045: raw 0.1.1 repeats and observed slot-6 `0x8004E00C` cancel; renderer returns `0x8004E017` | This does not qualify the FFmpeg-backed build's blocked waits or error paths |
| FFmpeg offline behavior | F-048: decoded fixtures, fractional rate, short reads, video-only, cancel and selected failures pass in fiohost | Fake streams are consistency tests, not real-host compatibility evidence |
| FFmpeg real-host success | F-050: one short fixture passes on 2026.0.3.189 with installed 0.2.0 | Repeat/cancel/error, fractional/1080p and slow/long real renders remain pending |
| Configuration UI | F-032/F-033/F-038: property-page calls observed on Voukoder Pro | Our exporter exposes zero pages; VEGAS-specific template-editing interface, ownership and commit behavior need recovery |
| Container naming | F-050: class-wide `*.mkv` and successful MKV path | Per-template extension behavior is unproven; keep one container initially |

Keep [INTEGRATION_CONTRACT.md](INTEGRATION_CONTRACT.md) as the evidence authority.
Any proposed helper or internal product interface below is an implementation
design, not a new native host method or a recovered original SDK definition.

## 3. Source migration map

Import an exact snapshot before restructuring. These are candidate destinations,
not existing product paths:

| Investigation input | Product destination / treatment |
| --- | --- |
| `src/sdk/sfio_abi.h` | `src/vegas/abi/`; preserve layout assertions, uncertain names, finding IDs and provenance |
| `src/ffbridge/plugin.cpp` | `src/vegas/adapter/` for discovery/exporter identity; move checked byte access and host allocation mechanics into `src/vegas/host/` |
| `src/ffbridge/render.cpp` | Split host readers/frame leases into `vegas/host`; scheduling and job coordination into `vegas/adapter`; diagnostics into a product logging/sink module |
| `src/ffbridge/ffbridge.h`, `diag.cpp` | Separate declarations by responsibility; template mechanics to `vegas/host`, product config/reporting elsewhere |
| `src/ffbridge/encode.h`, `encode.cpp` | Seed `src/engine/`; keep current process/pipe behavior first, then introduce plain media/job types |
| `src/fiohost/` | Seed product fake-host tests; document any comparison-connector mode separately from normal fake tests |
| `scripts/Make-BaselineMedia.py`, raw/encoded checkers and relevant tests | Self-contained deterministic fixture generation and output verification in the product |
| `scripts/Test-FfmpegProof.ps1` | Product baseline runner, with paths updated and current coverage preserved |
| `scripts/Install-FfBridge.ps1` | Seed reversible product installer; identity/path decisions must be deliberate |
| Build scripts and `.def` / `.ini` | Preserve x64 toolchain and baseline behavior, update only necessary paths at import |
| `src/fioprobe/`, binary decoders, raw captures | Remain investigation tools/evidence; not a product runtime dependency |

Include the current HEAD and per-file hashes in `ORIGIN.md`: the 0.2.0 source
baseline includes uncommitted work, so `791baa32a3358d1b9c93bada45be2aeca07caf6b`
alone is insufficient. Save an import manifest and source snapshot/patch. Keep
the pinned upstream reference read-only; record origin/attribution for reused work.

Maintain production code in the product after extraction. Preserve this repo's
prototype and its evidence rather than silently replacing historical inputs.

## 4. Internal contracts and dependency rules

### Native layer

`vegas/abi` centralizes native declarations. `vegas/host` supplies checked views,
allocator access, retained COM references and frame leases. `vegas/adapter` owns
exporter identity, preset definitions, Render As responses, source-default policy,
render scheduling, progress translation and orchestration of the product job.

Helpers must carry their supported host/layout profile and evidence limitations.
Keep unknown template bytes opaque. Do not infer undocumented flag meaning from
a successful copied value or call an untested method simply because it is declared.

### Product-facing data

The adapter hands the engine plain values and owned media storage. Proposed
concepts are a media description, video packet, audio packet, immutable job
configuration, cancellation state and final job result. Final names/signatures
are implementation choices; no public API compatibility commitment is required.

Each video packet needs frame index, rate/timing basis, dimensions, pixel layout,
plane/stride description and owned bytes. Each audio packet needs start sample,
sample-frame count, rate, representation, channel description and owned bytes.
Unknown color metadata stays explicitly unknown. Copying bytes does not establish
color matrix/range correctness or HDR support.

The engine does not include VEGAS declarations, receive `ISf*` objects, retain
host buffer pointers or call host progress. The engine may use Windows process
and pipe facilities; host independence does not imply immediate cross-platform support.

### Ownership and threading

| Resource | Owner / lifetime rule |
| --- | --- |
| Incoming template | Copy validated settings into the render object; no reliance on a later conform call or UI object lifetime |
| Template returned to VEGAS | Allocate through the evidenced host allocator; do not substitute a C++ heap buffer or guess the unverified allocator Free slot |
| Retained host interfaces | Balance references on replacement, failure, CloseFile and destruction according to the established native contract |
| Video frame and frame lock | Acquire/read/validate/copy/release on the Render caller thread; one release attempt per successful acquisition, including failure paths |
| Queued video/audio bytes | Product-owned storage transferred to the engine; release the host video lease before transport/backpressure waits |
| Encoder, pipes and workers | Owned by one render job; bounded shutdown and joined workers before final stats/destruction |
| Editor configuration | Per-dialog draft; a running render uses its own immutable snapshot |

Preserve the current conservative policy of calling host readers/progress only
on Render's caller thread. F-048 verifies the implementation uses this policy;
it does not prove VEGAS permits cross-thread interface use. COM object reference
counting alone does not establish full thread safety or simultaneous render support.

### Timing and results

Derive timing from actual stream/frame information, with the existing supported
rational-rate mapping. Verify consistent rates and sample counts; use cumulative
integer sample endpoints to avoid per-frame rounding drift. Handle short reads
by advancing actual returned samples, and consume valid final S_FALSE data.

Use distinct internal success/cancel/failure results with original HRESULT and
encoder exit details. Recognize the observed slot-6 cancel signal; preserve the
evidenced native render-stop return for user cancel. Stop on other failed host
calls while preserving their identity. The current implementation groups failed
progress calls as cancel; tightening that behavior is a separately tested change,
not something to alter silently during the import.

Report success only after encoder exit zero and final output publication. Record
cleanup failures, preserve existing destination bytes, and keep partial outputs
out of the completed-output path. Do not translate an encoder failure into a
successful render or an unexplained user cancellation.

## 5. Milestones and implementation tasks

Each milestone is a reviewable change with its own experiment, inputs, tool/build
identities, raw output and observed checks. Gate state is tracked in STATUS.md; existing research
proofs are prerequisites and comparison inputs, not completion of product milestones.

| ID | Deliverable | Dependency | Acceptance gate |
| --- | --- | --- | --- |
| A0 | Qualified import baseline and evidence manifest | Existing F-048/F-050 candidate | Real repeat/cancel/failure comparison evidence, explicit remaining limits |
| A1 | Independent product checkout with exact import | Reviewed architecture; selected source snapshot | Builds and fake checks use only the product checkout and documented tools |
| A2 | Internal ABI and host helpers | A1 | Layout, ownership, template and failure-path tests preserve baseline behavior |
| A3 | Adapter-to-engine boundary and render job | A2 | Owned media only, rational timing, bounded waits, no native interfaces in engine |
| A4 | Extracted adapter parity on VEGAS | A0–A3 | Real fixture/repeat/cancel/error checks and cleanup pass on recorded host/build |
| A5 | Native configuration exchange recovery | Can research after A1; build proof after A4 | Evidenced settings-object/template handoff and page lifetime |
| A6 | One-setting save/restart/render proof | A5 | Applied setting persists; Cancel preserves unapplied state; renders remain stable |
| A7 | Versioned settings snapshot boundary | A6 | Payload, migration and recipe-independence checks; real save/reload proof |
| A8 | Adapter foundation closeout | A4, A6, A7 | Support matrix, reproducible checks, reversible install and known limitations |

### A0 — Select and qualify the import baseline

1. Record host, candidate DLL, FFmpeg and fixture identities. Recheck target bytes
   before new runtime work; update target/findings/status if they changed.
2. Preserve the installed 0.2.0 candidate and rollback information from F-049.
3. Run the existing short fixture twice, cancel a longer render, then render the
   fixture again in one VEGAS session. Decode successful outputs and inspect cleanup.
4. Exercise a missing/early-exit encoder and destination failure under a reproducible,
   restorable configuration; distinguish discovery failures from render failures.
5. Record normal and failed HRESULTs, lock/reference counts, process exit and partial
   output state. Establish a measurable cancel/shutdown budget from the configured
   bounds; specify the limit before running the test.
6. Keep slow/long, fractional/1080p and full color qualification explicitly open if
   not exercised; use the existing [Phase 3 plan](ENCODING_BASELINE.md) for broader gates.

Gate: a defensible baseline for parity comparisons. Documentation/skeleton work
may proceed before this finishes; runtime-parity and release claims depend on it.

### A1 — Create an independent product baseline

1. Use the reviewed sibling directory name; initialize the product's own Git repo
   when implementation is requested. No commit or remote publication is automatic.
2. Import selected authored files and document hashes, file map, evidence references
   and attribution in `ORIGIN.md`. Exclude installed/third-party binary payloads.
3. Keep current x64 MSVC/C++17 build behavior initially, including export definitions.
   Remove absolute investigation-checkout includes and script paths. Document tool
   prerequisites and an override for the local compiler setup path.
4. Bring deterministic fixtures/checkers and the fake-host suite into the product.
   Normal fake tests must not require loading Voukoder or an installed VEGAS.
5. Choose discovery name, CLSID/type/preset IDs and install destination deliberately.
   The recommended development default is a distinct product identity so the proof
   installation remains available. New IDs require new templates; automatic migration
   of old proof templates is not assumed.
6. Build and run the baseline from an independent checkout location, including spaces
   in its path. Compare imports and decoded outputs to the preserved baseline.

Gate: self-contained build/validation. Build output alone is not VEGAS validation.

### A2 — Separate native declarations and host helpers

1. Centralize headers in `vegas/abi`; retain widths, calling conventions, zero-based
   slot comments, alignment/layout assertions and uncertain-field annotations.
2. Extract checked template byte access. Validate minimum/total size, arithmetic,
   section ranges, private payload bounds and text termination before reading.
   A byte-view validates a trusted pointer's declared span, not arbitrary process
   memory accessibility.
3. Preserve owner/preset IDs and private bytes through source-default conformance.
   Keep the null-source/no-change path and Create-without-fresh-conform behavior.
4. Extract host allocator and retained-reference handling. Test failed queries,
   allocation failure and replacement cleanup without guessing missing allocator API.
5. Extract frame leases and supported token/plane validation. Test both observed
   token modes as supported by the existing in-process path; reject other PIDs/modes,
   impossible offsets/sizes and unsupported layouts with clear diagnostic evidence.
6. Separate stream reads from product reports. Use injected diagnostics/context where
   needed; do not make helpers depend on preset storage or FFmpeg command construction.
7. Avoid adding host service tracing or unused interfaces to make the helpers generic.

Gate: focused fake-host/helper checks plus unchanged baseline decoded output. Record
the limits of fake objects and qualify behavior changes again on VEGAS.

### A3 — Establish the adapter and encoding job boundary

1. Separate native discovery/render objects, adapter scheduling, plain media types,
   and encoder implementation. Keep one fixed encoding profile during this step.
2. Snapshot final template configuration for Create/Render. Retain readers supplied
   later by the host; do not assume Create already contains streams or filename.
3. Model prepared, running, finalizing, succeeded, cancelled, failed and closed states.
   Cleanup must be idempotent and tolerate failed start, repeated CloseFile and destruction.
4. Copy validated video into owned storage and release the lease before encoder
   startup, queue waits, writes or finalization. Account for staging and queued bytes.
5. Read audio with cumulative sample endpoints, valid short-read handling and actual
   stream length checks. Reject mid-render format/rate changes for this baseline.
6. Preserve concurrent independent audio/video pipe delivery and bounded queue/wait
   behavior. Poll host cancellation from the caller thread during blocking phases.
7. Preserve explicit process ownership, exit/error capture, cancellation cleanup and
   final output publication. Keep UI notifications outside engine transport logic.
8. Translate job results at the adapter boundary. Catch C++ exceptions at native
   entry points and retain original failure details in logs.

Gate: fixture-exact fake-host render, fractional mismatch, short/final reads,
cancel during startup/backpressure/finalization, encoder exit, existing destination,
failed acquisition and release paths. No host interface/pointer reaches a worker.

### A4 — Qualify the extracted adapter on the real target

1. Check the new DLL's discovery config, dependencies and identity separately from
   its ABI. Use the reversible installer; preserve the proof installation/rollback.
2. Capture the new product DLL and host hashes. Confirm Render As discovery, visible
   presets (including the existing slot-0 workaround) and fixed MKV filename behavior.
3. Render/decode the 90-frame / 144,000 stereo sample-frame fixture. Check counters,
   markers, audio onsets and presentation timing with the existing checkers.
4. Repeat, cancel under a transport wait, trigger encoder/destination failure, and
   render again. Verify no leaked child/worker/host lock or published partial file.
5. Run the fractional, 1080p and slow/long cases before claiming the broader matrix.
   Define wait/memory/time limits from implementation settings before each experiment.
6. Compare normalized call sequence and decoded content with the baseline. Do not
   require cross-render byte-identical chroma: F-045/F-050 show small variation.

Gate: evidence for the extracted build on the exact target. Other versions remain
unqualified. If GUI/debugger control is unavailable, prepare the procedure and
mark the real-host gate pending while continuing independent work.

### A5 — Recover the configuration exchange

1. Pose a narrow native question: how does VEGAS give a property page editable
   template state, and how does Apply return updated state to the template?
2. Inspect existing F-032/F-033 captures and proxy/stub declarations first. Determine
   whether the FileIO-specific property-page interface adds a template exchange.
   Recover IDs, method shapes, allocation/lifetime and HRESULTs with evidence.
3. If existing captures are insufficient, prepare a focused, reversible probe of
   the known-working Voukoder Pro configuration workflow. Capture page creation,
   QueryInterface, settings exchange, Apply/Cancel, close/reopen and template save.
4. Implement only the measured host bridge, using the standard COM property-page
   lifecycle where applicable. Test site/object references and repeated activation
   in a small harness before loading the page into VEGAS.
5. Confirm actual parent/window/thread context. Avoid assuming the render thread is
   also the UI thread or that an object from SetObjects is a raw template pointer.

Microsoft documents the generic page lifecycle and object-reference rules:
[IPropertyPage](https://learn.microsoft.com/en-us/windows/win32/api/ocidl/nn-ocidl-ipropertypage),
[SetObjects](https://learn.microsoft.com/en-us/windows/win32/api/ocidl/nf-ocidl-ipropertypage-setobjects),
[SetPageSite](https://learn.microsoft.com/en-us/windows/win32/api/ocidl/nf-ocidl-ipropertypage-setpagesite).
Those documents do not define VEGAS's FileIO-specific template exchange.

Gate: a tracked native contract for editable settings and page ownership. If this
cannot be established, leave rich UI blocked on that question and continue adapter
render qualification; do not substitute an unverified host method.

### A6 — Prove one setting survives save and restart

1. Add one small page/control, using the standard native UI for the experiment.
   Avoid selecting the long-term desktop UI framework at this point.
2. Choose a bounded diagnostic setting, such as emitting an extra render report,
   so its effect is observable without expanding the encoding format/profile.
   This is a proof choice; it need not become a permanent user-facing option.
3. Edit a per-page draft. Apply validates and commits through the measured native
   exchange; closing with Cancel discards changes since the last Apply. If Apply
   was already pressed, do not invent rollback behavior without host evidence.
4. Save a named VEGAS template, close/reopen the configurator, restart VEGAS, choose
   the saved template, and render. Inspect the final Create payload and resulting report.
5. Test two distinct templates, unapplied cancellation, repeated page opening,
   changing source defaults, and Create without a new conform call. Verify independent
   state and stable output. Repeat the normal/cancel render checks after adding the page.

The standard Apply operation updates associated objects; native template persistence
must still be demonstrated in VEGAS.
[IPropertyPage::Apply](https://learn.microsoft.com/en-us/windows/win32/api/ocidl/nf-ocidl-ipropertypage-apply)

Gate: setting A and B persist separately, apply behavior matches captured host
semantics, unapplied edits do not leak, and a saved template renders after restart.

### A7 — Version the template configuration boundary

1. Define a product settings snapshot and a versioned private payload envelope
   containing a product marker, schema version, payload length and encoded data.
   Choose exact widths, encoding, limits and migration rules after A6 measurements.
2. Keep portable encoder/host preferences distinct from machine-local preferences.
   Save full edited recipe settings plus optional origin ID/revision. No library
   lookup is required during a render; "follow project" remains an explicit choice.
3. Validate payload before decoding, bound sizes, reject unsupported newer versions
   with an actionable error, and migrate only recognized older product schemas.
   Preserve the saved source payload on migration failure.
4. Carry the payload through conformance without changing unknown host bytes.
   Copy resolved settings into an immutable render job, separate from future UI edits.
5. Test empty/legacy proof payload, truncation, oversized lengths, malformed encoding,
   future version, two independent templates and a supported migration. Decide whether
   proof-template migration is supported before implementing it.
6. Prove a saved template still renders when its originating library recipe is edited,
   renamed, deleted or unavailable. Recheck save/restart on the real host.

Gate: versioned settings snapshot is independently validated and survives the
native template workflow. The full desktop preset catalog remains later work.

### A8 — Close the adapter foundation

1. Write internal integration docs in the product: build steps, evidence-backed
   native subset, module ownership, test runner and exact supported host/format matrix.
2. Verify install/update/uninstall on a fake installation tree, then document a
   measured real round trip with recorded restoration steps and file identities.
3. Record unresolved color, performance, start-up and extended-format limits. Include
   stage timings and queue high-water marks without claiming an unmeasured speed gain.
4. Record product version/source identity with host, DLL, encoder, settings schema,
   decoded results and cleanup evidence in each real-host qualification report.
5. Demonstrate independent checkout build/tests and a saved-template render without
   the desktop application running. The investigation remains provenance, not a dependency.

Gate: foundation checklist below is satisfied for its stated matrix. Commit or
publish only when requested. Record and preserve restoration steps for each install.

## 6. Focused validation matrix

| Case | Fake/unit checks | Real VEGAS observation |
| --- | --- | --- |
| Discovery/template listing | Factory queries, count/index/GUID and host allocator failures | Render As presence, slot-0 workaround, MKV extension and restart discovery |
| Template safety | Boundaries, text/private bytes, source-default conformance | Final Create settings, two-pass and no-fresh-conform paths |
| Frame ownership | Success/failure/exception release accounting, invalid layout/token | Recorded frame locks and stable repeated renders |
| Timing/audio | Fractional rate, mismatch, short reads, S_FALSE with data, invalid counts | Decoded counters, sample counts and sync at qualified rates |
| Backpressure/cancel | Slow sink and cancel at startup/wait/finalization | Bounded cancel, no surviving child/partial, next render succeeds |
| Failures | Missing/early-exit encoder, existing/unwritable destination, allocation failure | Actionable error, real HRESULT, cleanup and recovery render |
| Settings page | Site/object references, draft/Apply, decoding/migration | Save/reopen/restart, template separation and unapplied Cancel behavior |
| Preset independence | Full snapshot remains after recipe removal | Saved template renders without library lookup or running desktop app |
| Installation | Manifest-preserving fake update/uninstall | Recorded exact changes and rollback; unrelated plug-ins remain usable |

Use existing tools when they cover the behavior. Add focused tests for new
ownership, malformed-input and configuration behavior. Fake-host success cannot
replace a real-host gate. Keep raw commands, identities, logs and checker output
in evidence; summarize decisive results in tracked notes.

## 7. Risks and decisions for review

| Decision / uncertainty | Recommended initial handling |
| --- | --- |
| Product name and plug-in IDs | Vegas Encoder at `vegas-encoder`; distinct development identity assigned in import manifest |
| Proof-template compatibility | New product templates initially; migration is an explicit later decision |
| Configuration exchange unknown | A5 measured contract and A6 small native proof before richer editor |
| Several native fields/flags unknown | Preserve tested values/opaque bytes and documented limits |
| Source threads / simultaneous jobs | Caller-thread host access; no concurrent-render support claim without evidence |
| Container-specific extensions | Fixed MKV initially; investigate before multiple containers |
| Color/HDR/performance | No blanket guarantee; qualify independently with appropriate fixtures/measurements |
| UI hosting | Native proof first; shared editor design after page/persistence evidence |
| Build system | Preserve existing MSVC build first; broader packaging can follow |
| Host updates | Fingerprint again and requalify; never reuse old addresses as new evidence |
| Separate SDK | Deferred; internal helpers only until an actual consumer justifies extraction |

No speculative calendar estimate is attached. Native configuration recovery and
real-host access determine the schedule; work is tracked by completed gates.

## 8. Foundation review checklist

- [ ] Two-repository ownership and provisional product name reviewed.
- [ ] Exact import baseline/provenance, identity and migration policy selected.
- [ ] A0 baseline is sufficient for the intended parity claims.
- [ ] A1 independent build and fake tests pass.
- [ ] A2 native layouts, bounds, references and leases are checked.
- [ ] A3 owned-buffer boundary, timing and cleanup preserve baseline behavior.
- [ ] A4 real-host parity and stated failure/cancel matrix pass.
- [ ] A5 configuration exchange is evidence-backed.
- [ ] A6 one-setting save/restart/render proof passes.
- [ ] A7 versioned snapshot and recipe-independence behavior pass.
- [ ] A8 support matrix, reproducible checks and restoration procedure are complete.

After review, begin with A0 baseline qualification while preparing A1's import
manifest. Rich desktop/popup features follow the adapter foundation described here.
