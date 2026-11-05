# Experimental exporters for VEGAS 22, 21 and Sony 13

The three Windows x64 trials use the same recipe core, settings page and render
loop with separate native adapter builds.

| Target | Build |
| --- | --- |
| VEGAS Pro 22 | 248 |
| VEGAS Pro 21 | 108 |
| Sony VEGAS Pro 13 | 453 |

Render As displays a .vencoder placeholder. The selected recipe supplies the
actual output extension. The release build produces fresh per-host DLLs from
the same source. Setup uses its matching bundled app and selects the DLL for
the exact host build. The historical trial packages below remain rollback
references.

## First owner-operated test

Prepared bundle `build/test-results/older-vegas-20261105-163430530/`.
All three exact candidates were installed with owner authorization on
2026-11-05 and verified at 19:25 SGT. The DLLs, INIs and PDBs match the
bundle hashes and installation manifests. The discovery mappings also
verify. See `install-verification.json` in the bundle. Runtime tests are pending.

| Package | DLL SHA-256 | Offline results |
| --- | --- | --- |
| `vegas22/plugin` | `9E89B2A076E50CE67CE9BB50C35E7684C3EB628CF933B1CB9918058ADD2137CD` | Pass |
| `vegas21/plugin` | `C3EC1EB38915DEA0C40CEC6B49691985172F99A3B31CB9797A95644D0939B4C1` | Pass |
| `vegas13/plugin` | `8C7F90161644D9905FAA8AC795B15F0B14BA35CC8276BB2848DDC5D101530AF4` | Pass |

Each profile passed 464 checks against the actual DLL, 179 linked-render checks
over fake host streams with real FFmpeg, and rejection of a differently named
host process. The actual DLLs also ran from exported class factory through
template conformance and Render. FFprobe decoded 24 H.264 frames and AAC audio
from each resulting MP4. The first smoke harness omitted project conformance
and hit the expected missing-audio-format rejection. Adding conformance to the
harness resolved it using the same DLLs. Exact-byte fake installs and manifest
rollback passed for all three. The modern native regression suite passed.

Start testing with 22 build 248, followed by 21 and 13. Package preflight
confirmed all three product discovery and plug-in paths were vacant.
The installer owns only `VegasEncoder-x64.fio2007-config` and
`FileIO Plug-Ins/vegas-encoder` under each selected host root. Rollback uses its manifest-based
`-Uninstall` on the same root with the host closed.

The 22 rollback command from the product root is:

```powershell
$bundle = 'L:/repos/vegas-encoder/build/test-results/older-vegas-20261105-163430530'
$vegas22 = 'L:/Program Files/VEGAS/VEGAS Pro 22.0'
& "$bundle/Install-VegasEncoder.ps1" -VegasDir $vegas22 -Uninstall
```

Use the bundle's `Start-OlderVegasTrial.ps1 -Major 22` to
check installed hashes and open the host with an isolated Vegas Encoder profile.
That profile already selects the tested FFmpeg and stores trial jobs separately.

Import the prepared `trial-input.mp4` into a disposable project at 320×180,
30 fps, with stereo 48 kHz audio. Render all three seconds with a built-in
H.264/MP4 starter and a fresh basename. Record discovery, template names,
settings page visibility, the path displayed at completion and whether Open
works. The fixture has 90 video frames and an audible marker track. The first
qualification check is a decoded output and the corresponding native log.

If discovery works but the render fails, collect the log from that profile's
trial folder before changing settings. The render loop currently expects P010
video and float32 audio. Actual format negotiation, template persistence,
completion reporting and cancellation still need real host runs on each build.
Sony 13 is especially uncertain because its P010 delivery has yet to be measured.

## VEGAS 22 popup update

The 22 build 248 exporter was updated in place with owner authorization. Its
INI now points to the dedicated popup app in the new bundle. The existing
isolated data, FFmpeg, and logs are reused. The installed DLL, INI, and PDB
match the staged hashes and the discovery file matches its previous hash.
The candidate passed 464 actual-DLL checks and 179 linked-render checks with
fake host streams and real FFmpeg. The staged app's core passed 246 FFI checks.
The Container warning and first real render are pending owner testing.

Launch with the new bundle's hash-checking launcher from the product root:

```powershell
$bundle = 'L:/repos/vegas-encoder/build/test-results/vegas22-popup-update-20261105-193904036'
& "$bundle/Start-OlderVegasTrial.ps1" -Major 22
```

To restore the previous 22 candidate, close VEGAS 22 and run:

```powershell
$bundle = 'L:/repos/vegas-encoder/build/test-results/vegas22-popup-update-20261105-193904036'
$vegas22 = 'L:/Program Files/VEGAS/VEGAS Pro 22.0'
& "$bundle/Install-VegasEncoder.ps1" -VegasDir $vegas22 -BuildDir "$bundle/rollback/plugin" -Update
```

The rollback directory also contains the original install manifest and discovery
file. The original bundle's launcher applies again after restoring its candidate.

## VEGAS 21 and Sony 13 reinstall

The original 21 and 13 candidates were reinstalled with owner authorization on
2026-11-05. The DLL, INI, PDB and discovery hashes verified for both hosts.
The 21 reinstall had changed `vegas210.exe`. The current executable has a valid
MAGIX signature and reports build 108. Its kernel and FileIO proxy match the
original trial inputs. All three Sony 13 build 453 host inputs still match.
Existing discovery files in both installations matched their preinstall hashes.

The owner reports the VEGAS 21 trial passed after the x86 runtime repair.
Sony 13 starts and reaches Render with the H.264 (CPU) template. The exporter
resolves the filename, then stops on first-frame validation. Detailed evidence
lives in the private investigation repository. Sony 13 still needs a successful
render before Setup integration.

Use the refreshed launcher from the product root. It checks the current host
hashes and points to each trial's existing isolated data and logs.

```powershell
$trial = 'L:/repos/vegas-encoder/build/test-results/older-vegas-reinstall-20261105-213340265'
& "$trial/Start-OlderVegasTrial.ps1" -Major 21
# Use -Major 13 for Sony VEGAS 13.
```

To remove either trial, close its host and run the corresponding command.

```powershell
$bundle = 'L:/repos/vegas-encoder/build/test-results/older-vegas-20261105-163430530'
& "$bundle/Install-VegasEncoder.ps1" -VegasDir 'L:/Program Files/VEGAS/VEGAS Pro 21.0' -Uninstall
& "$bundle/Install-VegasEncoder.ps1" -VegasDir 'C:/Program Files/Sony/Vegas Pro 13.0' -Uninstall
```

## Rebuild

Run [Build-OlderVegasTrials.ps1](../scripts/etc/Build-OlderVegasTrials.ps1)
with an existing staged app and a local FFmpeg/FFprobe pair. The script creates
a fresh folder under `build/test-results` and builds in 22, 21, 13 order. Each
profile's `plugin` folder holds the candidate. The `checks` folder holds the
authored fake host and fake kernel used for testing.
