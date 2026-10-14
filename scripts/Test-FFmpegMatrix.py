"""B1 measured mux/readback/decode and format negotiation, from synthetic raw files.

No host, downloads or installation. Failures retain diagnostics in ignored build/.
Compatibility failures are distinguished from encode failures and timeouts.
"""
import argparse
import json
from pathlib import Path
import re
import struct
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from importlib import import_module
capture = import_module('Capture-FFmpegFacts')
run = capture.run
ROOT = capture.ROOT


def classify_remux(exit_code, stderr):
    """Only explicit measured codec/mux/profile refusals qualify a blocking rule."""
    if exit_code == 0:
        return 'invalid', ''  # Readback/decode must still qualify success.
    if exit_code is None:
        return 'timeout', stderr.strip()
    lines = [line.strip() for line in stderr.splitlines() if line.strip()]
    # Errno summaries such as "Operation not permitted" can follow an explicit
    # MXF codec refusal. Actual file/device failures must not become codec rules.
    environmental = re.compile(r'permission denied|access (?:is )?denied|no such file or directory|'
                               r'no space left on device|not enough space on the disk|disk full|'
                               r'input/output error|cannot load\b|DLL .*failed to (?:load|open)|'
                               r'error (?:creating|initializing).*?(?:MFX|CUDA|device|runtime)|'
                               r'no device available', re.I)
    diagnostic = next((line for line in lines if environmental.search(line)), None)
    if diagnostic:
        return 'error', diagnostic
    prefix = r'\[(?:mp4|mov|webm|mxf|pcm_rechunk)(?: @ [0-9a-fA-F]+)?\]\s+'
    refusal = re.compile(prefix + r'(?:'
        r'Could not find tag for codec \S+ in stream #\d+, codec not currently supported in container|'
        r'track \d+: could not find essence container ul, codec not currently supported in container|'
        r'\w+ only supported in MP4(?: and AVIF)?\.|'
        r'h264 profile not supported|'
        r'flac in MP4 support is experimental, add \'-strict -2\' if you want to use it\.|'
        r'Only VP8 or VP9 or AV1 video and Vorbis or Opus audio and WebVTT subtitles are supported for WebM\.|'
        r'Codec \'\w+\' \(\d+\) is not supported by the bitstream filter \'pcm_rechunk\'\.)', re.I)
    diagnostic = next((line for line in lines if refusal.match(line)), None)
    if diagnostic:
        return 'refused', diagnostic
    diagnostic = next((line for line in lines if re.search(r'error|failed|could not|not supported',line,re.I)),
                      lines[-1] if lines else 'Nonzero remux exit without a qualified refusal diagnostic.')
    return 'error', diagnostic


