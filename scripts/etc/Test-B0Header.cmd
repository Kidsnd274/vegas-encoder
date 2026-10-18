@echo off
setlocal
set "VE_B0_VCVARS=%~1"
if not defined VE_B0_VCVARS set "VE_B0_VCVARS=%VEGAS_ENCODER_VCVARS%"
if not defined VE_B0_VCVARS if exist "L:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat" set "VE_B0_VCVARS=L:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat"
if defined VE_B0_VCVARS (
  call "%VE_B0_VCVARS%" >nul || exit /b 1
) else (
  where cl >nul 2>nul || (echo Run from an x64 MSVC developer prompt or pass vcvars64.bat. & exit /b 1)
)
set "VE_B0_ROOT=%~dp0..\.."
if not exist "%VE_B0_ROOT%\build\core-tests" mkdir "%VE_B0_ROOT%\build\core-tests"
pushd "%VE_B0_ROOT%\build\core-tests" || exit /b 1
cl /nologo /W4 /WX /EHsc /std:c++17 "%VE_B0_ROOT%\tests\core\capi_header.cpp" /Fe:capi-header-cpp.exe || goto :fail
capi-header-cpp.exe || goto :fail
cl /nologo /W4 /WX /TC "%VE_B0_ROOT%\tests\core\capi_header.c" /Fe:capi-header-c.exe || goto :fail
capi-header-c.exe || goto :fail
popd
echo ABI HEADER PASSED: C and C++17, x64 /W4 /WX; declarations and layout only
exit /b 0
:fail
popd
exit /b 1
