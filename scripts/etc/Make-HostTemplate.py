#!/usr/bin/env python3
"""Generate an authored synthetic FileIO project template for the fake host.

This fixture uses only the recovered fields required by the offline harness.
It is not copied from VEGAS, and passing it does not qualify a real host.
The destination must not exist. Standard library only.
"""
import argparse
from pathlib import Path
import struct


def make_template(sample_rate=48000, channels=2):
    data = bytearray(0x218 + 4)  # fixed fields and two empty UTF-16 strings
    for offset, value in ((0x000, len(data)), (0x004, 0x02000000),
                          (0x038, 200), (0x03C, 1),
                          (0x100, 200), (0x104, 1), (0x210, 2)):
        struct.pack_into("<I", data, offset, value)
    # 32-byte internal audio record: PCM16 project audio (default 48 kHz stereo), not WAVEFORMATEX.
    align = 2 * channels
    struct.pack_into("<IIIHHIIII", data, 0x048,
                     32, 0x11, sample_rate, channels, align, 0, 0, 0, sample_rate * align)
    # A project source format. The exporter preset chooses render compression.
    struct.pack_into("<IiiHHIIiiII", data, 0x108,
                     40, 320, 180, 1, 32, 0, 320 * 180 * 4, 0, 0, 0, 0)
    struct.pack_into("<d", data, 0x140, 30.0)
    struct.pack_into("<d", data, 0x148, 1.0)
    return bytes(data)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    parser.add_argument("--sample-rate", type=int, default=48000)
    parser.add_argument("--channels", type=int, default=2)
    args = parser.parse_args()
    if not 1 <= args.sample_rate <= 768000 or not 1 <= args.channels <= 64:
        parser.error("project audio must be 1-768000 Hz with 1-64 channels")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("xb") as target:
        target.write(make_template(args.sample_rate, args.channels))
    print(f"Created {args.output} (540-byte synthetic fake-host template)")


if __name__ == "__main__":
    main()
