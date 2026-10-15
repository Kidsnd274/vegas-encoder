<# Launch the prepared app or VEGAS with process-local isolated trial data. #>
[CmdletBinding()]
param(
  [ValidateSet('App','Vegas')][string]$Target = 'App',
  [string]$CandidateRoot = (Join-Path $PSScriptRoot '..\build\b6-candidate-0.1.5'),
  [string]$VegasDir = 'C:\Program Files\BorisFX\Vegas Pro 2026'
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $CandidateRoot).Path
$application = Join-Path $root 'app\VegasEncoder.exe'
if (-not (Test-Path -LiteralPath $application -PathType Leaf)) { throw 'Prepare the complete candidate app folder first.' }
if ($Target -eq 'Vegas') {
  if (Get-Process -Name vegas2026 -ErrorAction SilentlyContinue) { throw 'Close VEGAS first so it inherits the isolated trial data root.' }
  $installed = Join-Path $VegasDir 'FileIO Plug-Ins\vegas-encoder\vegas-encoder.dll'
  $candidate = Join-Path $root 'plugin\vegas-encoder.dll'
  if (-not (Test-Path -LiteralPath $installed) -or
      (Get-FileHash -LiteralPath $installed).Hash -ne (Get-FileHash -LiteralPath $candidate).Hash) {
    throw 'The prepared candidate is not installed. Follow docs/B6_TRIAL.md before launching this trial.'
  }
  $application = Join-Path $VegasDir 'vegas2026.exe'
}
$previous = [Environment]::GetEnvironmentVariable('VEGAS_ENCODER_DATA_ROOT','Process')
try {
  $env:VEGAS_ENCODER_DATA_ROOT = Join-Path $root 'data'
  Start-Process -FilePath $application -WorkingDirectory (Split-Path -Parent $application)
  Write-Output "Started $Target with trial data: $env:VEGAS_ENCODER_DATA_ROOT"
} finally {
  [Environment]::SetEnvironmentVariable('VEGAS_ENCODER_DATA_ROOT',$previous,'Process')
}
