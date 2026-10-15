# B6 connected candidate: owner VEGAS trial

Prepared candidate: **0.1.4-recipe-proof**, frontend **0.1.4+1**. Target:
Boris FX VEGAS **2026.0.3.189**. This candidate connects the existing frontend
popup and monitor to native template recipes and the recipe engine. It is staged
under `L:\repos\vegas-encoder-platform\build\b6-candidate`; it is **not installed**.
No real-host gate has passed from preparation or fake-host tests.

## Install and start

1. Close VEGAS. Keep the entire candidate folder in place: its INI points to
   the staged `app\VegasEncoder.exe`. `app\data` and both package DLLs are required.
2. In PowerShell run the following. The existing installer requests administrator
   approval for the explicit exporter update. It checks the previous manifest,
   refuses unexpected files and leaves unrelated exporters alone.

   ```powershell
   Set-Location L:\repos\vegas-encoder-platform
   .\scripts\Install-VegasEncoder.ps1 -VegasDir 'C:\Program Files\BorisFX\Vegas Pro 2026' -BuildDir 'L:\repos\vegas-encoder-platform\build\b6-candidate\plugin' -Update
   .\scripts\Start-B6Trial.ps1 -Target Vegas
   ```

The launcher sets `VEGAS_ENCODER_DATA_ROOT` only in the launched process's
environment. Popup and monitor inherit it. Use this launcher again after every
VEGAS restart during the trial. It verifies the installed DLL matches the candidate.
It refuses an already running VEGAS, which would retain its previous environment.
No machine-wide environment variable or antivirus setting is changed.

Trial settings, library, sessions and History live in `build\b6-candidate\data`.
The default FFmpeg was registered through the production C3 discovery/settings
services as `C:\ffmpeg\bin\ffmpeg.exe`, with output verification and progress
window enabled. No hardware test/probe qualification is implied. To inspect or
change **trial** settings/History, launch the matching desktop app with:

```powershell
.\scripts\Start-B6Trial.ps1 -Target App
```

## First test: popup and saved templates

Use a short, square-pixel project with stereo audio at 48 kHz. Save the project
before testing. Select **Vegas Encoder → Vegas Encoder settings (MKV)** in Render
As, then open Customize Template. Use the fresh recipe preset, not an old raw,
fixed FFmpeg or configuration-proof template; there is no proof migration.

1. Click **Edit settings...**. The frontend popup should appear over the native
   settings window. The underlying settings window should be disabled until the
   popup closes, then become usable again.
2. Keep Matroska selected. Set video to **FFV1, lossless, 10-bit** and audio to
   **PCM float**, then Apply in the popup. Click VEGAS Apply/OK and save a named
   native template, for example **B6 lossless 10**.
3. Reopen Edit settings, change something, then Cancel. The previous applied
   settings should remain. Closing the native dialog without applying a new
   draft should also preserve the previous saved template.
4. Create a second fresh template with **H.264 (libx264), 8-bit, CRF 20** and
   **AAC 192 kb/s**, still **Matroska**. Save it as **B6 H264 8**.
5. Close VEGAS, restart through the trial launcher and reopen both named
   templates. Check each retained its own settings. Report if either name,
   recipe or dialog contents changed unexpectedly. This is the outstanding
   real two-template/restart persistence qualification, not an assumed pass.

Popup previews use explicitly unknown project/media context and the existing app
sample. Actual rendering compiles again from delivered media. Native project name,
path and source color metadata are not invented.

## Render and report

Render each saved template to a **new `.mkv` filename**. An existing destination
is deliberately refused by the engine, even if VEGAS offers an overwrite prompt.
The saved recipe should work with the desktop app and popup closed. Check:

- A playable output with the expected picture/audio, and distinct codec settings
  for the two templates. The FFV1 trial should preserve ten meaningful input bits.
- A separate progress window, readable status and a terminal result. It should
  appear without taking focus and should not prevent VEGAS cancellation. Closing
  the monitor should not stop or stall the render. History is in the trial app.
- Cancel a longer render through VEGAS, then immediately render successfully to
  another fresh filename. Report any freeze, unexpected error or retained partial.

Please report the exact step, template, output filename and any displayed error.
Native logs are in `build\b6-candidate\logs`; C5/C6 and FFmpeg logs are in
`build\b6-candidate\data\Local\jobs`. There is no need for a debugger, sanitizer,
antivirus exclusion or additional process/thread tracing.

This first candidate exposes only the evidenced MKV file type, P010 square-pixel
video, and the established 48 kHz stereo float input path. Non-MKV, audio-only,
and general Advanced commands without an established video output are refused.
Advanced requires explicit `-f matroska`; facts outside the core's supported
scope stay null. Do not use saved proof templates with the candidate.

Controlled real failure recovery, measured private-payload capacity and monitor
performance remain separate, unverified steps. After basic operation works,
compare the same longer render three times with the trial Settings progress
window enabled and three times disabled. Restart between preference changes if
needed; use fresh output names. The target is at most about 2% time cost and under
120 MB for the monitor. No performance claim follows from fake-host checks.

## Restore the previous exporter

The exact previous DLL/PDB/INI/install manifest and discovery file were copied to
`build\b6-candidate\rollback`, with `backup-sha256.json`. The installed exporter
was left unchanged during preparation. Keep this backup until the trial is accepted.

Close VEGAS and run:

```powershell
.\scripts\Install-VegasEncoder.ps1 -VegasDir 'C:\Program Files\BorisFX\Vegas Pro 2026' -BuildDir 'L:\repos\vegas-encoder-platform\build\b6-candidate\rollback\plugin' -Update
```

This restores the previous exporter binaries and INI through the same reversible
installer, which regenerates/verifies its discovery manifest. Use the ordinary
VEGAS shortcut afterward. Trial data and newly saved native templates remain;
the old proof exporter cannot use the new recipe templates. The backup's original
discovery file and manifest remain available for verification.
