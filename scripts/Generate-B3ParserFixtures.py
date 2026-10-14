"""Package bounded raw B1 help fixtures for standalone Dart parser tests."""
import json
from pathlib import Path
import re

root = Path(__file__).resolve().parent.parent
builds = json.loads((root / 'schema/ffmpeg/windows-builds.v1.json').read_text(encoding='utf-8'))['measurements']
for name, build in zip(('old', 'gyan', 'btbn'), builds):
    source = root / 'build/ffmpeg-b1' / ('capture-' + name)
    banner = (source / 'version.txt').read_text(encoding='utf-8')
    if re.search(r'^ffmpeg version (\S+)', banner, re.M)[1] != build['version']:
        raise SystemExit('B1 fixture source identity mismatch.')
    for kind in ('version', 'encoders', 'muxers'):
        text = (source / (kind + '.txt')).read_text(encoding='utf-8')
        (root / 'schema/fixtures/ffmpeg' / ('b3-' + name + '-' + kind + '.txt')).write_text(text, encoding='utf-8', newline='\n')
    full = (source / 'full.txt').read_text(encoding='utf-8')
    generic = full.split('AVCodecContext AVOptions:', 1)[1]
    generic = re.split(r'^\S.*AVOptions:', generic, maxsplit=1, flags=re.M)[0]
    (root / 'schema/fixtures/ffmpeg' / ('b3-' + name + '-generic.txt')).write_text(generic, encoding='utf-8', newline='\n')
print('B3 parser fixtures packaged from the three B1 Windows identities. Tests need no build captures.')
