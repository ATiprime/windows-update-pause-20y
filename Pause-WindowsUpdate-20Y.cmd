@echo off
chcp 65001 >nul 2>&1
setlocal EnableExtensions
title Windows Update - Pause 20 Years  [verified 2026-11-26]
cd /d "%~dp0"

rem ---- Already elevated? ----
fltmc >nul 2>&1
if errorlevel 1 (
    echo.
    echo   Administrator rights are required.
    echo   A UAC prompt will appear - please click "Yes".
    echo.
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b 0
)

echo.
echo   Pausing Windows Update for 20 years...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0pause-windows-update-20y.ps1"
set "RC=%ERRORLEVEL%"

echo.
if "%RC%"=="0" (
    echo   [OK] Done.
    echo   Open Settings - Windows Update - it should say "Paused until 2046".
    echo   To undo: run Restore-WindowsUpdate.cmd
) else (
    echo   [FAILED] Exit code %RC%. Check last-run.log
)
echo.
pause
exit /b %RC%
