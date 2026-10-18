#Requires -Version 7.0
<#
.SYNOPSIS
Runs the fixed-profile Vegas Encoder suite in fiohost without modifying VEGAS.
.DESCRIPTION
Build Vegas Encoder and fiohost first. Requires Python 3.9 or newer and a selected
FFmpeg with FFprobe beside it. A synthetic project template is generated from
authored source; no investigation payload is required. Each case gets its own
DLL/INI, logs and outputs. Use a fresh evidence directory for every invocation.
-Include1080p adds a 90-frame 1080p decoded check (about 560 MB decoded video).
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string] $EvidenceDir,
  [string] $FFmpegPath = 'C:\ffmpeg\bin\ffmpeg.exe',
  [string] $PythonPath = 'python',
  [switch] $Include1080p
)
$ErrorActionPreference = 'Stop'
$testRepo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$testDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($EvidenceDir)
if (Test-Path -LiteralPath $testDir) { throw 'EvidenceDir exists; use a fresh directory.' }
$testFfmpeg = (Resolve-Path -LiteralPath $FFmpegPath).Path
$testFfprobe = Join-Path (Split-Path -Parent $testFfmpeg) 'ffprobe.exe'
$testHost = Join-Path $testRepo 'build\fiohost\fiohost.exe'
$testDll = Join-Path $testRepo 'build\vegas-encoder\vegas-encoder.dll'
$testIniSource = Join-Path $testRepo 'config\vegas-encoder.ini'
$testChecker = Join-Path $testRepo 'scripts\etc\Check-EncodedRender.py'
$testRawChecker = Join-Path $testRepo 'scripts\etc\Check-RawRender.py'
$testTemplateMaker = Join-Path $testRepo 'scripts\etc\Make-HostTemplate.py'
foreach ($inputFile in $testFfmpeg,$testFfprobe,$testHost,$testDll,$testIniSource,$testChecker,$testRawChecker,$testTemplateMaker) {
  if (-not (Test-Path -LiteralPath $inputFile -PathType Leaf)) { throw "Required input missing: $inputFile" }
}
$testPython = (Get-Command -Name $PythonPath -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
$testIni = Get-Content -Raw -LiteralPath $testIniSource
$testCommands = [Collections.Generic.List[object]]::new()
New-Item -ItemType Directory -Path $testDir | Out-Null
$testTpl = Join-Path $testDir 'host-project.tpl'

function Set-TestIniValue {
  param([string] $Text, [string] $Key, [string] $Value)
  $pattern = '(?m)^' + [regex]::Escape($Key) + '=.*$'
  if (-not [regex]::IsMatch($Text, $pattern)) { throw "Missing INI key: $Key" }
  return [regex]::Replace($Text, $pattern, [Text.RegularExpressions.MatchEvaluator]{ param($match) "$Key=$Value" })
}

function Invoke-TestHost {
  param([string] $Name, [string[]] $Extra = @(), [string] $Mode = 'ffmpeg', [string] $Exe = $testFfmpeg,
        [switch] $ExistingDestination)
  $caseDir = Join-Path $testDir $Name
  $casePlugin = Join-Path $caseDir 'plugin'
  $caseOutput = Join-Path $caseDir 'output'
  $caseLogs = Join-Path $caseDir 'logs'
  New-Item -ItemType Directory -Path $casePlugin,$caseOutput,$caseLogs | Out-Null
  Copy-Item -LiteralPath $testDll -Destination $casePlugin
  $caseIni = Set-TestIniValue $testIni 'OutputMode' $Mode
  $caseIni = Set-TestIniValue $caseIni 'FFmpegPath' $Exe
  $caseIni = Set-TestIniValue $caseIni 'ShowEncoderErrors' '0'
  # Explicit case-local logs keep offline tests out of the user's app data.
  if ([regex]::IsMatch($caseIni, '(?m)^LogDir=')) {
    $caseIni = Set-TestIniValue $caseIni 'LogDir' $caseLogs
  } else {
    $caseIni += "`r`nLogDir=$caseLogs`r`n"
  }
  $caseIni | Set-Content -LiteralPath (Join-Path $casePlugin 'vegas-encoder.ini') -Encoding unicode
  if ($ExistingDestination) {
    [IO.File]::WriteAllBytes((Join-Path $caseOutput 'render-1.mkv'), [byte[]](1,2,3,4,5))
  }
  $extension = if ($Mode -eq 'raw') { 'ffdiag' } else { 'mkv' }
  $caseArgs = @((Join-Path $casePlugin 'vegas-encoder.dll'),$caseOutput,'--no-wmi','--render',$testTpl,
    '--preset','1','--size','320x180','--fps','30','--frames','90','--extension',$extension) + $Extra
  $testCommands.Add(@{ executable=$testHost; arguments=$caseArgs })
  & $testHost @caseArgs 2>&1 | Set-Content -LiteralPath (Join-Path $caseDir 'fiohost.txt') -Encoding utf8
  if ($LASTEXITCODE -ne 0) { throw "fiohost $Name failed; see $caseDir\fiohost.txt" }
  return $caseDir
}

function Test-CompletedOutput {
  param([string] $CaseDir, [int] $Run = 1, [string] $Reference = '')
  $manifest = Join-Path $CaseDir "output\render-$Run.mkv.vegas-encoder.json"
  $checkDir = Join-Path $CaseDir "check-$Run"
  $checkArgs = @('-I',$testChecker,$manifest,'--ffmpeg',$testFfmpeg,'--ffprobe',$testFfprobe,
    '--out-dir',$checkDir,'--fixture')
  if ($Reference) { $checkArgs += @('--reference-manifest',$Reference) }
  $testCommands.Add(@{ executable=$testPython; arguments=$checkArgs })
  & $testPython @checkArgs 2>&1 | Set-Content -LiteralPath (Join-Path $CaseDir "check-$Run.txt") -Encoding utf8
  if ($LASTEXITCODE -ne 0) { throw "Decoded check failed; see $CaseDir\check-$Run.txt" }
  Write-Output "PASS decoded: $CaseDir render $Run"
}

function Test-StoppedOutput {
  param([string] $CaseDir, [string] $Status, [long] $Frames = -1)
  $caseManifest = Get-Content -Raw -LiteralPath (Join-Path $CaseDir 'output\render-1.mkv.vegas-encoder.json') | ConvertFrom-Json
  if ($caseManifest.render.status -ne $Status -or $caseManifest.encoder.published -or
      $caseManifest.video.locks_outstanding -ne 0 -or
      (Test-Path -LiteralPath (Join-Path $CaseDir 'output\render-1.mkv'))) { throw "Invalid stopped outcome: $CaseDir" }
  if ($Frames -ge 0 -and $caseManifest.video.frames_written -ne $Frames) { throw "Wrong stopped count: $CaseDir" }
  if ($caseManifest.encoder.pid -gt 0 -and (Get-Process -Id $caseManifest.encoder.pid -ErrorAction SilentlyContinue)) {
    throw "Encoder process survived: $CaseDir"
  }
  if ($caseManifest.encoder.temporary_output -and (Test-Path -LiteralPath $caseManifest.encoder.temporary_output)) {
    throw "Partial output survived: $CaseDir"
  }
  Write-Output "PASS cleanup: $CaseDir ($Status)"
}

try {
  $templateArgs = @('-I',$testTemplateMaker,$testTpl)
  $testCommands.Add(@{ executable=$testPython; arguments=$templateArgs })
  & $testPython @templateArgs 2>&1 | Set-Content -LiteralPath (Join-Path $testDir 'template-generation.txt') -Encoding utf8
  if ($LASTEXITCODE -ne 0) { throw 'Synthetic template generation failed' }
  $identities = foreach ($inputFile in $testFfmpeg,$testFfprobe,$testHost,$testDll,$testIniSource,$testChecker,$testRawChecker,$testTemplateMaker,$testTpl) {
    $item = Get-Item -LiteralPath $inputFile
    [pscustomobject]@{ path=$item.FullName; bytes=$item.Length; sha256=(Get-FileHash -LiteralPath $inputFile -Algorithm SHA256).Hash }
  }
  $identities | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $testDir 'identities.json') -Encoding utf8
  & $testFfmpeg -version 2>&1 | Set-Content -LiteralPath (Join-Path $testDir 'ffmpeg-version.txt') -Encoding utf8
  if ($LASTEXITCODE -ne 0) { throw 'FFmpeg version check failed' }
  & $testFfprobe -version 2>&1 | Set-Content -LiteralPath (Join-Path $testDir 'ffprobe-version.txt') -Encoding utf8
  if ($LASTEXITCODE -ne 0) { throw 'FFprobe version check failed' }
  & $testPython --version 2>&1 | Set-Content -LiteralPath (Join-Path $testDir 'python-version.txt') -Encoding utf8
  if ($LASTEXITCODE -ne 0) { throw 'Python version check failed' }
  $rawCase = Invoke-TestHost -Name raw-baseline -Mode raw
  $rawManifest = Join-Path $rawCase 'output\render-1.ffdiag'
  $rawArgs = @('-I',$testRawChecker,$rawManifest,'--fixture')
  $testCommands.Add(@{ executable=$testPython; arguments=$rawArgs })
  & $testPython @rawArgs 2>&1 | Set-Content -LiteralPath (Join-Path $rawCase 'raw-check.txt') -Encoding utf8
  if ($LASTEXITCODE -ne 0) { throw 'Raw regression failed' }
  $repeatCase = Invoke-TestHost -Name repeat -Extra @('--renders','3')
  1..3 | ForEach-Object { Test-CompletedOutput -CaseDir $repeatCase -Run $_ -Reference $rawManifest }
  $fractional = Invoke-TestHost -Name fractional -Extra @('--fps','29.973071068961481','--delivered-fps','29.97002997002997')
  Test-CompletedOutput -CaseDir $fractional
  $short = Invoke-TestHost -Name short-read -Extra @('--short-read','511')
  Test-CompletedOutput -CaseDir $short -Reference $rawManifest
  $videoOnly = Invoke-TestHost -Name video-only -Extra @('--video-only')
  Test-CompletedOutput -CaseDir $videoOnly
  foreach ($cancelFrame in 0,45,90) {
    $cancelCase = Invoke-TestHost -Name "cancel-$cancelFrame" -Extra @('--cancel-at',"$cancelFrame")
    Test-StoppedOutput -CaseDir $cancelCase -Status cancelled -Frames $cancelFrame
  }
  $missing = Invoke-TestHost -Name missing-exe -Extra @('--expect-failure') -Exe (Join-Path $testDir 'missing-encoder.exe')
  Test-StoppedOutput -CaseDir $missing -Status failed
  $badRate = Invoke-TestHost -Name bad-rate -Extra @('--delivered-fps','29.973071068961481','--expect-failure')
  Test-StoppedOutput -CaseDir $badRate -Status failed
  $early = Invoke-TestHost -Name early-exit -Extra @('--expect-failure') -Exe $testFfprobe
  Test-StoppedOutput -CaseDir $early -Status failed
  $existing = Invoke-TestHost -Name existing-destination -Extra @('--expect-failure') -ExistingDestination
  $existingBytes = [IO.File]::ReadAllBytes((Join-Path $existing 'output\render-1.mkv'))
  if (($existingBytes -join ',') -ne '1,2,3,4,5') { throw 'Existing destination changed' }
  $existingResult = Get-Content -Raw -LiteralPath (Join-Path $existing 'output\render-1.mkv.vegas-encoder.json') | ConvertFrom-Json
  if ($existingResult.render.status -ne 'failed' -or $existingResult.encoder.published) { throw 'Overwrite refusal failed' }
  if ($existingResult.video.locks_outstanding -ne 0 -or
      ($existingResult.encoder.pid -gt 0 -and (Get-Process -Id $existingResult.encoder.pid -ErrorAction SilentlyContinue)) -or
      ($existingResult.encoder.temporary_output -and (Test-Path -LiteralPath $existingResult.encoder.temporary_output))) {
    throw 'Existing-destination failure left a lock, child or partial output'
  }
  Write-Output 'PASS destination: existing file preserved'
  $unicode = Invoke-TestHost -Name 'space Unicode 测试'
  Test-CompletedOutput -CaseDir $unicode -Reference $rawManifest
  if ($Include1080p) {
    $hd = Invoke-TestHost -Name 1080p -Extra @('--size','1920x1080')
    Test-CompletedOutput -CaseDir $hd
  }

  # The checker must reject a falsified submitted count.
  $badManifest = Get-Content -Raw -LiteralPath (Join-Path $repeatCase 'output\render-1.mkv.vegas-encoder.json') | ConvertFrom-Json
  $badManifest.video.frames_written = 89
  $badPath = Join-Path $repeatCase 'output\bad-count.json'
  $badManifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $badPath -Encoding utf8
  $negativeArgs = @('-I',$testChecker,$badPath,'--ffmpeg',$testFfmpeg,'--ffprobe',$testFfprobe,
    '--out-dir',(Join-Path $repeatCase 'negative-count'))
  $testCommands.Add(@{ executable=$testPython; arguments=$negativeArgs })
  & $testPython @negativeArgs 2>&1 | Set-Content -LiteralPath (Join-Path $repeatCase 'negative-count.txt') -Encoding utf8
  if ($LASTEXITCODE -ne 1) { throw 'Checker did not reject the wrong count' }
  Write-Output 'PASS checker negative: wrong frame count rejected'
  Write-Output 'VEGAS ENCODER SUITE PASSED (fiohost only; real VEGAS qualification is separate)'
} finally {
  $testCommands | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $testDir 'commands.json') -Encoding utf8
}
exit 0  # the intentional checker failure must not become this script's exit status
