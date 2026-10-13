# App/platform contracts v1 — B2

Updated: 2026-10-13 (Asia/Singapore). **B2 core/FFI plus additive B0/F2 extensions.** These
shapes are the shared contract. Breaking changes require the owner and both
workstreams; additive fields stay in v1. Native core implementation/build hook is
delivered in B2; real system services remain B3. No native payload persistence, popup, progress-window or
VEGAS compatibility gate is passed by this handoff.

## Common conventions

- UTF-8 JSON, camelCase keys, UTC timestamps in `YYYY-MM-DDTHH:mm:ss.sssZ`
  (fraction optional). Integers fit signed 64-bit; HWND is a decimal **string**.
- Sizes are bytes, durations seconds, rates decimal kbit/s (1000 bits), speed is a
  realtime multiplier (2.06 means 2.06×). Null is unknown, never zero by implication.
- Major discriminator must be 1: `schema`, `vepreset`, `profiles`, `protocol`,
  `live`, `job`, `index`, or `machine`, depending on the object. A newer major fails
  with an actionable error and leaves source bytes intact.
- Unknown properties survive at their original positions, at every nesting level;
  `extensions` is also an optional object at every model level. Readers tolerate
  additive keys. Dart constructors/fromJson deep-copy into immutable storage;
  `toJson()` returns an independent mutable copy. A getter's default does not insert
  the property into saved JSON. `copyWith(quality: null)` explicitly clears it.
- `fromJson` provides **serialization**, not semantic validation. Real normalize,
  validate, compile, lint, complete, diff, estimate and payload logic belongs to C++.
- No filesystem paths, HWND or GPU choice in a portable recipe. Local paths exist
  only in machine settings, sessions, caches and job records.
- Production writers use an adjacent temporary file plus atomic replacement, with
  bounded reads (1 MiB JSON request/file; 16 KiB total payload envelope draft budget).
  A failed read/write never replaces a good prior value. These limits do not assert
  VEGAS's still-unmeasured private-payload capacity.
- Service failures use `ServiceException(code, message)`; core/FFI transport
  failures use `CoreException(code, message)`. Semantic issues return in results.
  Stable service codes include `REVISION-CONFLICT`, `READ-ONLY`, `NOT-FOUND`,
  `DEFAULT-NOT-FOUND`, `SESSION-MISMATCH`, `SESSION-RESULT`, `SESSION-CLOSED`.

## C1 — Recipe and profile data

[recipe.v1.schema.json](../../schema/recipe.v1.schema.json) is the draft structural
schema. `SETTINGS_AND_COMMANDS.md` remains the rule specification. Audio is a
**one-element array** in v1. Library metadata is outside the recipe; there is no
product `options` map.
Basic is `structured`, Advanced is `template`; both sets of settings are retained.

```jsonc
{
  "schema": 1, "id": "yt-h264", "name": "YouTube upload, H.264",
  "notes": "", "tags": ["YouTube"], "category": "web",
  "container": {"format": "mp4", "faststart": true},
  "video": {
    "enabled": true, "encoder": "libx264", "mode": "crf", "quality": 18,
    "bitrateK": 12000, "maxrateK": null, "qp": null,
    "speed": "slow", "tune": null, "profile": "high", "multipass": null,
    "depth": 8, "gopSec": 2, "color": "bt709", "extra": ""
  },
  "audio": [{
    "enabled": true, "encoder": "aac", "mode": "bitrate", "bitrateK": 320,
    "vbr": null, "level": null, "sampleRate": "source", "channels": "source", "extra": ""
  }],
  "command": {"mode": "structured", "template": ""},
  "vegas": {"frame": "project", "inputFormat": "p010"},
  "extensions": {}
}
```

Required recipe keys: schema, id, name, container, video, audio, command, vegas.
`video.encoder`, `audio[0].encoder`, `container.format`, command.mode/template are
required. Other absent encoder controls or null controls mean encoder default.
`enabled` reads as true, Extra arguments as empty, audio sampleRate/channels as
`source`, vegas.frame as `project`, vegas.inputFormat as `p010`. Null sampleRate,
channels, color, enabled or Extra arguments is invalid. Only quality/rate/profile/
speed/tune/depth/GOP/multipass controls permit null. Unknown encoders, containers,
rate modes, categories and color policies are preserved for core to flag.

Profile shape returned by `VeCore.profiles()`:

