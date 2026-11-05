# Native configuration foundation

**Automatic legacy naming, 2026-11-05:** `LegacyAutoNames=1` keeps one original
format and resolves the actual suffix from the selected immutable recipe before
admission. Native page guidance says the suffix is set automatically; modern mode
retains its manual suffix guidance. No C4 schema/popup UI change. The approved
23 trial status is in [STATUS.md](STATUS.md). See [legacy naming](LEGACY_NAMING.md)
for the filename contract.

**Template text compatibility update, 2026-11-05:** current recipe placement
DWORD-aligns the private allocation before name/notes. The native boundary
accepts exact 0–3 zero DWORD padding and
legacy unpadded/one-byte WORD padding; the core envelope/checksum is unchanged.
379 native snapshot/holder and 314 actual-DLL fake-host checks pass. The new DLL
is uninstalled; visual/restart qualification is pending. The historical foundation
record below retains its original proof-build scope.

The measured native bridge and one-checkbox page are wired into a **separate,
opt-in development build**. Installed version is `0.1.2-config-proof`; this current
candidate adds progress-failure handling and awaits real recovery checks.
The default build still reports zero pages. Original tested candidates and the
installed proof are preserved, with verified rollback copies.
Native ownership is established on the specific static copies below; actual
VEGAS Apply/Cancel/save/restart and broader runtime qualification remain open.
This replaceable proof does not select the app framework, product editor, preset
management or final settings schema; the design boundary is in `DESIGN_GATE.md`.

## Native ownership contract

The page copies the incoming template and scalar settings. The holder returns
an independently owned template copy that must be freed through the matching
host allocator. Writes copy the complete replacement without taking ownership
of the caller's buffer. Host allocation stays separate from C++ allocations.

## Offline implementation and checks

`src/settings/diagnostic_settings.h` defines one portable boolean. The owned
draft helper edits only 12 reserved bytes in a recognized 64-byte VENC marker,
leaving all other template, private, and text bytes intact. Untouched 0.1.0-dev
markers load the false default. Unknown/future/partial proof markers and invalid
boolean values are rejected. This provisional `CFG1` proof region is not the
future A7 recipe envelope; exporter presets do not emit it.

`src/vegas/configuration/proof_page.*` implements a COM page with one native
checkbox. Its private in-process `IProofTemplateStore` seam returns owned copies
and commits by copy. The offline factory uses the fake store. The native factory
queries the measured holder through `native_store.*`, copies/validates every
returned template and releases it exactly once through the retained host
allocator, then commits an owned buffer synchronously. The page rejects calls on a
different thread; the harness binds, activates, deactivates and releases it on
its creator thread. No marshaling or concurrent-use support is claimed.
The host must deactivate and perform final Release on that UI thread while a
page window is active. Normal deactivation/destruction clears dialog userdata
before destroying the HWND. A defensive off-thread destruction check proves that
userdata is detached even though Windows requires the creator thread to destroy
the remaining window; that case is not supported native lifecycle behavior. The
recorded host page creation, callbacks and final Release share thread 41420.

The first real `0.1.0-config-proof` page attempt displayed the tab with an empty
body. Its dialog was created hidden and Activate never showed it. On the exact
host copy above, the container obtains an inset parent-client rectangle and calls
Activate at `0x2EA718`–`0x2EA757`, without a separate Show call there. The matching
connector explicitly invokes Show(1) during activation at `0x8AC5`–`0x8AD0`.
Version `0.1.1-config-proof` checks positioning and shows the fully initialized
page during Activate; later Show/Hide remains supported. Failed window creation
or positioning cannot return S_OK when Windows supplies no error code.

Apply prepares a new owned copy and marks the draft clean only after a successful
commit. An unapplied draft survives tab deactivation, then disappears on object
disconnect or page destruction. A previously successful Apply remains committed.
Failed query/load/rebind/Apply preserve the original draft and references.
The source and scalar initialization data are owned copies. Current legacy
64-byte markers load false. In the proof build, Create snapshots the value;
when true it adds `configuration_proof: {extra_report: true, proof_version: 1}`
to the existing `.vegas-encoder.json` sidecar. No encoding format changes.

