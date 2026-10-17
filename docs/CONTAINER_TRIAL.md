# Focused owner trial: container naming and rendering

Prepared and owner-authorized installation completed 2026-10-18 (Asia/Singapore).
**Installed and file-verified; active test queue closed at owner direction.**
On 2026-10-18 the owner confirms checking all five containers and correct values
passed to VEGAS. MP4/MOV/WebM renders have the actual checks recorded below.
The remaining MXF render/MKV regression are owner-skipped, not passed; the separate
two-container template restart is unconfirmed. The checklist below is historical
reproduction guidance, not a request for further owner tests. Do not resume it
without new owner direction.
This trial covers the retained multi-container feature only. It does not resume
the owner-deferred encoder-failure recovery, faster-progress or performance trials.
The owner operates VEGAS; installation requires explicit owner authorization.

## Candidate and exact rollback

- Host: `C:\Program Files\BorisFX\Vegas Pro 2026\vegas2026.exe`,
  **2026.0.3.189 x64**. Other detected hosts are not trial targets.
- Candidate: `L:\repos\vegas-encoder\build\release-inputs-containers-dashboard`.
  Native **0.1.7-recipe-proof**, app **0.1.7+1**, numeric PE **0.1.7.1**.
  These labels match earlier trials; distinguish the variant by native SHA-256:
  `9799B6CD65528101788658F4CCE59354BC8BAC6D4796A6670D0A18D2D0266707`.
  `installer-inputs.json` records checkpoint `c8e6e39` plus uncommitted source
  (`sourceDirty:true`), file hashes and `releaseQualified:false`.
- `rollback/files.json` records five hash-checked, exact installed files:
  DLL, INI, PDB, installed manifest and root discovery file. The saved INI still
  points to the retained platform template-name-fix app/log paths. Nothing was
  moved from or written into that live candidate or its data.
- New isolated `data/Roaming/machine.json` copies the prior trial's selected
  user-supplied **FFmpeg 5.1.2** identity. The progress window was initially disabled;
  it is **now enabled at owner request** (isolated C7 revision 7). This does not
  start the deferred performance-comparison trial. Five validated presets named **Container trial - MKV / MP4 / MOV /
  WEBM / MXF** are in its library. No active sessions, old render history,
  capacity media or build caches were copied.

## Before the owner test

Installation was explicitly authorized and completed; VEGAS was launched with this
isolated profile. The following commands are retained for reproduction, **not a
request to reinstall**. On any repeat, close VEGAS and all Encoder windows first:

```powershell
Set-Location L:\repos\vegas-encoder
$trial = 'L:\repos\vegas-encoder\build\release-inputs-containers-dashboard'
.\scripts\Install-VegasEncoder.ps1 `
  -VegasDir 'C:\Program Files\BorisFX\Vegas Pro 2026' `
  -BuildDir "$trial\plugin" -Update
.\scripts\Start-B6Trial.ps1 -Target Vegas -CandidateRoot $trial
```

The development installer requests elevation and refuses changed/unrecorded
installed files. Do not force past a refusal. The launcher checks the installed
DLL hash and sets the isolated data root for that VEGAS process and its popups.
The candidate app must remain at the prepared path while installed.

## Owner checklist

Use a disposable short timeline at **1920×1080, square pixels, 30 fps** (about
three seconds) with video and stereo audio. Use fresh destination names in a
writable test folder. P010 delivery and existing native media restrictions remain.

1. In **Render As**, confirm Vegas Encoder is listed. Open its settings and Load
   **Container trial - MP4**, then Apply to template/native Apply. Observe the
   default filename suffix and file-type filter. Switch to MOV and WEBM and
   observe whether the suffix/filter follows; repeat with a saved template.
   If VEGAS leaves an old suffix, report that exact sequence. Do not rename
   already-rendered bytes to make the result appear correct.
2. Render one short output for each prepared preset. Use the matching final
   extension even if VEGAS leaves a stale filename, and report that UI limitation.
   This covers:

   | Preset | Output | Video/audio |
   | --- | --- | --- |
   | Container trial - MKV | `.mkv` | FFV1 / float PCM regression |
   | Container trial - MP4 | `.mp4` | H.264 / AAC, faststart |
   | Container trial - MOV | `.mov` | ProRes HQ / 24-bit integer PCM |
   | Container trial - WEBM | `.webm` | Advanced VP9 / Opus |
   | Container trial - MXF | `.mxf` | DNxHR HQ / 16-bit integer PCM |

   Keep the final output files and tell the agent their paths. The agent will
   inspect the actual SetFile/log/C6 destinations and decode/probe the outputs.
   A successful dialog alone is not the output qualification.
3. Save two disposable VEGAS templates using different containers (for example
   MP4 and MOV), close/restart with the same launcher, then select each. Confirm
   its independent settings, suffix/filter behavior and one short render each.
   This is a normal two-container template test, not the deferred large-template
   capacity/restart sequence.
