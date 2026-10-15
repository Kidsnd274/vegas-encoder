# B6 recipe bytes, editor bridge and opt-in native candidate

The owner resumed B6 preparation and real-host testing on 2026-10-15. The opt-in
**0.1.6-recipe-proof** candidate connects fresh native recipe templates to the
existing frontend popup and recipe engine/C5 monitor. Default and historical proof
builds keep their previous paths. The owner's first 0.1.4 trial rendered successfully
but exposed text corruption and intermittent editor startup errors. The fix
candidate has since been installed by the owner. Distinct FFV1/libx264 recipe
renders, improved 0.1.6 startup and saved-template persistence across restarts
are owner-confirmed on VEGAS 2026.0.3.189. See [B6_TRIAL.md](B6_TRIAL.md) for
isolated data, testing and rollback. Foreground return after switching apps remains
faulty. A5–A7 are not fully qualified; controlled real failure recovery,
private-payload capacity and measured monitor performance remain open.

## Owned native payload boundary

`src/vegas/configuration/recipe_template.*` places the existing C++ core's `VEnc`
envelope directly in the evidenced private region at template offset `0x218`.
It does not define a second settings format, JSON serializer or domain validator.
The core's 16 KiB envelope limit remains a **draft product budget**, not a measured
VEGAS capacity. Core encoding uses canonical JSON, so an editor's object-key
insertion order cannot manufacture a setting change.

The byte helper checks the full owned span, exact declared `cbStruct` extent and
expected product owner GUID. Only `cbStruct` and `cbExtra` change in the fixed
native prefix. All remaining fixed host fields, preset identity, raw text
allocation, padding and any opaque declared suffix are preserved. Growing or
shrinking a recipe moves that entire suffix after the new private bytes. Reads
use the core's checksum/version/flags/schema validation; damaged or future data
is refused before any replacement. Inputs remain unchanged on failure.

Initialization accepts only a fresh product template with zero private bytes.
The historical `VENC`/`CFG1` proof cannot be read, replaced or initialized as a
recipe template. New product templates must be created deliberately; no proof
migration or automatic overwrite of an unknown private format is supplied.

The first real B6 trial exposed garbled names/notes with an odd `cbExtra=559`.
The original tests checked only this implementation's byte-based text reader and
missed a wchar-indexed consumer's byte shift. New native allocations round the
private length to an even number, inserting at most one zero byte **outside** the
strict VEnc envelope, before the preserved text suffix. Native reads strip only
that permitted alignment byte; the portable decoder still rejects trailing data.
Intact original odd B6 envelopes remain readable. This prevents recurrence for new
templates; it cannot reconstruct text already corrupted by a host save/rename.
The owner subsequently confirmed fresh template operation and persistence across
restarts for the tested recipes. Maximum private size remains unqualified. No saved
template is modified automatically.

`ReadRecipeSnapshot` returns an independent value for an immutable render
job. It reads no preset library, application files or machine preferences. Core
payload checks establish structure only; B6 must still compile/validate against
actual delivered media and the selected FFmpeg before rendering. Source color
facts, arbitrary host input formats and general Advanced output scopes retain
their existing limits.

## C4 transaction boundary

`RecipeTemplateDraft` keeps committed and pending snapshots on its creator UI
thread. BeginEdit fills the actual template name, recipe and origin from that
draft; the caller supplies a fresh session ID, owner HWND, native/core versions,
optional origin baseline, context and an immutable C3 capability view. Unknown
project facts remain null. The core validates C4 request/result shapes and recipe
semantics; the adapter enforces session identity and one terminal result.

- Only one editor transaction can be active. Host Apply is refused while it is
  open. Requests/results stay within C4's 1 MiB JSON bound.
- A missing, malformed, future-version, mismatched or unsuccessful-editor result
  consumes that session as cancellation and preserves the previous draft.
  Explicit Cancel also preserves earlier editor/host Apply results.
- A structurally valid result with recipe/domain/lint/capability/payload-size
  errors is rejected without changing pending or stored settings. Warnings may
  return with an accepted draft; they do not prove render qualification.
