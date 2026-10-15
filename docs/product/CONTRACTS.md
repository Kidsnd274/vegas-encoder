# App/platform contracts v1 — B1/B2/B3

Updated: 2026-10-15 (Asia/Singapore). **B3 Windows services delivered.** These
shapes are the shared contract. Breaking changes require the owner and both
workstreams; additive fields stay in v1. Native core implementation/build hook is
delivered in B2; B3 discovery, probe, hardware tests, preset tests and repositories
are delivered below. No native payload persistence, popup, progress-window or
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
survive in model.data and toJson. B1's native catalog embeds 12 video/11 audio
profiles and five containers with measured Windows option/format facts. B0 fakes
retain their historical design samples. `qualification` identifies the help builds
and runtime limits; `policy` distinguishes product defaults, curated ranges/marks
and heuristic estimates from measured encoder defaults. FDK AAC is absent from all
three GPL builds: its sample format/bits stay unknown. Hardware help is not GPU
qualification. `compatibilityByAvformatMajor` contains sampled major 59/63 rules;
`compatibility` is their conservative consensus. See [Windows recapture](research/FFMPEG_WINDOWS.md).

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
normalize(JsonMap) -> NormalizeResult {recipe:Recipe,issues:Issue[],requiredEncoders:string[]|null}
validate(Recipe,{MediaDescription? media,CoreCapabilities? capabilities}) -> Issue[]
compile(Recipe,{required media,required CompilePaths paths,capabilities?}) -> CompileResult
lint(String text,{capabilities?}) -> Diagnostic[]
complete(String text,int caret,{capabilities?}) -> CompletionResult
macros({required media,required paths,Recipe? recipe}) -> MacroDefinition[]
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
  libavformatMajor:positiveInt|null,
  encoders:{name:{kind:"video"|"audio",options:EncoderOption[],availability:EncoderAvailability,...}},
  muxers:{name:ContainerProfile}}
Issue {id:string,level:"error"|"warn"|"info"|"hint",field:string,message:string,
  params:object,fix:string|null,tokenIndices:nonnegativeInt[]}
Diagnostic {id,level,message,params,fix as above,start:int,end:int}
CompileResult {executable:string,argv:string[],display:CommandToken[],commandLine:string,
  advancedTemplate:string,resolved:ResolvedSettings|null,signalPath:SignalPathFacts|null,
  issues:Issue[],summary:RecipeSummary,overriddenFields:string[],expectedStreams:ExpectedStream[]|null,
  inputStreams:("video"|"audio")[]|null}
ExpectedStream {kind:"video"|"audio",encoder:string|null,codec:string|null}
CommandToken {text:string,role:"exe"|"global"|"input"|"map"|"video"|"audio"|"mux"|"output"|"extra"|"macro",
  field,replacedField,stage:string|null,isOption:bool|null,macros:string[],
  sourceStart,sourceEnd:nonnegativeInt|null}
ResolvedSettings {videoEncoder:string,audioEncoder:string|null,videoMode:string,audioMode:string|null,
  quality:number|null,speed,profile:string|null,depth:int,pixfmt:string,gopFrames:int|null}
SignalPathFacts {video:StreamSignalFacts|null,audio:StreamSignalFacts[],source:SourceSignalFacts|null}
SourceSignalFacts {video:SignalFormatFacts,audio:SignalFormatFacts|null}
SignalFormatFacts {format:string,bits:positiveInt|null,chroma:string|null,label,shortLabel:string}
StreamSignalFacts {inputFormat,outputFormat:string|null,inputBits,outputBits:positiveInt|null,
  inputChroma,outputChroma:string|null,chromaChanged,conversion:bool|null,
  containerSupport:"ok"|"warn"|"no"|"unknown",inputLabel,outputLabel,conversionNote:string|null}
RecipeSummary {container,video,videoQuality,depth,audio,audioQuality,mode:string,
  videoEncoder:string|null,speed:string|null,command:bool,videoEncoderId,audioEncoderId:string|null}
MacroDefinition {name,description:string,required:bool,value:string|null}
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