Build and focused checks from the product checkout:

```powershell
cmd /d /c scripts\etc\build.cmd
cmd /d /c scripts\etc\build-configuration-proof.cmd
.\build\host-tests\native-configuration.exe
.\build\host-tests\host-helpers.exe
.\build\host-tests\native-boundary.exe
.\scripts\etc\Test-ConfigurationProof.ps1 -OutputDir build\test-results\configuration-proof-new
```

Both default and opt-in x64 C++17 `/W4 /WX` builds pass. The corrected opt-in build
passes 67 configuration checks,
24 host-helper checks and 9 exception-boundary checks. Configuration coverage
includes owned-byte round-trip/two-template isolation, malformed/future payloads,
unapplied cancellation/prior Apply, failure retry, COM identity/reference balance,
thread rejection, rectangle overflow, and repeated activation. The visibility
regression checks fail three times on the old implementation and pass after the
fix: initial visibility without a separate Show call, effective visibility under
a shown parent, and reactivation. Inset positioning, control containment, valid
Move geometry and Hide/Show are also covered. This unit harness uses native
Windows controls without loading a connector/DLL.
The focused fake-host suite loads the proof DLL, edits its native page, saves and
reloads owned bytes, then calls Create without a fresh conform. On/off values
each pass two decoded 90-frame/144,000 stereo sample-frame renders. Cancellation
and encoder-failure cases preserve the proof value in diagnostics, balance locks,
leave no child/partial output and publish no final file. Output is under
`build/test-results/configuration-proof-visibility-fix/`. Default-DLL discovery also
confirms zero pages, under `build/test-results/default-discovery-native-1/`.
These are fake-host checks,
not real VEGAS qualification.

The current foundation suite passes 11 cases / 20 render attempts, including
seven stop-then-success pairs in the same loaded DLL. It covers cancellation,
both progress slots failing with E_ACCESSDENIED, failures at video/audio Submit,
the initial Finish poll, and existing-destination refusal; successful recovery
outputs are decoded. Failed jobs retain the original HRESULT, publish no output,
balance host objects/locks and leave no child/partial file. The existing destination
is preserved. Audio Submit injection waits for the fake audio-read counter; asserted
phase counts rule out queue repolls triggering the error in another phase. This
does not force a finalization stall or prove a strict Abort deadline. Output is in
`build/test-results/foundation-recovery-qualified-phases/`.

## Remaining real-host proof

Build artifact: `build/configuration-proof/vegas-encoder/vegas-encoder.dll`,
version `0.1.2-config-proof`; DLL SHA-256
`CA876E05CA4ED6D8A2A84529A573577716CEA650B74384D7B9ED19F4D578EA45`.
The matching DLL/PDB/INI are preserved for review in
`build/candidate-0.1.2-config-proof/`; normal builds do not overwrite that copy.
It is now installed with matching DLL/PDB/INI/discovery manifest and user approval.
The previous real-tested `0.1.1-config-proof` DLL was
`A644B62650B729918EAEF54DBCE24F488F6280753DE283BE645199862BB13FD8`,
and is backed up in `build/rollback-before-foundation-closeout/` with its manifest/
discovery configuration and restoration instructions. Its candidate is intact.
The original real-render-tested candidate hash remains
`9FE5587A49F7A65AE3DC62DBB54D6B4AB392B67447D1D21C9DDC307325EEF5B2`.
The previous `0.1.0-config-proof` installation is saved in
`build/rollback-before-page-visibility-fix/`; restore it with the product installer's
`-Update -BuildDir build/rollback-before-page-visibility-fix` while VEGAS is closed.
The original working installation is saved in `build/rollback-before-configuration-proof/`;
all preserved candidates remain intact. Host/sharedk/FFmpeg and other discovery
configs are unchanged. The old proof displayed a blank page. The user's corrected
build on/off renders now confirm that only `diagnostic_on.mkv.vegas-encoder.json`
contains the configuration-proof section. Both renders report S_OK, encoder exit
zero, publication and zero outstanding locks in the same VEGAS 2026.0.3.189
session. The same three output file types are expected in both cases; no extra
standalone report is generated. These new reports were inspected without decoding
the media. Actual saved-template reopen/restart and Cancel semantics remain open.
Restore with the product installer `-Update -BuildDir build/rollback-before-configuration-proof`
while VEGAS is closed. Current-build real cancellation/recovery now passes in one
host session, with the recovered 299-frame / 478,878-sample output decoded.
Controlled real error recovery remains unverified.

