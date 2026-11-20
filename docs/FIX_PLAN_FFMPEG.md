# FFmpeg page fix plan

Written 2026-11-19 from a review of the FFmpeg section on `master` at `510b417`
(0.2.1+1). The review reproduced each bug marked **confirmed** with tests or real
FFmpeg; the others come from reading the code. **Nothing in this plan has been
implemented.** Line numbers are approximate; find the code by name.

The owner wants every item fixed. One agent carries it out, in the order of
section 4. The owner's decisions are final (section 1): follow them exactly.

## 0. Before you start

- Read `AGENTS.md`, `docs/STATUS.md`, `docs/product/UI_SPEC.md` §5 and §5a, and the
  C3 FFmpeg sections of `docs/product/CONTRACTS.md` (the API table and models around
  lines 570–610, discovery and identification around lines 820–860).
- **Where to work (owner decision, 2026-11-19).** A new worktree,
  `../vegas-encoder-ffmpeg-fixes`, on a new branch `fix/ffmpeg-page` from `master`.
  The main checkout holds another agent's uncommitted changes (engine, core, several
  docs): don't edit, stage or commit anything there.
  - A new worktree needs `dart pub get` in `packages/ve_core` and
    `packages/ve_services`.
  - It builds and tests inside itself, with output in its own `build/`.
  - Never install anything from it.
  - Don't remove it when done; the owner decides.
- **Commits.** Commit only when the owner allows it, one item per commit, as in
  0.2.1. No co-author trailers or tool attribution in commit messages.
- **Test first.** For each confirmed bug, write the regression test, see it fail on
  the current code for the stated reason, then fix.
- **Not in scope.** Don't bump `services.ffmpegParserVersion` (the cache format
  doesn't change). Don't change the exporter or native code. Don't install anything.
- **No machine paths** in committed files. Refer to FFmpeg builds through
  `VEGAS_ENCODER_FFMPEG` or repo-relative paths.

## 1. Owner decisions (final, 2026-11-19)

| # | Decision |
| --- | --- |
| D1 | **Read the FFmpeg files once per add.** Add fingerprints (SHA-256) the files once. The check that immediately follows reuses that fingerprint, and its end-of-check confirmation compares file size and modified time, re-reading only if they changed. Checks the user starts later (Scan again, Test hardware encoders, Test again, Locate…) still re-read fully, as now. Renders are unaffected: the exporter verifies the hash itself before every render. |
| D2 | **Hardware tests: catalog first, the rest later.** The check test-encodes only the catalog's hardware encoders that FFmpeg lists. The other listed hardware encoders are tested afterwards in the background, one at a time. APIs that can't work on Windows (`vaapi`, `videotoolbox`, `v4l2m2m`, `mediacodec`, `rkmpp`, `omx`) are never tested. |
| D3 | **"Runs on" shows the GPU name.** For a passing hardware test, the services write the adapter's name (for example "AMD Radeon(TM) 8060S Graphics") into `EncoderAvailability.note`, taken from the existing GPU snapshot and matched by vendor. The UI and fixtures already expect this. |
| D4 | **Slim the installation record in `machine.json`.** Per encoder, persist only state, reason and a short note (plus `testedAt` and `tenBit`). FFmpeg's stderr and other test details stay in the capability cache. |

Derived rules (not separate decisions):
- The card that appears straight after picking a file is **app state only**. Nothing
  is written to `machine.json` until the fingerprint is done, so the exporter never
  sees an unverified installation.
- D1 applies to Scan again too: each installation a scan identifies is read once
  for that scan, and the check the scan starts reuses it.

## 2. Review findings and baseline

Measured on the review PC (AMD Radeon 8060S; NVENC and QSV unavailable), in an
AOT build of the services, with real FFmpeg:

| Build | Card can first appear (identify + record) | Re-identify at check start | Hardware phase | Whole check |
| --- | --- | --- | --- | --- |
| N-128435 static (194 MB exe, 194 MB ffprobe; `VEGAS_ENCODER_FFMPEG`) | 2.7 s | 2.7 s | 8.8 s | 11.9 s |
| gyan 9.0.2 essentials (105 MB) | 1.5 s | 1.5 s | 6.7 s | 8.6 s |
| BtbN n8.1.3 shared DLLs | 1.0 s | 1.0 s | 8.6 s | 10.1 s |

