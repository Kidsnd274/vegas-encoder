# Native v1 container support: investigation and implementation plan

Status: investigation complete; shared-core/native/engine/editor implementation
is in the original checkout and passes focused offline checks and optimized builds.
Writer advertising and template-specific naming are now implemented and checked
against the candidate DLL. The installed 2026.0.3.189 trial has successful
MP4/MOV/WebM renders and owner confirmation of correct values passed to VEGAS
for all five containers. The owner closed the active test queue; MXF render/MKV
regression are skipped and two-container restart is unconfirmed. See STATUS for
the exact recipe scopes. Updated 2026-10-18
(Asia/Singapore). The earlier integration follow-ups are committed at `df1ff9a`.
The original read-only investigation made no production or trial changes; the
owner subsequently authorized implementation with bounded parallel agents.

Read AGENTS.md, STATUS, NEXT_AGENT and relevant product/native contracts first.
Use the original checkout and one current queue. The earlier explicitly parallel
implementation pass is complete; default to one agent unless asked otherwise.
No new worktree is needed.
Implementation authorization does not authorize commits, installation or VEGAS
trials. Preserve the installed containers/dashboard trial in this checkout and
the prior template-name-fix trial's platform-folder paths, candidates, isolated
data and exact rollback files. Do not reopen the owner-deferred encoder-failure
recovery or faster-progress/performance trials. Existing large-template restart
and other qualification limits remain unchanged.

## Conclusion

**Retained release feature (owner, 2026-10-17):** finish MP4/MOV/WebM/MXF in VEGAS
alongside MKV. MKV-only is not the selected final release scope. The installation/
status dashboard is the other retained unfinished feature; the owner makes the
installer. Skipped features in PRODUCT_SPEC must not be added to this naming task.

MP4, MOV, WebM and MXF can use the existing evidenced P010/float-audio delivery
interface. The former MKV-only candidate guards have been replaced in current source.
The remaining gate is real VEGAS filtering/default-name behavior and rendering
when templates select different containers. Changing FFmpeg's muxer or
renaming the finished output does not establish correct host integration.

Recommended direction: retain the current exporter identity, resolve the active
command's container through the shared C++ core, require the host destination's
suffix to match it, and publish to exactly that path. Advertise a class-wide
five-extension list using the exact-host writer contract established below.

## Findings and evidence

### Current implementation delta

- C2 `paths.target:{id:"vegas-native-v1",outputPath?:string|null}` exposes native
  admission in the shared core. C4 carries the same target; portable recipes and
  old sessions do not acquire target restrictions. `outputExtension` supplies
  active-command suffix guidance and corrects Advanced preview naming.
- Native Apply and actual-media Render compilation use that preflight for the
  five known containers. Suffix mismatch fails before acquiring frames; actual
  delivered-media and capability checks still run before spawning FFmpeg. The
  page and popup show the required suffix, while actual edit-time path stays unknown.
- Engine temporary output retains its final suffix beside the exact destination;
  exclusive creation, no replacement, cancellation and verification-failure
  retention remain. C6 readback adds demuxer-family evidence, with the same
  sampled 32-packet scope; exact MP4/MOV or MKV/WebM discrimination is not claimed.
- Recipe exporter `GetStrings` ID 4 now returns
  `*.mkv;*.mp4;*.mov;*.webm;*.mxf`, keeping MKV first. Historical fixed-profile
  proof builds still advertise only MKV. Writer selector 11 returns the active
  recipe's wildcard through the shared core, including Advanced output identity.
  Unknown selectors retain `E_NOTIMPL`; corrupt/unknown output cannot guess a
  suffix. Exact destination/suffix enforcement remains the final defense.

### Native filename implementation

VEGAS 2026 receives a format list and a per-template extension from the
exporter. Older hosts use the filename policy described in
[legacy naming](../LEGACY_NAMING.md). The private investigation repository
holds the original binary trace and supporting evidence.

