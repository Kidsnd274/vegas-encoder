# Render fixes test checklist

Scope: the seven commits after `510b417` through `db938ba`. This supplements
[the 0.2.1 real-VEGAS checklist](FIX_PLAN_0.2.1.md#9-lead-integration-and-release).

## Priority 1 — end to end in VEGAS Pro

Use VEGAS Pro **2026.0.3.189** first, with the app and exporter from the same
candidate build. Use a disposable output directory and an approved trial
installation with rollback available. Record the candidate commit, exact host,
FFmpeg and SVT-AV1 versions, and GPU/driver for hardware runs. Start with the
known failing combination, FFmpeg N-128435 with SVT-AV1 4.3.0. Probe the FFmpeg
installation in the desktop app and set it as default. Open a square-pixel
1080p project with moving video and audible stereo audio. Use a long enough
timeline to switch windows while a successful render is running.

1. [ ] Open **AV1 4Mb/s Smol** in Presets, or create a Basic SVT-AV1 preset with
   **Target bitrate** and **Peak bitrate** both set to **4000 kb/s**. Expect
   `V-PEAK-UNSUPPORTED` under Peak bitrate and in Checks. Save and reopen to
   verify the peak survives. In VEGAS **Render As**, open the Vegas Encoder
   template editor, select the preset, and Apply. The template accepts it and
   the compiled command includes `-b:v 4000k` and `-maxrate 4000k`.
2. [ ] Render to a new filename. Start timing when FFmpeg begins. With the
   known failing build, expect VEGAS to return a render error within a few
   seconds of the encoder diagnostic, well before the normal stall timeout.
   Leave Cancel alone for this run. The progress window says **Render failed**,
   stays open, and shows
   `FFmpeg: Svt[error]: Max Bitrate only supported with CRF mode`. **Show in
   History** opens the same Failed job with the same reason, and **Show log**
   reveals the FFmpeg log. The saved job record has `ffmpegExitCode: -22` and
   `hresult: "0x80004005"`. Verify FFmpeg exits and no final output is published.
3. [ ] Clear Peak bitrate, save and reapply, and render the same project in the
   same VEGAS session. Expect normal progress and a successful History entry
   with the actual output path. Use FFprobe to verify AV1, the expected video
   dimensions and duration, and an audio stream. Play the output through the
   end or decode both streams to verify video and audio.
4. [ ] While the successful render runs, leave the progress window **unpinned**
   and click VEGAS, including its render dialog. The progress window stays
   above VEGAS without taking focus. Switch to an overlapping normal window
   such as Notepad. Notepad stays in front and covers the overlapping area.
   Switch back to VEGAS and check the progress window rises again. Pin it and
   switch to Notepad again. The progress window stays above Notepad. Unpin it
   and switch away and back once more. If two displays are available, repeat
   with VEGAS on the second display and check bottom-right placement at that
   display's DPI.

Record elapsed time, the job record and the FFmpeg log for any unexpected
result. On another FFmpeg build, a peak-rate render can succeed if its SVT-AV1
accepts the options. Keep the known failing build for step 2.

## Priority 2 — focused checks

| Check | Action and expected result |
| --- | --- |
| SVT-AV1 Video Extra | Clear the Peak bitrate field and put `-maxrate 4000k -bufsize 8000k` in **Video Extra**, keeping Target bitrate at 4000 kb/s. Expect the warning on Video Extra. Save and Apply succeed with the options intact. The known failing build reports the same prompt failure. |
| SVT-AV1 controls | With the same project and FFmpeg, try **Constant quality** with `-maxrate 4000k -bufsize 8000k` in Video Extra. Expect no peak warning and a successful render. Run the Advanced template variant with `-b:v 4000k -maxrate 4000k -bufsize 8000k` and confirm the same failure and exit code as Basic mode on the known failing build. |
| HEVC defaults | For x265 and HEVC NVENC, start with a recipe with neither depth nor profile set. Expect a compiled 10-bit input and `main10`. Explicitly select 8-bit with Profile left at its default. Expect `main` and an 8-bit result. Read back `profile` and `pix_fmt` with FFprobe. For NVENC, use a GPU capable of HEVC 10-bit. Also switch to HEVC from a recipe with explicitly selected 8-bit and confirm the selection survives. |
| x265 rejected profiles | Select 10-bit with `main`, then `main444-8`. Expect `V-PROFILE-DEPTH` to block Save and Apply in Basic mode. Repeat through Video Extra with `-profile:v main` and `-profile:v main444-8`. Select Main 10 and confirm Save, Apply and render succeed. |
| NVENC explicit profiles | Set 8-bit with explicit Main 10. Expect `V-PROFILE-LABEL` and Save and Apply still available. On the RTX 5070 Ti test configuration, FFprobe should report Main 10 with an 8-bit pixel format. Try explicit Main with 10-bit. On that same configuration the render should succeed and FFprobe should report Main 10 with 10-bit pixels. |
| Cancel | Cancel a healthy render from VEGAS while it is still encoding. Expect Cancelled in History and no final file. Use the automated suite for the timed cancellation and fatal-exit cases. |

## Automated checks before the host session

Run from the checkout root, with `VEGAS_ENCODER_FFMPEG` pointing to the known
failing FFmpeg and its matching FFprobe alongside it. Use the configured Flutter
and Python executables if they are outside PATH.

```powershell
.\scripts\Build-Release.ps1 -Action Build
cmd /d /c scripts\etc\Test-CoreNative.cmd
.\scripts\etc\Test-B4.ps1 -Asan
.\scripts\etc\Test-LegacyContainers.ps1 -FFmpegPath $env:VEGAS_ENCODER_FFMPEG
.\app\tool\spikes\run_window_spikes.ps1 -Checks monitor -ApplicationPath .\build\release\vegas-encoder\app\VegasEncoder.exe
Push-Location app
try { flutter test } finally { Pop-Location }
```

- [ ] Core tests cover command generation and validation. Flutter tests cover the
  warning with the native core and fake services, plus light and dark goldens.
  Review any golden diffs.
- [ ] B4 uses a fake host with real FFmpeg and controlled fake children. Check
  fatal-with-EOF preserves the child exit code, a stuck child hits the five-second
  fallback, cancellation before a terminal failure stays Cancelled, and ordinary
  warnings allow the render to finish. The legacy-container runner also exercises
  the actual adapter with fake host streams and real FFmpeg.
- [ ] The monitor probe uses a fake VEGAS window and a separate foreground
  process. Run it on an interactive desktop. Log the second-monitor case as
  skipped if only one display is available.

### Rate-control matrix

```powershell
python -I scripts/etc/Test-RateControlMatrix.py --encoders libsvtav1 libx265 hevc_nvenc
```

This runs the real core and FFmpeg on generated input. Review `summary.json`
with FFprobe present. Check codec profile and pixel format individually.
Run `--encoders hevc_qsv` on an Intel Quick Sync machine when available and
record unavailable hardware as skipped.

- The current runner counts the known SVT-AV1 Target bitrate plus peak rejection
  as a mismatch because it collects only profile warnings. On SVT-AV1 4.3.0,
  confirm the peak rows are rejected for the documented reason and confirm
  `V-PEAK-UNSUPPORTED` in the core or editor. Investigate any other mismatch.
- The runner tries both depths for the first rate-control mode and only the
  default depth for the remaining modes. It also supplies depth explicitly in
  every row. Exercise any missing 8-bit Target bitrate and CBR combinations
  separately before claiming coverage, and use the HEVC defaults check above
  to exercise an unset depth.
- The current B4 and actual-adapter SVT cases assume any FFmpeg listing
  `libsvtav1` will reject the settings with this exact message and exit code.
  Use the known failing build for those assertions. Before treating a failure
  of the test on another build as a transport regression, check whether FFmpeg
  accepts the options or emits a different diagnostic.
