# B5: native progress text on the selected VEGAS build

Static effects established; the authorized slot-4 trial ran on VEGAS 2026.0.3.189.
The control and repeated text-test renders completed normally; full decode checks
pass for the control and final text-test output. Slot-4 calls returned S_OK, but
the owner saw no switching text. **Drop the custom status-line track**, per the
owner's preference; prioritize useful numeric progress and the separate window.
This does not pass A5–A7, real two-template/restart persistence, controlled real
failure recovery or monitor performance.

## Exact implementation and provenance

Read-only inspection of the installed `vegas2026.exe`, file version
`2026.0.3.189`, x64, SHA-256
`2B93C6613E1BDD4A435B65F63E3FC0B0EAD9EDB06B45F2458C43B63F784A73AF`
matches [TARGET.md](TARGET.md). PE image base is `0x140000000`; all addresses
below are **RVAs**, independent of ASLR. No binary was loaded for this analysis.

F-026/F-027 supply the `ISfProgress` IID and parameter widths. The earlier F-031 /
F-041 capture identifies the progress supplied to Render as
`.?AVCSfRenderProgress@@`, vtable RVA `0xAAD890` (investigation's
`evidence/2026-10-10-diag-exporter/capture-analysis/vt173.txt`, lines 35–39).
The current executable's complete-object RTTI at `0xB3C148`, type descriptor at
`0xCAE990`, independently confirms that class and zero subobject offset. The
product build/tests do not depend on that investigation checkout.

| Slot | RVA | Established effect on this class |
| --- | --- | --- |
| 3 `(LPCWSTR, LONGLONG)` | `0x263D30` | Stores the supplied pointer at object `+0x28`, sets total at `+0x18`, resets position at `+0x20` to zero, returns S_OK |
| 4 `(LPCWSTR)` | `0x263D50` | Stores the supplied pointer at `+0x28`, returns S_OK; leaves total/position unchanged |
| 5 `SetTotal` | `0x642A0` | Sets total at `+0x18` and clamps existing position at `+0x20` to that total |
| 6 `SetPosition` | `0x263D80` | Clamps/stores position and calculates numeric progress; returns the recorded cancel HRESULT when the cancel bit is set |
| 7 `CheckCancel` | `0x263D60` | Returns S_OK or `0x8004E00C` from the same cancel bit |

Slot 3 is initialization with text and a total; **it is unsafe as a repeating
text update because it resets progress**. Slot 4 is the text-only setter. Neither
text method copies, allocates, frees, dispatches a message, draws a control or
checks cancellation. Retain the numeric names in the ABI: these are recovered
effects, not original SDK method names. Exact setter bodies:

```text
slot 3: mov [rcx+28h],rdx; xor eax,eax; mov [rcx+18h],r8;
        mov qword ptr [rcx+20h],0; ret
slot 4: mov [rcx+28h],rdx; xor eax,eax; ret
```

**Text is borrowed beyond the setter call.** A local `wstring.c_str()`, reused
formatting buffer or stack array is insufficient. The probe uses only immutable
module-lifetime literals, with no mutation, cleanup call or deallocation after
Render. The host render path creates the 0x30-byte object at `0x265459–0x2654A7`,
initializes the text pointer to null, passes it to Render at `0x26550C`, and releases
it after Render at `0x265709–0x265714`. No new AddRef or worker reference is needed.

## What consumes the text, and what is still unknown

The internal helper beginning at `0x264220` reads the retained text at `0x264667`
and stores it at `+0x50` of a stack `Scripting::RenderStatusEventArgs` object. RTTI
identifies event vtables at `0xAAD960` / `0xAAD988`. The final secondary-interface
getter (`0x2638C0`, vtable slot 14) copies that field as a string from subobject
`+0x48`. The helper dispatches event kind `0x0C` through `0x4A21A0` at `0x264685`,
subject to the host's scripting/event gates.

The installed primary scripting reference
`C:/Program Files/BorisFX/Vegas Pro 2026/ScriptPortal.Vegas.xml`, lines 5824–5864,
lists the corresponding fields and describes `Description` as the render window
title. Thus the retained value has a render-description/title role in the
scripting event path; that is not proof that the interactive render dialog shows
a custom status line.

The public `SetPosition` path (`0x263D80–0x26421B`) never reads this class's text
field. Its event record explicitly has a null description at `0x2641B6`. Only the
internal helper forwards the pointer. **Do not call the internal vtable slot 9**:
it is outside the recovered nine-slot interface, and its calling/lifetime/UI
contract has not been qualified. No host memory, event sink or dialog is patched.
Whether the normal interactive render invokes the helper and displays the text
is the owner test's question. A successful setter HRESULT proves only a store.

Reproduce the narrow byte/RTTI/consumer checks with standard-library Python:

```powershell
python -I scripts/Inspect-VegasProgress.py --host 'C:\Program Files\BorisFX\Vegas Pro 2026\vegas2026.exe'
```

