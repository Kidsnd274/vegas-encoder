# Vegas Encoder

Native VEGAS Pro Render As exporter with an external FFmpeg encoding engine.
The product includes its internal VEGAS adapter; a separate SDK is deferred.
Research provenance is in [ORIGIN.md](ORIGIN.md).

**Current implementation:** independent Windows x64 development build. Internal
ABI declarations, checked template/frame-lifetime helpers, render adapter, encoder,
diagnostics, fake host, synthetic fixtures and output checkers are implemented.
The first profile is P010 → lossless FFV1, with optional float32 stereo → PCM float,
in MKV. The raw diagnostic mode is a developer comparison tool.

**Qualification:** builds and generated fake-host/FFmpeg checks are tracked in
[STATUS.md](docs/STATUS.md). Vegas Encoder has not been installed or run in VEGAS.
The predecessor's real-host result does not validate this newly built DLL. Saved
recipe presets, property pages, desktop editor and rich popup UI remain later work.

## Build and validate

Requirements: Windows x64, MSVC x64 C++17 tools plus Windows SDK, PowerShell 7,
Python 3.9+, and FFmpeg/FFprobe. No research checkout, captured `.tpl`, Voukoder
installation or downloaded binary is required for build/fake tests. This machine's
existing tool locations can be overridden; FFmpeg is user-supplied.

```powershell
cmd /d /c scripts\build.cmd
.\build\host-tests\host-helpers.exe
.\build\host-tests\native-boundary.exe
python -I scripts\Test-Check-RawRender.py evidence\checker-selftest-new
.\scripts\Test-VegasEncoder.ps1 -EvidenceDir evidence\proof-new -Include1080p
.\scripts\Test-Install.ps1 -EvidenceDir evidence\install-smoke-new
```

Use a fresh evidence directory each run. If needed, pass `-PythonPath` and
`-FFmpegPath` to Test-VegasEncoder. FFprobe must sit beside FFmpeg. The build script
accepts the path to `vcvars64.bat` as its first argument, or the
`VEGAS_ENCODER_VCVARS` environment variable, or an existing x64 developer prompt.
Its default recognizes the existing local VS installation on L:; it does not require
that location on other machines. Build outputs and generated media are ignored.

Test-VegasEncoder generates its own synthetic host template. It verifies decoded
fixtures, three repeated renders, fractional timing, short audio reads, video-only,
cancel before/mid/end, encoder errors, destination preservation, Unicode paths,
optional 1080p and deliberate checker rejection. Fake tests establish consistency,
not VEGAS compatibility. See [encoding baseline](docs/ENCODING_BASELINE.md).

## Layout

| Path | Responsibility |
| --- | --- |
| `src/vegas/abi` | Recovered host declarations with evidence annotations |
| `src/vegas/host` | Checked template bytes and frame/reference lifetime helpers |
| `src/vegas/adapter` | Discovery, identities, templates and host render orchestration |
| `src/engine` | External encoder, pipes, queueing, exit and cleanup |
| `src/support` | Diagnostics and exception boundaries |
| `tests/host`, `tests/fiohost` | Helper checks and stand-in host |
| `config/vegas-encoder.ini` | Development defaults copied beside the built DLL |
| `scripts` | Build, fixtures, validation and explicit reversible installer |

Engine source includes no VEGAS native headers. Host calls remain on Render's
caller thread; encoded frames are copied/released before transport waits.
The diagnostic JSON schema remains `ffbridge-diag/1` for existing checker compatibility;
DLL/INI/log/sidecar names and product IDs are independently Vegas Encoder.

## Review and real-host testing

Read [architecture](docs/ARCHITECTURE.md), [adapter plan](docs/ADAPTER_PLAN.md),
[integration contract](docs/INTEGRATION_CONTRACT.md), and
[real-host procedure](docs/VEGAS_RUNTIME.md). Primary target: Boris FX VEGAS Pro
2026.0.3.189 x64; identity in [TARGET.md](docs/TARGET.md).

The explicit installer uses `FileIO Plug-Ins\vegas-encoder` and a separate
`VegasEncoder-x64.fio2007-config`. It preserves the proof exporter's installation.
Configure the built INI before installation. Hash-changed installed files, including
the INI, or unrecorded files cause update/uninstall refusal; config-preserving upgrades
are a future policy. No real installation is performed by the test commands above.

No project license has been selected, and no commit or remote publication is automatic.