B4 adds native `inputStreams` facts for allocating/draining host input pipes;
historical fakes may omit them (Dart exposes null). Output verification continues
to use `expectedStreams`, including unknown codecs/scope. The engine passes two
optional native CompilePaths flags: `liveInputs:true` supplies bounded raw-input
startup probing (`-probesize 32 -analyzeduration 0`), and `overwriteOutput:true`
supplies `-y` for its exclusively created temporary output. Defaults remain false
for existing previews/file tests. These are transport context, not recipe settings;
the core still produces every argv token. No rejected input queue flag is restored.

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

### Immutable capability reuse (additive, 2026-10-15)

`NativeVeCore` automatically reuses capabilities across validate/compile/lint/complete;
existing app calls need no change. Reuse is keyed by **Dart object identity** of the
deeply immutable CoreCapabilities, not installationId or identityKey. Lazy options,
availability and hardware facts can change for the same FFmpeg binary: a new view
gets a new snapshot. Retain the service's immutable views across edits. Passing null
means no capabilities; it never silently reuses a previous installation.

The facade retains at most four views (including full Advanced and compact Basic)
and releases the least recently used on replacement. `clearCapabilitiesCache()`
releases them early and is idempotent; it is optional, not a new VeCore lifecycle
requirement. The DLL retains at most **eight** immutable snapshots, each limited to
1 MiB submitted JSON and 65,536 JSON nodes (plus the existing 64-level depth bound).
This bounds retained parse storage by both bytes and node count, including abandoned
facades. Replacement briefly owns one incoming snapshot; synchronous in-flight calls
pin their own snapshot until return. There are no pointers in JSON, no background
threads and no mutex held during compile/lint. The native engine's direct C++ calls
continue borrowing their own capabilities; Render does not use this cache or wait
for the app.

Additive ABI-1 exports, with the existing counted-buffer/free contract:

- `ve_capabilities_store(capabilityObject)` returns `{capabilitiesId:string}`.
- validate/compile/lint/complete accept `capabilitiesId` instead of `capabilities`.
  Supplying both non-null values fails `CAPABILITIES-CONFLICT`.
- `ve_capabilities_release({capabilitiesId})` returns `{}` and is idempotent.

IDs are opaque, local to a loaded DLL and never reused during that DLL's lifetime.
Native LRU eviction/release makes an ID fail `CAPABILITIES-STALE`; there is no fallback
to other facts. Dart reinstalls the exact immutable object and retries once. Cache
node/ID limits use `CAPABILITIES-LIMIT`; the facade uses legacy inline transport for
these maps, preserving valid input semantics. Other failures remain explicit.
`NativeVeCore(cacheCapabilities:false)` is the diagnostic/parity baseline. Inline
requests remain supported. Neither mode performs discovery, probes or filesystem I/O.
Fakes need no snapshot handles because their API is unchanged.

### Advanced tokens and macro catalogue (additive)

User words in Advanced display carry `stage` (global/input/map/video/audio/mux/output,
or null when unestablished), `isOption` (true for an option, false for a consumed value)
and `macros` (recognized source spellings, including embedded/quoted macros). Negative
numbers and quoted values beginning with `-` are values. An unsuffixed option shared
by active encoders keeps stage null. Macro words use role `macro` and retain stage
separately. **Owned `{inputs}` / `{output}` keep roles input/output** for existing chip
guards, plus macro identities. Other input-scoped words keep role extra so they do not
become locked chips. Source spans are unchanged UTF-16 ranges around the original
whole word, including its quotes. Generated tokens may omit these additions; older
results read as null stage/marker and an empty macro list.

With an open double quote, display retains only complete preceding words and expanded
owned chips with trustworthy spans. The incomplete word is omitted. `L-QUOTE.start`
points at the unmatched opening quote (end is text length), including escaped-quote
and surrogate-pair handling. Blocking issues remain; **argv and commandLine are empty**
and expectedStreams/encoder IDs remain unknown. This prefix is highlighting data,
not an executable partial command.

`summary.videoEncoderId` / `audioEncoderId` identify the actual command's explicitly
scoped encoders. They are null for disabled/omitted streams, stream copy, unfinished
quotes, general codec/output/source/filter scope or nonzero stream specifiers. No
inactive Basic encoder or reverse-mapped label supplies an Advanced ID.

