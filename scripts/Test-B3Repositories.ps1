#Requires -Version 7.0
[CmdletBinding()]
param([string] $DartPath = 'L:\flutter\bin\cache\dart-sdk\bin\dart.exe')
$ErrorActionPreference = 'Stop'
$b3RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$b3Package = Join-Path $b3RepoRoot 'packages\ve_services'
$b3Output = Join-Path $b3RepoRoot 'build\b3-repositories'
$b3Output = [IO.Path]::GetFullPath($b3Output)
$b3BuildRoot = [IO.Path]::GetFullPath((Join-Path $b3RepoRoot 'build'))
if (-not $b3Output.StartsWith($b3BuildRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'B3 output must stay under this worktree build root.'
}
foreach ($b3CheckedPath in @($b3BuildRoot,$b3Output)) {
  if ((Test-Path -LiteralPath $b3CheckedPath) -and ((Get-Item -LiteralPath $b3CheckedPath).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    throw 'B3 build output must not follow a reparse point.'
  }
}
New-Item -ItemType Directory -Path $b3Output -Force | Out-Null
Push-Location -LiteralPath $b3Package
try {
  & $DartPath analyze --fatal-infos
  if ($LASTEXITCODE -ne 0) { throw 'B3 package analysis failed.' }
  # AOT runs parent and competing writers without simultaneous dart run build
  # hooks trying to replace a loaded .dart_tool/lib/ve_core.dll on Windows.
  $b3Executable = Join-Path $b3Output 'bundle\bin\repositories_test.exe'
  & $DartPath build cli --target test/repositories_test.dart --output $b3Output
  if ($LASTEXITCODE -ne 0) { throw 'B3 repository test compilation failed.' }
  & $b3Executable
  if ($LASTEXITCODE -ne 0) { throw 'B3 repository tests failed.' }
} finally { Pop-Location }
