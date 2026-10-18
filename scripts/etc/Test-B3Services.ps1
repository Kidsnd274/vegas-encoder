#Requires -Version 7.0
[CmdletBinding()]
param([string] $DartPath = 'L:\flutter\bin\cache\dart-sdk\bin\dart.exe')
$ErrorActionPreference = 'Stop'
$b3ServicesRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$b3ServicesBuild = [IO.Path]::GetFullPath((Join-Path $b3ServicesRoot 'build'))
$b3ServicesOutput = [IO.Path]::GetFullPath((Join-Path $b3ServicesBuild 'b3-services'))
if (-not $b3ServicesOutput.StartsWith($b3ServicesBuild + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe B3 services output.' }
foreach ($b3CheckedPath in @($b3ServicesBuild,$b3ServicesOutput)) {
  if ((Test-Path -LiteralPath $b3CheckedPath) -and ((Get-Item -LiteralPath $b3CheckedPath).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'B3 output cannot follow a reparse point.' }
}
Push-Location -LiteralPath (Join-Path $b3ServicesRoot 'packages\ve_services')
try {
  & $DartPath analyze --fatal-infos
  if ($LASTEXITCODE -ne 0) { throw 'B3 services analysis failed.' }
  & $DartPath build cli --target test/ffmpeg_services_test.dart --output $b3ServicesOutput
  if ($LASTEXITCODE -ne 0) { throw 'B3 service test bundle failed.' }
  & (Join-Path $b3ServicesOutput 'bundle\bin\ffmpeg_services_test.exe')
  if ($LASTEXITCODE -ne 0) { throw 'B3 service tests failed.' }
} finally { Pop-Location }
