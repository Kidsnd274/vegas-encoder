#Requires -Version 7.0
<# Build the product, publish runtime folders and compile Setup. Never installs or runs Setup. #>
[CmdletBinding()]
param(
  [ValidateSet('All','Build','Package')][string]$Action = 'All',
  [string]$OutputDir,
  [string]$FlutterPath = $(if (Test-Path -LiteralPath 'L:\flutter\bin\flutter.bat') { 'L:\flutter\bin\flutter.bat' } else { 'flutter.bat' }),
  [string]$PythonPath = 'python',
  [string]$VcVarsPath,
  [string]$IsccPath
)
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $PSScriptRoot 'etc\Version.ps1')
. (Join-Path $PSScriptRoot 'etc\Release-Inputs.ps1')
$version = Get-VeBuildVersion -PythonPath $PythonPath
if ($Action -eq 'Build' -and $OutputDir) { throw 'OutputDir is only used by All or Package.' }
if ($Action -ne 'Build') {
  if (-not $OutputDir) { $OutputDir = Join-Path $repo ("build/releases/vegas-encoder-$($version.app)-" + (Get-Date -Format 'yyyyMMdd-HHmmssfff')) }
  $OutputDir = Assert-VeReleaseOutput $repo $OutputDir
}
$oldPython = $env:VEGAS_ENCODER_PYTHON
$oldVcVars = $env:VEGAS_ENCODER_VCVARS
Push-Location $repo
try {
  $env:VEGAS_ENCODER_PYTHON = $PythonPath
  if ($VcVarsPath) { $env:VEGAS_ENCODER_VCVARS = (Resolve-Path -LiteralPath $VcVarsPath).Path }
  if ($Action -ne 'Package') {
    & $PythonPath -I scripts/etc/Generate-Versions.py
    if ($LASTEXITCODE -ne 0) { throw 'Version generation failed.' }
    & $PythonPath -I scripts/etc/Generate-CoreData.py
    if ($LASTEXITCODE -ne 0) { throw 'Core data generation failed.' }
    Push-Location app
    try {
      & $FlutterPath pub get
      if ($LASTEXITCODE -ne 0) { throw 'Flutter dependency resolution failed.' }
    } finally { Pop-Location }
    # Capture after pub get and before either compiler starts.
    $sourceBefore = Get-VeSourceState $repo | ConvertTo-Json -Depth 6 -Compress
    cmd /d /c 'scripts\etc\build.cmd "" release'
    if ($LASTEXITCODE -ne 0) { throw 'Native build failed.' }
    cmd /d /c scripts\etc\Build-SetupHelper.cmd
    if ($LASTEXITCODE -ne 0) { throw 'Setup helper build failed.' }
    Push-Location app
    try {
      & $FlutterPath build windows --release --build-name $version.release --build-number $version.build
      if ($LASTEXITCODE -ne 0) { throw 'App build failed.' }
    } finally { Pop-Location }
    Publish-VeApp $repo
    $sourceAfter = Get-VeSourceState $repo
    if ($sourceBefore -cne ($sourceAfter | ConvertTo-Json -Depth 6 -Compress)) { throw 'Source changed during build. Rebuild before packaging.' }
    Write-VeBuildReceipt $repo $version $sourceAfter
    Write-Output 'Product build complete: build/release/vegas-encoder/{app,core,plugin,setup}'
  }
  if ($Action -ne 'Build') {
    $null = Get-VeBuildVersion -PythonPath $PythonPath -CheckGenerated
    Test-VeBuildReceipt $repo $version (Get-VeSourceState $repo)
    & (Join-Path $PSScriptRoot 'etc\Prepare-B7.ps1') -OutputDir $OutputDir -PythonPath $PythonPath
    Write-Output "Installer inputs ready: $OutputDir"
    & (Join-Path $PSScriptRoot 'Build-Installer.ps1') -BundleDir $OutputDir -IsccPath $IsccPath
  }
} finally {
  Pop-Location
  $env:VEGAS_ENCODER_PYTHON = $oldPython
  $env:VEGAS_ENCODER_VCVARS = $oldVcVars
}
