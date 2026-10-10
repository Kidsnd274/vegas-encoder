"""Check raw output written by the ffbridge diagnostic exporter.

Reads the exporter's JSON manifest (the file VEGAS was asked to render, schema
"ffbridge-diag/1") and the sidecar raw video, WAV/raw audio and per-frame CSV
it names. Generic checks verify file sizes, frame/sample counts, header
agreement and lock balance. --fixture also decodes the deterministic baseline
fixture from scripts/Make-BaselineMedia.py (placed at timeline 0, scaled to
fill the frame): orientation from corner luma, the per-frame counter bar,
marker boxes, audio burst onsets and A/V sync. Only luma is inspected; the
colour matrix/range VEGAS uses is unknown, so pixel checks are relative.

Usage:
  python -I scripts/Check-RawRender.py MANIFEST [--fixture [--loop N]] [--first-frame N]
         [--expect-frames N] [--png DIR [--png-frames 0,30,60]] [--json OUT]

--loop N expects the fixture repeated every N frames (an event looped on the
timeline): counter and marker checks then compare modulo N.

Exit code: 0 when no check FAILs, 1 otherwise (argparse errors exit 2).
"""
import argparse
import array
import csv
import json
import os
import struct
import sys
import zlib

SCHEMA = "ffbridge-diag/1"

# Fixture geometry (scripts/Make-BaselineMedia.py), fixture pixel coordinates.
FIXTURE_W, FIXTURE_H, FIXTURE_FPS = 320, 180, 30
CORNER_CENTRES = {"TL": (16, 12), "TR": (304, 12), "BL": (16, 168), "BR": (304, 168)}
BAR_ROW, BAR_START, BAR_SCAN = 139, 40, (30, 260)   # bar = (40,135)-(42+2f,143)
MARKER_CENTRE, BG_SAMPLE = (160, 165), (60, 100)
MARKERS = (("yellow", 30), ("magenta", 60))           # marker box frames
AUDIO_MARKERS = (("L", 0, 1.0), ("R", 1, 2.0))         # channel, index, seconds
MARKER_MIN_DIFF = 15      # marker frame luma minus background (8-bit units)
IDLE_MAX_DIFF = 10        # non-marker frames must stay this close to background
BAR_MIN_CONTRAST = 20
FLOAT_THRESHOLD, PCM16_THRESHOLD = 0.05, 1638


def as_int(v, default=None):
    """Parse ints written as numbers, decimal strings or 0x-prefixed hex."""
    if v is None or isinstance(v, bool):
        return default if v is None else int(v)
    if isinstance(v, int):
        return v
    if isinstance(v, float):
        return int(v)
    s = str(v).strip()
    if not s:
        return default
    try:
        return int(s, 16) if s.lower().lstrip("-").startswith("0x") else int(s, 10)
    except ValueError:
        try:
            return int(float(s))
        except ValueError:
            return default


def as_float(v, default=None):
    try:
        return default if v is None or v == "" else float(v)
    except (TypeError, ValueError):
        return default


def hr_text(v):
    n = as_int(v)
    return "?" if n is None else f"0x{n & 0xFFFFFFFF:08X}"


def norm_fourcc(v):
    if v is None:
        return None
    if isinstance(v, int):
        v = {0: "BI_RGB", 3: "BI_BITFIELDS"}.get(v) or struct.pack("<I", v).decode("ascii", "replace")
    u = str(v).strip().upper()
    if u in ("BI_RGB", "RGB", "0", "0X0", "0X00000000"):
        return "BI_RGB"
    if u in ("BI_BITFIELDS", "3", "0X3", "0X00000003"):
        return "BI_BITFIELDS"
    return u or None


def fps_rational(fps):
    for d in (1, 1001):
        n = round(fps * d)
        if n and abs(n / d - fps) < 1e-6 * max(1.0, fps):
            return str(n) if d == 1 else f"{n}/{d}"
    return repr(fps)


class Report:
    def __init__(self, manifest_path):
        self.manifest_path = manifest_path
        self.results = []
        self.summary = {}
        self.ffmpeg = None

    def add(self, status, name, detail=""):
        self.results.append({"check": name, "status": status, "detail": detail})

    def check(self, ok, name, detail=""):
        self.add("PASS" if ok else "FAIL", name, detail)
        return ok

    def get(self, name):
        return next((r for r in self.results if r["check"] == name), None)

    @property
    def failed(self):
        return any(r["status"] == "FAIL" for r in self.results)

    def as_dict(self):
        return {"manifest": self.manifest_path, "ok": not self.failed, "results": self.results,
                "summary": self.summary, "ffmpeg": self.ffmpeg}


