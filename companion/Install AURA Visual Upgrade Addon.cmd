@echo off
setlocal
title Install AURA Visual Upgrade Addon
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0AscensionSetupWizard.ps1" -Preset AddonOnly
echo.
pause
