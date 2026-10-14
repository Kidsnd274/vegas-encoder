#Requires -Version 7.0
[CmdletBinding()]
param(
  [string] $DartPath = 'L:\flutter\bin\cache\dart-sdk\bin\dart.exe',
  [string] $CachedViewRoot,
  [string[]] $FFmpegPaths = @('C:\ffmpeg\bin\ffmpeg.exe')
)
$ErrorActionPreference = 'Stop'
$b3RuntimeRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$b3RuntimeBuild = [IO.Path]::GetFullPath((Join-Path $b3RuntimeRoot 'build'))
$b3RuntimeBundleName = if ($CachedViewRoot) { 'b3-views' } else { 'b3-runtime' }
$b3RuntimeOutput = [IO.Path]::GetFullPath((Join-Path $b3RuntimeBuild $b3RuntimeBundleName))
if (-not $b3RuntimeOutput.StartsWith($b3RuntimeBuild + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe B3 runtime output.' }
foreach ($b3CheckedPath in @($b3RuntimeBuild,$b3RuntimeOutput)) {
  if ((Test-Path -LiteralPath $b3CheckedPath) -and ((Get-Item -LiteralPath $b3CheckedPath).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Runtime output cannot follow a reparse point.' }
}
if ($CachedViewRoot) {
  $CachedViewRoot = (Resolve-Path -LiteralPath $CachedViewRoot).Path
  $b3RuntimeResults = [IO.Path]::GetFullPath((Join-Path $b3RuntimeBuild 'test-results'))
  if (-not $CachedViewRoot.StartsWith($b3RuntimeResults + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Cached view data must stay under this worktree build/test-results.' }
  foreach ($b3CachedCheckedPath in @($b3RuntimeResults,$CachedViewRoot)) {
    if ((Get-Item -LiteralPath $b3CachedCheckedPath).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Cached view data cannot follow a reparse point.' }
  }
} else {
  foreach ($b3EncoderPath in $FFmpegPaths) { if (-not (Test-Path -LiteralPath $b3EncoderPath -PathType Leaf)) { throw "Supplied encoder missing: $b3EncoderPath" } }
}
Push-Location -LiteralPath (Join-Path $b3RuntimeRoot 'packages\ve_services')
try {
  $b3RuntimeTarget = if ($CachedViewRoot) { 'capability_views_test' } else { 'ffmpeg_runtime_test' }
  & $DartPath build cli --target "test/$b3RuntimeTarget.dart" --output $b3RuntimeOutput
  if ($LASTEXITCODE -ne 0) { throw 'B3 runtime bundle failed.' }
  [string[]] $b3RuntimeArguments = if ($CachedViewRoot) { $CachedViewRoot } else { $FFmpegPaths }
  & (Join-Path $b3RuntimeOutput "bundle\bin\$b3RuntimeTarget.exe") @b3RuntimeArguments
  if ($LASTEXITCODE -ne 0) { throw 'B3 real FFmpeg checks failed.' }
} finally { Pop-Location }
