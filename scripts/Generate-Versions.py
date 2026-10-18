"""Validate version.json and project it into build inputs. Standard library only."""
import argparse
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SEMVER = re.compile(r'(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?\Z')


def fields(value, expected, where):
    if not isinstance(value, dict) or set(value) != set(expected.split()):
        raise ValueError(f'{where}: expected fields {expected}')


def integer(value, maximum, where, minimum=0):
    if type(value) is not int or not minimum <= value <= maximum:
        raise ValueError(f'{where}: integer {minimum}..{maximum} required')
    return value


def semver(value, where, release=False):
    match = SEMVER.fullmatch(value) if isinstance(value, str) else None
    if not match or (release and match[4]):
        raise ValueError(f'{where}: expected {"major.minor.patch" if release else "semantic version"}')
    if match[4] and any(x.isdigit() and len(x) > 1 and x[0] == '0' for x in match[4].split('.')):
        raise ValueError(f'{where}: numeric prerelease identifiers cannot have leading zeros')
    return [integer(int(match[i]), 65535, where) for i in (1, 2, 3)]


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f'Duplicate JSON field: {key}')
        result[key] = value
    return result


def load(path):
    raw = path.read_bytes()
    data = json.loads(raw.decode('utf-8-sig'), object_pairs_hook=unique_object)
    fields(data, 'schema release core services legacyExporters', 'version.json')
    if type(data['schema']) is not int or data['schema'] != 1:
        raise ValueError('Unsupported version.json schema')
    release, core, services = data['release'], data['core'], data['services']
    fields(release, 'version build exporterSuffix', 'release')
    fields(core, 'version packageVersion abi schemaMax contracts', 'core')
    fields(services, 'packageVersion', 'services')
    numbers = semver(release['version'], 'release.version', release=True)
    build = integer(release['build'], 65535, 'release.build')
    suffix = release['exporterSuffix']
    if not isinstance(suffix, str):
        raise ValueError('release.exporterSuffix: string required')
    exporter = release['version'] + (f'-{suffix}' if suffix else '')
    semver(exporter, 'release.exporterSuffix')
    for value, where in [(core['version'], 'core.version'), (core['packageVersion'], 'core.packageVersion'),
                         (services['packageVersion'], 'services.packageVersion')]:
        semver(value, where)
    for key in ('abi', 'schemaMax', 'contracts'):
        integer(core[key], 0xffffffff, f'core.{key}', minimum=1)
    fields(data['legacyExporters'], 'default configuration progressText', 'legacyExporters')
    for key, legacy in data['legacyExporters'].items():
        fields(legacy, 'version fileVersion', f'legacyExporters.{key}')
        triplet = semver(legacy['version'], f'legacyExporters.{key}.version')
        values = legacy['fileVersion']
        if not isinstance(values, list) or len(values) != 4:
            raise ValueError(f'legacyExporters.{key}.fileVersion: four integers required')
        for value in values:
            integer(value, 65535, f'legacyExporters.{key}.fileVersion')
        if values[:3] != triplet:
            raise ValueError(f'legacyExporters.{key}: numeric/product version mismatch')
    return dict(release=release['version'], build=build, app=f'{release["version"]}+{build}',
                exporter=exporter, numeric='.'.join(map(str, numbers + [build])),
                fileVersion=numbers + [build], core=core, services=services,
                legacyExporters=data['legacyExporters'], manifestSha256=hashlib.sha256(raw).hexdigest())


def outputs(root, version):
    macros = {
        'VE_RELEASE_VERSION': version['release'], 'VE_APP_VERSION': version['app'],
        'VE_APP_FILE_VERSION_STRING': version['numeric'], 'VE_EXPORTER_VERSION': version['exporter'],
        'VE_CORE_VERSION': version['core']['version'],
    }
    lines = ['// Generated from version.json by scripts/Generate-Versions.py. Do not edit.', '#pragma once']
    lines += [f'#define {key} {json.dumps(value)}' for key, value in macros.items()]
    lines += ['#define VE_APP_FILE_VERSION ' + ','.join(map(str, version['fileVersion']))]
    for key, field in [('ABI_VERSION', 'abi'), ('SCHEMA_MAX', 'schemaMax'), ('CONTRACTS_VERSION', 'contracts')]:
        lines += [f'#define VE_CORE_{key} {version["core"][field]}u']
    for key, macro in [('default', 'DEFAULT'), ('configuration', 'CONFIGURATION'), ('progressText', 'PROGRESS_TEXT')]:
        legacy = version['legacyExporters'][key]
        lines += [f'#define VE_LEGACY_{macro}_VERSION {json.dumps(legacy["version"])}',
                  f'#define VE_LEGACY_{macro}_FILE_VERSION ' + ','.join(map(str, legacy['fileVersion']))]
    result = {'src/version.generated.h': '\n'.join(lines) + '\n'}
    result['packages/ve_core/lib/src/version.g.dart'] = (
        '// Generated from version.json. Do not edit.\n'
        f'const expectedCoreAbi = {version["core"]["abi"]};\n')
    result['setup/version.generated.iss'] = (
        '; Generated from version.json. Do not edit; used by setup/setup_script.iss.\n'
        f'#define VeReleaseVersion "{version["release"]}"\n'
        f'#define VeAppVersion "{version["app"]}"\n'
        f'#define VeFileVersion "{version["numeric"]}"\n'
        f'#define VeExporterVersion "{version["exporter"]}"\n'
        f'#define VeCoreVersion "{version["core"]["version"]}"\n')
    for relative, value in [('app/pubspec.yaml', version['app']),
                            ('packages/ve_core/pubspec.yaml', version['core']['packageVersion']),
                            ('packages/ve_services/pubspec.yaml', version['services']['packageVersion'])]:
        text = (root / relative).read_text(encoding='utf-8')
        text, count = re.subn(r'(?m)^version: [^\r\n]*', f'version: {value}', text)
        if count != 1:
            raise ValueError(f'{relative}: exactly one top-level version field required')
        result[relative] = text
    return result


def sync(root, version, check=False):
    pending = outputs(root, version)
    stale = []
    for relative, text in pending.items():
        path = root / relative
        current = path.read_text(encoding='utf-8') if path.exists() else None
        if current != text:
            stale.append(relative)
    if check and stale:
        raise ValueError('Stale version outputs: ' + ', '.join(stale) + '. Run python -I scripts/Generate-Versions.py')
    if not check:
        for relative in stale:
            path = root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            with path.open('w', encoding='utf-8', newline='\n') as output:
                output.write(pending[relative])
    return stale


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--print-json', action='store_true', help='Print derived versions without changing files')
    args = parser.parse_args()
    try:
        version = load(ROOT / 'version.json')
        if args.check or not args.print_json:
            sync(ROOT, version, check=args.check)
        print(json.dumps(version) if args.print_json else 'Version outputs checked.' if args.check else 'Version outputs synchronized.')
    except (ValueError, OSError) as error:
        parser.exit(1, f'Version error: {error}\n')


if __name__ == '__main__':
    main()
