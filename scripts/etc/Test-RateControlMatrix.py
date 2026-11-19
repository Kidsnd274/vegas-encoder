"""Run every curated video encoder through every Basic rate-control mode on this PC.

The real core DLL compiles each command (the exporter's exact output arguments), and
the supplied FFmpeg encodes a generated P010 clip with it. The input is lavfi, not
the exporter's pipes, so this checks which settings each encoder accepts. It does
not check transport, VEGAS or the installed exporter.

Standalone: needs only Python 3, ve_core.dll and an FFmpeg build (FFprobe beside it
is optional). Copy this file and ve_core.dll into one folder to run it on a PC
without the repository. Each encoder's selectable codec profiles are also tried at
every bit depth. Exit code 1 means the core and FFmpeg disagree: the core allows a
command FFmpeg rejects, blocks one FFmpeg accepts, or says nothing about an 8-bit
file FFmpeg labels with a 10-bit profile.
"""
import argparse
import ctypes
import datetime
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

HERE = Path(__file__).resolve().parent
REPO_CORE = HERE.parents[1] / 'build/release/vegas-encoder/core/ve_core.dll'

# Driver, device or runtime missing: says nothing about the settings.
UNAVAILABLE = re.compile(r'cannot load \S+\.dll|no (?:nvenc )?capable devices|no device available|'
                         r'openencodesessionex failed|driver does not support the required nvenc api|'
                         r'minimum required nvidia driver|error creating a mfx session|'
                         r'failed to (?:create|initiali[sz]e) (?:a )?(?:d3d|dxva|cuda|amf|device)|'
                         r'device creation failed|could not (?:open|create) (?:the )?device', re.I)


class Buffer(ctypes.Structure):
    _fields_ = [('data', ctypes.c_void_p), ('length', ctypes.c_uint32)]


class Core:
    def __init__(self, path):
        self.dll = ctypes.CDLL(str(path))
        self.dll.ve_free.argtypes = [ctypes.c_void_p]
        self.dll.ve_free.restype = None

    def _result(self, status, output):
        try:
            text = ctypes.string_at(output.data, output.length).decode('utf-8')
            if status:
                raise RuntimeError(text)
            return json.loads(text)
        finally:
            self.dll.ve_free(output.data)

    def profiles(self):
        output = Buffer()
        self.dll.ve_profiles.argtypes = [ctypes.POINTER(Buffer)]
        return self._result(self.dll.ve_profiles(ctypes.byref(output)), output)

    def compile(self, request):
        encoded = json.dumps(request).encode('utf-8')
        output = Buffer()
        self.dll.ve_compile.argtypes = [ctypes.c_char_p, ctypes.c_uint32, ctypes.POINTER(Buffer)]
        return self._result(self.dll.ve_compile(encoded, len(encoded), ctypes.byref(output)), output)


def run(arguments, timeout):
    try:
        process = subprocess.run(arguments, capture_output=True, timeout=timeout)
        return process.returncode, process.stderr.decode('utf-8', 'replace').replace('\r', '\n'), process.stdout.decode('utf-8', 'replace')
    except subprocess.TimeoutExpired:
        return None, 'Timed out; process killed.', ''


def host_facts(ffmpeg):
    facts = {'ffmpeg': run([ffmpeg, '-hide_banner', '-version'], 30)[2].splitlines()[:1]}
    gpus = run(['powershell', '-NoProfile', '-Command',
                'Get-CimInstance Win32_VideoController | ForEach-Object { $_.Name + " | driver " + $_.DriverVersion }'], 60)[2]
    facts['gpus'] = [line.strip() for line in gpus.splitlines() if line.strip()]
    if shutil.which('nvidia-smi'):
        facts['nvidiaSmi'] = run(['nvidia-smi', '--query-gpu=name,driver_version', '--format=csv,noheader'], 30)[2].strip().splitlines()
    return facts


def recipe(profile, mode, depth, peak, codec_profile=None):
    encoder = profile['id']
    video = {'enabled': True, 'encoder': encoder, 'mode': mode, 'quality': None, 'bitrateK': 4000, 'maxrateK': peak, 'qp': None,
             'speed': None, 'tune': None, 'profile': codec_profile, 'depth': depth, 'gopSec': 2, 'color': 'bt709', 'extra': ''}
    container, audio = 'mkv', {'encoder': 'aac', 'mode': 'bitrate', 'bitrateK': 256}
    if encoder == 'prores_ks':
        video['profile'], container, audio = 'hq', 'mov', {'encoder': 'pcm_s16le', 'mode': 'lossless'}
    if encoder == 'dnxhd':
        video['profile'] = 'dnxhr_hq' if depth == 8 else 'dnxhr_hqx'
    return {'schema': 1, 'id': 'rate-matrix', 'name': 'Rate-control matrix', 'container': {'format': container, 'faststart': False},
            'video': video, 'audio': [dict(enabled=True, vbr=None, level=None, sampleRate='source', channels='source', extra='', **audio)],
            'command': {'mode': 'structured', 'template': ''}, 'vegas': {'frame': 'project', 'inputFormat': 'p010'}, 'extensions': {}}


