#Requires -Version 7.0
[CmdletBinding()]
param(
  [string] $PythonPath = 'python',
  [string] $FFmpegPath = 'C:\ffmpeg\bin\ffmpeg.exe',
  [string] $HostPath,
  [switch] $SkipBuild
)
$ErrorActionPreference = 'Stop'
$b5Root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
Push-Location -LiteralPath $b5Root
try {
  if (-not $SkipBuild) {
    & $env:ComSpec /d /c 'scripts\etc\build.cmd "" progress-text-proof'
    if ($LASTEXITCODE -ne 0) { throw 'B5 build failed.' }
  }
  & (Join-Path $b5Root 'build\host-tests\native-progress.exe')
  if ($LASTEXITCODE -ne 0) { throw 'B5 fake progress checks failed.' }
  if ($HostPath) {
    & $PythonPath -I (Join-Path $b5Root 'scripts\etc\Inspect-VegasProgress.py') --host $HostPath
    if ($LASTEXITCODE -ne 0) { throw 'B5 static host bytes are unqualified.' }
  }
  $b5Run = Join-Path $b5Root ('build\test-results\b5-' + [guid]::NewGuid().ToString('N').Substring(0,8))
  & (Join-Path $b5Root 'scripts\etc\Prepare-B5StatusLine.ps1') -OutputDir $b5Run -FFmpegPath $FFmpegPath
  $b5Template = Join-Path $b5Run 'host.tpl'
  & $PythonPath -I (Join-Path $b5Root 'scripts\etc\Make-HostTemplate.py') $b5Template
  if ($LASTEXITCODE -ne 0) { throw 'B5 synthetic template generation failed.' }
  foreach ($b5Mode in 0,4,3) {
    $b5Case = Join-Path $b5Run "mode-$b5Mode"
    $b5Logs = Join-Path $b5Case 'logs'
    $b5Output = Join-Path $b5Case 'output'
    New-Item -ItemType Directory -Path $b5Logs,$b5Output | Out-Null
    $b5IniFile = Join-Path $b5Case 'vegas-encoder.ini'
    $b5Ini = Get-Content -Raw -LiteralPath $b5IniFile
    $b5Ini = [regex]::Replace($b5Ini, '(?m)^ShowEncoderErrors=.*$', 'ShowEncoderErrors=0')
    ($b5Ini + "`r`nLogDir=$b5Logs`r`n") | Set-Content -LiteralPath $b5IniFile -Encoding unicode
    & (Join-Path $b5Root 'build\fiohost\fiohost.exe') (Join-Path $b5Case 'vegas-encoder.dll') $b5Output `
      --no-wmi --render $b5Template --preset 1 --size 320x180 --fps 30 --frames 90 --extension mkv |
      Set-Content -LiteralPath (Join-Path $b5Case 'fiohost.txt') -Encoding utf8
    if ($LASTEXITCODE -ne 0) { throw "B5 fake-host mode $b5Mode failed." }
    $b5Log = (Get-ChildItem -LiteralPath $b5Logs -Filter '*.log' | Get-Content -Raw) -join "`n"
    if ($b5Log -notmatch 'B5 progress-text calls=0 .*guardFailed=0' -or
        ($b5Mode -ne 0 -and $b5Log -notmatch 'exactTarget=0')) {
      throw 'B5 runtime gate must reject fiohost and make zero text calls.'
    }
    & $PythonPath -I (Join-Path $b5Root 'scripts\etc\Check-EncodedRender.py') `
      (Join-Path $b5Output 'render-1.mkv.vegas-encoder.json') --ffmpeg $FFmpegPath `
      --ffprobe (Join-Path (Split-Path -Parent $FFmpegPath) 'ffprobe.exe') --out-dir (Join-Path $b5Case 'decoded') --fixture |
      Set-Content -LiteralPath (Join-Path $b5Case 'decode.txt') -Encoding utf8
    if ($LASTEXITCODE -ne 0) { throw 'B5 fake-host output decode failed.' }
  }
  # The test INIs were deliberately edited above. These are test outputs, not
  # owner install candidates; remove the now-obsolete review manifest only.
  Remove-Item -LiteralPath (Join-Path $b5Run 'review.json')
  Write-Output "B5 PASS: fake progress + three rejected fake-host probes/full decodes; $b5Run"
} finally { Pop-Location }
