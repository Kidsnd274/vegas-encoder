"""B1 Windows recapture. User-supplied executables, bounded offline probes; no install.

Writes reproducible parsed facts plus diagnostics/media under an ignored output
directory. This is a development capture tool, not the B3 production probe service.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import re
import statistics
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
FLAGS = r"[EDFVASXRBT.P]{11}"
OPTION = re.compile(r"^\s{2,}-([^\s]+)\s+(\[?<[^>]+>\]?)\s*(" + FLAGS + r")\s*(.*)$")
CONSTANT = re.compile(r"^\s{5,}(\S+)\s+(?:(\S+)\s+)?(" + FLAGS + r")\s*(.*)$")


def parse_help(text, name, kind):
    result = dict(name=name, kind=kind, pixelFormats=[], sampleFormats=[], sampleRates=[], options=[])
    result['recognized'] = bool(re.search(r'^Encoder ' + re.escape(name) + r' \[', text, re.M))
    for label, key in [('pixel formats', 'pixelFormats'), ('sample formats', 'sampleFormats'), ('sample rates', 'sampleRates')]:
        match = re.search(r'^\s+Supported ' + label + r': (.*)$', text, re.M)
        if match:
            result[key] = [int(x) if key == 'sampleRates' else x for x in match[1].split()]
    current = None
    for line in text.splitlines():
        match = OPTION.match(line)
        if match:
            opt, typ, flags, description = match.groups()
            default = re.search(r'\s*\(default (.*?)\)\s*$', description)
            if default:
                description = description[:default.start()]
            bounds = re.search(r'\s*\(from (\S+) to (\S+)\)\s*$', description)
            if bounds:
                description = description[:bounds.start()]
            current = next((o for o in result['options'] if o['name'] == opt), None)
            if current is None:
                current = dict(name=opt, aliases=[], type=typ.strip('<>'), flags=flags,
                               description=description.strip(), min=bounds[1] if bounds else None,
                               max=bounds[2] if bounds else None,
                               defaultValue=default[1].strip('"') if default else None, constants=[])
                result['options'].append(current)
        else:
            match = CONSTANT.match(line)
            if match and current is not None:
                value = dict(name=match[1], value=match[2], description=match[4].strip())
                if value not in current['constants']:
                    current['constants'].append(value)
    # Preserve all spellings, but offer equivalent underscore/hyphen options once.
    merged = []
    for option in result['options']:
        prior = next((o for o in merged if o['name'].replace('_', '-') == option['name'].replace('_', '-')
                      and all(o[k] == option[k] for k in ['type', 'min', 'max', 'defaultValue', 'description', 'constants'])), None)
        if prior:
            prior['aliases'].append(option['name'])
        else:
            merged.append(option)
    result['options'] = merged
    return result


def run(exe, arguments, timeout=15):
    start = time.perf_counter()
    try:
        process = subprocess.run([str(exe), *map(str, arguments)], capture_output=True, timeout=timeout)
        return dict(exit=process.returncode, stdout=process.stdout.decode('utf-8', errors='replace').replace('\r',''),
                    stderr=process.stderr.decode('utf-8', errors='replace').replace('\r',''), ms=round((time.perf_counter()-start)*1000, 3))
    except subprocess.TimeoutExpired:
        # subprocess.run kills and reaps the process on expiry (no shell/children).
        return dict(exit=None, stdout='', stderr='Hard timeout; process killed and reaped.', ms=round((time.perf_counter()-start)*1000, 3))


def version_identity(text):
    """Read FFmpeg's exact banner/configuration and loaded library versions."""
    version = re.search(r'^ffmpeg version (\S+)', text, re.M)
    configuration = re.search(r'^configuration: (.*)$', text, re.M)
    libraries = {m[1]:'.'.join(m.groups()[1:]) for m in re.finditer(
        r'^\s*(lib\w+)\s+\d+\.\s*\d+\.\s*\d+\s*/\s*(\d+)\.\s*(\d+)\.\s*(\d+)\s*$', text, re.M)}
    if not version or not configuration or not libraries:
        raise RuntimeError('Cannot read complete FFmpeg version/configuration/library identity.')
    return dict(version=version[1], configuration=configuration[1], libraries=libraries)


def probe_identity(structured):
    try:
        program = structured['program_version']
        libraries = {v['name']:f"{v['major']}.{v['minor']}.{v['micro']}" for v in structured['library_versions']}
        identity = dict(version=program['version'], configuration=program['configuration'], libraries=libraries)
    except (KeyError, TypeError):
        raise RuntimeError('Cannot read complete FFprobe version/configuration/library identity.') from None
    if not identity['version'] or not identity['configuration'] or not libraries:
        raise RuntimeError('Cannot read complete FFprobe version/configuration/library identity.')
    return identity


def require_identity(actual, expected, label):
    differences = [key for key in ['version','configuration','libraries'] if actual[key] != expected.get(key)]
    if differences:
        raise RuntimeError(f'{label} identity mismatch ({", ".join(differences)}); '
                           f'expected {expected.get("version", "unknown")}, got {actual["version"]}.')


