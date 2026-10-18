@echo off
setlocal
if not defined VEGAS_ENCODER_PYTHON set "VEGAS_ENCODER_PYTHON=python"
"%VEGAS_ENCODER_PYTHON%" -I "%~dp0etc\Export-AppIcons.py" %*
exit /b %errorlevel%
