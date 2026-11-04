"""Check core-generated resize chains with supplied Windows FFmpeg; no VEGAS/install.

Use a capabilities JSON produced by the real ve_services probe. All generated
media and concise diagnostics stay in a fresh build/test-results directory.
"""
import argparse
from copy import deepcopy
import ctypes
import importlib
import json
from pathlib import Path
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
_core_test = importlib.import_module('Test-CoreFFmpegProfiles')
Core, Buffer = _core_test.Core, _core_test.Buffer


def run(executable, arguments):
    result = subprocess.run([str(executable), *arguments], capture_output=True, timeout=45)
    if result.returncode:
        raise AssertionError(result.stderr.decode('utf-8', errors='replace')[-4000:])
    return result.stdout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('ffmpeg', type=Path)
    parser.add_argument('capabilities', type=Path)
    parser.add_argument('--core', type=Path, default=ROOT / 'build/release/vegas-encoder/core/ve_core.dll')
    parser.add_argument('--legacy-core', type=Path, help='Optional preserved schema-1 core; read-only compatibility check')
    args = parser.parse_args()
    executable = args.ffmpeg.resolve(strict=True)
    probe = executable.with_name('ffprobe.exe')
    caps = json.loads(args.capabilities.read_text(encoding='utf-8'))
    caps = caps.get('capabilities', caps)
    core = Core(args.core.resolve(strict=True))
    folder = ROOT / 'build/test-results' / ('core-filters-' + uuid.uuid4().hex[:12])
    folder.mkdir(parents=True, exist_ok=False)
    catalog = json.loads((ROOT / 'schema/builtin-presets.v1.json').read_text(encoding='utf-8'))
    base = next(p['recipe'] for p in catalog['presets'] if p['recipe']['id'] == 'ffv1-master')
    rows = []
    checks = 0
    if args.legacy_core:
        legacy = Core(args.legacy_core.resolve(strict=True))
        recipe = json.loads((ROOT / 'schema/fixtures/retired-presets/h264-nvenc-720p-3500.v2.json').read_text(encoding='utf-8'))['recipe']
        rejected = legacy.call('ve_recipe_normalize', {'recipe': recipe})
        assert any(i['level'] == 'error' for i in rejected['issues']), 'old core must reject schema-2 recipe'
        snapshot = {'recipe': recipe, 'origin': None, 'vegasPrefs': {}, 'writtenBy': 'filter-compatibility-test'}
        encoded = json.dumps(snapshot).encode('utf-8')
        output = Buffer()
        fn = core.dll.ve_payload_encode
        fn.argtypes = [ctypes.c_char_p, ctypes.c_uint32, ctypes.POINTER(Buffer)]
        fn.restype = ctypes.c_int
        assert fn(encoded, len(encoded), ctypes.byref(output)) == 0
        try:
            payload = ctypes.string_at(output.data, output.length)
        finally:
            core.dll.ve_free(output.data)
        decoded = Buffer()
        fn = legacy.dll.ve_payload_decode
        fn.argtypes = [ctypes.c_char_p, ctypes.c_uint32, ctypes.POINTER(Buffer)]
        fn.restype = ctypes.c_int
        assert fn(payload, len(payload), ctypes.byref(decoded)) == 0
        try:
            refused = json.loads(ctypes.string_at(decoded.data, decoded.length))
        finally:
            legacy.dll.ve_free(decoded.data)
        assert refused['snapshot'] is None and any(i['level'] == 'error' for i in refused['issues'])
        checks += 2
    # delivered width, height, SAR, encoded width, height
    cases = [
        ('upscale', 320, 180, '1:1', 640, 360),
        ('downscale', 320, 180, '1:1', 160, 90),
        ('unchanged', 320, 180, '1:1', 320, 180),
        ('four-three', 320, 240, '1:1', 320, 180),
        ('portrait', 180, 320, '1:1', 320, 180),
        ('anamorphic', 320, 240, '4:3', 320, 180),
        ('rounded', 322, 238, '1:1', 320, 180),
    ]
    try:
        for label, width, height, sar, target_w, target_h in cases:
            raw = folder / f'{label}.raw'
            run(executable, ['-v', 'error', '-nostdin', '-f', 'lavfi', '-i',
                f'color=c=white:size={width}x{height}:rate=1', '-frames:v', '2',
                '-pix_fmt', 'p010le', '-f', 'rawvideo', str(raw)])
            media = {'video': {'width': width, 'height': height, 'fps': [1, 1],
                'pixfmt': 'p010le', 'sar': sar}, 'audio': None, 'durationSec': 2}
            for algorithm in ['bicubic', 'bilinear', 'lanczos', 'neighbor']:
                recipe = deepcopy(base)
                recipe['schema'] = 2
                recipe['audio'][0]['enabled'] = False
                recipe['video']['filters'] = [{'type': 'resize', 'enabled': True,
                    'width': target_w, 'height': target_h, 'backend': 'scale',
                    'algorithm': algorithm, 'fit': 'pad'}]
                output = folder / f'{label}-{algorithm}.mkv'
                paths = {'ffmpeg': str(executable), 'videoPipe': str(raw), 'audioPipe': None,
                    'output': str(output), 'project': ''}
                plan = core.call('ve_compile', {'recipe': recipe, 'media': media,
                    'paths': paths, 'capabilities': caps})
                errors = [i for i in plan['issues'] if i['level'] == 'error']
                assert not errors, (label, algorithm, errors)
                assert f'{width}x{height}' in plan['argv'], 'raw pipe must keep delivered size'
                run(executable, plan['argv'])
                streams = json.loads(run(probe, ['-v', 'error', '-count_frames',
                    '-show_streams', '-of', 'json', str(output)]))['streams']
                video = streams[0]
                assert (video['width'], video['height']) == (target_w, target_h)
                assert video['sample_aspect_ratio'] == '1:1'
                assert video['pix_fmt'] == 'yuv420p10le'
                assert video['nb_read_frames'] == '2'
                pixels = run(executable, ['-v', 'error', '-xerror', '-i', str(output),
                    '-map', '0:v:0', '-pix_fmt', 'rgb24', '-f', 'rawvideo', '-'])
                assert len(pixels) == target_w * target_h * 3 * 2, 'full decode'
                middle = ((target_h // 2) * target_w + target_w // 2) * 3
                assert min(pixels[middle:middle + 3]) > 210, 'picture remains in canvas'
                if label in ['four-three', 'portrait', 'rounded']:
                    assert max(pixels[:3]) < 24, 'pillarbox is black'
                if label == 'anamorphic':
                    assert min(pixels[:3]) > 210, 'display aspect ratio fills 16:9 canvas'
                geometry = plan['videoGeometry']
                assert (geometry['width'], geometry['height']) == (target_w, target_h)
                checks += 9
                # The seeded Advanced command must adapt to a different delivered
                # size/SAR, rather than freezing the sample fit rectangle.
                if algorithm == 'bicubic' and label == 'four-three':
                    advanced = deepcopy(recipe)
                    advanced['command'] = {'mode': 'template', 'template': plan['advancedTemplate']}
                    other = folder / 'seeded-portrait.raw'
                    run(executable, ['-v', 'error', '-nostdin', '-f', 'lavfi', '-i',
                        'color=c=white:size=180x320:rate=1', '-frames:v', '2',
                        '-pix_fmt', 'p010le', '-f', 'rawvideo', str(other)])
                    advanced_paths = {**paths, 'videoPipe': str(other), 'output': str(folder / 'seeded.mkv')}
                    advanced_media = {**media, 'video': {**media['video'], 'width': 180, 'height': 320}}
                    seeded = core.call('ve_compile', {'recipe': advanced, 'media': advanced_media,
                        'paths': advanced_paths, 'capabilities': caps})
                    assert not [i for i in seeded['issues'] if i['level'] == 'error']
                    run(executable, seeded['argv'])
                    seeded_video = json.loads(run(probe, ['-v', 'error', '-show_streams',
                        '-of', 'json', advanced_paths['output']]))['streams'][0]
                    assert (seeded_video['width'], seeded_video['height']) == (target_w, target_h)
                    seeded_pixels = run(executable, ['-v', 'error', '-xerror', '-i', advanced_paths['output'],
                        '-pix_fmt', 'rgb24', '-f', 'rawvideo', '-'])
                    # A fit rectangle frozen from the old 4:3 input would put
                    # white picture here; source-relative portrait fitting does not.
                    side = ((target_h // 2) * target_w + 100) * 3
                    assert max(seeded_pixels[side:side + 3]) < 24
                    checks += 4
                    rows.append({'case': 'advanced-seed-portrait', 'algorithm': algorithm,
                        'width': seeded_video['width'], 'height': seeded_video['height'],
                        'sar': seeded_video['sample_aspect_ratio']})
                rows.append({'case': label, 'algorithm': algorithm,
                    'width': video['width'], 'height': video['height'], 'sar': video['sample_aspect_ratio']})
        # Effective pixel-format overrides alter the required chroma grid. Cover
        # 8-bit 4:2:0, 10-bit 4:2:2 and an odd-sized 10-bit 4:4:4 canvas too.
        for pixel_format, target_w, target_h in [
            ('yuv420p', 320, 180), ('yuv422p10le', 320, 181), ('yuv444p10le', 321, 181),
        ]:
            recipe = deepcopy(base)
            recipe['schema'] = 2
            recipe['audio'][0]['enabled'] = False
            recipe['video']['extra'] = '-pix_fmt ' + pixel_format
            recipe['video']['filters'] = [{'type': 'resize', 'enabled': True,
                'width': target_w, 'height': target_h, 'backend': 'scale',
                'algorithm': 'bicubic', 'fit': 'pad'}]
            media = {'video': {'width': 322, 'height': 238, 'fps': [1, 1],
                'pixfmt': 'p010le', 'sar': '1:1'}, 'audio': None}
            output = folder / f'{pixel_format}.mkv'
            paths = {'ffmpeg': str(executable), 'videoPipe': str(folder / 'rounded.raw'),
                'audioPipe': None, 'output': str(output), 'project': ''}
            plan = core.call('ve_compile', {'recipe': recipe, 'media': media,
                'paths': paths, 'capabilities': caps})
            assert not [i for i in plan['issues'] if i['level'] == 'error'], plan['issues']
            run(executable, plan['argv'])
            video = json.loads(run(probe, ['-v', 'error', '-show_streams', '-of', 'json', str(output)]))['streams'][0]
            assert (video['width'], video['height'], video['pix_fmt']) == (target_w, target_h, pixel_format)
            run(executable, ['-v', 'error', '-xerror', '-i', str(output), '-f', 'null', '-'])
            checks += 3
            rows.append({'case': pixel_format, 'algorithm': 'bicubic',
                'width': target_w, 'height': target_h, 'sar': video['sample_aspect_ratio']})
        report = {'checks': checks, 'encodes': len(rows), 'cases': rows,
            'scope': 'real FFmpeg, synthetic input; no VEGAS'}
        (folder / 'summary.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
        print(f'CORE FILTERS PASSED: {checks} checks, {len(rows)} encodes/readbacks/full decodes; no VEGAS.')
        print(f'Result: {folder / "summary.json"}')
    except Exception:
        print(f'Diagnostics retained in {folder}', file=sys.stderr)
        raise


if __name__ == '__main__':
    main()
