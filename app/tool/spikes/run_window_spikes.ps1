<#
.SYNOPSIS
  Runs the F0 window spikes against a built VegasEncoder.exe.

.DESCRIPTION
  Compiles WindowProbe.cs with the Visual Studio Roslyn compiler into
  app\build\spikes\, then runs it. Output (report and screenshots) goes to
  app\build\spikes\results-<check>-<id>\ (ignored). The probe uses a WinForms window as a
  fake VEGAS host, makes it foreground with one real mouse click, and restores
  the cursor. The "theme" check flips HKCU AppsUseLightTheme for a few seconds
  and always restores the original value.

  The app runs on its real services with VEGAS_ENCODER_DATA_ROOT set to a fresh
  app\build\spikes\data-root, so settings, library and cache stay out of the
  user's %APPDATA% and %LOCALAPPDATA%; the run says whether those stayed
  untouched. Popups get the C4 request fixture (schema\fixtures\b0\request.json)
  with the fake host as their owner (VE_SPIKE_REQUEST).

.EXAMPLE
  powershell -File app\tool\spikes\run_window_spikes.ps1 -Configuration Release -Checks all
#>
param(
  [ValidateSet('Release', 'Profile', 'Debug')][string]$Configuration = 'Release',
  [ValidateSet('all', 'start', 'owner', 'close', 'monitor', 'theme', 'integration')][string]$Checks = 'all',
  [int]$Runs = 10,
  [string]$ApplicationPath
)
$ErrorActionPreference = 'Stop'
$app = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$exe = Join-Path $app "build\windows\x64\runner\$Configuration\VegasEncoder.exe"
if ($ApplicationPath) { $exe = (Resolve-Path -LiteralPath $ApplicationPath).Path }
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

# A fresh directory preserves earlier runs and never deletes trial data.
$dataRoot = Join-Path $out ('data-root-' + [guid]::NewGuid().ToString('N'))
$results = Join-Path $out ('results-' + $Checks + '-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $dataRoot | Out-Null
$userData = @((Join-Path $env:APPDATA 'VegasEncoder'), (Join-Path $env:LOCALAPPDATA 'VegasEncoder'))
$before = $userData | ForEach-Object { Test-Path $_ }
$previousDataRoot = $env:VEGAS_ENCODER_DATA_ROOT
$previousRequest = $env:VE_SPIKE_REQUEST
$env:VEGAS_ENCODER_DATA_ROOT = $dataRoot
$env:VE_SPIKE_REQUEST = (Resolve-Path (Join-Path $app '..\schema\fixtures\b0\request.json')).Path
try {
  & $probe $exe $results $Checks $Runs
  if ($LASTEXITCODE -ne 0) { throw "Window probe failed ($LASTEXITCODE): $Checks" }
} finally {
  $env:VEGAS_ENCODER_DATA_ROOT = $previousDataRoot
  $env:VE_SPIKE_REQUEST = $previousRequest
}
$lines = for ($i = 0; $i -lt $userData.Count; $i++) {
  "user data $($userData[$i]): existed before $($before[$i]), exists after $(Test-Path $userData[$i])"
}
$lines | ForEach-Object { Write-Host $_ }
Add-Content -Path (Join-Path $results 'window-spikes.txt') -Value $lines
Write-Output "Window results: $results"
