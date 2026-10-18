"""Version projection/change/staleness checks in temporary fixtures; no builds."""
from copy import deepcopy
from importlib.util import spec_from_file_location, module_from_spec
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = spec_from_file_location('versions', ROOT / 'scripts/etc/Generate-Versions.py')
versions = module_from_spec(spec)
spec.loader.exec_module(versions)


class VersionTests(unittest.TestCase):
    def setUp(self):
        self.temp = TemporaryDirectory(dir=ROOT / 'build/test-results')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.data = json.loads((ROOT / 'version.json').read_text())
        for relative in ('app/pubspec.yaml', 'packages/ve_core/pubspec.yaml', 'packages/ve_services/pubspec.yaml'):
            path = self.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('name: sample\nversion: 0.0.0\ndependencies:\n  example: 1.0.0\n')

    def load(self):
        path = self.root / 'version.json'
        path.write_text(json.dumps(self.data))
        return versions.load(path)

    def test_current_is_fresh(self):
        self.assertEqual(versions.sync(ROOT, versions.load(ROOT / 'version.json'), check=True), [])

    def test_changed_release_reaches_all_consumers(self):
        self.data['release'] = dict(version='1.2.3', build=42, exporterSuffix='rc.2')
        self.data['core'].update(version='0.9.1-rc.1', packageVersion='0.9.1', abi=2, schemaMax=3, contracts=4)
        self.data['services']['packageVersion'] = '0.8.0'
        value = self.load()
        versions.sync(self.root, value)
        header = (self.root / 'src/version.generated.h').read_text()
        for text in ('"1.2.3+42"', '"1.2.3-rc.2"', '1,2,3,42', '"0.9.1-rc.1"',
                     'VE_CORE_ABI_VERSION 2u', 'VE_CORE_SCHEMA_MAX 3u', 'VE_CORE_CONTRACTS_VERSION 4u'):
            self.assertIn(text, header)
        for relative, expected in [('app', '1.2.3+42'), ('packages/ve_core', '0.9.1'), ('packages/ve_services', '0.8.0')]:
            text = (self.root / relative / 'pubspec.yaml').read_text()
            self.assertIn('version: ' + expected, text)
            self.assertIn('example: 1.0.0', text)
        self.assertIn('expectedCoreAbi = 2', (self.root / 'packages/ve_core/lib/src/version.g.dart').read_text())
        self.assertIn('VeFileVersion "1.2.3.42"', (self.root / 'setup/version.generated.iss').read_text())
        self.assertEqual(versions.sync(self.root, value, check=True), [])

    def test_stale_check_does_not_write(self):
        value = self.load()
        with self.assertRaisesRegex(ValueError, 'Stale version outputs'):
            versions.sync(self.root, value, check=True)
        self.assertFalse((self.root / 'src/version.generated.h').exists())
        versions.sync(self.root, value)
        self.data['release']['build'] += 1
        with self.assertRaisesRegex(ValueError, 'Stale version outputs'):
            versions.sync(self.root, self.load(), check=True)

    def test_bad_versions_are_refused(self):
        original = deepcopy(self.data)
        for value in ('1.2', '01.2.3', '1.2.3\n', '1.2.3+4', '1.2.3-rc.01', '65536.0.0', '1.2.3"; bad'):
            with self.subTest(value=value):
                self.data = deepcopy(original)
                self.data['core']['version'] = value
                with self.assertRaises(ValueError):
                    self.load()

    def test_bad_numbers_and_unknown_fields_are_refused(self):
        original = deepcopy(self.data)
        cases = [('release', 'build', True), ('release', 'build', -1), ('release', 'build', 65536),
                 ('core', 'abi', 0), ('core', 'schemaMax', 1.5), ('core', 'contracts', 0x100000000),
                 ('release', 'typo', 1), ('release', 'exporterSuffix', 42)]
        for section, key, value in cases:
            with self.subTest(key=key, value=value):
                self.data = deepcopy(original)
                self.data[section][key] = value
                with self.assertRaises(ValueError):
                    self.load()

    def test_legacy_numeric_mismatch_is_refused(self):
        self.data['legacyExporters']['default']['fileVersion'][2] += 1
        with self.assertRaisesRegex(ValueError, 'mismatch'):
            self.load()

    def test_duplicate_fields_are_refused(self):
        path = self.root / 'version.json'
        path.write_text('{"schema":1,"schema":1}')
        with self.assertRaisesRegex(ValueError, 'Duplicate'):
            versions.load(path)

    def test_missing_pubspec_version_is_refused(self):
        (self.root / 'app/pubspec.yaml').write_text('name: sample\n')
        with self.assertRaisesRegex(ValueError, 'exactly one'):
            versions.sync(self.root, self.load())


if __name__ == '__main__':
    (ROOT / 'build/test-results').mkdir(parents=True, exist_ok=True)
    unittest.main()
