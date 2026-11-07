#Requires -Version 7.0
<#
.SYNOPSIS
Render matrix: drives the actual exporter DLL through fiohost (fake host) for every
built-in preset across project shapes, project audio, lengths and FFmpeg builds,
then checks each output with a full FFprobe decode.
.DESCRIPTION
Build the release first (scripts/Build-Release.ps1) and fiohost (fixed-build step),
or pass -DllPath/-HostPath. Each row gets its own DLL copy, INI, isolated data root
(VEGAS_ENCODER_DATA_ROOT with a machine.json for that FFmpeg) and output folder.
Checks: fiohost's own host-contract checks, then exact decoded video frame count,
decoded audio sample count (exact for PCM; lossy codecs may add at most one codec
frame of padding), expected codecs, container family and channel count.
Hardware presets are skipped when the FFmpeg build cannot open their encoder.
The VEGAS 22, 21 and 13 DLLs refuse a host that is not their VEGAS, so their renders
stay covered by Build-OlderVegasTrials.ps1; this matrix covers the 2026/23 DLL in its
modern and legacy automatic-name modes. Fake-host results do not qualify real VEGAS.
-Quick: one build, modern profile, 1080p 29.97, all presets, 48 kHz and 44.1 kHz
stereo, 60 and 900 frames. -Full: every build, both profiles, four shapes, five
audio layouts, both lengths.
#>
[CmdletBinding()]
param(
  [switch] $Quick,
  [switch] $Full,
  [string[]] $FFmpegPath,
  [string] $DllPath,
  [string] $HostPath,
  [string] $PythonPath,
  [string] $OutputDir,
  [string] $Match   # optional regex on the row label (profile-preset-shape-frames-audio)
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Tools.ps1')
if ($Quick -eq $Full) { throw 'Choose exactly one of -Quick or -Full.' }
$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$builds = @(if ($FFmpegPath) { $FFmpegPath | ForEach-Object { Resolve-VeFFmpeg $_ } } else { Resolve-VeFFmpeg '' })
if ($Quick) { $builds = @($builds[0]) }
$python = Resolve-VePython $PythonPath
$dll = if ($DllPath) { (Resolve-Path -LiteralPath $DllPath).Path } else { Join-Path $repo 'build\release\vegas-encoder\plugin\vegas-encoder.dll' }
$fiohost = if ($HostPath) { (Resolve-Path -LiteralPath $HostPath).Path } else { Join-Path $repo 'build\fiohost\fiohost.exe' }
foreach ($required in $dll, $fiohost) { if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Required input missing: $required" } }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$root = if ($OutputDir) { $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDir) } else { Join-Path $repo "build\test-results\render-matrix-$stamp" }
if (Test-Path -LiteralPath $root) { throw "Output folder exists; use a fresh one: $root" }
New-Item -ItemType Directory -Path $root | Out-Null
$iniSource = Get-Content -Raw -LiteralPath (Join-Path $repo 'config\vegas-encoder.ini')
$builtins = (Get-Content -Raw -LiteralPath (Join-Path $repo 'schema\builtin-presets.v1.json') | ConvertFrom-Json -AsHashtable)
$builtins = if ($builtins -is [System.Collections.IDictionary] -and $builtins.ContainsKey('presets')) { $builtins.presets } else { $builtins }

$profiles = if ($Quick) { @('modern') } else { @('modern', 'legacy-names') }
$shapes = @(@{ label = '1080p29.97'; size = '1920x1080'; num = 30000; den = 1001 })
if ($Full) {
  $shapes = @(@{ label = '720p23.976'; size = '1280x720'; num = 24000; den = 1001 }) + $shapes +
    @(@{ label = '1080p59.94'; size = '1920x1080'; num = 60000; den = 1001 }, @{ label = '2160p25'; size = '3840x2160'; num = 25; den = 1 })
}
$audios = @(@{ label = '48k-stereo'; rate = 48000; channels = 2 }, @{ label = '44.1k-stereo'; rate = 44100; channels = 2 })
if ($Full) { $audios += @(@{ label = '48k-mono'; rate = 48000; channels = 1 }, @{ label = '48k-5.1'; rate = 48000; channels = 6 }, @{ label = 'none'; rate = 0; channels = 0 }) }
$lengths = @(60, 900)
$videoCodecs = @{ libx264 = 'h264'; h264_nvenc = 'h264'; libx265 = 'hevc'; hevc_nvenc = 'hevc'; libsvtav1 = 'av1'; av1_nvenc = 'av1'
  prores_ks = 'prores'; dnxhd = 'dnxhd'; ffv1 = 'ffv1'; 'libvpx-vp9' = 'vp9' }
$audioCodecs = @{ aac = 'aac'; libopus = 'opus'; pcm_s24le = 'pcm_s24le'; pcm_s16le = 'pcm_s16le'; pcm_f32le = 'pcm_f32le' }
$families = @{ mp4 = 'mp4'; mov = 'mov'; mkv = 'matroska'; webm = 'webm'; mxf = 'mxf' }

function New-Case([string] $Dir, [string] $Profile, [string] $FFmpeg, [hashtable] $Audio) {
  $plugin = Join-Path $Dir 'plugin'; $data = Join-Path $Dir 'data'
  New-Item -ItemType Directory -Path $plugin, (Join-Path $data 'Roaming'), (Join-Path $data 'Local'), (Join-Path $Dir 'out'), (Join-Path $Dir 'logs') | Out-Null
  Copy-Item -LiteralPath $dll -Destination $plugin
  $ini = $iniSource -replace '(?m)^ShowEncoderErrors=.*$', 'ShowEncoderErrors=0'
  $ini = $ini -replace '(?m)^LegacyAutoNames=.*$', "LegacyAutoNames=$(if ($Profile -eq 'legacy-names') { 1 } else { 0 })"
  $ini += "`r`nLogDir=$(Join-Path $Dir 'logs')`r`n"
  $ini | Set-Content -LiteralPath (Join-Path $plugin 'vegas-encoder.ini') -Encoding unicode
  $probe = Join-Path (Split-Path -Parent $FFmpeg) 'ffprobe.exe'
  $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $FFmpeg).Hash.ToLowerInvariant()
  $libraries = [ordered]@{}
  Get-ChildItem -LiteralPath (Split-Path -Parent $FFmpeg) -Filter '*.dll' | Where-Object { $_.Name -match '^(av|sw|postproc)' } |
    ForEach-Object { $libraries[$_.Name] = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash.ToLowerInvariant() }
  $installation = [ordered]@{ id = 'matrix'; label = 'Render matrix'; path = $FFmpeg; ffprobePath = $probe; source = 'manual'; version = 'render matrix'
    identity = [ordered]@{ sha256 = $hash; key = $hash; libraries = $libraries }
    extensions = @{ ffprobeIdentity = @{ sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $probe).Hash.ToLowerInvariant() } } }
  @{ machine = 1; defaultFFmpegId = 'matrix'; installations = @($installation); verifyOutput = $true; progressWindow = $false } |
    ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $data 'Roaming\machine.json') -Encoding utf8NoBOM
  $rate = if ($Audio.rate) { $Audio.rate } else { 48000 }; $channels = if ($Audio.channels) { $Audio.channels } else { 2 }
  & $python -I (Join-Path $repo 'scripts\etc\Make-HostTemplate.py') (Join-Path $Dir 'host.tpl') --sample-rate $rate --channels $channels | Out-Null
  if ($LASTEXITCODE) { throw 'Make-HostTemplate.py failed' }
  return @{ plugin = Join-Path $plugin 'vegas-encoder.dll'; data = $data; out = Join-Path $Dir 'out'; tpl = Join-Path $Dir 'host.tpl'; probe = $probe }
}

