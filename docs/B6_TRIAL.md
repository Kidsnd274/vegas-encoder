# B6 connected candidate: owner VEGAS trial

**Current owner scope:** faster-progress installation/review and monitor
performance measurements are deferred until next time. Preserve the candidate
and rollback; commands below are for when the owner resumes that trial.

## Faster progress updates (2026-10-16; prepared, not installed)

Current next step: try `b6-candidate-0.1.7-faster-progress` before the performance
comparison. FFmpeg and background publication target 200 ms / five samples per
second; the window polls every 100 ms. The previous intervals were 500/500/250 ms.
Phase/terminal changes bypass the writer limit. This targets responsiveness;
real-host overhead is still unmeasured. Existing fixes are included.

After closing VEGAS and Encoder windows, install and launch:

```powershell
Set-Location L:\repos\vegas-encoder-platform
$trial = "$PWD\build\b6-candidate-0.1.7-faster-progress"
.\scripts\Install-VegasEncoder.ps1 -VegasDir 'C:\Program Files\BorisFX\Vegas Pro 2026' -BuildDir "$trial\plugin" -Update
.\scripts\Start-B6Trial.ps1 -Target Vegas -CandidateRoot $trial
```

Render a normal working preset to a fresh filename and observe progress updates.
No deliberate error/capacity retest is requested. Once responsiveness is accepted,
use this candidate/profile for the existing three-on/three-off monitor comparison.
Settings/library/history were copied; active edit sessions were excluded.

Native SHA-256:
`918C22A4F961D4E41883210B37FAF27A4326AE8AEADB26ED0B8C1C1FAA916B0D`.
Same development version labels; manifest variant/hashes distinguish the build.
Five exact installed-template-name-fix rollback files were verified. To restore
after closing VEGAS/Encoder:

```powershell
.\scripts\Install-VegasEncoder.ps1 -VegasDir 'C:\Program Files\BorisFX\Vegas Pro 2026' -BuildDir "$trial\rollback\plugin" -Update
.\scripts\Start-B6Trial.ps1 -Target Vegas -CandidateRoot "$PWD\build\b6-candidate-0.1.7-template-name-fix"
```

## Immediate large-preset reopen fix (2026-10-16; installed, owner-confirmed)

Capacity 16000 failed at Load → Apply → reopen, before any restart, with
`S-REQUEST, templateName`. The native name is empty at the C4 boundary. The fix
uses the page's captured name, then the validated recipe name, if the native name
is absent. This is display metadata only: native bytes and payload CRC/size
checks stay strict. No host size limit or payload corruption is inferred.

Fresh `build/b6-candidate-0.1.7-template-name-fix` has native SHA-256
`BBB01B74CB88F3CF4A33D0E86B72A9AFC595C1D86DC66E42C8369B3892C606EA`,
unchanged error-ui frontend, copied trial data and exact installed-error-ui
rollback. Same 0.1.7 labels; manifests distinguish the variant by hashes.

The owner installed this candidate and confirms Load → Apply → reopen now works
in real VEGAS. Installed DLL hash matches the candidate. Save/restart and notes
end-marker integrity remain to be checked; no reinstall is needed.

Installation commands retained for reference:

```powershell
Set-Location L:\repos\vegas-encoder-platform
$trial = "$PWD\build\b6-candidate-0.1.7-template-name-fix"
.\scripts\Install-VegasEncoder.ps1 -VegasDir 'C:\Program Files\BorisFX\Vegas Pro 2026' -BuildDir "$trial\plugin" -Update
.\scripts\Start-B6Trial.ps1 -Target Vegas -CandidateRoot $trial
```

Next, save the applied **B6 capacity 16000** as a new disposable VEGAS template,
for example **B6 capacity check**, using VEGAS's template save button. Close VEGAS,
then relaunch with the matching profile:

```powershell
Set-Location L:\repos\vegas-encoder-platform
.\scripts\Start-B6Trial.ps1 -Target Vegas -CandidateRoot "$PWD\build\b6-candidate-0.1.7-template-name-fix"
```

