#Requires -Version 7.0
[CmdletBinding()]
param([switch] $Asan)
$ErrorActionPreference = 'Stop'
$b6Root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
foreach ($b6Output in 'build','build\core','build\b6-tests','build\b6-tests-asan') {
  $b6Path = Join-Path $b6Root $b6Output
  if ((Test-Path -LiteralPath $b6Path) -and
      ((Get-Item -LiteralPath $b6Path).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    throw "B6 build output must not follow a reparse point: $b6Path"
  }
}
Push-Location -LiteralPath $b6Root
try {
  & $env:ComSpec /d /c scripts\build-core.cmd
  if ($LASTEXITCODE -ne 0) { throw 'B6 core build failed.' }
  & $env:ComSpec /d /c scripts\Build-B6.cmd
  if ($LASTEXITCODE -ne 0) { throw 'B6 offline snapshot/session checks failed.' }
  if ($Asan) {
    # Test in the vcvars process so the existing MSVC ASan runtime is on PATH.
    & $env:ComSpec /d /c 'scripts\Build-B6.cmd "" asan'
    if ($LASTEXITCODE -ne 0) { throw 'B6 ASan snapshot/session checks failed.' }
  }
} finally { Pop-Location }
Write-Output 'B6 preparation PASS; no exporter installation, editor/monitor launch or VEGAS test.'
