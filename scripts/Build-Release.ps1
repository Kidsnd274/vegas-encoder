#Requires -Version 7.0
<# Build the product, publish runtime folders and compile Setup. Never installs or runs Setup. #>
[CmdletBinding()]
param(
  [ValidateSet('All','Build','Package')][string]$Action = 'All',
  [string]$OutputDir,
  [string]$FlutterPath,
  [string]$PythonPath,
  [string]$VcVarsPath,
  [string]$IsccPath
)
$ErrorActionPreference = 'Stop'
function Write-ReleaseStep([string]$Message) {
  Write-Host "`n==> $Message" -ForegroundColor Cyan
}

$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $PSScriptRoot 'etc\Tools.ps1')
. (Join-Path $PSScriptRoot 'etc\Version.ps1')
. (Join-Path $PSScriptRoot 'etc\Release-Inputs.ps1')
Write-Host "Vegas Encoder release | $Action | Windows x64" -ForegroundColor Cyan
Write-ReleaseStep 'Locate tools and read the release version'
$PythonPath = Resolve-VePython $PythonPath
if ($Action -ne 'Package') { $FlutterPath = Resolve-VeFlutter $FlutterPath }
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
    Write-ReleaseStep "Generate build inputs for $($version.app)"
    Write-Host '  Synchronize version files'
    & $PythonPath -I scripts/etc/Generate-Versions.py
    if ($LASTEXITCODE -ne 0) { throw 'Version generation failed.' }
    Write-Host '  Embed the core data'
    & $PythonPath -I scripts/etc/Generate-CoreData.py
    if ($LASTEXITCODE -ne 0) { throw 'Core data generation failed.' }
    Write-Host '  Generate built-in recipes and VEGAS starters'
    & $PythonPath -I scripts/etc/Generate-ServiceBuiltins.py
    if ($LASTEXITCODE -ne 0) { throw 'Built-in preset generation failed.' }
    Push-Location app
    try {
      Write-ReleaseStep 'Resolve Flutter dependencies'
      & $FlutterPath pub get
      if ($LASTEXITCODE -ne 0) { throw 'Flutter dependency resolution failed.' }
    } finally { Pop-Location }
    # Capture after pub get and before either compiler starts.
    Write-ReleaseStep 'Record the source state for the build receipt'
    $sourceBefore = Get-VeSourceState $repo | ConvertTo-Json -Depth 6 -Compress
    Write-ReleaseStep 'Build the native core, VEGAS exporters and test tools'
    cmd /d /c 'scripts\etc\build.cmd "" release'
    if ($LASTEXITCODE -ne 0) { throw 'Native build failed.' }
    Write-ReleaseStep 'Build the Setup helper (ve-install.exe)'
    cmd /d /c scripts\etc\Build-SetupHelper.cmd
    if ($LASTEXITCODE -ne 0) { throw 'Setup helper build failed.' }
    $symbolsDir = Assert-VeReleaseOutput $repo (Join-Path $repo (
      "build/symbols/vegas-encoder-$($version.app)-" + (Get-Date -Format 'yyyyMMdd-HHmmssfff')
    ))
    Push-Location app
    try {
      Write-ReleaseStep 'Build the Flutter Windows release app'
      & $FlutterPath build windows --release "--split-debug-info=$symbolsDir" --build-name $version.release --build-number $version.build
      if ($LASTEXITCODE -ne 0) { throw 'App build failed.' }
    } finally { Pop-Location }
    Write-ReleaseStep 'Publish the app runtime'
    Publish-VeApp $repo
    Write-ReleaseStep 'Verify the source state and write the build receipt'
    $sourceAfter = Get-VeSourceState $repo
    if ($sourceBefore -cne ($sourceAfter | ConvertTo-Json -Depth 6 -Compress)) { throw 'Source changed during build. Rebuild before packaging.' }
    Write-VeBuildReceipt $repo $version $sourceAfter
    Write-Output 'Product build complete: build/release/vegas-encoder/{app,core,plugin,setup}'
    Write-Output "Flutter crash symbols: $symbolsDir"
  }
  if ($Action -ne 'Build') {
    Write-ReleaseStep 'Check the generated versions and validate the build receipt'
    $null = Get-VeBuildVersion -PythonPath $PythonPath -CheckGenerated
    Test-VeBuildReceipt $repo $version (Get-VeSourceState $repo)
    Write-ReleaseStep 'Stage the installer bundle'
    & (Join-Path $PSScriptRoot 'etc\Prepare-B7.ps1') -OutputDir $OutputDir -PythonPath $PythonPath
    Write-Output "Installer inputs ready: $OutputDir"
    Write-ReleaseStep 'Build the Windows installer'
    & (Join-Path $PSScriptRoot 'Build-Installer.ps1') -BundleDir $OutputDir -IsccPath $IsccPath
  }
} finally {
  Pop-Location
  $env:VEGAS_ENCODER_PYTHON = $oldPython
  $env:VEGAS_ENCODER_VCVARS = $oldVcVars
}
