#Requires -Version 7.0
<# Compile/test an isolated native candidate. Does not install or launch VEGAS/app. #>
[CmdletBinding()]
param(
  [string]$OutputDir,
  [string]$VcVarsPath = 'L:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat',
  [string]$AppPath,
  [string]$FFmpegPath
)
$ErrorActionPreference = 'Stop'
$legacyRepo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$legacyBuild = Join-Path $legacyRepo 'build'
if (-not $OutputDir) { $OutputDir = Join-Path $legacyBuild ('test-results/legacy-containers-' + (Get-Date -Format 'yyyyMMdd-HHmmssfff')) }
$OutputDir = [IO.Path]::GetFullPath($OutputDir)
if (-not $OutputDir.StartsWith($legacyBuild + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Output must stay inside this checkout build folder.' }
if (Test-Path -LiteralPath $OutputDir) { throw 'Use a fresh output folder; earlier candidates remain intact.' }
for ($legacyAncestor = [IO.DirectoryInfo]$OutputDir; $null -ne $legacyAncestor; $legacyAncestor = $legacyAncestor.Parent) {
  if ($legacyAncestor.Exists -and ($legacyAncestor.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Output must not traverse reparse points.' }
}
if (-not $AppPath) { $AppPath = Join-Path $legacyRepo 'build/release/vegas-encoder/app/VegasEncoder.exe' }
$AppPath = (Resolve-Path -LiteralPath $AppPath).Path
$VcVarsPath = (Resolve-Path -LiteralPath $VcVarsPath).Path
if ($FFmpegPath) { $FFmpegPath = (Resolve-Path -LiteralPath $FFmpegPath).Path }
New-Item -ItemType Directory -Path $OutputDir | Out-Null
foreach ($legacyPart in @('core','modern','legacy','manual','auto','checks','logs')) { New-Item -ItemType Directory -Path (Join-Path $OutputDir $legacyPart) | Out-Null }
$legacyCommands = @'
@echo off
setlocal
call "%VE_LEGACY_VCVARS%" >nul || exit /b 1
set "R=%VE_LEGACY_ROOT%"
set "O=%VE_LEGACY_OUT%"
cd /d "%O%\core" || exit /b 1
cl /nologo /c /O2 /MT /W4 /WX /EHsc /std:c++17 /utf-8 /DVE_CORE_BUILD_DLL "%R%\src\core\json.cpp" "%R%\src\core\text.cpp" "%R%\src\core\recipe.cpp" "%R%\src\core\signal.cpp" "%R%\src\core\compile.cpp" "%R%\src\core\lint.cpp" "%R%\src\core\payload.cpp" "%R%\src\core\capi\ve_core.cpp" || exit /b 1
link /nologo /DLL /OUT:ve_core.dll json.obj text.obj recipe.obj signal.obj compile.obj lint.obj payload.obj ve_core.obj || exit /b 1
lib /nologo /OUT:ve_core_static.lib json.obj text.obj recipe.obj signal.obj compile.obj lint.obj payload.obj ve_core.obj || exit /b 1
cd /d "%O%\modern" || exit /b 1
cl /nologo /c /O2 /MT /W4 /WX /EHsc /std:c++17 /utf-8 /Zi /Fd:vegas-encoder.pdb /DVEGAS_ENCODER_B6_RECIPE_PROOF "%R%\src\vegas\adapter\plugin.cpp" "%R%\src\vegas\adapter\render.cpp" "%R%\src\support\diagnostics.cpp" "%R%\src\vegas\host\template.cpp" "%R%\src\engine\encode.cpp" "%R%\src\engine\progress.cpp" "%R%\src\engine\job_store.cpp" "%R%\src\engine\recipe_job.cpp" "%R%\src\vegas\configuration\recipe_template.cpp" "%R%\src\vegas\configuration\editor_session.cpp" "%R%\src\vegas\configuration\recipe_page.cpp" "%R%\src\vegas\configuration\native_store.cpp" "%R%\src\vegas\adapter\recipe_runtime.cpp" || exit /b 1
rc /nologo /DVEGAS_ENCODER_B6_RECIPE_PROOF /fo vegas-encoder.res "%R%\src\vegas\adapter\version.rc" || exit /b 1
link /nologo /DLL /DEBUG /OUT:vegas-encoder.dll /DEF:"%R%\src\vegas\adapter\vegas-encoder.def" plugin.obj render.obj diagnostics.obj template.obj encode.obj progress.obj job_store.obj recipe_job.obj "%O%\core\ve_core_static.lib" recipe_template.obj editor_session.obj recipe_page.obj native_store.obj recipe_runtime.obj vegas-encoder.res ole32.lib oleaut32.lib user32.lib gdi32.lib version.lib bcrypt.lib || exit /b 1
copy /y vegas-encoder.dll "%O%\legacy\vegas-encoder.dll" >nul || exit /b 1
copy /y vegas-encoder.dll "%O%\manual\vegas-encoder.dll" >nul || exit /b 1
copy /y vegas-encoder.dll "%O%\auto\vegas-encoder.dll" >nul || exit /b 1
cd /d "%O%\checks" || exit /b 1
cl /nologo /O2 /MT /W4 /WX /EHsc /std:c++17 /utf-8 "%R%\tests\core\core_tests.cpp" "%O%\core\ve_core_static.lib" /link /OUT:core-tests.exe || exit /b 1
core-tests.exe "%R%\schema\fixtures\b0\core-and-services.json" "%R%\schema\fixtures\b1\core-argv.json" || exit /b 1
cl /nologo /c /O2 /MT /W4 /WX /EHsc /std:c++17 /utf-8 /DVEGAS_ENCODER_B6_RECIPE_PROOF "%R%\src\vegas\configuration\recipe_template.cpp" "%R%\src\vegas\host\template.cpp" "%R%\src\support\diagnostics.cpp" || exit /b 1
cl /nologo /O2 /MT /W4 /WX /EHsc /std:c++17 /utf-8 /DVEGAS_ENCODER_B6_RECIPE_PROOF "%R%\tests\host\container_naming.cpp" recipe_template.obj template.obj diagnostics.obj "%O%\core\ve_core_static.lib" /link /OUT:container-naming.exe ole32.lib oleaut32.lib user32.lib version.lib bcrypt.lib || exit /b 1
cl /nologo /O2 /MT /W4 /WX /EHsc /std:c++17 /utf-8 /DVEGAS_ENCODER_B6_RECIPE_PROOF "%R%\tests\host\legacy_containers.cpp" recipe_template.obj template.obj diagnostics.obj "%O%\core\ve_core_static.lib" /link /OUT:legacy-containers.exe ole32.lib oleaut32.lib user32.lib version.lib bcrypt.lib || exit /b 1
cl /nologo /O2 /MT /W4 /WX /EHsc /std:c++17 /utf-8 /DVEGAS_ENCODER_B6_RECIPE_PROOF "%R%\tests\host\manual_names.cpp" recipe_template.obj template.obj diagnostics.obj "%O%\core\ve_core_static.lib" /link /OUT:manual-names.exe ole32.lib oleaut32.lib user32.lib version.lib bcrypt.lib || exit /b 1
cl /nologo /O2 /MT /W4 /WX /EHsc /std:c++17 /utf-8 /DVEGAS_ENCODER_B6_RECIPE_PROOF "%R%\tests\host\recipe_templates.cpp" "%R%\src\vegas\configuration\native_store.cpp" recipe_template.obj template.obj diagnostics.obj "%O%\core\ve_core_static.lib" /link /OUT:recipe-templates.exe ole32.lib oleaut32.lib user32.lib version.lib bcrypt.lib || exit /b 1
cl /nologo /O2 /MT /W4 /WX /EHsc /std:c++17 /utf-8 /DVEGAS_ENCODER_B6_RECIPE_PROOF "%R%\tests\host\recipe_runtime_checks.cpp" "%R%\src\vegas\adapter\recipe_runtime.cpp" template.obj diagnostics.obj "%O%\core\ve_core_static.lib" /link /OUT:recipe-runtime.exe ole32.lib oleaut32.lib user32.lib version.lib bcrypt.lib || exit /b 1
if not defined VE_LEGACY_FFMPEG exit /b 0
cl /nologo /O2 /MT /W4 /WX /EHsc /std:c++17 /utf-8 /DVEGAS_ENCODER_B6_RECIPE_PROOF "%R%\tests\host\recipe_render.cpp" "%R%\tests\fiohost\fakehost.cpp" "%O%\modern\render.obj" recipe_template.obj template.obj diagnostics.obj "%O%\modern\encode.obj" "%O%\modern\progress.obj" "%O%\modern\job_store.obj" "%O%\modern\recipe_job.obj" "%O%\core\ve_core_static.lib" /link /OUT:recipe-render.exe ole32.lib oleaut32.lib user32.lib gdi32.lib version.lib bcrypt.lib psapi.lib || exit /b 1
'@
$legacyBuildScript = Join-Path $OutputDir 'build-and-check.cmd'
Set-Content -LiteralPath $legacyBuildScript -Value $legacyCommands -Encoding ascii
$legacyOldEnv = @{}
foreach ($legacyKey in @('VE_LEGACY_ROOT','VE_LEGACY_OUT','VE_LEGACY_VCVARS','VE_LEGACY_FFMPEG')) { $legacyOldEnv[$legacyKey] = [Environment]::GetEnvironmentVariable($legacyKey) }
try {
  $env:VE_LEGACY_ROOT = $legacyRepo; $env:VE_LEGACY_OUT = $OutputDir; $env:VE_LEGACY_VCVARS = $VcVarsPath
  $env:VE_LEGACY_FFMPEG = $FFmpegPath
  foreach ($legacyMode in @('modern','legacy','manual','auto','checks')) {
    $legacyFlag = if ($legacyMode -in @('legacy','manual','auto')) { 1 } else { 0 }
    $manualFlag = if ($legacyMode -in @('manual','auto')) { 1 } else { 0 }
    $autoFlag = if ($legacyMode -eq 'auto') { 1 } else { 0 }
    $legacyIni = "[vegas-encoder]`r`nLegacyContainers=$legacyFlag`r`nLegacyManualNames=$manualFlag`r`nLegacyAutoNames=$autoFlag`r`nOutputMode=ffmpeg`r`nLogDir=$OutputDir\logs`r`nAppPath=$AppPath`r`nDetailCalls=2`r`n"
    Set-Content -LiteralPath (Join-Path $OutputDir "$legacyMode/vegas-encoder.ini") -Value $legacyIni -Encoding unicode
  }
  & cmd /d /c $legacyBuildScript 2>&1 | Tee-Object -FilePath (Join-Path $OutputDir 'build.txt')
  if ($LASTEXITCODE -ne 0) { throw "Native build/check failed; see $OutputDir/build.txt" }
  & (Join-Path $OutputDir 'checks/container-naming.exe') (Join-Path $OutputDir 'modern/vegas-encoder.dll') (Join-Path $legacyRepo 'schema/fixtures/b0/core-and-services.json') (Join-Path $legacyRepo 'schema/builtin-presets.v1.json') | Tee-Object -FilePath (Join-Path $OutputDir 'modern-checks.txt')
  if ($LASTEXITCODE -ne 0) { throw 'Modern callback regression.' }
  & (Join-Path $OutputDir 'checks/legacy-containers.exe') (Join-Path $OutputDir 'legacy/vegas-encoder.dll') (Join-Path $legacyRepo 'schema/builtin-presets.v1.json') | Tee-Object -FilePath (Join-Path $OutputDir 'legacy-checks.txt')
  if ($LASTEXITCODE -ne 0) { throw 'Legacy callback regression.' }
  & (Join-Path $OutputDir 'checks/manual-names.exe') (Join-Path $OutputDir 'manual/vegas-encoder.dll') (Join-Path $legacyRepo 'schema/fixtures/b0/core-and-services.json') (Join-Path $legacyRepo 'schema/builtin-presets.v1.json') | Tee-Object -FilePath (Join-Path $OutputDir 'manual-checks.txt')
  if ($LASTEXITCODE -ne 0) { throw 'Single-format manual naming regression.' }
  & (Join-Path $OutputDir 'checks/manual-names.exe') (Join-Path $OutputDir 'auto/vegas-encoder.dll') (Join-Path $legacyRepo 'schema/fixtures/b0/core-and-services.json') (Join-Path $legacyRepo 'schema/builtin-presets.v1.json') --auto | Tee-Object -FilePath (Join-Path $OutputDir 'auto-checks.txt')
  if ($LASTEXITCODE -ne 0) { throw 'Single-format automatic naming regression.' }
  & (Join-Path $OutputDir 'checks/recipe-templates.exe') (Join-Path $legacyRepo 'schema/fixtures/b0/core-and-services.json') | Tee-Object -FilePath (Join-Path $OutputDir 'template-checks.txt')
  if ($LASTEXITCODE -ne 0) { throw 'Native snapshot regression.' }
  & (Join-Path $OutputDir 'checks/recipe-runtime.exe') (Join-Path $OutputDir 'runtime-data') $AppPath | Tee-Object -FilePath (Join-Path $OutputDir 'runtime-checks.txt')
  if ($LASTEXITCODE -ne 0) { throw 'Native Apply/context regression.' }
  if ($FFmpegPath) {
    & (Join-Path $OutputDir 'checks/recipe-render.exe') (Join-Path $legacyRepo 'schema/fixtures/b0/core-and-services.json') (Join-Path $OutputDir 'modern-renders') $FFmpegPath --containers-only | Tee-Object -FilePath (Join-Path $OutputDir 'modern-renders.txt')
    if ($LASTEXITCODE -ne 0) { throw 'Modern fake-host/real-FFmpeg container regression.' }
    & (Join-Path $OutputDir 'checks/recipe-render.exe') (Join-Path $legacyRepo 'schema/fixtures/b0/core-and-services.json') (Join-Path $OutputDir 'auto-renders') $FFmpegPath --legacy-auto-names | Tee-Object -FilePath (Join-Path $OutputDir 'auto-renders.txt')
    if ($LASTEXITCODE -ne 0) { throw 'Automatic naming fake-host/real-FFmpeg render regression.' }
  }
  Write-Output "Isolated native candidate/checks complete: $OutputDir (not installed)."
} finally {
  foreach ($legacyKey in $legacyOldEnv.Keys) { [Environment]::SetEnvironmentVariable($legacyKey,$legacyOldEnv[$legacyKey]) }
}
