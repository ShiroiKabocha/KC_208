@echo off
setlocal
cd /d "%~dp0"

set "CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not exist "%CSC%" (
  echo ERROR: Windows .NET Framework compiler was not found.
  echo Expected: %CSC%
  pause
  exit /b 1
)

echo Building dashboard...
"%CSC%" /nologo /target:winexe /platform:x64 /optimize+ /reference:System.Windows.Forms.dll /reference:System.Drawing.dll /win32icon:"Kabocha208.ico" /out:"208 EICAS Desktop.exe" "Program.cs" "DesktopDashboard.cs" >"BUILD-ERRORS.txt" 2>&1
set "RESULT=%ERRORLEVEL%"

type "BUILD-ERRORS.txt"

if not "%RESULT%"=="0" (
  echo.
  echo Build failed. Compiler details are saved in BUILD-ERRORS.txt.
  pause
  exit /b %RESULT%
)

del "BUILD-ERRORS.txt" >nul 2>&1
echo.
echo Build complete: 208 EICAS Desktop.exe
pause