```text
ProfileCatalog {profiles:1, provenance:string, video:EncoderProfile[],
  audio:EncoderProfile[], containers:ContainerProfile[], compatibility:Compatibility,
  rateModes:{mode:{id,label,short,blurb}}, videoOrder:{groups:Group[]}, audioOrder:{groups:Group[]}}
Group {group:string, ids:string[]}
Compatibility {video:{codecFamily:{containerId:"ok"|"warn"|"no"}},
               audio:{codecFamily:{containerId:"ok"|"warn"|"no"}}}
ContainerProfile {id,label,muxer,ext,blurb:string}
EncoderProfile {id,label,codec,family,blurb:string, hw:string|null, modes:string[],
  quality:NumericControl|null, qp:NumericControl|null, speed:ChoiceControl|null,
  tune:ChoiceControl|null, profile:ChoiceControl|null, profileQuality:ChoiceControl|null,
  multipass:ChoiceControl|null, depths:{decimalBitDepth:pixelFormat}, depthDef:int|null,
  bitrate:{values:int[],def:int}, vbr:NumericControl|null, level:NumericControl|null,
  rates:int[], fixedArgs:string[], chroma:string|null, appleTag:string|null, paramsFlag:string|null}
NumericControl {flag:string, min,max,step:number, def:number|null,
  lowerIsBetter:bool, marks:[[number,string], ...]}
ChoiceControl {flag:string, values:string[], def:string|null, names:{value:label},
  slowFirst:bool, slowLabel,fastLabel:string}
```

Encoder fields not relevant to an encoder may be omitted/null. Profile-specific
additional facts (e.g. profileQuality.mbps1080/pixfmt, PCM bits, vendor, vbrMode)
survive in model.data and toJson. B0 embeds the mockup's 12 video/11 audio profiles
and five containers, including design-time Linux FFmpeg facts. **Not a Windows
qualification.** B1 owns `schema/encoder-profiles.v1.json` with recaptured facts.

## C2 — VeCore and the C ABI

Import `package:ve_core/ve_core.dart`. `VeCore` is synchronous and isolate-local;
create `NativeVeCore()` per isolate. The build hook bundles its DLL. Core operations
perform no filesystem or host I/O (DLL loading happens during facade setup).
The app must not implement these rules. Types and signatures are in
[api.dart](../../packages/ve_core/lib/src/api.dart) and
[models.dart](../../packages/ve_core/lib/src/models.dart).

```text
version -> CoreVersion {core:string,abi:1,schemaMax:1,contracts:1,isFake:bool}
profiles() -> ProfileCatalog
normalize(JsonMap) -> NormalizeResult {recipe:Recipe,issues:Issue[]}
validate(Recipe,{MediaDescription? media,CoreCapabilities? capabilities}) -> Issue[]
compile(Recipe,{required media,required CompilePaths paths,capabilities?}) -> CompileResult
lint(String text,{capabilities?}) -> Diagnostic[]
complete(String text,int caret,{capabilities?}) -> CompletionResult
estimate(Recipe,{required media,double? durationSec}) -> SizeEstimate
diff(Recipe before,Recipe after) -> FieldDiff[]
encodePayload(TemplateSnapshot) -> Uint8List
decodePayload(Uint8List) -> PayloadResult
```