## Naming recommendation and alternatives

**Older-host opt-in update, 2026-11-05:** the owner's Classic-method continuation
adds `LegacyAutoNames=1`, described in [legacy naming](../LEGACY_NAMING.md). It
resolves a nominal host suffix to the active recipe's core-derived extension in
SetFile, before admission/reservation. All existing guards and publication checks
then operate on that actual path, which GetFileName reports. One nominal MP4 class
keeps all starters; its UI suffix can remain misleading. This is an explicit
legacy exception to item 3 below, not a change to default modern behavior. Real
VEGAS qualification and installation approval are still required.

1. Keep the current exporter/type/preset identities and existing MKV templates.
2. Resolve the container from the active compiled command, never from its filename.
3. Require canonical suffix agreement, case-insensitively: `.mp4`, `.mkv`, `.mov`,
   `.webm` or `.mxf`. Refuse a mismatch with an actionable message; do not silently
   replace the destination, append a second final extension or disguise its bytes.
4. Show the required suffix on the native page and in the popup. The actual Render
   As path is unestablished in current edit sessions; keep it unknown there.
5. Establish class-wide list syntax from targeted existing exact-host static
   evidence, then qualify its UI behavior later. Do not guess a delimiter.

| Alternative | Tradeoff |
| --- | --- |
| One exporter advertising five extensions | Preferred: keeps the reviewed workflow and identities. A user may need to change the filename after choosing another container. Filter/default behavior needs qualification. |
| Five container-specific exporter types | Fallback if one class cannot provide usable naming. Requires discovery/factory/type identities, cross-container recipe-load restrictions and host qualification. Preserve existing MKV identities; this is not just five presets under the same class. |
| Automatic per-template extension | Useful if an exact-host mechanism is recovered. Its existence/semantics are currently unresolved. |

## Basic and Advanced identity and restrictions

Basic uses `container.format` and the catalog's emitted muxer. Extra arguments
cannot replace owned muxer/input/map controls. Compatibility errors block Apply;
measured warnings and unqualified-VEGAS information remain separate from errors.

Advanced requires a known output-scoped `-f` for the owned `{output}`. Inactive
Basic container controls and suffixes do not supply identity. Existing
`outputContainerId` establishes this distinction; it is independent of
`expectedStreams`, so both facts must be checked. A video entry alone does not
establish every codec-option scope. Audit ordering and trailing options after
`{output}` before accepting the output fact as native admission.

Keep unsupported in native v1:

- Missing, input-only or unknown output muxers, even with a plausible filename.
- Extra outputs and tee/segment/manifest output, whose complete output ownership
  is not the single owned file.
- General/duplicate maps, extra-input selection and complex-filter outputs whose
  stream scope is unknown; unestablished codec scoping must not become a guessed
  expected-codec fact.
- Audio-only commands, malformed commands and missing/repeated owned macros.

Simple filters are not automatically disallowed: distinguish unknown precision
from unknown output ownership. Current portable lint allows some commands with
warnings that the native candidate rejects; expose native admission through shared
core target context rather than globally converting all warnings into errors.

Current app preview paths use the Basic container's extension even in Advanced
mode (`app/lib/state/editor.dart` and `popup.dart`). Correct that presentation from
active compiled facts; it must not become an alternative source of muxer identity.

## Safe output invariants

- Use an exclusively created temporary file in the final directory, retaining the
  final suffix as already specified, for example `name.ve-partial-<job>.mp4`.
  Always retain an explicit output `-f`; suffix preservation is not inference.
- Preserve initial existing-destination refusal and no-replacement publication,
  including a destination created while encoding. Overwrite policy does not
  expand with container support. Engine-owned `-y` applies only to its temporary.
- Finish includes trailer/index/faststart work. Poll cancellation through finish,
  probe and the last pre-publication check; keep bounded waits and owned children.
