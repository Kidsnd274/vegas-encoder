"""Create deterministic local test media using only Python's standard library.

Output is a 90-frame 320x180 BMP sequence at an intended 30 fps plus 3 seconds
of stereo 48 kHz signed 16-bit PCM. This creates source media, not a VEGAS project
or exporter output. The destination must not exist.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import wave

WIDTH, HEIGHT, FPS, FRAMES, RATE = 320, 180, 30, 90, 48000
DIGITS = ("abcdef", "bc", "abdeg", "abcdg", "bcfg", "acdfg",
          "acdefg", "abc", "abcdefg", "abcdfg")
SEGMENTS = {"a": (4, 0, 24, 4), "b": (24, 4, 28, 24),
            "c": (24, 28, 28, 48), "d": (4, 48, 24, 52),
            "e": (0, 28, 4, 48), "f": (0, 4, 4, 24),
            "g": (4, 24, 24, 28)}


def bitmap(frame):
    pixels = bytearray(bytes((24, 24, 24)) * WIDTH * HEIGHT)

    def rect(x0, y0, x1, y1, rgb):
        row = bytes(reversed(rgb)) * (x1 - x0)
        for y in range(y0, y1):
            offset = ((HEIGHT - 1 - y) * WIDTH + x0) * 3
            pixels[offset:offset + len(row)] = row

    rect(0, 0, 32, 24, (255, 0, 0))
    rect(WIDTH - 32, 0, WIDTH, 24, (0, 255, 0))
    rect(0, HEIGHT - 24, 32, HEIGHT, (0, 0, 255))
    rect(WIDTH - 32, HEIGHT - 24, WIDTH, HEIGHT, (255, 255, 255))
    for index, digit in enumerate(f"{frame:03d}"):
        for segment in DIGITS[int(digit)]:
            x0, y0, x1, y1 = SEGMENTS[segment]
            rect(108 + index * 36 + x0, 55 + y0,
                 108 + index * 36 + x1, 55 + y1, (240, 240, 240))
    rect(40, 135, 42 + frame * 2, 143, (0, 180, 220))
    if frame in (30, 60):
        rect(100, 150, 220, 180, (255, 255, 0) if frame == 30 else (255, 0, 255))
    # WIDTH*3 is already DWORD aligned. BMP rows are bottom-up BGR.
    header = struct.pack("<2sIHHI", b"BM", 54 + len(pixels), 0, 0, 54)
    dib = struct.pack("<IiiHHIIiiII", 40, WIDTH, HEIGHT, 1, 24, 0,
                      len(pixels), 0, 0, 0, 0)
    return header + dib + pixels


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    sequence = args.output / "frames"
    sequence.mkdir()
    for frame in range(FRAMES):
        (sequence / f"frame{frame:03d}.bmp").write_bytes(bitmap(frame))
    audio = bytearray()
    for sample in range(RATE * 3):
        channels = []
        for start, frequency in ((RATE, 1000), (RATE * 2, 500)):
            offset = sample - start
            channels.append(round(12000 * math.cos(2 * math.pi * frequency * offset / RATE))
                            if 0 <= offset < 480 else 0)
        audio.extend(struct.pack("<hh", *channels))
    with wave.open(str(args.output / "markers.wav"), "wb") as wav:
        wav.setnchannels(2)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(audio)
    manifest = {
        "width": WIDTH, "height": HEIGHT, "fps_numerator": FPS,
        "fps_denominator": 1, "frame_count": FRAMES, "first_frame": 0,
        "audio_rate": RATE, "audio_channels": 2, "audio_bits": 16,
        "audio_samples_per_channel": RATE * 3,
        "markers": [{"frame": 30, "sample": RATE, "channel": "left", "frequency": 1000},
                    {"frame": 60, "sample": RATE * 2, "channel": "right", "frequency": 500}],
        "marker_length_samples": 480,
        "sha256": {str(p.relative_to(args.output)).replace("\\", "/"):
                   hashlib.sha256(p.read_bytes()).hexdigest()
                   for p in sorted(args.output.rglob("*")) if p.is_file()},
    }
    (args.output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Created {FRAMES} frames and {RATE * 3} audio samples per channel in {args.output}")


if __name__ == "__main__":
    main()
