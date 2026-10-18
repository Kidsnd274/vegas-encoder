"""Offline B0 structural/bounds checks, not a product validator or VEGAS test.

The small walker handles only the keywords used by this repository's draft
recipe schema. It deliberately adds no third-party testing/runtime dependency.
"""
import base64
import copy
import json
from pathlib import Path
import re
import struct
import zlib

ROOT = Path(__file__).resolve().parents[2]
SCHEMA = json.loads((ROOT / 'schema/recipe.v1.schema.json').read_text(encoding='utf-8'))
FIXTURES = ROOT / 'schema/fixtures/b0'
checks = 0

def check(condition, message):
    global checks
    checks += 1
    if not condition:
        raise AssertionError(message)

def validate(value, schema):
    if '$ref' in schema:
        target = SCHEMA
        for part in schema['$ref'][2:].split('/'):
            target = target[part]
        validate(value, target)
        return
    if 'oneOf' in schema:
        valid = 0
        for branch in schema['oneOf']:
            try:
                validate(value, branch)
                valid += 1
            except ValueError:
                pass
        if valid != 1:
            raise ValueError('oneOf')
    if 'const' in schema and value != schema['const']:
        raise ValueError('const')
    if 'enum' in schema and value not in schema['enum']:
        raise ValueError('enum')
    types = schema.get('type', [])
    if isinstance(types, str):
        types = [types]
    matches = {'object':isinstance(value,dict), 'array':isinstance(value,list),
        'string':isinstance(value,str), 'boolean':isinstance(value,bool),
        'integer':type(value) is int, 'number':type(value) in (int,float), 'null':value is None}
    if types and not any(matches[t] for t in types):
        raise ValueError('type')
    if isinstance(value,dict):
        if any(key not in value for key in schema.get('required', [])):
            raise ValueError('required')
        for key, subschema in schema.get('properties',{}).items():
            if key in value:
                validate(value[key],subschema)
    if isinstance(value,list):
        if len(value) < schema.get('minItems',0) or len(value) > schema.get('maxItems',float('inf')):
            raise ValueError('items bound')
        if 'items' in schema:
            for item in value:
                validate(item,schema['items'])
    if isinstance(value,str):
        if len(value) < schema.get('minLength',0) or len(value) > schema.get('maxLength',float('inf')):
            raise ValueError('string bound')
        if 'pattern' in schema and not re.search(schema['pattern'],value):
            raise ValueError('pattern')
    if type(value) in (int,float):
        if value < schema.get('minimum',-float('inf')) or value <= schema.get('exclusiveMinimum',-float('inf')):
            raise ValueError('minimum')

def invalid(value):
    try:
        validate(value,SCHEMA)
    except ValueError:
        return True
    return False

bundle = json.loads((FIXTURES/'core-and-services.json').read_text(encoding='utf-8'))
check(len(bundle['fixtures']) == 6,'six built-ins')
for f in bundle['fixtures'] + bundle['additionalFixtures']:
    r = f['recipe']
    validate(r,SCHEMA)
    check(not {'revision','builtin','favorite','ffmpegPath'}.intersection(r),'portable metadata boundary')
    check('options' not in r['video'] and 'options' not in r['audio'][0],'no all-options map')
    argv = f['compile']['argv']
    check(argv == [t['text'] for t in f['compile']['display'][1:]],'argv/display parity')
    check(argv[-1] == f['paths']['output'],'output path agreement')
    check(f['paths']['videoPipe'] in argv and f['paths']['audioPipe'] in argv,'pipe path agreement')
    check(argv[argv.index('-r')+1] == '/'.join(map(str,f['media']['video']['fps'])),'delivered rational timing')
    check(f['estimate']['totalBytes'] is None,'editing duration is unknown')
    tokens = f['compile']['display']
    for token in tokens:
        field = token['field']
        if field is not None:
            value = r
            for part in field.replace('[0]', '.0').split('.'):
                value = value[int(part)] if isinstance(value, list) else value[part]
    check(True, 'all token fields resolve to product recipe paths')
    for issues in [f['compile']['issues'], *f['compileIssues'].values()]:
        for issue in issues:
            refs = issue['tokenIndices']
            check(refs == sorted(set(refs)) and all(type(i) is int and 0 <= i < len(tokens) for i in refs),
                  'compile issue display references unique and bounded')
    check(all(not issue['tokenIndices'] for issues in f['validations'].values() for issue in issues),
          'standalone validation has no display references')
    signal = f['compile']['signalPath']
    check(signal['video']['outputFormat'] == f['compile']['resolved']['pixfmt'] and
          signal['video']['outputBits'] == f['compile']['resolved']['depth'], 'signal/resolved video parity')
    check(signal['video']['conversion'] == (signal['video']['inputFormat'] != signal['video']['outputFormat']),
          'sample video conversion facts')
    check(signal['video']['chromaChanged'] == (signal['video']['inputChroma'] != signal['video']['outputChroma']),
          'sample video chroma facts')
    check(len(signal['audio']) == 1 and signal['audio'][0]['inputFormat'] == 'flt' and
          signal['audio'][0]['outputBits'] in (16, 24, 32), 'audio format and precision facts')
    for installation in bundle['installations']:
        check(installation['isFixture'] and len(installation['identity']['sha256']) == 64,'synthetic identity marked')

