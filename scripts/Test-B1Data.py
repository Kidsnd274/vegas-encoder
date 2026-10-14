"""Focused B1 parser/catalog regressions. No FFmpeg execution or network."""
from importlib import import_module
from copy import deepcopy
import json
from pathlib import Path
import sys
from unittest.mock import patch

sys.path.insert(0,str(Path(__file__).resolve().parent))
capture = import_module('Capture-FFmpegFacts')
ROOT = capture.ROOT
checks = 0


def check(condition,message):
    global checks
    checks += 1
    if not condition:
        raise AssertionError(message)


fixtures = ROOT/'schema/fixtures/ffmpeg'
old = capture.parse_help((fixtures/'old-h264_amf.txt').read_text(encoding='utf-8'),'h264_amf','video')
current = capture.parse_help((fixtures/'current-hevc_nvenc.txt').read_text(encoding='utf-8'),'hevc_nvenc','video')
old_nv = capture.parse_help((fixtures/'old-hevc_nvenc.txt').read_text(encoding='utf-8'),'hevc_nvenc','video')
dnx = capture.parse_help((fixtures/'current-dnxhd.txt').read_text(encoding='utf-8'),'dnxhd','video')
unknown = capture.parse_help((fixtures/'old-ve_b1_nonexistent.txt').read_text(encoding='utf-8'),'ve_b1_nonexistent','video')
option = lambda e,n: next(o for o in e['options'] if o['name'] == n)
check(old['recognized'] and current['recognized'] and dnx['recognized'],'encoder headers')
check(not unknown['recognized'] and not unknown['options'],'unknown encoder exit-zero text is not success')
check(option(old,'rc')['defaultValue'] == '-1','negative default')
check([c['name'] for c in option(old,'rc')['constants']] == ['cqp','cbr','vbr_peak','vbr_latency'],'old AMF enum')
check('uhq' in [c['name'] for c in option(current,'tune')['constants']],'new NVENC enum')
check(option(current,'rc')['max'] == 'INT_MAX','symbolic bound preserved')
check(option(old_nv,'spatial_aq')['aliases'] == ['spatial-aq'],'option aliases merged')
check(len([o for o in dnx['options'] if o['name'] == 'profile']) == 1,'DNxHD profile declaration parsed')
check('dnxhr_hqx' in [c['name'] for c in option(dnx,'profile')['constants']],'DNxHD profile constants retained')
repeated = ('Encoder duplicate [duplicate]:\n'
            '  -profile <int> E..V....... profile (from 0 to 5) (default 0)\n'
            '     first 0 E..V....... first declaration\n'
            '  -profile <int> E..V....... profile (from 0 to 5) (default 0)\n'
            '     second 1 E..V....... second declaration\n'
            '     first 0 E..V....... first declaration\n')
duplicate = capture.parse_help(repeated,'duplicate','video')
check(len(duplicate['options']) == 1,'repeated option declaration merged')
check([c['name'] for c in option(duplicate,'profile')['constants']] == ['first','second'],
      'constants from both declarations retained once')
synthetic = 'Encoder sample [sample]:\r\n  -flags <flags> E..V....... text (in parentheses) (default 0)\r\n     long-flag-name E..V....... no integer\r\n'
parsed = capture.parse_help(synthetic,'sample','video')
check(parsed['options'][0]['description'] == 'text (in parentheses)','description parentheses')
check(parsed['options'][0]['constants'][0]['value'] is None,'valueless flag constant')
check(capture.parse_help('Encoder pcm [PCM]:\n','pcm','audio')['options'] == [],'valid encoder without private options')
catalog = json.loads((ROOT/'schema/encoder-profiles.v1.json').read_text(encoding='utf-8'))
data = json.loads((ROOT/'schema/ffmpeg/windows-builds.v1.json').read_text(encoding='utf-8'))
check('B1 measured Windows' in catalog['provenance'] and 'not VEGAS' in catalog['provenance'],'qualification limits remain explicit')
check(len(data['measurements']) == 3,'three exact builds retained')
for build in data['measurements']:
    check(len(build['matrix']['cases']) == 85,'complete measured matrix')
    check(len(build['genericOptions']) < 150 and any(o['name'] == 'global_quality' for o in build['genericOptions']),'generic section isolated')
    check(build['unknownEncoder']['exit'] == 0 and not build['unknownEncoder']['recognized'],'unknown help result preserved')
    for p in catalog['video']:
        e = build['encoders'][p['id']]
        if not e['recognized']:
            continue
        for fmt in p['depths'].values():
            check(fmt in e['pixelFormats'],p['id']+' curated depth supported')
    for p in catalog['audio']:
        e = build['encoders'][p['id']]
        if e['recognized']:
            check(p['sampleFormat'] in e['sampleFormats'],p['id']+' observed float-source sample format supported')
            if e['sampleRates']:
                check(set(p['rates']).issubset(e['sampleRates']),p['id']+' curated rates supported')
amf = next(p for p in catalog['video'] if p['id'] == 'h264_amf')
check(amf['modes'] == ['abr','cbr','cqp'] and amf['qp']['flag'] == '-qp_i','AMF modes do not invent old-build CQ support')
fdk = next(p for p in catalog['audio'] if p['id'] == 'libfdk_aac')
check(fdk['sampleFormat'] is None and not fdk['qualification']['helpBuilds'],'uncaptured FDK format stays unknown')
old_rules = catalog['compatibilityByAvformatMajor']['59']
new_rules = catalog['compatibilityByAvformatMajor']['63']
check(old_rules['audio']['pcm']['mp4'] == 'no' and new_rules['audio']['pcm']['mp4'] == 'warn','version-specific MP4 PCM support')
check(old_rules['video']['ffv1']['mp4'] == 'no' and new_rules['video']['ffv1']['mp4'] == 'warn','version-specific FFV1 support')
check(catalog['compatibility']['audio']['pcm']['mp4'] == 'warn','unknown version does not inherit old-build rejection')

