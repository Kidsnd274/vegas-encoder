# Build receipts guard Package-only against changed versions, source or outputs.
function Assert-VeReleaseOutput([string]$Repo, [string]$OutputDir) {
  $output = [IO.Path]::GetFullPath($OutputDir)
  $build = [IO.Path]::GetFullPath((Join-Path $Repo 'build'))
  if (-not $output.StartsWith($build + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'OutputDir must be a fresh directory inside this worktree build/.'
  }
  for ($cursor = $output; $cursor; $cursor = [IO.Path]::GetDirectoryName($cursor)) {
    if ((Test-Path -LiteralPath $cursor) -and ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
      throw "Do not follow reparse points: $cursor"
    }
  }
  if (Test-Path -LiteralPath $output) { throw 'OutputDir exists; preserve it and choose a fresh candidate.' }
  return $output
}

function Get-VeSourceState([string]$Repo) {
  $commit = (& git -C $Repo rev-parse HEAD).Trim()
  if ($LASTEXITCODE -ne 0) { throw 'Cannot read source commit.' }
  $paths = @('app','packages','src','schema','scripts','config','version.json')
  $patch = (& git -C $Repo -c core.safecrlf=false diff --no-ext-diff --binary HEAD -- @paths) -join "`n"
  if ($LASTEXITCODE -ne 0) { throw 'Cannot read source changes.' }
  $untrackedPaths = @(& git -C $Repo ls-files --others --exclude-standard -- @paths)
  if ($LASTEXITCODE -ne 0) { throw 'Cannot read new source paths.' }
  $untracked = foreach ($path in $untrackedPaths) {
    $file = Get-Item -LiteralPath (Join-Path $Repo $path)
    [ordered]@{path=$path; bytes=$file.Length; modified=$file.LastWriteTimeUtc.Ticks}
  }
  $sha = [Security.Cryptography.SHA256]::Create()
  try { $patchHash = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($patch))).Replace('-', '') }
  finally { $sha.Dispose() }
  return [ordered]@{commit=$commit; patchSha256=$patchHash; untracked=@($untracked)}
}

function Get-VeBuildPaths([string]$Repo) {
  $app = 'app/build/windows/x64/runner/Release'
  $plugin = 'build/release/vegas-encoder'
  $root = Join-Path $Repo $app
  $entries = @((Get-Item -LiteralPath $root)) + @(Get-ChildItem -LiteralPath $root -Recurse -Force)
  foreach ($entry in $entries) {
    if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Build output traverses a reparse point: $($entry.FullName)" }
  }
  $paths = @($entries | Where-Object { -not $_.PSIsContainer } | ForEach-Object {
    [IO.Path]::GetRelativePath($Repo, $_.FullName).Replace('\', '/')
  })
  $paths += "$plugin/vegas-encoder.dll", "$plugin/vegas-encoder.ini", "$plugin/vegas-encoder.pdb"
  return @($paths | Sort-Object)
}

function Write-VeBuildReceipt([string]$Repo, $Version, $SourceState) {
  $paths = Get-VeBuildPaths $Repo
  $files = foreach ($path in $paths) {
    $full = Join-Path $Repo $path
    [ordered]@{path=$path; sha256=(Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash}
  }
  [ordered]@{schema=1; versionSha256=$Version.manifestSha256; source=$SourceState; files=@($files)} |
    ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $Repo 'build/product-build.json') -Encoding utf8
}

function Test-VeBuildReceipt([string]$Repo, $Version, $SourceState) {
  $path = Join-Path $Repo 'build/product-build.json'
  if (-not (Test-Path -LiteralPath $path)) { throw 'No build receipt. Run Build-Release.ps1 -Action Build or All first.' }
  $receipt = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
  if ($receipt.schema -ne 1 -or $receipt.versionSha256 -ne $Version.manifestSha256 -or
      ($receipt.source | ConvertTo-Json -Depth 6 -Compress) -cne ($SourceState | ConvertTo-Json -Depth 6 -Compress)) {
    throw 'Build receipt is stale: versions or source changed. Rebuild before packaging.'
  }
  $expected = @(Get-VeBuildPaths $Repo)
  if (@($receipt.files).Count -ne $expected.Count -or
      (@($receipt.files.path | Sort-Object) -join '|') -cne (@($expected | Sort-Object) -join '|')) {
    throw 'Invalid build receipt file set. Rebuild before packaging.'
  }
  foreach ($file in $receipt.files) {
    $full = Join-Path $Repo $file.path
    if (-not (Test-Path -LiteralPath $full -PathType Leaf) -or
        (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash -ne $file.sha256) {
      throw "Build output changed or missing: $($file.path). Rebuild before packaging."
    }
  }
}
