"""Self-test for Check-RawRender.py using synthetic ffbridge diagnostic output.

Renders the exact fixture pixels from scripts/Make-BaselineMedia.py (90 frames,
320x180) into the layouts the exporter writes, plus a float32 stereo WAV with
the fixture bursts, a manifest and a frames CSV. Cases:
  p010        P010 top-down, limited-range BT.709 luma      -> must PASS
  p010-scaled P010 at 960x540 (x3) with padded row stride    -> must PASS
  bgra-flip   BI_RGB 32-bit bottom-up rows                  -> PASS, flip detected
  dup-frame   P010 with frame 45 replaced by frame 44       -> frame index FAILS
  audio-shift P010 with audio delayed by 100 samples        -> audio onsets FAIL
Standard library only.

Usage: python -I scripts/Test-Check-RawRender.py [OUTDIR] [--keep]
OUTDIR defaults to a new folder under
evidence/checker-selftest/checker-selftest/. Raw video files are
deleted after a passing run unless --keep is given.
"""
import argparse
import array
import csv
import datetime
import hashlib
import importlib.util
import json
import math
import os
import pathlib
import struct
import sys

HERE = pathlib.Path(__file__).resolve().parent
W, H, FRAMES, RATE, FPS = 320, 180, 90, 48000, 30.0


def load(name):
    spec = importlib.util.spec_from_file_location(name.replace("-", "_").removesuffix(".py"), HERE / name)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


checker = load("Check-RawRender.py")
fixture = load("Make-BaselineMedia.py")


def fixture_rows(frame):
    """Top-down rows of 3-byte BGR pixels from the real fixture generator."""
    bmp = fixture.bitmap(frame)
    pixels, row = bmp[54:], W * 3
    return [pixels[(H - 1 - y) * row:(H - y) * row] for y in range(H)]