- One add of the static build hashes `ffmpeg.exe` 3 times and `ffprobe.exe` 5 times,
  about 1.55 GB.
- The card appears only after identify and record, plus up to 1 s for the discovery
  poll (`watch()` polls every second). The "Added" toast comes only after the whole
  check.
- Every encoder row, CPU encoders included, says "Not checked yet" until the whole
  check, including hardware tests, has finished.
- UI-isolate stalls stayed at or below 28 ms, except about 225 ms at the first launch
  of each large exe (`Process.start` is synchronous; the virus scanner checks a new
  binary). The lag users feel is mostly waiting, plus the card remounts of F1.
- The check tested 25 hardware encoders on gyan 9.0.2 (7 of them `*_vaapi`) and 24
  on N-128435. The catalog has 5: `av1_nvenc`, `h264_amf`, `h264_nvenc`, `hevc_nvenc`,
  `hevc_qsv`.
- `machine.json`: about 75 KB (gyan) and 70 KB (N-128435) per installation. About
  45–60% of that is the hardware entries, which carry FFmpeg's stderr twice.

Ruled out:
- **Lost writes to `machine.json`.** A 15 s stress run had three writers: discovery's
  repository, the app's repository, and another isolate standing in for the popup.
  It reached revision 925 with no installation lost. Only Remove deletes a record.
- **The reported "FFmpeg disappeared".** Not reproduced with the real page on real
  services (see section 7).

How the numbers were taken, to repeat them before and after:
- **Services harness.** A scratch Dart program in an ignored folder
  (`packages/ve_services/.dart_tool/review/harness.dart`), built with
  `dart build cli --target .dart_tool/review/harness.dart --output ../../build/review-scratch/harness`
  from `packages/ve_services`.
  - It builds `WindowsServices(core: NativeVeCore(), paths: ServicePaths(...))` with
    an **absolute** data root under this checkout's `build/review-scratch/`. A
    relative root can escape the repo.
  - It times `discovery.identify`, `discovery.add` and each `ProbeProgress` phase.
  - A 4 ms `Timer.periodic` records the longest event-loop stall.
  - Delete the scratch files afterwards.
- **Real page on real services.** In a scratch widget test, call
  `pumpApp(tester, core: NativeVeCore(), services: WindowsAppServices(() => core, paths: <isolated>))`,
  then alternate `tester.runAsync(() => Future.delayed(d))` with `tester.pump(d)`.
  - `LiveTestWidgetsFlutterBinding` can't be used: `test/flutter_test_config.dart`
    already initializes the test binding.
  - Don't commit these tests: they are slow and need real FFmpeg.

## 3. Phase 0: baseline

- [ ] On the starting commit, run the suites in section 5 and record the results.
- [ ] Run the services harness on the static, essentials and shared builds (or the
  FFmpeg builds available) and record the baseline table in your notes.

## 4. Items, in order

### F1. Every card is rebuilt from scratch on each page rebuild, so clicks are lost (confirmed)

- **Problem.** `_CardStrip` keys each slot `SizedBox(key: ObjectKey(children[i].key))`
  (`app/lib/features/ffmpeg/ffmpeg_page.dart`, around line 309).
  - `ObjectKey` compares by identity, and `ValueKey(i.id)` is a new object each
    build. So every FFmpeg page rebuild unmounts and remounts every card with all
    its state: hover, press, focus and tooltips.
  - Rebuilds come from each probe progress event (about 50 per add), from discovery
    ticks with changes, and from settings changes.
  - A click whose press and release straddle a rebuild is lost. That is the original
    C1 symptom, reintroduced by the 0.2.1 C1 fix.
- **Evidence.** Both tests below failed on `master`. With the fix, they and all 22
  existing tests in `ffmpeg_page_test.dart` pass.
