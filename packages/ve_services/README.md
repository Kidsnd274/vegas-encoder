# ve_services — Windows services and fakes

Dart system interfaces/models, real Windows services and service fakes. Import
`package:ve_services/ve_services.dart` (also exports ve_core types). There is no
Flutter dependency. A Windows x64 native-asset hook builds a bounded DXGI identity
helper beside ve_core. Exact pinned dependencies/license texts are covered by
[third-party notices](THIRD_PARTY_NOTICES.md).

See [C3–C7 contracts](../../docs/product/CONTRACTS.md) for exact file/service shapes.
Persistent presets/settings/cache/jobs/live status/edit sessions are implemented.
Windows FFmpeg discovery, probing, hardware tests and preset-test execution are
also implemented. No default app provider is changed by this package.

```dart
final services = WindowsServices(core: NativeVeCore());
// Inject discovery, probe, hardwareTests, capabilityCache, presetTests, library,
// machineSettings, jobs, liveStatus, editSessions, presetTransfer and fileReveal.
```

One composition root shares a four-process pool and parser-version-2 GPU-aware
cache. Construction does not scan/probe or create default files. Inject optional
ServicePaths, executor, GPU identity and candidate finder to isolate support/tests.
Discovery and probe/hardware services own persistent installation records in C7;
remove fake-era app copies of installation lists and manual capability writes.
App preference/default writes still re-read/reapply on revision conflicts.

List/watch compute health from stats without executing FFmpeg. Only explicit
scan/add/probe/test executes supplied binaries; no download, installation, PATH
change or default selection is implicit. Matching x64 FFprobe must be beside FFmpeg.
Process invocations are hidden, shell-free and bounded; cancellation kills/reaps
children and removes queued work. Cancel probes/hardware by installation ID and
preset tests by testId; await subscription cancellation on disposal.

Hardware reuse requires exact binary/parser/GPU/driver identity and age <30 days.
Listed hardware is unknown until tested; 8-bit and 10-bit input results stay separate.
Smoke results qualify the tested command/device only, not HDR or other sizes/drivers.
Preset tests run native-compiled commands on 60 synthetic frames plus stereo sine,
then FFprobe/full decode. Output/log stay under local tests for inspection, generated
inputs are removed, and no History/render output is published. Use
`capabilities.toCoreCapabilities(recipe: recipe)` to reuse a smaller Basic view;
Advanced retains all facts. App frame budgets still need F7 measurement.

Use `FilePresetLibrary(core: NativeVeCore())`, `FileMachineSettingsRepository()`,
`FileCapabilityCache()`, `FileJobRepository(core: NativeVeCore())`,
`FileLiveRenderStatusReader()` and `FileEditSessionService(core: NativeVeCore())`.
An optional `ServicePaths(roaming: ..., local: ...)` isolates test/support roots.
File reads/list/watch never probe, execute FFmpeg, create default files or repair
records implicitly. WindowsFileReveal is an explicit Explorer action.

`PresetPreferences.setPreferences` stores built-in stars/pins separately without
editing their recipes/revisions. `PresetLocations.location` returns user-preset
paths. `PresetTransfer` provides duplicate/History origins, selected-path export,
bounded selected-file import (`importFrom(path, newId: ...)`) and versioned share
strings. File import uses the repository's validation/create-only save and preserves
the source. `FakePresetTransfer(files: ...)` supplies selected-file fixtures and
captures exports without I/O.
`JobLogs` streams recorded full logs; `FakeJobRepository(logs: ...)` supplies them
in tests. `FakeFileReveal` captures reveal requests. Unknown data round-trips.

Writers use revision checks under Windows byte locks and adjacent atomic replace.
Reads are bounded and validated; future versions preserve source bytes. Watches
poll, replay per listener, pause reads and finish their read on cancellation.
Cancel every watch subscription on disposal. The six built-ins contain adopted
recipe policy only, with runtime facts derived by the native core.

Run `scripts/Test-B3Repositories.ps1` from the repository root for the real Windows
file/concurrency suite. It builds a native-asset AOT bundle so parent and competing
processes do not race Dart build hooks over a loaded DLL. Tests use isolated,
temporary directories under ignored build/test-results and remove only their
own directory. They do not touch user settings, FFmpeg, installed exporters or
VEGAS. `python -I scripts/Generate-ServiceBuiltins.py --check` verifies packaging.

Contract v1 additions: `LiveRenderStatus.hostHwnd` carries the host main window for
monitor placement; `MachineSettings.uiState` carries desktop bounds/maximize and
the last size-card length text via the existing revision-checked settings API.
The default machine/live fixtures expose these; keepOnTop still defaults false.

`FakeFFmpegDiscovery`, `FakeFFmpegProbe`, `FakeHardwareTests`, `FakePresetLibrary`,
`FakeMachineSettingsRepository`, `FakeJobRepository` and `FakeEditSessionService`
have default mockup fixtures. `FakeFFmpegHelpParser` maps injected exact text to
parsed outputs; `FakeCapabilityCache` is initially empty. Discovery.add requires an
injected executable fixture. None runs a process or reads/writes files.
`FakePresetTests` supplies an illustrative test stream without encoding.

`FakeLiveRenderStatusReader.samples()` provides all seven render states. Inject
initial values or call `publish(file, status)` to drive the monitor. The terminal
samples are alternative endings. Watchable services replay the latest snapshot
per listener. Cancel subscriptions and call `dispose()` in test teardown.

All installation hashes, paths, GPU results and history are illustrative, marked
`isFixture: true`; they do not describe the developer machine or real VEGAS.

Run `dart pub get --offline`, `dart analyze`, and
`dart run test/contracts_test.dart`, or the repository's `scripts/Test-B0.ps1`.
`scripts/Test-B3Services.ps1` checks captured parser text, fake FFmpeg boundaries,
real Windows process cancellation/timeouts and the DXGI helper.
`scripts/Test-B3Runtime.ps1 -FFmpegPaths @(...)` checks explicitly supplied FFmpeg
builds on native-compiled preset encodes/readbacks/full decodes. Run these runners
sequentially so build hooks do not replace a loaded DLL. Outputs stay in ignored
build/test-results; no fake host or VEGAS is involved. Parser fixtures are committed;
capture folders are needed only when deliberately regenerating them.