# --- video ---------------------------------------------------------------------

class Layout:
    """Where luma lives in one raw frame. Rows are read individually."""

    def __init__(self, kind, fourcc, width, height, height_sign, stride, row_bytes, frame_bytes, notes):
        self.kind, self.fourcc = kind, fourcc
        self.width, self.height, self.height_sign = width, height, height_sign
        self.stride, self.row_bytes, self.frame_bytes = stride, row_bytes, frame_bytes
        self.notes = notes

    def default_orientation(self):
        """Convention only (used when the fixture did not decide it)."""
        if self.kind in ("rgb32", "rgb24") and self.height_sign > 0:
            return "bottom-up"
        return "top-down"

    def luma_row(self, fh, index, phys_row):
        fh.seek(index * self.frame_bytes + phys_row * self.stride)
        raw = fh.read(self.row_bytes)
        if len(raw) < self.row_bytes:
            raise EOFError(f"frame {index} row {phys_row} truncated")
        if self.kind == "p010":
            return raw[1::2]          # high byte of (Y10 << 6) == Y10 >> 2
        if self.kind == "i420":
            return raw
        step = 4 if self.kind == "rgb32" else 3
        b, g, r = raw[0::step], raw[1::step], raw[2::step]
        # BT.709 weights scaled to 256: 54 + 183 + 19.
        return bytes((54 * R + 183 * G + 19 * B + 128) >> 8 for B, G, R in zip(b, g, r))


def make_layout(video, template, frame_bytes):
    fourcc = norm_fourcc(video.get("fourcc")) or norm_fourcc(template.get("render_fourcc"))
    width = as_int(video.get("width")) or as_int(template.get("render_width")) or 0
    signed_h = as_int(video.get("height")) or as_int(template.get("render_height")) or 0
    height = abs(signed_h)
    bits = as_int(video.get("bit_count")) or as_int(template.get("render_bit_count")) or 0
    pf = ([as_int(x, 0) or 0 for x in (video.get("plane_fields") or [])] + [0] * 6)[:6]
    if width <= 0 or height <= 0 or not frame_bytes:
        return None, "missing width/height/frame_bytes"
    notes = []
    if fourcc == "P010":
        kind, bpp = "p010", 2
    elif fourcc in ("I420", "IYUV", "YV12"):
        kind, bpp = "i420", 1     # luma plane first in all three
    elif fourcc in ("BI_RGB", "BI_BITFIELDS"):
        if bits not in (24, 32):
            bits = 32 if frame_bytes >= width * height * 4 else 24
            notes.append(f"bit count inferred as {bits}")
        kind, bpp = ("rgb32", 4) if bits == 32 else ("rgb24", 3)
    else:
        return None, f"unsupported fourcc {fourcc!r}"
    row_bytes = width * bpp
    packed = (row_bytes + 3) & ~3 if kind == "rgb24" else row_bytes
    fits = pf[0] >= row_bytes and pf[0] * (height - 1) + row_bytes <= frame_bytes
    stride = pf[0] if fits else packed
    if stride != packed:
        notes.append(f"stride {stride} from plane_fields (packed would be {packed})")
    if stride * (height - 1) + row_bytes > frame_bytes:
        return None, f"frame_bytes {frame_bytes} too small for {fourcc} {width}x{height} stride {stride}"
    if kind == "p010":
        packed_frame = width * 2 * height * 3 // 2
        plane1 = pf[1] or stride * height
        if frame_bytes != packed_frame or stride != width * 2 or plane1 != stride * height:
            notes.append(f"not packed P010 (frame {frame_bytes} vs {packed_frame}, plane1 offset {plane1}); "
                         "ffmpeg rawvideo assumes packed planes")
    sign = -1 if signed_h < 0 else 1
    return Layout(kind, fourcc, width, height, sign, stride, row_bytes, frame_bytes, notes), None


def fixture_px(fx, scale, limit):
    return min(limit - 1, max(0, int((fx + 0.5) * scale)))


def classify_corners(c):
    if c["BR"] > c["TR"] > c["TL"] > c["BL"]:
        return "top-down"
    if c["TR"] > c["BR"] > c["BL"] > c["TL"]:   # rows mirrored vertically
        return "bottom-up"
    return "unknown"


