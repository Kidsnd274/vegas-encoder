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
    finished_page(args, fixture)


EVENTS = ('function InitializeSetup', 'procedure InitializeWizard', 'function ShouldSkipPage', 'function NextButtonClick',
          'procedure CancelButtonClick', 'function UpdateReadyMemo', 'procedure CurPageChanged', 'procedure RegisterPreviousData')


def finished_page(args, fixture):
    """Show the real Finished page from a setup with no files and no app folder.

    The fixture's only [Run] entry is a hidden `cmd /c exit 0`. The script clicks through
    the Ready page, records the label and launch-checkbox layout, unticks the checkbox and
    closes the wizard itself. A stuck window is closed when the run times out.
    """
    wizard = (REPO / 'setup/includes/wizard.iss').read_text(encoding='utf-8')
    for event in EVENTS:
        kind, name = event.split()
        wizard = wizard.replace(f'{event}', f'{kind} Product{name}')
    (fixture / 'finished-wizard.iss').write_text(wizard, encoding='utf-8-sig')
    marker = fixture / 'finished.txt'
    script = fr'''#include "{REPO / 'setup/version.generated.iss'}"
#define VeAppId "{{0CF24E60-C0F5-4242-96AD-13FF2F9BF313}}"
[Setup]
AppName=Vegas Encoder finished-page fixture
AppVersion=0
PrivilegesRequired=lowest
CreateAppDir=no
Uninstallable=no
DisableWelcomePage=yes
DisableReadyPage=yes
WizardStyle=modern dynamic polar
OutputDir={fixture}
OutputBaseFilename=finished-test
[Run]
Filename: "{{cmd}}"; Parameters: "/c exit 0"; Description: "Launch Vegas Encoder"; Flags: postinstall nowait runhidden
[Code]
#include "{REPO / 'setup/includes/helper.iss'}"
#include "{REPO / 'setup/includes/hosts.iss'}"
#include "finished-wizard.iss"
procedure CurPageChanged(CurPageID: Integer);
var
  Before: Integer;
begin
  (* Inno still shows the Ready page when it would be the only page; click Install. *)
  if CurPageID = wpReady then PostMessage(WizardForm.NextButton.Handle, $00F5, 0, 0);
  if CurPageID <> wpFinished then Exit;
  HostCount := 1;
  SetArrayLength(HostLabel, 1); SetArrayLength(HostWanted, 1);
  HostLabel[0] := 'VEGAS Pro 2026'; HostWanted[0] := True;
  Before := WizardForm.RunList.Top;
  ProductCurPageChanged(wpFinished);
  SaveStringToFile('{marker}', Format('%d %d %d %d %d', [Before,
    WizardForm.FinishedLabel.Top + WizardForm.FinishedLabel.Height, WizardForm.RunList.Top,
    Ord(WizardForm.RunList.Visible), Ord(WizardForm.RunList.Checked[0])]), False);
  WizardForm.RunList.Checked[0] := False;
  PostMessage(WizardForm.NextButton.Handle, $00F5, 0, 0);
end;
'''
    source = fixture / 'finished-test.iss'
    source.write_text(script, encoding='utf-8-sig')
    subprocess.run([args.iscc, '/Q', str(source)], check=True, timeout=60)
    try:
        result = subprocess.run([str(fixture / 'finished-test.exe'), f'/LOG={fixture / "finished.log"}'], timeout=60)
    except subprocess.TimeoutExpired:
        # Inno runs the wizard in a copied finished-test.tmp; close only that fixture.
        subprocess.run(['taskkill', '/F', '/IM', 'finished-test.tmp'], capture_output=True)
        raise SystemExit(f'Finished-page fixture did not close itself; see {fixture / "finished.log"}')
    if not marker.exists():
        raise SystemExit(f'Finished page did not run (exit {result.returncode}); see {fixture / "finished.log"}')
    before, label_bottom, top, visible, checked = map(int, marker.read_text(encoding='ascii').split())
    if not (visible and checked and top >= label_bottom):
        raise SystemExit(f'Launch checkbox hidden, unticked or covered: label ends {label_bottom}, checkbox at {top} '
                         f'(Inno placed it at {before}), visible {visible}, ticked {checked}')
    print(f'Finished page PASS: launch checkbox visible and ticked below the text (label ends {label_bottom}, '
          f'checkbox at {top}; Inno placed it at {before}).')


if __name__ == '__main__':
    main()
