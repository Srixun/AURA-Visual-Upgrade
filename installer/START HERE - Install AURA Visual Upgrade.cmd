@echo off
setlocal
title AURA Visual Upgrade Addon Installer
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-AURAVisualUpgrade.ps1" -Action Install
echo.
pause
