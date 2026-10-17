#Requires -Version 7.0
<# Stage matched installer inputs only. Never install, execute payloads or overwrite a candidate. #>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$OutputDir,
  [string]$AppDir = (Join-Path $PSScriptRoot '..\app\build\windows\x64\runner\Release'),
  [string]$PluginDir = (Join-Path $PSScriptRoot '..\build\release\vegas-encoder'),
  [string]$PythonPath = 'python',
  [string[]]$VegasDir = @('C:\Program Files\BorisFX\Vegas Pro 2026',
    'L:\Program Files\VEGAS\VEGAS Pro 23.0', 'L:\Program Files\VEGAS\VEGAS Pro 22.0',
    'L:\Program Files\VEGAS\VEGAS Pro 21.0'),
  [switch]$SkipRegistry
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'Version.ps1')
$version = Get-VeBuildVersion -PythonPath $PythonPath -CheckGenerated
function Assert-PlainPath([string]$Path) {
  $full = [IO.Path]::GetFullPath($Path)
  for ($cursor = $full; $cursor; $cursor = [IO.Path]::GetDirectoryName($cursor)) {
    if ((Test-Path -LiteralPath $cursor) -and
        ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
      throw "Do not follow reparse points: $cursor"
    }
  }
  return $full
}
function Read-Pe([string]$Path) {
  $stream = [IO.File]::OpenRead($Path)
  try {
    $reader = [IO.BinaryReader]::new($stream)
    if ($reader.ReadUInt16() -ne 0x5a4d) { throw "Not PE: $Path" }
    $stream.Position = 0x3c
    $offset = $reader.ReadInt32()
    if ($offset -lt 64 -or $offset -gt $stream.Length - 6) { throw "Invalid PE: $Path" }
    $stream.Position = $offset
    if ($reader.ReadUInt32() -ne 0x4550 -or $reader.ReadUInt16() -ne 0x8664) { throw "Not x64 PE: $Path" }
  } finally { $stream.Dispose() }
  return [Diagnostics.FileVersionInfo]::GetVersionInfo($Path)
}
$output = Assert-PlainPath $OutputDir
$build = Assert-PlainPath (Join-Path $repo 'build')
if (-not $output.StartsWith($build + '\', [StringComparison]::OrdinalIgnoreCase)) {
  throw 'OutputDir must be a fresh directory inside this worktree build/.'
}
if (Test-Path -LiteralPath $output) { throw 'OutputDir exists; preserve it and choose a fresh candidate.' }
$appSource = Assert-PlainPath (Resolve-Path -LiteralPath $AppDir).Path
$pluginSource = Assert-PlainPath (Resolve-Path -LiteralPath $PluginDir).Path
$appFiles = @(Get-ChildItem -LiteralPath $appSource -Recurse -File -Force)
foreach ($item in Get-ChildItem -LiteralPath $appSource -Recurse -Force) { $null = Assert-PlainPath $item.FullName }
foreach ($name in 'VegasEncoder.exe','flutter_windows.dll','ve_core.dll','ve_windows_services.dll','data\icudtl.dat','data\app.so','data\flutter_assets\AssetManifest.bin') {
  if (-not (Test-Path -LiteralPath (Join-Path $appSource $name) -PathType Leaf)) { throw "Missing runtime input: $name" }
}
foreach ($item in Get-ChildItem -LiteralPath $appSource -Force) {
  if ($item.Name -notin @('VegasEncoder.exe','flutter_windows.dll','ve_core.dll','ve_windows_services.dll','data')) {
    throw "Unexpected app bundle item (do not package trial data): $($item.Name)"
  }
}
$nativeDll = Assert-PlainPath (Join-Path $pluginSource 'vegas-encoder.dll')
$native = Read-Pe $nativeDll
$frontend = Read-Pe (Join-Path $appSource 'VegasEncoder.exe')
function Numeric-Version($info) { return "$($info.FileMajorPart).$($info.FileMinorPart).$($info.FileBuildPart).$($info.FilePrivatePart)" }
if ($native.ProductVersion -ne $version.exporter -or $frontend.ProductVersion -ne $version.app -or
    (Numeric-Version $native) -ne $version.numeric -or (Numeric-Version $frontend) -ne $version.numeric) {
  throw "Require matched native $($version.exporter) / frontend $($version.app), numeric $($version.numeric)."
}
foreach ($name in 'flutter_windows.dll','ve_core.dll','ve_windows_services.dll') { $null = Read-Pe (Join-Path $appSource $name) }
$sourceIni = Assert-PlainPath (Join-Path $pluginSource 'vegas-encoder.ini')
$ini = [IO.File]::ReadAllText($sourceIni)
# Config is deployment-specific. Do not carry another candidate's absolute paths.
$ini = [regex]::Replace($ini, '(?m)^\s*(AppPath|LogDir)=.*\r?\n?', '')
$ini = [regex]::Replace($ini, '(?m)^ProbeGetters=.*$', 'ProbeGetters=0')
$targets = @(& (Join-Path $PSScriptRoot 'Get-VegasTargets.ps1') -CandidateDir $VegasDir -SkipRegistry:$SkipRegistry)
New-Item -ItemType Directory -Path "$output\app","$output\app\licenses","$output\plugin","$output\installer","$output\logs" | Out-Null
foreach ($file in $appFiles) {
  $relative = [IO.Path]::GetRelativePath($appSource, $file.FullName)
  $destination = Join-Path "$output\app" $relative
  New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
  Copy-Item -LiteralPath $file.FullName -Destination $destination
}
Copy-Item -LiteralPath $nativeDll -Destination "$output\plugin\vegas-encoder.dll"
Copy-Item -LiteralPath "$repo\packages\ve_core\THIRD_PARTY_NOTICES.md" -Destination "$output\app\licenses\ve_core.txt"
Copy-Item -LiteralPath "$repo\packages\ve_services\THIRD_PARTY_NOTICES.md" -Destination "$output\app\licenses\ve_services.txt"
foreach ($family in 'InstrumentSans','JetBrainsMono') {
  Copy-Item -LiteralPath "$repo\app\assets\fonts\$family\OFL.txt" -Destination "$output\app\licenses\$family-OFL.txt"
}
if (Test-Path -LiteralPath "$pluginSource\vegas-encoder.pdb") {
  $pdb = Assert-PlainPath "$pluginSource\vegas-encoder.pdb"
  Copy-Item -LiteralPath $pdb -Destination "$output\plugin\vegas-encoder.pdb"
}
[IO.File]::WriteAllText("$output\plugin\vegas-encoder.ini", "$ini`r`nAppPath=$output\app\VegasEncoder.exe`r`nLogDir=$output\logs`r`n")
[IO.File]::WriteAllText("$output\installer\vegas-encoder.ini.in", "$ini`r`nAppPath={app}\VegasEncoder.exe`r`n")
[IO.File]::WriteAllText("$output\installer\VegasEncoder-x64.fio2007-config", "[FileIO Plug-Ins]`r`nvegas-encoder=FileIO Plug-Ins\vegas-encoder\vegas-encoder.dll`r`n")
Copy-Item -LiteralPath "$repo\config\version.generated.iss" -Destination "$output\installer\version.iss"
$files = foreach ($file in Get-ChildItem -LiteralPath "$output\app","$output\plugin","$output\installer" -Recurse -File) {
  $relative = [IO.Path]::GetRelativePath($output, $file.FullName)
  [ordered]@{file=$relative; bytes=$file.Length; sha256=(Get-FileHash -LiteralPath $file.FullName).Hash}
}
$commit = (& git -C $repo rev-parse HEAD).Trim()
$dirty = [bool](& git -C $repo status --porcelain --untracked-files=normal)
$manifest = [ordered]@{
  schema='vegas-encoder-installer-inputs/1'; release=$version.release; candidate=$version.exporter; app=$version.app
  numericFileVersion=$version.numeric; versions=$version; architecture='x64'; sourceCommit=$commit; sourceDirty=$dirty
  installedByPreparation=$false; releaseQualified=$false
  openChecks=@('MXF render and MKV regression owner-skipped after all-container VEGAS value handoff confirmation',
    'two-container template restart remains unconfirmed; not an automatic owner test request',
    'exact large-template save/restart sequence remains unconfirmed',
    'owner-deferred extra failure recovery and progress-window performance trials',
    'owner installer, runtime deployment policy, project license and release signoff')
  targets=$targets; appDestination='{app}'; pluginDestination='{vegasDir}\FileIO Plug-Ins\vegas-encoder'
  iniTemplate='installer\vegas-encoder.ini.in'; files=@($files)
}
$manifest | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath "$output\installer-inputs.json" -Encoding utf8
# The existing trial launcher recognizes these identities; trial data stays separate.
$manifest | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath "$output\candidate.json" -Encoding utf8
Write-Output "Prepared $output ($(@($files).Count) files); not installed or release-qualified."
