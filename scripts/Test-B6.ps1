#Requires -Version 7.0
[CmdletBinding()]
param([switch] $Asan)
$ErrorActionPreference = 'Stop'
$b6Root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
foreach ($b6Output in 'build','build\release\vegas-encoder\core','build\b6-tests','build\b6-tests-asan','build\test-results') {
  $b6Path = Join-Path $b6Root $b6Output
  if ((Test-Path -LiteralPath $b6Path) -and
      ((Get-Item -LiteralPath $b6Path).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    throw "B6 build output must not follow a reparse point: $b6Path"
  }
}
$b6TrialRoot = Join-Path $b6Root ('build\test-results\b6-transport-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $b6TrialRoot | Out-Null
$b6JunctionTarget = Join-Path $b6TrialRoot 'junction-target'
New-Item -ItemType Directory -Path (Join-Path $b6JunctionTarget 'child') | Out-Null
New-Item -ItemType Junction -Path (Join-Path $b6TrialRoot 'junction') -Target $b6JunctionTarget | Out-Null
$b6PreviousTestRoot = $env:VEGAS_ENCODER_B6_TEST_ROOT
$env:VEGAS_ENCODER_B6_TEST_ROOT = $b6TrialRoot
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
} finally {
  Pop-Location
  $env:VEGAS_ENCODER_B6_TEST_ROOT = $b6PreviousTestRoot
}
Write-Output "B6 preparation PASS; fake children/local files only, no exporter installation, real editor/monitor or VEGAS test. Output: $b6TrialRoot"
