#Requires -Version 7.0
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$AppPath,
  [Parameter(Mandatory)][string]$FFmpegPath,
  [string]$VcVarsPath = 'L:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat'
)

$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out = Join-Path $repo ('build/test-results/older-vegas-' + (Get-Date -Format 'yyyyMMdd-HHmmssfff'))
$app = (Resolve-Path -LiteralPath $AppPath).Path
$ffmpeg = (Resolve-Path -LiteralPath $FFmpegPath).Path
$vcvars = (Resolve-Path -LiteralPath $VcVarsPath).Path
for ($ancestor = [IO.DirectoryInfo]$out; $null -ne $ancestor; $ancestor = $ancestor.Parent) {
  if ($ancestor.Exists -and ($ancestor.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    throw "Output traverses a reparse point: $ancestor"
  }
}
New-Item -ItemType Directory -Path $out | Out-Null
Write-Output "Building offline trials in $out"

$common = '/nologo /O2 /MT /W4 /WX /EHsc /std:c++17 /utf-8'
$libraries = 'ole32.lib oleaut32.lib user32.lib gdi32.lib version.lib bcrypt.lib'
function Sources([string[]]$relative) {
  ($relative | ForEach-Object { '"%VE_OLDER_ROOT%\' + $_ + '"' }) -join ' '
}
function Invoke-Commands([string]$directory, [string[]]$commands) {
  $batch = Join-Path $directory 'build.cmd'
  @('@echo off','setlocal','call "%VE_OLDER_VCVARS%" >nul || exit /b 1','cd /d "%~dp0" || exit /b 1') +
    ($commands | ForEach-Object { $_ + ' || exit /b 1' }) |
    Set-Content -LiteralPath $batch -Encoding ascii
  & cmd /d /c $batch 2>&1 | Tee-Object -FilePath (Join-Path $directory 'build.txt') | Out-Host
  if ($LASTEXITCODE -ne 0) { throw "Build failed in $directory" }
}
function Invoke-Check([string]$exe, [string[]]$arguments, [string]$log) {
  & $exe @arguments 2>&1 | Tee-Object -FilePath $log | Out-Host
  if ($LASTEXITCODE -ne 0) { throw "Check failed. See $log" }
}

$oldRoot = $env:VE_OLDER_ROOT
$oldOut = $env:VE_OLDER_OUT
$oldVc = $env:VE_OLDER_VCVARS
try {
  $env:VE_OLDER_ROOT = $repo
  $env:VE_OLDER_OUT = $out
  $env:VE_OLDER_VCVARS = $vcvars
  $core = Join-Path $out 'core'
  New-Item -ItemType Directory -Path $core | Out-Null
  $coreSources = Sources @('json','text','recipe','signal','compile','lint','payload','capi/ve_core' | ForEach-Object { "src/core/$_.cpp" })
  Invoke-Commands $core @(
    "cl $common /c /DVE_CORE_BUILD_DLL $coreSources"
    'lib /nologo /OUT:ve_core_static.lib json.obj text.obj recipe.obj signal.obj compile.obj lint.obj payload.obj ve_core.obj'
  )

  $fixture = Join-Path $repo 'schema/fixtures/b0/core-and-services.json'
  $catalog = Join-Path $repo 'schema/builtin-presets.v1.json'
  foreach ($profile in @(
    @{ Major=22; Build=248; Kernel='sharedk.dll' }
    @{ Major=21; Build=108; Kernel='vegas210k.dll' }
    @{ Major=13; Build=453; Kernel='vegas130k.dll' }
  )) {
    $major = $profile.Major
    $trial = Join-Path $out "vegas$major"
    $plugin = Join-Path $trial 'plugin'
    $checks = Join-Path $trial 'checks'
    New-Item -ItemType Directory -Path $plugin,$checks | Out-Null
    $flags = "/DVEGAS_ENCODER_B6_RECIPE_PROOF /DVEGAS_ENCODER_LEGACY_HOST=$major"
    $sourceList = Sources @(
      'src/vegas/adapter/plugin.cpp','src/vegas/adapter/render.cpp','src/support/diagnostics.cpp',
      'src/vegas/host/template.cpp','src/engine/encode.cpp','src/engine/progress.cpp',
      'src/engine/job_store.cpp','src/engine/recipe_job.cpp','src/vegas/configuration/recipe_template.cpp',
      'src/vegas/configuration/editor_session.cpp','src/vegas/configuration/recipe_page.cpp',
      'src/vegas/configuration/native_store.cpp','src/vegas/adapter/recipe_runtime.cpp'
    )
    $coreLib = '"%VE_OLDER_OUT%\core\ve_core_static.lib"'
    $version = Sources @('src/vegas/adapter/version.rc')
    $exports = Sources @('src/vegas/adapter/vegas-encoder.def')
    Invoke-Commands $trial @(
      "cl $common /c /Zi /Fd:compiler.pdb $flags $sourceList"
      "rc /nologo $flags /fo vegas-encoder.res $version"
      "link /nologo /DLL /DEBUG /IMPLIB:vegas-encoder.lib /OUT:plugin\vegas-encoder.dll /DEF:$exports plugin.obj render.obj diagnostics.obj template.obj encode.obj progress.obj job_store.obj recipe_job.obj recipe_template.obj editor_session.obj recipe_page.obj native_store.obj recipe_runtime.obj vegas-encoder.res $coreLib $libraries"
    )
    @(
      '[vegas-encoder]', 'LegacyAutoNames=1', 'OutputMode=ffmpeg', 'StreamTypes=3', 'Caps=0',
      "AppPath=$app", "FFmpegPath=$ffmpeg", "LogDir=$trial\logs", 'DetailCalls=16'
    ) | Set-Content -LiteralPath (Join-Path $plugin 'vegas-encoder.ini') -Encoding Unicode

    $testExe = "vegas${major}0.exe"
    $testRc = Sources @('tests/host/legacy_host_version.rc')
    $fakeSource = Sources @('tests/host/legacy_kernel.cpp')
    $fakeExports = Sources @('tests/host/legacy_kernel.def')
    $callbacks = Sources @('tests/host/manual_names.cpp')
    $render = Sources @('tests/host/recipe_render.cpp','tests/fiohost/fakehost.cpp')
    Invoke-Commands $checks @(
      "rc /nologo /dVE_TEST_MAJOR=$major /dVE_TEST_BUILD=$($profile.Build) /fo host.res $testRc"
      "cl $common $flags /LD $fakeSource host.res /link /DEF:$fakeExports /OUT:$($profile.Kernel)"
      "cl $common $flags $callbacks host.res ..\recipe_template.obj ..\template.obj ..\diagnostics.obj $coreLib /link /OUT:$testExe $libraries"
      "cl $common $flags $render ..\render.obj ..\recipe_template.obj ..\template.obj ..\diagnostics.obj ..\encode.obj ..\progress.obj ..\job_store.obj ..\recipe_job.obj $coreLib /link /OUT:recipe-render.exe $libraries psapi.lib"
    )
    Invoke-Check (Join-Path $checks $testExe) @((Join-Path $plugin 'vegas-encoder.dll'),$fixture,$catalog,'--auto') (Join-Path $trial 'callbacks.txt')
    Invoke-Check (Join-Path $checks 'recipe-render.exe') @($fixture,(Join-Path $trial 'renders'),$ffmpeg,'--legacy-auto-names') (Join-Path $trial 'renders.txt')
    $wrongHost = Join-Path $checks 'wrong-host.exe'
    Copy-Item -LiteralPath (Join-Path $checks $testExe) -Destination $wrongHost
    Invoke-Check $wrongHost @((Join-Path $plugin 'vegas-encoder.dll'),'--reject-host') (Join-Path $trial 'wrong-host.txt')
    Get-FileHash -LiteralPath (Join-Path $plugin 'vegas-encoder.dll'),(Join-Path $plugin 'vegas-encoder.ini') |
      ConvertTo-Json | Set-Content -LiteralPath (Join-Path $trial 'hashes.json')
  }
} finally {
  $env:VE_OLDER_ROOT = $oldRoot
  $env:VE_OLDER_OUT = $oldOut
  $env:VE_OLDER_VCVARS = $oldVc
}
Write-Output "All three isolated candidates and checks completed in $out"
