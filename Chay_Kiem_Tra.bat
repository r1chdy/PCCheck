@echo off
title PC Gaming Health Check
chcp 65001 >nul

:: Xin quyen Administrator (de doc day du thong tin o cung, nhiet do...)
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "try { Start-Process -FilePath '%~f0' -Verb RunAs -ErrorAction Stop } catch { exit 1 }"
    if not errorlevel 1 exit /b
    echo Khong co quyen Admin - van chay nhung thieu mot so muc.
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PCCheck.ps1"
echo.
pause
