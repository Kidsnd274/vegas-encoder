# Fixed-profile encoding baseline

The initial product preserves the tested source transport: explicit external FFmpeg
process, independent byte-pipe writers, owned job/process and bounded video/audio
queues. P010 is packed after validating the delivered frame; host locks are released
before waits. Audio uses cumulative rational sample endpoints and fills valid short
reads. Final S_FALSE data is consumed. Frame/sample bytes travel through pipes;
arguments carry input descriptions, profile and destination.

Profile: FFV1/yuv420p10le plus optional PCM float32 stereo, Matroska. Expected fixture:
320x180 at 30/1, 90 frames, 144,000 stereo sample frames, onsets 48,000 and 96,000.
Fractional fixture at 30000/1001 uses 144,144 sample frames. The checker verifies
container timestamps within Matroska's time-base resolution and compares decoded
fake media to its raw diagnostic reference.

The suite generates its project template from authored Python. A synthetic template
and fake reader model our interpretation; passing them is not a native ABI proof.
No ignored host capture or research checkout is needed. Queue high-water checks,
encoder exit, no published partial output, process cleanup and destination preservation
are verified for the selected fake cases. Formal shutdown bounds under a stalled
client and real-host backpressure/cancel still need qualification.

Existing destination is refused. Completed output is published after input EOF and
encoder exit zero; cancel/failure removes temporary output. The diagnostic schema
`ffbridge-diag/1` is kept for checker compatibility. New product sidecar suffix is
`.vegas-encoder.json`; stderr suffix remains `.ffmpeg.log`.

Run `scripts/etc/Test-VegasEncoder.ps1` with a fresh evidence directory, explicit Python/
FFmpeg paths if necessary, and optional `-Include1080p`. Inspect its identities,
commands, per-case logs/manifests and decoded checker output. Finalize real-host
qualification separately using [VEGAS_RUNTIME.md](VEGAS_RUNTIME.md).