```text
MediaDescription {video:VideoMedia,audio:AudioMedia|null,durationSec:number|null}
VideoMedia {width,height:int,fps:[positiveInt,positiveInt],pixfmt,sar:string}
AudioMedia {rate,channels:int,sampleFmt:string}
CompilePaths {ffmpeg:string,videoPipe:string,audioPipe:string|null,output:string,project:string}
CoreCapabilities {installationId,label,identityKey,version:string,
  encoders:{name:{kind:"video"|"audio",options:EncoderOption[],availability:EncoderAvailability,...}},
  muxers:{name:ContainerProfile}}
Issue {id:string,level:"error"|"warn"|"info"|"hint",field:string,message:string,
  params:object,fix:string|null,tokenIndices:nonnegativeInt[]}
Diagnostic {id,level,message,params,fix as above,start:int,end:int}
CompileResult {executable:string,argv:string[],display:CommandToken[],commandLine:string,
  advancedTemplate:string,resolved:ResolvedSettings|null,signalPath:SignalPathFacts|null,
  issues:Issue[],summary:RecipeSummary,overriddenFields:string[]}
CommandToken {text:string,role:"exe"|"global"|"input"|"map"|"video"|"audio"|"mux"|"output"|"extra"|"macro",
  field:string|null}
ResolvedSettings {videoEncoder:string,audioEncoder:string|null,videoMode:string,audioMode:string|null,
  quality:number|null,speed,profile:string|null,depth:int,pixfmt:string,gopFrames:int|null}
SignalPathFacts {video:StreamSignalFacts|null,audio:StreamSignalFacts[],source:SourceSignalFacts|null}
SourceSignalFacts {video:SignalFormatFacts,audio:SignalFormatFacts|null}
SignalFormatFacts {format:string,bits:positiveInt|null,chroma:string|null,label,shortLabel:string}
StreamSignalFacts {inputFormat,outputFormat:string|null,inputBits,outputBits:positiveInt|null,
  inputChroma,outputChroma:string|null,chromaChanged,conversion:bool|null,
  containerSupport:"ok"|"warn"|"no"|"unknown",inputLabel,outputLabel,conversionNote:string|null}
RecipeSummary {container,video,videoQuality,depth,audio,audioQuality,mode:string,
  videoEncoder:string|null,speed:string|null,command:bool}
CompletionResult {kind:"none"|"option"|"value",of:string|null,start:int,end:int,items:Suggestion[]}
Suggestion {value,description:string,type:string|null,defaultValue:JSON value,
  source:string|null,availability:"ok"|"missing"|"failed"|"unknown"|null}
SizeEstimate {available,approx:bool,videoKbps,audioKbps,bytesPerMinute:number,totalBytes:number|null,
  minBytesPerMinute,maxBytesPerMinute,minTotalBytes,maxTotalBytes:number|null,explanation:string}
FieldDiff {path:string,before:JSON value,after:JSON value}
Origin {presetId:string,revision:int,name:string}
TemplateSnapshot {recipe:Recipe,origin:Origin|null,vegasPrefs:VegasPreferences,writtenBy:string}
PayloadResult {snapshot:TemplateSnapshot|null,migrated:bool,issues:Issue[]}
```

`argv` excludes the executable; `display` includes it. paths.output is the already
selected preview path or the engine's temporary path, with the correct extension.
Core never invents pipe names or resolves machine settings. Runtime input facts
come from delivered media; desktop uses the documented sample. `durationSec` for
estimate is the File node's user-entered duration, not media.durationSec. If absent,
totalBytes is null. Advanced estimates return available=false. Estimates are core
results, including range/approximation; Dart must not calculate its own model.

`minTotalBytes` / `maxTotalBytes` are the range for the user-entered length, null if
there is no length, estimate or range. They are not figures the app scales itself.
Bitrate estimates have approx=false and no range; container overhead is excluded.
Filters and conflicting Extra rate-control options can return available=false.
`resolved.gopFrames` is the final emitted `-g`, including Extra overrides or the
FFV1 fixed GOP, null if no interval is emitted or established. UI formats the frame
count alongside the delivered rate; it does not round seconds into frames itself.

Field paths use `audio[0].bitrateK`. Diagnostics and completion start/end/caret are
**UTF-16 code-unit offsets**, end exclusive, matching Dart text selections. C++ must
map its UTF-8 parsing offsets; it must not return byte offsets as cursor positions.
Apply/render is blocked when any issue is error. UI can localize id/params; message
and fix are fallback copy. Unknown private options are warnings.

### Command provenance and signal-path facts (app review)

`CommandToken.field` is the controlling recipe path for click-to-field and lighting
tokens (e.g. `video.quality`, `audio[0].bitrateK`, `container.format`). An option and
its value both carry the path. Profile-generated defaults still point at the control
that owns them. Extra arguments point at `video.extra` / `audio[0].extra`, including
replacements; Advanced text points at `command.template`. Executable, generated
inputs/maps/globals and output paths have null: no editable recipe field produced
them. Field is a navigation target, not a complete dependency graph; a derived
option may depend on other fields too. Missing field in older results reads as null.
`overriddenFields` lists the generated recipe controls displaced by Basic Extra
arguments; use it for "set in Extra arguments" without parsing FFmpeg option names.
It is empty in Advanced mode and defaults empty for older results. Token optional
`sourceStart`/`sourceEnd` data are UTF-16 spans within the owning Extra/template text;
apps normally use issue indexes, not these internal provenance spans.

`Issue.tokenIndices` is a unique, ascending list of **zero-based indexes into that
CompileResult.display**, including the executable at index 0. It identifies actual
emitted tokens; it never indexes argv or a condensed UI view. Core returns indexes
after overrides and macro expansion. Issues can reference multiple option/value
pairs; a container issue can reference the muxer and affected stream's encoder.
An omitted option or a whole-recipe problem can have no tokens. Outside a compile
result (normalize/validate/payload), indexes are empty. Missing means empty for v1
readers. Apps map these indexes when grouping chips; they do not infer them from
message text or issue.field. Diagnostic ranges remain UTF-16 text offsets.

