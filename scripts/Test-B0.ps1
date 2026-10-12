#Requires -Version 7.0
[CmdletBinding()]
param(
  [string] $DartPath = 'L:\flutter\bin\cache\dart-sdk\bin\dart.exe',
  [string] $PythonPath = 'python',
  [string] $NodePath = 'node',
  [string] $VcvarsPath = ''
)
$ErrorActionPreference = 'Stop'
$b0Root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
function Invoke-B0Check {
  param([string] $Exe, [string[]] $Arguments)
  & $Exe @Arguments
  if ($LASTEXITCODE -ne 0) { throw "B0 check failed: $Exe (exit $LASTEXITCODE)" }
}
Push-Location -LiteralPath $b0Root
try {
  Invoke-B0Check $NodePath @('scripts/Generate-B0Fixtures.mjs','--check')
  Invoke-B0Check $PythonPath @('-I','scripts/Test-B0Fixtures.py')
  foreach ($b0Package in 've_core','ve_services') {
    Push-Location -LiteralPath (Join-Path $b0Root "packages\$b0Package")
    try {
      Invoke-B0Check $DartPath @('pub','get','--offline')
      Invoke-B0Check $DartPath @('analyze','--fatal-infos')
      Invoke-B0Check $DartPath @('run','test/contracts_test.dart')
    } finally { Pop-Location }
  }
  Invoke-B0Check 'cmd.exe' @('/d','/c',(Join-Path $PSScriptRoot 'Test-B0Header.cmd'),$VcvarsPath)
} finally { Pop-Location }
Write-Host 'B0 CONTRACTS PASSED (Dart fakes/design fixtures and offline ABI compilation only).'
