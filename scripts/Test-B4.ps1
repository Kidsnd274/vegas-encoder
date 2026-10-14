#Requires -Version 7.0
[CmdletBinding()]
param(
  [string] $DartPath = 'L:\flutter\bin\cache\dart-sdk\bin\dart.exe',
  [string[]] $FFmpegPaths = @('C:\ffmpeg\bin\ffmpeg.exe'),
  [string] $VcVars,
  [switch] $Asan
)
$ErrorActionPreference = 'Stop'
$b4Root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$b4Build = [IO.Path]::GetFullPath((Join-Path $b4Root 'build'))
$b4Run = Join-Path $b4Build ('test-results\b4-' + [guid]::NewGuid().ToString('N').Substring(0,8))
foreach ($b4Path in @($b4Build,(Join-Path $b4Build 'test-results'),(Join-Path $b4Build 'b4-tests'),(Join-Path $b4Build 'b4-tests-asan'),(Join-Path $b4Build 'b4-records'))) {
  if ((Test-Path -LiteralPath $b4Path) -and ((Get-Item -LiteralPath $b4Path).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'B4 output must not follow a reparse point.' }
}
foreach ($b4Exe in $FFmpegPaths) { if (-not (Test-Path -LiteralPath $b4Exe -PathType Leaf)) { throw "Supplied FFmpeg missing: $b4Exe" } }
New-Item -ItemType Directory -Path $b4Run | Out-Null
Push-Location -LiteralPath $b4Root
try {
  & $env:ComSpec /d /c scripts\build-core.cmd $VcVars
  if ($LASTEXITCODE -ne 0) { throw 'B4 native core build failed.' }
  & $env:ComSpec /d /c scripts\Build-B4.cmd $VcVars
  if ($LASTEXITCODE -ne 0) { throw 'B4 native engine build failed.' }
  Push-Location -LiteralPath (Join-Path $b4Root 'packages\ve_services')
  try {
    & $DartPath analyze --fatal-infos test/engine_records_test.dart
    if ($LASTEXITCODE -ne 0) { throw 'B4 reader test analysis failed.' }
    & $DartPath build cli --target test/engine_records_test.dart --output ../../build/b4-records
    if ($LASTEXITCODE -ne 0) { throw 'B4 reader test build failed.' }
  } finally { Pop-Location }
  $b4Reader = Join-Path $b4Build 'b4-records\bundle\bin\engine_records_test.exe'
  $b4Services = Join-Path $b4Run 'services'
  & $b4Reader --identify $b4Services @FFmpegPaths
  if ($LASTEXITCODE -ne 0) { throw 'B4 B3 installation snapshots failed.' }
  # Predeclared budgets: 64 MiB video/2 MiB audio in-flight queues, parent
  # working-set growth <160 MiB, caller polling <250 ms, blocked cancellation
  # <3 s, each recipe <15 s. Fake-child slowdown is deliberate, not throughput.
  $b4Engine = Join-Path $b4Run 'engine'
  & (Join-Path $b4Build 'b4-tests\recipe-jobs.exe') (Join-Path $b4Root 'schema\fixtures\b0\core-and-services.json') $b4Engine --snapshots (Join-Path $b4Services 'installations.json') @FFmpegPaths
  if ($LASTEXITCODE -ne 0) { throw 'B4 fake-host recipe qualification failed.' }
  & $b4Reader $b4Engine
  if ($LASTEXITCODE -ne 0) { throw 'B4 native C5/C6 reader qualification failed.' }
  if ($Asan) {
    $b4AsanEngine = Join-Path $b4Run 'engine-asan'
    # Build and execute in the same vcvars environment, which supplies MSVC's
    # sanitizer DLL on PATH. The runtime is never installed/copied into a release.
    $b4AsanBuild = 'scripts\Build-B4.cmd "' + $VcVars + '" asan "' + (Join-Path $b4Root 'schema\fixtures\b0\core-and-services.json') + '" "' + $b4AsanEngine + '" "' + (Join-Path $b4Services 'installations.json') + '" "' + $FFmpegPaths[0] + '"'
    & $env:ComSpec /d /c $b4AsanBuild
    if ($LASTEXITCODE -ne 0) { throw 'B4 ASan build/qualification failed.' }
    & $b4Reader $b4AsanEngine
    if ($LASTEXITCODE -ne 0) { throw 'B4 ASan C5/C6 reader qualification failed.' }
  }
  Write-Host "B4 PASS: $b4Run"
} finally { Pop-Location }
