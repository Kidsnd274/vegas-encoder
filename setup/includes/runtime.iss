const
  VisualCppRuntimeUrl = 'https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist?view=msvc-170#latest-supported-redistributable-version';
  VisualCppRuntimeInstructions = 'Download and install the x64 Microsoft Visual C++ Redistributable, then run Setup again.';

function HasX64VisualCppRuntime: Boolean;
var SystemDir: String;
begin
  SystemDir := ExpandConstant('{sys}');
#if Ver >= 0x07000000
  { A 32-bit Inno Setup 7 process needs the Sysnative alias for x64 DLLs. }
  SystemDir := ApplyPathRedirRulesForCurrentProcess(True, SystemDir);
#endif
  Result := FileExists(AddBackslash(SystemDir) + 'vcruntime140.dll') and
    FileExists(AddBackslash(SystemDir) + 'vcruntime140_1.dll') and
    FileExists(AddBackslash(SystemDir) + 'msvcp140.dll');
end;

function MissingVisualCppRuntimeMessage: String;
var ErrorCode: Integer;
begin
  Result := VisualCppRuntimeInstructions + #13#10#13#10 + VisualCppRuntimeUrl;
  if WizardSilent then Exit;
  if SuppressibleTaskDialogMsgBox('Microsoft Visual C++ Redistributable required',
    VisualCppRuntimeInstructions, mbError, MB_OKCANCEL, ['Open Microsoft download page'], 0, IDCANCEL) = IDOK then
    if not ShellExecAsOriginalUser('open', VisualCppRuntimeUrl, '', '', SW_SHOWNORMAL, ewNoWait, ErrorCode) then
      Log('Could not open the Visual C++ Redistributable download page: ' + SysErrorMessage(ErrorCode));
end;
