# Experiment: independent Vegas Encoder adapter baseline

- Date: 2026-10-10 (Asia/Singapore).
- Status: implementation complete for initial offline baseline; real-host gates pending.
- Question: Can the imported adapter build and validate independently of the research checkout?
- Success condition: own identities/module paths, self-contained generated fixtures,
  successful native/helper/FFmpeg/fake-installer checks and preserved source provenance.
- Inputs: exact research source hashes in ../import-manifest.json; no captured template
  or upstream connector binary. Compiler, host/encoder and build hashes are in ignored evidence.

## Changes

Imported authored ABI/adapter/engine/checkers; extracted checked templates and frame
leases, separated diagnostics headers, branded independent product identity, generated
synthetic project settings, authored build/tests and conservative reversible installer.
Review found stale short label, exception containment and diagnostic lock-unwind issues;
those were corrected before the final candidate rebuild.

## Commands and results

Raw build, host helper, native-boundary, raw checker, fake-tree installer and FFmpeg
suite output is preserved under `evidence/bootstrap/`; per-case decoded media/logs
are under fresh proof directories. The final validation report and identities link
each result to the actual DLL. Development source import is not a real-host test.

Commands: `cmd /d /c scripts/build.cmd`; `build/host-tests/host-helpers.exe`;
`build/host-tests/native-boundary.exe`; Python isolated raw-checker self-test;
`scripts/Test-VegasEncoder.ps1 -EvidenceDir <fresh> -Include1080p` with explicit Python/
FFmpeg paths; `scripts/Test-Install.ps1 -EvidenceDir <fresh>` against a fake tree only.
All generated inputs/outputs remain ignored. No project license, commit or publication.

## Limits and next task

**No real VEGAS runtime test ran.** Installed VEGAS/ffbridge/Voukoder were untouched.
A1's independent source/build foundation is implemented; A2/A3 have partial structural
and helper coverage. A0/A4 broader real-host, A5/A6 configuration, A7 snapshots and
A8 qualified product foundation remain pending. Test the final recorded DLL using
../VEGAS_RUNTIME.md; then recover the native configuration exchange.
