"""Fail when committed files contain machine-specific absolute paths (owner decision D7).

Scans files tracked by Git plus new files that Git does not ignore. Drive-letter
paths are refused outside the allowlisted test fixtures, generated fixtures and
historical records; user-profile paths are refused everywhere. Standard library only.
"""
import argparse
import fnmatch
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BS = '\\'

# A drive letter that is not part of a longer word, escape sequence or regular
# expression (for example "dependencies:\n", "\d:\d" or "HKLM:\").
DRIVE = re.compile(r'(?<![A-Za-z0-9\\])[A-Za-z]:\\')
# \Users\<name> (also JSON-escaped), or C:/Users/<name>. Placeholders such as
# <name>, %USERNAME%, $env:USERNAME or {user} are not user names.
PROFILE = re.compile(r'(?i)(?:\\+|(?<![A-Za-z0-9])[A-Za-z]:/+)Users(?:\\+|/+)(?![<%${*])([^\\/\s"\'<>`|;,)\]]+)')
SHARED_PROFILES = {'public', 'default'}

SCOPES = {
    'scripts': ('scripts/**', 'setup/**'),
    'all': ('**',),
}

# Drive-letter paths are allowed here (user-profile paths are still refused).
DRIVE_ALLOWED = (
    # Test fixture data.
    'app/test/**',
    'packages/*/test/**',
    'tests/**',
    # Generated fixture files.
    'schema/fixtures/**',
    'packages/ve_core/lib/src/fixture_data.dart',
    'packages/ve_services/lib/src/service_fixture_data.dart',
    # Historical records.
    'docs/product/workstreams/**',
    'docs/experiments/**',
    'evidence/**',
)

BINARY_SUFFIXES = {
    '.png', '.jpg', '.jpeg', '.gif', '.ico', '.bmp', '.webp', '.ttf', '.otf', '.woff', '.woff2',
    '.exe', '.dll', '.lib', '.obj', '.pdb', '.zip', '.7z', '.gz', '.mp4', '.mkv', '.mov', '.webm',
    '.wav', '.sft2', '.veg', '.bin',
}


def matches(path, patterns):
    return any(fnmatch.fnmatchcase(path, pattern) or
               (pattern.endswith('/**') and path.startswith(pattern[:-2])) for pattern in patterns)


def listed_files():
    output = subprocess.run(['git', '-C', str(ROOT), 'ls-files', '-z', '--cached', '--others', '--exclude-standard'],
                            check=True, capture_output=True).stdout
    return sorted({name for name in output.decode('utf-8').split('\0') if name})


def decode(data):
    if data.startswith((b'\xff\xfe', b'\xfe\xff')):
        return data.decode('utf-16', errors='replace')
    if b'\0' in data[:8192]:
        return None
    return data.decode('utf-8-sig', errors='replace')


def scan_text(text, drive_allowed):
    """Yield (line number, kind, excerpt) for each refused path in text."""
    for number, line in enumerate(text.splitlines(), 1):
        for match in PROFILE.finditer(line):
            if match[1].lower() not in SHARED_PROFILES:
                yield number, 'user-profile path', line.strip()[:160]
                break
        else:
            if not drive_allowed and DRIVE.search(line):
                yield number, 'drive-letter path', line.strip()[:160]


def scan(scope):
    problems = []
    checked = 0
    for relative in listed_files():
        if not matches(relative, SCOPES[scope]) or Path(relative).suffix.lower() in BINARY_SUFFIXES:
            continue
        path = ROOT / relative
        if not path.is_file():
            continue
        text = decode(path.read_bytes())
        if text is None:
            continue
        checked += 1
        problems += [(relative, *hit) for hit in scan_text(text, matches(relative, DRIVE_ALLOWED))]
    return checked, problems


def self_test():
    drive = 'C:' + BS
    refused = [
        drive + 'tools' + BS + 'ffmpeg.exe',
        'L:' + BS + 'repos' + BS + 'vegas-encoder',
        '"' + drive + BS + 'Program Files' + BS + BS + 'x"',
        BS + 'Users' + BS + 'someone' + BS + 'repos',
        BS + BS + 'Users' + BS + BS + 'someone',
        'C:' + '/' + 'Users/someone/AppData',
    ]
    accepted = [
        'dependencies:' + BS + 'n  example',
        BS + 'd' + BS + 'd:' + BS + 'd' + BS + 'd',
        '$env:ProgramFiles' + BS + 'Inno Setup 6',
        'HKLM:' + BS + 'Software',
        'Env:' + BS + 'Path',
        BS + 'Users' + BS + '<name>' + BS + 'repos',
        BS + 'Users' + BS + '%USERNAME%',
        BS + 'Users' + BS + 'Public' + BS + 'Documents',
        '%USERPROFILE%' + BS + 'repos',
        'https://example.com/Users/someone',
    ]
    failures = [f'not refused: {text!r}' for text in refused if not list(scan_text(text, False))]
    failures += [f'refused: {text!r}' for text in accepted if list(scan_text(text, False))]
    profile = BS + 'Users' + BS + 'someone'
    if not list(scan_text(profile, True)):
        failures.append('user-profile path allowed in a drive-letter allowlisted file')
    if list(scan_text(drive + 'fixture', True)):
        failures.append('drive-letter path refused in an allowlisted file')
    if not matches('docs/experiments/a/b.md', DRIVE_ALLOWED) or matches('docs/STATUS.md', DRIVE_ALLOWED):
        failures.append('allowlist matching is wrong')
    if not matches('packages/ve_core/test/x.dart', DRIVE_ALLOWED) or matches('packages/ve_core/lib/x.dart', DRIVE_ALLOWED):
        failures.append('package test allowlist matching is wrong')
    for failure in failures:
        print('SELF-TEST FAILED: ' + failure)
    return not failures


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--scope', choices=sorted(SCOPES), default='all',
                        help='scripts: scripts/** and setup/** only; all (default): every committed file')
    parser.add_argument('--self-test', action='store_true', help='check the detection rules only')
    args = parser.parse_args()
    if not self_test():
        return 1
    if args.self_test:
        print('Machine-path self-test passed.')
        return 0
    checked, problems = scan(args.scope)
    for relative, number, kind, excerpt in problems:
        print(f'{relative}:{number}: {kind}: {excerpt}')
    files = len({p[0] for p in problems})
    print(f'Machine-path check ({args.scope}): {checked} files checked, '
          f'{len(problems)} problem lines in {files} files.')
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