`VeCore.macros(media:..., paths:..., recipe:...)` is exposed through an additive
VeCoreMacros extension / optional VeCoreMacroCatalog interface, so older VeCore
implementations still compile (unsupported implementations throw MACROS-UNAVAILABLE).
NativeVeCore and FakeVeCore implement it. `ve_macros` takes `{media,paths,recipe?}` and
returns `{macros:[MacroDefinition...]}`. Name includes braces, description is fallback
copy, required marks inputs/output, and value is expanded text (null if unestablished).
`{gop:2s}` is the catalogue example of the parameterized GOP macro. Values use supplied
preview/render paths; the core invents no temporary filename. Supply the active recipe
to match `{inputs}`' enabled audio and input policy exactly; without it the catalogue
shows available media with audio enabled. The input value is quoted argument text;
ordinary macro values are raw strings. Completion, compile expansion and the catalogue
share native definitions. FakeVeCore takes exact context fixtures through
`macroFixtures` / `FakeVeCore.macrosKey(media,paths,recipe:...)`, without Dart expansion.

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
`replacedField` is the displaced control on each replacing Extra option and its
value, while `field` remains the Extra navigation target. An added option that
replaces nothing has null; Advanced tokens and older results also read as null.
This is the additive token-level link requested in F2; the aggregate
`overriddenFields` remains the simplest way to mark controls.
Token optional
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
Input-scoped Advanced options do not replace output facts. Pixel-format reflection
models only unscoped `-pix_fmt`, `-pix_fmt:v` and `-pix_fmt:v:0`; other selectors
(including absolute `:0`, whose stream may be audio) leave output format/bits
unknown in Basic Extra and Advanced. Arbitrary video filters, including `-filter:v`,
leave conversion unknown even when an explicit final pixel format establishes depth.
An unscoped/absolute-selector `-filter` leaves both stream conversions unknown;
pixel-format options in Basic audio Extra leave final video format/bits unknown,
since those arguments follow and may override the generated video options.
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
needs a version/setting/playback caveat, `ok` means supported by the selected rule set, and
`unknown` means unestablished. None asserts real VEGAS qualification. The app reads
this fact to draw a broken stream-to-container wire; no message parsing or local
compatibility calculation. Default fixture facts remain authored design samples.

`CoreCapabilities.libavformatMajor` comes from the probed library version, never
from parsing vendor version banners in the app. C3 `FFmpegCapabilities` carries
the same optional field; `toCoreCapabilities()` preserves it. Sampled 59/63 select
their measured container table; absent/untested majors use the conservative
consensus, not a guessed nearest version. These tables cover the recorded stream
settings, not every profile/rate or NLE/player. Generated Basic private-option
values and output pixel formats are checked against supplied build capabilities.

[ve_core.h](../../src/core/capi/ve_core.h) defines counted UTF-8 in/out and
paired ownership. Windows x64 default C calling convention, no packing override:
ve_buffer is 16 bytes, data at 0 and uint32 length at 8. Both DLL/static core consumers
use the same sources in B2. No C++ type, Windows header or host pointer crosses it.

| C entry point | Request | Result |
| --- | --- | --- |
| ve_core_version / ve_profiles | no input | CoreVersion / ProfileCatalog |
| ve_capabilities_store | CoreCapabilities | `{capabilitiesId:string}` |
| ve_capabilities_release | `{capabilitiesId:string}` | `{}` |
| ve_macros | `{media,paths,recipe?:Recipe}` | `{macros:MacroDefinition[]}` |
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
with ve_free, including error output. Borrowed input memory is never retained; capability store retains only its parsed owned copy. Semantic
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
and model data are immutable. Windows file/process services are implemented below;
the app explicitly injects them and keeps fakes in UI tests.

| API | Operations | Fake |
| --- | --- | --- |
| FFmpegDiscovery | list/watch/scan/add(executablePath)/remove(id) | FakeFFmpegDiscovery |
| FFmpegProbe | probe(installation) -> Stream<ProbeProgress>; encoderDetails; cancel(id) | FakeFFmpegProbe |
| FFmpegHelpParser | version; parseEncoderHelp/parseEncoders/parseMuxers(text) | FakeFFmpegHelpParser |
| HardwareTests | test(installation,{encoders?,force}) -> Stream<HardwareTestResult>; cancel(id) | FakeHardwareTests |
| PresetTests | test(recipe,installation) -> Stream<PresetTestProgress>; cancel(testId) | FakePresetTests |
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
  counts:{video,audio,muxers:int},availability:{encoder:EncoderAvailability},isFixture:bool,
  health:"unknown"|"unchanged"|"changed"|"missing"|"ffprobe-missing",healthMessage:string}