function Invoke-Fiohost([hashtable] $Case, [string[]] $Arguments) {
  $env:VEGAS_ENCODER_DATA_ROOT = $Case.data
  try { $text = & $fiohost $Case.plugin $Case.out '--no-wmi' '--render' $Case.tpl @Arguments 2>&1 | Out-String }
  finally { Remove-Item Env:VEGAS_ENCODER_DATA_ROOT -ErrorAction SilentlyContinue }
  return @{ exit = $LASTEXITCODE; text = $text }
}

# The DLL's visible preset templates map to the built-ins by name.
$discovery = New-Case (Join-Path $root 'discovery') 'modern' $builds[0] $audios[0]
[void](Invoke-Fiohost $discovery @('--preset', '1', '--size', '320x180', '--fps', '30', '--frames', '1', '--extension', 'mkv'))
$presets = foreach ($file in Get-ChildItem -LiteralPath $discovery.out -Filter 'preset-*.tpl') {
  $index = [int]($file.BaseName -replace '\D', '')
  $text = [Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($file.FullName))
  $builtin = $builtins | Where-Object { $text.Contains([string]$_.recipe.name) } | Sort-Object { ([string]$_.recipe.name).Length } -Descending | Select-Object -First 1
  if ($builtin -and $index -gt 1) { @{ index = $index; recipe = $builtin.recipe } }
}
$presets = @($presets | Sort-Object { $_.index })
if ($presets.Count -ne $builtins.Count) { throw "Found $($presets.Count) preset templates for $($builtins.Count) built-ins." }

