#Requires -Version 7.0
<# Focused packaging checks. Reads the prepared bundle; writes only fresh fake trees. #>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$BundleDir)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$bundle = (Resolve-Path -LiteralPath $BundleDir).Path
$out = Join-Path $repo ('build\test-results\b7-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $out | Out-Null
$checks = 0
function Check([bool]$Value, [string]$Message) {
  if (-not $Value) { throw $Message }
  $script:checks++
}
function Reject([scriptblock]$Action, [string]$Pattern) {
  $caught = $null
  try { & $Action | Out-Null } catch { $caught = $_.Exception.Message }
  Check ($caught -and $caught -match $Pattern) "Expected refusal matching '$Pattern', got '$caught'"
}
$manifest = Get-Content -LiteralPath "$bundle\installer-inputs.json" -Raw | ConvertFrom-Json
Check ($manifest.numericFileVersion -eq '0.1.7.1' -and -not $manifest.installedByPreparation -and -not $manifest.releaseQualified) 'Matched version and pending gates required'
foreach ($record in $manifest.files) {
  $path = [IO.Path]::GetFullPath((Join-Path $bundle $record.file))
  Check ($path.StartsWith($bundle + '\', [StringComparison]::OrdinalIgnoreCase)) 'Manifest path escapes bundle'
  Check ((Get-Item -LiteralPath $path).Length -eq $record.bytes -and (Get-FileHash -LiteralPath $path).Hash -eq $record.sha256) "Changed bundle input: $path"
}
$actual = @(Get-ChildItem -LiteralPath "$bundle\app","$bundle\plugin","$bundle\installer" -Recurse -File)
foreach ($license in 've_core.txt','ve_services.txt','InstrumentSans-OFL.txt','JetBrainsMono-OFL.txt') {
  Check (Test-Path -LiteralPath "$bundle\app\licenses\$license") "Required license notice: $license"
}
Check ($actual.Count -eq $manifest.files.Count) 'Manifest must cover every packaged file'
Check ((Get-Content -LiteralPath "$bundle\installer\vegas-encoder.ini.in" -Raw) -match 'AppPath=\{app\}\\VegasEncoder.exe' ) 'Installer must render its selected application path'
Check ((Get-Content -LiteralPath "$bundle\plugin\vegas-encoder.ini" -Raw).Contains("AppPath=$bundle\app\VegasEncoder.exe")) 'Trial must use its own app'
$prepare = Join-Path $PSScriptRoot 'Prepare-B7.ps1'
Reject { & $prepare -OutputDir $bundle } 'exists'
$missing = Join-Path $out 'missing-runtime'
New-Item -ItemType Directory -Path $missing | Out-Null
Reject { & $prepare -OutputDir "$out\bad-missing" -AppDir $missing } 'Missing runtime'
Check (-not (Test-Path -LiteralPath "$out\bad-missing")) 'Refused bundle must not be created'
Reject { & $prepare -OutputDir (Join-Path $repo 'outside-build') } 'inside this worktree build'
# A fake target is just the app's PE copied under a VEGAS-shaped filename; never loaded.
$fakeTarget = Join-Path $out 'fake-target'
New-Item -ItemType Directory -Path $fakeTarget | Out-Null
Copy-Item -LiteralPath "$bundle\app\VegasEncoder.exe" -Destination "$fakeTarget\vegas999.exe"
Copy-Item -LiteralPath "$bundle\app\VegasEncoder.exe" -Destination "$fakeTarget\VegasCapture.exe"
Set-Content -LiteralPath "$fakeTarget\vegas000.exe" -Value 'invalid PE marker; never loaded'
$targets = @(& (Join-Path $PSScriptRoot 'Get-VegasTargets.ps1') -SkipRegistry -CandidateDir @($fakeTarget, "$fakeTarget\"))
Check ($targets.Count -eq 1 -and $targets[0].x64 -and $targets[0].qualification -like 'Detected only*') 'Detection must deduplicate paths and never qualify an unknown host'
$link = Join-Path $out 'app-junction'
New-Item -ItemType Junction -Path $link -Target "$bundle\app" | Out-Null
Reject { & $prepare -OutputDir "$out\bad-link" -AppDir $link } 'reparse'
Check (-not (Test-Path -LiteralPath "$out\bad-link")) 'Reparse refusal must not create a bundle'
$oldApp = Join-Path $repo 'build\b6-candidate-0.1.6\app'
if (Test-Path -LiteralPath $oldApp) {
  Reject { & $prepare -OutputDir "$out\bad-version" -AppDir $oldApp } 'Require matched'
  Check (-not (Test-Path -LiteralPath "$out\bad-version")) 'Mismatched frontend must fail before staging'
}
Write-Output "B7 PASS: $checks packaging/detection checks; local files/fake target only. $out"
