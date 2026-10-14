@echo off
setlocal
set "VE_B4_ROOT=%~dp0.."
set "VE_B4_VCVARS=%~1"
if not defined VE_B4_VCVARS set "VE_B4_VCVARS=%VEGAS_ENCODER_VCVARS%"
if not defined VE_B4_VCVARS set "VE_B4_VCVARS=L:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat"
call "%VE_B4_VCVARS%" >nul || exit /b 1
set "VE_B4_OUT=%VE_B4_ROOT%\build\b4-tests"
set "VE_B4_FLAGS=/O2 /Zi"
set VE_B4_CORE="%VE_B4_ROOT%\build\core\ve_core_static.lib"
set "VE_B4_CORE_SOURCES="
if "%~2"=="asan" (
  set "VE_B4_OUT=%VE_B4_ROOT%\build\b4-tests-asan"
  set "VE_B4_FLAGS=/Od /Zi /fsanitize=address /DVE_B4_ASAN"
  set "VE_B4_CORE="
  set VE_B4_CORE_SOURCES="%VE_B4_ROOT%\src\core\json.cpp" "%VE_B4_ROOT%\src\core\text.cpp" "%VE_B4_ROOT%\src\core\recipe.cpp" "%VE_B4_ROOT%\src\core\signal.cpp" "%VE_B4_ROOT%\src\core\compile.cpp" "%VE_B4_ROOT%\src\core\lint.cpp" "%VE_B4_ROOT%\src\core\payload.cpp"
)
if not exist "%VE_B4_OUT%" mkdir "%VE_B4_OUT%"
pushd "%VE_B4_OUT%" || exit /b 1
cl /nologo /c %VE_B4_FLAGS% /MT /W4 /WX /EHsc /std:c++17 /utf-8 "%VE_B4_ROOT%\src\engine\encode.cpp" "%VE_B4_ROOT%\src\engine\progress.cpp" "%VE_B4_ROOT%\src\engine\job_store.cpp" "%VE_B4_ROOT%\src\engine\recipe_job.cpp" || goto :fail
if not exist "%VE_B4_ROOT%\tests\engine\recipe_jobs.cpp" goto :done
cl /nologo %VE_B4_FLAGS% /MT /W4 /WX /EHsc /std:c++17 /utf-8 "%VE_B4_ROOT%\tests\engine\recipe_jobs.cpp" "%VE_B4_ROOT%\tests\fiohost\fakehost.cpp" "%VE_B4_ROOT%\src\support\diagnostics.cpp" "%VE_B4_ROOT%\src\vegas\host\template.cpp" %VE_B4_CORE_SOURCES% encode.obj progress.obj job_store.obj recipe_job.obj %VE_B4_CORE% /link /OUT:recipe-jobs.exe ole32.lib oleaut32.lib user32.lib gdi32.lib version.lib bcrypt.lib psapi.lib || goto :fail
:done
if "%~2"=="asan" if not "%~3"=="" (
  set "ASAN_OPTIONS=quarantine_size_mb=8:thread_local_quarantine_size_kb=64"
  recipe-jobs.exe "%~3" "%~4" --snapshots "%~5" "%~6" || goto :fail
)
popd
exit /b 0
:fail
popd
exit /b 1
