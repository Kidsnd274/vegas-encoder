@echo off
setlocal
set "VE_B6_ROOT=%~dp0.."
set "VE_B6_VCVARS=%~1"
if not defined VE_B6_VCVARS set "VE_B6_VCVARS=%VEGAS_ENCODER_VCVARS%"
if not defined VE_B6_VCVARS if exist "L:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat" set "VE_B6_VCVARS=L:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat"
if defined VE_B6_VCVARS (call "%VE_B6_VCVARS%" >nul || exit /b 1) else (where cl >nul 2>nul || exit /b 1)
set "VE_B6_OUT=%VE_B6_ROOT%\build\b6-tests"
set "VE_B6_FLAGS=/O2 /Zi"
set VE_B6_CORE="%VE_B6_ROOT%\build\core\ve_core_static.lib"
set "VE_B6_CORE_SOURCES="
if "%~2"=="asan" (
  set "VE_B6_OUT=%VE_B6_ROOT%\build\b6-tests-asan"
  set "VE_B6_FLAGS=/Od /Zi /fsanitize=address"
  set "VE_B6_CORE="
  set VE_B6_CORE_SOURCES="%VE_B6_ROOT%\src\core\json.cpp" "%VE_B6_ROOT%\src\core\text.cpp" "%VE_B6_ROOT%\src\core\recipe.cpp" "%VE_B6_ROOT%\src\core\signal.cpp" "%VE_B6_ROOT%\src\core\compile.cpp" "%VE_B6_ROOT%\src\core\lint.cpp" "%VE_B6_ROOT%\src\core\payload.cpp"
)
if not exist "%VE_B6_OUT%" mkdir "%VE_B6_OUT%"
pushd "%VE_B6_OUT%" || exit /b 1
cl /nologo %VE_B6_FLAGS% /MT /W4 /WX /EHsc /std:c++17 /utf-8 "%VE_B6_ROOT%\tests\host\recipe_templates.cpp" "%VE_B6_ROOT%\src\vegas\configuration\recipe_template.cpp" "%VE_B6_ROOT%\src\vegas\configuration\native_store.cpp" "%VE_B6_ROOT%\src\vegas\host\template.cpp" "%VE_B6_ROOT%\src\support\diagnostics.cpp" %VE_B6_CORE_SOURCES% %VE_B6_CORE% /link /OUT:recipe-templates.exe ole32.lib oleaut32.lib user32.lib version.lib bcrypt.lib || goto :fail
recipe-templates.exe "%VE_B6_ROOT%\schema\fixtures\b0\core-and-services.json" || goto :fail
popd
echo B6 OFFLINE SNAPSHOT/SESSION CHECKS OK; exporter integration remains disabled
exit /b 0
:fail
popd
exit /b 1