def decode_bar(row, sx):
    """Frame index from the counter bar: width = 2 + 2*frame fixture pixels."""
    x0, x1 = int(BAR_SCAN[0] * sx), min(len(row), int(BAR_SCAN[1] * sx))
    seg = row[x0:x1]
    if not seg:
        return None
    lo, hi = min(seg), max(seg)
    if hi - lo < BAR_MIN_CONTRAST:
        return None
    thr = (lo + hi) / 2
    x = next((c for c in range(int(BAR_START * sx), min(len(row), int((BAR_START + 2) * sx) + 1))
              if row[c] > thr), None)
    if x is None:
        return None
    while x + 1 < len(row) and row[x + 1] > thr:
        x += 1
    return round(((x + 1) / sx - (BAR_START + 2)) / 2)


def fixture_video(rep, layout, video_path, frames, fps, first_frame, loop=0):
    sx, sy = layout.width / FIXTURE_W, layout.height / FIXTURE_H
    py = lambda fy: fixture_px(fy, sy, layout.height)
    px = lambda fx: fixture_px(fx, sx, layout.width)
    corners_per_frame, decoded, diffs = [], [], []
    with open(video_path, "rb") as fh:
        top, bottom = py(CORNER_CENTRES["TL"][1]), py(CORNER_CENTRES["BL"][1])
        for i in range(frames):
            rt, rb = layout.luma_row(fh, i, top), layout.luma_row(fh, i, bottom)
            corners_per_frame.append({k: (rt if fy < FIXTURE_H / 2 else rb)[px(fx)]
                                      for k, (fx, fy) in CORNER_CENTRES.items()})
        orient = classify_corners(corners_per_frame[0])
        per_frame = [classify_corners(c) for c in corners_per_frame]
        disagree = [i for i, o in enumerate(per_frame) if o != orient]
        rep.check(orient != "unknown" and not disagree, "fixture: orientation",
                  f"{orient} (frame 0 corner luma {corners_per_frame[0]}); "
                  f"{len(disagree)} frame(s) disagree" + (f", first {disagree[:5]}" if disagree else ""))
        use = orient if orient != "unknown" else layout.default_orientation()
        rep.summary["orientation"] = orient
        phys = (lambda y: y) if use == "top-down" else (lambda y: layout.height - 1 - y)
        for i in range(frames):
            decoded.append(decode_bar(layout.luma_row(fh, i, phys(py(BAR_ROW))), sx))
            mrow = layout.luma_row(fh, i, phys(py(MARKER_CENTRE[1])))
            brow = layout.luma_row(fh, i, phys(py(BG_SAMPLE[1])))
            diffs.append(mrow[px(MARKER_CENTRE[0])] - brow[px(BG_SAMPLE[0])])

    # Frame index from the counter bar.
    fixture_index = (lambda i: (i + first_frame) % loop) if loop else (lambda i: i + first_frame)
    expected = [fixture_index(i) for i in range(frames)]
    bad = [(i, d) for i, (d, e) in enumerate(zip(decoded, expected)) if d != e]
    dups = [i for i in range(1, frames) if decoded[i] is not None and decoded[i] == decoded[i - 1]]
    known = {d for d in decoded if d is not None}
    gaps = sorted(set(range(min(known), max(known) + 1)) - known) if known else []
    undecoded = sum(1 for d in decoded if d is None)
    detail = (f"{frames - len(bad)}/{frames} match; mismatches {len(bad)}"
              + (f" first (index, decoded) {bad[:8]}" if bad else "")
              + f"; repeated {len(dups)}" + (f" at {dups[:8]}" if dups else "")
              + f"; gaps {len(gaps)}" + (f" {gaps[:8]}" if gaps else "")
              + (f"; undecodable {undecoded}" if undecoded else ""))
    rep.check(not bad, "fixture: frame index", detail)
    rep.summary["decoded_first_last"] = [decoded[0], decoded[-1]] if decoded else None

    # Marker boxes.
    marker_frames = {}
    problems = []
    nominal = {name: f - first_frame for name, f in MARKERS}
    # Every rendered frame showing each marker (one per loop pass with --loop).
    occurrences = {name: [i for i in range(frames) if fixture_index(i) == f] if loop else
                   [i for i in (f - first_frame,) if 0 <= i < frames] for name, f in MARKERS}
    lit = [i for i, d in enumerate(diffs) if d > MARKER_MIN_DIFF]
    for name, idx in nominal.items():
        if 0 <= idx < frames:
            near = [i for i in lit if abs(i - idx) <= 3]
            marker_frames[name] = min(near, key=lambda i: abs(i - idx)) if near else idx
        for i in occurrences[name]:
            if diffs[i] <= MARKER_MIN_DIFF:
                problems.append(f"{name} frame {i} diff {diffs[i]}")
    for y_i, m_i in zip(occurrences["yellow"], occurrences["magenta"]):
        if diffs[y_i] <= diffs[m_i]:
            problems.append(f"yellow frame {y_i} diff {diffs[y_i]} not above magenta frame {m_i} {diffs[m_i]}")
    marker_set = {i for occ in occurrences.values() for i in occ}
    idle = [(i, d) for i, d in enumerate(diffs) if i not in marker_set and abs(d) >= IDLE_MAX_DIFF]
    if idle:
        problems.append(f"{len(idle)} non-marker frame(s) differ from background, first {idle[:6]}")
    checked = [n for n in nominal if occurrences[n]]
    if not checked:
        rep.add("SKIP", "fixture: markers", "marker frames 30/60 not in rendered range")
    else:
        rep.check(not problems, "fixture: markers",
                  "; ".join(problems) if problems else
                  ", ".join(f"{n} at {occurrences[n][:6]} diff {diffs[occurrences[n][0]]}" for n in checked))
    rep.summary["marker_frames"] = marker_frames
    return use, marker_frames