Select that saved template, reopen the editor and check the visible encoding
settings. The popup does not display recipe notes: do not ask the owner to find
the end marker there. Inspect the reopened session's `request.json` directly
for notes integrity instead. Real-host size qualification and the missing native
label's origin remain open; encoder recovery stays deferred.

The latest real-host request, session `EAFB2258-877B-4274-9FBB-D13AA08D8821`,
contains **15,088 UTF-8 bytes** of notes, ending in `END 容量`, exactly matching
the seeded B6 capacity 16000 notes. FFV1/PCM-float/MKV settings are present.
This confirms notes integrity in that reopened request; owner confirmation that
this followed saving and restarting is still pending. Do not infer the complete
persistence sequence or an absolute host capacity from this observation alone.

The owner then confirms the preset is visible and seems to work correctly.
Proceed to the monitor performance comparison below without repeating the notes
request. The exact large-template save/restart sequence remains unconfirmed;
record the functional acceptance and request integrity at their actual scope.

Rollback after closing VEGAS/Encoder:

```powershell
.\scripts\Install-VegasEncoder.ps1 -VegasDir 'C:\Program Files\BorisFX\Vegas Pro 2026' -BuildDir "$trial\rollback\plugin" -Update
.\scripts\Start-B6Trial.ps1 -Target Vegas -CandidateRoot "$PWD\build\b6-candidate-0.1.7-error-ui"
```

The current next check is save/restart/end-marker integrity above.

## Current owner scope and next check (2026-10-16)

The owner approves the error display and explicitly skips the additional
same-session good render after encoder failure. Treat that recovery check as
owner-deferred/unverified; do not repeat the request without a new relevant issue.
Earlier instructions requesting it below are historical, not the current queue.

Use the already applied **B6 capacity 16000** library preset in the installed
`b6-candidate-0.1.7-template-name-fix` trial and save a new
disposable VEGAS template (for example, `B6 capacity check`). Close/restart VEGAS
through the matching launcher, then reopen that template and check visible
settings; inspect the request file for notes integrity as above. No installer update is needed. This checks large snapshots
rather than repeating already confirmed normal-template persistence. Saved bytes
can be checked for the end marker/actual size afterward; one intact sample gives
a tested lower bound, not an absolute host maximum. Use the four-input ladder
below only if this fails or a tighter boundary is needed. Monitor overhead/memory
and installer work follow.

## Prominent persistent error panel (2026-10-16; installed, presentation approved)

The owner installed this variant and says it "looks good." Screenshot and new
failed C6 job `9A1785F2-5243-440D-8C7F-B942F8C807CD` confirm the real-host error
presentation. No subsequent successful render is recorded yet. Next: dismiss the
VEGAS error and monitor, then render the unchanged working template to a fresh
filename without restarting VEGAS. Retention duration/manual dismissal are not
claimed from a screenshot alone. The installation commands below are retained
for reference; no reinstall is needed for this next step.

The owner confirms the native error-fix candidate now reaches VEGAS's own error
dialog. The next candidate improves the bottom-right monitor: a prominent
"Why it failed" cause, no trailing queue warning in the primary panel, immediate
live-error display, long-message scrolling and explicit Close. Failed windows say
"Stays open until you close it" and cancel any previously started countdown.
VEGAS's own generic error dialog is retained; no extra blocking error box is added.

New folder: `L:\repos\vegas-encoder-platform\build\b6-candidate-0.1.7-error-ui`.
Native is the same tested error-fix DLL (`CE46036D…`); frontend executable SHA-256
is `89183626D2F023761B3BA114602D132F573ADA5B51CB126AF18FD09F732F6A7D`.
Version labels remain 0.1.7/0.1.7+1; manifests distinguish this development
variant. Data is copied from the installed error-fix trial. Its exact native,
INI, PDB, install manifest and discovery rollback are under `rollback`; the prior
frontend remains intact in the old candidate folder.

