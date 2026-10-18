"""Execute offline native-generated plans on user-supplied FFmpeg. No host/install."""
import argparse
from array import array
import json
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('directory',type=Path)
parser.add_argument('ffmpeg',type=Path)
args = parser.parse_args()
directory = args.directory.resolve()
ffmpeg = str(args.ffmpeg.resolve())
ffprobe = str(args.ffmpeg.resolve().with_name('ffprobe.exe'))
def run(command):
    process = subprocess.run(command,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=30)
    if process.returncode:
        raise RuntimeError(f'Command failed ({process.returncode}): {process.stderr.decode("utf-8",errors="replace")[-4000:]}')
    return process.stdout

version = run([ffmpeg,'-version']).decode('utf-8',errors='replace').splitlines()[0]
run([ffmpeg,'-hide_banner','-nostdin','-y','-f','lavfi','-i','testsrc2=size=256x144:rate=30000/1001',
     '-frames:v','60','-pix_fmt','p010le','-f','rawvideo',str(directory/'input-video.raw')])
run([ffmpeg,'-hide_banner','-nostdin','-y','-f','lavfi','-i','sine=frequency=1000:sample_rate=48000',
     '-t','2.002','-ac','2','-f','f32le',str(directory/'input-audio.raw')])
summaries = []
for name, expected in [('ffv1-master',['ffv1','pcm_f32le']),('yt-h264',['h264','aac'])]:
    plan = json.loads((directory/f'{name}.plan.json').read_text(encoding='utf-8'))
    assert Path(plan['executable']).resolve() == args.ffmpeg.resolve()
    output = Path(plan['argv'][-1]).resolve()
    assert output.parent == directory and not output.exists(), 'Use a fresh test directory.'
    run([plan['executable'],*plan['argv']])
    probe = json.loads(run([ffprobe,'-v','error','-count_frames','-show_streams','-of','json',str(output)]))
    codecs = [stream['codec_name'] for stream in probe['streams']]
    assert codecs == expected, codecs
    video = probe['streams'][0]
    assert int(video['nb_read_frames']) == 60
    assert video['width'] == 256 and video['height'] == 144
    assert video['r_frame_rate'] == '30000/1001'
    assert probe['streams'][1]['sample_rate'] == '48000' and probe['streams'][1]['channels'] == 2
    if name == 'ffv1-master':
        decoded_video = run([ffmpeg,'-v','error','-i',str(output),'-map','0:v','-pix_fmt','p010le','-f','rawvideo','pipe:1'])
        decoded_audio = run([ffmpeg,'-v','error','-i',str(output),'-map','0:a','-f','f32le','pipe:1'])
        expected_samples = array('H',(directory/'input-video.raw').read_bytes())
        decoded_samples = array('H',decoded_video)
        # P010's low six storage bits are not pixel data. libswscale can fill them
        # when generating the source; FFV1 stores all ten meaningful bits exactly.
        assert len(decoded_samples) == len(expected_samples)
        assert all((expected >> 6) == (actual >> 6) for expected,actual in zip(expected_samples,decoded_samples)), 'lossless 10-bit P010 sample parity'
        assert decoded_audio == (directory/'input-audio.raw').read_bytes(), 'lossless audio parity'
    summaries.append({'preset':name,'codecs':codecs,'frames':60,'fps':'30000/1001','size':output.stat().st_size})
(directory/'summary.json').write_text(json.dumps({'ffmpeg':version,'checks':summaries,'host':'none (synthetic raw files, no VEGAS)'},indent=2)+'\n',encoding='utf-8')
print(f'Native-generated FFmpeg plans passed: 60 fractional-rate frames each, FFV1/PCM decoded parity and H.264/AAC probe. {version}. No VEGAS.')