`signalPath` is independent of display text and issues. Video is null when disabled;
audio has one entry when enabled in v1 and is empty when disabled or unavailable.
Audio entries follow enabled recipe-row order. A non-null stream can still contain
unknown facts. Missing signalPath means facts unavailable (older result), not all
streams disabled. In Advanced mode core supplies only facts it can establish from
the active command, with unknown formats/bits/conversion null and unknown mux support.
It must not present the inactive Basic recipe as resolved command facts.
For general extra-input selection or multiple outputs, core keeps the delivered
source node but leaves unestablished stream/output facts unknown. It does not infer
which source/output FFmpeg's general stream-selection rules will choose.
`source` describes delivered input even when a stream is disabled. Its format
labels and the stream's inputLabel/outputLabel/conversionNote are fallback copy,
with numeric bits/chroma supplied independently. Apps may localize these labels
without deriving facts from a pixel/sample-format name. Unknown input formats keep
their raw name as a label and bits/chroma null. Basic `resolved` can also be null
when Extra arguments select an unknown final format; signalPath retains known facts.

Formats and bits describe the raw data delivered to the encoder **before compression**,
not the encoded packet format or compressed bitrate. Video uses FFmpeg pixel formats;
audio uses canonical FFmpeg sample formats (`flt`, `fltp`, `s16`, `s32`, etc.). For
example raw input `f32le` is `flt`/32 useful bits, AAC consumes `fltp`/32, and 24-bit
PCM uses an `s32` carrier with outputBits=24. Core supplies useful precision; the app
must not parse a format name to invent it. `conversion` includes layout, precision,
chroma, rate or channel conversion, but excludes codec compression and metadata-only
tagging. False explicitly means none; null means unknown. `chromaChanged` compares
video sampling (`4:2:0`, `4:2:2`, `4:4:4`); audio chroma fields are null.

`containerSupport=no` means the container cannot hold that stream. `warn` means it
muxes with a playback caveat, `ok` means supported by the selected rule set, and
`unknown` means unestablished. None asserts real VEGAS qualification. The app reads
this fact to draw a broken stream-to-container wire; no message parsing or local
compatibility calculation. Default fixture facts remain authored design samples.

[ve_core.h](../../src/core/capi/ve_core.h) defines counted UTF-8 in/out and
paired ownership. Windows x64 default C calling convention, no packing override:
ve_buffer is 16 bytes, data at 0 and uint32 length at 8. Both DLL/static core consumers
use the same sources in B2. No C++ type, Windows header or host pointer crosses it.

| C entry point | Request | Result |
| --- | --- | --- |
| ve_core_version / ve_profiles | no input | CoreVersion / ProfileCatalog |
| ve_recipe_normalize | `{recipe:object}` | NormalizeResult |
| ve_recipe_validate | `{recipe,media:null\|MediaDescription,capabilities:null\|CoreCapabilities}` | `{issues:Issue[]}` |
| ve_compile | `{recipe,media,paths,capabilities:null\|CoreCapabilities}` | CompileResult |
| ve_template_lint | `{text,capabilities:null\|CoreCapabilities}` | `{diagnostics:Diagnostic[]}` |
| ve_template_complete | `{text,caret,capabilities:null\|CoreCapabilities}` | CompletionResult |
| ve_estimate | `{recipe,media,durationSec:number\|null}` | SizeEstimate |
| ve_recipe_diff | `{before:Recipe,after:Recipe}` | `{diff:FieldDiff[]}` |
| ve_payload_encode | TemplateSnapshot | binary envelope |
| ve_payload_decode | binary envelope | PayloadResult |
| ve_session_request_validate | C4 EditSessionRequest | `{request:originalObject,issues:Issue[]}` |
| ve_session_result_validate | C4 EditSessionResult | `{result:originalObject,issues:Issue[]}` |

