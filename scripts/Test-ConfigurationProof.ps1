#Requires -Version 7.0
<#
.SYNOPSIS
Checks the separate native configuration proof DLL in the fake host only.
.DESCRIPTION
Native page Apply, an owned-byte save/reload without a new conform, on/off report
effects, repeated renders, cancellation, failure and same-DLL recovery. No installation
or VEGAS launch. Output must be a fresh directory under build/test-results.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string] $OutputDir,
  [string] $FFmpegPath = 'C:\ffmpeg\bin\ffmpeg.exe',
  [string] $PythonPath = 'python'
)
$ErrorActionPreference = 'Stop'
$proofRepo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$proofRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDir)
$proofAllowed = [IO.Path]::GetFullPath((Join-Path $proofRepo 'build\test-results')) + [IO.Path]::DirectorySeparatorChar
if (-not ([IO.Path]::GetFullPath($proofRoot)).StartsWith($proofAllowed, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'OutputDir must be a fresh child of build/test-results.'
}
if (Test-Path -LiteralPath $proofRoot) { throw 'OutputDir exists; choose a fresh directory.' }
$proofDll = Join-Path $proofRepo 'build\configuration-proof\vegas-encoder\vegas-encoder.dll'
$proofHost = Join-Path $proofRepo 'build\fiohost\fiohost.exe'
$proofExe = (Resolve-Path -LiteralPath $FFmpegPath).Path
$proofProbe = Join-Path (Split-Path -Parent $proofExe) 'ffprobe.exe'
foreach ($proofInput in $proofDll,$proofHost,$proofProbe) {
  if (-not (Test-Path -LiteralPath $proofInput -PathType Leaf)) { throw "Missing input: $proofInput" }
}
New-Item -ItemType Directory -Path $proofRoot | Out-Null
$proofTemplate = Join-Path $proofRoot 'host-project.tpl'
& $PythonPath -I (Join-Path $PSScriptRoot 'Make-HostTemplate.py') $proofTemplate
if ($LASTEXITCODE -ne 0) { throw 'Synthetic template generation failed.' }
$proofSourceIni = Get-Content -LiteralPath (Join-Path $proofRepo 'config\vegas-encoder.ini') -Raw

foreach ($proofCase in @(
  @{ name='on'; value=1; extra=@('--renders','2'); encoder=$proofExe; outcomes=@('ok','ok') },
  @{ name='off'; value=0; extra=@('--renders','2'); encoder=$proofExe; outcomes=@('ok','ok') },
  @{ name='cancel'; value=1; extra=@('--cancel-at','45'); encoder=$proofExe; outcomes=@('cancelled') },
  @{ name='encoder-failure'; value=1; extra=@('--expect-failure'); encoder=$proofProbe; outcomes=@('failed') },
  @{ name='cancel-recovery'; value=1; extra=@('--cancel-at','45','--recover','--renders','2'); encoder=$proofExe; outcomes=@('cancelled','ok') },
  @{ name='progress-6-recovery'; value=1; extra=@('--progress-failure-slot','6','--recover','--renders','2'); encoder=$proofExe; outcomes=@('failed','ok'); hresult='0x80070005' },
  @{ name='progress-7-recovery'; value=1; extra=@('--progress-failure-slot','7','--recover','--renders','2'); encoder=$proofExe; outcomes=@('failed','ok'); hresult='0x80070005' },
  @{ name='video-submit-recovery'; value=1; extra=@('--progress-failure-slot','6','--progress-failure-call','2','--recover','--renders','2'); encoder=$proofExe; outcomes=@('failed','ok'); hresult='0x80070005'; frames=45; reads=45 },
  @{ name='audio-submit-recovery'; value=1; extra=@('--progress-failure-slot','7','--progress-failure-after-audio-read','--recover','--renders','2'); encoder=$proofExe; outcomes=@('failed','ok'); hresult='0x80070005'; frames=46; reads=46 },
  @{ name='finalization-recovery'; value=1; extra=@('--progress-failure-slot','6','--progress-failure-at','90','--recover','--renders','2'); encoder=$proofExe; outcomes=@('failed','ok'); hresult='0x80070005'; frames=90; reads=90 },
  @{ name='destination-recovery'; value=1; extra=@('--expect-failure','--recover','--renders','2'); encoder=$proofExe; outcomes=@('failed','ok'); existing=$true }
)) {
  $proofCaseDir = Join-Path $proofRoot $proofCase.name
  $proofPlugin = Join-Path $proofCaseDir 'plugin'
  $proofOutput = Join-Path $proofCaseDir 'output'
  $proofLogs = Join-Path $proofCaseDir 'logs'
  New-Item -ItemType Directory -Path $proofPlugin,$proofOutput,$proofLogs | Out-Null
  Copy-Item -LiteralPath $proofDll -Destination $proofPlugin
  $proofIni = $proofSourceIni
  foreach ($proofPair in @(@('FFmpegPath',$proofCase.encoder),@('ShowEncoderErrors','0'),@('OutputMode','ffmpeg'))) {
    $proofPattern = '(?m)^' + [regex]::Escape($proofPair[0]) + '=.*$'
    if (-not [regex]::IsMatch($proofIni, $proofPattern)) { throw "Missing INI key: $($proofPair[0])" }
    $proofReplacement = $proofPair[0] + '=' + $proofPair[1]
    $proofIni = [regex]::Replace($proofIni, $proofPattern, [Text.RegularExpressions.MatchEvaluator]{ param($match) $proofReplacement })
  }
  $proofIni += "`r`nLogDir=$proofLogs`r`n"
  Set-Content -LiteralPath (Join-Path $proofPlugin 'vegas-encoder.ini') -Value $proofIni -Encoding unicode
  if ($proofCase.existing) {
    [IO.File]::WriteAllBytes((Join-Path $proofOutput 'render-1.mkv'), [byte[]](1,2,3,4,5))
  }
  $proofArgs = @((Join-Path $proofPlugin 'vegas-encoder.dll'),$proofOutput,'--no-wmi','--render',$proofTemplate,
    '--preset','1','--size','320x180','--fps','30','--frames','90','--extension','mkv',
    '--configuration-proof',"$($proofCase.value)") + $proofCase.extra
  & $proofHost @proofArgs 2>&1 | Set-Content -LiteralPath (Join-Path $proofCaseDir 'fiohost.txt') -Encoding utf8
  if ($LASTEXITCODE -ne 0) { throw "Fake host failed: $($proofCase.name)" }
  for ($proofRun = 1; $proofRun -le $proofCase.outcomes.Count; $proofRun++) {
    $proofStatus = $proofCase.outcomes[$proofRun - 1]
    $proofManifest = Join-Path $proofOutput "render-$proofRun.mkv.vegas-encoder.json"
    $proofReport = Get-Content -LiteralPath $proofManifest -Raw | ConvertFrom-Json
    $proofEnabled = $null -ne $proofReport.PSObject.Properties['configuration_proof']
    if ($proofEnabled -ne ($proofCase.value -eq 1) -or $proofReport.render.status -ne $proofStatus -or
        $proofReport.video.locks_outstanding -ne 0) { throw "Wrong setting/render result: $($proofCase.name)" }
    if ($proofReport.plugin.version -ne '0.1.2-config-proof') { throw 'Unexpected DLL version.' }
    if ($proofRun -eq 1 -and $proofCase.hresult -and
        ($proofReport.render.returned_hresult -ne $proofCase.hresult -or $proofReport.render.stop_hresult -ne $proofCase.hresult)) {
      throw "Original progress failure HRESULT was lost: $($proofCase.name)"
    }
    if ($proofRun -eq 1 -and $proofCase.ContainsKey('frames') -and
        ($proofReport.video.frames_written -ne $proofCase.frames -or $proofReport.audio.reads -ne $proofCase.reads)) {
      throw "Failure occurred in the wrong render phase: $($proofCase.name)"
    }
    if ($proofReport.encoder.pid -gt 0 -and (Get-Process -Id $proofReport.encoder.pid -ErrorAction SilentlyContinue)) {
      throw 'Encoder process survived.'
    }
    if ($proofReport.encoder.temporary_output -and (Test-Path -LiteralPath $proofReport.encoder.temporary_output)) {
      throw 'Partial output survived.'
    }
    if ($proofStatus -eq 'ok') {
      & $PythonPath -I (Join-Path $PSScriptRoot 'Check-EncodedRender.py') $proofManifest --ffmpeg $proofExe --ffprobe $proofProbe `
        --out-dir (Join-Path $proofCaseDir "check-$proofRun") --fixture 2>&1 |
        Set-Content -LiteralPath (Join-Path $proofCaseDir "check-$proofRun.txt") -Encoding utf8
      if ($LASTEXITCODE -ne 0) { throw "Decoded fixture failed: $($proofCase.name) render $proofRun" }
    } else {
      if ($proofReport.encoder.published) { throw 'Stopped render published output.' }
      $proofStoppedFile = Join-Path $proofOutput "render-$proofRun.mkv"
      if ($proofCase.existing -and $proofRun -eq 1) {
        if (([IO.File]::ReadAllBytes($proofStoppedFile) -join ',') -ne '1,2,3,4,5') {
          throw 'Failed render changed the existing destination.'
        }
      } elseif (Test-Path -LiteralPath $proofStoppedFile) { throw 'Stopped render left completed output.' }
    }
  }
  Write-Output "PASS configuration proof: $($proofCase.name); page Apply/save/reload and render checks"
}
Write-Output 'CONFIGURATION PROOF PASSED; fake host only; no VEGAS compatibility claim.'
