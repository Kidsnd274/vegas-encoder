"""Run only wizard initialization in an unprivileged, non-installing Inno harness.

Uses the actual helper/hosts/wizard scripts and the production helper's read-only
detection. Builds the VEGAS integrations page in install, update and maintenance
variants, then aborts before any install lifecycle code.
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
    # Rename the events so the harness can invoke them, check the results, then abort.
    wizard = (REPO / 'setup/includes/wizard.iss').read_text(encoding='utf-8')
    wizard = wizard.replace('function InitializeSetup: Boolean;', 'function ProductInitializeSetup: Boolean;')
    wizard = wizard.replace('procedure InitializeWizard;', 'procedure ProductInitializeWizard;')
    (fixture / 'wizard.iss').write_text(wizard, encoding='utf-8-sig')
    marker = fixture / 'initialized.txt'
    script = fr'''#include "{REPO / 'setup/version.generated.iss'}"
#define VeAppId "{{0CF24E60-C0F5-4242-96AD-13FF2F9BF313}}"
[Setup]
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
#include "{REPO / 'setup/includes/hosts.iss'}"
#include "wizard.iss"
procedure Check(const Ok: Boolean; const Message: String);
begin
  if not Ok then RaiseException(Message);
end;
procedure InitializeWizard;
var
  I: Integer;
  Supported: Boolean;
begin
  ExtractHelper;
  Check(LoadInstallation('{{#VeAppVersion}}'), 'Read-only detection failed: ' + HelperError);
  Check(GetIniString('setup', 'app', '', RequestFile) = '', 'Startup detection must not depend on the app directory');
  Check(HostCount > 0, 'Detection must list at least the supported VEGAS version');
  Supported := False;
  for I := 0 to HostCount - 1 do
    if HostSupported[I] and (HostFamily[I] = 'vegas2026') then Supported := True;
  Check(Supported, 'VEGAS Pro 2026 row missing');
  (* Real detection, then the update and maintenance variants of the same pages. *)
  ProductInitializeWizard;
  Check(HostList.Items.Count = HostCount, 'Integrations page rows do not match detection');
  (* Silent mode suppresses the no-integration warning and continues. *)
  Check(ConfirmIntegrations, 'Integration confirmation failed');
  Relation := 'older';
  InstalledVersion := '0.0.1';
  ProductInitializeWizard;
  Check(Pos('0.0.1', WizardForm.WelcomeLabel2.Caption) > 0, 'Update summary missing from the welcome page');
  Relation := 'same';
  ProductInitializeWizard;
  Check(MaintenancePage.CheckListBox.Items.Count = 3, 'Maintenance choices missing');
  Check(not Repairing, 'Modify must be the default maintenance choice');
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
