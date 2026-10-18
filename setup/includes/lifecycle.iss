function PrepareToInstall(var NeedsRestart: Boolean): String;
var PreviousApp: String;
begin
  Result := '';
  PreviousApp := GetPreviousData('AppDir', '');
  if (PreviousApp <> '') and
     (CompareText(RemoveBackslash(PreviousApp), RemoveBackslash(ExpandConstant('{app}'))) <> 0) then begin
    Result := 'Keep the existing app directory when updating. To move it, uninstall the previous installation first.';
    Exit;
  end;
  if TransactionDir <> '' then begin
    InitAppRequest;
    if not Helper('rollback') then begin Result := HelperError; Exit; end;
    TransactionDir := '';
  end;
  { We do not download or install machine-wide dependencies automatically. }
  if not FileExists(ExpandConstant('{sys}\vcruntime140.dll')) or
     not FileExists(ExpandConstant('{sys}\vcruntime140_1.dll')) or
     not FileExists(ExpandConstant('{sys}\msvcp140.dll')) then begin
    Result := 'Install the Microsoft Visual C++ 2015-2022 x64 Redistributable, then run Setup again.';
    Exit;
  end;
  ExtractTemporaryFile('payload.json');
  ExtractTemporaryFile('vegas-encoder.dll');
  ExtractTemporaryFile('vegas-encoder.ini.in');
  ExtractTemporaryFile('VegasEncoder-x64.fio2007-config');
  InitAppRequest;
  if WizardIsComponentSelected('vegas2026') then
    SetIniString('setup', 'host', HostPage.Values[0], RequestFile);
  SetIniString('setup', 'payload', ExpandConstant('{tmp}'), RequestFile);
  if Helper('prepare') then
    TransactionDir := GetIniString('setup', 'transaction', '', ResultFile)
  else Result := HelperError;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then begin
    InitAppRequest;
    if not Helper('commit') then RaiseException(HelperError);
    SetupCommitted := True;
  end;
end;

procedure DeinitializeSetup;
begin
  if (TransactionDir <> '') and not SetupCommitted then begin
    InitAppRequest;
    if not Helper('rollback') then
      SuppressibleMsgBox('Automatic rollback could not finish.' + #13#10 + HelperError, mbError, MB_OK, IDOK);
  end;
end;

function InitializeUninstall: Boolean;
begin
  HelperExe := ExpandConstant('{tmp}\ve-install.exe');
  Result := CopyFile(ExpandConstant('{app}\setup-support\ve-install.exe'), HelperExe, False);
  if not Result then begin
    SuppressibleMsgBox('The setup helper is missing. Repair the installation before uninstalling.', mbError, MB_OK, IDOK);
    Exit;
  end;
  InitAppRequest;
  Result := Helper('uninstall-check');
  if not Result then SuppressibleMsgBox(HelperError, mbError, MB_OK, IDOK);
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then begin
    InitAppRequest;
    if not Helper('uninstall-prepare') then RaiseException(HelperError);
    TransactionDir := GetIniString('setup', 'transaction', '', ResultFile);
    InitAppRequest;
    if not Helper('uninstall') then RaiseException(HelperError);
  end;
  if CurUninstallStep = usPostUninstall then begin
    InitAppRequest;
    if not Helper('finish-removal') then RaiseException(HelperError);
    RemovalCommitted := True;
  end;
end;

procedure DeinitializeUninstall;
begin
  if (TransactionDir <> '') and not RemovalCommitted then begin
    InitAppRequest;
    if not Helper('rollback') then
      SuppressibleMsgBox('Automatic rollback could not finish.' + #13#10 + HelperError, mbError, MB_OK, IDOK);
  end;
end;
