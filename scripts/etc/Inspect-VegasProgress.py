#!/usr/bin/env python3
"""Read-only B5 byte check for the selected VEGAS executable. Standard library only.

No module loading, launch, download, patching or investigation-checkout dependency.
Optional dumpbin prints the small setter/total range; full consumer analysis is
documented in docs/NATIVE_PROGRESS.md, not inferred by this byte check.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import sys

TARGET_SHA256 = '2B93C6613E1BDD4A435B65F63E3FC0B0EAD9EDB06B45F2458C43B63F784A73AF'
VTABLE = 0xAAD890
SLOTS = [0x263C60, 0x3A360, 0x263CF0, 0x263D30, 0x263D50,
         0x642A0, 0x263D80, 0x263D60, 0x2B710]
SETTERS = {
    3: '48 89 51 28 33 c0 4c 89 41 18 48 c7 41 20 00 00 00 00 c3',
    4: '48 89 51 28 33 c0 c3',
    5: '48 8b 41 20 48 3b d0 48 89 51 18 48 0f 42 c2 48 89 41 20 33 c0 c3',
}


class Image:
    def __init__(self, data):
        self.data = data
        if data[:2] != b'MZ':
            raise ValueError('Expected an MZ executable')
        pe = self.unpack('<I', 0x3C)[0]
        if data[pe:pe+4] != b'PE\0\0' or self.unpack('<H', pe+4)[0] != 0x8664:
            raise ValueError('Expected x64 PE')
        optional = pe + 24
        if self.unpack('<H', optional)[0] != 0x20B:
            raise ValueError('Expected PE32+')
        self.base = self.unpack('<Q', optional+24)[0]
        self.sections = []
        table = optional + self.unpack('<H', pe+20)[0]
        for i in range(self.unpack('<H', pe+6)[0]):
            _, va, size, raw = self.unpack('<IIII', table+i*40+8)
            self.sections.append((va, size, raw))

    def unpack(self, fmt, offset):
        if offset < 0 or offset + struct.calcsize(fmt) > len(self.data):
            raise ValueError('Truncated PE data')
        return struct.unpack_from(fmt, self.data, offset)

    def read(self, rva, size):
        for va, raw_size, raw in self.sections:
            if va <= rva and rva + size <= va + raw_size:
                start = raw + rva - va
                if start + size > len(self.data):
                    break
                return self.data[start:start+size]
        raise ValueError(f'RVA span not file-backed: {rva:#x}+{size:#x}')

    def at(self, fmt, rva):
        return struct.unpack(fmt, self.read(rva, struct.calcsize(fmt)))


def inspect(data):
    digest = hashlib.sha256(data).hexdigest().upper()
    if digest != TARGET_SHA256:
        raise ValueError('Host bytes changed/unqualified; do not reuse these addresses')
    image = Image(data)
    actual = [value-image.base for value in image.at('<9Q', VTABLE)]
    if actual != SLOTS:
        raise ValueError('Unexpected ISfProgress vtable')
    col = image.at('<Q', VTABLE-8)[0] - image.base
    signature, offset, _, type_rva, _, self_rva = image.at('<6I', col)
    if (signature, offset, self_rva) != (1, 0, col):
        raise ValueError('Unexpected complete-object RTTI')
    name = image.read(type_rva+16, len(b'.?AVCSfRenderProgress@@'))
    if name != b'.?AVCSfRenderProgress@@':
        raise ValueError('Unexpected progress type')
    for slot, text in SETTERS.items():
        expected = bytes.fromhex(text)
        if image.read(SLOTS[slot], len(expected)) != expected:
            raise ValueError(f'Unexpected slot {slot} body')
    # The internal helper forwards borrowed text into a scripting event, not
    # into the public SetPosition's event (whose description is zero).
    if image.read(0x264667, 8) != bytes.fromhex('49 8b 46 28 48 89 45 b0'):
        raise ValueError('Unexpected internal description forwarding')
    event_col = image.at('<Q', 0xAAD960-8)[0] - image.base
    event_type = image.at('<I', event_col+12)[0]
    event_name = b'.?AVRenderStatusEventArgs@Scripting@@'
    if image.read(event_type+16, len(event_name)) != event_name:
        raise ValueError('Unexpected scripting event RTTI')
    if image.at('<Q', 0xAAD988+14*8)[0] - image.base != 0x2638C0 or \
       image.read(0x2638D9, 10) != bytes.fromhex('48 8b 49 48 ff 15 2d 24 7c 00'):
        raise ValueError('Unexpected description getter')
    return {'hostSha256': digest, 'imageBase': hex(image.base),
            'type': name.decode(), 'vtableRva': hex(VTABLE),
            'slotRvas': {str(i): hex(rva) for i, rva in enumerate(actual)},
            'slot3': 'borrow text at +0x28; total at +0x18; zero position at +0x20; S_OK',
            'slot4': 'borrow text at +0x28; S_OK; no UI/copy/free call',
            'consumer': 'internal helper 0x264220 forwards text at 0x264667 into Scripting::RenderStatusEventArgs',
            'publicSetPosition': '0x263D80 uses total/position; event description is null',
            'qualification': 'static bytes only; visible status line unverified'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--host', type=Path,
                        default=Path(r'C:\Program Files\BorisFX\Vegas Pro 2026\vegas2026.exe'))
    parser.add_argument('--dumpbin', type=Path)
    args = parser.parse_args()
    try:
        print(json.dumps(inspect(args.host.read_bytes()), indent=2))
        if args.dumpbin:
            subprocess.run([str(args.dumpbin), '/nologo', '/nopdb', '/disasm:bytes',
                            '/range:0x140263d30,0x140263d57', str(args.host)], check=True)
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f'B5 inspection failed: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
