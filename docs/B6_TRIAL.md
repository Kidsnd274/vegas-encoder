# B6 connected candidate: owner VEGAS trial

Prepared candidate: **0.1.6-recipe-proof**, frontend **0.1.5+1** (unchanged). Target:
Boris FX VEGAS **2026.0.3.189**. This candidate connects the existing frontend
popup and monitor to native template recipes and the recipe engine. It is staged
under `L:\repos\vegas-encoder-platform\build\b6-candidate-0.1.6`; the owner has
installed and retested it. No real-host gate passes from preparation or fake tests.

Latest result: the owner confirms faster opening and saved templates surviving
restarts. Three process-age traces reach the visible window in 0.53–0.75 s.
The remaining focus bug is switching to another full-screen app, returning to
VEGAS/the editor, then Apply exposing that other app. The app close-handoff request
is in the [platform handoff](product/workstreams/platform.md). Capacity, controlled
real failure recovery and measured monitor overhead remain open. Installation
steps below are retained for reproducibility; no reinstall is needed for this
documentation update.

The owner reports that both 0.1.5 templates now render with their intended codecs
and the template-text/request bugs appear resolved. Current retest priorities are
**click-to-visible editor time** and **VEGAS staying restored after popup Apply**.
The 0.1.6 native path performs file/process startup on an independent worker while
VEGAS's UI keeps running; the same frontend/Skia build is retained. This does not
prove the variable Windows process-creation cost has disappeared. The previous
logs show roughly 33–37 ms fast and 7–12 s slow in grouped launch/resume work.
That points to native startup but does not isolate the exact call or establish
a shader cause; renderer choice remains unchanged pending the detailed data.
No launch-cancellation UI is added. The new launcher enables the frontend's
existing first-frame trace at `logs\frontend-startup.txt`, alongside native launch
phase timings, so the next real trial can measure total opening latency.

The owner's first 0.1.4 trial reached a successful real VEGAS FFV1/PCM render and
the progress window, but exposed garbled native text, intermittent edit requests
and an Explorer reveal bug. The 0.1.5 fixes supplied aligned native text, correct
Explorer arguments and bounded sampled verification; 0.1.6 retains them. Its data
folder is a copy of the 0.1.5 trial's data; original candidates/data remain untouched.

**For old corrupted 0.1.4 templates, use the fresh built-in and save new names.** Old test
templates may already contain corrupted names/notes; the patch cannot reliably
reconstruct those strings. Preserve them for now. Intact old recipe payloads remain
readable, but existing garbled Recent entries are not automatically repaired.
The historical hidden id-0 preset workaround is retained; no speculative ordering
change was made. Start with names such as **B6 fixed lossless** and **B6 fixed H264**.
Already-working 0.1.5 templates remain compatible with 0.1.6. Reuse those for the
current startup/Apply checks; another codec render is not required to repeat the
owner's successful test.

## Install and start

1. Close VEGAS. Keep the entire candidate folder in place: its INI points to
   the staged `app\VegasEncoder.exe`. `app\data` and both package DLLs are required.
2. In PowerShell run the following. The existing installer requests administrator
   approval for the explicit exporter update. It checks the previous manifest,
   refuses unexpected files and leaves unrelated exporters alone.

   ```powershell
   Set-Location L:\repos\vegas-encoder-platform
   .\scripts\Install-VegasEncoder.ps1 -VegasDir 'C:\Program Files\BorisFX\Vegas Pro 2026' -BuildDir 'L:\repos\vegas-encoder-platform\build\b6-candidate-0.1.6\plugin' -Update
   .\scripts\Start-B6Trial.ps1 -Target Vegas
   ```

The launcher sets `VEGAS_ENCODER_DATA_ROOT` only in the launched process's
environment. Popup and monitor inherit it. Use this launcher again after every
VEGAS restart during the trial. It verifies the installed DLL matches the candidate.
It refuses an already running VEGAS, which would retain its previous environment.
No machine-wide environment variable or antivirus setting is changed.

