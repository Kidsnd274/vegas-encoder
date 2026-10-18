"""Run only wizard initialization in an unprivileged, non-installing Inno harness.

Uses the actual helper/host scripts and production helper's read-only detection.
Aborts before displaying pages or invoking any install lifecycle code.
"""
import argparse
from pathlib import Path
import subprocess
import uuid

REPO = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--iscc', default=r'C:\Program Files (x86)\Inno Setup 6\ISCC.exe')
    parser.add_argument('--helper', type=Path, default=REPO / 'build/release/vegas-encoder/setup/ve-install.exe')
    args = parser.parse_args()
    fixture = REPO / 'build/test-results' / ('setup-wizard-' + uuid.uuid4().hex)
    fixture.mkdir(parents=True)
    # Rename the event so the harness can invoke it, check the request, then abort.
    hosts = (REPO / 'setup/includes/hosts.iss').read_text(encoding='utf-8')
    hosts = hosts.replace('procedure InitializeWizard;', 'procedure InitializeHostWizard;')
    (fixture / 'hosts.iss').write_text(hosts, encoding='utf-8-sig')
    marker = fixture / 'initialized.txt'
    script = fr'''[Setup]
AppName=Vegas Encoder wizard regression fixture
AppVersion=0
DefaultDirName={{tmp}}\unused-ve-setup-fixture
PrivilegesRequired=lowest
CreateAppDir=no
Uninstallable=no
DisableDirPage=no
OutputDir={fixture}
OutputBaseFilename=wizard-test
[Files]
Source: "{args.helper.resolve()}"; Flags: dontcopy
[Code]
#include "{REPO / 'setup/includes/helper.iss'}"
#include "hosts.iss"
procedure InitializeWizard;
begin
  InitializeHostWizard;
  if not FileExists(RequestFile) then RaiseException('Request was not created');
  if GetIniString('setup', 'app', '', RequestFile) <> '' then
    RaiseException('Startup detection must not depend on the app directory');
  if not FileExists(ResultFile) then RaiseException('Detection did not run');
  if GetIniString('setup', 'ok', '', ResultFile) <> '1' then
    RaiseException('Read-only host detection failed');
  SaveStringToFile('{marker}', 'PASS', False);
  Abort;
end;
'''
    source = fixture / 'wizard-test.iss'
    source.write_text(script, encoding='utf-8-sig')
    subprocess.run([args.iscc, '/Q', str(source)], check=True, timeout=60)
    # This executable has no install lifecycle and always aborts in InitializeWizard.
    result = subprocess.run([str(fixture / 'wizard-test.exe'), '/VERYSILENT',
                             '/SUPPRESSMSGBOXES', '/NORESTART', f'/LOG={fixture / "setup.log"}'], timeout=30)
    if not marker.exists() or marker.read_text(encoding='ascii') != 'PASS':
        raise SystemExit(f'Wizard initialization failed (exit {result.returncode}); see {fixture / "setup.log"}')
    print('Wizard initialization PASS: actual scripts, read-only host detection; no installation.')


if __name__ == '__main__':
    main()
