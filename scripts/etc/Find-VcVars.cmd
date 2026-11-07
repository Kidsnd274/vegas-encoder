@echo off
rem Sets the variable named by %1 to vcvars64.bat for the scripts in this folder.
rem Callers first try their own argument and VEGAS_ENCODER_VCVARS. An active x64
rem developer prompt needs no batch file (the variable stays empty); otherwise
rem vswhere finds the newest Visual Studio with the x64 C++ tools.
if "%~1"=="" exit /b 2
if defined INCLUDE (where cl >nul 2>nul && exit /b 0)
if not exist "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" goto :missing
pushd "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer" || goto :missing
for /f "usebackq delims=" %%P in (`.\vswhere.exe -latest -prerelease -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -find VC\Auxiliary\Build\vcvars64.bat`) do if exist "%%P" set "%~1=%%P"
popd
if defined %~1 exit /b 0
:missing
echo MSVC x64 tools were not found. Set VEGAS_ENCODER_VCVARS to vcvars64.bat, pass it as the first argument, or run from an x64 developer prompt. 1>&2
exit /b 1