Transport failure returns ve_status and optional UTF-8 `{error:{code,message}}`;
output may be empty on allocation failure. Every returned allocation is freed once
with ve_free, including error output. Input memory is never retained. Semantic
validation errors return VE_OK with issues. All exceptions are contained at the ABI.
Payload layout is TECH_ARCHITECTURE §6.2, total draft limit 16 KiB, little endian,
CRC-32/IEEE of canonical UTF-8. Proof markers are rejected and never migrated. This
is implemented and tested offline; native placement/persistence stays gated A6/A7.
The two C4 helpers perform pure shape checks and preserve unknown fields. File I/O,
matching the expected session ID and one-final-result lifetime remain in services/
adapter. `NativeVeCore.validateSessionRequest/Result` expose these helpers as JSON.

Native reads reject duplicate keys, invalid UTF-8, overflowing integer literals and
nesting deeper than 64. Text tokenization follows CRT quoting and accepts pasted
line continuations. No shell expansion runs. Extra arguments cannot override
encoders or owned inputs/maps/mux/progress controls; choose the control or Advanced
mode instead. Extra inputs in Advanced mode must follow {inputs} to keep generated
VEGAS input indexes stable. Macro substitution is one pass: supplied paths/project
text remain literal, and expanded arguments are bounded to 1 MiB. FFmpeg remains
the final authority; profile/option bootstrap data is not Windows qualification.

### Using FakeVeCore

```dart
final core = FakeVeCore();
final fixture = core.fixtures.first;
final result = core.compile(fixture.recipe,
    media: fixture.media, paths: fixture.paths);
final estimate = core.estimate(fixture.recipe, media: fixture.media);
```

Defaults cover all six built-ins plus a popup snapshot, normalize, compile,
validation for the three illustrative installations, per-minute estimates,
seeded-command lint, preset completion, identical-recipe diff and binary payload
round-trip fixtures. `CoreFixture` exposes the precise context. Modified recipes,
paths, media, duration estimates, arbitrary commands/diffs require **injected
fixtures**. Unmatched requests throw B0-FIXTURE-MISSING; they never silently show
the original preset's result. Fixture keys are supplied by FakeVeCore's static key
helpers. Capabilities in default validation/compile select by installationId only;
these fixture results do not inspect or qualify an actual capability cache.
`CoreFixture.compileIssues` supplies capability-specific compile issues with display
indexes separately from standalone validations. Injected fixtures that omit it retain
the earlier fallback to their validations; provide it when highlights are needed.
Payload injection copies input/output bytes. Fake matching ignores only empty
`extensions` objects at any nesting level; it preserves source JSON and still
rejects genuine edits. No edited-state fixture sweep is added. `NativeVeCore` accepts
edits and supplied contexts directly, with no fixture lookup.

## C3 — System service APIs and fakes

Import `package:ve_services/ve_services.dart` (also exports C2 types). Pure Dart,
no Flutter dependencies. Futures do one operation. watch() produces a current
snapshot for **each** listener, then updates, without implicit scans/probes. Lists
and model data are immutable. Real services will use files/processes in B3.

| API | Operations | Fake |
| --- | --- | --- |
| FFmpegDiscovery | list/watch/scan/add(executablePath)/remove(id) | FakeFFmpegDiscovery |
| FFmpegProbe | probe(installation) -> Stream<ProbeProgress>; encoderDetails; cancel(id) | FakeFFmpegProbe |
| FFmpegHelpParser | version; parseEncoderHelp/parseEncoders/parseMuxers(text) | FakeFFmpegHelpParser |
| HardwareTests | test(installation,{encoders?,force}) -> Stream<HardwareTestResult>; cancel(id) | FakeHardwareTests |
| CapabilityCache | read(identityKey)/write(capabilities)/invalidate(identityKey) | FakeCapabilityCache |
| PresetLibrary | list/watch/get(id,{revision?})/save({expectedRevision?})/delete(id,{expectedRevision})/importPreset(jsonText,{newId})/exportPreset(id) | FakePresetLibrary |
| MachineSettingsRepository | read/watch/save(settings,{expectedRevision}) | FakeMachineSettingsRepository |
| JobRepository | list/watch -> JobIndexEntry[]; get(id) -> JobRecord? | FakeJobRepository |
| LiveRenderStatusReader | read(file)/watch(file) -> LiveRenderStatus? | FakeLiveRenderStatusReader |
| EditSessionService | readRequest(dir)/writeResult(dir,result) | FakeEditSessionService |