def p010_frame(frame, lut={}):
    out = bytearray()
    for r in fixture_rows(frame):
        for i in range(0, len(r), 3):
            key = r[i:i + 3]
            v = lut.get(key)
            if v is None:
                b, g, rr = key
                y8 = 16 + 219 * (0.2126 * rr + 0.7152 * g + 0.0722 * b) / 255
                v = lut[key] = struct.pack("<H", round(y8 * 4) << 6)
            out += v
    out += struct.pack("<H", 512 << 6) * (W * H // 2)   # interleaved UV, H/2 rows of W samples
    return bytes(out)


SCALE, PAD = 3, 64   # p010-scaled case: nearest-neighbour x3 with padded rows


def p010_scaled_frame(frame):
    src = p010_frame(frame)
    stride = W * SCALE * 2 + PAD
    out = bytearray()
    for y in range(H):
        row = src[y * W * 2:(y + 1) * W * 2]
        wide = b"".join(row[i:i + 2] * SCALE for i in range(0, len(row), 2)) + bytes(PAD)
        out += wide * SCALE
    uv_row = struct.pack("<H", 512 << 6) * (W * SCALE) + bytes(PAD)
    out += uv_row * (H * SCALE // 2)
    assert len(out) == stride * H * SCALE * 3 // 2
    return bytes(out)


def bgra_bottom_up_frame(frame):
    rows = fixture_rows(frame)
    return b"".join(b"".join(r[i:i + 3] + b"\xff" for i in range(0, len(r), 3)) for r in reversed(rows))


def audio_samples(shift):
    a = array.array("f", bytes(4 * RATE * 3 * 2))
    amp = 12000 / 32767
    for ch, start, freq in ((0, RATE, 1000), (1, RATE * 2, 500)):
        for n in range(480):
            a[(start + shift + n) * 2 + ch] = amp * math.cos(2 * math.pi * freq * n / RATE)
    return a


def write_wav(path, samples):
    data = samples.tobytes()
    frames = len(samples) // 2
    fmt = struct.pack("<HHIIHHH", 3, 2, RATE, RATE * 8, 8, 32, 0)
    body = (b"WAVE" + b"fmt " + struct.pack("<I", len(fmt)) + fmt
            + b"fact" + struct.pack("<II", 4, frames) + b"data" + struct.pack("<I", len(data)) + data)
    pathlib.Path(path).write_bytes(b"RIFF" + struct.pack("<I", len(body)) + body)


def make_case(root, name, kind, dup=None, shift=0):
    d = root / name
    d.mkdir(parents=True)
    base = d / "test.ffdiag"
    scaled = kind == "P010-scaled"
    kind = "P010" if scaled else kind
    make = p010_scaled_frame if scaled else p010_frame if kind == "P010" else bgra_bottom_up_frame
    w, h = (W * SCALE, H * SCALE) if scaled else (W, H)
    stride = w * 2 + PAD if scaled else w * 2
    sums, frame_bytes = [], None
    with open(str(base) + ".video.raw", "wb") as f:
        for i in range(FRAMES):
            data = make(dup[1] if dup and i == dup[0] else i)
            frame_bytes = len(data)
            sums.append(hashlib.blake2b(data, digest_size=8).hexdigest())   # stand-in for FNV-1a64
            f.write(data)
    samples = audio_samples(shift)
    write_wav(str(base) + ".audio.wav", samples)
    per_frame = RATE // int(FPS)
    with open(str(base) + ".frames.csv", "w", newline="", encoding="utf-8") as f:
        cw = csv.writer(f)
        cw.writerow("frame,video_hr,get_ms,token_handle,token_cb,token_alloc,token_offset,token_mode,lock,"
                   "cb_out,info_index,checksum,audio_pos,audio_req,audio_got,audio_hr,audio_ms".split(","))
        for i in range(FRAMES):
            cw.writerow([i, "0x00000000", "1.250", "0x000032D4", frame_bytes, frame_bytes, 0, 1,
                        f"0x{0x120C140000 + i:X}", frame_bytes, 0, sums[i], i * per_frame, per_frame,
                        per_frame, "0x00000000", "0.300"])
    rgb = kind != "P010"
    manifest = {
        "schema": "ffbridge-diag/1",
        "plugin": {"name": "ffbridge", "version": "selftest", "dll": None, "dll_sha256": None},
        "host": {"exe": "synthetic", "version": None, "pid": os.getpid()},
        "render": {"index": 1, "status": "ok", "returned_hresult": "0x00000000", "stop_reason": None,
                   "stop_hresult": None, "elapsed_ms": 1000.0},
        "files": {"manifest": base.name, "video": base.name + ".video.raw", "audio": base.name + ".audio.wav",
                  "frames_csv": base.name + ".frames.csv"},
        "template": {"cb_struct": 0x218, "name": name, "preset_id": 0, "render_fourcc": kind,
                     "render_width": w, "render_height": h, "render_bit_count": 32, "fps": FPS,
                     "audio_format_code": 0x20, "audio_rate": RATE, "audio_channels": 2, "audio_block_align": 8},
        "video": {"present": True, "frame_count_reported": FRAMES, "frames_written": FRAMES,
                  "frame_bytes": frame_bytes, "fourcc": kind, "width": w, "height": h,
                  "bit_count": 32 if rgb else 24, "fps": FPS, "pixel_aspect": 1.0,
                  "plane_fields": [w * 4, 0, 0, 0, 0, 0] if rgb else [stride, stride * h, stride, 0, 0, 0],
                  "first_frame_info_hex": "", "frame_info_changes": 0, "frame_size_changes": 0,
                  "token_mode": 1, "locks_outstanding": 0},
        "audio": {"present": True, "format_code": 0x20, "sample_rate": RATE, "channels": 2, "block_align": 8,
                  "wav_format": "ieee_float32", "samples_written": len(samples) // 2,
                  "samples_expected": RATE * 3, "reads": FRAMES, "short_reads": 0,
                  "stream_length_reported": None},
        "progress": {"total_set": FRAMES, "non_ok": []},
        "probes": [],
        "timing_ms": {"total": 1000.0},
    }
    base.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return base


def status(rep, name):
    r = rep.get(name)
    return r["status"] if r else None


def main():
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser()
    ap.add_argument("outdir", nargs="?")
    ap.add_argument("--keep", action="store_true", help="keep the synthetic raw video files")
    a = ap.parse_args()
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    root = pathlib.Path(a.outdir) if a.outdir else (
        HERE.parent / "evidence" / "2026-10-10-diag-exporter" / "checker-selftest" / f"run-{stamp}")
    root.mkdir(parents=True, exist_ok=False)
    failures = []

    def expect(case, cond, what):
        print(f"{'ok ' if cond else 'BAD'} {case}: {what}")
        if not cond:
            failures.append(f"{case}: {what}")

    def run(case, manifest, **kw):
        rep = checker.check(str(manifest), fixture=True, **kw)
        (manifest.parent / "check-result.json").write_text(json.dumps(rep.as_dict(), indent=2), encoding="utf-8")
        return rep

    rep = run("p010", make_case(root, "p010", "P010"), png_dir=str(root / "p010" / "png"))
    expect("p010", not rep.failed, "no FAIL results" + ("" if not rep.failed else
           f" ({[r['check'] for r in rep.results if r['status'] == 'FAIL']})"))
    expect("p010", rep.summary.get("orientation") == "top-down", f"orientation {rep.summary.get('orientation')}")
    expect("p010", status(rep, "fixture: frame index") == "PASS", "frame index PASS")
    expect("p010", "p010le" in (rep.ffmpeg or "") and "30" in rep.ffmpeg, "ffmpeg command uses p010le")
    expect("p010", len(list((root / "p010" / "png").glob("*.png"))) == 3, "3 PNGs written")

    rep = run("p010-scaled", make_case(root, "p010-scaled", "P010-scaled"))
    expect("p010-scaled", not rep.failed, "no FAIL results at 960x540 with padded stride" + (
        "" if not rep.failed else f" ({[r['check'] for r in rep.results if r['status'] == 'FAIL']})"))
    expect("p010-scaled", "stride 1984" in rep.get("video: pixel layout")["detail"], "stride from plane_fields")

    rep = run("bgra-flip", make_case(root, "bgra-flip", "BI_RGB"))
    expect("bgra-flip", not rep.failed, "no FAIL results" + ("" if not rep.failed else
           f" ({[r['check'] for r in rep.results if r['status'] == 'FAIL']})"))
    expect("bgra-flip", rep.summary.get("orientation") == "bottom-up", f"orientation {rep.summary.get('orientation')}")
    expect("bgra-flip", "vflip" in (rep.ffmpeg or "") and "bgra" in rep.ffmpeg, "ffmpeg command uses bgra + vflip")

    rep = run("dup-frame", make_case(root, "dup-frame", "P010", dup=(45, 44)))
    expect("dup-frame", status(rep, "fixture: frame index") == "FAIL", "frame index FAIL")
    expect("dup-frame", "45" in rep.get("fixture: frame index")["detail"], "mismatch names index 45")
    expect("dup-frame", "1 at [45]" in rep.get("csv: consecutive identical checksums")["detail"],
           "identical checksum reported at 45")
    expect("dup-frame", status(rep, "fixture: audio onset L") == "PASS", "audio unaffected")

    rep = run("audio-shift", make_case(root, "audio-shift", "P010", shift=100))
    expect("audio-shift", status(rep, "fixture: audio onset L") == "FAIL", "onset L FAIL")
    expect("audio-shift", status(rep, "fixture: audio onset R") == "FAIL", "onset R FAIL")
    expect("audio-shift", status(rep, "fixture: frame index") == "PASS", "video unaffected")

    if not failures and not a.keep:
        for raw in root.glob("*/*.video.raw"):
            raw.unlink()
    print(f"\n{'SELFTEST PASSED' if not failures else 'SELFTEST FAILED'} ({len(failures)} failure(s)); output {root}")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
