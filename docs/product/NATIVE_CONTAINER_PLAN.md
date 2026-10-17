# Native v1 container support: investigation and implementation plan

Status: investigation complete; shared-core/native/engine/editor implementation
is in the original checkout and passes focused offline checks and optimized builds.
New-container real-host qualification has not started. Updated 2026-10-17
(Asia/Singapore). The earlier integration follow-ups are committed at `df1ff9a`.
The original read-only investigation made no production or trial changes; the
owner subsequently authorized implementation with bounded parallel agents.

Read AGENTS.md, STATUS, NEXT_AGENT and relevant product/native contracts first.
Use the original checkout and one current queue. The earlier explicitly parallel
implementation pass is complete; default to one agent unless asked otherwise.
No new worktree is needed.
Implementation authorization does not authorize commits, installation or VEGAS
trials. Preserve the installed
0.1.7 template-name-fix trial, its platform-folder paths, candidates, isolated
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
The unresolved native issue is how VEGAS advertises, filters and chooses output
filenames when templates select different containers. Changing FFmpeg's muxer or
renaming the finished output does not establish correct host integration.

Recommended direction: retain the current exporter identity, resolve the active
command's container through the shared C++ core, require the host destination's
suffix to match it, and publish to exactly that path. Advertise a class-wide
five-extension list only after establishing the exact-host parser syntax.

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
- **Still open:** `GetStrings` ID 4 advertises `*.mkv`. Bounded exact-module
  GetStrings/vtable/RTTI inspection establishes that AIF's semicolon list belongs
  to its reader; its writer returns only `*.aif`. This does not establish writer
  multi-extension syntax or prove the host parser/default behavior.
  No delimiter, flag or per-template callback was guessed. Complete this naming
  gate and later exact-host checks before claiming full native container support.

Validation results and the next queue are recorded in STATUS and NEXT_AGENT.
The following table records the pre-implementation investigation baseline; its
MKV guards and old temporary naming have since been replaced as described above.

Source references below describe the reviewed implementation; finding references
retain their historical host/build scope. The sibling investigation was consulted
only for the unresolved filename/extension ABI questions.

| Area | Established behavior and source/evidence | Gap or unresolved question |
| --- | --- | --- |
| Basic compilation | [compile.cpp](../../src/core/compile.cpp), Basic: emits `-f` from the five [container profiles](../../schema/encoder-profiles.v1.json); MP4 faststart is separate. | A compiled command is not native support or a guarantee for every codec/profile/rate. |
| Native editor admission | [recipe_runtime.cpp](../../src/vegas/adapter/recipe_runtime.cpp), `ValidateCandidateRecipe`: requires `outputContainerId == "mkv"` and an established video output. [recipe_page.cpp](../../src/vegas/configuration/recipe_page.cpp), `PollEditor`: invokes it after the popup returns Apply. | Deliberate candidate policy. The popup can offer Apply before this native rejection becomes visible. |
| Snapshot/conformance/Create | [recipe_template.cpp](../../src/vegas/configuration/recipe_template.cpp) preserves the complete core envelope and opaque native suffix. [plugin.cpp](../../src/vegas/adapter/plugin.cpp) preserves the snapshot through conformance. [render.cpp](../../src/vegas/adapter/render.cpp) decodes its owned copy at Create. | No new container payload representation is needed. Existing persistence observations concern the tested MKV recipes. |
| Render admission | `DoEncode` in render.cpp requires `.mkv`; its RecipeJob options require container ID `mkv`. [recipe_job.cpp](../../src/engine/recipe_job.cpp) checks that requirement before child creation. | Explicit policy checks, independent of P010, square-pixel, rate and audio-input restrictions. |
| Class-wide extension | plugin.cpp `GetStrings`, ID 4, returns `*.mkv` for encoding. [ADAPTER_PLAN](../ADAPTER_PLAN.md) and sibling [EXPORTER_CONTRACT](../../../vegas-ffmpeg-frameserver/docs/EXPORTER_CONTRACT.md), F-050, establish the working class-wide MKV path. | No reviewed evidence establishes multi-extension list syntax, preferred/default suffix or automatic suffix updates after template edits. |
| Render As filtering | Sibling EXPORTER_CONTRACT, F-041/F-044: exporter discovery works; preset index-0/id-0 is hidden, with exact index-versus-ID rule unknown. | This is not evidence of container-sensitive filtering. Capability flag meanings and per-template extension behavior remain unresolved. |
| Possible template callback | plugin.cpp `GetTemplateInfo` returns `E_NOTIMPL`; F-038/F-041 observed selectors 1, 9, 10 and 11 tolerated that answer. The recovered [ABI](../../src/vegas/abi/sfio_abi.h) defines no established per-template extension contract. | Do not assign extension semantics to a selector or add an older SDK callback from its name alone. |
| Destination lifecycle | F-041/F-045/F-050: `Create(null, 0)`, later readers and `SetFile`; success then `GetFileName`, `CloseFile`, release. Current render.cpp stores and returns the exact SetFile path. | A post-success GetFileName call does not prove earlier overwrite checks, queued destinations or other host state follow a changed path. |
| Temporary/publication path | [encode.cpp](../../src/engine/encode.cpp) uses `<destination>.<GUID>.partial`, `CREATE_NEW`, existing-destination refusal and MoveFileEx without replacement. | Actual temporary naming differs from [SETTINGS_AND_COMMANDS](SETTINGS_AND_COMMANDS.md) and [C2](CONTRACTS.md), which retain the final extension. |
| Verification | recipe_job.cpp samples the first 32 packets, checks decoded video readability, stream kinds/count and known codecs. | It does not currently validate container identity or perform a full-file decode/count. |
| Existing muxing evidence | [FFMPEG_WINDOWS](research/FFMPEG_WINDOWS.md): three supplied Windows builds, 85 matrix cases each, with explicit codec/profile/rate limits. MXF ProRes/DNxHR plus integer PCM worked at tested settings; float PCM failed. | Synthetic FFmpeg results do not qualify VEGAS filenames, native templates or arbitrary combinations. |

End-to-end path: portable recipe -> core compile -> popup result -> native
admission -> pending template draft -> host Apply -> VEnc snapshot -> conformance
-> immutable Create copy -> SetFile destination -> actual-media compile in
RecipeJob -> FFmpeg temporary output -> finish -> verification -> publication.
Rendering does not consult the preset library or wait for the app/monitor.

## Naming recommendation and alternatives

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