- **Tests first** (`app/test/widget/ffmpeg_page_test.dart`):
  - [ ] "a page rebuild keeps each card mounted". Take the `State` of the
    `VeInteractive` inside the "FFmpeg 7.1.1" card, call
    `ffmpegControllerProvider.notifier.setFilter(CapabilityFilter.problems)`, pump,
    and expect the same `State` object (`identical`).
  - [ ] "a click whose press and release straddle a rebuild selects the card".
    `tester.startGesture` on the card's title, pump 60 ms, `setQuery('x')`, pump
    60 ms, `up()`, then expect `selectedId == 'manual-7.1'`.
- **Fix.** Key the slot with the card's own key (`SizedBox(key: children[i].key, …)`),
  or pass `(id, card)` pairs and use `ValueKey(id)`. Update the comment.

### F2. One check per installation at a time (confirmed in part)

- **Problem 1 (confirmed with real services and real FFmpeg).** `capabilitiesProvider`
  starts its own probe when the cache has no entry (`app/lib/state/services.dart`,
  around lines 298–313).
  - Repro: add an FFmpeg. While it is being checked, click **Set as default** on its
    card, then open Presets. A second full check of the same installation starts and
    runs concurrently: hashing, help, and every hardware test encode on the same GPU.
  - When the provider is invalidated, its `await for` keeps running, so that check is
    never cancelled.
- **Problem 2 (from reading).**
  - `FFmpegController.probe` has no in-flight guard. **Scan again** during an add's
    check probes the new installation again.
  - `state.probes[id]` is shared, so whichever check ends first clears the other's
    progress.
  - `_probing` is a `Set`, so only one of the two is cancelled on dispose.
  - "Test hardware encoders" and the detail panel's **Test** stay enabled during a
    check, so hardware tests run on the GPU alongside the check's own.
  - **Remove…** doesn't stop a running check or test.
- **Fix.**
  - `FFmpegController`: replace `_probing` with `Map<String, Future<void>> _checks`.
    `probe(installation)` returns the running future for that id instead of starting
    another. Dispose cancels every key.
  - `capabilitiesProvider` never opens a probe stream itself. On the desktop with no
    cache entry it awaits
    `ref.read(ffmpegControllerProvider.notifier).probe(installation)`, then returns
    `cache.read(key)`. The popup still only reads. There is no provider cycle:
    `FFmpegController.build` watches only the probe and hardware-test services.
  - `testHardware` for an installation that is being checked refuses with
    `ServiceException('CHECK-RUNNING', 'Wait until the check of <label> finishes.')`.
    The page disables the header's "Test hardware encoders" and the detail's
    **Test** for that installation while `state.probes[id]` is set.
  - `remove(id)`: first `ffmpegProbeProvider.cancel(id)` and
    `hardwareTestsProvider.cancel(id)`, then `discovery.remove`, then drop the id from
    `probes`, `probeFailures`, `probed`, `testing` and `testResults`.
