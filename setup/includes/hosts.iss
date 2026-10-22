{ VEGAS integrations: one row per detected VEGAS version, read from the helper's
  read-only inspect. The helper's installation records are the source of truth. }
var
  Relation, InstalledVersion, InstalledAppDir: String;
  HostCount: Integer;
  HostFamily, HostLabel, HostDir, HostVersion, HostCore, HostRecordedDir: array of String;
  HostSupported, HostWanted: array of Boolean;
  IntegrationsPage: TWizardPage;
  HostList: TNewCheckListBox;
  FolderLabel: TNewStaticText;
  FolderEdit: TNewEdit;
  ChangeButton: TNewButton;

function Arrow: String;
begin
  Result := ' ' + #$2192 + ' ';
end;

function Ellipsis: String;
begin
  Result := #$2026;
end;

{ Startup detection deliberately omits the app directory: Inno has not
  initialized the app constant during InitializeSetup or InitializeWizard. }
function LoadInstallation(const SetupVersion: String): Boolean;
var
  I: Integer;
  N: String;
begin
  InitRequest;
  SetIniString('setup', 'version', SetupVersion, RequestFile);
  Result := Helper('inspect');
  if not Result then Exit;
  Relation := GetIniString('setup', 'relation', 'none', ResultFile);
  InstalledVersion := GetIniString('setup', 'appVersion', '', ResultFile);
  InstalledAppDir := GetIniString('setup', 'appDir', '', ResultFile);
  HostCount := StrToIntDef(GetIniString('setup', 'count', '0', ResultFile), 0);
  SetArrayLength(HostFamily, HostCount); SetArrayLength(HostLabel, HostCount);
  SetArrayLength(HostDir, HostCount); SetArrayLength(HostVersion, HostCount);
  SetArrayLength(HostCore, HostCount); SetArrayLength(HostRecordedDir, HostCount);
  SetArrayLength(HostSupported, HostCount); SetArrayLength(HostWanted, HostCount);
  for I := 0 to HostCount - 1 do begin
    N := IntToStr(I);
    HostFamily[I] := GetIniString('setup', 'family' + N, '', ResultFile);
    HostLabel[I] := GetIniString('setup', 'label' + N, '', ResultFile);
    HostDir[I] := GetIniString('setup', 'dir' + N, '', ResultFile);
    HostVersion[I] := GetIniString('setup', 'version' + N, '', ResultFile);
    HostCore[I] := GetIniString('setup', 'core' + N, '', ResultFile);
    HostSupported[I] := GetIniString('setup', 'supported' + N, '', ResultFile) = '1';
    if HostCore[I] <> '' then HostRecordedDir[I] := HostDir[I];
    { Installed exporters stay ticked; new VEGAS versions start unticked. }
    HostWanted[I] := HostSupported[I] and (HostCore[I] <> '') and (HostVersion[I] <> '');
  end;
end;

function CatalogReadable: Boolean;
begin
  Result := GetIniString('setup', 'catalog', '1', ResultFile) = '1';
end;

{ Silent and scripted installs: /VEGAS=existing (default), none, or a list such
  as 2026,23. /VEGASDIR2026="path" picks the folder for one version. }
procedure ApplyVegasParameter;
var
  I: Integer;
  Param, Version, Dir: String;
begin
  Param := Lowercase(ExpandConstant('{param:VEGAS|existing}'));
  for I := 0 to HostCount - 1 do begin
    Version := Copy(HostFamily[I], 6, Length(HostFamily[I]));
    Dir := ExpandConstant('{param:VEGASDIR' + Version + '|}');
    if Dir <> '' then begin
      HostDir[I] := RemoveBackslashUnlessRoot(Dir);
      HostVersion[I] := '?';
    end;
    if Param = 'none' then HostWanted[I] := False
    { A listed version that was not found still counts as wanted, so preparation
      fails with a clear message instead of silently skipping it. }
    else if Param <> 'existing' then
      HostWanted[I] := HostSupported[I] and (Pos(',' + Version + ',', ',' + Param + ',') > 0);
  end;
end;

function Moved(const I: Integer): Boolean;
begin
  Result := (HostRecordedDir[I] <> '') and (CompareText(HostRecordedDir[I], HostDir[I]) <> 0);
end;

function RowCaption(const I: Integer): String;
begin
  Result := HostLabel[I];
  if (HostVersion[I] <> '') and (HostVersion[I] <> '?') then Result := Result + '  (' + HostVersion[I] + ')';
end;

function RowStatus(const I: Integer; const Wanted: Boolean): String;
begin
  if not HostSupported[I] then Result := 'Not supported by this release'
  else if HostVersion[I] = '' then Result := 'Not found'
  else if HostCore[I] = '' then begin
    if Wanted then Result := 'Exporter will be added' else Result := 'Not installed';
  end
  else if not Wanted then Result := 'Exporter will be removed'
  else if Moved(I) then Result := 'Exporter will move here'
  else if Relation = 'older' then Result := 'Update ' + InstalledVersion + Arrow + '{#VeAppVersion}'
  else Result := 'Installed';
end;

procedure RefreshRows;
var
  I: Integer;
begin
  for I := 0 to HostCount - 1 do begin
    HostList.ItemCaption[I] := RowCaption(I);
    HostList.ItemSubItem[I] := RowStatus(I, HostList.Checked[I]);
  end;
end;

procedure ShowSelectedFolder;
var
  I: Integer;
begin
  I := HostList.ItemIndex;
  if I < 0 then Exit;
  FolderLabel.Caption := 'Folder for ' + HostLabel[I];
  if HostDir[I] <> '' then FolderEdit.Text := HostDir[I] else FolderEdit.Text := 'Not found';
  ChangeButton.Enabled := HostSupported[I];
  if HostVersion[I] = '' then ChangeButton.Caption := 'Locate' + Ellipsis
  else ChangeButton.Caption := 'Change' + Ellipsis;
end;

function ValidateHost(const I: Integer; const Dir: String): Boolean;
begin
  InitRequest;
  SetIniString('setup', 'host', Dir, RequestFile);
  SetIniString('setup', 'family', HostFamily[I], RequestFile);
  Result := Helper('validate');
end;

{ Returns True when the user picked a valid folder for row I. }
function BrowseHost(const I: Integer): Boolean;
var
  Dir: String;
begin
  Result := False;
  Dir := HostDir[I];
  if Dir = '' then Dir := ExpandConstant('{commonpf}');
  if not BrowseForFolder('Select the ' + HostLabel[I] + ' folder.', Dir, False) then Exit;
  if not ValidateHost(I, Dir) then begin
    SuppressibleMsgBox(HelperError, mbError, MB_OK, IDOK);
    Exit;
  end;
  HostDir[I] := RemoveBackslashUnlessRoot(Dir);
  HostVersion[I] := GetIniString('setup', 'version', '', ResultFile);
  Result := True;
end;

procedure HostSelected(Sender: TObject);
begin
  ShowSelectedFolder;
end;

procedure HostChecked(Sender: TObject);
var
  I: Integer;
begin
  I := HostList.ItemIndex;
  { Ticking a version that was not detected asks for its folder first. }
  if (I >= 0) and HostList.Checked[I] and (HostVersion[I] = '') then
    if not BrowseHost(I) then HostList.Checked[I] := False;
  RefreshRows;
  ShowSelectedFolder;
end;

procedure ChangeFolder(Sender: TObject);
var
  I: Integer;
begin
  I := HostList.ItemIndex;
  if (I < 0) or not BrowseHost(I) then Exit;
  HostList.Checked[I] := True;
  RefreshRows;
  ShowSelectedFolder;
end;

procedure CreateIntegrationsPage(const AfterID: Integer);
var
  Intro: TNewStaticText;
  I: Integer;
begin
  IntegrationsPage := CreateCustomPage(AfterID, 'VEGAS integrations',
    'Choose which VEGAS versions get the Vegas Encoder exporter.');
  Intro := TNewStaticText.Create(IntegrationsPage);
  Intro.Parent := IntegrationsPage.Surface;
  Intro.Width := IntegrationsPage.SurfaceWidth;
  Intro.WordWrap := True;
  Intro.Caption := 'Tick each VEGAS version to install the exporter into. Unticking an installed ' +
    'version removes its exporter. The app is always installed and updated.';
  HostList := TNewCheckListBox.Create(IntegrationsPage);
  HostList.Parent := IntegrationsPage.Surface;
  HostList.Top := Intro.Top + Intro.Height + ScaleY(10);
  HostList.Width := IntegrationsPage.SurfaceWidth;
  HostList.Height := ScaleY(104) + IntegrationsPage.SurfaceExtraHeight;
  HostList.Anchors := [akLeft, akTop, akRight, akBottom];
  HostList.OnClickCheck := @HostChecked;
  HostList.OnClick := @HostSelected;
  for I := 0 to HostCount - 1 do
    HostList.AddCheckBox(RowCaption(I), RowStatus(I, HostWanted[I]), 0, HostWanted[I], HostSupported[I], False, False, nil);
  FolderLabel := TNewStaticText.Create(IntegrationsPage);
  FolderLabel.Parent := IntegrationsPage.Surface;
  FolderLabel.Top := HostList.Top + HostList.Height + ScaleY(10);
  FolderLabel.Anchors := [akLeft, akBottom];
  ChangeButton := TNewButton.Create(IntegrationsPage);
  ChangeButton.Parent := IntegrationsPage.Surface;
  ChangeButton.Width := WizardForm.NextButton.Width;
  ChangeButton.Height := WizardForm.NextButton.Height;
  ChangeButton.Left := IntegrationsPage.SurfaceWidth - ChangeButton.Width;
  ChangeButton.Top := FolderLabel.Top + FolderLabel.Height + ScaleY(4);
  ChangeButton.Anchors := [akRight, akBottom];
  ChangeButton.OnClick := @ChangeFolder;
  FolderEdit := TNewEdit.Create(IntegrationsPage);
  FolderEdit.Parent := IntegrationsPage.Surface;
  FolderEdit.ReadOnly := True;
  FolderEdit.Top := ChangeButton.Top + (ChangeButton.Height - FolderEdit.Height) div 2;
  FolderEdit.Width := ChangeButton.Left - ScaleX(8);
  FolderEdit.Anchors := [akLeft, akRight, akBottom];
  if HostCount > 0 then HostList.ItemIndex := 0;
  ShowSelectedFolder;
end;

{ Repair reinstalls exactly what is recorded, undoing unsaved page changes. }
procedure SelectRecorded;
var
  I: Integer;
begin
  for I := 0 to HostCount - 1 do begin
    if HostCore[I] <> '' then HostDir[I] := HostRecordedDir[I];
    HostList.Checked[I] := HostSupported[I] and (HostCore[I] <> '') and (HostVersion[I] <> '');
  end;
  RefreshRows;
end;

procedure ReadIntegrationChoices;
var
  I: Integer;
begin
  { Interactive ticks on a version that was not found are undone unless its folder
    is located, so only scripted selections can reach the helper without one. }
  for I := 0 to HostCount - 1 do
    HostWanted[I] := HostSupported[I] and HostList.Checked[I];
end;

function AnyWanted: Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to HostCount - 1 do if HostWanted[I] then Result := True;
end;

function AnyInstalled: Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to HostCount - 1 do if HostCore[I] <> '' then Result := True;
end;

{ Warns once when nothing is ticked. Silent installs continue. }
function ConfirmIntegrations: Boolean;
begin
  ReadIntegrationChoices;
  Result := True;
  if AnyWanted then Exit;
  if AnyInstalled then
    Result := SuppressibleTaskDialogMsgBox('Remove the exporter from every VEGAS version?',
      'Vegas Encoder will be updated, but its exporter will be removed. It won''t appear in VEGAS Render As until you run setup again and tick a VEGAS version.',
      mbConfirmation, MB_OKCANCEL, ['Remove and continue', 'Go back'], 0, IDOK) = IDOK
  else
    Result := SuppressibleTaskDialogMsgBox('Install without a VEGAS integration?',
      'Vegas Encoder will be installed, but it won''t appear in VEGAS Render As. Run setup again to add a VEGAS version later.',
      mbConfirmation, MB_OKCANCEL, ['Continue without VEGAS', 'Go back'], 0, IDOK) = IDOK;
end;

procedure AddTargets;
var
  I, Count: Integer;
begin
  Count := 0;
  for I := 0 to HostCount - 1 do
    if HostWanted[I] then begin
      SetIniString('setup', 'family' + IntToStr(Count), HostFamily[I], RequestFile);
      SetIniString('setup', 'dir' + IntToStr(Count), HostDir[I], RequestFile);
      Count := Count + 1;
    end;
  SetIniString('setup', 'count', IntToStr(Count), RequestFile);
end;

function IntegrationSummary(const Space, NewLine: String): String;
var
  I: Integer;
  Line: String;
begin
  Result := '';
  for I := 0 to HostCount - 1 do begin
    Line := '';
    if HostWanted[I] and (HostCore[I] = '') then Line := 'add exporter in ' + HostDir[I]
    else if HostWanted[I] and Moved(I) then Line := 'move exporter to ' + HostDir[I]
    else if HostWanted[I] and (Relation = 'older') then Line := 'update exporter'
    else if HostWanted[I] then Line := 'reinstall exporter'
    else if HostCore[I] <> '' then Line := 'remove exporter';
    if Line <> '' then Result := Result + Space + HostLabel[I] + ': ' + Line + NewLine;
  end;
  if Result = '' then Result := Space + 'No VEGAS integration' + NewLine;
end;

function WantedLabels: String;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to HostCount - 1 do
    if HostWanted[I] then begin
      if Result <> '' then Result := Result + ', ';
      Result := Result + HostLabel[I];
    end;
end;