EncoderAvailability {state:"ok"|"missing"|"failed"|"unknown",reason,detail,note:string}
EncoderDetails {name:string,kind:"video"|"audio",pixelFormats,sampleFormats:string[],
  sampleRates:int[],options:EncoderOption[]}
EncoderOption {name:string,aliases:string[],type,description:string,min,max,defaultValue:string|null,
  constants:OptionConstant[]}
OptionConstant {name:string,value:string|null,description:string}
parseEncoders result: {encoderName:{name:string,kind:"video"|"audio"|"subtitle",flags:string,description:string,codec?:string}}
parseMuxers result: {muxerName:{flags:string,description:string,canonical:string,aliases:string[]}}
FFmpegCapabilities {installationId,identityKey:string,parser:int,version:string,
  encoders:map as CoreCapabilities,muxers:map as CoreCapabilities,
  hardware:{encoder:EncoderAvailability},gpuFingerprint:string,probedAt:UTC}
ProbeProgress {installationId:string,phase:"identity"|"lists"|"details"|"hardware"|"done"|"failed"|"cancelled",
  completed,total:int,message:string,capabilities:FFmpegCapabilities|null}
HardwareTestResult {encoder:string,state:"ok"|"missing"|"failed"|"unknown",tenBit:bool,
  failureClass:"runtime-missing"|"no-device"|"unsupported-format"|"timeout"|"unknown"|null,
  reason,stderr:string,testedAt:UTC,identityKey,gpuFingerprint:string}
PresetTestProgress {testId:string,phase:"preparing"|"encoding"|"verifying"|"done"|"failed"|"cancelled",
  log,message:string,framesDone,framesTotal:int,commandLine,logPath,outputPath:string|null,
  verification:VerificationResult|null,isFixture:bool}
Preset {vepreset:1,revision:positiveInt,favorite,pinned,builtin:bool,updatedAt:UTC,
  origin:string|null,requires:PresetRequirements,recipe:Recipe}
PresetRequirements {encoders:string[],minFFmpegVersion:string|null,known:bool}
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
round-trips unknown keys. Real import/save uses core validation; the fake
stores supplied snapshots without claiming semantic validation. requirements are
derived from native normalization, not by the app. Basic returns the enabled
encoders; Advanced returns null, so the repository records known=false and an
empty encoder list rather than claiming inactive Basic codecs are requirements.
No minimum FFmpeg version is inferred. Missing `requiredEncoders` (older core/fake)
also means unknown. Stars/pins use `PresetPreferences` below; normal user-recipe
Save can still update metadata.

### B3 persistent services and additive app APIs

`FilePresetLibrary(core: VeCore, paths?: ServicePaths)` implements PresetLibrary,
PresetPreferences and PresetLocations. `FileMachineSettingsRepository(paths?)`,
`FileCapabilityCache(paths?, parserVersion:1)`, `FileJobRepository(core, paths?)`,
`FileLiveRenderStatusReader()` and `FileEditSessionService(core: NativeVeCore)`
implement their existing C3 interfaces. The app injects these explicitly; platform
does not change app providers. Production uses NativeVeCore. No repository invokes
FFmpeg or VEGAS. FileReveal launches Explorer only on an explicit reveal call.

ServicePaths defaults to the C3/C6/C7 Windows user roots; injectable roaming/local
roots keep tests isolated. Cache files are `%LOCALAPPDATA%\VegasEncoder\cache\<identityKey>.json`,
with `{cache:1,capabilities:FFmpegCapabilities}`. Parser mismatch is a cache miss;
future envelope versions fail without overwriting their bytes. Identity keys must
be safe IDs; the identity producer emits a SHA-256 hex digest. Production uses
the parser-version-2 cache and GPU-aware view composed by WindowsServices below.

| Additive API | Operations | Fake |
| --- | --- | --- |
| PresetPreferences | setPreferences(id,{favorite?,pinned?}) -> Preset | FakePresetLibrary |
| PresetLocations | location(id) -> absolute path or null for built-in/missing | FakePresetLibrary (illustrative location) |
| PresetTransfer(library) | duplicate(id,{newId,name?}); fromJob(record,{newId,name?}); exportTo(id,selectedPath); importFrom(selectedPath,{required newId}); shareString(id); importShareString(text,{newId}) | FakePresetTransfer (selected-file fixtures and captured exports in memory) |
| JobLogs | readLog(id) -> Stream<String> UTF-8 chunks; logLocation(id) -> path or null | FakeJobRepository(logs:{id:text}) |
| FileReveal | reveal(absolutePath) | FakeFileReveal |