- Editor Apply updates the per-page draft only. Existing `vegasPrefs` and unknown
  snapshot metadata survive; no setting is committed to the host at this step.
- Host Apply prepares and copies all allocating state before calling the store.
  Only S_OK accepts a new baseline, using nonallocating swaps after host success.
  Failure, S_FALSE or an exception leaves the draft dirty and retryable. The
  store contract requires a synchronous independent copy and unchanged prior
  state on any other result; the measured holder bridge retains its existing
  matching-allocator/caller-storage ownership rules.
- Disconnect/Discard restores the last successfully committed snapshot. A late
  result after disconnect or a duplicate result cannot apply. Another UI edit
  does not mutate a previously copied render snapshot.

The callback seam is only a transaction interface, not a VEGAS ABI or a public
SDK. The transport below handles files and owned child lifetime. `recipe_page.*`
now supplies UI-thread startup scheduling, root-owner disable/restore and timer
polling through the existing native holder/allocator bridge. File/process launch
now runs in parallel through `EditorSessionTask`, with copied C4 values and a
retained DLL lifetime. The task owns its transport entirely on its worker, while
draft/window/holder operations remain on the page thread. No host interface is
handed to a worker. Render never
participates in edit sessions or waits for an editor/progress window.

## C4 file/process transport (offline)

`editor_session.*` accepts an explicit, existing absolute local session root and
an explicit executable/argv; it selects no user path and executes no shell. A
new UUID directory inherits that root's ACL. Core-validated requests are bounded
to 1 MiB, flushed into an adjacent temporary file and published before launch.
Root/ancestor/session directory handles reject reparse points and deny namespace
replacement while active. Tests exposed that attributes-only directory access
did not prevent rename; the implementation now pins with directory-list access,
sharing read/write while denying delete. A focused check verifies directory rename
is refused while adjacent child-file atomic publication still works.
The candidate creates its per-user session root after rejecting known reparse
ancestors; transport pins the existing root. Real-host/per-user ACL qualification
remains open.

The helper is created suspended, with no inherited handles, then assigned to a
kill-on-close job before resume. Process polling uses a zero timeout on the
creator thread. A prewritten result does not finish a still-open editor. Only
after child exit does the transport read a stable disk file with no write/delete
sharing; missing, malformed, future, foreign-session, oversized, linked or busy
results cancel. The core owns shape validation and the existing draft owns domain,
capability and payload validation. Nonzero exit discards even a valid Apply.
One transport owns one launch and one terminal result.

Explicit Cancel terminates only the owned job and discards any prewritten result;
polling can continue without a wait loop. Destruction closes the job, killing its
owned child/descendants, and never waits. A child still exiting at destruction
may leave a session directory for diagnosis. Once exit is observed, cleanup deletes
only direct known protocol files (including `.result.lock` and interrupted result
temps); it does not recurse or delete unknown entries/the supplied root. Cleanup
failure is reported with the retained path available through `Directory()`.

The low-level Start does synchronous local file/process setup on its owning worker.
The native page polls one copied result without joining startup; late teardown
retains the worker/DLL until it can terminate its owned child safely. Normal return
from a foreground editor re-enables its original native owner and follows explicit
GW_OWNER links to restore an iconic host. Background/crashed completion stays
passive. Actual total startup latency and the real Apply/minimize symptom require
the owner's 0.1.6 test; offloading alone does not prove a faster visible editor.
No launch-cancel UI was added. No editor or monitor is needed to render a saved
snapshot; the transport is never called from Render.