The user deferred the real two-template/restart test (steps 2–3 below). Keep this
procedure for later product qualification; do not repeat that request as a
foundation prerequisite. On a deliberately installed proof build in VEGAS 2026.0.3.189:

1. In Render As, choose Vegas Encoder's lossless template and Customize. Confirm
   the single checkbox page opens repeatedly and its parent/thread behavior works.
   Check **Include extra diagnostic report**, then close with Cancel. Reopen and
   confirm the unapplied edit was discarded.
2. Check it and accept/apply, save a named template **Config proof A**, then reopen
   it. Save **Config proof B** with the opposite value. Reopen both independently;
   an accepted Apply must survive later unapplied edits/cancellation. If the host
   offers no separate Apply button, record its actual OK/Cancel behavior instead
   of inventing that workflow.
3. Exit and restart VEGAS. Select A and render a short clip, then select B and
   render to a different path. A's `.vegas-encoder.json` must contain the extra
   `configuration_proof` object; B's must omit it. Inspect final Create bytes as
   well as the dialog. Reopen A/B again and test changed project defaults.
4. Repeat a normal render, cancel and recover, trigger an encoder/destination
   failure and recover; verify balanced frame locks, no surviving encoder/partial
   output and no published cancelled/failed media. Retain useful diagnostics and
   exact host/DLL identities. The fake test separately covers Create from saved
   bytes without a new conform; real host sequencing still needs observation.
5. Exit VEGAS and restore the recorded previous installation if the proof build
   fails or the temporary qualification installation is no longer wanted.

If page hosting fails, capture only the product call sequence, HRESULTs and
window/thread context needed to reproduce it; no broad SDK reconstruction is
needed. Persistence, real Apply/Cancel and controlled error recovery remain
qualification limits. Implementation closes at the user's requested foundation
commit; app-design branch review is explicitly left for next time.

## Generic COM documentation

Microsoft documents object/site references and page lifecycle, but these sources
do not define VEGAS template ownership. Context7 was resolved first; its Win32 API
index had no matching documentation after the three-command lookup limit, so the
current primary pages were read directly. The later visibility lookup similarly
returned unrelated Context7 entries, so Activate and Show were read directly:

- [SetObjects](https://learn.microsoft.com/en-us/windows/win32/api/ocidl/nf-ocidl-ipropertypage-setobjects)
  requires retained object/interface references and releasing them on disconnect.
- [Apply](https://learn.microsoft.com/en-us/windows/win32/api/ocidl/nf-ocidl-ipropertypage-apply)
  commits current page values to associated objects.
- [Activate](https://learn.microsoft.com/en-us/windows/win32/api/ocidl/nf-ocidl-ipropertypage-activate)
  and [Deactivate](https://learn.microsoft.com/en-us/windows/win32/api/ocidl/nf-ocidl-ipropertypage-deactivate)
  establish page-window creation/destruction responsibilities.
- [Show](https://learn.microsoft.com/en-us/windows/win32/api/ocidl/nf-ocidl-ipropertypage-show)
  defines the supported Show/Hide commands. The initial self-show behavior above
  comes from the measured VEGAS hosting path.
- [PROPPAGEINFO](https://learn.microsoft.com/en-us/windows/win32/api/ocidl/ns-ocidl-proppageinfo)
  specifies task-allocated title ownership.
- [OnStatusChange](https://learn.microsoft.com/en-us/windows/win32/api/ocidl/nf-ocidl-ipropertypagesite-onstatuschange)
  describes notification of edited values.