def variants(profile):
    rows = []
    for index, mode in enumerate(profile['modes']):
        peaks = [None, 4000, 6000] if mode == 'abr' else [None]
        depths = [int(d) for d in profile['depths']] if index == 0 else [int(profile.get('depthDef', 8))]
        for depth in depths:
            for peak in peaks:
                label = mode + ('' if peak is None else '+peak=avg' if peak == 4000 else '+peak=1.5x') + f'-{depth}bit'
                rows.append((label, mode, depth, peak, None))
    # Every selectable codec profile at every depth, in the first mode.
    control = profile.get('profile') or {}
    if profile['modes'][0] != 'profile':
        for value in control.get('values', []):
            for depth in sorted(int(d) for d in profile['depths']):
                rows.append((f'profile={value}-{depth}bit', profile['modes'][0], depth, None, value))
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--ffmpeg', type=Path, default=os.environ.get('VEGAS_ENCODER_FFMPEG'), help='default: VEGAS_ENCODER_FFMPEG')
    parser.add_argument('--core', type=Path, help='ve_core.dll; default: beside this script, else the repository release build')
    parser.add_argument('--output', type=Path, help='fresh folder; default: build/test-results/rate-matrix-<time> under the current folder')
    parser.add_argument('--encoders', nargs='*', help='only these encoder IDs, for example h264_nvenc hevc_nvenc av1_nvenc')
    parser.add_argument('--hardware', action='store_true', help='only hardware encoders (NVENC, Quick Sync, AMF)')
    parser.add_argument('--size', default='1920x1080')
    parser.add_argument('--frames', type=int, default=90)
    args = parser.parse_args()
    if not args.ffmpeg:
        parser.error('Pass --ffmpeg or set VEGAS_ENCODER_FFMPEG.')
    ffmpeg = args.ffmpeg.resolve(strict=True)
    core_path = args.core or (HERE / 've_core.dll' if (HERE / 've_core.dll').exists() else REPO_CORE)
    core = Core(core_path.resolve(strict=True))
    ffprobe = ffmpeg.with_name('ffprobe.exe')
    stamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
    output = (args.output or Path.cwd() / 'build' / 'test-results' / f'rate-matrix-{stamp}').resolve()
    output.mkdir(parents=True, exist_ok=False)
    width, height = (int(x) for x in args.size.lower().split('x'))
    media = {'video': {'width': width, 'height': height, 'fps': [30, 1], 'pixfmt': 'p010le', 'sar': '1:1', 'frames': args.frames},
             'audio': {'rate': 48000, 'channels': 2, 'sampleFmt': 'f32le'}, 'durationSec': args.frames / 30}
    paths = {'ffmpeg': str(ffmpeg), 'videoPipe': 'VIDEO-PIPE', 'audioPipe': 'AUDIO-PIPE', 'output': 'OUTPUT',
             'liveInputs': True, 'overwriteOutput': True}
    seconds = args.frames / 30
    source = ['-f', 'lavfi', '-i', f'testsrc2=size={width}x{height}:rate=30,format=p010le',
              '-f', 'lavfi', '-i', 'sine=r=48000', '-t', f'{seconds:g}']
    facts = host_facts(ffmpeg)
    print('FFmpeg:', *facts['ffmpeg'], '\nGPUs:', '; '.join(facts['gpus']) or 'unknown', flush=True)
    rows = []
    for profile in core.profiles()['video']:
        if args.encoders and profile['id'] not in args.encoders:
            continue
        if args.hardware and not profile.get('hw'):
            continue
        for label, mode, depth, peak, codec_profile in variants(profile):
            r = recipe(profile, mode, depth, peak, codec_profile)
            plan = core.compile({'recipe': r, 'media': media, 'paths': paths})
            core_errors = [f"{i['id']} ({i['field']}): {i['message']}" for i in plan['issues'] if i['level'] == 'error']
            profile_warnings = [i['id'] for i in plan['issues'] if i['level'] == 'warn' and i['field'] == 'video.profile']
            argv = plan['argv']
            first_output = max(i for i, a in enumerate(argv) if a == '-i') + 2
            name = f"{profile['id']}-{label}".replace('+', '_').replace('=', '_')
            target = output / f"{name}.{r['container']['format']}"
            out_args = [str(target) if a == 'OUTPUT' else a for a in argv[first_output:]]
            code, stderr, _ = run([str(ffmpeg), '-hide_banner', '-nostdin', '-y', *source, *out_args], 300)
            (output / f'{name}.log').write_text(stderr, encoding='utf-8')
            lines = [l.strip() for l in stderr.splitlines() if l.strip()]
            row = {'encoder': profile['id'], 'hardware': profile.get('hw'), 'variant': label, 'coreErrors': core_errors,
                   'outputArgs': [Path(a).name if a == str(target) else a for a in out_args], 'exit': code}
            if code == 0:
                row['verdict'] = 'pass'
                if ffprobe.exists():
                    _, _, probe = run([str(ffprobe), '-v', 'error', '-show_entries', 'format=bit_rate:stream=codec_type,codec_name,profile,pix_fmt',
                                       '-of', 'json', str(target)], 60)
                    try:
                        facts_out = json.loads(probe)
                        row['measuredKbps'] = round(int(facts_out['format']['bit_rate']) / 1000)
                        row['video'] = next(s for s in facts_out['streams'] if s['codec_type'] == 'video')
                    except (ValueError, KeyError, StopIteration):
                        row['verdict'], row['diagnostic'] = 'unreadable', 'FFprobe could not read the output.'
            elif code is None:
                row['verdict'], row['diagnostic'] = 'timeout', 'FFmpeg did not finish in 300 s.'
            else:
                unavailable = next((l for l in lines if UNAVAILABLE.search(l)), None)
                lib = next((l for l in lines if '[error]' in l.lower()), None)
                specific = next((l for l in lines if re.search(r'error|failed|not supported|invalid|cannot|could not', l, re.I)
                                 and not l.startswith(('frame=', 'size='))), lines[-1] if lines else '')
                row['verdict'] = 'unavailable' if unavailable else 'rejected'
                row['diagnostic'] = unavailable or lib or specific
            blocked = bool(core_errors)
            row['profileWarnings'] = profile_warnings
            # An 8-bit file labelled with a 10-bit profile ("Main 10", "High 10") that the core
            # didn't warn about: decoders that only take the 8-bit profile may refuse it.
            video_out = row.get('video', {})
            labelled_10 = '10' in str(video_out.get('profile', ''))
            pixels_10 = '10' in str(video_out.get('pix_fmt', ''))
            row['labelMismatch'] = bool(video_out) and labelled_10 and not pixels_10 and not profile_warnings
            row['mismatch'] = (not blocked and row['verdict'] in ('rejected', 'timeout', 'unreadable')) or (blocked and row['verdict'] == 'pass') or row['labelMismatch']
            rows.append(row)
            flag = '  <-- MISMATCH' if row['mismatch'] else ''
            core_state = 'blocks' if blocked else 'warns' if profile_warnings else 'allows'
            written = f"  wrote {video_out.get('profile')}/{video_out.get('pix_fmt')}" if video_out else ''
            print(f"{profile['id']:12} {label:22} {row['verdict']:11} core={core_state:6}"
                  f"{'  ' + str(row.get('measuredKbps')) + ' kb/s' if 'measuredKbps' in row else ''}{written}{flag}", flush=True)
            if row.get('diagnostic'):
                print('    ' + row['diagnostic'][:220], flush=True)
    summary = {'tool': 'Test-RateControlMatrix.py', 'scope': 'real core compile + real FFmpeg on lavfi P010; no pipes, exporter or VEGAS',
               'host': facts, 'size': args.size, 'frames': args.frames, 'rows': rows}
    (output / 'summary.json').write_text(json.dumps(summary, indent=1), encoding='utf-8')
    counts = {v: sum(r['verdict'] == v for r in rows) for v in ('pass', 'rejected', 'unavailable', 'timeout', 'unreadable')}
    mismatches = [r for r in rows if r['mismatch']]
    print(f"\n{len(rows)} rows: " + ', '.join(f'{k} {v}' for k, v in counts.items()) + f"; {len(mismatches)} core/FFmpeg mismatches")
    print(f'Summary: {output / "summary.json"}')
    return 1 if mismatches else 0


if __name__ == '__main__':
    sys.exit(main())
