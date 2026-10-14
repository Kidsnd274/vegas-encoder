# B6 preparation: recipe bytes and editor drafts

This is an **offline implementation checkpoint**, not completion of B6 or any
real-host gate. The default/proof exporters do not reference these new helpers.
No recipe page is exposed, editor/monitor launched, or saved product recipe
rendered by VEGAS. A5–A7, real two-template/restart persistence, controlled real
failure recovery and monitor performance remain unverified.

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

Odd-length payloads are supported by the owned-byte helper without assuming
aligned UTF-16. That does **not** establish VEGAS's native save/reload behavior,
maximum private length or text alignment. The existing holder/allocator bridge
can copy these variable-length values in the fake harness; the actual saved host
workflow still requires qualification. No host memory or saved template is edited
by these tests.

`ReadRecipeSnapshot` returns an independent value for a future immutable render
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
SDK. File transport, unique-directory creation, editor lifecycle/modality, owner
re-enable, crash cleanup and HWND validation are **not implemented here**. No
host interface is handed to a worker. Render never participates in edit sessions
or waits for an editor/progress window.

## Focused checks

```powershell
scripts/Test-B6.ps1 -Asan
```

Optimized and AddressSanitizer x64 builds each pass **95 checks** with `/W4 /WX`.
The latter instruments the boundary, existing holder/template helpers and core.
The runner builds only under the platform worktree's ignored `build/` and rejects
known reparse output roots. The ASan runtime comes from the existing vcvars
environment; no runtime or machine-wide tool is installed.

Checks cover six authored recipes, independent owned reads, exact host/text/trailer
preservation on growth/shrink, both payload parities, owner/span/header bounds,
future/damaged/proof rejection, host allocation/envelope/C4 limits, native core
domain/lint/capability errors, canonical key order, single/duplicate/stale session
results, creator-thread rejection, Apply failure/exception/retry, discard after
prior Apply, immutable render values, and variable-payload fake-holder reference/
allocation balance. No VEGAS, exporter DLL, application process, UI or user
settings were used. Fake save/reload is an owned-byte simulation.

## Remaining B6 work and owner qualification

Continue with a file/process transport harness using explicit fake children and
isolated roots, followed by the native page and recipe Render bridge only through
an opt-in candidate. Coordinate F5/F6 UI readiness via platform.md; do not edit
app-owned files. The app's F4 metadata requests remain separately queued in that
handoff and C2 remains unchanged by this checkpoint.

Before enabling the real adapter, the owner must choose when to resume the
previously deferred A5/A6 real Apply/Cancel/two-template/restart procedure in
[NATIVE_CONFIGURATION.md](NATIVE_CONFIGURATION.md). This checkpoint does not
reopen that deferred request automatically. The later real B6 candidate needs:

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

The B5 description/status-line trial has its own staged candidate and checklist
in [NATIVE_PROGRESS.md](NATIVE_PROGRESS.md). Approval for that trial would not
qualify or enable this B6 boundary, reopen deferred persistence automatically,
or authorize a future B6 installation.