def write_png(path, width, rows):
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    raw = b"".join(b"\x00" + bytes(r) for r in rows)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, len(rows), 8, 0, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b""))


# --- audio ---------------------------------------------------------------------

def parse_wav(path):
    size = os.path.getsize(path)
    info = {"path": path, "riff_ok": False}
    with open(path, "rb") as f:
        head = f.read(12)
        if len(head) < 12 or head[:4] != b"RIFF" or head[8:12] != b"WAVE":
            raise ValueError("not a RIFF/WAVE file")
        info["riff_ok"] = struct.unpack_from("<I", head, 4)[0] + 8 == size
        pos = 12
        while pos + 8 <= size:
            f.seek(pos)
            cid, clen = struct.unpack("<4sI", f.read(8))
            if cid == b"fmt ":
                body = f.read(clen)
                tag, ch, rate, avg, align, bits = struct.unpack_from("<HHIIHH", body)
                if tag == 0xFFFE and clen >= 26:
                    tag = struct.unpack_from("<H", body, 24)[0]
                info.update(tag=tag, channels=ch, rate=rate, avg=avg, block_align=align, bits=bits,
                            fmt_len=clen)
            elif cid == b"fact":
                info["fact_frames"] = struct.unpack("<I", f.read(4))[0] if clen >= 4 else None
            elif cid == b"data":
                info["data_offset"] = pos + 8
                info["data_header_bytes"] = clen
                info["data_bytes"] = min(clen, size - pos - 8)
                info["data_truncated"] = clen in (0, 0xFFFFFFFF) or pos + 8 + clen > size
                if info["data_truncated"]:
                    info["data_bytes"] = size - pos - 8
                break
            pos += 8 + clen + (clen & 1)
    if "tag" not in info or "data_offset" not in info:
        raise ValueError("missing fmt or data chunk")
    info["kind"] = ("float32" if (info["tag"], info["bits"]) == (3, 32) else
                    "pcm16" if (info["tag"], info["bits"]) == (1, 16) else None)
    return info


def scan_audio(info):
    """Peak and first-above-threshold frame index per channel (chunked)."""
    kind, ch, align = info["kind"], info["channels"], info["block_align"]
    item = 4 if kind == "float32" else 2
    if kind is None or not ch or align != ch * item:
        return None
    thr = FLOAT_THRESHOLD if kind == "float32" else PCM16_THRESHOLD
    onsets, peaks = [None] * ch, [0.0] * ch
    remaining, base = info["data_bytes"] - info["data_bytes"] % align, 0
    with open(info["path"], "rb") as f:
        f.seek(info["data_offset"])
        while remaining > 0:
            buf = f.read(min(remaining, 65536 * align))
            if not buf:
                break
            buf = buf[:len(buf) - len(buf) % align]
            arr = array.array("f" if kind == "float32" else "h")
            arr.frombytes(buf)
            if sys.byteorder != "little":
                arr.byteswap()
            for c in range(ch):
                chan = arr[c::ch]
                pk = max(max(chan), -min(chan))
                peaks[c] = max(peaks[c], pk)
                if onsets[c] is None and pk > thr:
                    onsets[c] = base + next(i for i, v in enumerate(chan) if v > thr or v < -thr)
            base += len(buf) // align
            remaining -= len(buf)
    scale = 1.0 if kind == "float32" else 1 / 32768
    return {"onsets": onsets, "peaks": [p * scale for p in peaks], "frames": base}


# --- main checks -----------------------------------------------------------------