```text
BinaryIdentity {sha256:string,key:string,size:int,mtime:UTC,libraries:{dllFileName:sha256}}
FFmpegInstallation {id,label,path,ffprobePath,source,version,build,license:string,
  identity:BinaryIdentity,probedAt:UTC|null,probeMs:int|null,
  counts:{video,audio,muxers:int},availability:{encoder:EncoderAvailability},isFixture:bool}
EncoderAvailability {state:"ok"|"missing"|"failed"|"unknown",reason,detail,note:string}
EncoderDetails {name:string,kind:"video"|"audio",pixelFormats,sampleFormats:string[],
  sampleRates:int[],options:EncoderOption[]}
EncoderOption {name:string,aliases:string[],type,description:string,min,max,defaultValue:string|null,
  constants:OptionConstant[]}
OptionConstant {name:string,value:string|null,description:string}
parseEncoders result: {encoderName:{kind:"video"|"audio",flags:string,description:string}}
parseMuxers result: {muxerName:{flags:string,description:string}}
FFmpegCapabilities {installationId,identityKey:string,parser:int,version:string,
  encoders:map as CoreCapabilities,muxers:map as CoreCapabilities,
  hardware:{encoder:EncoderAvailability},gpuFingerprint:string,probedAt:UTC}
ProbeProgress {installationId:string,phase:"identity"|"lists"|"details"|"hardware"|"done"|"failed"|"cancelled",
  completed,total:int,message:string,capabilities:FFmpegCapabilities|null}
HardwareTestResult {encoder:string,state:"ok"|"missing"|"failed"|"unknown",tenBit:bool,
  failureClass:"runtime-missing"|"no-device"|"unsupported-format"|"timeout"|"unknown"|null,
  reason,stderr:string,testedAt:UTC,identityKey,gpuFingerprint:string}
Preset {vepreset:1,revision:positiveInt,favorite,pinned,builtin:bool,updatedAt:UTC,
  origin:string|null,requires:PresetRequirements,recipe:Recipe}
PresetRequirements {encoders:string[],minFFmpegVersion:string|null}
```

source is `ini|path|winget|scoop|chocolatey|manual`. identity.key combines executable
and sorted sibling library hashes and parser version in B3; hardware also keys GPU
fingerprint and driver versions. Literal option range/default strings preserve
INT_MIN/FLT_MAX/enum/scientific values. No fake runs FFmpeg. Default installations
are exactly the mockup's FFmpeg 8.1 full (gyan), 7.1.1 essentials (manual), and 8.0
LGPL shared (BtbN); identities/GPU results are deliberately synthetic and
isFixture=true. They **do not describe this PC** or replace its gyan 5.1.2 PATH build.
Probe details are the read-only prototype's captured option data, not B1 facts.

Fakes accept replacement seed values/results. Discovery.add requires an injected
path fixture; parser outputs are injected by exact text. Probe/hardware cancellation
stops subsequent emitted events. Cache is keyed by identityKey. Watchable fakes have
dispose(); cancel subscriptions before disposal. No timers or files are created.

Library root: `%APPDATA%\VegasEncoder\library\<id>.vepreset`. Save checks the
expected revision atomically, increments it and preserves the last 20 old versions
under `.history\<id>\<revision>.vepreset`. expectedRevision=null creates only;
conflicting saves fail. get(id) means current; get(id,revision:N) may return history.
Built-ins are read-only. Duplicate/import requires a new ID and writes a user
preset, origin `builtin/<id>` when duplicated from a built-in. Import/export JSON
round-trips unknown keys. Real import/save uses core validation in B3; the fake
stores supplied snapshots without claiming semantic validation. requirements are
derived by the real service, not by the app. favorites/pinned changes also Save.

## C4 — Edit sessions

Launch: `VegasEncoder.exe --edit-session <absolute-session-dir>`.
Root `%LOCALAPPDATA%\VegasEncoder\sessions\<uuid>\`, one page/session, inherited
per-user ACL. Files are request.json and result.json. Request shape:

```text
EditSessionRequest {
  protocol:1,sessionId:string,templateName:string,recipe:Recipe,origin:Origin|null,
  baseRecipe:Recipe|null,
  context:{hostVersion:string|null,project:string|null,media:MediaDescription|null},
  ownerHwnd:decimalString,dllVersion:string,coreVersion:string
}
EditSessionResult {protocol:1,sessionId:string,action:"apply"|"cancel",
  recipe:Recipe|null,origin:Origin|null}
