@echo off
setlocal
set "VE_CORE_VCVARS=%~1"
if not defined VE_CORE_VCVARS set "VE_CORE_VCVARS=%VEGAS_ENCODER_VCVARS%"
if not defined VE_CORE_VCVARS if exist "L:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat" set "VE_CORE_VCVARS=L:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat"
if defined VE_CORE_VCVARS (call "%VE_CORE_VCVARS%" >nul || exit /b 1) else (where cl >nul 2>nul || exit /b 1)
set "VE_CORE_ROOT=%~dp0.."
set "VE_CORE_PYTHON=%VEGAS_ENCODER_PYTHON%"
if not defined VE_CORE_PYTHON set "VE_CORE_PYTHON=python"
"%VE_CORE_PYTHON%" -I "%~dp0Generate-Versions.py" --check || exit /b 1
set "VE_CORE_OUT=%VE_CORE_ROOT%\build\release\vegas-encoder\core"
if not exist "%VE_CORE_OUT%" mkdir "%VE_CORE_OUT%"
pushd "%VE_CORE_OUT%" || exit /b 1
cl /nologo /c /O2 /MT /W4 /WX /EHsc /std:c++17 /utf-8 /DVE_CORE_BUILD_DLL "%VE_CORE_ROOT%\src\core\json.cpp" "%VE_CORE_ROOT%\src\core\text.cpp" "%VE_CORE_ROOT%\src\core\recipe.cpp" "%VE_CORE_ROOT%\src\core\signal.cpp" "%VE_CORE_ROOT%\src\core\compile.cpp" "%VE_CORE_ROOT%\src\core\lint.cpp" "%VE_CORE_ROOT%\src\core\payload.cpp" "%VE_CORE_ROOT%\src\core\capi\ve_core.cpp" || goto :fail
link /nologo /DLL /OUT:ve_core.dll json.obj text.obj recipe.obj signal.obj compile.obj lint.obj payload.obj ve_core.obj || goto :fail
lib /nologo /OUT:ve_core_static.lib json.obj text.obj recipe.obj signal.obj compile.obj lint.obj payload.obj ve_core.obj || goto :fail
popd
echo CORE BUILD OK: DLL and static library, portable sources, Windows x64
exit /b 0
:fail
popd
exit /b 1
