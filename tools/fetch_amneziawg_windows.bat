@echo off
REM AmneziaWG Windows fetch (see fetch_amneziawg_windows.ps1). Uses Bypass so it runs under default PS execution policy.
setlocal
cd /d "%~dp0\.."
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0fetch_amneziawg_windows.ps1" %*
exit /b %ERRORLEVEL%
