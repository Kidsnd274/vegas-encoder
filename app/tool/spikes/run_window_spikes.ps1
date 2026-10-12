<#
.SYNOPSIS
  Runs the F0 window spikes against a built VegasEncoder.exe.

.DESCRIPTION
  Compiles WindowProbe.cs with the Visual Studio Roslyn compiler into
  app\build\spikes\, then runs it. Output (report and screenshots) goes to
  app\build\spikes\results\ (ignored). The probe uses a WinForms window as a
  fake VEGAS host, makes it foreground with one real mouse click, and restores
  the cursor. The "theme" check flips HKCU AppsUseLightTheme for a few seconds
  and always restores the original value.

.EXAMPLE
  powershell -File app\tool\spikes\run_window_spikes.ps1 -Configuration Release -Checks all
#>
param(
  [ValidateSet('Release', 'Profile', 'Debug')][string]$Configuration = 'Release',
  [ValidateSet('all', 'start', 'owner', 'monitor', 'theme')][string]$Checks = 'all',
  [int]$Runs = 10
)
$ErrorActionPreference = 'Stop'
$app = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$exe = Join-Path $app "build\windows\x64\runner\$Configuration\VegasEncoder.exe"
if (-not (Test-Path $exe)) { throw "Build first: flutter build windows --$($Configuration.ToLower())  ($exe not found)" }

$csc = Get-ChildItem -Path "${env:ProgramFiles}\Microsoft Visual Studio", 'L:\Program Files\Microsoft Visual Studio' -Filter csc.exe -Recurse -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -match 'Roslyn\\csc\.exe$' } | Select-Object -First 1
if (-not $csc) { throw 'Roslyn csc.exe (Visual Studio) not found.' }

$out = Join-Path $app 'build\spikes'
New-Item -ItemType Directory -Force $out | Out-Null
$probe = Join-Path $out 'WindowProbe.exe'
$fw = "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319"
& $csc.FullName /nologo /langversion:latest /target:exe /platform:x64 "/out:$probe" `
  "/r:$fw\System.Windows.Forms.dll" "/r:$fw\System.Drawing.dll" (Join-Path $PSScriptRoot 'WindowProbe.cs')
if ($LASTEXITCODE -ne 0) { throw 'WindowProbe.cs did not compile.' }

& $probe $exe (Join-Path $out 'results') $Checks $Runs
