"""Promote B1 parsed Windows captures into committed catalog/probe fixtures.

No network, executable launches or edited-state FakeVeCore sweep. Profile controls
remain product policy; measured AVOption defaults are retained separately.
"""
import argparse
from copy import deepcopy
from importlib import import_module
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'scripts'))
matrix_runner = import_module('Test-FFmpegMatrix')


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')


def validate_matrix(matrix):
    cases = matrix['cases']
    if len(cases) != 85 or any(c['status'] not in ['ok','refused'] for c in cases):
        raise RuntimeError('Incomplete/unqualified matrix; errors, invalid outputs and timeouts cannot be promoted.')
    for case in cases:
        if case['status'] == 'ok':
            if case['exit'] != 0:
                raise RuntimeError('A successful matrix case must have exit zero.')
        elif matrix_runner.classify_remux(case['exit'],case['diagnostic'])[0] != 'refused':
            raise RuntimeError('A refused matrix case needs an explicit codec/mux/profile refusal diagnostic.')


def generate(directories):
    builds = []
    for directory in directories:
        facts = json.loads((directory/'facts.json').read_text(encoding='utf-8'))
        matrix = json.loads((directory/'matrix.json').read_text(encoding='utf-8'))
        assert facts['version'] == matrix['version']
        validate_matrix(matrix)
        for case in matrix['cases']:
            case['diagnostic'] = re.sub(r' @ [0-9a-fA-F]+', '', case['diagnostic'])
        facts.pop('pixelFormats')  # Full descriptor listing stays in ignored captures.
        facts['matrix'] = matrix
        builds.append(facts)
    assert len(builds) == 3 and {b['libraries']['libavformat'].split('.')[0] for b in builds} == {'59','63'}
    provenance = 'B1 measured Windows x64: gyan 5.1.2 (shared); gyan 2026-10-12 git 615b07170e (static); BtbN 2026-10-13 git 24e860f6d3 (shared). Synthetic offline checks, not VEGAS qualification.'
    write(ROOT/'schema/ffmpeg/windows-builds.v1.json',dict(builds=1,provenance=provenance,measurements=builds))
    baseline = builds[1]
    write(ROOT/'schema/encoder-options.windows.v1.json',dict(provenance=provenance,baselineVersion=baseline['version'],
                                                            encoders={n:e for n,e in baseline['encoders'].items() if e['recognized']}))
    profiles = json.loads((ROOT/'schema/encoder-profiles.v1.json').read_text(encoding='utf-8'))
    profiles['provenance'] = provenance
    profiles['policy'] = 'Control defaults, curated ranges/choices, quality marks and size-model coefficients are product choices, not measured encoder defaults or quality guarantees. AVOption defaults live in Windows probe fixtures.'
    for kind in ['video','audio']:
        for profile in profiles[kind]:
            name = profile['id']
            tested = [b['version'] for b in builds if b['encoders'][name]['recognized']]
            profile['qualification'] = dict(helpBuilds=tested, runtime='hardware not qualified' if profile.get('hw') else 'synthetic P010/float32 checks' if tested else 'not captured: absent from all three GPL builds')
            for control in ['quality','qp','vbr','level']:
                if isinstance(profile.get(control), dict):
                    profile[control]['defaultSource'] = 'product policy'
                    for mark in profile[control].get('marks',[]):
                        mark[1] = mark[1].replace('Visually lossless','High quality').replace('FFmpeg default','Reference value')
            if kind == 'audio' and tested:
                rates = set.intersection(*(set(b['encoders'][name]['sampleRates']) for b in builds if b['encoders'][name]['recognized']))
                if rates:
                    profile['rates'] = sorted(rates)
                samples = [n['encoderSampleFormat'] for b in builds for n in b['matrix']['negotiation'] if n['encoder'] == name]
                assert len(set(samples)) == 1 and samples[0] == profile['sampleFormat']
            if name == 'libfdk_aac':
                profile['sampleFormat'] = None
                profile['sampleBits'] = None
            if name.endswith('_nvenc'):
                tune = next(o for o in baseline['encoders'][name]['options'] if o['name'] == 'tune')
                profile['tune']['values'] = [c['name'] for c in tune['constants']]
            # Repair mojibake inherited from the prototype's fixture-generation locale.
            for key,value in list(profile.items()):
                if isinstance(value,str):
                    try:
                        profile[key] = value.encode('cp1252').decode('utf-8')
                    except (UnicodeError,UnicodeDecodeError):
                        pass
    amf = next(p for p in profiles['video'] if p['id'] == 'h264_amf')
    amf['modes'] = ['abr','cbr','cqp']
    amf.pop('quality',None)  # qp_i alone is not constant quality; newer qvbr is version-specific.
    amf['qp'] = {'flag':'-qp_i','min':0,'max':51,'step':1,'def':20,'defaultSource':'product policy'}
    profiles['compatibilityByAvformatMajor'] = {}
    families = {p['id']:p['family'] for p in profiles['audio']}
    caveats = {('video','vp9','mp4'),('video','h264','mxf'),('video','ffv1','mp4'),('video','ffv1','mov'),('video','ffv1','mxf'),
               ('audio','flac','mp4'),('audio','pcm','mp4'),('audio','pcmf','mp4')}
    tables = []
    for build in builds:
        table = {'video':{},'audio':{}}
        for case in build['matrix']['cases']:
            kind, container = case['kind'],case['container']
            family = families[case['encoder']] if kind == 'audio' else case['encoder']
            value = 'ok' if case['status'] == 'ok' else 'no'
            # h264/MXF is profile-dependent; old FLAC/MP4 needs -strict experimental.
            if (kind,family,container) in caveats and (value == 'ok' or (family == 'h264' and container == 'mxf') or (family == 'flac' and container == 'mp4')):
                value = 'warn'
            row = table[kind].setdefault(family,{})
            if container in row:
                assert row[container] == value, 'Family members disagree; do not generalize'
            row[container] = value
        tables.append(table)
        major = build['libraries']['libavformat'].split('.')[0]
        if major in profiles['compatibilityByAvformatMajor']:
            assert profiles['compatibilityByAvformatMajor'][major] == table
        profiles['compatibilityByAvformatMajor'][major] = table
    # Unknown/unprobed versions block only combinations rejected by all tested builds.
    consensus = deepcopy(tables[0])
    for kind,rows in consensus.items():
        for family,row in rows.items():
            for container in row:
                values = {t[kind][family][container] for t in tables}
                row[container] = next(iter(values)) if len(values) == 1 else 'warn'
    profiles['compatibility'] = consensus
    write(ROOT/'schema/encoder-profiles.v1.json',profiles)
    fixture_dir = ROOT/'schema/fixtures/ffmpeg'
    for directory, name in [(directories[0],'h264_amf'),(directories[0],'hevc_nvenc'),(directories[1],'hevc_nvenc'),(directories[1],'dnxhd'),(directories[0],'ve_b1_nonexistent')]:
        source = directory/('unknown.txt' if name == 've_b1_nonexistent' else 'encoder-'+name+'.txt')
        target = fixture_dir/(('old-' if directory == directories[0] else 'current-')+name+'.txt')
        target.parent.mkdir(parents=True,exist_ok=True)
        # Preserve help layout for parser fixtures; raw captures remain in build/.
        text = '\n'.join(line.rstrip() for line in source.read_text(encoding='utf-8').splitlines()).rstrip() + '\n'
        target.write_text(text,encoding='utf-8')
    print('Promoted measured Windows options, versioned matrix and qualified product profiles; B0 design fixtures unchanged.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('captures',nargs=3,type=Path,help='Older gyan, current gyan, current BtbN capture folders, in that order')
    args = parser.parse_args()
    generate(args.captures)
