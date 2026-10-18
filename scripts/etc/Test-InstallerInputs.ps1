#Requires -Version 7.0
<# Refusal checks on a copied frozen bundle. Never runs an installer/payload. #>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$BundleDir)
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$fixture = Join-Path $repo ('build/test-results/setup-inputs-' + [guid]::NewGuid().ToString('N'))
Copy-Item -LiteralPath (Resolve-Path -LiteralPath $BundleDir).Path -Destination $fixture -Recurse
$compiler = Join-Path $PSScriptRoot '..\Build-Installer.ps1'
$checks = 0
function Reject([string]$Pattern) {
  $caught = $null
  try { & $compiler -BundleDir $fixture | Out-Null } catch { $caught = $_.Exception.Message }
  if (-not $caught -or $caught -notmatch $Pattern) { throw "Expected '$Pattern', got '$caught'" }
  $script:checks++
}
$ini = Join-Path $fixture 'installer/vegas-encoder.ini.in'
$original = [IO.File]::ReadAllBytes($ini)
Add-Content -LiteralPath $ini -Value 'changed'
Reject 'Bundle file changed'
[IO.File]::WriteAllBytes($ini, $original)
$extra = Join-Path $fixture 'app/extra.txt'
Set-Content -LiteralPath $extra -Value 'unlisted'
Reject 'file set changed'
Remove-Item -LiteralPath $extra
$manifestPath = Join-Path $fixture 'installer-inputs.json'
$manifestBytes = [IO.File]::ReadAllBytes($manifestPath)
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$manifest.files[-1] = $manifest.files[0]
$manifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $manifestPath
Reject 'escaping/duplicate'
[IO.File]::WriteAllBytes($manifestPath, $manifestBytes)
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$manifest.files[-1].file = '../escape.txt'
$manifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $manifestPath
Reject 'escaping/duplicate'
[IO.File]::WriteAllBytes($manifestPath, $manifestBytes)
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$unlisted = Join-Path $fixture 'logs/unlisted.txt'
Set-Content -LiteralPath $unlisted -Value 'unlisted'
$manifest.files[-1] = @{file='logs/unlisted.txt'; bytes=(Get-Item -LiteralPath $unlisted).Length; sha256=(Get-FileHash -LiteralPath $unlisted).Hash}
$manifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $manifestPath
Reject 'Unlisted bundle input'
Write-Output "Installer input guards PASS: $checks refusals; copied bundle only."