```

Apply requires a complete recipe snapshot; origin may be null. Cancel has recipe
and origin omitted or null. The matching sessionId prevents consuming another
session's result. Only one final result is written. Editor Apply returns a draft;
the native page commits only on host Apply/OK. No library lookup during rendering.
baseRecipe is the origin revision's copied snapshot when available; null means
three-way update cannot be offered. Project facts may all be null: UI must say
"Set by the project"; sample preview facts must be labeled as samples.

Missing, invalid, newer-version, mismatched, or crashed-editor result means cancel;
no old draft leaks into the template. Result is written adjacent-temp then atomic
replace before editor exit. Native owner disable/re-enable and crash recovery are
adapter tasks gated on real-host evidence; Render never participates in sessions.
Sample request/apply/cancel files are in schema/fixtures/b0. FakeEditSessionService
seeds directory key `b0-session`; actual paths can be injected.

## C5 — Live render status

Launch: `VegasEncoder.exe --render-monitor <absolute-live-file>`.
Path `%LOCALAPPDATA%\VegasEncoder\jobs\<jobId>.live.json`. A job keeps one ID and
file for its lifetime. No commands, cancellation requests or pipe handles travel
through this file; cancel remains VEGAS's control.

```text
LiveRenderStatus {
  live:1,jobId:string,hostHwnd:decimalString|null,sequence:nonnegativeInt,updatedAt:UTC,
  state:"starting"|"encoding"|"finishing"|"verifying"|"done"|"failed"|"cancelled",
  framesDone:nonnegativeInt,framesTotal:positiveInt|null,
  encodeFps:number|null,speed:number|null,bitrateKbps:number|null,
  bytesWritten:nonnegativeInt,elapsedSec:number,etaSec:number|null,
  estimatedFinalBytes:nonnegativeInt|null,outputPath:string,templateName:string,
  encoderSummary:string,message:string,ffmpegExitCode:int|null
}
```

Sequence strictly increases; reader ignores duplicate/out-of-order snapshots.
Typical writer transitions: starting → encoding → finishing → verifying → done;
failed/cancelled may terminate any active phase. Readers can miss phases. `done`
means exit zero, verification passed (or explicitly disabled), and final publication.
Finishing/verification are not success. Failed verification may retain a temp file,
reported in the job record. bytesWritten is work so far; failure/cancellation does
not mean it was published. Unknown metrics remain null; ETA is advisory.

Worker writes at most twice a second plus phase/terminal changes, atomically.
Render never waits for the app, monitor startup, or file-reader acknowledgements;
failed monitor launch/status publication is logged and does not fail the render.
Missing initial file produces null. Malformed/incomplete replacements retain the
last good snapshot; a stale/disappeared file does not manufacture a terminal state.
Monitor must not steal focus; keep-on-top comes from C7. Window performance remains
subject to the owner's three-with/three-without real-host test and ~2%/120 MB rule.

`hostHwnd` is VEGAS's **main window**, for locating the monitor work area before
showing the progress window. It is not C4's template-dialog owner and establishes
neither modality nor window ownership. The writer includes it in the initial
snapshot before launching the monitor, then keeps it for that job. It is an unsigned
decimal string in 1…18446744073709551615; null/absent means unavailable. Handles
are process-local lifetime facts, never persisted in recipes or machine settings.
The app checks the handle still names a valid host window; an unavailable/stale
handle uses its normal placement fallback. No focus activation or wait on Render.

[schema/fixtures/b0/live](../../schema/fixtures/b0/live) contains a file for **each
of seven states**. These are alternative terminal examples, not one legal sequence
through done → failed → cancelled. FakeLiveRenderStatusReader.samples() returns
them; publish(file,status) drives tests and checks jobId/sequence. Reader creates
no timer/process and never touches VEGAS.

## C6 — Job records and index

Use one consistent root: `%LOCALAPPDATA%\VegasEncoder\jobs\` for records, live files
and index. Each completed/stopped job writes `<id>.json` atomically
then appends one UTF-8 line to jobs.jsonl. Index is a reference, not a second complete
record. Serialized index appends cannot interleave; readers ignore a truncated final
line and can reconstruct from complete per-job files. Retention/deletion is deferred.

```text
JobRecord {
  job:1,id:string,startedAt,endedAt:UTC,project,templateName,outputPath:string,
  status:"succeeded"|"failed"|"cancelled",recipe:Recipe,origin:Origin|null,
  recipeSha256:hexSha256,media:MediaDescription,ffmpeg:FFmpegInstallation,argv:string[],
  elapsedSec:number,sizeBytes:nonnegativeInt,avgFps:number|null,ffmpegExitCode:int|null,
  hresult:string,message,stderrTail:string,
  verification:{state:"passed"|"failed"|"skipped",message:string,
    expectedCodecs:string[],actualCodecs:string[],ffprobeVersion:string|null},
  timings:{phase:seconds},published:bool,retainedPartialPath:string|null
}
JobIndexEntry {index:1,id:string,recordFile:relativeBasename,startedAt:UTC,
  status:"succeeded"|"failed"|"cancelled",templateName:string,outputPath:string}