- **Tests first:**
  - [ ] Unit (`app/test/unit/ffmpeg_test.dart`). A container whose
    `FakeMachineSettingsRepository` records installation X with no cache entry, and a
    counting `StalledProbe` (`app/test/ffmpeg_doubles.dart`). Start
    `controller.probe(X)` without awaiting, then read
    `capabilitiesProvider(X.id).future` without awaiting. Exactly one probe starts;
    finishing it resolves the provider. (The widget-level repro passed with fakes
    only because fake discovery doesn't record into machine settings.)
  - [ ] Unit: two `controller.probe(X)` calls start one probe.
  - [ ] Widget: during a stalled add's check, "Test hardware encoders" is disabled
    for that card, and Scan again starts no second probe for it.
  - [ ] Widget: **Remove…** on a card mid-check cancels it (`StalledProbe.cancelled`
    contains the id).

### F3. Read the files once per add (D1)

- **Problem.**
  - `identify()` hashes ffmpeg and its DLLs, and hashes ffprobe twice, before and
    after `-show_versions` (`ffmpeg_discovery.dart`, around lines 239–317).
  - The check then calls `discovery.refresh` → `identify` again (`ffmpeg_probe.dart`,
    around line 97).
  - At the end it calls `requireCurrentInstallation`, which hashes ffmpeg, the DLLs
    and ffprobe again (`ffmpeg_identity.dart`, around lines 212–239).
- **Fix** (`packages/ve_services`):
  - `identify()`: hash ffprobe concurrently with `binaryIdentity` (both already run
    in isolates). Replace the second ffprobe hash with a size and mtime comparison,
    re-hashing only if they changed.
  - Add `Future<bool> statsUnchanged(FFmpegInstallation)` to `ffmpeg_identity.dart`:
    `binaryStats(path)` equals `identity.extensions['fileStats']`, and ffprobe's size
    and mtime equal `extensions['ffprobeIdentity']` (as `installationHealth`
    compares).
  - `WindowsFFmpegDiscovery`: a one-shot map from installation id to identity key,
    filled by `add()` and by `scan()` after each `register`.
    `refresh(installation, token)` removes the entry. If the entry matched
    `installation.identity.key` and `statsUnchanged` is true, refresh returns the
    recorded installation without identifying or writing. Otherwise it identifies,
    as now.
  - Probe: remember whether it started from a reused fingerprint. At the end, a
    reused check confirms with `statsUnchanged` and falls back to
    `requireCurrentInstallation` only if stats differ; a fresh check calls
    `requireCurrentInstallation`, as now.
  - `HardwareTests.test` gains `bool reuseIdentity = false` (C3). When true it
    confirms with `statsUnchanged` (falling back to the full check) instead of
    `requireCurrentInstallation`. Only the background tests of F4 pass `true`.
    Update `FakeHardwareTests` and `StalledHardwareTests` to accept the parameter.
- **Tests first** (`packages/ve_services/test/ffmpeg_services_test.dart`, temp files
  plus `FakeProcessExecutor`):
  - [ ] After add, replace ffmpeg's bytes with the same size and restore its mtime
    (`File.setLastModified`). The add's own check completes `done`, and the next
    explicit probe fails `FFMPEG-CHANGED`. This proves both the reuse and that
    explicit checks still read.
  - [ ] After add, change ffmpeg's size. The add's own check fails `FFMPEG-CHANGED`.
  - [ ] The existing `changeProbeDuringCheck` case (ffprobe grows during
    `-show_versions`) still fails `FFPROBE-CHANGED`.
- **Acceptance.** The harness shows ffmpeg and ffprobe each hashed once per add.
- **Docs.** CONTRACTS C3, the identification paragraph ("Explicit probe/test
  operations rehash…", around line 842): the check that follows Add or a scan reuses
  that fingerprint and confirms it by file stats; checks the user starts rehash.

### F4. Test only the catalog's hardware encoders during the check (D2)

- **Problem.** `qualify` defaults to every listed hardware video encoder
  (`hardware_services.dart`, around lines 190–199), up to 10 s each on timeout.
  This was the bulk of the check time and of the `machine.json` size.
- **Fix:**
  - Probe: the hardware phase passes
    `encoders: [catalog hardware ids that FFmpeg lists]`, from
    `core.profiles().video.where((p) => p.hw != null)`.
  - Add `bool windowsUnsupportedHardware(String name)`: true for suffixes `_vaapi`,
    `_videotoolbox`, `_v4l2m2m`, `_mediacodec`, `_rkmpp` and `_omx`.
    - In the probe's availability pass (`ffmpeg_probe.dart`, around lines 195–211),
      record these as `failed` with reason "Needs Linux or macOS; not available on
      Windows.", without running anything.
    - `qualify`'s default selection excludes them too.
  - After a check ends with `done`, `FFmpegController` tests the other listed
    hardware encoders (not in the catalog, not Windows-impossible) in the background:
    `hardwareTests.test(installation, encoders: rest, reuseIdentity: true)`.
    - `qualify` runs them one at a time, so they use one process slot.
    - No progress shows on the card. On completion, invalidate
      `capabilitiesProvider(id)`.
    - Cancel the run when the user starts a check or a hardware test on that
      installation, removes it, or closes the app. Don't restart it automatically;
      what's left stays untested until tested on demand or by the next check.
  - "Test hardware encoders" and the setup wizard's `untestedHardware` stay
    catalog-only, as now.
- **Tests first:**
  - [ ] Services: FFmpeg lists `h264_nvenc`, `hevc_amf` (not in the catalog) and
    `h264_vaapi`. The check runs test encodes only for `h264_nvenc`. `h264_vaapi` is
    recorded `failed` with the Windows reason and no process ran. `hevc_amf` is
    `unknown`.
  - [ ] App: after `done`, the controller calls `hardwareTests.test` with
    `[hevc_amf]` and `reuseIdentity: true`. Starting "Test hardware encoders" cancels
    that run.
- **Docs.** UI_SPEC §5 and §5a, where the check says it tests the listed hardware
  encoders. `docs/product/FFMPEG_INTEGRATION.md` §2.3, if it implies all of them.

### F5. "Runs on" shows the GPU name (D3, confirmed)

- **Problem.** The UI reads `EncoderAvailability.note` as the device
  (`app/lib/features/ffmpeg/display.dart`: `_row` around lines 391–395, and
  `encoderDetail` around line 473). The services write sentences instead:
  - The cache entry gets `note: result.reason` (`hardware_services.dart`, around
    lines 356–360).
  - The record gets '10-bit test passed.' or '10-bit has not passed.' (around lines
    383–385).
  - The check's final record update copies the cache entry.
  - Real result on the review PC: Runs on "8-bit test passed; 10-bit test failed."
    and detail "…a test encode passed on 8-bit test passed; 10-bit test failed..
    Presets that use it render normally."
- **Fix:**
  - In `qualify`, for a passing test, pick the adapter from the `GpuSnapshot`
    (`adapters[]` has `name` and `vendorId`; the native helper already drops
    software adapters).
    - `_nvenc` → 0x10DE, `_qsv` → 0x8086, `_amf` → 0x1002.
    - Other suffixes (`_mf`, `_d3d12va`, `_vulkan`) get the adapter's name only if
      there is exactly one adapter, otherwise ''.
  - Write `note` = that name for passes and '' for failures, in both the cache entry
    and the record. The 10-bit result stays in `tenBit` (cache) and moves to the
    record's `extensions.tenBit` (F6).
  - For results saved before this change, the display treats a note equal to the
    entry's `reason`, or to either old 10-bit sentence, as no device, and shows
    "<hw> GPU".
  - When there's no test result this session, the detail panel shows "10-bit works"
    or "8-bit only on this PC" from the recorded `extensions.tenBit`.
- **Tests first:**
  - [ ] Services: `FakeGpuIdentity` with adapters NVIDIA (vendorId 4318) and AMD
    (4098). A passing `h264_nvenc` gets the NVIDIA name in both the cache and the
    record, a passing `h264_amf` gets the AMD name, and a failure gets ''. Update any
    existing assertions on `note`.
  - [ ] App unit: an old-format note shows "AMD GPU" and no "passed on 8-bit…" text.
    A device note gives "…a test encode passed on AMD Radeon(TM) 8060S Graphics."
- **Docs.** CONTRACTS `EncoderAvailability` (around line 592): `note` is the device
  a passing hardware test ran on, empty otherwise.

### F6. Slim the installation record in `machine.json` (D4)

- **Problem.** Each installation's `availability` copies the cache's hardware
  entries: `stderr` and `detail` (the same text), plus `identityKey`,
  `gpuFingerprint`, `encoder`, `failureClass`, `tenBit` and `testedAt`.
  - The two writers are the check's final record update (`ffmpeg_probe.dart`, around
    lines 253–288) and `qualify`'s per-test update (`detail: result.stderr`).
  - `machine.json` is limited to 1 MiB in both the app and the exporter: roughly a
    dozen installations.
  - The exporter copies the whole record into every job record
    (`src/engine/recipe_job.cpp`, around line 483), so History records carry it too.
- **Fix:**
  - Add one helper, `recordAvailability(Map entry)`, returning `{state, reason`
    (capped at 300 characters)`, note, extensions: {testedAt?, tenBit?}}`. Use it for
    every availability written to `machine.json`: the check's final update,
    `qualify`'s per-test update, and the background tests.
  - Discovery's `register`, `refresh` and `updateRecord` slim every installation they
    write, so existing large records shrink on the next discovery write.
  - Leave the cache unchanged; it keeps stderr and details.
    - The FFmpeg page keeps showing FFmpeg's stderr line, because
      `WindowsFFmpegDiscovery.list()` overlays the cache's availability for unchanged
      installations (around lines 194–213).
    - Presets reads only state and reason.
  - The exporter needs no change: it reads `path`, `ffprobePath`, `identity` and
    `extensions` from the record (`recipe_job.cpp`, around lines 322–346), and
    `validateInstallation` accepts the slim fields.
- **Tests first:**
  - [ ] Services: after a check whose hardware failures carry 16 KB of stderr each,
    - the record's availability has no `detail`, `stderr`, `identityKey` or
      `gpuFingerprint`;
    - the cache's hardware entry still has `detail`;
    - `machine.json` stays under 20 KB for one full installation;
    - a fat legacy record is slimmed by the next `updateRecord`.
  - [ ] Repositories: a job record whose `ffmpeg` is a slim record decodes
    (`decodeJob`).
- **Acceptance.** Re-measure a real record. About 12–15 KB per full build is
  expected; record the actual size.

### F7. Show the encoder list as soon as it's read; stream hardware results (confirmed)

- **Problem.** `FFmpegController.probe` sets `state.probed` only on `done`
  (`app/lib/state/ffmpeg.dart`, around lines 211–217), although the check caches the
  encoder lists before its hardware phase (`ffmpeg_probe.dart`, around line 232).
  Hardware results don't reach the rows during the check.
- **Fix, services:**
  - The check's first `hardware` event carries `capabilities` (the capabilities just
    cached, with hardware rows `unknown`) and `total` = the number of encoders it
    will test.
  - `ProbeProgress` gains an optional `hardwareResult: HardwareTestResult?` (C3,
    model, fake). The check emits one `hardware` event with it per tested encoder.
    `done` is unchanged.
