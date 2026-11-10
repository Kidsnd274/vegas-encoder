# Tool lookup shared by the scripts; dot-source this file. Each tool comes from
# the explicit parameter, then its environment variable, then PATH. MSVC also
# accepts an active x64 developer prompt and finally asks vswhere. Never add a
# machine-specific default here.
function Resolve-VeCommand([string]$Value, [string]$Variable, [string[]]$Names, [string]$Parameter) {
  $sources = @(@{ value = $Value; from = "-$Parameter" })
  if ($Variable) { $sources += @{ value = [Environment]::GetEnvironmentVariable($Variable); from = $Variable } }
  foreach ($source in $sources) {
    if (-not $source.value) { continue }
    if (Test-Path -LiteralPath $source.value -PathType Leaf) { return (Resolve-Path -LiteralPath $source.value).Path }
    $command = Get-Command -Name $source.value -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) { return $command.Source }
    throw "$($source.value) (from $($source.from)) was not found."
  }
  foreach ($name in $Names) {
    $command = Get-Command -Name $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) { return $command.Source }
  }
  $hint = if ($Variable) { ", set $Variable" } else { '' }
  throw "$($Names[0]) was not found. Pass -$Parameter$hint, or add it to PATH."
}

function Resolve-VePython([string]$Path) { Resolve-VeCommand $Path 'VEGAS_ENCODER_PYTHON' @('python.exe') 'PythonPath' }
function Resolve-VeFlutter([string]$Path) { Resolve-VeCommand $Path 'VEGAS_ENCODER_FLUTTER' @('flutter.bat') 'FlutterPath' }
function Resolve-VeFFmpeg([string]$Path) { Resolve-VeCommand $Path 'VEGAS_ENCODER_FFMPEG' @('ffmpeg.exe') 'FFmpegPath' }

function Resolve-VeDart([string]$Path) {
  if ($Path) { return Resolve-VeCommand $Path '' @('dart.exe') 'DartPath' }
  # Prefer the Dart SDK of the selected Flutter, so both always match.
  $flutter = $null
  try { $flutter = Resolve-VeFlutter '' } catch { }
  if ($flutter) {
    $dart = Join-Path (Split-Path -Parent $flutter) 'cache\dart-sdk\bin\dart.exe'
    if (Test-Path -LiteralPath $dart -PathType Leaf) { return $dart }
  }
  try { return Resolve-VeCommand '' '' @('dart.exe', 'dart.bat') 'DartPath' }
  catch { throw 'Dart was not found. Pass -DartPath, set VEGAS_ENCODER_FLUTTER, or add dart to PATH.' }
}

# Returns vcvars64.bat, or '' when an x64 developer prompt is already active.
function Resolve-VeVcVars([string]$Path) {
  foreach ($candidate in @($Path, $env:VEGAS_ENCODER_VCVARS)) {
    if (-not $candidate) { continue }
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { throw "vcvars64.bat was not found: $candidate" }
    return (Resolve-Path -LiteralPath $candidate).Path
  }
  if ($env:INCLUDE -and (Get-Command -Name cl.exe -CommandType Application -ErrorAction SilentlyContinue)) { return '' }
  $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
  if (Test-Path -LiteralPath $vswhere -PathType Leaf) {
    $found = & $vswhere -latest -prerelease -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -find 'VC\Auxiliary\Build\vcvars64.bat' |
      Select-Object -First 1
    if ($found -and (Test-Path -LiteralPath $found -PathType Leaf)) { return $found }
  }
  throw 'MSVC x64 tools were not found. Pass -VcVarsPath, set VEGAS_ENCODER_VCVARS to vcvars64.bat, or run from an x64 developer prompt.'
}