After closing VEGAS and all Encoder windows, the owner installs/launches:

```powershell
Set-Location L:\repos\vegas-encoder-platform
$trial = "$PWD\build\b6-candidate-0.1.7-error-ui"
.\scripts\Install-VegasEncoder.ps1 -VegasDir 'C:\Program Files\BorisFX\Vegas Pro 2026' -BuildDir "$trial\plugin" -Update
.\scripts\Start-B6Trial.ps1 -Target Vegas -CandidateRoot $trial
```

Repeat the disposable invalid-filter recipe with a fresh output filename.
Check that the cause is obvious in the monitor and it stays open until Close
(the title-bar close also works), even after dismissing VEGAS's error. Then render
the unchanged working template to another fresh filename without restarting VEGAS.
Report both filenames/results. New UI is tested with fakes/goldens only until
this owner retest; same-session encoder-failure recovery remains open.

Rollback after closing VEGAS/Encoder:

```powershell
.\scripts\Install-VegasEncoder.ps1 -VegasDir 'C:\Program Files\BorisFX\Vegas Pro 2026' -BuildDir "$trial\rollback\plugin" -Update
.\scripts\Start-B6Trial.ps1 -Target Vegas -CandidateRoot "$PWD\build\b6-candidate-0.1.7-error-fix"
```

The earlier candidate instructions below are retained as historical checkpoints.

## Error-reporting fix candidate (2026-10-16; not installed)

The controlled bad-filter trial produced a failed C6 job, but the monitor showed
a secondary pipe error and VEGAS appeared stuck. Recipe Render opened an unowned
modal error box before returning its failed HRESULT. The revised native candidate
removes that blocking dialog and supplies the concrete FFmpeg diagnostic to the
existing monitor/History. Expected primary text for this test is
`FFmpeg: No such filter: 'vegas_encoder_deliberate_failure'`.

New folder: `L:\repos\vegas-encoder-platform\build\b6-candidate-0.1.7-error-fix`.
The 0.1.7 stamps and unchanged 0.1.7+1 frontend are retained; native DLL SHA-256
`CE46036DC5A7ACC3A296BF91B610A7B04DF6367F3BC6BD7989AA0982FB75D017`
identifies this variant (original installed native starts `0A5D6F74`). Package
manifests record the variant, dirty source and source patch hash. Trial data is
copied separately; exact installed original-0.1.7 rollback is under `rollback`.
This is a development fix candidate, not a new qualified release.

After closing VEGAS and Encoder windows, the owner installs/launches:

```powershell
Set-Location L:\repos\vegas-encoder-platform
$trial = "$PWD\build\b6-candidate-0.1.7-error-fix"
.\scripts\Install-VegasEncoder.ps1 -VegasDir 'C:\Program Files\BorisFX\Vegas Pro 2026' -BuildDir "$trial\plugin" -Update
.\scripts\Start-B6Trial.ps1 -Target Vegas -CandidateRoot $trial
```

Repeat the disposable bad-filter template to a fresh output name. The monitor
should name the missing filter, VEGAS should finish with failure rather than wait
behind a hidden dialog, and no final output should appear. Without restarting
VEGAS, render the unchanged normal template to a fresh name. Report the two names,
the VEGAS result/message and any remaining wait. Also note any focus regression.
Fake-host success does not establish this real-host UI behavior or recovery.

To restore the original 0.1.7, close VEGAS/Encoder and run:

```powershell
.\scripts\Install-VegasEncoder.ps1 -VegasDir 'C:\Program Files\BorisFX\Vegas Pro 2026' -BuildDir "$trial\rollback\plugin" -Update
.\scripts\Start-B6Trial.ps1 -Target Vegas -CandidateRoot "$PWD\build\b6-candidate-0.1.7"
```

The earlier instructions below describe the original 0.1.7 checkpoints.

## Current continuation: 0.1.7 focus fix and remaining owner checks