4. Open the candidate app with the same profile if you want to review Settings:
   `Start-B6Trial.ps1 -Target App -CandidateRoot $trial`. **VEGAS integration**
   should report this installed exporter and its covered file hashes, plus older
   detected hosts separately. Expand paths/details and press Refresh. Shared app/
   runtime integrity and current-build host compatibility remain separate claims.

No deliberate encoder-failure, cancellation, capacity or monitor/performance
retests are requested. Stop if a new failure would require unrelated diagnosis;
retain the exact message/path and return it to the agent.

## Restore the prior installed trial

Close VEGAS and all candidate app/popup windows. From an elevated PowerShell:

```powershell
Set-Location L:\repos\vegas-encoder
$trial = 'L:\repos\vegas-encoder\build\release-inputs-containers-dashboard'
$vegas = 'C:\Program Files\BorisFX\Vegas Pro 2026'
.\scripts\Install-VegasEncoder.ps1 -VegasDir $vegas `
  -BuildDir "$trial\rollback\plugin" -Update
# Restore the exact old manifest as well as the old DLL/INI/PDB/discovery bytes.
Copy-Item -LiteralPath "$trial\rollback\plugin\install-manifest.json" `
  -Destination "$vegas\FileIO Plug-Ins\vegas-encoder\install-manifest.json"
.\scripts\Start-B6Trial.ps1 -Target Vegas `
  -CandidateRoot 'L:\repos\vegas-encoder-platform\build\b6-candidate-0.1.7-template-name-fix'
```

Afterward compare the five installed hashes to `rollback/files.json`; they must
match exactly. The old platform candidate, old isolated data/logs, and previous
rollback files remain in place throughout. Preserve both trial folders until the
owner accepts the result. The finished installer remains the owner's work.

## Current result

Offline implementation and candidate checks pass (STATUS). The authorized update
completed, installed hashes/manifest/app paths verify, and VEGAS was launched with
the isolated container profile. Owner confirms that VEGAS updates the filename
to `.mp4`. Two initial attempts failed: an existing destination was preserved,
then a modified default H.264/float-PCM recipe failed because FFmpeg 5.1.2 cannot
mux that PCM codec in MP4. The prepared MP4 trial preset uses AAC instead.
During those failed attempts the progress window was disabled; actionable error
text is present in C5/C6 but was not shown by VEGAS's generic HRESULT dialog.
The owner requested the progress window enabled and then left VEGAS error-text
integration separate. Progress is enabled for subsequent renders; no native
error-interface investigation or deferred performance comparison is requested.

The owner subsequently rendered MP4 successfully after switching audio to AAC.
Job `C24475AA-4C26-420B-9D5C-C4E1C5D81795` published
`C:\Users\Samuel Tee\Desktop\test_video\test_mp4.mp4` with S_OK and sampled
verification passed. Agent full video/audio decode succeeds; readback is 182 video
frames, 1920×1080 at 30000/1001 fps, H.264 10-bit 4:2:0 plus 48 kHz stereo AAC.
This modified-default recipe had faststart enabled; box inspection confirms
`moov` at byte 32 before `mdat` at byte 8106. The remaining results and later owner
decision to close the test queue are recorded below.

The owner also confirms MOV rendered correctly. Job
`0DA59B34-CD66-4153-A21B-08267D4CA81E` publishes
`C:\Users\Samuel Tee\Desktop\test_video\test_mov.mov`; full video/audio decode
passes. Readback: ProRes **LT**, 10-bit 4:2:2, 1920×1080 at 30000/1001 fps,
182 frames, 48 kHz stereo 24-bit PCM, 6.073 seconds. The recipe was the owner's
modified default; this does not qualify the prepared HQ preset or every profile.
The owner also completed WebM. Job `67F333E0-FE7A-4024-A9EA-BCB27C14E98E`
published `C:\Users\Samuel Tee\Desktop\test_video\test_vp9.webm`; FFmpeg exit 0,
sampled verification passed, terminal C5 done at 182/182 frames. Agent full
video/audio decode passes. Readback: VP9 Profile 2, 10-bit 4:2:0, 1920×1080,
30000/1001 fps, 182 frames, 48 kHz stereo Opus, 6.080 seconds, 726,231 bytes.
The owner's structured modified default used VP9 CRF 31 / deadline good and
Opus 192 kb/s with `-f webm`; this does not qualify the prepared Advanced realtime
preset. FFprobe reports the shared Matroska/WebM demuxer family and cannot by
itself distinguish those two identities.
The owner subsequently confirms all-container values passed to VEGAS and closes
the test queue. MXF render/MKV regression are owner-skipped; two-container restart
remains unconfirmed. Fresh installer inputs including the Profile-list refinement
are ready at `build/release-inputs-profile-list`; next is the owner's installer
build, not another render request. That newer bundle is not installed.
The later owner-requested ProRes Profile-list UI refinement is source/build only;
the installed candidate and its rollback are preserved.
Record the actual build/host and each checklist result before closing that gate.