Current primary references, retrieved through Context7:
[Win32 API](https://learn.microsoft.com/en-us/windows/win32/api/) and
[MoveFileExW](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-movefileexw).
Directory-sharing behaviour above is additionally checked on this Windows host;
the documentation and offline files/processes do not qualify VEGAS page modality.

## Focused checks

```powershell
scripts/Test-B6.ps1
# Optional sanitizer mode; current continuation did not complete it:
scripts/Test-B6.ps1 -Asan
```

The optimized x64 `/W4 /WX` run passes **95 boundary + 89 transport checks**.
The prior snapshot/session checkpoint recorded 95 optimized/95 ASan passes.
**Current sanitizer validation is incomplete:** both unoptimized and optimized
attempts stalled at the boundary's creator-thread test after 87 checks, before
the new transport suite ran. No sanitizer error report or root cause was
established. The owner reported an antivirus alert during process/thread
inspection, stopped that investigation, then directed continuing without further
debugging. Temporary tracing/worker changes and sanitizer flag experiments are
removed. Do not claim a sanitizer pass for this checkpoint or infer a product
threading defect/antivirus false positive from the incomplete run.
The runner builds only under the platform worktree's ignored `build/` and rejects
known reparse output roots. The ASan runtime comes from the existing vcvars
environment; no runtime or machine-wide tool is installed.

Checks cover six authored recipes, independent owned reads, exact host/text/trailer
preservation on growth/shrink, both payload parities, owner/span/header bounds,
future/damaged/proof rejection, host allocation/envelope/C4 limits, native core
domain/lint/capability errors, canonical key order, single/duplicate/stale session
results, creator-thread rejection, Apply failure/exception/retry, discard after
prior Apply, immutable render values, and variable-payload fake-holder reference/
allocation balance. These 95 boundary checks use no process/UI/user state; fake
save/reload is an owned-byte simulation.

The transport suite adds **89 optimized checks** with actual Windows files and
authored fake child processes: Unicode/quoted/trailing-slash argv, fresh directories,
atomic request publication, reparse root/ancestor refusal, blocked live-directory
rename, early Apply before exit, explicit Cancel/crash/missing/malformed/future/
foreign/oversized/linked/directory results, core domain rejection, prior-draft
preservation, duplicate/caller-thread rejection, known-file cleanup, unknown-file
retention, child/descendant teardown and launch refusal. The first invalid-image
CreateProcess refusal changed this harness's process-wide handle count by 14;
after priming that path, repeated success/failure/cancel/teardown paths have equal
before/after counts. It is a steady-state check, not a claim about Windows runtime
initialization. Script syntax and whitespace checks pass. No real Flutter helper,
VEGAS, exporter installation, native page or monitor is used.

## Remaining B6 work and owner qualification

The native page and recipe/C5 bridges are implemented in the opt-in candidate;
the owner's next step is the real trial in [B6_TRIAL.md](B6_TRIAL.md), incorporating
the deferred Apply/Cancel/two-template/restart procedure. Frontend sources remain
app-owned and unchanged. The candidate still needs real-host evidence for:

1. Deliberately fresh product templates, full recipe/origin bytes at Create,
   correct name/notes after growth/shrink and odd/even private lengths, and a
   measured private-size capacity. Unsupported/newer payloads preserve original
   saved bytes and show an actionable refusal.
2. Owner/UI-thread/page lifetime and correct native Apply/Cancel behavior, two
   distinct saved templates after restart, unchanged prior Apply after a later
   Cancel, and a saved recipe that renders without library lookup or a running
   editor. A5–A7 remain open until these actual host observations exist.
3. Owned recipe/media/C3/C7 snapshots into the existing B4 engine, all host reads
   and progress on Render's caller thread, and frame release before transport,
   hashing or process waits. Monitor startup/publication cannot add a Render wait.
4. Actual normal render, cancellation/recovery and separately controlled real
   failure recovery, with decoded media, preserved destinations, balanced host
   locks and cleared owned children/partials on the exact recorded build/host.
5. C5 monitor initial context and no-focus behavior, then the owner's separate
   three-with/three-without render comparison (about 2% maximum time cost and
   under 120 MB). No timing claim follows from these offline draft checks.

The B5 slot-4 trial showed no useful visible text, and the owner dropped custom
dialog text; see [NATIVE_PROGRESS.md](NATIVE_PROGRESS.md). The B6 candidate does not
resume that investigation. The owner explicitly resumed B6 preparation afterward;
installation remains a separate manual step with the prepared rollback. Useful
numeric progress and the frontend window remain the target; performance is open.
