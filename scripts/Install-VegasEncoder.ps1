<#
.SYNOPSIS
Explicit, reversible development install/update/uninstall of Vegas Encoder.
.DESCRIPTION
Owns only FileIO Plug-Ins\vegas-encoder and VegasEncoder-x64.fio2007-config.
Other exporters are left in place. Existing installations require a matching
manifest and unchanged recorded hashes; unexpected files cause refusal.
An update stages its replacement before moving the old installation aside.
The script refuses reparse points along all mutation paths and requires all
programs running from VegasDir to close. No automatic installation occurs.
-NoElevate is intended for a fake installation tree or an already elevated shell.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string] $VegasDir,
  [string] $BuildDir = (Join-Path $PSScriptRoot '..\build\vegas-encoder'),
  [switch] $Uninstall,
  [switch] $Update,
  [switch] $NoElevate,
  [string] $TranscriptPath
)
$ErrorActionPreference = 'Stop'

# Resolve every mutation target before use and reject link/junction traversal.
function Assert-PlainPath {
  param([string] $Path)
  $candidate = [IO.Path]::GetFullPath($Path)
  $cursor = $candidate
  while ($cursor) {
    if (Test-Path -LiteralPath $cursor) {
      $item = Get-Item -LiteralPath $cursor -Force
      if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw "Reparse point is not permitted in an install path: $cursor"
      }
    }
    $parent = [IO.Path]::GetDirectoryName($cursor.TrimEnd('\'))
    if (-not $parent -or $parent -eq $cursor) { break }
    $cursor = $parent
  }
  return $candidate
}

function Assert-InRoot {
  param([string] $Path, [string] $Root)
  $full = Assert-PlainPath $Path
  $prefix = $Root.TrimEnd('\') + '\'
  if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Install target escapes VEGAS directory: $full"
  }
  return $full
}

function Remove-OwnedDirectory {
  param([string] $Path, [string] $Root)
  if (-not (Test-Path -LiteralPath $Path)) { return }
  $full = Assert-InRoot $Path $Root
  # Never recursively delete. Only the known flat installation names are allowed.
  $files = @(Get-ChildItem -LiteralPath $full -Force)
  foreach ($file in $files) {
    if ($file.PSIsContainer -or $file.Name -notin @('vegas-encoder.dll','vegas-encoder.pdb','vegas-encoder.ini','install-manifest.json')) {
      throw "Unexpected item in owned directory; preserving it: $($file.FullName)"
    }
    $null = Assert-InRoot $file.FullName $Root
  }
  foreach ($file in $files) { Remove-Item -LiteralPath $file.FullName -Force }
  Remove-Item -LiteralPath $full -Force
}

function Read-ValidatedInstall {
  param([string] $PluginDir, [string] $ConfigPath, [string] $Root)
  $manifestPath = Join-Path $PluginDir 'install-manifest.json'
  if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw "No install manifest: $manifestPath" }
  $null = Assert-InRoot $manifestPath $Root
  $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
  if ($manifest.schema -ne 'vegas-encoder-install/1' -or $manifest.config -ne $ConfigPath -or
      $manifest.pluginDir -ne $PluginDir) { throw 'Manifest identity or path does not match this installation.' }
  $recorded = @($manifest.files)
  if ($recorded.Count -lt 2 -or $recorded.Count -gt 3) { throw 'Manifest has an invalid file count.' }
  $allowed = @('vegas-encoder.dll','vegas-encoder.pdb','vegas-encoder.ini')
  $seen = @{}
  foreach ($record in $recorded) {
    $name = [IO.Path]::GetFileName([string]$record.file)
    $expected = Join-Path $PluginDir $name
    if ($name -notin $allowed -or $record.file -ne $expected -or $seen.ContainsKey($name)) {
      throw 'Manifest contains an unexpected, duplicate or escaping file path.'
    }
    $seen[$name] = $true
    $null = Assert-InRoot $expected $Root
    if (-not (Test-Path -LiteralPath $expected -PathType Leaf) -or
        (Get-FileHash -LiteralPath $expected -Algorithm SHA256).Hash -ne $record.sha256) {
      throw "Installed file is missing or changed; preserving installation: $expected"
    }
  }
  if (-not $seen.ContainsKey('vegas-encoder.dll') -or -not $seen.ContainsKey('vegas-encoder.ini')) {
    throw 'Manifest must record the DLL and INI.'
  }
  foreach ($item in Get-ChildItem -LiteralPath $PluginDir -Force) {
    $null = Assert-InRoot $item.FullName $Root
    if ($item.PSIsContainer -or ($item.Name -ne 'install-manifest.json' -and -not $seen.ContainsKey($item.Name))) {
      throw "Unrecorded item found; preserving installation: $($item.FullName)"
    }
  }
  if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf) -or
      (Get-FileHash -LiteralPath $ConfigPath -Algorithm SHA256).Hash -ne $manifest.configSha256) {
    throw 'Discovery configuration is missing or changed; preserving installation.'
  }
  return $manifest
}

