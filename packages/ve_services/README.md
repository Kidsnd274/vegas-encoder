# ve_services — B0

Pure Dart system interfaces/models and an in-memory fake for every service. Import
`package:ve_services/ve_services.dart` (also exports ve_core types). Only dependency:
the sibling ve_core path package, which now carries B2's native hook and pinned
MIT/BSD dependencies. No Flutter dependency or additional service dependency.

See [C3–C7 contracts](../../docs/product/CONTRACTS.md) for exact file/service shapes.
Real Windows discovery, process execution and repositories arrive in B3.

Contract v1 additions: `LiveRenderStatus.hostHwnd` carries the host main window for
monitor placement; `MachineSettings.uiState` carries desktop bounds/maximize and
the last size-card length text via the existing revision-checked settings API.
The default machine/live fixtures expose these; keepOnTop still defaults false.

`FakeFFmpegDiscovery`, `FakeFFmpegProbe`, `FakeHardwareTests`, `FakePresetLibrary`,
`FakeMachineSettingsRepository`, `FakeJobRepository` and `FakeEditSessionService`
have default mockup fixtures. `FakeFFmpegHelpParser` maps injected exact text to
parsed outputs; `FakeCapabilityCache` is initially empty. Discovery.add requires an
injected executable fixture. None runs a process or reads/writes files.

`FakeLiveRenderStatusReader.samples()` provides all seven render states. Inject
initial values or call `publish(file, status)` to drive the monitor. The terminal
samples are alternative endings. Watchable services replay the latest snapshot
per listener. Cancel subscriptions and call `dispose()` in test teardown.

All installation hashes, paths, GPU results and history are illustrative, marked
`isFixture: true`; they do not describe the developer machine or real VEGAS.

Run `dart pub get --offline`, `dart analyze`, and
`dart run test/contracts_test.dart`, or the repository's `scripts/Test-B0.ps1`.
