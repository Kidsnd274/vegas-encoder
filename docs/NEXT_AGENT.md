# Next agent: native configuration foundation

Use the updated [AGENTS.md](../AGENTS.md): focused checks and concise progress
summaries, without a per-task research ledger or mandatory experiment archives.

The user authorized continuing the **xhigh** agent through the integration
foundation. The user now reports the app design is complete on another branch;
`origin/product-ui-design` is present but has not been merged here. They deferred
real two-template/restart testing. Current closeout stops at the requested Git
checkpoint; review the design only in a later app implementation stage. Do not select a UI framework or
build presets/rich editor/product workflows in this foundation task. See
[design gate](DESIGN_GATE.md).

The installed 0.1.0-dev candidate completed its first real VEGAS render:
`C:/Users/Samuel Tee/Desktop/test_video/vegas_encoder_test.mkv`. Decoded checks pass:
182 frames at 1920x1080 / 30000/1001, FFV1 10-bit, and 291,491 float32 stereo sample
frames at 48 kHz. S_OK, encoder exit zero, publication and zero outstanding locks;
duration difference about 0.004 ms. This is real footage, not the counter/click
fixture, so frame identity/perceptual sync and a same-run byte oracle are untested.

The manifest identifies DLL `9FE5587A49F7A65AE3DC62DBB54D6B4AB392B67447D1D21C9DDC307325EEF5B2`
on VEGAS 2026.0.3.189. The initially empty process log is now complete; there is
no established logging regression.

Legacy FFmpeg Bridge was removed. Its research/source remain available, and its
installation is backed up under `build/retired-ffbridge-2026-10-11/`. Vegas Encoder,
external FFmpeg, host and other discovery configs are unchanged. A live legacy
installation is unnecessary unless a specific comparison later calls for it.

The **xhigh** subagent resolved native ownership on the known copies and wired a
minimal page into a separate `0.1.0-config-proof` DLL. Its sole effect is an optional
configuration-proof section in the existing sidecar. Both build modes pass; 60
configuration, 24 helper and 9 boundary checks pass, plus decoded fake-host on/off,
save/reload/Create-without-conform, repeat, cancel and encoder-failure cases.
The default build has zero pages; the proof build is now installed. The tested
baseline is preserved, with its old installation backed up for rollback.

The first real proof UI displayed a blank body because Activate left its dialog
hidden and VEGAS did not separately call Show. The `0.1.1-config-proof` fix now
shows the initialized page during activation. Its 67 configuration checks include
three visibility regressions reproduced before the fix; the fake-host suite
passes again. That corrected candidate was installed and verified at
`build/candidate-0.1.1-config-proof/`. Previous proof files are backed up in
`build/rollback-before-page-visibility-fix/`, and the original working build is
still in `build/rollback-before-configuration-proof/`.

Real corrected-build renders `diagnostic_on.mkv` / `diagnostic_off.mkv` now show
the expected presence/absence of the JSON configuration-proof section. Both
report S_OK, encoder exit zero, publication and zero outstanding locks in the
same host session. File counts are intentionally identical. Media was not decoded
in this check; restart persistence and Cancel semantics have not been established.
The latest installed candidate is `build/candidate-0.1.2-config-proof/`, DLL
`CA876E05CA4ED6D8A2A84529A573577716CEA650B74384D7B9ED19F4D578EA45`.
It corrects generic progress errors being reported as cancellation and preserves
their HRESULT through video/audio Submit and Finish. All 11 configuration/fake-host
cases (20 attempts) pass, including seven same-loaded-DLL stop/recovery pairs;
successful recovery outputs decode correctly. The default `0.1.1-dev` build passes
the existing baseline suite. The user approved installation; the current payloads
match this tested candidate. The prior `0.1.1-config-proof` is preserved in
`build/rollback-before-foundation-closeout/`; host/sharedk/FFmpeg/other configs
are unchanged.
The user's real cancel/recovery check now passes on this candidate in one host
session: no cancelled MKV/partial/child or locks remain, and the following render
decodes to 299 1080p frames and 478,878 stereo sample frames. Controlled real
failure/recovery remains unverified; see [VEGAS_RUNTIME.md](VEGAS_RUNTIME.md).
The user's deferred persistence check is a qualification limit, not a renewed
request for them to run it. The user now requested the foundation changes be
committed and expressly deferred reviewing the app-design branch to next time.
Stop at that checkpoint; do not review or merge the branch in this task.
Use existing native captures read-only; generic COM docs alone do not establish
FileIO ownership. Unknown contracts need a precise small capture procedure and
useful offline scaffolding, not guessed production wiring. Keep the installed-tested
`build/candidate-0.1.0-dev/` unchanged; no automatic install or commit.

The product still needs controlled real failure/recovery qualification; normal
renders and cancellation/recovery now pass. Use [adapter plan](ADAPTER_PLAN.md)
and [runtime procedure](VEGAS_RUNTIME.md); rich desktop UI and preset catalog stay later.

To restore the legacy exporter for a deliberate comparison, close VEGAS and copy
the saved flat DLL/PDB/INI/manifest to
`C:/Program Files/BorisFX/Vegas Pro 2026/FileIO Plug-Ins/ffbridge/`, and its saved
`FfBridge-x64.fio2007-config` to the host root, with administrator rights and verified
backup bytes. Keep Vegas Encoder intact.
