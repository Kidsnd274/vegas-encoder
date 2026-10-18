@echo off
setlocal
set "VE_SETUP_VCVARS=%VEGAS_ENCODER_VCVARS%"
if not defined VE_SETUP_VCVARS if exist "L:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat" set "VE_SETUP_VCVARS=L:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat"
if defined VE_SETUP_VCVARS (call "%VE_SETUP_VCVARS%" >nul || exit /b 1) else (where cl >nul 2>nul || exit /b 1)
set "VE_SETUP_ROOT=%~dp0.."
set "VE_SETUP_OUT=%VE_SETUP_ROOT%\build\release\vegas-encoder\setup"
set "VE_SETUP_FLAGS="
if "%~1"=="test" (
  set "VE_SETUP_OUT=%VE_SETUP_ROOT%\build\test-results\setup-helper"
  set "VE_SETUP_FLAGS=/DVE_SETUP_TESTING"
)
if not exist "%VE_SETUP_OUT%" mkdir "%VE_SETUP_OUT%"
pushd "%VE_SETUP_OUT%" || exit /b 1
cl /nologo /O2 /MT /W4 /WX /EHsc /std:c++17 /utf-8 %VE_SETUP_FLAGS% "%VE_SETUP_ROOT%\setup\native\install.cpp" /link /OUT:ve-install.exe bcrypt.lib advapi32.lib shell32.lib ole32.lib version.lib
set "VE_SETUP_EXIT=%ERRORLEVEL%"
popd
exit /b %VE_SETUP_EXIT%
