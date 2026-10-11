# Vegas Encoder foundation runtime check

Target: Boris FX VEGAS Pro 2026.0.3.189 x64, identity in [TARGET.md](TARGET.md).
Current progress and exact candidate identities are in [STATUS.md](STATUS.md).
Real 1080p/fractional renders and the configuration checkbox's on/off render effects
pass on earlier builds. Current `0.1.2-config-proof` real cancellation/recovery
also passes: cancelled output is unpublished/removed, locks and child are cleared,
and the next render in the same host session decodes to 299 frames and 478,878
audio sample frames. Controlled failure/recovery remains unverified. The user deferred
real saved-template restart testing; its procedure remains in
[NATIVE_CONFIGURATION.md](NATIVE_CONFIGURATION.md) for later product qualification.

## Candidate and rollback

The installed version is now `0.1.2-config-proof`, preserved under
`build/candidate-0.1.2-config-proof/`. It adds accurate encoded progress-failure
handling and passes fake-host recovery checks. The user explicitly approved the
upgrade, and DLL/PDB/INI/discovery manifest match the tested candidate. Host,
sharedk, FFmpeg and other discovery configs are unchanged. Real cancel/recovery
now passes on this candidate; see STATUS.md for its exact result and limits.

The prior working `0.1.1-config-proof` installation is backed up in
`build/rollback-before-foundation-closeout/`, including its manifest/config and
restoration instructions. To restore it with VEGAS closed:

```powershell
.\scripts\Install-VegasEncoder.ps1 -VegasDir 'C:\Program Files\BorisFX\Vegas Pro 2026' -Update -BuildDir 'L:\repos\vegas-encoder\build\rollback-before-foundation-closeout'
```

The installer owns only the product folder and discovery file. It refuses running
host processes, modified recorded files and unrecorded installation contents.
An INI test change must be prepared in its own candidate and installed deliberately;
do not edit the live INI and then expect a hash-checked update to accept it. INI
changes take effect after VEGAS restarts. The original real-render-tested `0.1.0-dev`
backup remains in `build/rollback-before-configuration-proof/`.

## Recovery checks and future qualification

1. **Cancel, then render again in the same session (passed).** Render a sufficiently long
   timeline range to a new `foundation_cancel.mkv` and cancel while encoding.
   Expect a cancelled result, no completed MKV, no remaining owned FFmpeg process
   or partial file, and zero outstanding frame locks. Render a short range to a
   fresh `foundation_recovery.mkv` without restarting VEGAS. Expect S_OK, encoder
   exit zero and published media. Inspect the existing report/logs and decode the
   successful output. Record the observed cancellation response; no strict Abort
   deadline or stalled-pipe qualification is currently claimed.
2. **Controlled failure, then recovery (not yet observed in real VEGAS).** Prepare one reversible unavailable-encoder
   or blocked-destination case first. Confirm the adapter reports a failure with
   its reason/code rather than success or cancellation, preserves pre-existing
   output, and cleans up its owned process/partial file/host locks. Restore the
   test condition and render successfully again. A settings change that needs a
   host restart does not establish same-session recovery; record which case was
   actually exercised. Avoid relying on a VEGAS preflight rejection as an adapter
   failure test.

Keep a short outcome summary with the tested build/host and relevant reports.
Detailed diagnostics are needed only if a check fails. Do not create a research
ledger, copy media, or collect broad evidence inventories for this check.

## App handoff

Foundation code now covers discovery, template/frame ownership, fixed media
delivery, process/transport cleanup, failure classification and a native editable
proof value. Cancellation/recovery has passed in real VEGAS; controlled failure
and deferred persistence retain their qualification limits.
Raw diagnostic mode, broader host/format support, color/HDR qualification and
formal stalled-I/O deadlines retain their documented limits.

The user reports app designs on another branch; `origin/product-ui-design` is
available. The user requested a foundation commit and explicitly left design-branch
review for next time. Stop after the checkpoint. No new SDK repository, codec catalog, full recipe schema,
preset library or UI framework selection is needed in this foundation task.