- **Fix, app:**
  - `FFmpegController.probe`: when an event carries capabilities, set `probed[id]`
    at once and invalidate `capabilitiesProvider(id)` (once per new capabilities, not
    on every event).
  - On the first `hardware` event, set `testing[id]` to the catalog hardware encoders
    listed in those capabilities.
  - Record each `hardwareResult` in `testResults[id]` and remove it from `testing`.
    On the terminal event, clear what's left.
  - The card computes its counts from `probed` when present. The recorded `counts`
    are written only at the end.
- **Tests first:**
  - [ ] Services: events arrive in order: capabilities on the first `hardware`
    event, one `hardwareResult` per tested encoder, then `done`.
  - [ ] App unit: a scripted probe stream (the `FakeFFmpegProbe` progress fixture).
    After the first `hardware` event, libx264 is Ready and `h264_nvenc` is Testing…;
    after its result, Ready or Failed.
  - [ ] Goldens: the probing state with the list visible. Review the diffs of
    `ffmpeg_probing_{light,dark}` before updating them.
- **Docs.**
  - CONTRACTS `ProbeProgress` (around line 603): capabilities also on the first
    `hardware` event; the `hardwareResult` field.
  - UI_SPEC §5 "Probing" row.

### F8. Show the new card at once: quick version check and a pending card