function Invoke-Install {
  if ($Uninstall -and $Update) { throw 'Use either -Uninstall or -Update, not both.' }
  if (-not (Test-Path -LiteralPath $VegasDir -PathType Container)) { throw "VEGAS directory not found: $VegasDir" }
  $installRoot = Assert-PlainPath (Resolve-Path -LiteralPath $VegasDir).Path
  $pluginParent = Assert-InRoot (Join-Path $installRoot 'FileIO Plug-Ins') $installRoot
  $pluginDir = Assert-InRoot (Join-Path $pluginParent 'vegas-encoder') $installRoot
  $configPath = Assert-InRoot (Join-Path $installRoot 'VegasEncoder-x64.fio2007-config') $installRoot
  $running = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
    try { $_.Path -and $_.Path.StartsWith($installRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase) } catch { $false }
  })
  if ($running) { throw "Close programs running from VEGAS directory first: $(($running | ForEach-Object Name) -join ', ')" }

  if ($Uninstall -or $Update) {
    $previous = Read-ValidatedInstall $pluginDir $configPath $installRoot
  } elseif ((Test-Path -LiteralPath $pluginDir) -or (Test-Path -LiteralPath $configPath)) {
    throw 'Product install path or discovery config already exists. Use -Update only for a recorded installation.'
  }
  if ($Uninstall) {
    # All contents and hashes were validated above. Delete only those files.
    foreach ($record in $previous.files) { Remove-Item -LiteralPath $record.file -Force }
    Remove-Item -LiteralPath $configPath -Force
    Remove-Item -LiteralPath (Join-Path $pluginDir 'install-manifest.json') -Force
    Remove-Item -LiteralPath $pluginDir -Force
    Write-Output 'Uninstalled Vegas Encoder; unrelated files and exporters are preserved.'
    return
  }

  $buildRoot = (Resolve-Path -LiteralPath $BuildDir).Path
  $names = @('vegas-encoder.dll','vegas-encoder.ini')
  if (Test-Path -LiteralPath (Join-Path $buildRoot 'vegas-encoder.pdb') -PathType Leaf) { $names += 'vegas-encoder.pdb' }
  foreach ($name in $names) {
    if (-not (Test-Path -LiteralPath (Join-Path $buildRoot $name) -PathType Leaf)) { throw "Build input missing: $name" }
  }
  if (-not (Test-Path -LiteralPath $pluginParent)) { New-Item -ItemType Directory -Path $pluginParent | Out-Null }
  $stageDir = Assert-InRoot (Join-Path $pluginParent ('.vegas-encoder-stage-' + [guid]::NewGuid().ToString('N'))) $installRoot
  $newDir = Assert-InRoot (Join-Path $stageDir 'new') $installRoot
  $backupDir = Assert-InRoot (Join-Path $stageDir 'previous') $installRoot
  $stageConfig = Assert-InRoot (Join-Path $stageDir 'new-config') $installRoot
  $backupConfig = Assert-InRoot (Join-Path $stageDir 'previous-config') $installRoot
  New-Item -ItemType Directory -Path $newDir | Out-Null
  $oldMoved = $false
  $configMoved = $false
  $newMoved = $false
  $newConfigMoved = $false
  $completed = $false
  try {
    $records = foreach ($name in $names) {
      $source = Join-Path $buildRoot $name
      $staged = Join-Path $newDir $name
      Copy-Item -LiteralPath $source -Destination $staged
      [pscustomobject]@{ file=(Join-Path $pluginDir $name); sha256=(Get-FileHash -LiteralPath $staged -Algorithm SHA256).Hash }
    }
    Set-Content -LiteralPath $stageConfig -Value "[FileIO Plug-Ins]`r`nvegas-encoder=FileIO Plug-Ins\vegas-encoder\vegas-encoder.dll`r`n" -Encoding Ascii -NoNewline
    $vegasExe = Get-ChildItem -LiteralPath $installRoot -Filter 'vegas*.exe' -File | Select-Object -First 1
    [pscustomobject]@{
      schema='vegas-encoder-install/1'; product='Vegas Encoder'; installed=(Get-Date).ToString('o')
      vegasDir=$installRoot; pluginDir=$pluginDir
      vegasExe=if ($vegasExe) { $vegasExe.FullName } else { $null }
      vegasVersion=if ($vegasExe) { $vegasExe.VersionInfo.FileVersion } else { $null }
      config=$configPath; configSha256=(Get-FileHash -LiteralPath $stageConfig -Algorithm SHA256).Hash
      files=@($records)
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $newDir 'install-manifest.json') -Encoding utf8
    if ($Update) {
      # Both resolved directory paths are inside the exact VEGAS root; contents
      # are flat, recorded and reparse-free. Keep the previous install for rollback.
      $null = Assert-InRoot $pluginDir $installRoot
      $null = Assert-InRoot $backupDir $installRoot
      Move-Item -LiteralPath $pluginDir -Destination $backupDir
      $oldMoved = $true
      Move-Item -LiteralPath $configPath -Destination $backupConfig
      $configMoved = $true
    }
    $null = Assert-InRoot $newDir $installRoot
    $null = Assert-InRoot $pluginDir $installRoot
    Move-Item -LiteralPath $newDir -Destination $pluginDir
    $newMoved = $true
    Move-Item -LiteralPath $stageConfig -Destination $configPath
    $newConfigMoved = $true
    $null = Read-ValidatedInstall $pluginDir $configPath $installRoot
    $completed = $true
  } catch {
    $failure = $_
    if ($newConfigMoved -and (Test-Path -LiteralPath $configPath)) { Remove-Item -LiteralPath $configPath -Force }
    if ($newMoved) { Remove-OwnedDirectory $pluginDir $installRoot }
    if ($oldMoved) {
      $null = Assert-InRoot $backupDir $installRoot
      $null = Assert-InRoot $pluginDir $installRoot
      Move-Item -LiteralPath $backupDir -Destination $pluginDir
    }
    if ($configMoved) { Move-Item -LiteralPath $backupConfig -Destination $configPath }
    throw $failure
  } finally {
    # Flat cleanup is intentionally conservative; a surprising item is preserved.
    Remove-OwnedDirectory $newDir $installRoot
    if ($completed) { Remove-OwnedDirectory $backupDir $installRoot }
    $cleanupFiles = @($stageConfig)
    # A failed rollback must retain both halves of the previous installation.
    if ($completed) { $cleanupFiles += $backupConfig }
    foreach ($path in $cleanupFiles) {
      if (Test-Path -LiteralPath $path) {
        $null = Assert-InRoot $path $installRoot
        Remove-Item -LiteralPath $path -Force
      }
    }
    if (Test-Path -LiteralPath $stageDir) {
      if (@(Get-ChildItem -LiteralPath $stageDir -Force).Count -eq 0) { Remove-Item -LiteralPath $stageDir -Force }
      else { Write-Warning "Preserved staging/rollback files: $stageDir" }
    }
  }
  Write-Output "Installed Vegas Encoder into $installRoot"
  $records | ForEach-Object { Write-Output "  $($_.file)  $($_.sha256)" }
  Write-Output "Undo: ./scripts/Install-VegasEncoder.ps1 -VegasDir '$installRoot' -Uninstall"
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
  [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin -and -not $NoElevate) {
  # Hidden elevated helper, with its output available in a transcript.
  $elevationLog = Join-Path ([IO.Path]::GetTempPath()) ('vegas-encoder-install-' + [guid]::NewGuid().ToString('N') + '.log')
  $argList = @('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`"",
    '-VegasDir',"`"$([IO.Path]::GetFullPath($VegasDir))`"",'-BuildDir',"`"$([IO.Path]::GetFullPath($BuildDir))`"",
    '-NoElevate','-TranscriptPath',"`"$elevationLog`"")
  if ($Uninstall) { $argList += '-Uninstall' }
  if ($Update) { $argList += '-Update' }
  Write-Output "Requesting administrator rights. Helper transcript: $elevationLog"
  $helper = Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList $argList -Verb RunAs -WindowStyle Hidden -Wait -PassThru
  if ($helper.ExitCode -ne 0) { throw "Elevated install failed ($($helper.ExitCode)); see $elevationLog" }
  Write-Output "Elevated operation completed; see $elevationLog"
  return
}
$transcribing = $false
$failed = $false
try {
  if ($TranscriptPath) { Start-Transcript -LiteralPath $TranscriptPath -Force | Out-Null; $transcribing = $true }
  Invoke-Install
} catch {
  $failed = $true
  Write-Error -Message $_.Exception.Message -ErrorAction Continue
} finally {
  if ($transcribing) { Stop-Transcript | Out-Null }
}
if ($failed) { exit 1 }
