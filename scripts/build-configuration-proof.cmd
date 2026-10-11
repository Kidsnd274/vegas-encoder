@echo off
rem Separate opt-in DLL; never changes candidate-0.1.0-dev or installed files.
call "%~dp0build.cmd" "%~1" configuration-proof
exit /b %errorlevel%
