@echo off
setlocal
set "VE_CORE_TEST_VCVARS=%~1"
if not defined VE_CORE_TEST_VCVARS set "VE_CORE_TEST_VCVARS=%VEGAS_ENCODER_VCVARS%"
if not defined VE_CORE_TEST_VCVARS if exist "L:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat" set "VE_CORE_TEST_VCVARS=L:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat"
if defined VE_CORE_TEST_VCVARS (call "%VE_CORE_TEST_VCVARS%" >nul || exit /b 1) else (where cl >nul 2>nul || exit /b 1)
set "VE_CORE_TEST_ROOT=%~dp0.."
set "VE_CORE_TEST_OUT=%VE_CORE_TEST_ROOT%\build\core-tests"
if "%~2"=="asan" set "VE_CORE_TEST_OUT=%VE_CORE_TEST_ROOT%\build\core-tests-asan"
if not exist "%VE_CORE_TEST_OUT%" mkdir "%VE_CORE_TEST_OUT%"
pushd "%VE_CORE_TEST_OUT%" || exit /b 1
if "%~2"=="asan" goto :asan
cl /nologo /O2 /MT /W4 /WX /EHsc /std:c++17 /utf-8 "%VE_CORE_TEST_ROOT%\tests\core\core_tests.cpp" "%VE_CORE_TEST_ROOT%\build\release\vegas-encoder\core\ve_core_static.lib" /link /OUT:core-tests.exe || goto :fail
core-tests.exe "%VE_CORE_TEST_ROOT%\schema\fixtures\b0\core-and-services.json" "%VE_CORE_TEST_ROOT%\schema\fixtures\b1\core-argv.json" || goto :fail
popd
exit /b 0
:asan
cl /nologo /Od /Zi /MT /W4 /WX /EHsc /std:c++17 /utf-8 /fsanitize=address "%VE_CORE_TEST_ROOT%\tests\core\core_tests.cpp" "%VE_CORE_TEST_ROOT%\src\core\json.cpp" "%VE_CORE_TEST_ROOT%\src\core\text.cpp" "%VE_CORE_TEST_ROOT%\src\core\recipe.cpp" "%VE_CORE_TEST_ROOT%\src\core\signal.cpp" "%VE_CORE_TEST_ROOT%\src\core\compile.cpp" "%VE_CORE_TEST_ROOT%\src\core\lint.cpp" "%VE_CORE_TEST_ROOT%\src\core\payload.cpp" "%VE_CORE_TEST_ROOT%\src\core\capi\ve_core.cpp" /link /OUT:core-tests-asan.exe || goto :fail
core-tests-asan.exe "%VE_CORE_TEST_ROOT%\schema\fixtures\b0\core-and-services.json" "%VE_CORE_TEST_ROOT%\schema\fixtures\b1\core-argv.json" || goto :fail
popd
exit /b 0
:fail
popd
exit /b 1
