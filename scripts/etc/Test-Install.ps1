#Requires -Version 7.0
<#
.SYNOPSIS
Tests installer behavior against a fresh fake tree; never touches installed VEGAS.
.DESCRIPTION
Uses text marker files with DLL/PDB names. No binary is loaded and no elevation
is requested. Keeps its fake tree and logs in the selected evidence directory.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string] $EvidenceDir)
$ErrorActionPreference = 'Stop'
$installTestDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($EvidenceDir)
if (Test-Path -LiteralPath $installTestDir) { throw 'EvidenceDir exists; use a fresh directory.' }
$installTestScript = Join-Path $PSScriptRoot '..\Install-VegasEncoder.ps1'
$installTestShell = (Get-Process -Id $PID).Path
$installTestVegas = Join-Path $installTestDir 'fake VEGAS'
$installTestBuild = Join-Path $installTestDir 'build'
New-Item -ItemType Directory -Path $installTestVegas,$installTestBuild | Out-Null
$installTestPlugin = Join-Path $installTestVegas 'FileIO Plug-Ins\vegas-encoder'
$installTestConfig = Join-Path $installTestVegas 'VegasEncoder-x64.fio2007-config'
$installTestManifest = Join-Path $installTestPlugin 'install-manifest.json'
$installTestOther = Join-Path $installTestVegas 'FileIO Plug-Ins\ffbridge'
New-Item -ItemType Directory -Path $installTestOther | Out-Null
$installTestOtherDll = Join-Path $installTestOther 'ffbridge.dll'
$installTestOtherConfig = Join-Path $installTestVegas 'FfBridge-x64.fio2007-config'
Set-Content -LiteralPath $installTestOtherDll -Value 'unrelated exporter marker'
Set-Content -LiteralPath $installTestOtherConfig -Value 'unrelated discovery marker'
$installTestOtherHash = (Get-FileHash -LiteralPath $installTestOtherDll).Hash
$installTestOtherConfigHash = (Get-FileHash -LiteralPath $installTestOtherConfig).Hash
Set-Content -LiteralPath (Join-Path $installTestBuild 'vegas-encoder.dll') -Value 'fake DLL v1; never loaded'
Set-Content -LiteralPath (Join-Path $installTestBuild 'vegas-encoder.ini') -Value "[vegas-encoder]`nOutputMode=ffmpeg"
Set-Content -LiteralPath (Join-Path $installTestBuild 'vegas-encoder.pdb') -Value 'fake PDB marker'

function Assert-InstallTest {
  param([bool] $Condition, [string] $Message)
  if (-not $Condition) { throw $Message }
  Write-Output "PASS installer: $Message"
}

function Invoke-InstallTest {
  param([string] $Name, [string[]] $Extra = @(), [int] $ExpectedExit = 0)
  $argsList = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$installTestScript,
    '-VegasDir',$installTestVegas,'-BuildDir',$installTestBuild,'-NoElevate') + $Extra
  & $installTestShell @argsList 2>&1 | Set-Content -LiteralPath (Join-Path $installTestDir "$Name.txt") -Encoding utf8
  if ($LASTEXITCODE -ne $ExpectedExit) { throw "$Name returned $LASTEXITCODE, expected $ExpectedExit; see its log." }
}

Invoke-InstallTest initial-install
$installedDll = Join-Path $installTestPlugin 'vegas-encoder.dll'
$v1Hash = (Get-FileHash -LiteralPath $installedDll).Hash
Assert-InstallTest ($v1Hash -eq (Get-FileHash -LiteralPath (Join-Path $installTestBuild 'vegas-encoder.dll')).Hash) 'install copied the supplied DLL'
$originalConfig = [IO.File]::ReadAllBytes($installTestConfig)
$originalManifest = [IO.File]::ReadAllBytes($installTestManifest)

$unrecorded = Join-Path $installTestPlugin 'user-notes.txt'
Set-Content -LiteralPath $unrecorded -Value 'preserve this unrecorded file'
Invoke-InstallTest reject-unrecorded -Extra @('-Uninstall') -ExpectedExit 1
Assert-InstallTest ((Test-Path -LiteralPath $unrecorded) -and (Get-FileHash -LiteralPath $installedDll).Hash -eq $v1Hash) 'unrecorded file prevents removal and is preserved'
Remove-Item -LiteralPath $unrecorded

Set-Content -LiteralPath $installTestConfig -Value 'changed discovery config'
Invoke-InstallTest reject-config-drift -Extra @('-Update') -ExpectedExit 1
Assert-InstallTest ((Get-FileHash -LiteralPath $installedDll).Hash -eq $v1Hash) 'changed config prevents update before DLL mutation'
[IO.File]::WriteAllBytes($installTestConfig, $originalConfig)

$outsideMarker = Join-Path $installTestDir 'outside-plugin-marker.txt'
Set-Content -LiteralPath $outsideMarker -Value 'manifest may not delete this'
$badManifest = Get-Content -Raw -LiteralPath $installTestManifest | ConvertFrom-Json
$badManifest.files[0].file = $outsideMarker
$badManifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $installTestManifest -Encoding utf8
Invoke-InstallTest reject-manifest-escape -Extra @('-Uninstall') -ExpectedExit 1
Assert-InstallTest ((Test-Path -LiteralPath $outsideMarker) -and (Get-FileHash -LiteralPath $installedDll).Hash -eq $v1Hash) 'escaping manifest path is refused before removal'
[IO.File]::WriteAllBytes($installTestManifest, $originalManifest)

Remove-Item -LiteralPath (Join-Path $installTestBuild 'vegas-encoder.ini')
Invoke-InstallTest reject-missing-update-input -Extra @('-Update') -ExpectedExit 1
Assert-InstallTest ((Get-FileHash -LiteralPath $installedDll).Hash -eq $v1Hash) 'missing replacement input preserves installed version'
Set-Content -LiteralPath (Join-Path $installTestBuild 'vegas-encoder.ini') -Value "[vegas-encoder]`nOutputMode=raw"
Set-Content -LiteralPath (Join-Path $installTestBuild 'vegas-encoder.dll') -Value 'fake DLL v2; never loaded'
Invoke-InstallTest successful-update -Extra @('-Update')
Assert-InstallTest ((Get-FileHash -LiteralPath $installedDll).Hash -eq
  (Get-FileHash -LiteralPath (Join-Path $installTestBuild 'vegas-encoder.dll')).Hash) 'update publishes supplied replacement'
Invoke-InstallTest successful-uninstall -Extra @('-Uninstall')
Assert-InstallTest ((-not (Test-Path -LiteralPath $installTestPlugin)) -and (-not (Test-Path -LiteralPath $installTestConfig))) 'uninstall removes only the recorded product installation'
Assert-InstallTest (((Get-FileHash -LiteralPath $installTestOtherDll).Hash -eq $installTestOtherHash) -and
  ((Get-FileHash -LiteralPath $installTestOtherConfig).Hash -eq $installTestOtherConfigHash)) 'unrelated exporter and discovery config remain unchanged'
Assert-InstallTest (@(Get-ChildItem -LiteralPath (Split-Path -Parent $installTestPlugin) -Filter '.vegas-encoder-stage-*').Count -eq 0) 'successful operations leave no staging folders'
Write-Output "INSTALLER FAKE-TREE TEST PASSED; evidence: $installTestDir"
exit 0
