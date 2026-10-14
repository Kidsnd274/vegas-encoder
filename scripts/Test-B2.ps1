#Requires -Version 7.0
[CmdletBinding()]
param(
  [string] $DartPath = 'L:\flutter\bin\cache\dart-sdk\bin\dart.exe',
  [string] $PythonPath = 'python',
  [string] $FFmpegPath = 'C:\ffmpeg\bin\ffmpeg.exe',
  [string] $VcvarsPath = '',
  [switch] $Asan,
  [switch] $Aot,
  [switch] $Encoder
)
$ErrorActionPreference = 'Stop'
$veB2Root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
function Invoke-B2Check {
  param([string] $Exe,[string[]] $Arguments)
  & $Exe @Arguments
  if ($LASTEXITCODE -ne 0) { throw "B2 check failed: $Exe (exit $LASTEXITCODE)" }
}
Push-Location -LiteralPath $veB2Root
try {
  Invoke-B2Check $PythonPath @('-I','scripts/Generate-CoreData.py','--check')
  Invoke-B2Check 'cmd.exe' @('/d','/c',(Join-Path $PSScriptRoot 'build-core.cmd'),$VcvarsPath)
  Invoke-B2Check $PythonPath @('-I','scripts/Generate-CoreGoldens.py','--check')
  Invoke-B2Check $PythonPath @('-I','scripts/Test-B1Data.py')
  Invoke-B2Check 'cmd.exe' @('/d','/c',(Join-Path $PSScriptRoot 'Test-CoreNative.cmd'),$VcvarsPath)
  if ($Asan) {
    # Explicit quotes retain the empty vcvars argument through cmd.exe.
    $veAsanCommand = '"' + (Join-Path $PSScriptRoot 'Test-CoreNative.cmd') + '" "' + $VcvarsPath + '" asan'
    Invoke-B2Check 'cmd.exe' @('/d','/c',$veAsanCommand)
  }
  Push-Location -LiteralPath (Join-Path $veB2Root 'packages/ve_core')
  try {
    Invoke-B2Check $DartPath @('pub','get','--offline')
    Invoke-B2Check $DartPath @('analyze','--fatal-infos')
    Invoke-B2Check $DartPath @('run','test/native_test.dart')
    Invoke-B2Check $DartPath @('run','test/native_test.dart',(Join-Path $veB2Root 'build/core/ve_core.dll'))
    if ($Aot) {
      $veAotDir = Join-Path $veB2Root 'build/core-aot'
      # dart build replaces its output directory. Verify the absolute target is
      # confined to this worktree's intended build root, without a junction.
      $veAotDir = [IO.Path]::GetFullPath($veAotDir)
      $veBuildRoot = [IO.Path]::GetFullPath((Join-Path $veB2Root 'build'))
      if (-not $veAotDir.StartsWith($veBuildRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'AOT output must stay under this worktree build root.'
      }
      foreach ($veCheckedDir in @($veBuildRoot,$veAotDir)) {
        if ((Test-Path -LiteralPath $veCheckedDir) -and ((Get-Item -LiteralPath $veCheckedDir).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
          throw 'AOT output must not follow a reparse point.'
        }
      }
      New-Item -ItemType Directory -Path $veAotDir -Force | Out-Null
      $veAotExe = Join-Path $veAotDir 'bundle/bin/native_test.exe'
      Invoke-B2Check $DartPath @('build','cli','--target','test/native_test.dart','--output',$veAotDir)
      Invoke-B2Check $veAotExe @()
    }
    if ($Encoder) {
      $veEncoderDir = Join-Path $veB2Root ('build/test-results/core-encoder-' + [guid]::NewGuid().ToString('N'))
      Invoke-B2Check $DartPath @('run','tool/encoder_plans.dart',$veEncoderDir,$FFmpegPath)
      Invoke-B2Check $PythonPath @('-I',(Join-Path $PSScriptRoot 'Test-CoreEncoder.py'),$veEncoderDir,$FFmpegPath)
    }
  } finally { Pop-Location }
} finally { Pop-Location }
Write-Host 'B2 CORE PASSED (portable C++, real Dart FFI, offline only; native VEGAS gates unchanged).'