def measure(exe, facts_dir):
    facts = json.loads((facts_dir/'facts.json').read_text(encoding='utf-8'))
    capture.verify_capture_identity(exe, facts)
    directory = facts_dir/'matrix-fixed-rate'
    directory.mkdir(exist_ok=False)
    probe = exe.with_name('ffprobe.exe')
    def execute(label, args, timeout=15):
        value = run(exe, ['-hide_banner','-nostdin','-y', *args], timeout)
        (directory/(label+'.log')).write_text(value['stderr'], encoding='utf-8')
        return value
    def checked(label, args):
        value = execute(label, args)
        if value['exit'] != 0:
            raise RuntimeError(label + ': ' + value['stderr'][-3000:])
        return value
    video = directory/'video.raw'
    audio = directory/'audio.raw'
    checked('input-video',['-v','error','-f','lavfi','-i','testsrc2=s=320x180:r=25',
                           '-frames:v','3','-pix_fmt','p010le','-f','rawvideo',video])
    checked('input-audio',['-v','error','-f','lavfi','-i','sine=frequency=1000:sample_rate=48000',
                           '-t','0.12','-ac','2','-f','f32le',audio])
    vin = ['-f','rawvideo','-pix_fmt','p010le','-s','320x180','-r','25','-i',video]
    ain = ['-f','f32le','-ar','48000','-ac','2','-i',audio]
    variants = [
        ('h264','libx264',['-preset','veryfast','-profile:v','high','-crf','23','-pix_fmt','yuv420p']),
        ('hevc','libx265',['-preset','ultrafast','-crf','28','-pix_fmt','yuv420p10le','-x265-params','pools=1:frame-threads=1']),
        ('av1','libsvtav1',['-preset','12','-crf','35','-pix_fmt','yuv420p10le']),
        ('vp9','libvpx-vp9',['-deadline','realtime','-cpu-used','5','-crf','31','-b:v','0','-pix_fmt','yuv420p']),
        ('prores','prores_ks',['-profile:v','hq','-pix_fmt','yuv422p10le']),
        ('dnxhr','dnxhd',['-profile:v','dnxhr_hq','-pix_fmt','yuv422p']),
        ('ffv1','ffv1',['-level','3','-g','1','-slicecrc','1','-pix_fmt','yuv420p10le']),
    ]
    encoded = {}
    negotiation = []
    for family, name, options in variants:
        if not facts['encoders'][name]['recognized']:
            continue
        target = directory/(name+'.mkv')
        value = checked('encode-'+name, [*vin,'-an','-c:v',name,*options,'-threads','2','-f','matroska',target])
        encoded[family] = target
        # Remove explicit pix_fmt only. These are observed negotiation facts, not product defaults.
        omitted = {'-pix_fmt','-profile:v'} if name == 'libx264' else {'-pix_fmt'}
        auto = [x for i,x in enumerate(options) if x not in omitted and (i == 0 or options[i-1] not in omitted)]
        value = execute('negotiate-'+name,[*vin,'-an','-c:v',name,*auto,'-threads','2','-f','null','-'])
        match = re.search(r'Video: [^\n]*?, ([\w]+)(?:\(|,)', value['stderr'].split('Output #')[-1])
        negotiation.append(dict(encoder=name, exit=value['exit'], encoderPixelFormat=match[1] if match and value['exit'] == 0 else None))
    for profile in [p for p in json.loads((ROOT/'schema/encoder-profiles.v1.json').read_text(encoding='utf-8'))['audio']]:
        name = profile['id']
        if not facts['encoders'][name]['recognized']:
            continue
        target = directory/(name+'.mkv')
        opts = ['-b:a',str(profile.get('bitrate', {}).get('def', 160))+'k'] if 'bitrate' in profile else []
        value = checked('encode-'+name,[*ain,'-vn','-c:a',name,*opts,'-f','matroska',target])
        encoded[name] = target
        match = re.search(r'Audio: [^\n]*? stereo, ([\w]+)(?: \((\d+) bit\))?',value['stderr'].split('Output #')[-1])
        negotiation.append(dict(encoder=name, exit=0, encoderSampleFormat=match[1] if match else None,
                                usefulBits=int(match[2]) if match and match[2] else None))
    matrix = []
    def test(kind, key, container):
        target = directory/(kind+'-'+key+'-'+container['id']+container['ext'])
        if kind == 'video':
            args = ['-i',encoded[key],'-map','0:v:0','-c','copy']
            expected = [('video', {'dnxhr':'dnxhd'}.get(key,key))]
        else:
            companion = 'vp9' if container['id'] == 'webm' else 'dnxhr' if container['id'] == 'mxf' else 'h264'
            args = ['-i',encoded[companion],'-i',encoded[key],'-map','0:v:0','-map','1:a:0','-c','copy']
            expected = [('video',{'dnxhr':'dnxhd'}.get(companion,companion)),('audio',{'libopus':'opus','libmp3lame':'mp3'}.get(key,key))]
        # MKV's 1/1000 time base must not masquerade as the frame rate in MXF.
        value = execute(target.stem,[*args,'-r','25','-f',container['muxer'],target])
        status, error = classify_remux(value['exit'], value['stderr'])
        streams = []
        if value['exit'] == 0:
            back = run(probe,['-v','error','-show_streams','-of','json',target])
            if back['exit'] == 0:
                streams = json.loads(back['stdout']).get('streams', [])
                decoded = execute(target.stem+'-decode',['-v','error','-i',target,'-map','0','-f','null','-'])
                if [(s['codec_type'],s['codec_name']) for s in streams] == expected and decoded['exit'] == 0:
                    status = 'ok'
        matrix.append(dict(kind=kind, encoder=key, container=container['id'], status=status, exit=value['exit'],
                           streams=[dict(type=s['codec_type'],codec=s['codec_name'],tag=s.get('codec_tag_string')) for s in streams],
                           diagnostic=error))
    containers = json.loads((ROOT/'schema/encoder-profiles.v1.json').read_text(encoding='utf-8'))['containers']
    for key in [v[0] for v in variants if v[0] in encoded]:
        for container in containers:
            test('video',key,container)
    for key in [p['id'] for p in json.loads((ROOT/'schema/encoder-profiles.v1.json').read_text(encoding='utf-8'))['audio'] if p['id'] in encoded]:
        for container in containers:
            test('audio',key,container)
    # Check faststart atom ordering and requested hvc1 tags; no player compatibility claim.
    tagged = directory/'hevc-hvc1.mp4'
    checked('tag-faststart',['-i',encoded['hevc'],'-c','copy','-tag:v','hvc1','-movflags','+faststart',tagged])
    atoms = []
    with tagged.open('rb') as handle:
        while header := handle.read(8):
            size, typ = struct.unpack('>I4s',header)
            atoms.append(typ.decode('ascii'))
            if size == 1:
                size = struct.unpack('>Q',handle.read(8))[0]
                handle.seek(size-16,1)
            elif size >= 8:
                handle.seek(size-8,1)
            else:
                break
    back = json.loads(run(probe,['-v','error','-show_streams','-of','json',tagged])['stdout'])
    assert back['streams'][0]['codec_tag_string'] == 'hvc1' and atoms.index('moov') < atoms.index('mdat')
    result = dict(matrix=1, version=facts['version'], input=dict(video='P010 320x180, 25 fps, 3 frames',audio='float32 48 kHz stereo, 0.12 s'),
                  method='Encode raw inputs once, then stream-copy mux, ffprobe stream identity and complete decode.',
                  cases=matrix, negotiation=negotiation, faststartAtoms=atoms, appleTag='hvc1')
    (facts_dir/'matrix.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(f'{facts["version"]}: {len(matrix)} mux/readback/decode cases; {sum(c["status"] == "ok" for c in matrix)} pass; negotiation captured',flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('ffmpeg',type=Path)
    parser.add_argument('capture_directory',type=Path)
    args = parser.parse_args()
    directory = args.capture_directory.resolve(strict=True)
    if not directory.is_relative_to(ROOT/'build'):
        parser.error('Output must stay under this worktree build/.')
    measure(args.ffmpeg.resolve(strict=True),directory)