def verify_capture_identity(exe, facts=None):
    """Bounded read-only guard; never qualify an executable under another capture."""
    version = run(exe, ['-hide_banner','-version'])
    if version['exit'] != 0:
        raise RuntimeError('FFmpeg identity probe failed: ' + version['stderr'])
    identity = version_identity(version['stdout']+version['stderr'])
    if facts is not None:
        require_identity(identity, facts, 'FFmpeg/capture')
    probe = run(exe.with_name('ffprobe.exe'), ['-v','error','-show_versions','-of','json'])
    if probe['exit'] != 0:
        raise RuntimeError('FFprobe identity probe failed: ' + probe['stderr'])
    try:
        structured = json.loads(probe['stdout'])
    except ValueError:
        raise RuntimeError('FFprobe identity probe returned invalid JSON.') from None
    require_identity(probe_identity(structured), identity, 'FFprobe/FFmpeg')
    return identity


def capture(exe, source, output):
    exe = exe.resolve(strict=True)
    identity = verify_capture_identity(exe)
    output.mkdir(parents=True, exist_ok=False)
    probe = exe.with_name('ffprobe.exe')
    catalog = json.loads((ROOT/'schema/encoder-profiles.v1.json').read_text(encoding='utf-8'))
    names = {p['id']:kind for kind in ['video', 'audio'] for p in catalog[kind]}
    names.update({'libvorbis':'audio', 'utvideo':'video', 'h264_qsv':'video', 'hevc_amf':'video', 'av1_amf':'video'})
    calls = {}
    def help_call(key, args):
        value = run(exe, ['-hide_banner', *args])
        if value['exit'] != 0:
            raise RuntimeError(f'{key}: {value["stderr"]}')
        (output/f'{key}.txt').write_text(value['stdout']+value['stderr'], encoding='utf-8')
        calls[key] = value['ms']
        return value['stdout']+value['stderr']
    version = help_call('version', ['-version'])
    lists = {key:help_call(key, ['-'+key]) for key in ['encoders','muxers','pix_fmts','sample_fmts','layouts']}
    full = help_call('full', ['-h','full'])
    # Generic codec AVOptions are kept separately; private-only encoder help is insufficient.
    generic = re.split(r'^\S.*AVOptions:', full.split('AVCodecContext AVOptions:', 1)[1], maxsplit=1, flags=re.M)[0]
    details = {}
    start = time.perf_counter()
    for name, kind in sorted(names.items()):
        details[name] = parse_help(help_call('encoder-'+name, ['-h','encoder='+name]), name, kind)
    serial_ms = (time.perf_counter()-start)*1000
    start = time.perf_counter()
    with ThreadPoolExecutor(max_workers=4) as pool:
        list(pool.map(lambda name: run(exe, ['-hide_banner','-h','encoder='+name]), sorted(names)))
    parallel_ms = (time.perf_counter()-start)*1000
    muxers = {}
    for container in catalog['containers']:
        text = help_call('muxer-'+container['id'], ['-h','muxer='+container['muxer']])
        muxers[container['id']] = dict(container, options=parse_help(text, container['muxer'], 'muxer')['options'])
    unknown = help_call('unknown', ['-h','encoder=ve_b1_nonexistent'])
    structured = run(probe, ['-v','error','-show_versions','-show_pixel_formats','-of','json'])
    if structured['exit'] != 0:
        raise RuntimeError(structured['stderr'])
    structured = json.loads(structured['stdout'])
    require_identity(version_identity(version), identity, 'FFmpeg/capture-start')
    require_identity(probe_identity(structured), identity, 'FFprobe/capture-start')
    exact_version = identity['version']
    sample_fmts = dict((m[1], int(m[2])) for m in re.finditer(r'^\s*(\w+)\s+(\d+)\s*$', lists['sample_fmts'], re.M))
    facts = dict(capture=1, platform='Windows x64', sourceUrl=source, version=exact_version,
                 configuration=structured['program_version']['configuration'],
                 libraries={v['name']:f"{v['major']}.{v['minor']}.{v['micro']}" for v in structured['library_versions']},
                 encoders=details, muxers=muxers,
                 genericOptions=parse_help(generic, 'generic', 'generic')['options'],
                 encoderList=[dict(flags=m[1], name=m[2], description=m[3]) for m in
                              re.finditer(r'^ ([VAS][A-Z.]{5})\s+(\S+)\s+(.*)$', lists['encoders'], re.M) if m[2] != '='],
                 muxerList=[dict(name=m[1], description=m[2]) for m in re.finditer(r'^\s+E\s+(\S+)\s+(.*)$', lists['muxers'], re.M)],
                 pixelFormats=structured['pixel_formats'], sampleFormats=sample_fmts,
                 timings=dict(callsMs=calls, serialHelpMs=round(serial_ms,3), fourWorkerHelpMs=round(parallel_ms,3),
                              medianHelpMs=statistics.median(calls['encoder-'+n] for n in names)),
                 unknownEncoder=dict(exit=0, recognized=False, message=unknown.strip()))
    (output/'facts.json').write_text(json.dumps(facts, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(f'{exact_version}: {len(facts["encoderList"])} encoders; {len(facts["muxerList"])} muxers; '
          f'{sum(len(d["options"]) for d in details.values())} private options; '
          f'help serial {serial_ms:.0f} ms / four workers {parallel_ms:.0f} ms', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('ffmpeg', type=Path)
    parser.add_argument('source_url')
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    if not args.output.resolve().is_relative_to(ROOT/'build'):
        parser.error('Capture output must be under this worktree build/ directory.')
    capture(args.ffmpeg, args.source_url, args.output.resolve())
