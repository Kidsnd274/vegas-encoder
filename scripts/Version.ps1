# Shared read-only version access for build/staging scripts.
function Get-VeBuildVersion {
  param([string]$PythonPath = 'python', [switch]$CheckGenerated)
  $versionArgs = @('-I', (Join-Path $PSScriptRoot 'Generate-Versions.py'), '--print-json')
  if ($CheckGenerated) { $versionArgs += '--check' }
  $versionText = & $PythonPath @versionArgs
  if ($LASTEXITCODE -ne 0) { throw 'Version validation failed; see generator diagnostics.' }
  return ($versionText | ConvertFrom-Json)
}
