#Requires -Version 7.0
<# Compile a verified, frozen bundle. Does not run/install the resulting executable. #>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$BundleDir, [string]$IsccPath)
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$bundle = (Resolve-Path -LiteralPath $BundleDir).Path
if (-not $IsccPath) { $IsccPath = Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6/ISCC.exe' }
if (-not (Test-Path -LiteralPath $IsccPath -PathType Leaf)) { throw 'Inno Setup 6 compiler not found. Supply -IsccPath.' }
$manifest = Get-Content -LiteralPath "$bundle/installer-inputs.json" -Raw | ConvertFrom-Json
if ($manifest.schema -ne 'vegas-encoder-installer-inputs/1') { throw 'Unknown bundle manifest.' }
function Assert-Bundle {
  $actual = @(Get-ChildItem -LiteralPath "$bundle/app","$bundle/plugin","$bundle/installer","$bundle/setup" -Recurse -File)
  if ($actual.Count -ne $manifest.files.Count) { throw 'Bundle file set changed.' }
  $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach ($entry in $manifest.files) {
    $path = [IO.Path]::GetFullPath((Join-Path $bundle $entry.file))
    if (-not $path.StartsWith($bundle + '\', [StringComparison]::OrdinalIgnoreCase) -or -not $seen.Add($path)) { throw 'Bundle manifest contains an escaping/duplicate path.' }
    for ($cursor = $path; $cursor; $cursor = [IO.Path]::GetDirectoryName($cursor)) {
      if ((Test-Path -LiteralPath $cursor) -and ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Bundle traverses a reparse point.' }
    }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).Length -ne $entry.bytes -or (Get-FileHash -LiteralPath $path).Hash -ne $entry.sha256) { throw "Bundle file changed: $($entry.file)" }
  }
  foreach ($file in $actual) { if (-not $seen.Contains($file.FullName)) { throw "Unlisted bundle input: $($file.FullName)" } }
}
Assert-Bundle
$dist = Join-Path $repo 'dist'
if ((Test-Path -LiteralPath $dist) -and ((Get-Item -LiteralPath $dist -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'dist must not be a reparse point.' }
New-Item -ItemType Directory -Path $dist -Force | Out-Null
$name = "VegasEncoder-$($manifest.numericFileVersion)-windows-x64-setup-" + (Get-Date -Format 'yyyyMMdd-HHmmssfff')
& $IsccPath "/DBundleDir=$bundle" "/O$dist" "/F$name" "$bundle/setup/setup_script.iss"
if ($LASTEXITCODE -ne 0) { throw 'Installer compilation failed.' }
Assert-Bundle
$exe = Join-Path $dist "$name.exe"
[ordered]@{schema='vegas-encoder-setup-artifact/1'; version=$manifest.app; bundle=$bundle
  sourceCommit=$manifest.sourceCommit; sourceDirty=$manifest.sourceDirty
  installerInputsSha256=(Get-FileHash -LiteralPath "$bundle/installer-inputs.json").Hash
  installerSha256=(Get-FileHash -LiteralPath $exe).Hash; installed=$false; releaseQualified=$false
} | ConvertTo-Json | Set-Content -LiteralPath "$dist/$name.json" -Encoding utf8
Write-Output "Installer built (not run): $exe"