- **Goal (owner).** Choosing `ffmpeg.exe` checks its version immediately. A valid
  FFmpeg appears and is selected straight away, with its details. The slower work
  follows without blocking the UI.
- **Problem.**
  - The card waits for identify and record (F3 baseline: 1.0–2.7 s), plus up to 1 s
    for the discovery poll.
  - There is no feedback meanwhile, and **Add FFmpeg…** stays enabled.
  - `add()` awaits the whole check, so "Added …" arrives at the end.
- **Fix, services:**
  - `FFmpegDiscovery.quickCheck(String executablePath) → Future<FFmpegInstallation>`
    (C3). On Windows:
    - `_resolve` (Scoop shim), `requireX64Pe`, ffprobe present beside it;
    - `-hide_banner -version` with `probeIdentityTimeout`;
    - `parseVersion`, then `requireSupportedFFmpeg`.
  - It returns a **display-only** installation:
    - the same id as `identify()` (extract `installationIdFor(resolved)` and use it
      in both);
    - label, path, ffprobePath, source `manual`, version, build and license;
    - `identity: BinaryIdentity(sha256: '', key: '')`, `health: 'unknown'`.
  - It writes nothing, hashes nothing and doesn't run ffprobe. It uses the same
    error codes as `identify`.
  - `FakeFFmpegDiscovery.quickCheck` returns the addition fixture, or throws
    `B0-FIXTURE-MISSING`. Allow gating with a Completer for tests.
