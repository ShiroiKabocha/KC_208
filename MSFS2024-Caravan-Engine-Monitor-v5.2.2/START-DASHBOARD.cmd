@echo off
cd /d "%~dp0"
if not exist "208 EICAS.exe" (
  echo 208 EICAS.exe is missing from this folder.
  pause
  exit /b 1
)
start "208 EICAS" "208 EICAS.exe"
