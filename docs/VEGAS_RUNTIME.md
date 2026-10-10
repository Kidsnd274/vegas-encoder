# First Vegas Encoder real-host qualification

Status: pending. This procedure is prepared; bootstrap did not execute it or
change the installed host. Target identity is in [TARGET.md](TARGET.md).

## Candidate and installation

1. Use the exact DLL recorded in `evidence/bootstrap/final-identities.json`; preserve
   DLL/PDB/INI as a candidate with hashes before any rebuild. Recheck the host executable
   hash/version and FFmpeg identity. If host bytes changed, update the target record
   before reusing old compatibility evidence.
2. Configure `build/vegas-encoder/vegas-encoder.ini` before installation: executable,
   fixed FFmpeg output mode and logging. Close VEGAS.
3. Run the explicit installer only when performing this runtime qualification:

```powershell
.\scripts\Install-VegasEncoder.ps1 -VegasDir 'C:\Program Files\BorisFX\Vegas Pro 2026'
```

The installer uses its own folder/config and manifests exact files/hashes. It refuses
reparse traversal, existing unrecorded paths, modified installation contents and
programs running from the target. Elevation helper output goes to a named transcript.
It leaves installed ffbridge/Voukoder and host discovery configs in place.

## Observe and record

- Fresh launch lists Vegas Encoder under Render As, with the visible lossless MKV
  preset. Capture Components/Render As, template summary and new product logs.
- Render the existing counter/audio fixture to a fresh `.mkv`. Expect 90 frames and
  144,000 stereo sample frames, exact markers and sync. Run
  `scripts/Check-EncodedRender.py` on `<output>.vegas-encoder.json` with a fresh
  decode directory and `--fixture`; supply FFmpeg/FFprobe paths.
- Repeat to another filename. Cancel a longer render, verify bounded response and
  absence of child/partial/completed output, then render the fixture again in the
  same session. Define the expected cancellation limit from the configured waits
  before the experiment; fake cancel coverage is not proof of this behavior.
- Exercise a missing/early-exit encoder and an unwritable/existing destination through
  a saved, reversible test configuration. Record native HRESULT, user-visible message,
  stderr/manifest and cleanup; preserve pre-existing destination bytes.
- Qualify fractional/1080p and slow/long cases before extending the supported matrix.
  Use the staged plan for color/metadata/performance evidence; do not assume a speed gain.

Keep exact host/DLL/encoder hashes, user steps, logs, output hashes, decoded check
results and restoration outcome under a fresh evidence folder. A new product DLL
must earn its own result even though its predecessor rendered successfully.

## Restore

Close VEGAS, then remove only the product's recorded installation:

```powershell
.\scripts\Install-VegasEncoder.ps1 -VegasDir 'C:\Program Files\BorisFX\Vegas Pro 2026' -Uninstall
```

If installation files were edited, the installer intentionally refuses hash drift;
restore their recorded candidate bytes before update/uninstall. Unrecorded files are
preserved by refusal. Keep candidate hashes/manifest and changed settings so restoration
is concrete. The separate ffbridge proof installation remains available.

Native property-page editing and saved recipe settings are not implemented in this
candidate. First establish render parity, then perform A5–A7's configuration proof.
