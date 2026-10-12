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
- Render progress: a status line in VEGAS's render dialog if a real-host test shows it
  works, plus a small progress window that is dropped if it measurably slows renders
  (docs/product/TECH_ARCHITECTURE.md §5.6).

Work runs in two parallel workstreams, **app** and **platform**. Before product work,
read docs/product/README.md, docs/product/WORKSTREAMS.md and the documents your
workstream uses. Stay inside the paths your workstream owns. Ask for changes elsewhere
through your file in docs/product/workstreams/, and keep using a stub meanwhile. The
C++ core is the only implementation of compile, validate, lint and completion; the app
reaches it and the system only through packages/ve_core and packages/ve_services.

Outstanding qualification limits stay explicit: the real two-template/restart
persistence test and controlled real failure recovery are unverified (see
docs/STATUS.md). Features gated on A5–A7 stay gated until real-host evidence exists.
Do not claim a gate passed from offline mocks, fakes or design decisions.

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
Update docs/STATUS.md (platform) or your workstream file when a milestone, limitation
or next task changes. Summarize what changed and the focused checks actually performed
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
Commit only to your own workstream branch, and only when the owner's task prompt
allows it. Never push, merge into master, rewrite shared history, publish, install or
replace an installed exporter without asking. Upgrading the Flutter SDK or other
machine-wide tools is the owner's call.

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
