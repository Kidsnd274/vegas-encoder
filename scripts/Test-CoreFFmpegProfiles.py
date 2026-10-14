"""Execute real core-generated B1 mode/depth/profile plans against a supplied build.

Hardware runs are local observations only. No installation or VEGAS calls. This
does not generate FakeVeCore fixtures; B0 remains a historical design sample.
"""
import argparse
from copy import deepcopy
import ctypes
import json
from pathlib import Path
import re
import sys
import uuid
from importlib import import_module

sys.path.insert(0,str(Path(__file__).resolve().parent))
capture = import_module('Capture-FFmpegFacts')
ROOT,run = capture.ROOT,capture.run


class Buffer(ctypes.Structure):
    _fields_ = [('data',ctypes.c_void_p),('length',ctypes.c_uint32)]


class Core:
    def __init__(self,path):
        self.dll = ctypes.CDLL(str(path))
        self.dll.ve_free.argtypes = [ctypes.c_void_p]
        self.dll.ve_free.restype = None

    def call(self,name,request):
        encoded = json.dumps(request,ensure_ascii=False).encode('utf-8')
        output = Buffer()
        fn = getattr(self.dll,name)
        fn.argtypes = [ctypes.c_char_p,ctypes.c_uint32,ctypes.POINTER(Buffer)]
        fn.restype = ctypes.c_int
        status = fn(encoded,len(encoded),ctypes.byref(output))
        try:
            result = ctypes.string_at(output.data,output.length)
            if status:
                raise RuntimeError(result.decode('utf-8'))
            return json.loads(result)
        finally:
            self.dll.ve_free(output.data)


