# Vegas Encoder: agent instructions

Vegas Encoder is a VEGAS Pro exporter plug-in, a shared C++ core, and a Flutter
desktop app. This repository holds the production code, contracts, product docs,
build and Setup instructions, and concise qualification status. Detailed reverse
engineering and host diagnostics live in the private `vegas-ffmpeg-frameserver`
repository. Builds and tests must never require that repository.

## Before you start

- Read `docs/STATUS.md` (current state and limits) and `docs/NEXT_AGENT.md`
  (current queue).
- For product or app work, also read `docs/product/README.md` (owner decisions)
  and the relevant parts of `docs/product/UI_SPEC.md` and
  `docs/product/CONTRACTS.md`.
- Before changing native code, also read `docs/ARCHITECTURE.md`,
  `docs/ADAPTER_PLAN.md`, `docs/INTEGRATION_CONTRACT.md` and `docs/TARGET.md`.
- Build and test instructions are in `docs/BUILDING.md` and `scripts/README.md`.

## Product decisions that constrain the work

- Signal Flow design (`docs/product/design/signal-flow.html`, light and dark);
  `UI_SPEC.md` defines behaviour.
- Basic mode has curated controls plus Extra arguments. Advanced mode edits the
  whole FFmpeg command.
- Flutter with Riverpod and the app's own components (not the Material look).
  The theme follows Windows.
- Windows x64 only, for the product, development, tests and CI.
- FFmpeg is supplied by the user.
- Render progress uses the small progress window. The VEGAS status-line
  experiment was dropped.

## Architecture rules

- The C++ core (`src/core`) is the only implementation of compile, validate,
  lint and completion. The app reaches the core and the system only through
  `packages/ve_core` and `packages/ve_services`.
- Keep `src/core` free of Windows and VEGAS headers. Keep the engine and portable
  settings/media concepts independent of VEGAS native interfaces.
- Host (VEGAS) calls stay on Render's caller thread. Copy and release host frames
  before any wait. Nothing may make Render wait on the app or the progress window.
- Implement both sides of an integration together. Do not leave a stub for
  someone else to finish.

## Working rules

- **Agents and worktrees.** Use subagents and git worktrees when the work splits
  cleanly. Give each one clear file ownership, and agree any shared data formats
  first. One lead agent merges the work, owns the shared docs, and keeps a
  single task queue in `docs/NEXT_AGENT.md`. Each worktree builds and tests
  inside itself. Never install anything from a worktree, so no installed file
  depends on one. Ask the owner before removing a worktree.
- **Commits.** Commit only when the owner allows it. Never push, merge into
  `master`, rewrite shared history, publish, install, or replace an installed
  exporter without asking. Commit messages must not contain co-author trailers
  (`Co-Authored-By:`), "Generated with" lines or any other agent or tool
  attribution.
- **Machine-wide tools.** Upgrading the Flutter SDK or other machine-wide tools is
  the owner's call.
- **No machine-specific paths.** Never write absolute paths, drive letters or user
  names into committed files. Use repo-relative paths, environment variables
  (`VEGAS_ENCODER_FLUTTER`, `VEGAS_ENCODER_VCVARS`, `VEGAS_ENCODER_PYTHON`,
  `VEGAS_ENCODER_FFMPEG`) or placeholders. The work must run on any PC.
- **Installed trials.** Preserve existing installed trials, their candidate files,
  isolated trial data and rollback files. Do not move, delete or rewrite them as
  part of routine development. Keep installation changes reversible, with a backup
  or manifest and clear restore steps.
- **Test output.** Builds and test output go in this checkout's ignored `build/`
  folders (test results under `build/test-results/`).
- **Dependencies.** No project licence is selected yet. Check licences before
  adding a dependency or bundling a font or asset. Keep origin and attribution for
  imported or reused code.

## Testing and claims

- Write a failing regression test before fixing a bug, where possible.
- Run focused checks for ownership, bounds, timing, cancellation and any changed
  script.
- App changes need widget tests and golden tests in light and dark. Review image
  diffs before accepting new goldens.
- Say whether each check used fakes, the fake host, real FFmpeg or real VEGAS.
  Fake-host results do not prove real VEGAS compatibility.
- Compatibility claims must name the exact build and the tested host. Never claim
  a gate passed from mocks, fakes or design decisions.
- Keep binary hashes for installation and release verification, or when needed to
  tell builds apart. Don't hash every input during routine development.
- Owner-deferred trials stay deferred until the owner says otherwise. `STATUS.md`
  lists them.

## Documentation

- Update `docs/STATUS.md` when a milestone or limitation changes, and
  `docs/NEXT_AGENT.md` when the next task changes.
- Summarize what changed, and the checks actually run, in your response or the
  relevant doc.
- Don't create dated experiment notes, numbered findings, raw command archives or
  copied media for routine tasks. Keep detailed diagnostics only when they help
  reproduce a failure, resolve an ABI question, or verify installation or release
  behaviour.
- `evidence/`, `docs/experiments/` and `docs/product/workstreams/` are historical
  records. Preserve them and don't extend them.

## External documentation

For Flutter, Dart, pub packages and other external libraries or APIs, use current
primary documentation or Context7. Don't rely on memory.

- Run `npx ctx7@latest library <official-name> "<concept>"`, then
  `npx ctx7@latest docs <id> "<concept>"`. Use at most three commands per
  question.
- Run them outside the sandbox, and retry network failures there.
- Report quota failures, with the option to use `npx ctx7@latest login` or
  `CONTEXT7_API_KEY`. Never send credentials in queries.