- **Fix, app** (`FFmpegController`):
  - New state: `pending: Map<String, FFmpegInstallation>`.
  - `add(path, {ValueChanged<FFmpegInstallation>? onRegistered})`:
    1. `quick = await discovery.quickCheck(path)`. If `quick.id` is already pending,
       select it and return the running future, so no duplicate is added.
    2. Add `quick` to `pending`. Select it if `_selections` hasn't changed since the
       add started (keep the C1 rule).
    3. `installation = await discovery.add(path)`. On `ServiceException`, remove the
       pending entry and rethrow; the page toasts as now.
    4. `ref.invalidate(discoveredInstallationsProvider)`, so the recorded card arrives
       now rather than on the next poll. Then call `onRegistered?.call(installation)`.
    5. `await probe(installation)`. Remove the pending entry in `finally`.
- **Fix, page:**
  - The card strip shows the discovered installations, plus pending entries whose id
    isn't listed yet. For each id there is exactly one card at every moment.
  - A pending card shows:
    - title and the build/licence/source line;
    - the path;
    - "Checking the files…" with an indeterminate bar;
    - **Copy path** only: no Set as default, no Remove.
  - With a pending card selected, the capability pane shows the table as "Not
    checked yet", with "Test hardware encoders" and **Test** disabled.
  - Toast "Added <label>" from `onRegistered`. Re-adding a listed installation says
    "<label> is already listed. Checking it again."
  - Scroll the selected new card into view with `Scrollable.ensureVisible`. At the
    1,100 px minimum width, a fourth card is off-screen.
- **Fix, setup wizard.** The candidate list includes pending entries as
  non-selectable rows with the same progress line. `SetupWizardController.add` still
  awaits the whole add. **Locate…** uses the same path, unchanged.
- **Tests first:**
  - [ ] Services, fake processes: a valid file returns version, build and license,
    runs `-version` exactly once, doesn't run ffprobe, and leaves `machine.json`
    unchanged.
    - It refuses a non-x64 exe, a missing ffprobe, FFmpeg 4.3 (`FFMPEG-UNSUPPORTED`)
      and a non-`.exe` path.
  - [ ] Widget, with `FakeFFmpegDiscovery.add` gated by a Completer:
    - after tapping **Add FFmpeg…**, the pending card is visible and selected within
      one pump, showing its version and "Checking the files…";
    - Set as default and Remove are absent, and "Test hardware encoders" is
      disabled;
    - completing the add swaps in the recorded card, never with zero or two cards;
    - a failing add removes it and toasts "Couldn't add …".
  - [ ] Widget: a `quickCheck` refusal shows a toast and no card.
  - [ ] Widget: adding the same path twice quickly gives one card.
  - [ ] Widget: the wizard shows the pending row.
  - [ ] Widget: with three cards at 1440×900, the added fourth card ends up visible.
  - [ ] Goldens: `ffmpeg_pending_{light,dark}`.
- **Docs.** UI_SPEC §5 Header, Cards and States, and §5a Check. CONTRACTS C3 API
  table (`quickCheck`).

### F9. Smaller fixes

- [ ] **Presets marks every encoder of a never-checked FFmpeg as missing.**
  `availabilityOf` returns missing when there's no entry
  (`app/lib/features/presets/display.dart`, around lines 162–179). Right after adding
  and setting as default, the editor says "Not in FFmpeg X" everywhere.
  - Fix: no entry and `probedAt == null` gives `unknown`, with no reason.
  - Unit test.
- [ ] **Scan problems are never shown.** `WindowsFFmpegDiscovery.scanProblems`
  (around line 192) isn't on the interface, and its entries lack the path.
  - Add `List<ScanProblem> get scanProblems` (path, code, message) to
    `FFmpegDiscovery`, configurable on the fake.
  - The Scan again toast adds "N couldn't be used: <path>: <message>", naming the
    first.
  - Widget test.