- Verify before publication. Add container-family evidence without treating a
  shared FFprobe demuxer name as exact container identity. MOV/MP4 and MKV/WebM
  need tested discriminators for stronger distinctions, or explicit limits.
- Keep sampled-readback scope honest. Review legitimate muxer-generated streams
  with real fixtures before changing the strict stream-count policy; do not
  broadly ignore unexpected streams to make a format pass.
- Encoder/start/publish failures remove the owned unpublished temporary. Ordinary
  verification failure currently retains it for diagnosis; cancelled verification
  removes it. Preserve these distinctions and C6 retainedPartialPath reporting.
- A stopped job cannot claim published bytes. Later jobs use independent state.
  This plan requests no new owner-run deferred recovery trial.
- Host calls remain on Render's caller thread. Copy/release host frames before
  hashing, startup, queues or other waits. Render never waits on UI/status writers.

## Staged implementation plan

### 1. Agree contracts and resolve the bounded native naming question

Update CONTRACTS C2/C4/C6, PRODUCT_SPEC's filename-limit row,
SETTINGS_AND_COMMANDS, ADAPTER_PLAN and INTEGRATION_CONTRACT. Define supported
IDs, exact destination preservation, temporary naming and native admission errors.
Resolve extension-list syntax through the relevant exact-host parser/captured
exporter evidence; keep any remaining automatic per-template behavior explicitly
unqualified. No guessed selector/flag and no new investigation ledger.

### 2. Shared portable preflight

Affect `src/core/compile.cpp`, `lint.cpp`, `recipe.cpp`, `core.h` and necessary
C API wiring. Tighten output scoping; expose actionable issues through additive
C2 target context carried by C4. Use existing catalog muxer/extension data and
`outputContainerId`, avoiding duplicated recipe fields or a new payload schema.
Check the selected muxer against available build capabilities: current validation
checks the catalog container but lacks an equivalent muxer-presence check.
Keep all compile/validate/lint rules in C++, with no Windows or VEGAS headers.

### 3. Native integration

Affect `src/vegas/adapter/recipe_runtime.cpp`, `plugin.cpp`, `render.cpp`, and
`src/vegas/configuration/recipe_page.cpp` plus headers as needed. Generalize the
MKV checks, labels and advertising. Validate the known output identity and path
suffix before acquiring frames where possible; retain Render's defensive check.
Recompile against actual delivered media before launching FFmpeg. Preserve
conformance, the immutable Create snapshot, allocator ownership and old MKV state.

### 4. Engine naming, verification and records

Affect `src/engine/encode.cpp`, `recipe_job.h/.cpp`, and relevant C6 schema/model
readers. Generalize required-container error text; retain explicit allowed output
identity and suffix agreement instead of simply deleting the guards. Align
temporary naming with the contract. Extend verification with container evidence;
keep finish -> verify -> publish and existing failure/cancel cleanup. Record
actual path, command, verification evidence and retained partial consistently.

### 5. Popup and editor adoption

Affect `packages/ve_core` API/models/fakes, C4 models under `packages/ve_services`,
`app/lib/state/editor.dart`, `app/lib/state/popup.dart`, and the affected native,
popup/container/Advanced presentation. Show core-produced native restrictions
before Apply and derive Advanced suffix guidance from the active command. Keep
actual destination and delivered project facts unknown when unavailable. Do not
implement a Dart FFmpeg parser or change desktop preset save policy incidentally.

Update STATUS and NEXT_AGENT as milestones/limits actually change. Installation,
publication, commits and real VEGAS trials require their separate authorizations.

## Minimal focused automated checks

Extend existing tests rather than adding a parallel harness or rerunning broad
suites. No tests/builds were run for this investigation.

- `tests/core/core_tests.cpp`: five Basic containers and corresponding Advanced
  commands; misleading filename/inactive controls; last effective known muxer;
  absent/input-only/unknown muxer; trailing output options, multiple outputs,
  malformed macros and ambiguous stream scope. Validate missing muxer capabilities.