Optional `--dumpbin <existing-dumpbin.exe>` prints the two setter bodies. The
script rejects changed host bytes rather than applying old offsets to a new
build. Inspect further functions with that tool's `/RANGE` and `/DISASM`; no
disassembler library or machine-wide tool installation was added.

## Opt-in candidate

```powershell
cmd /d /c 'scripts\build.cmd "" progress-text-proof'
scripts/Test-B5.ps1 -SkipBuild -HostPath 'C:\Program Files\BorisFX\Vegas Pro 2026\vegas2026.exe'
scripts/Prepare-B5StatusLine.ps1 -OutputDir build/b5-owner-review -FFmpegPath 'C:\ffmpeg\bin\ffmpeg.exe'
```

Preparation creates three separate DLL/PDB/INI candidates and `review.json` with
their SHA-256 identities under a fresh worktree `build/` directory. It runs no
installer and changes no user preferences. The candidate identifies itself as
`0.1.3-progress-text-proof`, preserves the native configuration-proof page, and
uses the existing fixed FFV1/PCM path. B6 recipe/template/monitor wiring remains
gated. The default DLL has no text-probe code/configuration reads.

`B5ProgressText` is read once from the candidate INI at DLL setup:

| Value | Test behavior |
| --- | --- |
| absent / `0` / invalid | No text calls |
| `4` | Alternates `Vegas Encoder B5: text marker A` and `... B` through slot 4, at most once per 500 ms |
| `3` | Calls slot 3 once, after ordinary SetTotal and before any frame acquisition, with the same known frame total and marker A; never uses it for updates |

Modes 3/4 require the exact executable version/hash **and** the actual inspected
vtable/setter addresses. A wrapper or other class is rejected. Hash polling uses
ordinary caller-thread progress/cancel checks before acquiring a frame. The
helper checks caller thread and zero outstanding locks on every text call.
It allocates no text, launches no process, writes no live file and never waits
for the app or monitor. Text failures (including a text-only cancel HRESULT or
C++ exception) disable further text calls; ordinary SetPosition/CheckCancel still
decide the render's failure/cancellation. The synchronous setter itself cannot
be forcibly timed out; the inspected bodies are simple stores. Record any real
stall and drop the feature, without moving host calls to a worker.

Logs record mode/target eligibility, text call count, last HRESULT, maximum call
time in milliseconds and any thread/lock guard failure. The normal manifest
retains numeric progress, output, cancellation and lock diagnostics. No formatted
FFmpeg statistics are claimed by this marker test; add them only after visible
behavior and retained-string lifetime are qualified.

## Owner checklist — authorized trial reference

The owner authorized candidate replacement and the observed VEGAS trial on
2026-10-14, with this correction: **retain a healthy candidate; rollback only if
issues occur.** This supersedes the unconditional restoration step in the original
checklist. The owner subsequently ended the custom-text track after the slot-4
observation; no further marker/mode-3 trial is requested. The checklist remains
the operational reference, not a claim that every qualification step passed.

1. Review the uncommitted source diff, focused results and staged `review.json`.
   Confirm the intended FFmpegPath/log location in each candidate INI. Keep the
   default build and owner candidates separate from edited fake-test directories.
2. Verify the exact host fingerprint with the inspection script. Check the current
   installed manifest and all its recorded DLL/PDB/INI/discovery hashes. During
   preparation the DLL still matched `CA876E05CA4ED6D8A2A84529A573577716CEA650B74384D7B9ED19F4D578EA45`;
   all three payloads matched the preserved
   `L:\repos\vegas-encoder\build\candidate-0.1.2-config-proof` rollback candidate.
   Recheck before an update. If state drifted, stop and prepare an exact backup;
   do not override installer refusals. Successful installer updates discard their
   temporary previous-install copy, so the separately preserved rollback matters.
3. Close VEGAS. Install the **mode-0** candidate with the reversible installer and
   restart VEGAS. Use the working fixed-profile template and a fresh MKV path.
   Render a repeatable range, record result/duration/numeric progress, inspect
   zero locks/encoder cleanup and decode the output. This is the same-build
   no-text control; no popup/monitor is launched.
4. Close VEGAS. Update to **mode-4**, restart and render the same range to a fresh
   output. Choose a range that keeps rendering for at least a few seconds so both
   A/B markers can be attempted. Confirm `exactTarget=1`, positive text calls,
   `guardFailed=0` and S_OK in the B5 log. Watch for a changing status line,
   a title change, no visible effect, flicker, focus changes or a stall. Record
   which control changes; a screenshot is useful only to locate the text.
   Numeric progress must keep advancing. Decode and compare counts/timing with
   the control. A null-description/public-poll path may produce no visible text.
5. In that mode/session, cancel a longer render, inspect unpublished output,
   removed owned partial/child and zero locks, then render a short range again.
   Record actual cancellation response and both HRESULTs. A prior 0.1.2 pass
   does not qualify this candidate. Do not infer controlled failure recovery
   from this cancellation check.
