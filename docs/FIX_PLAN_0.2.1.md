# Vegas Encoder 0.2.1 bug-fix plan

Written 2026-11-07 from two static code reviews of `master` at `5c59138` (release
0.2.0+3). The second review's claims were checked against the code; section 10
records each verdict. **Nothing in this plan has been executed or reproduced yet.**
The review machine had no Flutter, Dart, MSVC, Python or Node. Treat every root
cause below as a hypothesis until its regression test fails on the current code
for the stated reason.

The owner wants every item fixed, except those dropped by owner decisions. The
work is split between a **lead agent** and up to **three subagents** (section 1).
All owner decisions are recorded in section 2. Subagents cannot ask questions, so
they follow those decisions exactly.

## Phase 0 record (lead, 2026-11-07)

- **Decisions.** D1 to D10 in section 2 are final. No default was replaced (D3, D6
  and D9 use the recommended default).
- **Branch.** `fix/0.2.1` from `master` `5c59138`. Before the baseline the owner
  merged `from-vegas-display` (`45c5f76`, live VEGAS pipe streams in the editor)
  into `fix/0.2.1`; the baseline includes it.
- **Lead toolchain.** Flutter 3.47.9 (Dart 3.13.7; the plan names 3.47.7), VS 18
  MSVC 14.51, Python 3.14. FFmpeg and FFprobe `N-128435-g7798de15f86-gdb8537d8cc7+2`
  (the owner's AV1-stall build) are the only FFmpeg on the lead PC. No Inno Setup,
  Node or VEGAS is installed there.
- **Checkout paths with spaces** now build and test (owner-approved):
  `native_toolchain_c` 0.19.2 → 0.19.3 (the upstream fix for MSVC builds from paths
  with spaces; the app lock also moves `meta` 1.18.3 → 1.19.0). `Test-B2.ps1` calls
  `cmd` with relative script paths, and the setup helper's test-only respawn quotes
  its arguments.
- **Fresh checkout prep.** Run `dart pub get` in `packages/ve_core` and
  `packages/ve_services` before the Dart runners, and
  `cmd /d /c scripts\etc\Build-SetupHelper.cmd test` before `Test-Setup.py`.
- **L0.6.** `scripts/etc/Tools.ps1` and `scripts/etc/Find-VcVars.cmd` resolve every
  tool from the parameter, then `VEGAS_ENCODER_*`, then `PATH` (MSVC: an active x64
  developer prompt, then `vswhere`). See `scripts/README.md`.
  `Test-NoMachinePaths.py --scope scripts` passes; the full scope fails until L4
  (150 lines in 46 files). Its drive-letter allowlist also covers `tests/**` (native
  test fixtures) and the two generated B0 fixture Dart files.
- **L0.4.** Release 0.2.1+1 (file version 0.2.1.1), core 0.3.1. A new
  `Test-Setup.py` case checks the upgrade from 0.2.0+3 and the downgrade block; it
  failed before the bump and passes after.
- **Pre-existing failures found by the baseline:**
  - Fixed in Phase 0: the AV1 (CPU) built-in's `updatedAt` was not UTC, so copies
    of it failed to load (`library_watch_test`); `Generate-ServiceBuiltins.py` now
    refuses non-UTC timestamps. `repositories_test` still expected AV1 (CPU) at
    revision 3. The setup helper's ancestor test failed on paths with spaces.
  - Still open, **for A**: `Test-VegasEncoder.ps1` (fiohost, fixed-profile DLL)
    fails on FFmpeg N-128435, because the fixed-profile command in
    `src/engine/encode.cpp` passes `-thread_queue_size` before each `-i`, which
    this FFmpeg rejects ("cannot be applied to input url"). It passed on a gyan
    2025-10-27 build. The core already dropped this flag (core test "live inputs
    do not reintroduce rejected queue flags").

**Results after Phase 0** (real FFmpeg N-128435 where FFmpeg is used; fakes or the
fake host everywhere else; no real VEGAS):

| Suite | Result |
| --- | --- |
| Versions, generated built-ins, scripts path check | pass (8 version tests) |
| `Build-Release.ps1 -Action Build` | pass; app `0.2.1+1`, all four exporter DLLs 0.2.1.1 |
| `Test-B2.ps1 -Asan` | pass: 3,182 core checks (normal and ASan), 180 B1 data, 246 FFI ×2 |
| `Test-B4.ps1 -Asan` | pass: 32,645–32,672 checks, 27 cases (timing-dependent count), 369 record checks; normal and ASan |
| `Test-B6.ps1 -Asan` | pass: 523 snapshot, 97 transport, 485 page, monitor cadence; normal and ASan |
| `Test-VegasEncoder.ps1` (fiohost) | **fail** (pre-existing, above; for A) |
| `Test-LegacyContainers.ps1 -FFmpegPath` | pass: 335 naming, 417 legacy, 184 manual, 443 automatic, 34 runtime, 120 container renders, 179 automatic-name renders |
| `Build-OlderVegasTrials.ps1` | pass: 22, 21 and 13 each 478 callback + 179 render checks + wrong-host rejection |
| ve_core / ve_services Dart runners | pass: 177; 89, 15, 12, 99 (library watch), 26 |
| `Test-B3Services.ps1` / `Test-B3Repositories.ps1` / `Test-B3Runtime.ps1` | pass: 4,469 / 170 / 67 (11 synthetic encodes, 3 unavailable-encoder refusals) |
| `flutter analyze` / `flutter test` | clean / 700 pass |
| `Test-Setup.py` / `Test-ReleaseInputs.ps1` | 48 / 15 pass |
| `Test-RenderMatrix.ps1` | not yet (A creates it in T3) |

---

## 0. Read this first (every agent)

### Project rules that apply to this work (from AGENTS.md)

- Never install or replace an installed exporter, run Setup, push, merge into
  `master`, rewrite history or upgrade machine-wide tools.
- The C++ core (`src/core`) is the **only** implementation of compile, validate,
  lint and completion. The app reaches it only through `packages/ve_core` and
  `packages/ve_services`. Keep `src/core` free of Windows and VEGAS headers.
- Host (VEGAS) calls stay on Render's caller thread. Release host frames before any
  wait. Nothing may make Render wait on the app or the progress window.
- Every app UI change needs widget tests and golden tests in **light and dark**.
  Review the image diffs before accepting new goldens.
- Always state whether a check used fakes, the fake host, real FFmpeg or real VEGAS.
  Fake-host results never prove real-VEGAS compatibility.
- For Flutter, Dart, Riverpod and other external API questions, use Context7
  (`npx ctx7@latest library …`, then `npx ctx7@latest docs …`, outside the
  sandbox). Do not guess.
- Owner-deferred trials stay deferred: same-session encoder-failure recovery, and
  the faster-progress real-host performance comparison. Do not request them.
- Test output goes under the ignored `build/test-results/`.
- Subagents and worktrees are allowed (decision D10 and AGENTS.md). Each worktree
  builds and tests inside itself, and nothing is installed from a worktree.

### Read before starting

`AGENTS.md`, `docs/product/README.md`, `docs/product/WORKSTREAMS.md`,
`docs/STATUS.md`, `docs/NEXT_AGENT.md`, `docs/ARCHITECTURE.md`,
`docs/ADAPTER_PLAN.md`, `docs/INTEGRATION_CONTRACT.md`, `docs/product/CONTRACTS.md`,
`docs/product/TECH_ARCHITECTURE.md` (§5, §9), the relevant `docs/product/UI_SPEC.md`
sections, and `docs/BUILDING.md`.

### Toolchain needed

- PowerShell 7
- Flutter 3.47.7
- MSVC (VS 18 `vcvars64.bat`)
- Python 3
- At least one real FFmpeg build with FFprobe beside it. Ideally use two:
  - the owner's build `N-128435-g7798de15f86-gdb8537d8cc7+2`, which reproduced the
    AV1 stall;
  - a current gyan or BtbN release.
- Node only if B0 design fixtures must be regenerated (probably not needed).
- Inno Setup 6.7.1 only for packaging.

Read each script's `param()` block before running it. The commands in this plan are
a guide; the scripts are authoritative. After L0.6, tool locations come from
parameters, environment variables (`VEGAS_ENCODER_FLUTTER`, `VEGAS_ENCODER_VCVARS`,
`VEGAS_ENCODER_PYTHON`, `VEGAS_ENCODER_FFMPEG`) or `PATH`. Confirm build outputs
land inside your own checkout or worktree.

**No machine-specific paths (decision D7).** Never write absolute paths (drive
letters, user-profile folders, user names) into committed files: code, scripts,
docs, plan updates or reports that the lead copies into docs. Use repo-relative
paths, environment variables, or placeholders such as `<ffmpeg.exe>` and
`<worktree>`.

---

## 1. How the work is split

### 1.1 Workstreams

| Workstream | Who | Owns (may edit) | Items |
| --- | --- | --- | --- |
| **Lead** | The agent the owner starts | `version.json` and its generated files; `schema/builtin-presets.v1.json` and its generated files; all shared docs (`docs/**`, `AGENTS.md`, `README.md`); merging; cross-cutting golden and fixture refreshes | L0–L6 (sections 5 and 9) |
| **A: native exporter and engine** | Subagent A | `src/engine/**`, `src/vegas/adapter/**`, `src/vegas/host/**`, `src/support/**`, `src/settings/**`, `tests/engine/**`, `tests/fiohost/**`, `tests/host/recipe_render.cpp`, `tests/host/recipe_runtime_checks.cpp`, `tests/host/legacy_*.cpp`, `tests/host/container_naming.cpp`, `tests/host/manual_names.cpp`, `tests/host/native_progress.cpp`, new `scripts/etc/Test-RenderMatrix.ps1`, `scripts/etc/Test-B4.ps1` | A1–A19, T1–T3 (section 6) |
| **B: C++ core and VEGAS template page** | Subagent B | `src/core/**` (except generated `profiles/data.h`, unless its generator input changes), `tests/core/**`, `src/vegas/configuration/**`, `tests/host/recipe_pages.cpp`, `tests/host/editor_sessions.cpp`, `tests/host/native_configuration.cpp`, `tests/host/recipe_templates.cpp`, `scripts/etc/Generate-CoreGoldens.py` outputs (`packages/ve_core/test/b1_argv.dart`, `schema/fixtures/b1/core-argv.json`) | B1–B9, T4 (section 7) |
| **C: Dart services and Flutter app** | Subagent C | `packages/ve_services/**` (except generated `builtin_presets.dart`), `packages/ve_core/lib/**`, `packages/ve_core/test/**` (except `b1_argv.dart`), `app/**` (including `app/windows/runner/**` and `app/test/**`) | C1–C16 (section 8) |

**Files more than one workstream needs.** Make only minimal, additive edits to
these. If a conflict appears, the lead resolves it while merging.
- `scripts/etc/Build-B6.cmd` and `scripts/etc/Test-B6.ps1`: A and B both add test
  sources there.
- `scripts/etc/build.cmd`: A only; B asks the lead if it needs a change.

**If a subagent needs a change in a file it doesn't own:** don't make it. Describe
the change in your final report; the lead applies it during integration.

### 1.2 Order of work

1. **Lead, Phase 0** (section 5): baseline, version bump, decisions recorded, plan
   committed, worktrees created.
2. **A, B and C run in parallel**, each in its own worktree and branch. Each follows
   the test-first protocol (section 4.3) and must not edit shared docs.
3. **Lead merges B, then A, then C** into `fix/0.2.1`. Order: core, then exporter,
   then app.
4. **Lead integration** (section 9):
   - the AV1 workaround removal (L2), which depends on A1;
   - the `-nostats` refresh of app goldens and fixtures (L3), which depends on B1;
   - end-to-end checks of the shared contracts;
   - docs, full regression, release build, owner checklist.

### 1.3 Worktrees and branches (decision D10)

From the original checkout, after the Phase 0 commit on `fix/0.2.1`:

```powershell
git worktree add ..\vegas-encoder-fix-a -b fix/0.2.1-a fix/0.2.1
git worktree add ..\vegas-encoder-fix-b -b fix/0.2.1-b fix/0.2.1
git worktree add ..\vegas-encoder-fix-c -b fix/0.2.1-c fix/0.2.1
```

- Each subagent commits locally on its own branch, never pushes, and builds and
  tests only inside its own worktree (`build/`, `build/test-results/`, `.dart_tool`).
- After merging, the lead asks the owner before removing the worktrees
  (`git worktree remove`).
- Existing sibling worktrees and `.claude/` must stay untouched.

### 1.4 Spawning the subagents (lead)

- Start three **background** subagents with a profile that can write files and run
  commands (the general-purpose profile).
- Give each the prompt template in the appendix, filled in for its workstream.
  Subagents can't see this conversation and can't ask questions, so everything they
  need must be in the prompt and this plan file.
- If background subagents can't run builds or tests because of tool-permission
  limits, run them one at a time in the foreground instead, in the order A, B, C.
- While they run, the lead does not edit any file that a subagent owns.
- When each one finishes, the lead:
  1. reads its report;
  2. reviews its diff (`git diff fix/0.2.1...fix/0.2.1-x`);
  3. reruns that workstream's focused suites itself, inside the worktree;
  4. only then merges.

---

## 2. Owner decisions (settle before spawning; defaults recommended)

| # | Question | Recommended default |
| --- | --- | --- |
| D1 | **Overwriting an existing output (A4).** VEGAS 2026 checks the real filename. Legacy auto-name hosts (13, 21, 22, 23) only check the `.vencoder` placeholder and never warn about the real file. | **Decided by the owner (option 2):** where VEGAS checked the real name (2026), replace the file, but only if it is still the same file that existed when the render started. On legacy auto-name hosts, write `name (2).ext` (the first free name) and show the actual path. Never silently replace a file VEGAS did not warn about. The owner confirms on 2026.0.3.189 that VEGAS asks before replacing (L6). |
| D2 | **Frozen template editor (B7).** | **Decided by the owner:** keep things as they are (the user can end the editor in Task Manager). No watchdog; B7 is dropped. |
| D3 | **Imported presets that touch outside files or the network (B3, C9).** | **Decided by the owner (default):** warn and ask for confirmation at import, and keep a warning visible. Do not block rendering. |
| D4 | **Length-limiting FFmpeg options (B2, A7, C16).** | **Decided by the owner:** allow them, with a warning. `-t`, `-to`, `-frames*`, `-vframes`, `-aframes`, `-fs` and `-shortest` are core **warnings**, not errors. The app shows a pop-up warning when a preset using them is saved or applied. When FFmpeg finishes early with exit code 0, the render ends successfully with the shortened file. |
| D5 | **Retention.** | **Decided by the owner:** dropped. No cleanup of old jobs, logs or sessions (A16 and C7 dropped). Only the cancel bug in B8 is fixed. |
| D6 | **Non-square pixel projects (A9).** | **Decided by the owner (default):** fix the message now. Full anamorphic rendering is a later, separately approved feature. |
| D7 | **Paths in docs and scripts.** | **Decided by the owner:** no machine-specific absolute paths in committed files, for privacy and so work runs on any PC. Scripts find tools through parameters, environment variables or `PATH` (L0.6). Active docs use repo-relative paths and placeholders (L4). Historical records keep their content, but user-profile paths in them are redacted to `%USERPROFILE%`, `%APPDATA%` or `%LOCALAPPDATA%` form. |
| D8 | **Hardware encoder that failed its last test (A10).** | **Decided by the owner:** warn, don't block. The render goes ahead so the user can try. If FFmpeg then fails, the error says this encoder also failed its last test on this PC, and suggests testing again on the FFmpeg page or choosing another encoder. |
| D9 | **Failures before encoding starts (A5).** | Write a failed History record with the reason, and show the progress window with that reason when the progress window is enabled. |
| D10 | **Parallel execution.** | **Decided by the owner:** allowed. Up to 3 temporary git worktrees, local commits on `fix/0.2.1*` branches (no push), and background subagents. The single-agent rule was removed from AGENTS.md. |

---

## 3. Shared contracts (fixed here so A, B and C build the same thing)

The lead copies these into `docs/product/CONTRACTS.md` during integration. Any
change to them must go through the lead.

### 3.1 C6 job record: new fields (all optional, so older records stay readable)

| Field | Type | Producer | Meaning |
| --- | --- | --- | --- |
| `stage` | `"preflight"` or `"encode"` (absent means `"encode"`) | A | `"preflight"`: the render stopped before FFmpeg started (A5). |
| `requestedOutputPath` | string, present only when it differs from `outputPath` | A | The path VEGAS asked for. `outputPath` is always the file actually written (A4, legacy `name (2).ext`). |
| `replacedExisting` | bool (absent means false) | A | A pre-existing destination was replaced (A4). |
| `endedEarly` | bool (absent means false) | A | FFmpeg finished with exit code 0 before all of VEGAS's frames were sent, for example because of `-t` (A7). The render still succeeded. |
| `transport` | object `{videoHighWater, audioHighWater, videoBytes, audioBytes, videoQueueLimit, audioQueueLimit}`, all integers ≥ 0 | A | Queue diagnostics (A1). |

**Preflight records** (`stage: "preflight"`):
- `status` is `"failed"` or `"cancelled"`;
- `media` may be `null`, and `ffmpeg` may be `null`;
- `argv` is `[]`;
- `verification` is `{"state":"skipped", …}`;
- `published` is false, `sizeBytes` is 0, `ffmpegExitCode` is null, `logFile` is
  null;
- `recipe` and `origin` are the template snapshot (always available from `Create`).

**Timestamps:**
- Writers guarantee `endedAt >= startedAt` by clamping (A18).
- Readers must not reject a record because of clock skew; at most they show the
  elapsed time as unknown (C11).

### 3.2 C5 live status

A preflight failure (A5) writes a terminal live file:
- `state: "failed"` (or `"cancelled"`), with `message` set to the reason;
- `framesTotal` may be null.

The progress window, if launched, shows the reason (C15).

### 3.3 C3 services API

- `Future<String> PresetLibrary.availableId(String name)`: returns a safe ID that is
  free among current presets **and** retained history folders, compared
  case-insensitively (C2).
- Library problems: `list()` no longer throws because of one bad file. Problems are
  exposed through an API C chooses (for example
  `Future<List<LibraryProblem>> problems()`, with `LibraryProblem {path, code, message}`).
  C documents the exact shape in its report.
- Preferences: favorite and pinned flags for user presets live in the
  `preferences.json` overlay, keyed by lowercase ID, exactly as built-ins already
  work. Writing them never bumps a preset's revision or adds history. Reading uses
  the overlay first, then falls back to the value in the `.vepreset` file (C3).
- Job index: malformed lines are skipped and counted, never fatal. C documents the
  API for the count (C4).

### 3.4 Core issue IDs (B produces, C consumes)

| ID | Level | Where | Meaning |
| --- | --- | --- | --- |
| `L-DURATION-LIMIT` | warn | Advanced | `-t`, `-to`, `-frames*`, `-vframes`, `-aframes`, `-fs` |
| `V-EXTRA-DURATION` | warn | Basic Extra arguments | same options |
| `L-SHORTEST` / `V-EXTRA-SHORTEST` | warn | Advanced / Basic | `-shortest` |
| `L-INPUT` (existing) | warn | Advanced | extra `-i` inputs |
| `L-OUTPUTS` (existing) | warn | Advanced | extra outputs |
| `L-NETWORK` / `V-EXTRA-NETWORK` | warn | Advanced / Basic | URL or protocol arguments (`://`, `http:`, `https:`, `ftp:`, `tcp:`, `udp:`, `rtmp:`, `srt:` and similar), including `tee` targets |
| `L-FILE-ACCESS` / `V-EXTRA-FILE` | warn | Advanced / Basic | `-attach`, `-dump_attachment`, `-/option` file loading, `-filter_script`, `-filter_complex_script`, and filters with file arguments (`movie=`, `amovie=`, `subtitles=`, `ass=`, `drawtext=…textfile=`) |
| `V-EXTRA-WRONG-STREAM` | warn | Basic | an option with an explicit stream specifier for the other stream (for example `-b:a` in Video Extra arguments) |

The app's **external access** set is `L-INPUT`, `L-OUTPUTS`, `L-NETWORK`,
`L-FILE-ACCESS`, `V-EXTRA-NETWORK` and `V-EXTRA-FILE`.

### 3.5 Native INI keys (A)

- `StallTimeoutMs`: default 120000.
- `ConnectTimeoutMs`: default 30000.
- The existing `PipeTimeoutMs` and `FinishTimeoutMs` are read as deprecated aliases
  for `StallTimeoutMs`; log which value was used.

---

## 4. Testing

### 4.1 Can the export path be tested without VEGAS?

Mostly yes. "If the core works, the export works" is only partly true. The export
path has three parts that can fail independently:

1. **VEGAS to plug-in (ABI).** What each VEGAS version actually delivers: frame
   formats, audio formats, template bytes, call order, naming, prompts, threading.
   - Version-specific. Only real VEGAS proves it.
   - The fake host (`tests/fiohost`) loads the **real DLL** and replays the call
     sequence recorded from VEGAS, so it catches regressions against known
     behaviour.
   - Past bugs found only on real hosts: template-name alignment, the Sony 13
     1×1 RGB frame, `.vencoder` naming. The 44.1 kHz project failure (A2) was
     missed because every test used 48 kHz.
2. **Plug-in to FFmpeg (transport).** Pipes, queues, timeouts, process lifetime,
   early exit. Depends on the encoder and the FFmpeg build. **Fully automatable
   without VEGAS.**
   - The AV1 stall lives here. The core produced the right command; the transport
     deadlocked with one encoder.
3. **Publishing and verification (filesystem).** Overwrite, locked files,
   permissions, long or Unicode paths. Fully automatable.

What already exists:
- `tests/engine/recipe_jobs.cpp` runs the real engine against real FFmpeg, and its
  `Child()` function already acts as a scriptable **fake FFmpeg** (`exit` and
  `hold` modes).
- `tests/host/recipe_render.cpp` (B6) runs the real `render.cpp` against the fake
  host.
- `tests/fiohost` drives the actual DLL.
- `Test-LegacyContainers.ps1 -FFmpegPath …` and `Build-OlderVegasTrials.ps1` cover
  the 22, 21 and 13 host profiles with fake kernel DLLs.

So: make part 2 and part 3 testing exhaustive and automatic (T1 to T3), and keep
real-VEGAS testing as a short owner checklist per version (L6). After a new VEGAS
version is checked by hand, record what it delivered into fake-host fixtures, so
later regressions are caught offline.

Situations the render matrix must cover:
- encoder delay longer than the queues allow (lookahead, many-core SVT-AV1, x264 or
  x265 with large `rc-lookahead`, 4K);
- very slow encoders, and a long flush at the end;
- differences between FFmpeg builds;
- container and codec mismatches;
- project audio at **44.1 kHz, 96 kHz, mono and 5.1**, plus video-only presets in
  those projects;
- unusual sizes and frame rates (48000/1001, 12.5, 240000/1001), and non-square
  pixels;
- an existing, locked or vanished destination; Unicode and long paths;
- cancelling at the start, middle and finish stages; FFmpeg crashing or exiting
  early;
- hardware encoders that are unavailable or busy; two renders in one session.

### 4.2 New test infrastructure (each owner builds it before their fixes)

- [ ] **T1 (A). Chaos fake FFmpeg.** Extend `Child()` in
  `tests/engine/recipe_jobs.cpp`. Each mode prints `-progress` blocks to stdout,
  flushing each block. It writes `\r`-terminated `frame= … fps= …` stats lines and
  errors to stderr, the way real FFmpeg does. Each mode reads `-s`, `-r` and `-i`
  from its argv.

  | Mode | Behaviour |
  | --- | --- |
  | `latency:<N>` | Reads video freely. Reads audio only while audio time ≤ (video frames read − N) ÷ fps + 0.1 s. |
  | `slow-read:<ms>` | Reads one frame every `<ms>`, with advancing `out_time_us` and `total_size` every 500 ms. |
  | `stall-after:<frames>` | Stops reading after `<frames>` frames; keeps printing unchanging progress. |
  | `slow-flush:<ms>` | After input ends, takes `<ms>` to exit, with advancing progress. |
  | `hang-flush` | Never exits after input ends; prints nothing. |
  | `early-exit-ok` | Exits with code 0 right after input ends, without draining the last buffers. |
  | `stats-then-error` | About 50 `\r` stats lines, then `[vost#0:0/libx264 @ 0x1] Error submitting video frame to the encoder` and `Conversion failed!`, then exits 1. |

- [ ] **T2 (A). Fake-host options and counters** in
  `tests/fiohost/fakehost.{h,cpp}`:
  - a `progressCalls` count (`SetPosition` and `CheckCancel`);
  - a `pixelAspect` option;
  - **audio `sampleRate` and `channels` options**, delivering float32 at any rate
    and channel count;
  - a way to make the delivered template carry those audio facts, as
    `ConformTemplate` would.
- [ ] **T3 (A). Render matrix.** Create `scripts/etc/Test-RenderMatrix.ps1`. It
  drives the **actual exporter DLL** through fiohost for each host profile: 2026/23
  modern, 23 legacy names, 22, 21 and 13. Dimensions:
  - every built-in preset;
  - several project shapes: 1280×720 at 23.976 / 1920×1080 at 29.97 / 1920×1080
    at 59.94 / 3840×2160 at 25;
  - project audio 48 kHz stereo / 44.1 kHz stereo / 48 kHz mono / 48 kHz 5.1 /
    none;
  - a short length (60 frames) and a long length (≥ 900 frames);
  - every supplied FFmpeg build.

  Verify each output with a full FFprobe decode: exact frame count, exact sample
  count, and the expected codec, container and channel count. Provide `-Quick`
  (one build, modern profile, 1080p29.97, all presets, 48 kHz and 44.1 kHz, short
  and long) and `-Full`. Write results to
  `build/test-results/render-matrix-<timestamp>/summary.json`. Hardware rows are
  skipped when the probe reports them unavailable.
- [ ] **T4 (B). Fake template editor.** Add a child mode to the native page test
  executable acting as `VegasEncoder.exe --edit-session`. Modes:
  - `normal`: shows a window and writes an Apply result;
  - `invalid-apply`: Apply with a recipe the page's validation rejects;
  - `cancel-hold`: keeps running until killed (for the B8 cancel test).

### 4.3 Test-first protocol (mandatory for every item)

1. **Write the regression test first.** Run it on the unmodified code. It must fail
   *for the reason this plan describes*. Record the failing output (command and key
   lines). If it fails for another reason, stop and re-diagnose before changing
   product code.
2. Implement the fix.
3. Re-run the regression test until it passes.
4. Run the focused suites for that layer (table below).
5. At the end of the workstream, run **all** suites the workstream touches,
   including the ASan variants. Fix every regression.
6. Never regenerate goldens or fixtures blindly. Inspect each changed image in both
   themes and each changed fixture line; only the intended change may differ.
7. If a fix cannot be shown failing first, write down why. Add the strongest
   automated guard possible plus manual reproduction steps.
8. Record passed counts and the scope (fakes, fake host, real FFmpeg) in your
   report. The lead copies them into `docs/STATUS.md`.

### 4.4 Suites

| Layer | Command (from the checkout or worktree root, PowerShell 7) |
| --- | --- |
| Versions and generated data | `python -I scripts/etc/Generate-Versions.py --check`; `python -I scripts/etc/Test-Versions.py`; `python -I scripts/etc/Generate-ServiceBuiltins.py --check` |
| Core (C++) | `cmd /d /c scripts\etc\Test-CoreNative.cmd`; `.\scripts\etc\Test-B2.ps1` (argv goldens: `scripts/etc/Generate-CoreGoldens.py`) |
| Engine and transport (real FFmpeg plus the T1 child) | `.\scripts\etc\Test-B4.ps1 -FFmpegPaths <ffmpeg.exe>,<second ffmpeg.exe>`; also with `-Asan` |
| Native adapter, page, editor session (fake host) | `.\scripts\etc\Test-B6.ps1`; also with `-Asan` |
| Actual DLL in fiohost | `.\scripts\etc\Test-VegasEncoder.ps1 -EvidenceDir build\test-results\<fresh> -FFmpegPath …` |
| Older host profiles | `.\scripts\etc\Test-LegacyContainers.ps1 -OutputDir build\test-results\<fresh> -FFmpegPath …`; `.\scripts\etc\Build-OlderVegasTrials.ps1` (read its parameters) |
| Render matrix (new) | `.\scripts\etc\Test-RenderMatrix.ps1 -Quick`; `-Full` before release |
| Services (Dart) | `dart test` in `packages/ve_services` and `packages/ve_core`; `.\scripts\etc\Test-B3Services.ps1`; `.\scripts\etc\Test-B3Repositories.ps1`; `.\scripts\etc\Test-B3Runtime.ps1 -FFmpegPaths …` |
| App | In `app/`: `flutter analyze` and `flutter test` |
| Setup and release inputs | `python -I scripts/etc/Test-Setup.py`; `.\scripts\etc\Test-ReleaseInputs.ps1`; `.\scripts\Build-Release.ps1 -Action Build` |

---

## 5. Lead, Phase 0 (before spawning)

- [ ] **L0.1** All decisions are recorded in section 2. Re-read them; no owner
  questions are needed before spawning. Record the answers at the top
  of this file, replacing the defaults where they differ.
- [ ] **L0.2** Create branch `fix/0.2.1` in the original checkout. Add one line to
  the "Current queue" in `docs/NEXT_AGENT.md` linking to this file.
- [ ] **L0.3 Baseline.** Build and run every suite in 4.4 on unmodified code.
  Record the counts and any failures that already exist, so new failures can be
  told apart.
- [ ] **L0.4 Version bump.**
  - In `version.json`, set `release.version` to `"0.2.1"` and `release.build` to
    `1`. This gives app `0.2.1+1` and Windows file version `0.2.1.1`.
  - Set `core.version` and `core.packageVersion` to `"0.3.1"`, because core
    behaviour changes.
  - Leave `abi`, `schemaMax`, `contracts` and `services.ffmpegParserVersion`
    unchanged. Bumping the parser version would invalidate every user's capability
    cache.
  - Run `python -I scripts/etc/Generate-Versions.py`, then `--check` and
    `python -I scripts/etc/Test-Versions.py`, and
    `python -I scripts/etc/Test-Setup.py`. Confirm the upgrade from 0.2.0.3 is
    accepted and downgrades are still blocked.
- [ ] **L0.6 Portable scripts and a path guard (D7).**
  - **Test first**: add `scripts/etc/Test-NoMachinePaths.py`. It scans committed
    files for drive-letter paths (`[A-Za-z]:\`) and user-profile paths
    (`\Users\<name>`).
    - Allowlisted: test fixture data under `app/test/**` and
      `packages/*/test/**`, generated fixture files, and the historical records
      `docs/product/workstreams/**`, `docs/experiments/**` and `evidence/**`
      (user-profile paths are still flagged there).
    - Its `--scope scripts` mode checks `scripts/**` and `setup/**` only; the
      default mode checks everything.
    - It fails now (the scripts default to paths on the `L:` drive, and docs
      name the checkout's location and user name).
  - **Fix the scripts**: replace every `L:` drive default (Flutter, Dart, vcvars,
    FFmpeg) with this lookup order: parameter, then environment variable
    (`VEGAS_ENCODER_FLUTTER`; the existing `VEGAS_ENCODER_VCVARS` and
    `VEGAS_ENCODER_PYTHON`; new `VEGAS_ENCODER_FFMPEG`), then `PATH`. For MSVC,
    finally try `vswhere.exe` under `%ProgramFiles(x86)%`. If nothing is found,
    fail with a clear message naming the variable to set.
  - Scripts that resolve the repo root keep using their own location
    (`$PSScriptRoot`, `%~dp0`).
  - Run `Test-NoMachinePaths.py --scope scripts`, and run each changed script
    once with the environment variables set.
  - Docs are cleaned in L4; the full-scope check runs in L5.
- [ ] **L0.5** Commit Phase 0, including this plan with the decisions filled in, if
  the owner allows commits. Create the worktrees (1.3) and spawn A, B and C (1.4).

---

## 6. Workstream A: native exporter and engine

Each item lists **Problem**, **Where**, **Test first**, **Fix**, **Verify**. Line
numbers are from the review snapshot and may drift. Build T1 and T2 first.

### A1. Audio queue deadlock (the real cause of the AV1 "stall")

- **Problem**
  - `render.cpp` `DoEncode` submits one video frame and then that frame's audio,
    on one thread.
  - `FfmpegEncoder::Submit` (`encode.cpp`, around line 402) caps the audio queue at
    **128 blocks** and 2 MiB. That is about one block per frame, so about 128
    frames.
  - FFmpeg stops reading audio while the video encoder hasn't produced output yet.
    If the encoder's delay is longer than about 140 frames, Render blocks on audio,
    stops feeding video, and everything waits until the 10 s timeout.
  - The owner's logs show **145 frames submitted** on both VEGAS 2026 and Sony 13.
- **Where**: `src/engine/encode.{h,cpp}`, `src/engine/recipe_job.{h,cpp}`,
  `src/vegas/adapter/render.cpp`.
- **Test first**
  - [ ] T1 `latency:300`: 320×180, 30000/1001, 600 frames, audio, test pipe
    timeout 3000 ms, expecting success. **Fails now** at about 130 to 145 frames.
  - [ ] Real FFmpeg, run by hand and recorded: the AV1 (CPU) recipe **without**
    `-svtav1-params`, at 1920×1080, 29.97 fps, ≥ 900 frames, with audio, on build
    `N-128435…`, for both `p010le` and `bgr0`. Also libx264 with
    `-x264-params rc-lookahead=250`, 600 frames. Expect a failure before the fix.
- **Fix**
  - [ ] Size the audio queue by time: bytes per second × 60 s (computed from
    `media`; about 23 MB for 48 kHz stereo float). Raise the audio block cap (for
    example to 4096). Leave the video limits (8 frames, 64 MiB) unchanged.
  - [ ] Write the C6 `transport` object (contract 3.1) and log a one-line summary.
- **Verify**
  - Update the `audioHighWater <= 2 MiB` assertion in `recipe_jobs.cpp` and the
    budget comment in `Test-B4.ps1`. Keep the 160 MiB working-set budget.
  - Run Test-B4 (with and without `-Asan`), Test-B6 and the render matrix
    `-Quick`.
  - Report the real-FFmpeg AV1 results to the lead; L2 depends on them.

### A2. Projects that aren't 48 kHz stereo always fail (from review 2)

- **Problem**
  - The starters leave the template's audio at zero, meaning "same as the project"
    (`sfio_abi.h`: `audioRender … zero = project`).
  - `ConformTemplate` and `ConformTemplateToSource` (`plugin.cpp`, around lines
    542–546 and 610–614) copy the **project's** sample rate and channel count into
    it.
  - `DoEncode` (`render.cpp`, around lines 569–571) then rejects anything that
    isn't float32, 48 kHz and stereo, with "fixed FFmpeg profile requires float32
    stereo at 48000 Hz".
  - That check is outside the `#if defined(VEGAS_ENCODER_B6_RECIPE_PROOF)` guard,
    so it runs in the product build.
  - It even fails presets with **audio turned off**, because VEGAS still supplies
    the audio stream (`GetAllowedStreamTypes` returns both streams).
  - The core, the engine (`Endpoint` and `media.audio`) and the app's Audio panel
    already handle any rate and channel count.
- **Test first** (T2 audio options, B6 `recipe_render.cpp`, and a T3 matrix row).
  Each fails now:
  - [ ] 44.1 kHz stereo project with an AAC preset: success, output at the
    preset's or the source rate, exact sample count.
  - [ ] 48 kHz mono project: success, 1 channel.
  - [ ] 48 kHz 5.1 project with AAC or Opus: success, 6 channels.
  - [ ] 44.1 kHz project with a video-only preset (audio turned off): success, no
    audio stream.
- **Fix**
  - [ ] In the recipe build, move the fixed 48 kHz stereo check into the
    fixed-profile `#else` branch.
  - [ ] For recipe renders, accept float32 audio where `blockAlign == 4 × channels`,
    the rate is 1 to 768000 and channels are 1 to 64 (the core's limits). Reject
    anything else with a precise message.
  - [ ] When the recipe has audio turned off, ignore the audio stream entirely: no
    format check and no reads.
  - [ ] Check how FFmpeg infers the channel layout for 3 or more channels from raw
    `f32le` input. If needed, have the core emit an explicit channel layout; that
    change goes to B through the lead.
- **Verify**: Test-B6, fiohost, matrix `-Quick` (44.1 kHz rows) and the
  legacy-profile suites. Add owner checks to L6: a 44.1 kHz project, a mono
  project, and a 5.1 channel-order test using a test-tone project where each
  channel can be identified.

### A3. Replace fixed timeouts with "no progress" detection

- **Problem**: any single pipe write or queue wait over 10 s fails the render
  (`Impl::Complete`, `Submit`). Finalization has a fixed 120 s limit (`Finish`). So
  slow but healthy encodes fail, sometimes at the very end of a long render.
- **Test first** (T1, using short test timeouts)
  - [ ] `slow-read:4000` with stall timeout 3000 ms and advancing progress:
    success. Fails now.
  - [ ] `slow-flush:<2 × old finish timeout>` with advancing progress: success.
    Fails now.
  - [ ] `stall-after:30` and `hang-flush`: fail with "FFmpeg stopped making
    progress for N s" within the stall timeout plus 1 s.
  - [ ] Blocked cancellation still under 3 s.
- **Fix**
  - [ ] Keep an atomic "last activity" timestamp. Update it whenever a pipe write
    completes with bytes, or the progress parser sees `frame`, `out_time_us` or
    `total_size` increase.
  - [ ] Fail only after `StallTimeoutMs` with no activity. Use a separate
    `ConnectTimeoutMs` for `ConnectNamedPipe`. INI keys per contract 3.5.
  - [ ] Write a clear message, including the last frame number.

### A4. Re-rendering over an existing file (decision D1)

- **Problem**
  - `FfmpegEncoder::StartImpl` refuses any existing destination (`encode.cpp`,
    around lines 252–254), and `Publish` never replaces a file (around line 456).
  - So re-rendering to the same name always fails, with "(prototype refuses
    overwrite)". The owner's 2026 trial confirmed this.
- **Owner check first** (through the lead): on VEGAS 2026.0.3.189, does Render As
  ask before replacing an existing file?
- **Test first**
  - [ ] recipe_jobs `preexisting-confirmed`: success, content replaced,
    `replacedExisting: true`. Fails now.
  - [ ] Keep the `collision` case: a file created during the render is preserved,
    now with the partial retained and a clear message.
  - [ ] `preexisting-locked`: a clean failure, the original intact, a clear message.
  - [ ] B6 legacy auto-name test with `out.mp4` already existing: expect
    `out (2).mp4`, with `outputPath` set to the actual file and
    `requestedOutputPath` set (contract 3.1). Fails now.
  - [ ] fiohost actual DLL, modern mode: render twice to the same path; the second
    render succeeds. Fails now.
- **Fix**
  - [ ] In `Start`, record the existing file's identity (volume serial, file index,
    size, modified time) instead of failing.
  - [ ] In `Publish`, replace the file only if it still has that identity
    (`ReplaceFileW`, or `MoveFileExW` with `REPLACE_EXISTING | WRITE_THROUGH`).
    Otherwise keep refusing, retain the partial and report its path.
  - [ ] Choose the policy by naming mode: `SetFile` knows when the resolved path
    differs from the requested one.
  - [ ] Remove the "prototype" wording.

### A5. Failures before encoding starts leave no explanation (from review 2, decision D9)

- **Problem**
  - `RecipeJob` (which writes the progress window status and the History record)
    starts only after the preflight check, frame 0 and `LoadRecipeRuntime()`.
  - Anything that fails earlier writes nothing, and the error message box is
    compiled out in the recipe build. The user sees only VEGAS's generic HRESULT
    dialog, with no History entry and no progress window.
  - Affected failures:
    - filename suffix mismatch (`N-OUTPUT-SUFFIX`);
    - missing default FFmpeg or a stale capability cache;
    - the audio format check (A2);
    - frame layout and non-square pixels (A9);
    - unsupported frame rates (A8);
    - early `RecipeJob::Start` returns.
- **Test first** (B6 `recipe_render.cpp`): each case above produces a C6 record
  with `stage: "preflight"`, the precise reason and a terminal live file (contracts
  3.1 and 3.2). Each fails now (no record).
- **Fix**
  - [ ] Separate "where the jobs folder is" from `LoadRecipeRuntime`, so it works
    even when `machine.json` is missing or invalid.
  - [ ] Load the runtime **before** fetching frame 0, so a missing FFmpeg fails
    fast.
  - [ ] Add a preflight-failure path that writes the record and live file through
    `JobStore` (asynchronous, so Render never waits).
  - [ ] Launch the progress window when enabled and the app is the matching
    version. Nothing on the Render thread waits for it.

### A6. Readable FFmpeg error messages (engine part; B1 adds `-nostats`)

- **Problem**: `EncoderFailureMessage` and `Tail` (`recipe_job.cpp`) split on `\n`
  only, so `\r`-separated stats lines bury mid-render errors.
- **Test first**
  - [ ] `PureChecks`: `EncoderFailureMessage` on
    `"frame=  1 …\rframe= 20 …\r[vost#0:0/libx264 @ 0x1] Error submitting video frame to the encoder\nConversion failed!\n"`
    returns `"FFmpeg: Error submitting video frame to the encoder"`. Fails now.
  - [ ] T1 `stats-then-error`: the C6 `message` is that line, and `stderrTail`
    contains no stats lines.
- **Fix**: [ ] split on both `\r` and `\n`; drop FFmpeg stats lines before choosing
  the message and before saving `stderrTail`.

### A7. FFmpeg exiting early (engine part; B2 adds lint, decision D4)

- **Decision D4**: length-limiting options are allowed, so FFmpeg may legitimately
  finish before VEGAS has sent every frame.
- **Test first** (each fails now with "FFmpeg exited before input EOF" or a pipe
  write error):
  - [ ] T1 `early-exit-ok` after end of input: success.
  - [ ] A new T1 mode, `early-exit-mid:<frames>`, which reads N frames, writes its
    output and exits 0 (like `-t`): the render succeeds; VEGAS frame fetching stops
    soon after; the output is verified and published; C6 has `endedEarly: true`.
  - [ ] The same mode with exit code 1: still a failure.
- **Fix**
  - [ ] When FFmpeg exits with code 0 and its output file is non-empty, treat the
    resulting broken pipe and early exit as "finished early", not failure.
  - [ ] Stop fetching frames and audio from VEGAS. Skip the remaining submits. Run
    verification and publishing as normal, and return success.
  - [ ] Set `endedEarly` in C6, and show "FFmpeg finished early because of an option
    in the command" in the live status message.
  - [ ] Any other early exit stays a failure.
- **Owner real-host check**: VEGAS accepts a successful Render return before every
  frame was fetched (L6).

### A8. Support more frame rates

- **Test first**
  - [ ] Unit: `EncodeRate::FromDouble` gives 48000/1001 for 47.952…, 25/2 for
    12.5, and 240000/1001 for 239.76…. Fails now.
  - [ ] Engine case at 48000/1001 with exact audio sample totals.
- **Fix**: [ ] accept exact matches (within 1e-8) for denominator 1 (1 to 240),
  denominator 2, and n/1001 where n = 1000×k (k ≤ 240). Keep refusing everything
  else, with a message naming the rate.

### A9. Clear error for non-square pixel projects (decision D6)

- **Problem**: the combined frame-layout check (`render.cpp`, around line 655)
  already requires pixel aspect 1.0, so the specific check (around lines 676–679)
  is unreachable. Users see "unsupported video frame layout, memory token or aspect
  ratio".
- **Test first**: [ ] T2 `pixelAspect` 1.2121 in B6. Assert the new message, and
  that a preflight record is written (A5). Fails now.
- **Fix**: [ ] check pixel aspect first, with "This project uses non-square pixels
  (pixel aspect 1.2121). Vegas Encoder renders square-pixel projects only. Set the
  pixel aspect ratio to 1.0000." Remove the dead check.

### A10. Keep known hardware failures (from review 2, decision D8)

- **Problem**: `LoadRecipeRuntime` (`recipe_runtime.cpp`, around lines 131–137)
  rewrites the availability of **every** cached hardware encoder to "unknown",
  including "failed". So a render with an encoder that failed its test on this PC
  proceeds and fails later inside FFmpeg.
  - The "missing" part of review 2's claim doesn't apply: encoders not listed by
    FFmpeg aren't in the cache map at all.
- **Test first** (each fails now):
  - [ ] A capability cache with `h264_nvenc` marked failed, plus a T1 child that
    exits at start with an NVENC-style error: the render is attempted, not blocked.
    The C6 message contains the FFmpeg error **and** says the encoder also failed
    its last test on this PC, suggesting a re-test on the FFmpeg page or another
    encoder.
  - [ ] Same cache with a child that succeeds: the render succeeds normally.
- **Fix**
  - [ ] Keep the downgrade to a warning for both "ok" and "failed", so nothing is
    blocked.
  - [ ] Remember which encoders were marked failed, with the date and reason, and
    add that context to the failure message when FFmpeg fails.
  - [ ] The exporter never writes the capability cache; the app owns it.

### A11. Reuse frame buffers (performance; includes review 2's whole-plane copy)

- **Problem**: each frame does `owned.resize(packed)`, which allocates and
  zero-fills about 6 MB at 1080p (about 25 MB at 4K) and then frees it, on the
  Render thread. Rows are copied one at a time even when the stride equals the row
  width.
- **Test first**: [ ] assert at most 12 buffer allocations for a 300-frame render,
  using a test-visible counter. Fails now (300). Record throughput before and
  after; don't gate on it.
- **Fix**
  - [ ] Pipe writers hand finished buffers back to a bounded free list (at most
    queue depth + 2). Ownership passes by move only.
  - [ ] When `planes[0] == row`, copy the luma plane in one `memcpy`; do the same
    for chroma when `planes[2] == row`.
- **Verify**: ASan suites. Lossless FFV1 `framemd5` must be identical before and
  after.

### A12. Fewer host progress calls per frame (performance)

- **Test first**: [ ] using the T2 counter, at most 2 progress-call pairs per frame
  on an unblocked render. Fails now (3 to 4).
- **Fix**: [ ] poll once per frame at the top of the loop. Inside `Submit`, poll
  only while waiting, at least every 100 ms. Remove the per-audio-chunk poll.
- **Verify**: keep `maxPollGap < 250 ms` and blocked cancellation under 3 s. Do not
  request the deferred real-host performance comparison.

### A13. Cache FFmpeg and FFprobe hashing per VEGAS session (performance)

- **Test first**: [ ] two renders in a row: the second one doesn't re-hash `ffmpeg`,
  `ffprobe` or the DLLs (hash-call counter). Rewriting the file between renders
  re-hashes it and refuses with "Selected FFmpeg identity changed". Fails now.
- **Fix**: [ ] keep an in-process cache keyed by path, volume serial, file index,
  size and last-write time. The first render in each session still hashes in full.
- Not changing, per review 2: hashing the plug-in DLL once at log open, and
  flushing the log after each line. Both happen rarely and keep logs intact after
  a crash.

### A14. Don't force live status writes to disk (performance)

- **Fix**: [ ] `job_store.cpp` `Atomic()` gets a durable flag. Live status writes
  skip `FlushFileBuffers` and write-through; records and the index stay durable.
- **Test**: this can't be shown failing first. Existing tests must pass; explain
  the reasoning in your report.

### A15. Progress window placement

- **Test first**: [ ] a pure window-choice function with an injected window list:
  when the foreground window belongs to another process, choose this process's
  visible, unowned, largest top-level window. Fails now.
- **Fix**: [ ] in `LoadRecipeRuntime`, use the foreground window when it belongs to
  this process, otherwise enumerate. No `SendMessage`-based calls (such as
  `GetWindowText`) on the Render thread.

### A16. Plug-in log retention: dropped (decision D5)

Don't implement.

### A17. Long paths (from review 2)

- **Problem**: `ModuleDir`, `LoadConfig`, `OpenLogLocked` and `ModulePath`
  (`diagnostics.cpp`) use fixed `MAX_PATH` buffers. `IsLegacyHost` and
  `LegacyTemplateAllocator::Acquire` (`plugin.cpp`) depend on them.
- **Test first**: [ ] unit-test a helper with a tiny starting buffer: it grows on
  `ERROR_INSUFFICIENT_BUFFER` up to 32768 and returns the full path. Fails now
  (no helper).
- **Fix**: [ ] use that helper for module paths, and sized calls for environment
  variables.

### A18. Job timestamps never go backwards (from review 2)

- **Test first**: [ ] with an injectable clock that steps back 5 ms between start
  and end, the record's `endedAt` is ≥ `startedAt`. Fails now.
- **Fix**: [ ] clamp `endedAt` to at least `startedAt` (`job_store.cpp`
  `JobUtcNow` callers, `RecipeJob::Complete`).

### A19. Compile the cache-key regex once (micro)

- [ ] `recipe_runtime.cpp` line 120 builds `std::regex("[A-Fa-f0-9]{64}")` on every
  call. Replace it with a simple character check. No failing test is needed; keep
  the existing coverage of invalid keys.

**End of workstream A**: Test-B4 (with and without `-Asan`), Test-B6 (with and
without `-Asan`), Test-VegasEncoder, Test-LegacyContainers with FFmpeg,
`Build-OlderVegasTrials`, `Test-RenderMatrix -Quick`. Report every count.

---

## 7. Workstream B: C++ core and VEGAS template page

### B1. Add `-nostats` (core part of readable errors)

- **Test first**: [ ] core test: generated argv contains `-nostats`, and progress
  still uses `-progress pipe:1`. Fails now.
- **Fix**: [ ] add `-nostats` to the generated global options (`compile.cpp`,
  around line 441).
- **Churn**: regenerate the argv goldens (`scripts/etc/Generate-CoreGoldens.py`,
  which writes `packages/ve_core/test/b1_argv.dart` and
  `schema/fixtures/b1/core-argv.json`), and update any C++ test that asserts the
  command line.
  - **Do not touch** app goldens or Dart service fixtures; that is L3.
  - Do not regenerate the B0 design fixtures.

### B2. Lint length-limiting options (decision D4)

- **Test first**: [ ] `L-DURATION-LIMIT`, `V-EXTRA-DURATION`, `L-SHORTEST` and
  `V-EXTRA-SHORTEST` **warnings** (never errors), for every listed option (contract
  3.4), with correct UTF-16 ranges. Each fails now.
- **Fix**: [ ] add the rules to `lint.cpp`, and to validate for Basic Extra
  arguments. Message: "This option can stop the render before the end of the VEGAS
  timeline. The output will be shorter."

### B3. Lint external file and network access (decision D3)

- **Test first**: [ ] `L-NETWORK`, `V-EXTRA-NETWORK`, `L-FILE-ACCESS` and
  `V-EXTRA-FILE` for each pattern in contract 3.4. The existing `L-INPUT` and
  `L-OUTPUTS` stay. Add negative cases: ordinary filters, and `-metadata` values
  containing `:`, are not flagged. Each positive case fails now.
- **Fix**: [ ] add the detection in `src/core` lint and validate only.

### B4. Make Extra-argument scanning consistent (from review 2)

- **Problem**: four places pair an option with its value in Extra-argument text,
  and they disagree:
  - `InputColorTags`, `Extra()`, `ReadStream` and `ResizeAlignment` in
    `compile.cpp`, and the pairing loop in `Validate()` in `recipe.cpp`;
  - lint treats a quoted word starting with `-` as a value; the others treat it as
    an option;
  - `OptionKey` drops stream specifiers, so `-b:a 128k` in **Video** Extra
    arguments removes the generated `-b:v`;
  - `-profile:a …` in Video Extra arguments rewrites the reflected video profile,
    which can cause a false profile error or a wrong summary;
  - `ResizeAlignment` also reads Audio Extra arguments and doesn't skip values,
    unlike `ReadStream`.
  - Review 2's example `comment="-profile"` doesn't trigger this (it tokenizes as
    one non-option word); the cases above do.
- **Test first** (each fails now):
  - [ ] `-b:a 128k` in Video Extra arguments leaves the generated `-b:v` in place,
    nothing is marked overridden, and `V-EXTRA-WRONG-STREAM` warns.
  - [ ] `-profile:a aac_low` in Video Extra arguments doesn't change the resolved
    video profile.
  - [ ] `-flags "-global_header"` in Video Extra arguments is an option with a
    value, nothing is marked overridden, and lint and compile agree.
  - [ ] `-pix_fmt yuv444p` in Audio Extra arguments: `ReadStream` and
    `ResizeAlignment` agree (both conservative/unknown, giving 2×2 alignment), and
    lint warns that it is a video option in Audio Extra arguments.
- **Fix**
  - [ ] Add one helper that returns option/value pairs for a stream's Extra text.
    Quoted words are always values. It understands stream specifiers (`:v`, `:a`,
    `:v:0` and so on). Use it everywhere.
  - [ ] Options aimed at the other stream don't override or reflect anything for
    this stream.
  - [ ] Optional: accept unquoted `-flag` values after options whose type (from
    the capabilities) is a flags option.

### B5. Core per-compile cost (from review 2; performance)

- **Problem**
  - `CompileInternal` runs `Structural(r)` twice (inside `Validate`, then again at
    around line 434).
  - `Estimate` runs `Structural`, a full `Compile`, then `Resolve` again.
  - `SchemaCheck` builds a `std::regex` per call (`recipe.cpp`, line 57).
  - `payload.cpp` line 35 builds `std::regex("[0-9]+")` per call.
- **Measure first**: [ ] a core micro-benchmark (for example 1,000 compiles of each
  built-in, in `tests/core`). Record before and after; the goal is a clear drop,
  not a hard gate.
- **Fix**
  - [ ] Reuse one `Structural` result per call.
  - [ ] Let `Estimate` reuse the resolved values from its compile.
  - [ ] Replace both regexes with a static cache keyed by pattern, or character
    checks.
- **Verify**: all core tests, unchanged argv goldens (apart from B1), Test-B2.

### B6. Frame-rate rationals in the core (support for A8)

- [ ] Core tests: `CheckMedia` and compile accept 48000/1001, 25/2 and 240000/1001,
  and emit the right `-r`. If they already pass, keep them as guards and say so.

### B7. Frozen template editor: dropped (decision D2)

The owner chose to keep the current behaviour: if the editor hangs, the user ends
it in Task Manager. Don't implement a watchdog.

### B8. Session folder left behind after cancelling the editor

- **Problem**: on cancel, the transport's destructor kills the editor but checks
  whether it has exited immediately. Termination hasn't finished yet, so the
  session folder (including `request.json`, which holds the preset) is left
  behind (`editor_session.cpp`, around lines 155–164).
- **Test first**: [ ] using T4 `cancel-hold`, cancelling during an active session
  removes the folder within 6 s. Fails now.
- **Fix**: [ ] in `EditorSessionTask::Worker` (a worker thread, so it may block):
  after cancelling, wait up to 5 s for the process, then clean up. Don't add a
  sweep of old folders (decision D5).

### B9. VEGAS isn't brought back to the front after a rejected Apply (from review 2)

- **Problem**: in `PollEditor`, if `validateRecipe` throws, the catch path calls
  `EndEditor()`, which calls `RestoreOwner()` without returning focus. The dialog
  is re-enabled but may stay behind other windows.
- **Test first**: [ ] T4 `invalid-apply` with the editor in the foreground: through
  a test hook, `RestoreOwner` is called with foreground return requested, and the
  status explains that the changes were rejected. Fails now.
- **Fix**: [ ] work out `returnForeground` before validating, and pass it on the
  failure path too. Use the "Editor changes were rejected" status, not "Editor
  session failed".

**End of workstream B**: Test-CoreNative, Test-B2, Test-B6 (with and without
`-Asan`), `Generate-CoreGoldens.py` freshness. Report every count, and list the
app goldens and Dart fixtures that `-nostats` will affect, for L3.

---

## 8. Workstream C: Dart services and Flutter app

### C1. FFmpeg page: can't select the older installation after adding one (owner-reported)

- **Symptom**: after **Add FFmpeg…** adds a second installation, clicking the older
  card does nothing. Clicking away and coming back makes selection work.
- **Status**: the root cause was not found by reading the code. Reproduce first.
- **Step 1: reproduce on the real desktop app** (two real FFmpeg builds,
  `VEGAS_ENCODER_DATA_ROOT` pointed at an isolated folder). Record each answer:
  - [ ] Does it happen when the Open dialog is closed by double-clicking, by
    clicking **Open**, or both?
  - [ ] Only while the new card shows its progress bar, or afterwards too?
  - [ ] Does hover work on the old card? Do its buttons work? Does Tab plus Enter
    select it?
  - [ ] Does Presets → **Import…** (the same `pickFile` dialog) leave the preset
    list unclickable?
  - [ ] In profile mode with DevTools, are UI frames long while the page is open?
    See C6: discovery parses each installation's full capability cache every
    second on the UI isolate.
  - [ ] Add temporary debug prints in `InstallationCard` (`onTapDown`, `onTap`) and
    `FFmpegController.select`, to tell whether the click never arrives or arrives
    and is overwritten.
- **Step 2: regression test first**, in `app/test/widget/ffmpeg_page_test.dart`:
  - [ ] Start with one default installation. Add FFmpeg… with the fake picker: the
    new card is selected.
  - [ ] While a Completer-gated fake probe is still running, tap the old card: it
    is selected and the capability pane shows it.
  - [ ] Complete the probe: the old card stays selected. Tapping between the two
    cards keeps working.
  - [ ] Repeat with discovery emitting the new card before, and then after, `add()`
    returns.
  - [ ] Add light and dark goldens for the two-card selected state.
  - If the widget test passes while the manual repro fails, the cause is native or
    timing. Add the strongest guard possible (for example `WindowProbe.cs` driving
    the real window with `SendInput`) and document manual steps.
- **Step 3: candidate causes, in order**
  1. **Pointer state left behind by the native Open dialog.** `IFileDialog::Show`
     runs synchronously inside the platform-channel handler (`flutter_window.cpp`,
     `file_dialog.cpp`). A double-click that closes the dialog can leave a stray
     mouse-up in the Flutter view. Fixes to evaluate:
     - show the dialog from a posted message and reply asynchronously;
     - discard pending mouse messages after it closes.
  2. **Selection overwritten**: `add()` calls `select(new)` after discovery
     returns. Fix: auto-select only if the user hasn't selected anything since
     `add` started.
  3. **Element churn during a tap**: probe progress rebuilds the whole page, and
     `_CardStrip` wraps the keyed cards in **unkeyed** `SizedBox`es. Fix: key the
     wrappers, and narrow the rebuilds.
  4. **UI isolate overload** from the polling described in C6.
- [ ] Fix every confirmed cause. Remove the debug prints.

### C2. Deleting a preset blocks its ID (includes case-only clashes)

- **Problem**
  - `FilePresetLibrary.delete` keeps `.history/<id>/`.
  - `save` refuses an ID with retained history.
  - The app's `uniqueId` (`app/lib/state/presets.dart`, around lines 410–419) only
    checks current presets, and compares case-sensitively.
- **Test first** (each fails now):
  - [ ] repositories_test: save, delete, then `availableId` returns a different ID.
  - [ ] presets_controller_test: import, delete, import again succeeds.
  - [ ] An existing `My-Preset.vepreset` plus a new preset named "my preset" gives
    `my-preset-2`.
  - [ ] Update `FakePresetLibrary` to model retained history, and add a test that
    the fake and file libraries agree.
- **Fix**
  - [ ] Implement `availableId` (contract 3.3).
  - [ ] Use it in `createNew`, `_create`, `createFromJob`, `importShareString`,
    `importFile` and the popup's Save as new (`app/lib/state/popup.dart`).
  - [ ] Keep the history-protection rule in `save`.

### C3. Starring or pinning a preset shows "Library has revision N"

- **Problem**: `setPreferences` bumps a user preset's revision and writes history.
  The popup's `libraryNewer` (`popup.dart`, around lines 148–151) compares revision
  numbers only.
- **Test first** (each fails now):
  - [ ] Starring leaves the revision unchanged and adds no history file.
  - [ ] Template origin at revision N, library at N+1 with an identical recipe: the
    origin state is not `libraryNewer`.
  - [ ] An old `.vepreset` with `"favorite": true` still shows as starred.
- **Fix**
  - [ ] Store the flags in the preferences overlay (contract 3.3).
  - [ ] `libraryNewer` requires a newer revision **and** a non-empty core diff when
    the template carries its base.

### C4. One bad file or line empties the library or History

- **Test first** (each fails now):
  - [ ] Library with one valid, one malformed and one badly named
    (`My preset (1).vepreset`) file: the valid preset is listed, plus 2 problems.
  - [ ] Job index with one malformed line, and one `\r`-only line from a CRLF edit:
    the other entries are listed; the malformed line is counted and the `\r` line
    ignored.
  - [ ] Widget tests and **light and dark** goldens for the library banner ("1
    preset file couldn't be read: … Show in folder") and the History banner (with
    **Rebuild index**).
- **Fix**
  - [ ] Catch errors per file in `_readList`, and per line in
    `FileJobRepository.list`. Trim `\r` from lines.
  - [ ] A user file that shadows a built-in becomes a problem, not a crash.
  - [ ] Expose problems as in contract 3.3.

### C5. History reading cost (performance; includes review 2's lexer fixes)

- **Problem**
  - History re-reads the whole `jobs.jsonl` 4 times a second, building lines byte
    by byte (`job_files.dart` `_completeLines`).
  - `decodeJson` (`storage.dart`, around lines 91–148) constructs regexes per
    character and per integer token, parses `BigInt` bounds every time, and runs
    `jsonDecode` on every object key.
- **Test first**: [ ] with a 5,000-line index, a second `list()` on an unchanged
  file performs no read (counting hook). Fails now. Add budgets: a full parse in
  under 200 ms, an appended line visible on the next tick, and a 300 KB capability
  file parsed under a recorded budget, before and after.
- **Fix**
  - [ ] Cache size and modified time, and return the identical list when unchanged.
  - [ ] When the file has grown, parse only the appended bytes; reparse fully if it
    shrank.
  - [ ] Split chunks with `indexOf(10)`.
  - [ ] In `decodeJson`, hoist the regexes and `BigInt` bounds to top-level finals
    (or use character checks). Read keys without escapes with `substring`, without
    `jsonDecode`.

### C6. Background polling while the app is idle (from review 2; performance)

- **Problem** (verified):
  - `discoveredInstallationsProvider` (watched by the FFmpeg page and the setup
    wizard) polls `WindowsFFmpegDiscovery.list()` **every second**. For each
    installation, `GpuAwareCapabilityCache.read` re-reads and parses the full
    capability cache JSON (hundreds of KB) on the UI isolate. It also calls
    `WindowsGpuIdentity.read()`, which **starts a new isolate** and queries DXGI
    each time.
  - `FileMachineSettingsRepository.watch()` re-reads and parses `machine.json` 4
    times a second without checking whether the file changed.
  - `readLibraryDirectoryMetadata` allocates and zero-fills a 1 MiB native buffer 4
    times a second.
- **Test first** (counters through fakes or hooks; each fails now):
  - [ ] Over 5 discovery ticks with nothing changed: GPU reads ≤ 1, capability-file
    parses 0 after the first, `machine.json` parses 0 after the first.
- **Fix**
  - [ ] Cache the GPU snapshot (60 s lifetime). Invalidate it when a hardware test
    or probe runs, or on explicit Scan or Refresh.
  - [ ] Stamp caches (size plus modified time) in `FileMachineSettingsRepository`
    and `FileCapabilityCache`, returning the identical object when unchanged.
  - [ ] Reuse the native metadata buffer (allocate once per library instance; no
    zero-fill).
- **Verify**: library_watch_test, ffmpeg_services_test, repositories_test, the app
  suite. Record idle CPU use of the desktop app on the FFmpeg page before and after
  (manual, recorded).

### C7. Job retention: dropped (decision D5)

Don't implement.

### C8. Advanced mode compiles too often per keystroke (performance)

- **Problem**
  - `compilePreview` always compiles twice in Advanced mode, because the first
    attempt has no extension (`editor.dart`, around lines 47–69).
  - Lint, the "as Basic" compile, completion and `_describe` add more calls
    (`advanced_workspace.dart`, around lines 97–116). There is no debounce.
- **Measure first**: [ ] record keystroke cost with `app/tool/budgets` (budget
  4 ms).
- **Test first**: [ ] a counting `VeCore` spy: one keystroke causes at most 1
  compile and 1 lint, plus 1 completion when the caret asks. Fails now.
- **Fix**
  - [ ] Remember the last `outputExtension` per recipe and template.
  - [ ] Make `_describe` and `editorProvider` use identical `paths`.
  - [ ] Compute the `basic` compile lazily.
  - [ ] Debounce lint only if it's still over budget.
- **Report** the measured figure, so the lead can replace the stale text in
  `SYSTEM_OVERVIEW.md`.

### C9. Warning for imported presets that touch outside files or the network (decision D3)

- **Test first**: [ ] widget test: importing a share string whose recipe triggers
  any issue in the external-access set (contract 3.4) shows a confirmation dialog
  listing them. Cancel imports nothing; Import keeps the warning visible in the
  editor and library row. Add light and dark goldens.
  - Until B's core is merged, use fakes (an issue list injected by the test).
  - The lead re-runs this against the real core in L1.
- **Fix**: [ ] add the dialog and persistent warning to imports from share strings,
  files and History.

### C10. FFmpeg probe timeouts

- **Problem**: every probe call uses the 10 s default (`process_runner.dart`,
  around line 147).
- **Test first**: [ ] a fake runner records the timeout passed to each call. Fails
  now (all 10 s).
- **Fix**: [ ] identity and `-version`: 30 s. Lists and `-h full`: 60 s. Encoder
  and filter help: 30 s. Hardware tests keep their own timeouts.

### C11. Reading the new job record fields

- **Test first** (each fails now):
  - [ ] `decodeJob` accepts records with `stage`, `requestedOutputPath`,
    `replacedExisting` and `transport` (contract 3.1).
  - [ ] It accepts preflight records with null `media` and `ffmpeg`.
  - [ ] It accepts a record whose `endedAt` is 5 ms before `startedAt`, showing
    elapsed time as unknown instead of rejecting it.
  - [ ] Old records still pass. Use JSON fixtures written from the contract.
- **Fix**: [ ] update `storage_validation.dart`, the models and
  `engine_records_test.dart`.

### C12. Open dialog shows "Programs (*.exe)" when importing presets (from review 2)

- **Problem**: `ShowOpenFileDialog` always adds a `Programs (*.exe)` filter
  (`app/windows/runner/file_dialog.cpp`, around lines 78–86).
- **Test first**: [ ] the Dart side passes an explicit list of filters through the
  window channel. A fake window-controller test asserts that preset import sends
  only `*.vepreset`, and the FFmpeg picker sends `ffmpeg.exe` plus `*.exe`. Fails
  now.
- **Fix**: [ ] the runner builds its filter list from the channel arguments. Check
  both dialogs by hand.

### C13. Closing with unsaved drafts skips the "can't render with this FFmpeg" warning (from review 2)

- **Problem**: `DesktopShell._onExitGuarded` passes `const []` as the compiled
  issues to `saveErrors` (`desktop_shell.dart`, around line 204). So
  FFmpeg-specific errors never produce the "Save anyway / Cancel" warning when
  saving on exit.
- **Test first**: [ ] widget test: a draft with an FFmpeg-specific error; close the
  window and choose Save. The warning appears, and Cancel keeps the window open.
  Fails now.
- **Fix**: [ ] compile each draft against the selected installation's capabilities
  (the same path the editor uses: `compileSample`, `capabilitiesFor`), and pass its
  issues.

### C14. Progress window closes the instant the pointer leaves near the end of the countdown (from review 2)

- **Problem**: hovering pauses the countdown at its current value. If that was 1 s,
  the next tick after the pointer leaves closes the window at once
  (`monitor_window.dart`, around lines 85–93).
- **Test first**: [ ] widget test with fake time: done, then hover at 1 s left, then
  leave. The window stays open for at least 3 s. Fails now.
- **Fix**: [ ] when the pointer leaves, set the countdown to at least 3 s. Check
  what UI_SPEC §12 says. Update goldens if the text changes.

### C15. Show the new facts in History and the progress window

- **Test first**: [ ] widget tests and **light and dark** goldens. Each fails now:
  - a preflight failure record (`stage: "preflight"`) shows its reason in History
    and the progress window;
  - a legacy `name (2).ext` output shows the actual path, with the requested path
    as secondary text;
  - a replaced file shows that it replaced an existing file.
- **Fix**: [ ] update `job_detail.dart`, `job_list.dart` and the monitor display.

### C16. Pop-up warning for length-limiting options (decision D4)

- **Test first** (widget tests plus **light and dark** goldens; each fails now):
  - [ ] Saving a preset, or applying in the VEGAS popup, when the recipe has a
    `L-DURATION-LIMIT`, `V-EXTRA-DURATION`, `L-SHORTEST` or `V-EXTRA-SHORTEST`
    warning shows a dialog: "This preset can stop the render before the end of
    the timeline (`-t 5`). The output will be shorter." with **Save anyway** and
    **Cancel**.
  - [ ] Cancel keeps editing. Save anyway saves.
  - [ ] Recipes without these options show no dialog.
  - Use injected issues until B's core is merged; the lead re-runs the tests with
    the real core in L1.
- **Fix**: [ ] add the check to the save path (`presets_page.dart`, `save_check.dart`)
  and the popup's Apply path. The warning also stays visible in Checks.

**End of workstream C**: `dart test` in both packages, Test-B3Services,
Test-B3Repositories, Test-B3Runtime with FFmpeg, `flutter analyze` and
`flutter test` in `app/`. Report every count, and list every golden added or
changed, with the reason.

---

## 9. Lead: integration and release

- [ ] **L1 Merge and check contracts.**
  - Merge `fix/0.2.1-b`, then `-a`, then `-c` into `fix/0.2.1`, resolving conflicts.
  - Then check end to end:
    - records written by A's native tests decode with C's `decodeJob` (run
      `engine_records_test` against native-produced records);
    - the import warning (C9) fires with the real core's B3 issues
      (`native_core_test.dart` style);
    - preflight records from A5 show correctly in the app (C15).
- [ ] **L2 Remove the AV1 `lp=3` workaround** (needs A1's real-FFmpeg AV1 pass
  without `lp=3`, for `p010le` and `bgr0`).
  - **Test first**: change the expectation in
    `app/test/golden/builtin_presets_golden_test.dart` (around line 192) to `''`,
    and add a test that `av1-small` has an empty `video.extra` and revision 5.
  - **Fix**:
    - in `schema/builtin-presets.v1.json`, entry `av1-small`: set `video.extra` to
      `""`, rewrite `notes` and increase `revision` from 4 to 5;
    - run `python -I scripts/etc/Generate-ServiceBuiltins.py` and then `--check`.
      It regenerates `builtin_presets.dart` and `builtin_presets.generated.inc`;
    - update native starter tests that assert the AV1 revision or its extra
      arguments;
    - review and regenerate the `builtins_av1_cpu_{light,dark}` goldens.
  - **Notes**: saved templates keep their snapshot until "Update from library".
    Templates made from revision 4 correctly show "Library has revision 5".
- [ ] **L3 Refresh for `-nostats`.** Update the Dart service fixtures and app
  goldens that show the command preview (B lists them). Review every image: only
  the command text may differ.
- [ ] **L4 Docs.**
  - `docs/STATUS.md`: replace the "live pipe stall" story with the root cause and
    fix, and record all counts and their scope.
  - `docs/NEXT_AGENT.md`: the next task is L6; remove the link to this plan once
    it's done.
  - `docs/STARTER_PRESETS.md`: AV1 (CPU) at revision 5, no extra arguments.
  - `docs/product/CONTRACTS.md`: section 3 of this plan.
  - `docs/product/UI_SPEC.md`: import warning, library and History banners, editor
    unresponsive state, FFmpeg page, output path display, monitor countdown.
  - `docs/product/TECH_ARCHITECTURE.md` §5: queue sizing, no-progress detection,
    preflight records, audio formats.
  - `docs/product/SYSTEM_OVERVIEW.md`: the measured keystroke figure.
  - **Paths (D7).** In active docs, replace absolute paths with repo-relative
    paths, environment variables or placeholders. Active docs include `AGENTS.md`,
    `README.md`, `app/README.md`, `app/assets/icon/README.md`,
    `packages/ve_core/README.md`, `docs/BUILDING.md`, `docs/NEXT_AGENT.md`,
    `docs/STATUS.md`, `docs/INSTALLER.md`, `docs/VEGAS_RUNTIME.md`,
    `docs/ARCHITECTURE.md` and `docs/product/*.md`.
    - Keep operational meaning: for example, describe the installed trial's
      rollback location as "the sibling `vegas-encoder-platform` checkout's
      `build` folder", not by drive letter.
    - In historical records (`docs/B6_TRIAL.md`, `docs/CONTAINER_TRIAL.md`,
      `docs/product/workstreams/**` and similar), redact only user-profile paths
      to `%USERPROFILE%`, `%APPDATA%` or `%LOCALAPPDATA%` form; leave everything
      else as recorded.
    - Do not rewrite git history; older commits keep their old text.
- [ ] **L5 Full regression and build.**
  - Run every suite in 4.4, including both `-Asan` runs, and
    `Test-RenderMatrix.ps1 -Full` with both FFmpeg builds.
  - Run `python -I scripts/etc/Test-NoMachinePaths.py` (full scope). It must
    pass.
  - Run `.\scripts\Build-Release.ps1 -Action Build`. Check that the app reports
    `0.2.1+1` and every exporter DLL reports file version `0.2.1.1`.
  - Package only when the owner asks. Never run Setup. Never push.
  - Ask the owner before removing the temporary worktrees.
- [ ] **L6 Owner real-VEGAS checklist.** Run on 2026.0.3.189, 23.0.0.278,
  22.0.0.248, 21.0.0.108 and Sony 13.0.0.453, about 10–15 minutes per host:
  1. Install 0.2.1 over 0.2.0+3 with Setup.
  2. Render **AV1 (CPU) revision 5** (no `lp=3`) on a 1080p clip of at least 60 s,
     with audio. Do this first on **2026 and Sony 13**.
  3. Render each built-in preset once, on a clip of at least 30 s.
  4. Render projects at **44.1 kHz stereo, 48 kHz mono and 48 kHz 5.1**. Check the
     5.1 channel order with a test-tone project. Render a video-only preset in the
     44.1 kHz project.
  5. Render twice to the same filename. On 2026, VEGAS should ask before
     replacing, and the file is replaced. On older hosts, a `name (2)` file is
     written and its path shown (D1).
  6. Cancel mid-render, then render again.
  7. Trigger a preflight failure (for example clear the default FFmpeg, or use a
     non-square project). Check the progress window and History explain it.
  8. Open the template editor and Apply. Apply an invalid recipe and check VEGAS
     returns to the front.
  8a. Render with a preset that uses `-t 5` (D4). Check the pop-up warning appears
     when it is saved, and that the render ends successfully with a 5-second file.
  9. Switch to another app while a render starts, and check the progress window's
     placement.
  10. Force a mid-render FFmpeg failure and check the History message is readable.

---

## 10. Second review: verification results

| Review 2 item | Verdict | Plan item |
| --- | --- | --- |
| 1.1 Non-48 kHz or non-stereo projects fail, even with audio off | **Valid, high.** The template audio is zero ("project"), the conform step copies the project format, and the fixed check sits outside the recipe-build guard. | A2 |
| 1.2 Failures before RecipeJob leave no progress window or History | **Valid, medium.** | A5, C11, C15, D9 |
| 1.3 Extra-argument parsing and overrides | **Partly valid, low.** The quoted example given doesn't trigger it, but cross-stream specifiers, quoted dash values and `ResizeAlignment`'s different pairing do. | B4 |
| 1.4 Hardware "failed" and "missing" downgraded to "unknown" | **Partly valid, low.** "missing" can't occur (unlisted encoders aren't in the cache). Per owner decision D8, "failed" stays non-blocking, but its context is added to any FFmpeg failure message. | A10, D8 |
| 1.5 Clock step makes records unreadable; one bad line or file breaks the list; `\r` lines | **Valid, low** (clock); the list resilience was already planned; the `\r` case is an edge. | A18, C11, C4 |
| 1.6 `Programs (*.exe)` filter on preset import | **Valid, cosmetic.** | C12 |
| 1.7 Exit-save skips FFmpeg warnings | **Valid, low.** | C13 |
| 1.8 Foreground not returned when validation throws | **Valid, low.** | B9 |
| 1.9 Monitor closes instantly near the countdown's end | **Valid, low.** | C14 |
| 1.10 `MAX_PATH` buffers | **Valid, very low.** | A17 |
| 2.1 Idle polling (GPU isolate per second, cache re-parse, `machine.json` 4 Hz, 1 MiB `calloc`) | **Valid, medium.** May also contribute to the FFmpeg page bug. | C6, C1 |
| 2.2 Per-frame allocation, row-by-row copy | **Valid.** Already planned; whole-plane copy added. | A11 |
| 2.3 Hashing on every render | **Valid.** Already planned; FFprobe added. Log-open hashing and per-line flush are deliberate and cheap: not changed. | A13 |
| 2.4 Advanced double compile; duplicate `Structural`; `Estimate`; per-call `std::regex` | **Valid.** The compile issue was already planned; the rest are micro-optimizations. | C8, B5, A19 |
| 2.5 `decodeJson` lexer allocations | **Valid.** Partly planned; key fast path added. | C5 |

---

## 11. Definition of done

- Every item has a regression test that failed before and passes after. The
  exceptions are noted with the reason and manual steps.
- All suites pass after integration, and the counts and scope are in STATUS.
- The version is 0.2.1+1 everywhere, and the generated files are fresh.
- The AV1 starter has no workaround. The offline real-FFmpeg AV1 long render passes.
  44.1 kHz, mono and 5.1 projects render through the actual DLL offline.
- The owner's checklist (L6) is the next task. Do not claim real-VEGAS
  compatibility before the owner confirms it.

---

## Appendix: subagent prompt template (the lead fills in `{…}`)

```text
You are subagent {A | B | C} working on the Vegas Encoder 0.2.1 bug-fix plan.

Working folder: {worktree folder; give it only in the spawn message, never in a committed file}, branch {fix/0.2.1-a|b|c}. Work, build and
test ONLY inside this folder. Commit locally on this branch when an item is done.
Never push, merge, rebase, install anything, run Setup, or touch other worktrees.

Read first, in this folder: docs/FIX_PLAN_0.2.1.md sections 0, 2 (decisions as
recorded at the top of the file), 3 (shared contracts), 4 (testing) and section
{6 | 7 | 8} (your workstream). Also read AGENTS.md and the docs listed in
section 0.

Your items: {list, for example A1–A19 and T1–T3}, in the order given.
You own these paths and may edit only them: {ownership row from section 1.1}.
Do NOT edit shared docs (docs/**, AGENTS.md, README.md), version.json,
schema/builtin-presets.v1.json or generated files outside your ownership. If you
need such a change, describe it in your report instead.

For every item, follow the test-first protocol (section 4.3):
1. write the regression test;
2. run it on unmodified code and confirm it fails for the stated reason; save
   the key failing output;
3. fix;
4. confirm it passes;
5. run that layer's suites.
At the end, run every suite listed at the end of your workstream section, plus
ASan variants where listed. Never refresh goldens or fixtures without inspecting
each change. Implement the shared contracts exactly as written. If a contract
seems wrong, stop that item and report it.

Toolchain: provided through environment variables VEGAS_ENCODER_FLUTTER,
VEGAS_ENCODER_VCVARS, VEGAS_ENCODER_PYTHON and VEGAS_ENCODER_FFMPEG (the lead sets
them), or PATH. Never write absolute paths, drive letters or user names into any
committed file or into your report (decision D7); use repo-relative paths or
placeholders.

Final report (your last message):
- for each item: status; regression test name or location; failing output before
  (key lines); passing after;
- every suite run, with pass/fail counts and scope (fakes, fake host, real
  FFmpeg);
- files changed;
- changes needed outside your ownership;
- doc text the lead should add (STATUS, CONTRACTS, UI_SPEC, TECH_ARCHITECTURE);
- anything unresolved or that you couldn't make fail first, and why.
```
