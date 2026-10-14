#Requires -Version 7.0
<#
.SYNOPSIS
Stages off/slot4/slot3 B5 candidates for review, without touching an installation.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string] $OutputDir,
  [Parameter(Mandatory)][string] $FFmpegPath,
  [string] $BuildDir = (Join-Path $PSScriptRoot '..\build\progress-text-proof\vegas-encoder')
)
$ErrorActionPreference = 'Stop'
$b5Repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$b5BuildRoot = [IO.Path]::GetFullPath((Join-Path $b5Repo 'build'))
$b5Out = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDir)
if (-not $b5Out.StartsWith($b5BuildRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
  throw 'B5 candidates must stay in this worktree build directory.'
}
if (Test-Path -LiteralPath $b5Out) { throw 'OutputDir exists; use a fresh directory.' }
# Do not stage through junctions, even if their lexical path is below build/.
for ($b5Cursor = $b5Out; $b5Cursor; $b5Cursor = [IO.Path]::GetDirectoryName($b5Cursor)) {
  if ((Test-Path -LiteralPath $b5Cursor) -and
      ((Get-Item -LiteralPath $b5Cursor).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    throw "B5 output must not follow a reparse point: $b5Cursor"
  }
}
$b5Exe = (Resolve-Path -LiteralPath $FFmpegPath).Path
if ($b5Exe -match '[\r\n]' -or -not (Test-Path -LiteralPath $b5Exe -PathType Leaf)) {
  throw 'Supply an existing single-line FFmpeg executable path.'
}
$b5Source = (Resolve-Path -LiteralPath $BuildDir).Path
foreach ($b5Name in 'vegas-encoder.dll','vegas-encoder.pdb','vegas-encoder.ini') {
  if (-not (Test-Path -LiteralPath (Join-Path $b5Source $b5Name) -PathType Leaf)) {
    throw "Missing B5 build file: $b5Name"
  }
}
$b5Ini = Get-Content -Raw -LiteralPath (Join-Path $b5Source 'vegas-encoder.ini')
if (-not [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes(
    (Join-Path $b5Source 'vegas-encoder.dll'))).Contains('0.1.3-progress-text-proof')) {
  throw 'BuildDir must contain the B5 progress-text-proof DLL.'
}
if (-not [regex]::IsMatch($b5Ini, '(?m)^FFmpegPath=.*$')) { throw 'Missing FFmpegPath INI key.' }
$b5Ini = [regex]::Replace($b5Ini, '(?m)^FFmpegPath=.*$',
  [Text.RegularExpressions.MatchEvaluator]{ param($match) "FFmpegPath=$b5Exe" })
$b5Ini = [regex]::Replace($b5Ini, '(?m)^B5ProgressText=.*\r?\n?', '')
New-Item -ItemType Directory -Path $b5Out | Out-Null
$b5Manifest = foreach ($b5Mode in 0,4,3) {
  $b5Case = Join-Path $b5Out "mode-$b5Mode"
  New-Item -ItemType Directory -Path $b5Case | Out-Null
  foreach ($b5Name in 'vegas-encoder.dll','vegas-encoder.pdb') {
    Copy-Item -LiteralPath (Join-Path $b5Source $b5Name) -Destination $b5Case
  }
  ($b5Ini.TrimEnd() + "`r`n; B5 opt-in test: 0 off, 4 text only, 3 initialize once.`r`nB5ProgressText=$b5Mode`r`n") |
    Set-Content -LiteralPath (Join-Path $b5Case 'vegas-encoder.ini') -Encoding unicode
  $b5Files = foreach ($b5Name in 'vegas-encoder.dll','vegas-encoder.pdb','vegas-encoder.ini') {
    $b5File = Join-Path $b5Case $b5Name
    @{ name=$b5Name; sha256=(Get-FileHash -LiteralPath $b5File -Algorithm SHA256).Hash }
  }
  @{ mode=$b5Mode; buildDir=$b5Case; files=@($b5Files) }
}
@{ schema='vegas-encoder-b5-review/1'; version='0.1.3-progress-text-proof';
   installed=$false; candidates=@($b5Manifest); checklist='docs/NATIVE_PROGRESS.md' } |
  ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $b5Out 'review.json') -Encoding utf8
Write-Output "B5 review candidates staged; nothing installed: $b5Out"
