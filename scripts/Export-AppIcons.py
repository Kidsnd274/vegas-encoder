"""Export the selected SVG to Windows ICO and PNGs. Python standard library only."""

import argparse
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parent.parent
SOURCE = Path('app/assets/icon/app_icon.svg')
SIZES = (16, 20, 24, 32, 40, 48, 64, 128, 256)
PNG_SIGNATURE = b'\x89PNG\r\n\x1a\n'


def find_inkscape(explicit):
    configured = explicit or os.environ.get('INKSCAPE_EXE')
    if configured:
        found = shutil.which(configured)
        if not found:
            raise ValueError(f'Inkscape not found: {configured}')
        return found
    for name in ('inkscape.com', 'inkscape.exe'):
        found = shutil.which(name)
        if found:
            return found
    # Standard installation and the existing tool location on the development PC.
    for base in (os.environ.get('ProgramFiles'), 'L:/Program Files'):
        if base:
            for name in ('inkscape.com', 'inkscape.exe'):
                candidate = Path(base) / 'Inkscape/bin' / name
                if candidate.is_file():
                    return str(candidate)
    raise ValueError('Inkscape is required. Put it on PATH, set INKSCAPE_EXE, or pass --inkscape "path/to/inkscape.com".')


def read_png(path, size):
    data = path.read_bytes()
    if len(data) < 33 or data[:8] != PNG_SIGNATURE or data[12:16] != b'IHDR':
        raise ValueError(f'Invalid exported PNG: {path}')
    width, height, depth, colour = struct.unpack('>IIBB', data[16:26])
    if (width, height, depth, colour) != (size, size, 8, 6):
        raise ValueError(f'Expected {size}x{size}, 8-bit RGBA PNG: {path}')
    return data


def make_ico(frames):
    # Windows Vista and later support PNG payloads in ICO entries. Render each
    # size directly from the SVG rather than downscaling a single raster image.
    header = struct.pack('<HHH', 0, 1, len(frames))
    offset = len(header) + 16 * len(frames)
    entries = []
    payloads = []
    for size, data in frames:
        dimension = 0 if size == 256 else size
        entries.append(struct.pack('<BBBBHHII', dimension, dimension, 0, 0, 1, 32, len(data), offset))
        payloads.append(data)
        offset += len(data)
    return header + b''.join(entries) + b''.join(payloads)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--inkscape', help='Inkscape console executable (or set INKSCAPE_EXE).')
    parser.add_argument('--check', action='store_true', help='Regenerate in a temporary folder and fail if checked-in outputs differ; write nothing.')
    args = parser.parse_args()
    if sys.platform != 'win32':
        parser.error('Icon generation is supported on Windows only.')
    try:
        inkscape = find_inkscape(args.inkscape)
        source = ROOT / SOURCE
        if not source.is_file():
            raise ValueError(f'Missing source SVG: {source}')
        # Finish every export before replacing any checked-in file. A failed
        # renderer leaves the existing app/Markdown icons intact.
        scratch = ROOT / 'build/app-icons'
        scratch.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix='export-', dir=scratch) as temp:
            temp = Path(temp)
            exports = {}
            for size in (*SIZES, 512):
                target = temp / f'{size}.png'
                subprocess.run([
                    inkscape, str(source), '--export-area-page', '--export-type=png',
                    '--export-background-opacity=0',
                    f'--export-width={size}', f'--export-height={size}',
                    f'--export-filename={target}',
                ], check=True, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=60)
                exports[size] = read_png(target, size)
            outputs = {
                Path('app/assets/icon/app_icon.png'): exports[256],
                Path('docs/assets/app-icon.png'): exports[512],
                Path('app/windows/runner/resources/app_icon.ico'): make_ico([(s, exports[s]) for s in SIZES]),
            }
            stale = []
            for relative, data in outputs.items():
                target = ROOT / relative
                if args.check:
                    if not target.is_file() or target.read_bytes() != data:
                        stale.append(str(relative))
                else:
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_bytes(data)
                    print(f'Wrote {relative}')
            if stale:
                raise ValueError('Stale icon outputs: ' + ', '.join(stale) + '. Run scripts\\export_app_icons.bat.')
        print('Icon outputs are current.' if args.check else 'Done. Rebuild the Windows app to embed the new icon.')
        return 0
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f'Icon export failed: {error}', file=sys.stderr)
        if isinstance(error, subprocess.CalledProcessError):
            print(error.stderr, file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
