@echo off
setlocal
set "VE_NAMING_ROOT=%~dp0.."
set "VE_NAMING_VCVARS=%VEGAS_ENCODER_VCVARS%"
if not defined VE_NAMING_VCVARS set "VE_NAMING_VCVARS=L:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat"
call "%VE_NAMING_VCVARS%" >nul || exit /b 1
set "VE_NAMING_OUT=%VE_NAMING_ROOT%\build\test-results\container-naming"
if not exist "%VE_NAMING_OUT%" mkdir "%VE_NAMING_OUT%"
pushd "%VE_NAMING_OUT%" || exit /b 1
cl /nologo /O2 /MT /W4 /WX /EHsc /std:c++17 /utf-8 "%VE_NAMING_ROOT%\tests\host\container_naming.cpp" "%VE_NAMING_ROOT%\src\vegas\configuration\recipe_template.cpp" "%VE_NAMING_ROOT%\src\vegas\host\template.cpp" "%VE_NAMING_ROOT%\src\support\diagnostics.cpp" "%VE_NAMING_ROOT%\build\release\vegas-encoder\core\ve_core_static.lib" /link /OUT:container-naming.exe ole32.lib oleaut32.lib user32.lib version.lib bcrypt.lib || goto :fail
container-naming.exe "%VE_NAMING_ROOT%\build\release\vegas-encoder\plugin\vegas-encoder.dll" "%VE_NAMING_ROOT%\schema\fixtures\b0\core-and-services.json"
set "VE_NAMING_RESULT=%ERRORLEVEL%"
popd
exit /b %VE_NAMING_RESULT%
:fail
popd
exit /b 1
