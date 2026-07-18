@echo off
setlocal
title Uninstall AURA Visual Upgrade
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-AURAVisualUpgrade.ps1" -Action Uninstall
echo.
pause
