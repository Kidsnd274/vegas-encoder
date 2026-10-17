#Requires -Version 7.0
<# Receipt/output guards on fake bytes in a fresh ignored tree. No DLL execution. #>
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Release-Inputs.ps1')
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$fake = Join-Path $repo ('build/test-results/release-inputs-' + [guid]::NewGuid().ToString('N'))
$paths = @('app/build/windows/x64/runner/Release/VegasEncoder.exe',
  'app/build/windows/x64/runner/Release/data/app.so', 'app/build/windows/x64/runner/Release/data/asset.txt',
  'build/release/vegas-encoder/vegas-encoder.dll', 'build/release/vegas-encoder/vegas-encoder.ini',
  'build/release/vegas-encoder/vegas-encoder.pdb')
foreach ($relative in $paths) {
  $path = Join-Path $fake $relative
  New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
  Set-Content -LiteralPath $path -Value 'fake build bytes; never execute'
}
$version = @{manifestSha256='version-a'}
$source = [ordered]@{commit='fake'; patchSha256='patch-a'; untracked=@()}
$checks = 0
function Reject([scriptblock]$Action, [string]$Message) {
  $caught = $null
  try { & $Action | Out-Null } catch { $caught = $_.Exception.Message }
  if (-not $caught -or $caught -notmatch $Message) { throw "Expected '$Message', got '$caught'" }
  $script:checks++
}
Reject { Test-VeBuildReceipt $fake $version $source } 'No build receipt'
Write-VeBuildReceipt $fake $version $source
Test-VeBuildReceipt $fake $version $source
$checks++
Reject { Test-VeBuildReceipt $fake @{manifestSha256='version-b'} $source } 'stale'
Reject { Test-VeBuildReceipt $fake $version ([ordered]@{commit='fake';patchSha256='patch-b';untracked=@()}) } 'stale'
Set-Content -LiteralPath (Join-Path $fake $paths[2]) -Value 'changed asset'
Reject { Test-VeBuildReceipt $fake $version $source } 'changed or missing'
Write-VeBuildReceipt $fake $version $source
Set-Content -LiteralPath (Join-Path $fake 'app/build/windows/x64/runner/Release/extra.txt') -Value 'extra'
Reject { Test-VeBuildReceipt $fake $version $source } 'file set'
Write-VeBuildReceipt $fake $version $source
$receipt = Join-Path $fake 'build/product-build.json'
$data = Get-Content -LiteralPath $receipt -Raw | ConvertFrom-Json
$data.files[0].path = '../escape.dll'
$data | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $receipt
Reject { Test-VeBuildReceipt $fake $version $source } 'file set'
Reject { Assert-VeReleaseOutput $repo (Join-Path $repo 'outside-build') } 'inside this worktree build'
Reject { Assert-VeReleaseOutput $repo $fake } 'exists'
$null = Assert-VeReleaseOutput $repo (Join-Path $fake 'fresh-output')
$checks++
$errors = $null
$null = [Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'Build-Release.ps1'), [ref]$null, [ref]$errors)
if ($errors) { throw ($errors | Out-String) }
$checks++
Write-Output "Release input guards PASS: $checks checks; fake files only."
