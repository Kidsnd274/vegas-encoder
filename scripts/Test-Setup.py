"""Exercise the compiled TEST-ONLY helper in confined, disposable fixture folders.

Does not execute an installer, load a DLL, write registry keys or touch real hosts.
"""
import configparser
import hashlib
import json
import os
from pathlib import Path
import subprocess
import unittest
import uuid

REPO = Path(__file__).resolve().parents[1]
HELPER = REPO / 'build/test-results/setup-helper/ve-install.exe'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


class SetupTests(unittest.TestCase):
    def setUp(self):
        self.root = REPO / 'build/test-results' / ('setup-' + uuid.uuid4().hex)
        self.root.mkdir(parents=True)
        self.app = self.root / 'App ü 编码'
        self.host = self.root / 'VEGAS 2026'
        self.host.mkdir()
        (self.host / 'vegas2026.exe').write_text('fixture; never executed')
        self.payload = self.root / 'payload'
        self.payload.mkdir()
        (self.payload / 'vegas-encoder.dll').write_bytes(b'new plugin; never loaded')
        (self.payload / 'vegas-encoder.ini.in').write_bytes(b'[vegas-encoder]\r\nAppPath={app}\\VegasEncoder.exe\r\n')
        (self.payload / 'VegasEncoder-x64.fio2007-config').write_bytes(b'[FileIO Plug-Ins]\r\nvegas-encoder=FileIO Plug-Ins\\vegas-encoder\\vegas-encoder.dll\r\n')
        self.files = {'VegasEncoder.exe': b'fake app; never executed', 'data/app.so': b'Dart fixture', 'setup-support/ve-install.exe': b'fake helper; never executed'}
        self.package = {'schema': 'vegas-encoder-payload/1', 'version': '0.1.7+1', 'coreVersion': '0.1.7-recipe-proof',
                        'files': [{'file': k, 'sha256': hashlib.sha256(v).hexdigest().upper()} for k, v in self.files.items()],
                        'pluginSha256': sha(self.payload / 'vegas-encoder.dll'),
                        'iniSha256': sha(self.payload / 'vegas-encoder.ini.in'),
                        'configSha256': sha(self.payload / 'VegasEncoder-x64.fio2007-config')}
        self.save_package()
        self.transaction = ''

    def save_package(self):
        (self.payload / 'payload.json').write_text(json.dumps(self.package), encoding='utf-8')

    def call(self, operation, success=True, **extra):
        request = self.root / 'request.ini'
        result = self.root / 'result.ini'
        fields = {'app': str(self.app), 'host': str(self.host), 'payload': str(self.payload), 'transaction': self.transaction, **extra}
        request.write_text('[setup]\n' + '\n'.join(f'{k}={v}' for k, v in fields.items()), encoding='utf-16')
        process = subprocess.run([str(HELPER), operation, str(request), str(result), str(self.root)], capture_output=True, timeout=20)
        answer = configparser.ConfigParser(interpolation=None)
        answer.read(result, encoding='utf-16')
        message = answer['setup'].get('message', '')
        self.assertEqual(process.returncode == 0, success, f'{operation}: {message}')
        return answer['setup']

    def prepare(self, **extra):
        self.transaction = self.call('prepare', **extra)['transaction']

    def copy_app(self):
        for name, data in self.files.items():
            path = self.app / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)

    def install(self):
        self.prepare()
        self.copy_app()
        self.call('commit')

    @property
    def plugin(self):
        return self.host / 'FileIO Plug-Ins/vegas-encoder'

    def test_install_update_and_unicode_ini(self):
        self.install()
        text = (self.plugin / 'vegas-encoder.ini').read_text(encoding='utf-16')
        self.assertIn(str(self.app), text)
        import ctypes
        buffer = ctypes.create_unicode_buffer(32768)
        ctypes.windll.kernel32.GetPrivateProfileStringW('vegas-encoder', 'AppPath', '', buffer, 32768, str(self.plugin / 'vegas-encoder.ini'))
        self.assertEqual(buffer.value, str(self.app / 'VegasEncoder.exe'))
        self.call('uninstall-check')
        self.files['VegasEncoder.exe'] = b'updated app'
        self.package['files'][0]['sha256'] = hashlib.sha256(self.files['VegasEncoder.exe']).hexdigest().upper()
        self.save_package()
        self.prepare()
        self.copy_app()
        self.call('commit')
        self.assertEqual((self.app / 'VegasEncoder.exe').read_bytes(), b'updated app')
        self.assertTrue((Path(self.transaction) / '0.bak').is_file())

    def test_app_only_no_host_needed(self):
        self.prepare(host='')
        self.copy_app()
        self.call('commit')
        self.assertFalse(self.plugin.exists())
        self.assertEqual(json.loads((self.app / 'vegas-encoder-setup.json').read_text(encoding='utf-8'))['host'], '')

    def records(self):
        return {p: json.loads(p.read_text(encoding='utf-8')) for p in (self.root / 'Installations').glob('*.json')}

    def test_independent_component_identity_and_versions_survive_update(self):
        self.install()
        before = self.records()
        self.assertEqual(len(before), 2)
        app = next(r for r in before.values() if r['componentId'] == 'vegas-encoder.app.windows-x64')
        core = next(r for r in before.values() if r['componentId'] == 'vegas-encoder.core.vegas2026.windows-x64')
        self.assertNotEqual(app['instanceId'], core['instanceId'])
        self.assertEqual(core['appInstanceId'], app['instanceId'])
        self.assertEqual(core['installDir'], str(self.plugin))
        self.assertEqual(app['installDir'], str(self.app))
        self.package['version'] = '0.1.8+2'
        self.save_package()
        self.prepare()
        self.copy_app()
        self.call('commit')
        after = self.records()
        self.assertEqual(before.keys(), after.keys())
        self.assertEqual(next(r for r in after.values() if r['componentId'] == app['componentId'])['version'], '0.1.8+2')
        self.assertEqual(next(r for r in after.values() if r['componentId'] == core['componentId'])['version'], '0.1.7-recipe-proof')
        self.call('restore')
        self.assertEqual(self.records(), before)

    def test_legacy_manifests_gain_component_records(self):
        self.install()
        for manifest in (self.app / 'vegas-encoder-setup.json', self.plugin / 'install-manifest.json'):
            state = json.loads(manifest.read_text(encoding='utf-8'))
            record = state.pop('installation')
            (self.root / 'Installations' / (record['instanceId'] + '.json')).unlink()
            manifest.write_text(json.dumps(state), encoding='utf-8')
        self.prepare()
        self.copy_app()
        self.call('commit')
        self.assertEqual(len(self.records()), 2)
        self.call('uninstall-check')

    def test_catalog_tamper_blocks_update_and_uninstall(self):
        self.install()
        path, record = next(iter(self.records().items()))
        record['version'] = 'unexpected'
        path.write_text(json.dumps(record), encoding='utf-8')
        self.call('prepare', success=False)
        self.call('uninstall-check', success=False)

    def test_other_app_cannot_take_over_core(self):
        self.install()
        previous = self.records()
        self.app = self.root / 'Another app'
        self.call('prepare', success=False)
        self.assertEqual(self.records(), previous)

    def test_component_records_removed_and_restored_with_uninstall(self):
        self.install()
        previous = self.records()
        self.transaction = self.call('uninstall-prepare')['transaction']
        self.call('uninstall')
        self.assertEqual(self.records(), {})
        self.call('rollback')
        self.assertEqual(self.records(), previous)
        self.call('uninstall-check')

    def test_failed_fresh_install_leaves_no_component_records(self):
        self.prepare()
        self.copy_app()
        (self.root / 'fail-commit').touch()
        self.call('commit', success=False)
        self.call('rollback')
        self.assertEqual(self.records(), {})

    def test_removing_core_component_retains_only_app_record(self):
        self.install()
        before = self.records()
        self.prepare(host='')
        self.copy_app()
        self.call('commit')
        records = self.records()
        self.assertEqual(len(records), 1)
        self.assertEqual(next(iter(records.values()))['componentId'], 'vegas-encoder.app.windows-x64')
        self.call('restore')
        self.assertEqual(self.records(), before)

    def test_separate_installations_have_distinct_records_and_paths(self):
        self.install()
        previous = self.records()
        self.app = self.root / 'Second app'
        self.host = self.root / 'Second VEGAS'
        self.host.mkdir()
        (self.host / 'vegas2026.exe').write_bytes(b'fixture')
        self.transaction = ''
        self.install()
        self.assertEqual(len(self.records()), 4)
        for path, record in previous.items():
            self.assertEqual(self.records()[path], record)
        self.transaction = self.call('uninstall-prepare')['transaction']
        self.call('uninstall')
        self.assertEqual(self.records(), previous)

    def test_invalid_record_identity_or_path_refused(self):
        self.install()
        manifest = self.plugin / 'install-manifest.json'
        state = json.loads(manifest.read_text(encoding='utf-8'))
        original = state['installation']['instanceId']
        state['installation']['instanceId'] = '../escape'
        manifest.write_text(json.dumps(state), encoding='utf-8')
        self.call('prepare', success=False)
        state['installation']['instanceId'] = original
        state['installation']['installDir'] = str(self.root / 'wrong-location')
        manifest.write_text(json.dumps(state), encoding='utf-8')
        self.call('uninstall-check', success=False)

    def test_moving_core_retains_app_identity_and_replaces_core_record(self):
        self.install()
        previous = self.records()
        self.host = self.root / 'Custom VEGAS path'
        self.host.mkdir()
        (self.host / 'vegas2026.exe').write_bytes(b'fixture')
        self.prepare()
        self.copy_app()
        self.call('commit')
        records = self.records()
        self.assertEqual(len(records), 2)
        for path, record in previous.items():
            if record['componentId'] == 'vegas-encoder.app.windows-x64':
                self.assertEqual(records[path], record)
            else:
                self.assertNotIn(path, records)
        core = next(r for r in records.values() if r['componentId'] == 'vegas-encoder.core.vegas2026.windows-x64')
        self.assertEqual(core['hostDir'], str(self.host))

    def test_unknown_plugin_refused(self):
        self.plugin.mkdir(parents=True)
        (self.plugin / 'vegas-encoder.dll').write_bytes(b'unknown owner')
        self.call('prepare', success=False)
        self.assertFalse(self.app.exists())

    def test_unknown_app_refused(self):
        self.app.mkdir()
        (self.app / 'private.txt').write_text('preserve')
        self.call('prepare', success=False)
        self.assertEqual((self.app / 'private.txt').read_text(), 'preserve')

    def test_changed_owned_file_refused(self):
        self.install()
        (self.plugin / 'vegas-encoder.ini').write_bytes(b'user edit')
        self.call('prepare', success=False)
        self.call('uninstall-check', success=False)
        self.assertEqual((self.plugin / 'vegas-encoder.ini').read_bytes(), b'user edit')

    def test_unknown_plugin_file_refused(self):
        self.install()
        (self.plugin / 'private.txt').write_text('preserve')
        self.call('prepare', success=False)
        self.call('uninstall-check', success=False)

    def test_failed_commit_rolls_back_fresh_install(self):
        self.prepare()
        self.copy_app()
        (self.root / 'fail-commit').touch()
        self.call('commit', success=False)
        self.call('rollback')
        self.assertFalse(self.plugin.exists())
        self.assertFalse((self.app / 'VegasEncoder.exe').exists())

    def test_failed_update_restores_exact_bytes(self):
        self.install()
        before = {p: p.read_bytes() for p in self.plugin.iterdir()}
        self.prepare()
        self.copy_app()
        (self.root / 'fail-commit').touch()
        self.call('commit', success=False)
        self.call('rollback')
        self.assertEqual(before, {p: p.read_bytes() for p in self.plugin.iterdir()})
        self.call('uninstall-check')

    def test_interrupted_setup_requires_recovery(self):
        self.prepare()
        pending = self.transaction
        self.call('prepare', success=False)
        self.call('rollback', transaction=pending)
        self.prepare()

    def test_manifest_escape_refused(self):
        self.install()
        manifest = self.plugin / 'install-manifest.json'
        state = json.loads(manifest.read_text())
        state['files'][0]['file'] = str(self.root / 'outside.dll')
        manifest.write_text(json.dumps(state))
        self.call('prepare', success=False)

    def test_duplicate_payload_refused(self):
        self.package['files'].append(self.package['files'][0])
        self.save_package()
        self.call('prepare', success=False)

    def test_payload_escape_refused(self):
        self.package['files'][0]['file'] = '../outside.exe'
        self.save_package()
        self.call('prepare', success=False)

    def test_host_validation_and_confined_helper(self):
        self.call('validate')
        self.call('validate', success=False, host=str(self.root / 'missing'))
        self.call('validate', success=False, host=str(self.root.parent))

    def test_remove_component_keeps_app(self):
        self.install()
        self.prepare(host='')
        self.copy_app()
        self.call('commit')
        self.assertFalse(self.plugin.exists())
        self.assertTrue((self.app / 'VegasEncoder.exe').is_file())

    def test_change_host_removes_only_previous_integration(self):
        self.install()
        old_plugin = self.plugin
        self.host = self.root / 'Other VEGAS 2026'
        self.host.mkdir()
        (self.host / 'vegas2026.exe').write_bytes(b'fixture')
        self.prepare()
        self.copy_app()
        self.call('commit')
        self.assertFalse(old_plugin.exists())
        self.assertTrue((self.plugin / 'vegas-encoder.dll').is_file())

    def test_uninstall_and_rollback_preserve_user_data(self):
        self.install()
        private = self.app / 'personal-presets.json'
        private.write_bytes(b'user data')
        self.transaction = self.call('uninstall-prepare')['transaction']
        self.call('uninstall')
        # Simulate Inno removing its registered app files, never private data.
        for name in self.files:
            (self.app / name).unlink()
        self.call('finish-removal')
        self.assertEqual(private.read_bytes(), b'user data')
        self.assertFalse(self.plugin.exists())
        self.call('restore')
        self.call('uninstall-check')
        self.assertEqual(private.read_bytes(), b'user data')

    def test_committed_restore_protects_later_changes(self):
        self.install()
        (self.app / 'VegasEncoder.exe').write_bytes(b'newer bytes')
        self.call('restore', success=False)
        self.assertEqual((self.app / 'VegasEncoder.exe').read_bytes(), b'newer bytes')

    def test_unknown_app_collision_on_update_refused(self):
        self.install()
        private = self.app / 'extra.dll'
        private.write_bytes(b'private')
        self.package['files'].append({'file': 'extra.dll', 'sha256': sha(private)})
        self.save_package()
        self.call('prepare', success=False)
        self.assertEqual(private.read_bytes(), b'private')

    def test_app_hash_mismatch_does_not_deploy_plugin(self):
        self.prepare()
        self.copy_app()
        (self.app / 'data/app.so').write_bytes(b'bad copy')
        self.call('commit', success=False)
        self.assertFalse(self.plugin.exists())
        self.call('rollback')

    def test_existing_development_manifest_and_symbols_adopted(self):
        self.install()
        manifest = self.plugin / 'install-manifest.json'
        old = json.loads(manifest.read_text())
        old.pop('installedBy')
        pdb = self.plugin / 'vegas-encoder.pdb'
        pdb.write_bytes(b'development symbols')
        old['files'].append({'file': str(pdb), 'sha256': sha(pdb)})
        manifest.write_text(json.dumps(old))
        self.prepare()
        self.copy_app()
        self.call('commit')
        self.assertFalse(pdb.exists())
        self.call('restore')
        self.assertEqual(pdb.read_bytes(), b'development symbols')
        self.assertNotIn('installedBy', json.loads(manifest.read_text()))

    def test_discovery_file_hash_change_refused(self):
        self.install()
        conf = self.host / 'VegasEncoder-x64.fio2007-config'
        conf.write_bytes(b'user edit')
        self.call('prepare', success=False)
        self.call('uninstall-check', success=False)

    def test_reparse_host_rejected(self):
        link = self.root / 'host-junction'
        env = dict(os.environ, VE_SETUP_TEST_LINK=str(link), VE_SETUP_TEST_TARGET=str(self.host))
        subprocess.run(['pwsh', '-NoLogo', '-NoProfile', '-NonInteractive', '-Command',
                        'New-Item -ItemType Junction -Path $env:VE_SETUP_TEST_LINK -Target $env:VE_SETUP_TEST_TARGET | Out-Null'],
                       env=env, check=True, capture_output=True)
        self.call('validate', success=False, host=str(link))

    def test_cancelled_uninstall_can_restore_current_installation(self):
        self.install()
        self.transaction = self.call('uninstall-prepare')['transaction']
        self.call('uninstall')
        self.call('rollback')
        self.call('uninstall-check')

    def test_running_process_under_app_blocks_changes(self):
        self.install()
        sleeper = self.app / 'running-fixture.exe'
        # TEST-ONLY helper supplies a stable process fixture without launching the app.
        sleeper.write_bytes(HELPER.read_bytes())
        process = subprocess.Popen([str(sleeper), 'test-sleep', str(self.root / 'request.ini'), str(self.root / 'sleeper.ini'), str(self.root)])
        try:
            self.call('prepare', success=False)
            self.call('uninstall-check', success=False)
        finally:
            process.terminate()
            process.wait(timeout=10)

    def test_vegas_removed_before_app_uninstall(self):
        self.install()
        (self.host / 'vegas2026.exe').unlink()
        self.call('uninstall-check')
        self.transaction = self.call('uninstall-prepare')['transaction']
        self.call('uninstall')
        self.assertFalse(self.plugin.exists())

    def test_inno_uninstaller_ancestor_does_not_block_removal(self):
        self.install()
        parent = self.app / 'unins000.exe'
        proxy = self.root / 'temporary-uninstaller.exe'
        parent.write_bytes(HELPER.read_bytes())
        proxy.write_bytes(HELPER.read_bytes())
        request, result = self.root / 'uninstall.ini', self.root / 'uninstall-result.ini'
        request.write_text(f'[setup]\napp={self.app}\nhelper={HELPER}\nproxy={proxy}\n', encoding='utf-16')
        # The real helper is outside this case's root; use a confined copy instead.
        helper = self.root / 'helper.exe'
        helper.write_bytes(HELPER.read_bytes())
        request.write_text(f'[setup]\napp={self.app}\nhelper={helper}\nproxy={proxy}\n', encoding='utf-16')
        process = subprocess.run([str(parent), 'test-uninstall-parent', str(request), str(result), str(self.root)], timeout=20)
        self.assertEqual(process.returncode, 0, result.read_text(encoding='utf-16'))


if __name__ == '__main__':
    unittest.main()