Built-in stars/pins live in `library\preferences.json` as
`{preferences:1,presets:{lowercaseId:{favorite:bool,pinned:bool}}}`. The overlay
preserves unknown metadata and changes neither the built-in recipe nor its origin
revision. Save/delete remain READ-ONLY for built-ins. User preference updates copy
the latest metadata under the writer lock, increment the preset revision and keep
history. Duplicate origin is `builtin/<id>` or `preset/<id>@<revision>`; History
copies use `job/<id>`. Imports retain their supplied origin (built-ins are relabelled
`builtin/<id>`). Transfers always require a caller-chosen new ID.

Share format is `vepreset:1:<base64url UTF-8 exported preset JSON>` (padded). It is
plain portable preset data, not encrypted or signed. Decoded data is bounded and
validated through the same import path. Export writes only the user-selected path,
atomically. Six packaged built-ins adopt the original recipe snapshots at product
revision 1; design-time installation identities/results are never packaged with them.

`PresetTransfer.importFrom(selectedPath, newId: ...)` reads only the caller-selected
UTF-8 JSON file, bounded to 1 MiB even if it grows during the read. It delegates to
the same repository import/native recipe validation and create-only Save path as
share imports; a selected file cannot overwrite an existing preset. Imports preserve
unknown metadata and copy origins, use the caller's new ID and start at revision 1.
The source file is never changed or removed, including on failure. A missing file
is NOT-FOUND, an unreadable file is FILE-READ, oversized input is FILE-LIMIT;
malformed JSON/UTF-8, future versions, invalid recipes/IDs and collisions retain the
repository's existing errors. The app supplies the Open dialog and refreshes/selects
the returned preset. No extension-based trust or automatic scan is introduced.
`FakePresetTransfer(library, files: {selectedPath: jsonText})` supports this operation
without file I/O and can re-import its captured exports. Its file envelope checks
are bounded; semantic behavior remains that of the injected library.

Adjacent temp files are flushed then atomically renamed; the old destination is
never deleted before replacement. Separate persistent lock files serialize Windows
writers across processes/isolates, with nonblocking byte locks and a five-second
deadline. Compare-and-swap happens while locked. A crashed process releases its OS
lock. Transient Windows sharing violations on repository replacement retry for at
most 500 ms; other errors fail immediately. These helpers are app storage code and
must never become waits in Render. B4 uses a separate native worker with bounded
sharing/access-denied retries; publication failures are nonfatal. The live reader
holds only short-lived file handles.

Reads reject invalid UTF-8, duplicate keys, >64 nesting levels, nonfinite numbers,
overflowing signed integers, unsafe Windows IDs and invalid known field types.
Unknown fields and arbitrary JSON inside extensions survive. A newer major fails
and leaves bytes intact. Watches poll at 250 ms, emit a current value per listener,
pause reads when paused and close their in-flight read on cancellation. C5 retains
its last valid snapshot on malformed/stale/missing replacement. Large-library/app
scroll/search timing budgets remain app-side F7 measurements.

### Library list/watch caching (2026-10-15, additive implementation)

C3 signatures and fakes are unchanged. FilePresetLibrary polls the current folder
and preferences.json metadata every 250 ms while watched. Its Windows services DLL
uses one non-recursive directory enumeration for names, size, last-write and creation
times; it closes the search handle before return. This is a short synchronous local
metadata query; changed file contents still use the existing bounded async reads.
No preset is opened/decoded/normalized on an unchanged tick. The service compares
its last metadata JSON before parsing/sorting it again, reuses the immutable preset
list and skips the watcher's full-library JSON comparison for that same instance.
Enumeration order is not assumed: changed results are sorted as before.

Changed or added files pass through the original native recipe checks and requirements
calculation. Removed entries are pruned; the cache retains one successful current
entry per file, one preferences object and one list/metadata snapshot, with no
history accumulation. Built-in requirements are stable for the core instance;
preferences overlays are refreshed independently. Save/delete/preferences invalidate
the affected cache immediately. Concurrent lists share one in-flight scan; writes
winning during async reads force a retry (at most three, then STORE-BUSY). get and
revision/Save validation remain authoritative disk reads rather than cache lookups.

