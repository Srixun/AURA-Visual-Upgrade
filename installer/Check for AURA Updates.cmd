@echo off
setlocal
title Check for AURA Visual Upgrade Updates
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-AURAVisualUpgrade.ps1" -Action Update
echo.
pause
