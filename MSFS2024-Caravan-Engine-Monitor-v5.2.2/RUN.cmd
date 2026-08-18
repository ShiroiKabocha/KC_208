@echo off
cd /d "%~dp0"
if not exist "CaravanDashboard.exe" (
  echo CaravanDashboard.exe has not been built yet.
  echo Run BUILD.cmd first.
  pause
  exit /b 1
)
start "" "CaravanDashboard.exe"
