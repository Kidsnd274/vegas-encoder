#Requires -Version 7.0
<# Read-only installer discovery. Detection is not compatibility qualification. #>
[CmdletBinding()]
param([string[]]$CandidateDir = @(), [switch]$SkipRegistry)
$ErrorActionPreference = 'Stop'
$dirs = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
function Add-Directory([string]$Directory) {
  $null = $dirs.Add([IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($Directory)))
}
foreach ($dir in $CandidateDir) { Add-Directory $dir }
if (-not $SkipRegistry) {
  foreach ($hive in 'HKLM:', 'HKCU:') {
    foreach ($key in 'Software\Microsoft\Windows\CurrentVersion\Uninstall',
                     'Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall') {
      foreach ($entry in Get-ChildItem "$hive\$key" -ErrorAction SilentlyContinue) {
        $record = Get-ItemProperty -LiteralPath $entry.PSPath -ErrorAction SilentlyContinue
        if ($record.DisplayName -match '(?i)vegas.*pro|vegas pro' -and $record.InstallLocation) {
          Add-Directory $record.InstallLocation.Trim('"')
        }
      }
    }
    foreach ($entry in Get-ChildItem "$hive\Software\Microsoft\Windows\CurrentVersion\App Paths" -ErrorAction SilentlyContinue) {
      if ($entry.PSChildName -match '^vegas\d+\.exe$') {
        $exe = (Get-Item -LiteralPath $entry.PSPath).GetValue('')
        if ($exe) { Add-Directory ([IO.Path]::GetDirectoryName($exe.Trim('"'))) }
      }
    }
  }
}
foreach ($dir in ($dirs | Sort-Object)) {
  if (-not (Test-Path -LiteralPath $dir -PathType Container)) { continue }
  foreach ($exe in Get-ChildItem -LiteralPath $dir -Filter 'vegas*.exe' -File) {
    if ($exe.Name -notmatch '^vegas\d+\.exe$') { continue }
    $stream = [IO.File]::OpenRead($exe.FullName)
    try {
      $reader = [IO.BinaryReader]::new($stream)
      if ($stream.Length -lt 64) { continue }
      if ($reader.ReadUInt16() -ne 0x5a4d) { continue }
      $stream.Position = 0x3c
      $offset = $reader.ReadInt32()
      if ($offset -lt 64 -or $offset -gt $stream.Length - 6) { continue }
      $stream.Position = $offset
      if ($reader.ReadUInt32() -ne 0x4550) { continue }
      $x64 = $reader.ReadUInt16() -eq 0x8664
    } finally { $stream.Dispose() }
    [pscustomobject]@{
      vegasDir = $dir; executable = $exe.FullName
      fileVersion = $exe.VersionInfo.FileVersion; x64 = $x64
      qualification = if ($x64 -and $exe.VersionInfo.FileVersion -eq '2026.0.3.189') {
        'Selected host version; B6 qualification still pending'
      } else { 'Detected only; unsupported until separately qualified' }
      pluginDir = Join-Path $dir 'FileIO Plug-Ins\vegas-encoder'
      discovery = Join-Path $dir 'VegasEncoder-x64.fio2007-config'
    }
  }
}
