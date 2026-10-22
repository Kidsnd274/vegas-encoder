{ Setup modes, chosen from the installed app's version:
  none = install, older = update, same = maintenance, newer = blocked. }
var
  MaintenancePage: TInputOptionWizardPage;
  ClosingForUninstall: Boolean;

function Maintenance: Boolean;
begin
  Result := Relation = 'same';
end;

function Repairing: Boolean;
begin
  Result := Maintenance and (MaintenancePage.SelectedValueIndex = 1);
end;

function InitializeSetup: Boolean;
begin
  ExtractHelper;
  Result := LoadInstallation('{#VeAppVersion}');
  if not Result then begin
    SuppressibleMsgBox(HelperError, mbError, MB_OK, IDOK);
    Exit;
  end;
  if not CatalogReadable then begin
    SuppressibleMsgBox('Setup cannot read its installation records. Run Setup as administrator.' + #13#10#13#10 +
      GetIniString('setup', 'catalogError', '', ResultFile), mbError, MB_OK, IDOK);
    Result := False;
    Exit;
  end;
  if Relation = 'newer' then begin
    SuppressibleTaskDialogMsgBox('A newer version is installed',
      'Vegas Encoder ' + InstalledVersion + ' is installed. Uninstall it before installing this older version ({#VeAppVersion}).',
      mbError, MB_OK, [], 0, IDOK);
    Result := False;
    Exit;
  end;
  ApplyVegasParameter;
end;

procedure InitializeWizard;
var
  I: Integer;
  Cores: String;
begin
  if Relation = 'older' then begin
    Cores := '';
    for I := 0 to HostCount - 1 do
      if HostCore[I] <> '' then Cores := Cores + #13#10 + '    ' + HostLabel[I];
    if Cores = '' then Cores := #13#10 + '    No VEGAS integration is installed.';
    WizardForm.WelcomeLabel2.Caption := 'Vegas Encoder ' + InstalledVersion + ' is installed. This setup updates it to {#VeAppVersion}, ' +
      'together with the exporter in each VEGAS version it is installed in:' + #13#10 + Cores + #13#10#13#10 +
      'Each exporter only works with the matching app version, so they are always updated together.' + #13#10#13#10 +
      'Close VEGAS and Vegas Encoder before continuing.';
    WizardForm.AdjustLabelHeight(WizardForm.WelcomeLabel2);
  end;
  if Maintenance then begin
    MaintenancePage := CreateInputOptionPage(wpWelcome, 'Vegas Encoder {#VeAppVersion} is already installed',
      'Choose what to do.', '', True, False);
    MaintenancePage.Add('Modify' + #13#10 + 'Add or remove VEGAS integrations.');
    MaintenancePage.Add('Repair' + #13#10 + 'Reinstall the app and every installed exporter.');
    MaintenancePage.Add('Uninstall' + #13#10 + 'Remove Vegas Encoder and every VEGAS exporter.');
    MaintenancePage.SelectedValueIndex := 0;
    CreateIntegrationsPage(MaintenancePage.ID);
  end else
    CreateIntegrationsPage(wpSelectDir);
end;

function ShouldSkipPage(PageID: Integer): Boolean;
begin
  Result := False;
  if PageID = wpWelcome then Result := Maintenance
  else if Repairing then Result := (PageID = IntegrationsPage.ID) or (PageID = wpSelectTasks);
end;

function UninstallerPath: String;
begin
  Result := '';
  RegQueryStringValue(HKLM, 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{#VeAppId}_is1', 'UninstallString', Result);
  Result := RemoveQuotes(Result);
end;

function NextButtonClick(CurPageID: Integer): Boolean;
var
  Code: Integer;
begin
  Result := True;
  if Maintenance and (CurPageID = MaintenancePage.ID) then begin
    if MaintenancePage.SelectedValueIndex = 2 then begin
      Result := False;
      if (UninstallerPath = '') or not Exec(UninstallerPath, '', '', SW_SHOW, ewNoWait, Code) then begin
        SuppressibleMsgBox('The Vegas Encoder uninstaller was not found. Use Installed apps in Windows Settings instead.', mbError, MB_OK, IDOK);
        Exit;
      end;
      ClosingForUninstall := True;
      WizardForm.Close;
    end else if Repairing then SelectRecorded;
  end;
  if CurPageID = IntegrationsPage.ID then Result := ConfirmIntegrations;
end;

procedure CancelButtonClick(CurPageID: Integer; var Cancel, Confirm: Boolean);
begin
  if ClosingForUninstall then Confirm := False;
end;

function UpdateReadyMemo(Space, NewLine, MemoUserInfoInfo, MemoDirInfo, MemoTypeInfo, MemoComponentsInfo, MemoGroupInfo, MemoTasksInfo: String): String;
var
  Action: String;
begin
  if Repairing then ReadIntegrationChoices;
  if Relation = 'none' then Action := 'Install Vegas Encoder {#VeAppVersion}'
  else if Relation = 'older' then Action := 'Update Vegas Encoder ' + InstalledVersion + Arrow + '{#VeAppVersion}'
  else if Repairing then Action := 'Repair Vegas Encoder {#VeAppVersion}'
  else Action := 'Keep Vegas Encoder {#VeAppVersion}';
  Result := 'App' + NewLine + Space + Action + NewLine + Space + ExpandConstant('{app}') + NewLine + NewLine +
    'VEGAS integrations' + NewLine + IntegrationSummary(Space, NewLine);
  if MemoTasksInfo <> '' then Result := Result + NewLine + MemoTasksInfo;
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  if CurPageID = wpFinished then begin
    if AnyWanted then
      WizardForm.FinishedLabel.Caption := WizardForm.FinishedLabel.Caption + #13#10#13#10 +
        'Restart ' + WantedLabels + ' to load the exporter.'
    else
      WizardForm.FinishedLabel.Caption := WizardForm.FinishedLabel.Caption + #13#10#13#10 +
        'No VEGAS integration is installed. Run setup again to add one.';
    WizardForm.AdjustLabelHeight(WizardForm.FinishedLabel);
  end;
end;

procedure RegisterPreviousData(PreviousDataKey: Integer);
begin
  SetPreviousData(PreviousDataKey, 'AppDir', ExpandConstant('{app}'));
end;
