"""Capture bounded FFmpeg help fixtures from release builds for parser tests.

Usage: Capture-FFmpegVersionFixtures.py <build-dir>...
Each build directory holds ffmpeg.exe and ffprobe.exe. Only the help/identity
commands the services run are executed. Fixtures are written with LF endings to
schema/fixtures/ffmpeg/v<version>-<kind>.txt; `-h full` keeps only the generic
AVCodecContext section, as the probe does.
"""
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'schema/fixtures/ffmpeg'


def run(exe, *args):
    done = subprocess.run([str(exe), *args], capture_output=True, timeout=60)
    if done.returncode != 0:
        raise SystemExit(f'{exe} {" ".join(args)} exited {done.returncode}')
    return (done.stdout + done.stderr).decode('utf-8').replace('\r\n', '\n')


def capture(directory):
    ffmpeg, ffprobe = directory / 'ffmpeg.exe', directory / 'ffprobe.exe'
    banner = run(ffmpeg, '-hide_banner', '-version')
    version = re.search(r'^ffmpeg version (\S+)', banner, re.M)[1]
    name = re.match(r'^[\d.]+', version)[0]
    full = run(ffmpeg, '-hide_banner', '-h', 'full')
    generic = full.split('AVCodecContext AVOptions:', 1)[1]
    generic = re.split(r'^\S.*AVOptions:', generic, maxsplit=1, flags=re.M)[0]
    files = {
        'version': banner,
        'ffprobe': json.dumps(json.loads(run(ffprobe, '-v', 'error', '-show_versions', '-of', 'json')), indent=2) + '\n',
        'encoders': run(ffmpeg, '-hide_banner', '-encoders'),
        'muxers': run(ffmpeg, '-hide_banner', '-muxers'),
        'filters': run(ffmpeg, '-hide_banner', '-filters'),
        'generic': generic,
        'encoder-libx264': run(ffmpeg, '-hide_banner', '-h', 'encoder=libx264'),
        'encoder-aac': run(ffmpeg, '-hide_banner', '-h', 'encoder=aac'),
        'filter-scale': run(ffmpeg, '-hide_banner', '-h', 'filter=scale'),
    }
    for kind, text in files.items():
        (OUT / f'v{name}-{kind}.txt').write_text(text, encoding='utf-8', newline='\n')
    print(name, version)


if __name__ == '__main__':
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    for argument in sys.argv[1:]:
        capture(Path(argument))