def resolve(base_dir, manifest_path, files, key, suffix):
    if isinstance(files, dict) and key in files:
        name = files.get(key)
        return os.path.join(base_dir, name) if name else None
    cand = manifest_path + suffix
    return cand if os.path.exists(cand) else None


def read_csv(path):
    with open(path, newline="", encoding="utf-8-sig") as f:
        return list(csv.DictReader(f))


def check(manifest_path, fixture=False, first_frame=0, expect_frames=None, png_dir=None,
          png_frames=(0, 30, 60), loop=0):
    rep = Report(os.path.abspath(manifest_path))
    try:
        with open(manifest_path, encoding="utf-8-sig") as f:
            m = json.load(f)
    except (OSError, ValueError) as e:
        rep.add("FAIL", "manifest: parse", str(e))
        return rep
    sec = lambda k: m.get(k) if isinstance(m.get(k), dict) else {}
    render, files, template, video, audio = sec("render"), sec("files"), sec("template"), sec("video"), sec("audio")
    progress, plugin, host = sec("progress"), sec("plugin"), sec("host")
    base = os.path.dirname(os.path.abspath(manifest_path))
    if m.get("schema") == SCHEMA:
        rep.add("PASS", "manifest: schema", SCHEMA)
    else:
        rep.add("INFO", "manifest: schema", f"unexpected schema {m.get('schema')!r}; continuing")
    status = render.get("status") or "?"
    rep.add("INFO", "render: status",
            f"#{render.get('index')} {status} returned {hr_text(render.get('returned_hresult'))}"
            + (f"; stop {render.get('stop_reason')} {hr_text(render.get('stop_hresult'))}"
               if render.get("stop_reason") else "")
            + (f"; {as_float(render.get('elapsed_ms')):.1f} ms" if as_float(render.get("elapsed_ms")) else ""))
    non_ok = progress.get("non_ok") or []
    rep.add("INFO", "progress: non-S_OK returns",
            f"{len(non_ok)}" + (f", first {non_ok[:4]}" if non_ok else "")
            + f"; total set {progress.get('total_set')}")
    probes = m.get("probes") or []
    if probes:
        def short(v):  # 184-byte format blocks are hex; the manifest keeps them whole
            v = str(v)
            return v if len(v) <= 24 else f"{v[:16]}...({len(v) // 2} bytes)"
        rep.add("INFO", "probes", "; ".join(f"{p.get('stream')}#{p.get('slot')} {p.get('hresult')} {short(p.get('value'))}"
                                            for p in probes[:12]))

    # Video.
    fps = as_float(video.get("fps")) or as_float(template.get("fps")) or 0.0
    frame_bytes = as_int(video.get("frame_bytes"), 0) or 0
    video_path = resolve(base, manifest_path, files, "video", ".video.raw")
    layout, frames = None, as_int(video.get("frames_written"))
    video_present = bool(video.get("present", video_path is not None))
    if video_present:
        if not video_path or not os.path.exists(video_path):
            rep.add("FAIL", "video: file", f"missing {video_path}")
            video_path = None
        else:
            vsize = os.path.getsize(video_path)
            if frames is None and frame_bytes:
                frames = vsize // frame_bytes
            if frame_bytes and frames is not None:
                rep.check(vsize == frames * frame_bytes, "video: file size",
                          f"{vsize} bytes; expected {frames} x {frame_bytes} = {frames * frame_bytes}")
            else:
                rep.add("FAIL", "video: file size", "frame_bytes/frames_written missing from manifest")
        reported = as_int(video.get("frame_count_reported"))
        if status == "ok":
            rep.check(frames == reported, "video: frames vs reported", f"written {frames}, reported {reported}")
        else:
            rep.add("INFO", "video: frames vs reported", f"written {frames}, reported {reported} (status {status})")
        if expect_frames is not None:
            rep.check(frames == expect_frames, "video: expected frames", f"written {frames}, expected {expect_frames}")
        locks = as_int(video.get("locks_outstanding"))
        if locks is not None:
            rep.check(locks == 0, "video: locks balanced", f"{locks} outstanding")
        size_changes = as_int(video.get("frame_size_changes"), 0) or 0
        rep.check(size_changes == 0, "video: constant frame size",
                  f"{size_changes} change(s); raw offsets assume constant frame_bytes")
        rep.add("INFO", "video: frame info changes", str(video.get("frame_info_changes")))
        layout, why = make_layout(video, template, frame_bytes)
        if layout is None:
            rep.add("SKIP", "video: pixel layout", why)
        else:
            rep.add("INFO", "video: pixel layout",
                    f"{layout.fourcc} {layout.width}x{layout.height * layout.height_sign} {layout.kind} "
                    f"stride {layout.stride}" + (f"; {'; '.join(layout.notes)}" if layout.notes else ""))
    else:
        rep.add("INFO", "video: present", "no video stream in manifest")

    # Per-frame CSV.
    csv_path = resolve(base, manifest_path, files, "frames_csv", ".frames.csv")
    rows = None
    if csv_path and os.path.exists(csv_path):
        rows = read_csv(csv_path)
        if frames is not None:
            rep.check(len(rows) >= frames, "csv: rows", f"{len(rows)} rows for {frames} written frames")
            written = rows[:frames]
            seq = [as_int(r.get("frame")) for r in written]
            rep.check(seq == list(range(len(written))), "csv: frame sequence",
                      "0..n-1" if seq == list(range(len(written))) else f"first {seq[:8]}")
            bad_hr = [(r.get("frame"), r.get("video_hr")) for r in written if as_int(r.get("video_hr"), -1) != 0]
            rep.check(not bad_hr, "csv: video HRESULTs", f"{len(bad_hr)} non-zero" + (f", {bad_hr[:5]}" if bad_hr else ""))
            sums = [r.get("checksum") for r in written]
            same = [i for i in range(1, len(sums)) if sums[i] and sums[i] == sums[i - 1]]
            rep.add("INFO", "csv: consecutive identical checksums",
                    f"{len(same)}" + (f" at {same[:10]}" if same else ""))
            get_ms = [v for v in (as_float(r.get("get_ms")) for r in written) if v is not None]
            if get_ms:
                rep.add("INFO", "csv: GetRenderFrame ms",
                        f"mean {sum(get_ms) / len(get_ms):.2f}, max {max(get_ms):.2f}, total {sum(get_ms):.1f}")
        audio_hr = [(r.get("frame"), r.get("audio_hr")) for r in rows
                    if r.get("audio_hr") not in (None, "") and as_int(r.get("audio_hr"), -1) != 0]
        if audio_hr:
            rep.add("INFO", "csv: audio HRESULTs", f"{len(audio_hr)} non-zero, {audio_hr[:5]}")
    elif video_present:
        rep.add("INFO", "csv: rows", "no frames CSV")

    # Audio.
    rate = as_int(audio.get("sample_rate")) or as_int(template.get("audio_rate")) or 0
    channels = as_int(audio.get("channels")) or as_int(template.get("audio_channels")) or 0
    align = as_int(audio.get("block_align")) or as_int(template.get("audio_block_align")) or 0
    samples_written = as_int(audio.get("samples_written"))
    wav_format = audio.get("wav_format")
    ainfo, scan = None, None
    audio_present = bool(audio.get("present", False))
    if audio_present:
        apath = resolve(base, manifest_path, files, "audio",
                        ".audio.raw" if wav_format == "raw" else ".audio.wav")
        if not apath or not os.path.exists(apath):
            rep.add("FAIL", "audio: file", f"missing {apath}")
        elif wav_format == "raw":
            code = as_int(audio.get("format_code"))
            kind = {0x20: "float32", 0x11: "pcm16"}.get(code)
            ainfo = {"path": apath, "kind": kind, "channels": channels, "rate": rate, "block_align": align,
                     "data_offset": 0, "data_bytes": os.path.getsize(apath)}
            rep.add("INFO", "audio: header", f"raw, format code {hr_text(code)} -> {kind}")
        else:
            try:
                ainfo = parse_wav(apath)
            except (OSError, ValueError, struct.error) as e:
                rep.add("FAIL", "audio: WAV parse", str(e))
            if ainfo:
                rep.check(ainfo["riff_ok"] and not ainfo["data_truncated"], "audio: WAV sizes finalized",
                          f"RIFF size ok {ainfo['riff_ok']}, data header {ainfo['data_header_bytes']}, "
                          f"data present {ainfo['data_bytes']}")
                want = {"ieee_float32": "float32", "pcm16": "pcm16"}.get(wav_format, ainfo["kind"])
                mismatch = [f"{k} {a}!={b}" for k, a, b in (
                    ("channels", ainfo["channels"], channels), ("rate", ainfo["rate"], rate),
                    ("block_align", ainfo["block_align"], align), ("format", ainfo["kind"], want)) if a != b]
                rep.check(not mismatch, "audio: header vs manifest",
                          ", ".join(mismatch) if mismatch else
                          f"tag {ainfo['tag']} {ainfo['bits']}-bit {ainfo['channels']} ch {ainfo['rate']} Hz")
        if ainfo:
            if samples_written is not None and align:
                rep.check(ainfo["data_bytes"] == samples_written * align, "audio: data size",
                          f"{ainfo['data_bytes']} bytes; expected {samples_written} x {align}")
            expected = as_int(audio.get("samples_expected"))
            if expected is not None and samples_written is not None:
                rep.add("INFO", "audio: samples vs expected",
                        f"written {samples_written}, expected {expected}, delta {samples_written - expected}")
            if rows is not None and samples_written is not None:
                got = [as_int(r.get("audio_got")) for r in rows if r.get("audio_got") not in (None, "")]
                if got and None not in got:
                    rep.check(sum(got) == samples_written, "csv: audio got total",
                              f"sum {sum(got)} vs samples_written {samples_written}")
            rep.add("INFO", "audio: reads", f"{audio.get('reads')} reads, {audio.get('short_reads')} short; "
                    f"stream length reported {audio.get('stream_length_reported')}")
            scan = scan_audio(ainfo)
            if scan:
                rep.add("INFO", "audio: peak", ", ".join(f"ch{c} {p:.4f}" for c, p in enumerate(scan["peaks"])))
            else:
                rep.add("SKIP", "audio: scan", f"unsupported sample format {ainfo.get('kind')}")
    else:
        rep.add("INFO", "audio: present", "no audio stream in manifest")

    if frames is not None and fps and samples_written is not None and rate:
        vms, ams = frames / fps * 1000, samples_written / rate * 1000
        rep.add("INFO", "audio vs video duration", f"video {vms:.3f} ms, audio {ams:.3f} ms, delta {ams - vms:+.3f} ms")

    # Fixture.
    orientation = None
    if fixture:
        marker_frames = {}
        if layout and video_path and frames:
            orientation, marker_frames = fixture_video(rep, layout, video_path, frames, fps or FIXTURE_FPS,
                                                       first_frame, loop)
        else:
            rep.add("SKIP", "fixture: video", "no decodable video")
        if scan and len(scan["onsets"]) >= 2 and ainfo.get("rate"):
            arate = ainfo["rate"]
            onsets = scan["onsets"]
            exp = {lab: round((sec - first_frame / FIXTURE_FPS) * arate) for lab, _, sec in AUDIO_MARKERS}
            for lab, idx, sec in AUDIO_MARKERS:
                if exp[lab] < 0 or exp[lab] >= scan["frames"]:
                    rep.add("SKIP", f"fixture: audio onset {lab}", f"expected sample {exp[lab]} outside audio")
                    continue
                o = onsets[idx]
                other = "R" if lab == "L" else "L"
                hint = "; channels swapped?" if o is not None and abs(o - exp[other]) <= 1 else ""
                rep.check(o is not None and abs(o - exp[lab]) <= 1, f"fixture: audio onset {lab}",
                          f"onset {o}, expected {exp[lab]}, delta {None if o is None else o - exp[lab]}{hint}")
            vfps = fps or FIXTURE_FPS
            for (name, _), (lab, idx, _) in zip(MARKERS, AUDIO_MARKERS):
                if name in marker_frames and onsets[idx] is not None:
                    off = (onsets[idx] / arate - marker_frames[name] / vfps) * 1000
                    rep.check(abs(off) < 500 / vfps, f"fixture: A/V sync {name}",
                              f"audio {onsets[idx] / arate * 1000:.3f} ms vs frame {marker_frames[name]} "
                              f"{marker_frames[name] / vfps * 1000:.3f} ms, offset {off:+.3f} ms "
                              f"(limit {500 / vfps:.1f})")
        else:
            rep.add("SKIP", "fixture: audio", "no scannable stereo audio")

    if png_dir and layout and video_path and frames:
        os.makedirs(png_dir, exist_ok=True)
        use = orientation if orientation in ("top-down", "bottom-up") else layout.default_orientation()
        written_png = []
        with open(video_path, "rb") as fh:
            for i in png_frames:
                if 0 <= i < frames:
                    rows_l = [layout.luma_row(fh, i, y if use == "top-down" else layout.height - 1 - y)
                              for y in range(layout.height)]
                    out = os.path.join(png_dir, f"frame{i:05d}-luma.png")
                    write_png(out, layout.width, rows_l)
                    written_png.append(out)
        rep.add("INFO", "png", f"{len(written_png)} file(s) in {png_dir} ({use})")

    # ffmpeg command and summary.
    if layout and video_path:
        pix = {"p010": "p010le", "i420": "yuv420p", "rgb32": "bgra", "rgb24": "bgr24"}[layout.kind]
        parts = ["ffmpeg", "-f rawvideo", f"-pix_fmt {pix}", f"-s {layout.width}x{layout.height}",
                 f"-framerate {fps_rational(fps or FIXTURE_FPS)}", f'-i "{video_path}"']
        if ainfo:
            if wav_format == "raw":
                parts += [f"-f {'f32le' if ainfo['kind'] == 'float32' else 's16le'}",
                          f"-ar {ainfo['rate']}", f"-ac {ainfo['channels']}"]
            parts.append(f'-i "{ainfo["path"]}"')
        flip = (orientation or (layout.default_orientation() if layout.kind.startswith("rgb") else "top-down"))
        if flip == "bottom-up":
            parts.append("-vf vflip")
        parts += ["-c:v libx264 -pix_fmt yuv420p"] + (["-c:a aac"] if ainfo else []) + ["out.mp4"]
        rep.ffmpeg = " ".join(parts)
        if layout.kind.startswith("rgb") and orientation is None:
            rep.ffmpeg += "   # bottom-up as VEGAS 2026 delivered BI_RGB (F-041); run --fixture to detect"
        if any(n.startswith(("not packed", "stride")) for n in layout.notes):
            rep.ffmpeg += "   # WARNING: padded layout; rawvideo needs packed planes"
    rep.summary.update({
        "plugin": f"{plugin.get('name')} {plugin.get('version')}",
        "host": f"{host.get('exe')} {host.get('version')} pid {host.get('pid')}",
        "render": f"#{render.get('index')} {status} {hr_text(render.get('returned_hresult'))}",
        "template": (f"{template.get('name')!r} preset {template.get('preset_id')}: "
                     f"{template.get('render_fourcc')} {template.get('render_width')}x{template.get('render_height')} "
                     f"fps {template.get('fps')}; audio code {hr_text(template.get('audio_format_code'))} "
                     f"{template.get('audio_rate')} Hz {template.get('audio_channels')} ch "
                     f"align {template.get('audio_block_align')}"),
        "video": (f"{layout.fourcc if layout else video.get('fourcc')} "
                  f"{video.get('width')}x{video.get('height')}, {frames}/{video.get('frame_count_reported')} frames "
                  f"x {frame_bytes} bytes, fps {fps}") if video_present else "none",
        "audio": (f"{wav_format} {rate} Hz {channels} ch, {samples_written} samples "
                  f"(expected {audio.get('samples_expected')})") if audio_present else "none",
    })
    return rep


