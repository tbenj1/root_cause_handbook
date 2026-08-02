@echo off
setlocal

powershell.exe ^
  -NoLogo ^
  -NoProfile ^
  -ExecutionPolicy Bypass ^
  -File "%~dp0bootstrap-windows.ps1" ^
  -LocalRun %*

exit /b %errorlevel%
