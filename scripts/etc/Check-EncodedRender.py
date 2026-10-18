#!/usr/bin/env python3
"""Decode the fixed FFV1/float-PCM proof and check real output against its manifest.

Requires the explicitly selected ffmpeg/ffprobe. Optional --reference-manifest
compares decoded packed P010 and float samples exactly to a raw diagnostic run.
No media is overwritten; use a new --out-dir for each check.
"""
import argparse
import copy
from fractions import Fraction
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys


def load_raw_checker():
    path = Path(__file__).with_name("Check-RawRender.py")
    spec = importlib.util.spec_from_file_location("raw_checker", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def run(args, log):
    result = subprocess.run([str(a) for a in args], capture_output=True, timeout=120)
    log.write_bytes(result.stderr)
    if result.returncode:
        raise ValueError(f"{args[0]} exited {result.returncode}; see {log}")
    return result.stdout


def digest(path, offset=0, length=None):
    h = hashlib.sha256()
    with path.open("rb") as f:
        f.seek(offset)
        while length is None or length > 0:
            b = f.read(min(length, 1 << 20) if length is not None else 1 << 20)
            if not b:
                break
            h.update(b)
            if length is not None:
                length -= len(b)
        if length not in (None, 0):
            raise ValueError(f"truncated reference: {path}")
    return h.hexdigest()


def check(manifest, ffmpeg, ffprobe, out, fixture=False, reference=None):
    raw = load_raw_checker()
    m = json.loads(manifest.read_text(encoding="utf-8-sig"))
    rep = raw.Report(str(manifest))
    out.mkdir(parents=True, exist_ok=False)
    try:
        video, audio, encoder = m["video"], m["audio"], m["encoder"]
        rep.check(m["render"]["status"] == "ok" and encoder["published"] and encoder["exit_code"] == 0,
                  "encode: finalized successfully", str(m["render"]))
        encoded = m["files"].get("encoded")
        if not encoded:
            raise ValueError("manifest has no completed encoded output")
        media = manifest.parent / encoded
        probe = json.loads(run([ffprobe, "-v", "error", "-count_frames", "-show_streams", "-show_format",
                               "-of", "json", media], out / "probe.stderr.txt"))
        (out / "ffprobe.json").write_text(json.dumps(probe, indent=2), encoding="utf-8")
        vstreams = [s for s in probe["streams"] if s["codec_type"] == "video"]
        astreams = [s for s in probe["streams"] if s["codec_type"] == "audio"]
        rep.check(len(vstreams) == 1 and len(astreams) == int(audio["present"]), "encode: stream mapping")
        if len(vstreams) != 1:
            raise ValueError("expected one video stream")
        v = vstreams[0]
        frames = int(video["frames_written"])
        width, height = int(video["width"]), int(video["height"])
        rate = Fraction(int(encoder["fps_num"]), int(encoder["fps_den"]))
        rep.check(v["codec_name"] == "ffv1" and v["pix_fmt"] == "yuv420p10le", "encode: lossless 10-bit codec")
        rep.check((v["width"], v["height"]) == (width, height), "encode: dimensions")
        rep.check(int(v.get("nb_read_frames", -1)) == frames == int(video["frame_count_reported"]),
                  "encode: decoded frame count", f"{v.get('nb_read_frames')} vs submitted {frames}")
        rep.check(Fraction(v["avg_frame_rate"]) == rate, "encode: rational frame rate", v["avg_frame_rate"])
        rep.check(encoder["video_bytes"] == frames * width * height * 3, "pipe: complete video bytes")
        rep.check(video["locks_outstanding"] == 0, "host: balanced frame locks")
        rep.check(encoder["video_queue_high_water"] <= 64 * 1024 * 1024 and
                  encoder["audio_queue_high_water"] <= 2 * 1024 * 1024, "pipe: bounded queued/in-flight bytes")

        vpath = out / "decoded.p010"
        run([ffmpeg, "-hide_banner", "-nostdin", "-v", "error", "-n", "-i", media, "-map", "0:v:0",
             "-vsync", "0", "-pix_fmt", "p010le", "-f", "rawvideo", vpath], out / "video-decode.stderr.txt")
        rep.check(vpath.stat().st_size == frames * width * height * 3, "decode: video byte count")

        # Inspect actual container timestamps, allowing only its time-base quantization.
        packets = json.loads(run([ffprobe, "-v", "error", "-select_streams", "v:0", "-show_packets",
                                  "-show_entries", "packet=pts", "-of", "json", media], out / "pts.stderr.txt"))
        timebase = Fraction(v["time_base"])
        pts = [int(p["pts"]) * timebase for p in packets["packets"]]
        timing_ok = len(pts) == frames and all(abs(t - Fraction(i, 1) / rate) <= timebase for i, t in enumerate(pts))
        rep.check(timing_ok, "encode: presentation timing", f"time base {timebase}; {len(pts)} packets")

        apath = None
        if audio["present"]:
            if len(astreams) != 1:
                raise ValueError("expected one audio stream")
            a = astreams[0]
            rep.check(a["codec_name"] == "pcm_f32le" and a["channels"] == 2 and int(a["sample_rate"]) == 48000,
                      "encode: float stereo format")
            apath = out / "decoded.f32"
            run([ffmpeg, "-hide_banner", "-nostdin", "-v", "error", "-n", "-i", media, "-map", "0:a:0",
                 "-c:a", "pcm_f32le", "-f", "f32le", apath], out / "audio-decode.stderr.txt")
            rep.check(apath.stat().st_size == audio["samples_written"] * 8 == encoder["audio_bytes"],
                      "decode: complete audio samples")
            rep.check(audio["samples_written"] == audio["samples_expected"], "decode: audio count vs endpoint")

        adapted = copy.deepcopy(m)
        adapted["files"].update(video=vpath.name, audio=apath.name if apath else None, frames_csv=None)
        adapted["video"].update(frame_bytes=width * height * 3,
                                plane_fields=[2 * width, 2 * width * height, 2 * width, 0, 0, 0], fps=float(rate))
        adapted["audio"]["wav_format"] = "raw"
        adapter = out / "decoded.ffdiag"
        adapter.write_text(json.dumps(adapted, indent=2), encoding="utf-8")
        decoded = raw.check(str(adapter), fixture=False)
        rep.results.extend(decoded.results)
        if fixture:
            layout, why = raw.make_layout(adapted["video"], adapted["template"], width * height * 3)
            if not layout:
                raise ValueError(why)
            _, markers = raw.fixture_video(rep, layout, str(vpath), frames, float(rate), 0)
            if apath:
                scan = raw.scan_audio(dict(path=str(apath), kind="float32", channels=2, rate=48000,
                                           block_align=8, data_offset=0, data_bytes=apath.stat().st_size))
                for channel, (name, marker) in enumerate(raw.MARKERS):
                    expected = round(Fraction(marker * 48000, 1) / rate)
                    onset = scan["onsets"][channel]
                    rep.check(onset is not None and abs(onset - expected) <= 1,
                              f"fixture: audio onset {name}", f"{onset} vs expected {expected}")
                    marker_frame = markers.get(name)
                    rep.check(marker_frame is not None and onset is not None and
                              abs(Fraction(onset, 48000) - Fraction(marker_frame, 1) / rate) <= Fraction(1, 48000),
                              f"fixture: exact A/V sync {name}")

        if reference:
            ref = json.loads(reference.read_text(encoding="utf-8-sig"))
            rep.check(digest(vpath) == digest(reference.parent / ref["files"]["video"]),
                      "lossless: exact packed P010 vs reference")
            if apath:
                rp = reference.parent / ref["files"]["audio"]
                wi = raw.parse_wav(str(rp))
                rep.check(digest(apath) == digest(rp, wi["data_offset"], wi["data_bytes"]),
                          "lossless: exact float samples vs reference")
    except (OSError, ValueError, KeyError, TypeError, subprocess.TimeoutExpired) as e:
        rep.add("FAIL", "encoded check", str(e))
    (out / "check.json").write_text(json.dumps(rep.as_dict(), indent=2), encoding="utf-8")
    for r in rep.results:
        print(f"{r['status']:4} {r['check']}: {r.get('detail', '')}")
    return not rep.failed


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("manifest", type=Path)
    p.add_argument("--ffmpeg", type=Path, required=True)
    p.add_argument("--ffprobe", type=Path, required=True)
    p.add_argument("--out-dir", type=Path, required=True)
    p.add_argument("--fixture", action="store_true")
    p.add_argument("--reference-manifest", type=Path)
    a = p.parse_args()
    return 0 if check(a.manifest.resolve(), a.ffmpeg.resolve(), a.ffprobe.resolve(), a.out_dir.resolve(),
                      a.fixture, a.reference_manifest.resolve() if a.reference_manifest else None) else 1


if __name__ == "__main__":
    sys.exit(main())