```

argv excludes the executable (ffmpeg.path supplies it) and includes actual temp
output and input names. recipeSha256 hashes canonical UTF-8 recipe JSON. FFmpeg
identity records the exact selected executable and shared-library hashes. hresult
is a zero-padded `0xXXXXXXXX` string, not a signed decimal. sizeBytes is published
size, zero when unpublished; retained partials are explicit. Record boundaries
must validate before History reads it. Five sample records reflect the mockup's
success, cancellation and failure, **all with illustrative installation identities**.
FakeJobRepository.publish(record) updates History test snapshots. No real job was
recorded by B0.

## C7 — machine.json

Path `%APPDATA%\VegasEncoder\machine.json`; app writes, DLL reads once at render
start. Missing file alone permits development INI FFmpegPath fallback. A malformed
file/newer major/missing selected executable does not silently switch to another
installation. No default ID means setup is required unless using the missing-file
development fallback. Each job snapshots the selection; edits cannot alter an
already-running render.

```text
MachineSettings {
  machine:1,revision:nonnegativeInt,installations:FFmpegInstallation[],
  defaultFFmpegId:string|null,progressWindow:bool,keepOnTop:bool,
  verifyOutput:bool,theme:"system"|"light"|"dark",uiState:AppUiState|null
}
AppUiState {desktopWindowBounds:DesktopWindowBounds|null,desktopMaximized:bool,
  lastSizeLengthText:string|null}
DesktopWindowBounds {x,y:int,width,height:positiveInt}
```

Defaults: revision 0, no installations/default, progressWindow=true,
keepOnTop=false, verifyOutput=true, theme=system. Default ID must name an installation.
No per-installation isDefault field exists: derive it from defaultFFmpegId. Changing
the default uses MachineSettingsRepository.save(expectedRevision), never editing
the portable recipe. The DLL needs defaultFFmpegId/installations, progressWindow,
keepOnTop and verifyOutput; theme is app-only. Real reads check binary identity/cache
without probing; unknown availability warns. Installed application path belongs to
installer configuration, not to a user-controlled monitor argument in machine.json.

`uiState` is app-only and defaults to null; the DLL ignores it. Desktop bounds are
the last restored (non-maximized) **outer window rectangle in physical screen pixels**
on the Windows virtual desktop; negative x/y are valid for other monitors.
desktopMaximized defaults false. The app restores/clamps bounds against the current
monitor work areas, minimum size and DPI; invalid/unavailable bounds use its normal
default. Popup/progress bounds are not restored from desktop bounds. `lastSizeLengthText`
preserves exactly what the user typed in the File node (including empty or incomplete
text), null if never typed. It is not a recipe duration or a total-size estimate;
display parsing stays app-side and numeric duration is passed to core. Popup project
length never overwrites this remembered desktop input automatically.

UI-state writes use MachineSettingsRepository.save(expectedRevision) like other
preferences: copy the latest settings, change uiState, retry a revision conflict by
reading and reapplying the UI change. This preserves another window's FFmpeg choice
or pin setting. Unknown keys survive at all three new model levels. Null explicitly
clears the saved state; older machine.json files need no migration. KeepOnTop remains
false by default.

## App handoff / validation

Path dependencies from app/: `../packages/ve_core`, `../packages/ve_services`.
`FakePresetLibrary`, `FakeFFmpegDiscovery`, `FakeMachineSettingsRepository`,
`FakeJobRepository` are ready without IO. Inject those behind app providers. Use
FakeVeCore.fixtures contexts, or inject edited-state fixtures for widget/golden
tests. The app owns display formatting, workflow, focus/window behavior, and skins;
platform owns domain/system rules. No app or design files changed for B0.

Run `scripts/Test-B0.ps1` for Dart model/fake contract tests, recipe/fixture bounds
and MSVC C/C++ ABI-header checks. `scripts/Test-B2.ps1 -Asan -Aot -Encoder` adds
static/DLL/FFI, sanitizer, bundled AOT and synthetic encoder checks. Dart pub
resolution uses the cached, pinned MIT/BSD dependencies; notices are in ve_core.
Existing fake-host/fake-installer
regression summaries and remaining gates are in platform.md and docs/STATUS.md.