recipe = copy.deepcopy(bundle['fixtures'][0]['recipe'])
for mutate in (
    lambda r:r.update(schema=2), lambda r:r.update(audio=[]),
    lambda r:r.update(audio=r['audio']*2), lambda r:r.update(audio=r['audio'][0]),
    lambda r:r.update(id='../escape'), lambda r:r['video'].update(bitrateK=0),
    lambda r:r['audio'][0].update(sampleRate=0), lambda r:r['video'].update(gopSec=-1),
    lambda r:r['command'].update(mode='basic'), lambda r:r.update(name='x'*257),
):
    bad = copy.deepcopy(recipe); mutate(bad); check(invalid(bad),'malformed recipe rejected')
unknown = copy.deepcopy(recipe)
unknown['future'] = {'nested':[1,2]}; unknown['video']['encoder']='unknown_encoder'
validate(unknown,SCHEMA)
check(True,'unknown properties/encoders structurally preserved')

for key, encoded in bundle['payloads'].items():
    blob = base64.b64decode(encoded,validate=True)
    check(32 <= len(blob) <= 16384,'draft payload bound')
    magic, version, flags, length, crc, schema = struct.unpack('<4sHHIII',blob[:20])
    check((magic,version,flags,schema) == (b'VEnc',1,0,1),'envelope identity')
    check(blob[20:32] == bytes(12) and length == len(blob)-32,'length/reserved bytes')
    check(zlib.crc32(blob[32:]) == crc,'fixture CRC')
    check(json.loads(blob[32:]) == json.loads(key),'canonical snapshot agreement')

request = json.loads((FIXTURES/'request.json').read_text(encoding='utf-8'))
check(request['protocol'] == 1 and request['ownerHwnd'].isdigit(),'session identity/handle')
validate(request['recipe'],SCHEMA); validate(request['baseRecipe'],SCHEMA)
for action in ('apply','cancel'):
    result = json.loads((FIXTURES/f'result-{action}.json').read_text(encoding='utf-8'))
    check(result['sessionId'] == request['sessionId'] and result['action'] == action,'matched result')
    check(('recipe' in result) == (action == 'apply'),'cancel carries no draft')
states = {'starting','encoding','finishing','verifying','done','failed','cancelled'}
seen = set()
for file in (FIXTURES/'live').glob('*.live.json'):
    live = json.loads(file.read_text(encoding='utf-8')); seen.add(live['state'])
    check(live['live'] == 1 and live['framesDone'] <= live['framesTotal'],'live identity/counts')
    check(live['bytesWritten'] >= 0 and live['elapsedSec'] >= 0,'live bounds')
    check(live['hostHwnd'].isdigit() and 0 < int(live['hostHwnd']) <= 2**64-1, 'main host HWND string')
    check(live['outputBitDepth'] == (None if live['state'] == 'starting' else 8), 'sample encoder-input video depth')
    check(live['pixelFormatConversionReducesPrecision'] is (None if live['state'] == 'starting' else True),
          'sample P010 to eight-bit conversion, unknown before compile')
    if live['state'] == 'done':
        check(live['ffmpegExitCode'] == 0,'done fixture exit')
check(seen == states,'all seven live states')
machine = json.loads((FIXTURES/'machine.json').read_text(encoding='utf-8'))
check(machine['keepOnTop'] is False, 'monitor default unpinned')
bounds = machine['uiState']['desktopWindowBounds']
check(bounds['x'] < 0 and bounds['width'] > 0 and bounds['height'] > 0, 'virtual desktop restored bounds')
check(machine['uiState']['lastSizeLengthText'] == '10:00', 'last typed size-card text')
for line in (FIXTURES/'jobs.jsonl').read_text(encoding='utf-8').splitlines():
    index = json.loads(line)
    check(index['recordFile'] == index['id']+'.json','safe index basename')
    job = json.loads((FIXTURES/index['recordFile']).read_text(encoding='utf-8'))
    check(job['id'] == index['id'] and job['status'] == index['status'],'index/record agreement')
    check(job['published'] == (job['status'] == 'succeeded'),'publication matches terminal result')
    check(job['published'] or job['sizeBytes'] == 0,'unpublished job size zero')
    check('.ve-partial-'+job['id'] in job['argv'][-1],'actual temp output recorded')
print(f'B0 fixtures: {checks} structural/bounds checks passed (design fixtures only).')