Installed trial is now **native 0.1.7-recipe-proof / frontend 0.1.7+1** on VEGAS
**2026.0.3.189**, from
`L:\repos\vegas-encoder-platform\build\b6-candidate-0.1.7`.
On 2026-10-16 the owner reports the focus issue "seems like it has been fixed."
The installed native hash matches this candidate, and real-host logs confirm
its native/host versions. Record the reported repro as owner-confirmed fixed;
individual unreported Apply/Cancel/switch-order/background variants are not
separate passes. Next is controlled cancellation/failure recovery below; no
reinstall or repetition of the reported focus repro is needed.
Its trial data is a copy of 0.1.6; original candidates/data/backups are preserved.
The new `rollback` holds the exact installed 0.1.6 set with hashes. The native
parallel startup path is unchanged. Normal distinct-codec templates and restart
persistence are already owner-confirmed; do not repeat those basic qualification
steps. Remaining A5–A7 checks below stay open until tested in real VEGAS.

The close fix samples foreground before enabling the owner and explicitly
activates it before destruction only for foreground closes. With the same probe,
the old frontend failed four of seven cases (accepted foreground Apply/Cancel
exposed another window); the new frontend passes all seven, including both switch
sequences and passive background close. These are **fake-window** results.

### Owner installation and focus retest

Close VEGAS and all trial app/editor/monitor windows, then manually install:

```powershell
Set-Location L:\repos\vegas-encoder-platform
$trial = "$PWD\build\b6-candidate-0.1.7"
.\scripts\Install-VegasEncoder.ps1 -VegasDir 'C:\Program Files\BorisFX\Vegas Pro 2026' -BuildDir "$trial\plugin" -Update
.\scripts\Start-B6Trial.ps1 -Target Vegas -CandidateRoot $trial
```

1. Open an existing working template's editor. Switch to the full-screen app,
   return through VEGAS to the editor, then click **Apply to template**. VEGAS's
   template dialog should remain foreground and usable; the other app must stay
   behind it. Repeat with **Cancel**. Also check a normal foreground close.
2. Repeat with the other full-screen app foreground **before opening** the editor.
   Report the exact route used to open it, then Apply/Cancel and the foreground
   result. An iconic/minimized VEGAS window and one merely covered are different;
   report which was observed if it fails.
3. Check background completion if encountered: another app stays foreground when
   the editor closes. Do not click the editor to manufacture a background close;
   that click would make it foreground. Automated fake-window coverage includes
   this case, but do not call the real-host variant passed unless actually observed.
4. Report any startup regression. Existing `logs\frontend-startup.txt` and native
   timings suffice; no extra tracing. The installed baseline's observed visible
   times were 0.53–0.75 s after process creation, not an exact click-to-visible total.

### Controlled cancellation and failure recovery

**Cancellation/recovery completed on 2026-10-16:** owner reports the requested
sequence worked. Jobs `17E0A52A-F34A-4B9B-A887-9868150ABD49` (cancelled after
605/1470 frames, no publication/retained partial) and
`BD533179-4D29-47B7-B4A1-93C30C4D1FD4` (same recipe hash, succeeded, 1470 frames,
published `unchaed_render.mkv`, passed sampled H.264/AAC readback) support the
result. Same-session operation follows the owner report; cancel-click latency
was not measured. Continue at step 2 below for actual encoder-failure recovery.

The first 0.1.7 cancellation attempt stopped before encoding with "Choose a
default FFmpeg in Vegas Encoder before rendering." Read-only inspection found
the trial's `data/Roaming/machine.json` already selects
`C:\ffmpeg\bin\ffmpeg.exe`, while the normal `%APPDATA%\VegasEncoder\machine.json`
had no installations/default at inspection. This is consistent with launching VEGAS outside
the isolated launcher; it is not a cancellation/recovery result. Close VEGAS
and relaunch with `-Target Vegas -CandidateRoot $trial` above to use trial data.
For ordinary launches, open the desktop app without the trial launcher, select
FFmpeg, add the existing executable if needed and choose **Set as default**.
The trial and ordinary profiles are separate; changing one does not set the other.