- `tests/host/recipe_runtime_checks.cpp`, `recipe_templates.cpp`, `recipe_pages.cpp`:
  shared preflight, container changes through Apply/conformance/Create, immutable
  snapshots, Cancel/rejection preserving bytes and required-extension guidance.
  Reuse existing bounds/CRC/allocator checks.
- `tests/host/recipe_render.cpp`: short fake-host/real-supplied-FFmpeg render for
  each new container plus MKV regression; exact SetFile/GetFileName/C5/C6 paths,
  real readback and decoded output. Existing fixtures need container parameters.
- `tests/engine/recipe_jobs.cpp`: changed temp names; initial/racing destination
  sentinel preservation; container/stream verification refusal; retained partial;
  cancellation during finish/probe; independent later job state. Exercise changed
  paths without multiplying the full recovery matrix across all containers.
- Affected package/widget tests and light/dark goldens: Basic and Advanced Apply
  restrictions, suffix guidance and unknown facts. Verify links/docs separately.

Use the existing measured recipes/settings as starting points: MP4 H.264/AAC with
faststart, MOV ProRes/PCM, WebM VP9/Opus, MXF DNxHR/integer PCM. Select measured
profiles/rates and a sufficient short duration for sampled decoding. Changing
only the container of FFV1/float-PCM is not a valid all-format smoke test.

## Necessary later owner-run VEGAS checks

After implementation/offline checks and explicit authorization, use the recorded
VEGAS 2026.0.3.189 target and an identifiable matched candidate with reversible
installation. Existing imported observations do not qualify a new binary.

1. Restart discovery; inspect Render As filtering/default suffix and switching
   templates/containers. Inspect the actual SetFile path rather than relying only
   on the displayed filename. Confirm useful mismatch guidance/refusal.
2. One short render per new container using the measured recipes, with Advanced
   used for one case. Inspect/decode media, final path and normal return. Cover
   MP4 faststart finalization. Record only the useful concise result/build scope.
3. Save two templates with different containers, restart and confirm independent
   container selection and filename guidance/rendering. This is not a repeat of
   the deferred large-payload capacity/restart experiment.

No broad real recovery/cancel/performance matrix is requested. The owner-deferred
encoder-failure recovery and faster-progress/monitor comparison remain deferred.
Offline checks establish implementation readiness; class/filter/path behavior
and successful new-container real rendering require the observations above.

## External documentation consulted

The find-docs skill was used through Context7, outside the default sandbox:
resolved FFmpeg to `/websites/ffmpeg_documentation`, then fetched output-format
option scoping and MP4/MOV faststart finalization (three commands total).

- [Official FFmpeg options](https://ffmpeg.org/ffmpeg-all.html): `-f` forces input
  or output format; otherwise output format is guessed from the extension.
- [Official muxer documentation](https://ffmpeg.org/ffmpeg-formats.html): faststart
  moves the moov index in another pass and has fragmentation limitations. Keep
  regular files for outputs; pipes carry inputs. Do not silently enable fragmentation
  or change existing completion semantics.
- Official FFmpeg [MOV demuxer source](https://github.com/FFmpeg/FFmpeg/blob/master/libavformat/mov.c)
  and [Matroska demuxer source](https://github.com/FFmpeg/FFmpeg/blob/master/libavformat/matroskadec.c):
  shared demuxer names explain why literal catalog-ID/format-name comparison is
  insufficient for exact MP4/MOV or MKV/WebM distinction.
- The later native-admission review resolved FFmpeg again through Context7 and
  checked the official manual's complex-filter aliases/file-argument forms and
  [FFmpeg 8.0 option source](https://ffmpeg.org/doxygen/8.0/ffmpeg__opt_8c_source.html)
  for the legacy script option. Native rejection covers these forms in both
  modes; portable command policy remains unchanged.

These current primary sources inform the plan; actual selected-build behavior
still needs the focused checks above. No new dependencies or tools were installed.