- [ ] **Check failures show "ServiceException(CODE): …".** `ffmpeg_probe.dart`
  (around line 304) uses `toString()`. Use `message` for a `ServiceException`. Check
  any tests that match on the old text.

## 5. Validation

Say for each result whether it used fakes, real FFmpeg or neither. Nothing here
involves real VEGAS.

- [ ] App: `& $env:VEGAS_ENCODER_FLUTTER analyze` is clean, and the full
  `flutter test` passes, including light and dark goldens. Review every image diff
  before `--update-goldens`.
- [ ] Services: `scripts/etc/Test-B3Services.ps1` and
  `scripts/etc/Test-B3Repositories.ps1`.
- [ ] Real FFmpeg: `scripts/etc/Test-B3Runtime.ps1 -FFmpegPaths <static>,<essentials>,<shared>`.
  Use `VEGAS_ENCODER_FFMPEG` and the builds in the ignored `build/ffmpeg-builds/`, or
  any FFmpeg 4.4+ builds; pass them by path and never commit them.
- [ ] Render matrix `-Quick` (fake host, real FFmpeg), once. It confirms that job
  records built from a slim installation record still decode.
- [ ] `python -I scripts/etc/Test-NoMachinePaths.py`.
- [ ] Repeat the services harness (section 2) and compare with Phase 0. Targets on
  the review PC with the static build:
  - card visible at most 0.5 s after the path is chosen;
  - encoder list at most 3 s;
  - check done (catalog hardware) at most 6 s;
  - ffmpeg and ffprobe each hashed once per add;
  - no UI-isolate stall over 50 ms apart from an exe's first launch.
  Record the actual numbers.
- [ ] Repeat the real-services page repro of F2 (Set as default mid-check, then
  Presets): exactly one check runs.
- [ ] Delete every scratch file and folder.

## 6. Owner's manual checks (real app, isolated data root)

Set `VEGAS_ENCODER_DATA_ROOT` to an empty folder and start the built app. Settings >
About shows the data folder in use.

1. Add the static FFmpeg build. The card shows and is selected at once with its
   version; the encoder list follows within a few seconds; hardware results fill in.
2. While it is being checked, click other cards and their buttons: every click works.
3. While it is being checked, click **Set as default** on it, then open Presets. Task
   Manager shows only one set of FFmpeg test processes.
4. Add a second build, switch to another app and back, then restart. Both
   installations are listed.
5. Hover a passing hardware encoder: Runs on shows the GPU name.

## 7. Unresolved: the report of an FFmpeg disappearing

Not reproduced. Tried with real services and real FFmpeg:
- adding the static build while gyan 9.0.2 was the default;
- switching to Presets and back mid-check;
- making the app inactive, then active again;
- restarting with fresh services.

Both installations stayed every time, and `machine.json` kept both.

Leads, if it happens again:
- Note which build was running (installed, or `flutter run`) and whether
  `VEGAS_ENCODER_DATA_ROOT` was set. A different data root reads a different
  `machine.json`. Settings > About shows the folder in use.
- Copy `machine.json` from that folder straight away: its `revision` and
  `installations` show whether the record was really removed.
- F1 (cards remounted mid-click) and the fourth card sitting off-screen (F8) can both
  look like a card vanishing.

## 8. Docs to update when done

- `docs/product/UI_SPEC.md` §5 and §5a. In the 0.2.1 behaviour list, extend the
  "FFmpeg page" line (around line 870).
- `docs/product/CONTRACTS.md` C3:
  - the API table (`quickCheck`, `scanProblems`, `HardwareTests.test(reuseIdentity)`);
  - `EncoderAvailability.note`;
  - `ProbeProgress`;
  - the identification and rehash rule;
  - the record slimming.
- `docs/product/FFMPEG_INTEGRATION.md`, where it describes which hardware encoders
  are tested.
- `docs/STATUS.md`: what changed, the checks run (fakes or real FFmpeg), and the
  measured before and after numbers.
- `docs/NEXT_AGENT.md`: the queue entry for this work and its outcome.