Use test copies and fresh `.mkv` filenames; leave working saved templates intact.

1. Use a range long enough to cancel during encoding. Cancel through **VEGAS**,
   note time until the dialog becomes usable, and render the normal template to a
   new name **in the same VEGAS session**. Expect a cancelled C6 job, no successful
   publication, and a successful recovery render. Report a freeze, retained partial
   or child, wrong terminal status, or need to restart.
2. For an actual FFmpeg error, edit a **test copy** of the H.264/MKV recipe and put
   `-vf vegas_encoder_deliberate_failure` in Video → Extra arguments. Apply and
   render a short range to a new name. This is a deliberately nonexistent filter;
   the current core emits it without a blocking issue. Expect an actionable encoder
   failure/failed History record and no published final output. If Apply blocks on
   this machine, report its message; do not bypass validation or alter FFmpeg files.
3. Return to the unchanged normal template and render to another fresh filename
   without restarting VEGAS. Report the failure and recovery output names and any
   displayed message. A preflight refusal alone does not qualify recovery from an
   encoder failure. Never kill VEGAS or corrupt the user's encoder installation.

### Payload capacity, separate from normal persistence

Four isolated library inputs **B6 capacity 4096 / 8192 / 12288 / 16000** are seeded
only into the new candidate's copied trial library. They use FFV1/PCM/MKV with
large inert notes and a UTF-8 end marker; encoding settings stay short and valid.
`capacity\capacity-inputs.json` records their exact **offline** envelope sizes and
notes byte counts. Popup origin metadata may alter the final stored size.

In increasing order, Load preset in the popup, Apply, save a **new disposable VEGAS
template**, reopen, restart through the matching launcher, then reopen it again.
Stop on the first failure; preserve that test template and the last good one, and
report their names/paths and the step. Leave normal templates alone. Existing core
payload decoding can check the saved bytes/end marker once their paths are known.
One short render of the largest intact sample checks that saved settings remain
usable. If all four pass, report **at least the largest measured intact size**, not
an absolute host maximum. The product's 16 KiB draft ceiling is not an established
VEGAS limit; refine the boundary only if needed after this bounded pass.

### Monitor overhead using the existing records

The toggle is in the **separate desktop app**, not the template popup:

```powershell
.\scripts\Start-B6Trial.ps1 -Target App -CandidateRoot $trial
```

Settings → Rendering → **Show a progress window during renders**. Use the existing
six-run comparison below, **on, off, off, on, on, off**, one fixed project/template/
range, a warm-up, fresh filenames and otherwise unchanged settings/load. Close the
desktop app before each run; closing an already-launched monitor does not make an
off run. Send the six output names: C6 `elapsedSec` and phase timings already give
the measurements. Compare on/off medians; inconclusive variation stays inconclusive.
During an on run, also observe the monitor's private memory and working set in Task
Manager (record both, with the PID); the budget is under 120 MB and about 2% time.
Record any visible disturbance. Restore the preferred toggle afterward.

For this candidate all logs/jobs are under `$trial\logs` and `$trial\data\Local\jobs`.
Rollback after closing VEGAS/app windows uses the existing reversible installer:

```powershell
.\scripts\Install-VegasEncoder.ps1 -VegasDir 'C:\Program Files\BorisFX\Vegas Pro 2026' -BuildDir "$trial\rollback\plugin" -Update
.\scripts\Start-B6Trial.ps1 -Target Vegas -CandidateRoot "$PWD\build\b6-candidate-0.1.6"
```

The original discovery file/manifest and `rollback\backup-sha256.json` are retained;
the installer regenerates and verifies its installation manifest. Saved templates
and both trial data roots remain. B7's matched runtime/destination/update inputs
are in [B7_INSTALLER_INPUTS.md](B7_INSTALLER_INPUTS.md).

## Installed 0.1.6 trial record and original procedure

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
5. This normal restart check is now **owner-confirmed** for the tested templates.
   Retain those working templates; only the separate capacity samples above need
   new restart qualification.

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
