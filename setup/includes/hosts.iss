var
  HostPage: TInputDirWizardPage;
  DetectedHosts: TNewComboBox;

procedure SelectDetectedHost(Sender: TObject);
begin
  if DetectedHosts.ItemIndex >= 0 then
    HostPage.Values[0] := DetectedHosts.Items[DetectedHosts.ItemIndex];
end;

procedure InitializeWizard;
var
  Count, I: Integer;
  PreviousHost: String;
begin
  ExtractHelper;
  InitRequest;
  HostPage := CreateInputDirPage(wpSelectComponents,
    'VEGAS Pro 2026 plug-in', 'Choose the VEGAS installation to integrate with',
    'Select a detected folder, or Browse to a folder containing vegas2026.exe.' + #13#10 +
    'On updates, this selection replaces the previous plug-in target. ' +
    'Unchecking the plug-in component removes the previous integration.', False, '');
  HostPage.Add('VEGAS Pro 2026 folder:');
  DetectedHosts := TNewComboBox.Create(HostPage);
  DetectedHosts.Parent := HostPage.Surface;
  DetectedHosts.Left := 0;
  DetectedHosts.Top := HostPage.Buttons[0].Top + HostPage.Buttons[0].Height + ScaleY(20);
  DetectedHosts.Width := HostPage.SurfaceWidth;
  DetectedHosts.Style := csDropDownList;
  DetectedHosts.OnChange := @SelectDetectedHost;
  if Helper('inspect') then begin
    Count := StrToIntDef(GetIniString('setup', 'count', '0', ResultFile), 0);
    for I := 0 to Count - 1 do
      DetectedHosts.Items.Add(GetIniString('setup', 'host' + IntToStr(I), '', ResultFile));
  end;
  if DetectedHosts.Items.Count > 0 then begin
    DetectedHosts.ItemIndex := 0;
    SelectDetectedHost(DetectedHosts);
  end;
  PreviousHost := GetPreviousData('Vegas2026Dir', '');
  if PreviousHost <> '' then HostPage.Values[0] := PreviousHost;
  if ExpandConstant('{param:VEGASDIR|}') <> '' then
    HostPage.Values[0] := ExpandConstant('{param:VEGASDIR|}');
end;

function ShouldSkipPage(PageID: Integer): Boolean;
begin
  Result := (PageID = HostPage.ID) and not WizardIsComponentSelected('vegas2026');
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if CurPageID = HostPage.ID then begin
    InitRequest;
    SetIniString('setup', 'host', HostPage.Values[0], RequestFile);
    Result := Helper('validate');
    if not Result then SuppressibleMsgBox(HelperError, mbError, MB_OK, IDOK);
  end;
end;

procedure RegisterPreviousData(PreviousDataKey: Integer);
var Host: String;
begin
  Host := '';
  if WizardIsComponentSelected('vegas2026') then Host := HostPage.Values[0];
  SetPreviousData(PreviousDataKey, 'Vegas2026Dir', Host);
  SetPreviousData(PreviousDataKey, 'AppDir', ExpandConstant('{app}'));
end;
