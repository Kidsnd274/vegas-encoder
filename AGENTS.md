# Vegas Encoder implementation instructions

Read README.md, ORIGIN.md, docs/STATUS.md, docs/ARCHITECTURE.md,
docs/ADAPTER_PLAN.md and docs/INTEGRATION_CONTRACT.md before changing native code.
The primary target identity is in docs/TARGET.md. Keep the engine and portable
settings/media concepts independent of VEGAS native interfaces. A public SDK is deferred.

Runtime claims require the actual built DLL and exact host/version/hash. Fake-host
checks are consistency tests only. Preserve finding IDs and uncertain native fields.
Keep host calls on Render's caller thread; copy/release host frames before waits.
No payload/download/installer execution belongs to source inspection.

Production code lives here; the sibling investigation is provenance and a place
for targeted ABI experiments. Builds and fake tests must not require that checkout.
Record origin and hashes for imported/reused code. No project license is selected.

Run focused checks for ownership, bounds, timing, cancellation and changed scripts.
Update docs/STATUS.md and a dated note under docs/experiments/ after meaningful tasks,
record exact commands/inputs/results in ignored evidence/, and state when no real
VEGAS test ran. Keep install changes reversible and record exact restoration steps.
Do not automatically commit, publish, install or replace an installed exporter.

For external API/library-specific questions use current primary documentation and
Context7, resolving the library before requesting docs (maximum three commands per
question); do not guess quota/network failures away. Pure refactoring and authored
scripts can be validated from this implementation and its focused tests.