# Identity guards must reject same-banner configuration/library changes, as well
# as a mismatched companion probe, before either measurement runner writes files.
def identity_outputs(identity):
    banner = '\n'.join([f'ffmpeg version {identity["version"]}',
                        'configuration: '+identity['configuration'],
                        *(f'{name} {value} / {value}' for name,value in identity['libraries'].items())])
    structured = dict(program_version={k:identity[k] for k in ['version','configuration']},
                      library_versions=[dict(name=name,**dict(zip(['major','minor','micro'],map(int,value.split('.')))))
                                        for name,value in identity['libraries'].items()])
    return [dict(exit=0,stdout=banner,stderr=''),dict(exit=0,stdout=json.dumps(structured),stderr='')]


def rejects(action, message):
    try:
        action()
    except RuntimeError:
        check(True,message)
    else:
        check(False,message)


executable = Path('fixture-bin/ffmpeg.exe')
for build in data['measurements']:
    with patch.object(capture,'run',side_effect=identity_outputs(build)) as invoke:
        check(capture.verify_capture_identity(executable,build) == {k:build[k] for k in ['version','configuration','libraries']},
              'exact FFmpeg/FFprobe/capture identity matches')
        check(invoke.call_count == 2 and invoke.call_args.args[0] == executable.with_name('ffprobe.exe'),
              'identity guard checks the adjacent FFprobe')
baseline = {k:data['measurements'][1][k] for k in ['version','configuration','libraries']}
for key in ['version','configuration','libraries']:
    altered = deepcopy(baseline)
    if key == 'libraries':
        altered[key]['libavformat'] = '63.999.100'
    else:
        altered[key] += '-different'
    with patch.object(capture,'run',side_effect=identity_outputs(altered)):
        rejects(lambda: capture.verify_capture_identity(executable,baseline),'different captured '+key+' rejected')
    with patch.object(capture,'run',side_effect=[identity_outputs(baseline)[0],identity_outputs(altered)[1]]):
        rejects(lambda: capture.verify_capture_identity(executable,baseline),'different companion FFprobe '+key+' rejected')
for responses in [[dict(exit=None,stdout='',stderr='Hard timeout')],
                  [identity_outputs(baseline)[0],dict(exit=None,stdout='',stderr='Hard timeout')],
                  [identity_outputs(baseline)[0],dict(exit=0,stdout='invalid JSON',stderr='')]]:
    with patch.object(capture,'run',side_effect=responses):
        rejects(lambda: capture.verify_capture_identity(executable,baseline),'failed/incomplete identity cannot qualify a runner')
for module_name in ['Test-FFmpegMatrix','Test-CoreFFmpegProfiles']:
    runner = import_module(module_name)
    with patch.object(Path,'read_text',return_value=json.dumps(baseline)), \
         patch.object(Path,'mkdir') as mkdir, \
         patch.object(capture,'run',side_effect=identity_outputs(data['measurements'][0])):
        action = (lambda: runner.measure(executable,Path('unused-capture'))) if module_name == 'Test-FFmpegMatrix' else \
                 (lambda: runner.check(None,executable,Path('unused-capture')))
        rejects(action,module_name+' rejects wrong executable identity')
        check(not mkdir.called,module_name+' creates no output on identity mismatch')

matrix_runner = import_module('Test-FFmpegMatrix')
promotion = import_module('Generate-WindowsFFmpegData')
qualified = deepcopy(data['measurements'][1]['matrix'])
promotion.validate_matrix(qualified)
check(True,'existing current matrix has qualified refusal diagnostics')
refused_index = next(i for i,c in enumerate(qualified['cases']) if c['status'] == 'refused')
refusal = qualified['cases'][refused_index]['diagnostic']
for message in ['Error opening output file output.mp4: Permission denied',
                'Could not write header: Access is denied',
                'Error opening input file input.mkv: No such file or directory',
                'Error writing trailer: No space left on device',
                'Error writing output file: Input/output error',
                'Cannot load avformat-63.dll',
                'DLL amfrt64.dll failed to open',
                'Error creating a MFX session: -9',
                'The requested feature is not supported',
                'Could not write header: Unknown error occurred']:
    status,diagnostic = matrix_runner.classify_remux(1,message)
    check(status == 'error' and diagnostic == message,'environment/unknown failure stays unqualified')
    bad = deepcopy(qualified)
    bad['cases'][refused_index].update(status='refused',exit=1,diagnostic=message)
    rejects(lambda: promotion.validate_matrix(bad),'environment/unknown failure cannot become a blocking rule')
check(matrix_runner.classify_remux(1,refusal+'\nError writing trailer: No space left on device')[0] == 'error',
      'explicit environmental failure takes priority over a refusal')
check(matrix_runner.classify_remux(None,refusal)[0] == 'timeout','timeout cannot qualify a refusal')
check(matrix_runner.classify_remux(0,refusal)[0] == 'invalid','exit zero still requires readback/decode')
for status in ['error','invalid','timeout']:
    bad = deepcopy(qualified)
    bad['cases'][refused_index]['status'] = status
    rejects(lambda: promotion.validate_matrix(bad),'unqualified matrix status cannot be promoted')
bad = deepcopy(qualified)
bad['cases'][refused_index]['exit'] = 0
rejects(lambda: promotion.validate_matrix(bad),'refusal cannot have exit zero')
print(f'B1 data: {checks} parser/catalog/build-qualification checks passed (offline; no host).')
