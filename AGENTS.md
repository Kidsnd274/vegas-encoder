# Vegas Encoder implementation instructions

This is a product development repository. The sibling investigation is historical
provenance and a resource for specific unresolved native-interface questions.
Use a lightweight development workflow; do not inherit its research ledger process.

## Current stage: building the product

The VEGAS integration foundation is committed. The owner reviewed the product design
on 2026-10-12 and recorded the decisions in docs/product/README.md (Decisions):

- Signal Flow is the direction. docs/product/design/signal-flow.html is the visual
  reference in light and dark; docs/product/UI_SPEC.md is the behaviour.
- Basic and Advanced modes. Basic has curated controls plus Extra arguments; there is
  no all-options list. Advanced-mode autocomplete is built last.
- Flutter with Riverpod and the app's own components (not the Material look). The
  theme follows Windows.
- Windows x64 only, for the product, development, tests and CI.
- User-supplied FFmpeg. No proof-template migration.
- Render progress: the owner dropped the VEGAS status-line experiment. Keep the
  small progress window; its real-host overhead remains unqualified
  (docs/product/TECH_ARCHITECTURE.md §5.6 and docs/STATUS.md).

The owner consolidated app and platform work on 2026-10-16. One agent owns product
work across app, packages, native code, tests, scripts and documentation in the
original checkout, `L:\repos\vegas-encoder`, currently on
`master`. Do not create or resume a separate worktree or split
the work between agents unless the owner asks. A branch in this original folder
is fine; it does not require another checkout. Do not spawn subagents by default.

Before product work, read docs/product/README.md, docs/product/WORKSTREAMS.md,
docs/STATUS.md and docs/NEXT_AGENT.md, plus the contracts/specifications relevant
to the change. The old docs/product/workstreams/ files are historical component
handoffs, not active ownership boundaries or instructions to work elsewhere.
Implement both sides of an integration together rather than leaving an ownership
stub. Preserve architectural boundaries: the C++ core is the only implementation
of compile, validate, lint and completion; the app reaches it and the system only
through packages/ve_core and packages/ve_services.

Outstanding qualification limits stay explicit in docs/STATUS.md. Basic renders,
normal template restart persistence, cancellation/recovery, failure presentation
and immediate large-preset reopen are owner-confirmed at their recorded scope.
Extra same-session encoder-failure recovery and the faster-progress real-host trial/
performance comparison are owner-deferred; do not request or resume them without
new owner direction. The exact large-template save/restart sequence remains
unconfirmed. Do not claim a gate passed from mocks, fakes or design decisions.

## Development rules

Read README.md, ORIGIN.md, docs/STATUS.md, docs/ARCHITECTURE.md,
docs/ADAPTER_PLAN.md and docs/INTEGRATION_CONTRACT.md before changing native code.
The primary target identity is in docs/TARGET.md. Keep the engine and portable
settings/media concepts independent of VEGAS native interfaces. Keep src/core free of
Windows and VEGAS headers. A public SDK is deferred.

Compatibility claims must identify the actual build and tested host. Keep binary
hashes for installation/release verification or when needed to distinguish builds;
do not inventory/hash every input for routine development. Fake-host checks do not
prove real VEGAS compatibility. Preserve existing finding references and uncertain fields.
Keep host calls on Render's caller thread; copy/release host frames before waits.
Nothing may make Render wait on the app or the progress window.
No payload/download/installer execution belongs to source inspection.

Production code lives here; the sibling investigation is provenance and a place
for targeted ABI experiments. Builds and fake tests must not require that checkout.
Keep origin/attribution for imported or reused code. Existing import manifests remain
historical provenance; no per-task manifest is required. No project license is selected;
check licences before adding a dependency or bundling a font or asset.

Run focused checks for ownership, bounds, timing, cancellation and changed scripts.
App work needs widget tests and golden tests in light and dark for what it changes.
Update docs/STATUS.md when a milestone or limitation changes, and docs/NEXT_AGENT.md
when the next task changes. Keep one current queue; do not maintain parallel app
and platform queues. Summarize what changed and the focused checks actually performed
in the task response or appropriate product documentation. State whether validation
used fakes, a fake host or real VEGAS when that distinction matters.

Do not create dated experiment notes, numbered findings, raw command archives,
copied media or comprehensive evidence inventories for every task. Keep detailed
diagnostics only when they help reproduce a failure, resolve an ABI uncertainty,
or verify installation/release behavior. Existing evidence/ and docs/experiments/
are historical records; preserve them without extending them by default.

Keep installation changes reversible with an appropriate backup/manifest and clear
restoration instructions. This is operational rollback information, not a research
workflow. Test output can go under ignored build/test-results/; existing runners'
-EvidenceDir argument simply names their output folder.
Commit only when the owner's task prompt allows it, using the current local branch
in the original checkout. Never push, merge into master, rewrite shared history, publish, install or
replace an installed exporter without asking. Upgrading the Flutter SDK or other
machine-wide tools is the owner's call.

Existing sibling worktrees and `.claude/` are preserved, not active development
locations. The installed trial's INI still points to candidate app/log files under
`L:\repos\vegas-encoder-platform\build`; keep those candidates, isolated trial
data and exact rollback files intact. Do not rewrite installed paths, relocate a
live candidate, delete old worktrees or copy their build caches as part of routine
development. New builds/tests belong in this checkout's ignored build folders.

For external API/library-specific questions use current primary documentation and
Context7, resolving the library before requesting docs (maximum three commands per
question); do not guess quota/network failures away. This applies to Flutter, Dart
and pub packages too. Pure refactoring and authored scripts can be validated from
this implementation and its focused tests.

Use `npx ctx7@latest library <official-name> "<specific concept>"` first unless a
valid `/org/project` ID is supplied, then `npx ctx7@latest docs <id> "<concept>"`.
Choose exact/relevant, reputable matches; use a supplied version-specific ID when
available. Run requests outside the default sandbox. Network/DNS failures should
be retried outside it; quota failures must be reported with the option to use
`npx ctx7@latest login` or `CONTEXT7_API_KEY`. Do not send credentials in queries or
silently substitute training knowledge when documentation retrieval fails.
