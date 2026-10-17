@echo off
setlocal
set "VE_BUILD_VCVARS=%~1"
if not defined VE_BUILD_VCVARS set "VE_BUILD_VCVARS=%VEGAS_ENCODER_VCVARS%"
if not defined VE_BUILD_VCVARS if exist "L:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat" set "VE_BUILD_VCVARS=L:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat"
if defined VE_BUILD_VCVARS (
  call "%VE_BUILD_VCVARS%" >nul || exit /b 1
) else (
  where cl >nul 2>nul || (echo Run from an x64 MSVC developer prompt or pass vcvars64.bat. & exit /b 1)
)
set "VE_BUILD_ROOT=%~dp0.."
call "%~dp0build-core.cmd" "%VE_BUILD_VCVARS%" || exit /b 1
set "VE_BUILD_PLUGIN=%VE_BUILD_ROOT%\build\vegas-encoder"
set "VE_BUILD_PROOF_FLAGS="
set "VE_BUILD_PROOF_SOURCES="
set "VE_BUILD_PROOF_OBJECTS="
if "%~2"=="configuration-proof" (
  set "VE_BUILD_PLUGIN=%VE_BUILD_ROOT%\build\configuration-proof\vegas-encoder"
  set "VE_BUILD_PROOF_FLAGS=/DVEGAS_ENCODER_CONFIGURATION_PROOF"
  set VE_BUILD_PROOF_SOURCES="%VE_BUILD_ROOT%\src\vegas\configuration\template_draft.cpp" "%VE_BUILD_ROOT%\src\vegas\configuration\proof_page.cpp" "%VE_BUILD_ROOT%\src\vegas\configuration\native_store.cpp"
  set "VE_BUILD_PROOF_OBJECTS=template_draft.obj proof_page.obj native_store.obj"
)
if "%~2"=="progress-text-proof" (
  set "VE_BUILD_PLUGIN=%VE_BUILD_ROOT%\build\progress-text-proof\vegas-encoder"
  set "VE_BUILD_PROOF_FLAGS=/DVEGAS_ENCODER_CONFIGURATION_PROOF /DVEGAS_ENCODER_PROGRESS_TEXT_PROOF"
  set VE_BUILD_PROOF_SOURCES="%VE_BUILD_ROOT%\src\vegas\configuration\template_draft.cpp" "%VE_BUILD_ROOT%\src\vegas\configuration\proof_page.cpp" "%VE_BUILD_ROOT%\src\vegas\configuration\native_store.cpp"
  set "VE_BUILD_PROOF_OBJECTS=template_draft.obj proof_page.obj native_store.obj"
)
set "VE_BUILD_TESTS=%VE_BUILD_ROOT%\build\fiohost"
set "VE_BUILD_MODE=%~2"
rem Retain the old argument as an alias, but never write to the legacy folder.
if "%VE_BUILD_MODE%"=="recipe-proof" set "VE_BUILD_MODE=release"
if "%VE_BUILD_MODE%"=="release" (
  set "VE_BUILD_PLUGIN=%VE_BUILD_ROOT%\build\release\vegas-encoder"
  set "VE_BUILD_PROOF_FLAGS=/DVEGAS_ENCODER_B6_RECIPE_PROOF"
  set VE_BUILD_PROOF_SOURCES="%VE_BUILD_ROOT%\src\vegas\configuration\recipe_template.cpp" "%VE_BUILD_ROOT%\src\vegas\configuration\editor_session.cpp" "%VE_BUILD_ROOT%\src\vegas\configuration\recipe_page.cpp" "%VE_BUILD_ROOT%\src\vegas\configuration\native_store.cpp" "%VE_BUILD_ROOT%\src\vegas\adapter\recipe_runtime.cpp"
  set "VE_BUILD_PROOF_OBJECTS=recipe_template.obj editor_session.obj recipe_page.obj native_store.obj recipe_runtime.obj"
)
set "VE_BUILD_HELPERS=%VE_BUILD_ROOT%\build\host-tests"
if not exist "%VE_BUILD_PLUGIN%" mkdir "%VE_BUILD_PLUGIN%"
if not exist "%VE_BUILD_TESTS%" mkdir "%VE_BUILD_TESTS%"
if not exist "%VE_BUILD_HELPERS%" mkdir "%VE_BUILD_HELPERS%"
pushd "%VE_BUILD_PLUGIN%" || exit /b 1
cl /nologo /c /O2 /MT /W4 /WX /EHsc /std:c++17 /utf-8 /Zi /Fd:vegas-encoder.pdb %VE_BUILD_PROOF_FLAGS% "%VE_BUILD_ROOT%\src\vegas\adapter\plugin.cpp" "%VE_BUILD_ROOT%\src\vegas\adapter\render.cpp" "%VE_BUILD_ROOT%\src\support\diagnostics.cpp" "%VE_BUILD_ROOT%\src\vegas\host\template.cpp" "%VE_BUILD_ROOT%\src\engine\encode.cpp" "%VE_BUILD_ROOT%\src\engine\progress.cpp" "%VE_BUILD_ROOT%\src\engine\job_store.cpp" "%VE_BUILD_ROOT%\src\engine\recipe_job.cpp" %VE_BUILD_PROOF_SOURCES% || goto :fail
rc /nologo %VE_BUILD_PROOF_FLAGS% /fo vegas-encoder.res "%VE_BUILD_ROOT%\src\vegas\adapter\version.rc" || goto :fail
link /nologo /DLL /DEBUG /OUT:vegas-encoder.dll /DEF:"%VE_BUILD_ROOT%\src\vegas\adapter\vegas-encoder.def" plugin.obj render.obj diagnostics.obj template.obj encode.obj progress.obj job_store.obj recipe_job.obj "%VE_BUILD_ROOT%\build\core\ve_core_static.lib" %VE_BUILD_PROOF_OBJECTS% vegas-encoder.res ole32.lib oleaut32.lib user32.lib gdi32.lib version.lib bcrypt.lib || goto :fail
copy /y "%VE_BUILD_ROOT%\config\vegas-encoder.ini" vegas-encoder.ini >nul || goto :fail
popd
pushd "%VE_BUILD_TESTS%" || exit /b 1
cl /nologo /O2 /MT /W4 /WX /EHsc /std:c++17 /Zi "%VE_BUILD_ROOT%\tests\fiohost\fiohost.cpp" "%VE_BUILD_ROOT%\tests\fiohost\fakehost.cpp" /link /OUT:fiohost.exe ole32.lib oleaut32.lib wbemuuid.lib user32.lib || goto :fail
popd
pushd "%VE_BUILD_HELPERS%" || exit /b 1
cl /nologo /O2 /MT /W4 /WX /EHsc /std:c++17 /Zi "%VE_BUILD_ROOT%\tests\host\host_helpers.cpp" "%VE_BUILD_ROOT%\src\vegas\host\template.cpp" /link /OUT:host-helpers.exe ole32.lib oleaut32.lib || goto :fail
cl /nologo /O2 /MT /W4 /WX /EHsc /std:c++17 /Zi "%VE_BUILD_ROOT%\tests\host\native_boundary.cpp" /link /OUT:native-boundary.exe || goto :fail
cl /nologo /O2 /MT /W4 /WX /EHsc /std:c++17 /Zi "%VE_BUILD_ROOT%\tests\host\native_progress.cpp" /link /OUT:native-progress.exe ole32.lib || goto :fail
cl /nologo /O2 /MT /W4 /WX /EHsc /std:c++17 /Zi "%VE_BUILD_ROOT%\tests\host\native_configuration.cpp" "%VE_BUILD_ROOT%\src\vegas\configuration\template_draft.cpp" "%VE_BUILD_ROOT%\src\vegas\configuration\proof_page.cpp" "%VE_BUILD_ROOT%\src\vegas\configuration\native_store.cpp" "%VE_BUILD_ROOT%\src\vegas\host\template.cpp" /link /OUT:native-configuration.exe ole32.lib user32.lib gdi32.lib || goto :fail
popd
echo BUILD OK: Vegas Encoder, fiohost and native helpers
exit /b 0
:fail
popd
echo BUILD FAILED
exit /b 1