def check(core,exe,directory,recheck=False):
    facts = json.loads((directory/'facts.json').read_text(encoding='utf-8'))
    capture.verify_capture_identity(exe, facts)
    profiles = json.loads((ROOT/'schema/encoder-profiles.v1.json').read_text(encoding='utf-8'))
    sample = json.loads((ROOT/'schema/fixtures/b0/core-and-services.json').read_text(encoding='utf-8'))['fixtures'][0]
    output = directory/('core-profiles-'+uuid.uuid4().hex)
    if not recheck:
        output.mkdir(exist_ok=False)
    previous = json.loads((directory/'core-profiles.json').read_text(encoding='utf-8')) if recheck else None
    raw = directory/'matrix-fixed-rate'
    caps = dict(installationId='b1-test',version=facts['version'],libavformatMajor=int(facts['libraries']['libavformat'].split('.')[0]),
                encoders={k:dict(v,availability={'state':'unknown'}) for k,v in facts['encoders'].items() if v['recognized']},muxers=facts['muxers'])
    media = dict(video=dict(width=320,height=180,fps=[25,1],pixfmt='p010le',sar='1:1'),audio=dict(rate=48000,channels=2,sampleFmt='f32le'))
    results = []
    for kind in ['video','audio']:
        for profile in profiles[kind]:
            name = profile['id']
            if not facts['encoders'][name]['recognized']:
                continue
            settings = [{}]
            if kind == 'video':
                settings += [dict(mode=mode) for mode in profile['modes'][1:]]
                settings += [dict(depth=int(depth)) for depth in profile['depths'] if int(depth) != profile['depthDef']]
                if profile.get('profileQuality'):
                    settings += [dict(profile=value) for value in profile['profileQuality']['values'] if value != profile['profileQuality']['def']]
            else:
                settings += [dict(mode=mode) for mode in profile['modes'][1:]]
            for index,changes in enumerate(settings):
                label = name+'-'+str(index)
                recipe = deepcopy(sample['recipe'])
                recipe['container'] = {'format':'mkv'}
                recipe['video'] = {'encoder':name if kind == 'video' else 'libx264',**(changes if kind == 'video' else {})}
                recipe['audio'] = [{'encoder':name if kind == 'audio' else 'aac','enabled':kind == 'audio',**(changes if kind == 'audio' else {})}]
                paths = dict(ffmpeg=str(exe),videoPipe=str(raw/'video.raw'),audioPipe=str(raw/'audio.raw'),output=str(output/(label+'.mkv')),project='B1 synthetic')
                plan = core.call('ve_compile',dict(recipe=recipe,media=media,paths=paths,capabilities=caps))
                errors = [i for i in plan['issues'] if i['level'] == 'error']
                if errors:
                    raise AssertionError(f'{label} generated invalid plan: {errors}')
                if recheck:
                    recorded = previous['checks'][len(results)]
                    argv = [Path(a).name if a in list(paths.values()) else a for a in plan['argv']]
                    assert recorded['encoder'] == name and recorded['settings'] == changes and recorded['argv'] == argv, label+' changed after the recorded encode'
                    results.append(recorded)
                    continue
                result = run(exe,plan['argv'],timeout=10 if profile.get('hw') else 30)
                (output/(label+'.log')).write_text(result['stderr'],encoding='utf-8')
                row = dict(encoder=name,kind=kind,settings=changes,argv=plan['argv'],exit=result['exit'],ms=result['ms'],hardware=bool(profile.get('hw')))
                if result['exit'] == 0:
                    back = run(exe.with_name('ffprobe.exe'),['-v','error','-show_streams','-of','json',paths['output']])
                    assert back['exit'] == 0
                    streams = json.loads(back['stdout'])['streams']
                    target = streams[0] if kind == 'video' else streams[1]
                    assert target['codec_name'] == {'dnxhr':'dnxhd','ac3':'eac3' if name=='eac3' else 'ac3','pcmf':'pcm_f32le','pcm':name}.get(profile['family'],profile['family'])
                    row['decodedFormat'] = target.get('pix_fmt',target.get('sample_fmt'))
                    decoded = run(exe,['-v','error','-i',paths['output'],'-map','0','-f','null','-'],timeout=30)
                    assert decoded['exit'] == 0, decoded['stderr']
                    # Distinguish the raw encoder input (signal fact) from codec readback.
                    stream_text = result['stderr'].split('Output #')[-1]
                    if kind == 'audio':
                        match = re.search(r'Audio: [^\n]*? stereo, (\w+)',stream_text)
                        assert match and match[1] == plan['signalPath']['audio'][0]['outputFormat'], (label,stream_text)
                    if name == 'libsvtav1':
                        row['rateControlLog'] = [l.strip() for l in result['stderr'].splitlines() if 'BRC' in l or 'CRF' in l or 'CQP' in l or 'QP ' in l]
                    elif name == 'libx265':
                        row['rateControlLog'] = [l.strip() for l in result['stderr'].splitlines() if 'Rate Control' in l]
                elif not profile.get('hw'):
                    raise AssertionError(f'{label}: {result["stderr"][-4000:]}')
                else:
                    row['failure'] = next((l.strip() for l in result['stderr'].splitlines() if any(t in l.lower() for t in ['cannot','failed','error','unsupported','no capable'])),result['stderr'][-400:])
                # Local file paths are diagnostic, not portable catalog facts.
                row['argv'] = [Path(a).name if a in list(paths.values()) else a for a in row['argv']]
                results.append(row)
    if recheck:
        assert len(results) == len(previous['checks'])
        print(f'{facts["version"]}: {len(results)} final core plans match the recorded encode/readback/decode run.',flush=True)
        return
    (directory/'core-profiles.json').write_text(json.dumps(dict(version=facts['version'],checks=results),indent=2)+'\n',encoding='utf-8')
    print(f'{facts["version"]}: {len(results)} native-generated mode/depth/profile plans, '
          f'{sum(r["exit"]==0 for r in results)} encode/readback/decode passes; '
          f'{sum(r["hardware"] and r["exit"]!=0 for r in results)} local hardware failures',flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('ffmpeg',type=Path)
    parser.add_argument('capture_directory',type=Path)
    parser.add_argument('--core',type=Path,default=ROOT/'build/core/ve_core.dll')
    parser.add_argument('--recheck',action='store_true',help='Compile-only parity with the recorded successful/failed hardware run; no new encodes')
    args = parser.parse_args()
    directory = args.capture_directory.resolve(strict=True)
    if not directory.is_relative_to(ROOT/'build'):
        parser.error('Output must stay within worktree build/.')
    check(Core(args.core.resolve(strict=True)),args.ffmpeg.resolve(strict=True),directory,args.recheck)
