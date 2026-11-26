@echo off
chcp 65001 >nul 2>&1
setlocal EnableExtensions
title Windows Update - Restore  [verified 2026-11-26]
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
echo   Restoring normal Windows Update behaviour...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0restore-updates.ps1"
set "RC=%ERRORLEVEL%"

echo.
if "%RC%"=="0" (
    echo   [OK] Windows Update is back to normal.
) else (
    echo   [FAILED] Exit code %RC%. Check last-run.log
)
echo.
pause
exit /b %RC%
