# Vegas Encoder implementation instructions

This is a product development repository. The sibling investigation is historical
provenance and a resource for specific unresolved native-interface questions.
Use a lightweight development workflow; do not inherit its research ledger process.

## Current scope and app-design stop point

The user reports the app plan/design is complete on another branch. Review that
design before the next product stage; until then, finish only the VEGAS integration foundation and the fixed
encoding path needed to validate it. A temporary one-setting native page is a
technical proof, not the final product UI.

The user now wants this foundation implementation checkpoint committed and then
to stop. Do not review or merge the app-design branch in this task; that is for
next time. Keep outstanding runtime qualification limits explicit at closeout.

The foundation is ready for the design handoff when the stated target supports:

- reliable discovery and rendered video/audio delivery;
- repeated renders, cancellation/recovery and useful failure handling;
- an editable native configuration page with understood template ownership;
- one setting saved in a VEGAS template, surviving reopen/restart and reaching
  the next render, with separate templates and Apply/Cancel behavior verified.

The user explicitly deferred the real two-template/restart persistence test.
Keep it unverified in support notes and revisit during product qualification;
do not repeat it as a prerequisite for this foundation handoff. Real cancellation/
recovery now passes; controlled real failure recovery remains a qualification
limit at this requested checkpoint. Review the existing design only before the
later product feature stage, not during this closeout.
Do not claim the original full qualification checklist passed without those tests.
Do not select the desktop UI framework, build preset/library management, finalize
the full encoding-settings model or recipe schema, or implement basic/advanced
views and the full popup editor before that design is supplied. Generic plumbing
and a small versioned proof payload are permitted; product decisions stay open.
See docs/DESIGN_GATE.md. Do not claim the gate is passed from offline mocks alone.

## Development rules

Read README.md, ORIGIN.md, docs/STATUS.md, docs/ARCHITECTURE.md,
docs/ADAPTER_PLAN.md and docs/INTEGRATION_CONTRACT.md before changing native code.
The primary target identity is in docs/TARGET.md. Keep the engine and portable
settings/media concepts independent of VEGAS native interfaces. A public SDK is deferred.

Compatibility claims must identify the actual build and tested host. Keep binary
hashes for installation/release verification or when needed to distinguish builds;
do not inventory/hash every input for routine development. Fake-host checks do not
prove real VEGAS compatibility. Preserve existing finding references and uncertain fields.
Keep host calls on Render's caller thread; copy/release host frames before waits.
No payload/download/installer execution belongs to source inspection.

Production code lives here; the sibling investigation is provenance and a place
for targeted ABI experiments. Builds and fake tests must not require that checkout.
Keep origin/attribution for imported or reused code. Existing import manifests remain
historical provenance; no per-task manifest is required. No project license is selected.

Run focused checks for ownership, bounds, timing, cancellation and changed scripts.
Update docs/STATUS.md when a milestone, limitation or next task changes. Summarize
what changed and the focused checks actually performed in the task response or
appropriate product documentation. State whether validation used a fake host or
real VEGAS when that distinction matters.

Do not create dated experiment notes, numbered findings, raw command archives,
copied media or comprehensive evidence inventories for every task. Keep detailed
diagnostics only when they help reproduce a failure, resolve an ABI uncertainty,
or verify installation/release behavior. Existing evidence/ and docs/experiments/
are historical records; preserve them without extending them by default.

Keep installation changes reversible with an appropriate backup/manifest and clear
restoration instructions. This is operational rollback information, not a research
workflow. Test output can go under ignored build/test-results/; existing runners'
-EvidenceDir argument simply names their output folder.
Do not automatically commit, publish, install or replace an installed exporter.

For external API/library-specific questions use current primary documentation and
Context7, resolving the library before requesting docs (maximum three commands per
question); do not guess quota/network failures away. Pure refactoring and authored
scripts can be validated from this implementation and its focused tests.

Use `npx ctx7@latest library <official-name> "<specific concept>"` first unless a
valid `/org/project` ID is supplied, then `npx ctx7@latest docs <id> "<concept>"`.
Choose exact/relevant, reputable matches; use a supplied version-specific ID when
available. Run requests outside the default sandbox. Network/DNS failures should
be retried outside it; quota failures must be reported with the option to use
`npx ctx7@latest login` or `CONTEXT7_API_KEY`. Do not send credentials in queries or
silently substitute training knowledge when documentation retrieval fails.