Every new listener receives a current snapshot, then only changed values. Malformed
files still fail list() and emit stream errors without replacing the last successful
snapshot; repairs are revalidated. A directory named preferences.json remains a
FILE-READ error rather than being cached as missing/default preferences.
Pause/cancel retains the existing timer/in-flight
lifetime rules. No persistent watcher, process, worker thread or new dispose API is
introduced. FakePresetLibrary continues its existing in-memory snapshot contract.

The native metadata fast path is bounded to 1 MiB output, 8,192 retained entries,
100,000 enumerated entries and 32,700 input UTF-16 units. Exceeding that bound (or a
preset/preferences reparse point) uses the previous Dart directory/stat scan in a short-lived
isolate. Other scan failures remain FILE-READ; no partial directory is accepted.
Reparse entries use Dart's existing followLinks:false policy through that fallback. Metadata
caching detects ordinary edits/atomic replacements; an external rewrite preserving
size and all recorded timestamps can evade it. Explicit get/Save still reread bytes.
Measured 500-preset costs and cold-load limits are in the platform handoff. This
changes app storage only; no scan, wait or filesystem dependency enters Render.

Preset history keeps the last 20 old revisions (post-commit pruning is best effort
and retries on the next save). Delete retains the final snapshot for recovery.
An ID with retained history cannot be recreated at revision 1; use a new ID.
Storage adds `INVALID-DATA`, `INVALID-ID`, `UNSUPPORTED-VERSION`, `FILE-LIMIT`,
`FILE-READ`, `FILE-WRITE`, `STORE-BUSY` and `RECIPE-INVALID` service errors.

### B3 Windows FFmpeg services and app composition

Construct one `WindowsServices(core: NativeVeCore(), paths?: ServicePaths)` for the
app's providers. It supplies machineSettings, discovery, probe, hardwareTests,
capabilityCache, presetTests, library, jobs, liveStatus, editSessions, presetTransfer
and fileReveal. Construction does not scan, execute FFmpeg or write default files.
The Windows x64 native-asset hook builds a bounded DXGI GPU/driver helper alongside
ve_core; there is no Flutter dependency. Exact pinned dependencies and notices
are in packages/ve_services/THIRD_PARTY_NOTICES.md.

**C7 ownership:** discovery add/scan/remove and completed probe/hardware tests own
installation-record writes. The app must remove its fake-era discovery-to-machine
copy and manual capability-cache writes when switching providers. Default selection,
theme, UI bounds and other preferences still use revision-checked settings writes;
on REVISION-CONFLICT re-read and reapply only the intended preference. Services
do this internally (eight attempts) and preserve unrelated fields. Removing the
current default fails DEFAULT-IN-USE. Vanished installations stay listed with health.

Discovery explicitly scans legacy INI, PATH, WinGet links/package folders, Scoop
paths/shims and Chocolatey package executables. Package walking is bounded to
4,000 entries and six levels. Scoop .shim text resolves to the target exe; shims
are never executed. Paths/symlinks are canonicalized and deduplicated; Windows
environment names are case-insensitive. The default INI is beside the app;
WindowsFFmpegCandidateFinder accepts explicit iniPaths/environment for other roots.
Candidate failures are exposed through discovery.scanProblems. Nothing downloads
FFmpeg, edits PATH or chooses a default automatically.

Identification requires Windows x64 PE executables, FFprobe beside FFmpeg, and
matching full version/configuration/loaded-library facts. SHA-256 covers FFmpeg and
sorted sibling av*/sw*/postproc* DLLs plus parser version; extensions retain their
file stats and FFprobe hash/stats. Reads/list/watch use stats for health without
executing FFmpeg or hashing entire binaries. Explicit probe/test operations rehash
and refuse changed/incomplete installations. Installation IDs are stable per
canonical path; capability identities change with bytes, libraries or parser.