Trial settings, library, sessions and History live in `build\b6-candidate-0.1.6\data`.
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
Native logs are in `build\b6-candidate-0.1.6\logs`; C5/C6 and FFmpeg logs are in
`build\b6-candidate-0.1.6\data\Local\jobs`. There is no need for a debugger, sanitizer,
antivirus exclusion or additional process/thread tracing.

The native page paints “Starting the editor...” before scheduling parallel work
and logs preflight/files/job/process-creation/resume timings. Report total time
until the editor is visible, including repeat opens. These existing per-process
logs and frontend trace separate Windows launch from first-frame latency.
Progress remains within the existing two-updates-per-second publication budget,
with phase changes immediate; an idle sample no longer waits for an extra timer
tick. Verification samples at most 32 packets after normal stream discovery,
requires decoded video and checks all stream kinds/count and known codecs. It
does not certify the entire file is free of later corruption. The first trial's
full recount took about nine seconds after a two-second encode; the bounded probe
on that same file took about 0.74 seconds in a read-only comparison.

This first candidate exposes only the evidenced MKV file type, P010 square-pixel
video, and the established 48 kHz stereo float input path. Non-MKV, audio-only,
and general Advanced commands without an established video output are refused.
Advanced requires explicit `-f matroska`; facts outside the core's supported
scope stay null. Do not use saved proof templates with the candidate.

Controlled real failure recovery, measured private-payload capacity and monitor
performance remain separate, unverified steps. Normal saved-template persistence
is now owner-confirmed for the tested recipes; it is not a maximum-capacity test.

## Progress-window timing comparison

No extra tool or build is required. Use the installed 0.1.6 candidate:

1. Select one project, one saved template and one fixed render range. Prefer a
   range that takes at least about a minute to render, so subsecond variation
   does not dominate. Keep output verification and other settings unchanged.
2. Launch the trial desktop app using `Start-B6Trial.ps1 -Target App`. In Settings
   → Rendering, use **Show a progress window during renders**. This changes the
   same isolated C7 settings that VEGAS reads at each render. Close prior progress
   windows and the desktop app before each measured run. Merely closing a launched
   monitor is not an off run: its startup cost would already have occurred.
3. Do one unmeasured warm-up, then six renders in this order: **on, off, off, on,
   on, off**. Reopen the trial app between runs to set the toggle as needed, allow
   the setting to save, then close it. Use fresh names such as `monitor-on-1.mkv`
   and `monitor-off-1.mkv`; never overwrite earlier results. Keep other app/load
   conditions similar and leave VEGAS at the same visibility throughout.
4. Send the six output names when done. C6 records already include precise
   `elapsedSec` and phase timings in the trial's `data\Local\jobs`; no manual
   stopwatch is required. Compare medians as
   `100 * (median_on / median_off - 1)`. If run variation is comparable to the
   difference, record the result as inconclusive rather than asserting no cost.

The existing product target is at most about 2% render-time cost and under 120 MB
for the monitor. Memory needs a separate observed measurement, not inference from
elapsed time. Restore the preferred progress setting afterward. No performance
claim follows from fake-host checks or subjective smoothness.

## Restore the previous exporter

The exact currently installed **0.1.5** DLL/PDB/INI/install manifest and discovery file were copied to
`build\b6-candidate-0.1.6\rollback`, with `backup-sha256.json`. The installed exporter
was left unchanged during preparation. Keep this backup until the trial is accepted.

Close VEGAS and run:

```powershell
.\scripts\Install-VegasEncoder.ps1 -VegasDir 'C:\Program Files\BorisFX\Vegas Pro 2026' -BuildDir 'L:\repos\vegas-encoder-platform\build\b6-candidate-0.1.6\rollback\plugin' -Update
```

This restores the previous exporter binaries and INI through the same reversible
installer, which regenerates/verifies its discovery manifest. Launch the old
candidate's isolated data after rollback with:

```powershell
.\scripts\Start-B6Trial.ps1 -Target Vegas -CandidateRoot 'L:\repos\vegas-encoder-platform\build\b6-candidate-0.1.5'
```

Trial data and saved native templates remain. Versions 0.1.5 and 0.1.6 use the
same aligned payload format. The backup's original discovery file and manifest
remain available.