def print_report(rep):
    print(f"Manifest  {rep.manifest_path}")
    for k in ("plugin", "host", "render", "template", "video", "audio", "orientation"):
        if k in rep.summary:
            print(f"{k.capitalize():<9} {rep.summary[k]}")
    print()
    for r in rep.results:
        print(f"{r['status']:<4}  {r['check']}: {r['detail']}")
    if rep.ffmpeg:
        print(f"\nffmpeg command:\n  {rep.ffmpeg}")
    n_fail = sum(r["status"] == "FAIL" for r in rep.results)
    print(f"\nRESULT: {'FAIL' if n_fail else 'PASS'} ({n_fail} failed, "
          f"{sum(r['status'] == 'PASS' for r in rep.results)} passed)")


def main():
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser(description="Check ffbridge diagnostic exporter output.")
    ap.add_argument("manifest", help="the rendered file (JSON manifest)")
    ap.add_argument("--fixture", action="store_true", help="decode the baseline fixture (frame counter, markers, audio)")
    ap.add_argument("--first-frame", type=int, default=0, help="fixture frame index of the first rendered frame")
    ap.add_argument("--loop", type=int, default=0, metavar="N",
                    help="fixture repeats every N frames (looped event); compare counter/markers modulo N")
    ap.add_argument("--expect-frames", type=int, help="required frames_written")
    ap.add_argument("--png", metavar="DIR", help="write grayscale luma PNGs of selected frames")
    ap.add_argument("--png-frames", default="0,30,60", help="comma-separated frame indexes for --png")
    ap.add_argument("--json", metavar="OUT", help="write results as JSON")
    a = ap.parse_args()
    png_frames = tuple(int(x) for x in a.png_frames.split(",") if x.strip())
    if a.loop < 0:
        ap.error("--loop must not be negative")
    rep = check(a.manifest, a.fixture, a.first_frame, a.expect_frames, a.png, png_frames, a.loop)
    print_report(rep)
    if a.json:
        with open(a.json, "w", encoding="utf-8") as f:
            json.dump(rep.as_dict(), f, indent=2)
    sys.exit(1 if rep.failed else 0)


if __name__ == "__main__":
    main()