Probe streams identity, lists, curated details, hardware and a terminal phase.
Generic codec AVOptions come from the AVCodecContext section of -h full; version,
encoder/muxer lists and curated encoder help are parsed off the caller isolate.
Other encoder help is fetched lazily and merged under the cache lock. The parser
preserves literal bounds/defaults/constants, merges duplicate options/aliases, and
detects unknown encoder help even with exit 0. Muxer aliases are individual lookup
keys but counts deduplicate canonical implementations; joined device flag Ed is
accepted. Production parser version is **2**, invalidating earlier qualification
commands/cache entries. Existing parser-1 fakes remain historical fixtures.

One shared pool allows at most four direct, shell-free hidden Windows children.
Help/identity/hardware timeout is 10 s per child; stdout is bounded (1 MiB normally,
4 MiB for full help), combined output 8 MiB and returned stderr tail 64 KiB.
Timeout/cancellation kills and reaps owned children and removes queued work.
Probe/hardware cancel uses installation ID; preset-test cancel uses testId.
Await cancel/subscription cancellation before disposal. Failure/cancellation never
emits probe done; a completed catalog or previous qualified result can remain cached.

Hardware tests qualify listed **video** wrappers with one 320x192 frame, forced
pixel format, and a second 10-bit input test when advertised. Media Foundation
uses -hw_encoding 1 to prevent software fallback. Vulkan/D3D12-only surfaces use
explicit device initialization and hwupload. A failed 10-bit test does not discard
an 8-bit success; tenBit requires its own success. Results retain bounded stderr,
failure class, binary identity, DXGI adapter/driver fingerprint and testedAt, and
persist in cache/C7. Reuse requires exact identity/fingerprint and age <30 days;
force bypasses reuse. Unknown driver identity is not reusable. GPU changes/expiry
make availability unknown on reads without launching a test. These are smoke
results for the tested default device/command, not HDR, resolution/performance or
all possible custom device/filter configurations. Audio wrappers are listed facts,
not GPU qualification results.

PresetTests generates 60 320x180 P010 testsrc2 frames at 30 fps and two seconds of
48 kHz stereo float sine in a unique local tests directory. Only core.compile
produces argv and expectedStreams: canonical codec comes from captured capabilities
or curated native family facts; unestablished codecs stay null. Basic and seeded
Advanced commands are supported. General extra input/output/map/filter scope is
explicitly refused by this small synthetic test. There is no Dart command parsing.
Encoding (60 s), FFprobe count/readback (15 s) and full decode (30 s) are bounded,
with streamed stderr and an 8 MiB persisted log. A passed result needs matching
stream kinds/count/known codecs, readable video and full decode. Cancellation/log
failure releases resources; terminal results follow log close/input cleanup.
Output/log are retained for inspection; generated inputs are removed. Tests do
not publish render outputs or create History jobs (B4).

`capabilities.toCoreCapabilities(label: ..., recipe: recipe)` reuses immutable
views across edits. Basic retains all encoder names/kinds/codecs/availability and
active encoders' full option facts; Advanced or omitted recipe retains the full
map. Availability state/reason are retained; unused hardware diagnostics stay in
the full service data. Native compile results match across these views for the six
built-ins, Extra arguments and disabled audio on all three supplied builds (61
parity/reuse checks). Warm Basic FFI compile means are 2.5–2.9 ms with 27–33 KiB
maps, versus 10.5–13.2 ms full-map means (50 calls/build). App frames and the complete 4 ms edit budget still
need F7 measurements; the full Advanced map remains materially slower.

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