$results = [Collections.Generic.List[object]]::new()
foreach ($ffmpeg in $builds) {
  $available = @{}
  foreach ($preset in $presets) {
    $encoder = [string]$preset.recipe.video.encoder
    if ($encoder -notmatch '_(nvenc|qsv|amf)$' -or $available.ContainsKey($encoder)) { continue }
    & $ffmpeg -hide_banner -v error -f lavfi -i 'color=s=256x256:d=0.04' -frames:v 1 -c:v $encoder -f null - 2>$null | Out-Null
    $available[$encoder] = $LASTEXITCODE -eq 0
  }
  foreach ($profile in $profiles) { foreach ($shape in $shapes) { foreach ($audio in $audios) { foreach ($length in $lengths) { foreach ($preset in $presets) {
    $recipe = $preset.recipe; $container = [string]$recipe.container.format
    $label = '{0}-{1}-{2}-{3}f-{4}' -f $profile, ($recipe.name -replace '[^A-Za-z0-9]+', ''), $shape.label, $length, $audio.label
    if ($Match -and $label -notmatch $Match) { continue }
    $name = "$($results.Count)-$label"
    $row = [ordered]@{ case = $name; ffmpeg = Split-Path -Leaf (Split-Path -Parent (Split-Path -Parent $ffmpeg)); profile = $profile; preset = $recipe.name
      shape = $shape.label; audio = $audio.label; frames = $length; status = 'pass'; reason = ''; elapsedSec = 0 }
    $encoder = [string]$recipe.video.encoder
    if ($available.ContainsKey($encoder) -and -not $available[$encoder]) {
      $row.status = 'skipped'; $row.reason = "$encoder is unavailable in this FFmpeg build"; $results.Add([pscustomobject]$row); continue
    }
    $started = Get-Date
    try {
      $case = New-Case (Join-Path $root $name) $profile $ffmpeg $audio
      $extension = if ($profile -eq 'legacy-names') { 'vencoder' } else { $container }
      $fps = ([double]$shape.num / $shape.den).ToString('R', [Globalization.CultureInfo]::InvariantCulture)
      $arguments = @('--preset', $preset.index, '--size', $shape.size, '--fps', $fps, '--frames', $length, '--extension', $extension)
      if (-not $audio.rate) { $arguments += '--video-only' }
      $run = Invoke-Fiohost $case $arguments
      $run.text | Set-Content -LiteralPath (Join-Path (Join-Path $root $name) 'fiohost.txt') -Encoding utf8
      $output = Join-Path $case.out "render-1.$(if ($container -eq 'mkv') { 'mkv' } else { $container })"
      if ($run.exit -ne 0 -or -not (Test-Path -LiteralPath $output)) {
        # fiohost can exit before the asynchronous record writer finishes; the live status already has the reason.
        $files = @(Get-ChildItem -LiteralPath (Join-Path $case.data 'Local\jobs') -Filter '*.json' -ErrorAction SilentlyContinue)
        $record = $files | Where-Object { $_.Name -notmatch '\.live\.json$' } | Select-Object -First 1
        if (-not $record) { $record = $files | Where-Object { $_.Name -match '\.live\.json$' } | Select-Object -First 1 }
        $why = if ($record) { (Get-Content -Raw -LiteralPath $record.FullName | ConvertFrom-Json).message } else { 'no job record or live status' }
        throw "fiohost exit $($run.exit): $why"
      }
      $info = & $case.probe -v error -count_frames -show_entries 'stream=codec_type,codec_name,channels,sample_rate,nb_read_frames:format=format_name' -of json $output | ConvertFrom-Json
      $video = @($info.streams | Where-Object codec_type -eq 'video'); $audioStreams = @($info.streams | Where-Object codec_type -eq 'audio')
      if ($video.Count -ne 1 -or [int64]$video[0].nb_read_frames -ne $length) { throw "decoded $($video[0].nb_read_frames) video frames, expected $length" }
      if ($video[0].codec_name -ne $videoCodecs[$encoder]) { throw "video codec $($video[0].codec_name), expected $($videoCodecs[$encoder])" }
      if (-not ((',' + $info.format.format_name + ',').Contains(',' + $families[$container] + ','))) { throw "container $($info.format.format_name), expected $container" }
      $audioOn = [bool]$recipe.audio[0].enabled -and $audio.rate
      if (-not $audioOn) { if ($audioStreams.Count) { throw 'unexpected audio stream' } }
      else {
        $audioEncoder = [string]$recipe.audio[0].encoder
        if ($audioStreams.Count -ne 1 -or $audioStreams[0].codec_name -ne $audioCodecs[$audioEncoder]) { throw "audio codec $($audioStreams[0].codec_name), expected $($audioCodecs[$audioEncoder])" }
        if ([int]$audioStreams[0].channels -ne $audio.channels) { throw "audio channels $($audioStreams[0].channels), expected $($audio.channels)" }
        $samples = (& $case.probe -v error -select_streams a:0 -show_entries frame=nb_samples -of csv=p=0 $output | Measure-Object -Sum).Sum
        # A chosen rate is exact; "source" keeps the project rate unless the core resampled it to 48 kHz (decision D11).
        $outputRate = [int]$audioStreams[0].sample_rate
        $allowed = if ($recipe.audio[0].sampleRate -is [ValueType]) { @([int]$recipe.audio[0].sampleRate) } else { @($audio.rate, 48000) }
        if ($outputRate -notin $allowed) { throw "audio rate $outputRate Hz, expected $($allowed -join ' or ') Hz" }
        $row.audioRate = $outputRate
        $expected = [math]::Round([double]$length * $outputRate * $shape.den / $shape.num)
        $row.audioSamples = $samples; $row.expectedSamples = $expected
        $slack = if ($audioEncoder -like 'pcm_*') { 1 } else { 2048 }
        if ([math]::Abs($samples - $expected) -gt $slack) { throw "decoded $samples audio samples, expected $expected" }
      }
      $row.videoFrames = [int64]$video[0].nb_read_frames
    } catch { $row.status = 'fail'; $row.reason = $_.Exception.Message }
    $row.elapsedSec = [math]::Round(((Get-Date) - $started).TotalSeconds, 1)
    $results.Add([pscustomobject]$row)
    Write-Output ('{0,-7} {1} {2}' -f $row.status.ToUpperInvariant(), $name, $row.reason)
  } } } } }
}
$summary = [ordered]@{ mode = if ($Quick) { 'quick' } else { 'full' }; validation = 'fiohost fake host, actual exporter DLL, real FFmpeg; not real VEGAS'
  passed = @($results | Where-Object status -eq 'pass').Count; failed = @($results | Where-Object status -eq 'fail').Count
  skipped = @($results | Where-Object status -eq 'skipped').Count; rows = $results }
$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $root 'summary.json') -Encoding utf8
Write-Output "Render matrix: $($summary.passed) passed, $($summary.failed) failed, $($summary.skipped) skipped. Summary: $(Join-Path $root 'summary.json')"
if ($summary.failed) { exit 1 }
