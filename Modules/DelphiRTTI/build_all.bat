@echo off
setlocal
REM Set path to your RAD Studio bin folder (e.g. Delphi 12: Studio\23.0\bin)
if not defined RSBIN set RSBIN=C:\Program Files (x86)\Embarcadero\Studio\23.0\bin
call "%RSBIN%\rsvars.bat"
cd /d "%~dp0"

REM All platforms defined in DelphiRTTI.dproj (Base_* + Linux64 from Platforms section)
set PLATFORMS=Win32 Win64 Android Android64 iOSDevice64 iOSSimARM64 OSX64 OSXARM64 Linux64
set CONFIGS=Debug Release

set FAILED=0
for %%C in (%CONFIGS%) do (
  for %%P in (%PLATFORMS%) do (
    echo.
    echo Building %%P %%C...
    msbuild DelphiRTTI.dproj /t:Build /p:Config=%%C /p:Platform=%%P
    if errorlevel 1 (
      echo [FAILED] %%P %%C
      set /a FAILED+=1
    ) else (
      echo [OK] %%P %%C
    )
  )
)

echo.
if %FAILED% gtr 0 (
  echo %FAILED% build(s) failed.
  exit /b 1
)
echo All builds done.
exit /b 0
