@echo off
setlocal
title Ascension Modern Graphics Setup
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0AscensionSetupWizard.ps1"
echo.
pause