6. If useful to distinguish initialization behavior, separately update/restart
   into **mode-3** and repeat the normal render. Expect exactly one text call,
   the correct total and no subsequent numeric resets. Do not combine modes or
   call slot 3 repeatedly. Stop immediately on broken progress or a stall.
7. Keep the status line only if the real render shows useful text without
   disturbing rendering/cancellation. A scripting description or title alone
   does not meet the selected status-line design. If absent/useless or unsafe,
   drop the status-line track and record the observed outcome. Do not enable
   it in production solely because S_OK or fake checks passed.
8. Retain the healthy tested candidate, per the owner's authorization. If issues
   occur, close VEGAS and restore the recorded working 0.1.2 candidate; verify
   installer hashes, restart and run one normal render. Preserve a concise
   outcome: candidate DLL/INI identities, exact host, text location/behavior,
   B5 log summary, normal/cancel/recovery outputs and rollback verification.
   Detailed diagnostics are needed only for a failure/ABI ambiguity.

After authorization, use the chosen staging directory from `review.json`:

```powershell
# Example; substitute the actual reviewed mode directory.
scripts/Install-VegasEncoder.ps1 -VegasDir 'C:\Program Files\BorisFX\Vegas Pro 2026' -Update -BuildDir 'L:\repos\vegas-encoder-platform\build\b5-owner-review\mode-0'
# Repeat with mode-4 (and optionally mode-3), closing/restarting VEGAS each time.
# Only if issues occur: restore the verified prior build, with VEGAS closed:
scripts/Install-VegasEncoder.ps1 -VegasDir 'C:\Program Files\BorisFX\Vegas Pro 2026' -Update -BuildDir 'L:\repos\vegas-encoder\build\candidate-0.1.2-config-proof'
```

Do not edit the live INI between trials: its manifest hash would drift. These
tests neither enable B6 nor measure a monitor. The separate owner performance
rule remains three real renders with/three without the monitor, about 2% maximum
render-time cost and under 120 MB, after gated B6 wiring is ready.

## Authorized trial results and owner decision

- Installation of mode 0 completed using the reversible installer. DLL/PDB/INI
  and discovery hashes match the reviewed candidate/installation manifest. The
  prior 0.1.2 DLL/PDB/INI still match the separate preserved rollback candidate.
  Operational installer records are under ignored
  `build/test-results/b5-host-trial-3cea0e12/`.
- Exact host: VEGAS **2026.0.3.189**, PID **38892**; native log identifies
  `0.1.3-progress-text-proof`, DLL
  `BB3447D10A689895DB8A7652B8397F8B62F03A79BD0CE3D44F8022AECC4F72BF`.
- Owner rendered `C:/Users/Samuel Tee/Desktop/test_video/test_b4.mkv` from
  `test.veg` and reports normal completion with steadily advancing progress.
  Native return S_OK, encoder exit zero/publication, **182** 1920x1080 frames at
  **30000/1001**, **291,491** float32 stereo sample frames at **48 kHz**, zero
  outstanding locks. Elapsed native render time **3998.7 ms** is a single control
  observation, not a throughput/performance qualification.
- Full decode/readback checks pass: FFV1 10-bit, PCM float, complete frame/sample
  byte counts and presentation timing. Audio/video duration difference is about
  **0.004 ms**. B5 summary: zero text calls and no guard failure, as intended for
  mode 0. No counter/click fixture or cross-render pixel identity is claimed.
- VEGAS exited after a normal close request. The first mode-4 elevation request
  was cancelled before installation. The owner authorized a retry; mode 4 is now
  installed and DLL/PDB/INI/discovery hashes match review. In VEGAS PID **30000**,
  the owner rendered `b5_text_2.mkv` and `b5_text_2.mkv.mkv` in the same desktop
  directory. Both returned S_OK, encoder exit zero/publication, **182** frames,
  **291,491** sample frames and zero outstanding locks; elapsed **3880.6 ms** and
  **3954.0 ms**. Both logs show `exactTarget=1`, **8** slot-4 calls, S_OK,
  `maxCallMs=0`, `guardFailed=0`. These short runs do not qualify performance.
- Full decode/readback of the final `b5_text_2.mkv.mkv` passes the same counts,
  formats and timing checks as the control; audio/video duration difference is
  about **0.004 ms**. The first text-test output has native completion diagnostics,
  not a separate full-decode qualification. No cross-render pixel identity is
  claimed.
- Owner reports no apparent text switching; the supplied screenshot shows the
  normal render dialog at 76%, with no marker. This supports **no useful visible
  status line in this trial**, not a general claim that the host can never consume
  the retained description. The owner explicitly does not need dialog text
  changes and wants somewhat accurate progress. End B5 custom-text testing;
  mode 3 and this candidate's cancellation/recovery were not tested.
- Keep the healthy mode-4 proof candidate installed under the owner's policy;
  no rollback or further install was performed. Retire the optional text calls in
  a future reviewed normal update. The installed fixed-profile proof does not
  launch the frontend monitor or use B4's recipe/C5 progress bridge.
  A5–A7, controlled real failure recovery, deferred persistence and monitor
  performance remain **unverified**.