B6's offline `RecipeTemplateDraft` now supplies the native transaction side:
actual template name/recipe/origin in requests, one matching terminal result,
core validation before accepting a draft, and stored-byte changes only after
successful host Apply. The existing `VEnc` envelope can be placed/resized in
owned native template bytes while preserving the host prefix and raw text suffix.
Core payload encoding remains canonical; key order alone does not dirty a draft.
The offline native transport now writes bounded requests in fresh UUID directories,
launches an explicitly selected owned helper and polls its exit before consuming
one core-validated result. Nonzero exit, missing/invalid/foreign results or explicit
Cancel preserve the draft; no Render wait or app lookup is introduced. Direct
known-file cleanup preserves unknown entries and reports incomplete cleanup.
These helpers are not linked into exporter discovery/pages/Render. Actual Flutter
launch, startup scheduling/modality, native persistence and monitor integration remain gated;
details/tests are in [NATIVE_RECIPE_BOUNDARY.md](../NATIVE_RECIPE_BOUNDARY.md).
No C4/C5 shape or C2 API changed for this checkpoint.

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
  encoderSummary:string,outputBitDepth:positiveInt|null,
  pixelFormatConversionReducesPrecision:bool|null,message:string,ffmpegExitCode:int|null
}
```

Sequence strictly increases; reader ignores duplicate/out-of-order snapshots.
Typical writer transitions: starting → encoding → finishing → verifying → done;
failed/cancelled may terminate any active phase. Readers can miss phases. `done`
means exit zero, verification passed (or explicitly disabled), and final publication.
Finishing/verification are not success. Failed verification may retain a temp file,
reported in the job record. bytesWritten is work so far; failure/cancellation does
not mean it was published. Unknown metrics remain null; ETA is advisory.

`outputBitDepth` is the core's useful video precision at the encoder input, after
pixel-format conversion and before codec compression. It describes the compiled
signal path, not measured encoded-file precision or a codec quality guarantee.
`pixelFormatConversionReducesPrecision` is true only when established input bits
exceed output bits and the core establishes conversion; false covers unchanged or
increased depth and layout-only conversion. It excludes compression and chroma
changes. Unknown input precision or arbitrary filters leave that flag null, even
if outputBitDepth is known. Consumers must not turn null into false or derive facts
from encoder labels, pixel-format names, the recipe or diagnostic text.

The native writer initializes both fields to null and fills them only after a valid
compile establishes exactly one video output and an unambiguous video encoder ID.
Video-disabled/audio-only commands, stream copy, general Advanced input/output/map
or codec scope, and unknown output formats keep both null. A simple Advanced command
with an explicit scoped encoder and known pixel format can supply facts; inactive
Basic settings never fill them. Facts then persist across phases and terminal states.
An error before valid compilation retains nulls. Existing files with absent fields
remain readable as unknown without inserting defaults; copyWith(null) explicitly
clears them. Disk and fake readers reject nonpositive/noninteger depth or a nonbool
nonnull precision flag; malformed replacements preserve the last valid snapshot.
The fake transports supplied facts without calculating them. Samples show unknown
at startup and illustrative P010-to-8-bit reduction in subsequent phases.

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
  timings:{phase:seconds},published:bool,retainedPartialPath:string|null,
  commandLine,encoderSummary,logFile:string|null,durationSec,realtime:number|null,
  errorTokenIndices:nonnegativeInt[]
}
JobIndexEntry {index:1,id:string,recordFile:relativeBasename,startedAt:UTC,
  status:"succeeded"|"failed"|"cancelled",templateName:string,outputPath:string,
  encoderSummary,project:string|null,durationSec,elapsedSec:number|null,sizeBytes:int|null}
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

B3 reads and validates records; B4's native RecipeJob now writes them. Optional summary
fields keep old records readable; absent values stay unknown. B4 writes the core's
commandLine, encoder summary, duration/realtime facts and errorTokenIndices;
indexes refer to recorded argv (zero-based, executable excluded), not display
tokens. The app never parses stderr to produce them. `logFile` is the relative
basename `<id>.ffmpeg.log` under the jobs root. JobLogs streams the full UTF-8 log
without the 1 MiB JSON allocation limit; a missing historical log is NOT-FOUND.

FileJobRepository reads the bounded lines of jobs.jsonl without reading every
record. It ignores an incomplete final line and rejects malformed complete lines
or unsafe recordFile references. Missing index can be reconstructed read-only from
complete per-job files. `rebuildIndex()` explicitly replaces an interrupted/corrupt
index under the index lock. Watches never repair files as a side effect. Stopped
jobs cannot claim publication or published bytes; success requires zero exit,
publication and a passed/explicitly skipped output check.

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
  lastSizeLengthText:string|null,popupWindowSize:PopupWindowSize|null}
DesktopWindowBounds {x,y:int,width,height:positiveInt}
PopupWindowSize {width,height:int in 1..32768}
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

`popupWindowSize` is the restored **outer window size in physical pixels**; it
contains no position or maximized state. Null/absent means default popup size. Both
real settings storage and its fake reject dimensions outside 1..32768 or non-integers,
preserving the previous settings. The app owns restoring/clamping it to current DPI,
monitor work area and its minimum size, centring on its current owner, and saving it
through revision-checked UI writes. Desktop fields and unknown nested keys survive;
older files require no migration. No frontend adoption or real VEGAS persistence
qualification follows from the service field.

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
