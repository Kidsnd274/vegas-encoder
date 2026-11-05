{ Asks the user to close programs that use the app or a selected VEGAS folder.
  Returns '' when nothing is open; otherwise the message Setup stops with. }
function WaitForClosedPrograms: String;
var
  Busy: String;
begin
  Result := '';
  repeat
    InitAppRequest;
    AddTargets;
    if not Helper('running') then begin Result := HelperError; Exit; end;
    Busy := GetIniString('setup', 'busy', '', ResultFile);
    if Busy = '' then Exit;
    if SuppressibleTaskDialogMsgBox('Close programs to continue',
      'Close these programs, then click Retry: ' + Busy, mbError, MB_RETRYCANCEL, [], 0, IDCANCEL) <> IDRETRY then begin
      Result := 'Close these programs, then run Setup again: ' + Busy;
      Exit;
    end;
  until False;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var PreviousApp: String;
begin
  Result := '';
  ReadIntegrationChoices;
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
  Result := WaitForClosedPrograms;
  if Result <> '' then Exit;
  ExtractTemporaryFile('payload.json');
  ExtractTemporaryFile('vegas-encoder.dll');
  ExtractTemporaryFile('vegas-encoder-22.dll');
  ExtractTemporaryFile('vegas-encoder-21.dll');
  ExtractTemporaryFile('vegas-encoder-13.dll');
  ExtractTemporaryFile('vegas-encoder.ini.in');
  ExtractTemporaryFile('VegasEncoder-x64.fio2007-config');
  InitAppRequest;
  AddTargets;
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

var
  RemoveSettings, RemoveLibrary: Boolean;

function CommandLineFlag(const Name: String): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to ParamCount do
    if CompareText(ParamStr(I), Name) = 0 then Result := True;
end;

function PresetCount: Integer;
var
  Found: TFindRec;
begin
  Result := 0;
  if FindFirst(ExpandConstant('{userappdata}\VegasEncoder\library\*.vepreset'), Found) then
    try
      repeat Result := Result + 1; until not FindNext(Found);
    finally
      FindClose(Found);
    end;
end;

function AddText(const Form: TSetupForm; const Top: Integer; const Caption: String): TNewStaticText;
begin
  Result := TNewStaticText.Create(Form);
  Result.Parent := Form;
  Result.Left := ScaleX(16);
  Result.Top := Top;
  Result.Width := Form.ClientWidth - ScaleX(32);
  Result.WordWrap := True;
  Result.Caption := Caption;
  Result.AdjustHeight;
end;

function AddChoice(const Form: TSetupForm; const Top: Integer; const Caption: String; const Checked: Boolean): TNewCheckBox;
begin
  Result := TNewCheckBox.Create(Form);
  Result.Parent := Form;
  Result.Left := ScaleX(16);
  Result.Top := Top;
  Result.Width := Form.ClientWidth - ScaleX(32);
  Result.Height := ScaleY(20);
  Result.Caption := Caption;
  Result.Checked := Checked;
end;

{ Data stays by default. Silent uninstalls remove it only with /REMOVEDATA
  (settings, caches, logs, setup backups) and /REMOVEPRESETS (preset library). }
procedure AskAboutUserData;
var
  Form: TSetupForm;
  Title, Note: TNewStaticText;
  SettingsBox, LibraryBox: TNewCheckBox;
  ContinueButton: TNewButton;
  Count: Integer;
begin
  RemoveSettings := CommandLineFlag('/REMOVEDATA');
  RemoveLibrary := CommandLineFlag('/REMOVEPRESETS');
  if UninstallSilent then Exit;
  Count := PresetCount;
  Form := CreateCustomForm(ScaleX(440), ScaleY(240), False, False);
  try
    Form.Caption := 'Uninstall Vegas Encoder';
    Title := AddText(Form, ScaleY(16), 'Also remove your Vegas Encoder data?');
    Title.Font.Style := [fsBold];
    Title.AdjustHeight;
    Note := AddText(Form, Title.Top + Title.Height + ScaleY(8),
      'Your data is kept unless you tick it here, so reinstalling picks up where you left off. ' +
      'Ticked items are deleted for this Windows account and can''t be restored.');
    SettingsBox := AddChoice(Form, Note.Top + Note.Height + ScaleY(14),
      'Settings, caches, render logs and setup backups', RemoveSettings);
    LibraryBox := AddChoice(Form, SettingsBox.Top + SettingsBox.Height + ScaleY(6),
      'Preset library (' + IntToStr(Count) + ' presets)', RemoveLibrary);
    ContinueButton := TNewButton.Create(Form);
    ContinueButton.Parent := Form;
    ContinueButton.Caption := 'Continue';
    ContinueButton.Width := Form.CalculateButtonWidth([ContinueButton.Caption]);
    ContinueButton.Height := ScaleY(23);
    ContinueButton.Left := Form.ClientWidth - ContinueButton.Width - ScaleX(16);
    ContinueButton.Top := LibraryBox.Top + LibraryBox.Height + ScaleY(18);
    ContinueButton.ModalResult := mrOk;
    ContinueButton.Default := True;
    Form.ClientHeight := ContinueButton.Top + ContinueButton.Height + ScaleY(16);
    Form.ActiveControl := ContinueButton;
    { Closing the window keeps everything. }
    if Form.ShowModal = mrOk then begin
      RemoveSettings := SettingsBox.Checked;
      RemoveLibrary := LibraryBox.Checked;
    end else begin
      RemoveSettings := False;
      RemoveLibrary := False;
    end;
  finally
    Form.Free;
  end;
end;

procedure RemoveUserData;
var
  Flag: String;
begin
  if not RemoveSettings and not RemoveLibrary then Exit;
  InitRequest;
  SetIniString('setup', 'appdata', ExpandConstant('{userappdata}'), RequestFile);
  SetIniString('setup', 'localappdata', ExpandConstant('{localappdata}'), RequestFile);
  if RemoveSettings then Flag := '1' else Flag := '0';
  SetIniString('setup', 'settings', Flag, RequestFile);
  if RemoveLibrary then Flag := '1' else Flag := '0';
  SetIniString('setup', 'library', Flag, RequestFile);
  { Vegas Encoder is already uninstalled here; a leftover folder is only reported. }
  if not Helper('remove-data') then
    SuppressibleMsgBox('Vegas Encoder was uninstalled, but some of your data was not removed.' + #13#10#13#10 +
      GetIniString('setup', 'message', 'The setup helper could not complete.', ResultFile), mbInformation, MB_OK, IDOK);
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
    AskAboutUserData;
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
    RemoveUserData;
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
