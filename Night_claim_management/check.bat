@echo off
echo.
echo ===========================================
echo            Night claim program
echo ===========================================
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0check_gui.ps1"
pause
