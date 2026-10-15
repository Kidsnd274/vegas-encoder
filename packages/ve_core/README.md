# ve_core — B2

Windows x64 Dart facade over the portable C++17 product core, plus immutable models
and the fixture-only `FakeVeCore`. No Flutter dependency. The C++ core is the sole
implementation of normalize, validate, compile, lint, complete, estimate, diff and
payload rules. It performs no filesystem/process/VEGAS I/O.

```dart
import 'package:ve_core/ve_core.dart';

final core = NativeVeCore(); // hook/build.dart builds and bundles the native asset
final command = core.compile(recipe, media: media, paths: paths);
```

Create a facade per isolate. Buffers are copied and freed within each call, including
transport-error buffers. No dispose is needed; no host pointers or frame buffers
cross the API. `NativeVeCore.open(dllPath)` is for explicit DLL parity checks. Semantic
errors are result issues; transport errors are `CoreException`. Never fall back to
fakes when the native core fails. A fake is selected explicitly for tests.

Build tools: the owner's Dart 3.13.5 / Flutter 3.47.7, installed MSVC x64 C++17 tools
and Windows SDK. The hook uses the source under `../../src/core/`, also built by
`scripts/build-core.cmd` as DLL and static library. No research checkout, FFmpeg
download, SDK upgrade or exporter installation is needed to build the core.
Standalone AOT consumers use [`dart build cli`](https://dart.dev/tools/dart-build) so native assets are bundled;
`dart compile exe` does not run build hooks. Flutter's native-asset build is the app
workstream's integration path.

See [C1/C2 contracts](../../docs/product/CONTRACTS.md). Results include token field
provenance and issue display indexes, `overriddenFields`, structured stream/source
facts and fallback labels, resolved keyframe frames, and size ranges for a typed
length. Advanced facts come from the active command; unsupported/unknown facts are
null/unknown. Arbitrary filters, rate-control changes outside the recipe mode, or
unknown final formats can make the estimate unavailable. Estimates are guides.

The embedded profiles/options are explicitly **B2 bootstrap design data from B0 /
Linux FFmpeg 8.1.3**, pending B1 Windows recapture. Supplied capabilities determine
installation availability and private options; no FFmpeg/GPU probe runs here. The
core and offline encodes do not establish any new real VEGAS qualification.

`FakeVeCore` retains six built-ins and a popup snapshot. It matches missing and empty
`extensions` alike without changing stored JSON; real changes still require injected
fixtures or fail `B0-FIXTURE-MISSING`. No edited-state sweep or domain rules in Dart.
Its capability-specific display highlights use `CoreFixture.compileIssues`.

Run `scripts/Test-B2.ps1 -Asan -Aot -Encoder` from the repository root for focused
native/static, real FFI, sanitizer, AOT-bundle and synthetic-encoder checks. Encoder
checks use the existing `C:\ffmpeg\bin\ffmpeg.exe` by default, with FFprobe beside it,
and write only ignored build/test-results/. `scripts/Test-B0.ps1` retains model/fake
and fixture checks. Read [third-party notices](THIRD_PARTY_NOTICES.md) for the pinned
MIT/BSD source and build dependencies; no project license is selected.

Capability transfer is cached automatically by immutable CoreCapabilities object
identity (four facade views / eight DLL snapshots). Keep the service's views across
edits; no new app call sites or dispose requirement. clearCapabilitiesCache() permits
early release; cacheCapabilities:false supplies the inline diagnostic baseline.
See CONTRACTS C2 for bounds, stale-ID retry and optional inline fallback.

Advanced tokens now expose stage, isOption, macros and typed UTF-16 source spans;
owned macro roles stay input/output. An unfinished quote retains prefix display but
has empty argv/commandLine. summary supplies conservative videoEncoderId/audioEncoderId.
VeCore.macros(media:..., paths:..., recipe:...) supplies native catalogue/values;
FakeVeCore takes exact-context macroFixtures rather than expanding in Dart.
