var
  HelperExe, RequestFile, ResultFile, TransactionDir: String;
  SetupCommitted, RemovalCommitted: Boolean;

function Quoted(const Value: String): String;
begin
  Result := '"' + Value + '"';
end;

procedure InitRequest;
begin
  RequestFile := ExpandConstant('{tmp}\ve-setup-request.ini');
  ResultFile := ExpandConstant('{tmp}\ve-setup-result.ini');
  { A BOM makes Windows INI functions preserve non-ASCII installation paths. }
  SaveStringToFile(RequestFile, #$FF#$FE, False);
  SetIniString('setup', 'transaction', TransactionDir, RequestFile);
end;

procedure InitAppRequest;
begin
  { The app constant is unavailable during InitializeWizard. Detection/validation use
    InitRequest; only installation and uninstall requests need the final path. }
  InitRequest;
  SetIniString('setup', 'app', ExpandConstant('{app}'), RequestFile);
end;

function Helper(const Operation: String): Boolean;
var
  ExitCode: Integer;
begin
  DeleteFile(ResultFile);
  Result := Exec(HelperExe, Operation + ' ' + Quoted(RequestFile) + ' ' +
    Quoted(ResultFile), '', SW_HIDE, ewWaitUntilTerminated, ExitCode);
  if Result then Result := (ExitCode = 0) and
    (GetIniString('setup', 'ok', '', ResultFile) = '1');
end;

function HelperError: String;
begin
  Result := GetIniString('setup', 'message',
    'The setup helper could not complete. Check antivirus quarantine and the Setup log.', ResultFile);
  if TransactionDir <> '' then
    Result := Result + #13#10#13#10 + 'Backup/rollback: ' + TransactionDir;
end;

procedure ExtractHelper;
begin
  ExtractTemporaryFile('ve-install.exe');
  HelperExe := ExpandConstant('{tmp}\ve-install.exe');
end;
