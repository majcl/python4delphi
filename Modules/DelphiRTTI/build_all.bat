@echo off
setlocal EnableDelayedExpansion
REM Set path to your RAD Studio bin folder (e.g. Delphi 12: Studio\23.0\bin)
if not defined RSBIN set RSBIN=C:\Program Files (x86)\Embarcadero\Studio\23.0\bin
call "%RSBIN%\rsvars.bat"
cd /d "%~dp0"

REM All platforms defined in DelphiRTTI.dproj (Base_* + Linux64 from Platforms section)
set PLATFORMS=Win32 Win64 Android Android64 iOSDevice64 iOSSimARM64 OSX64 OSXARM64 Linux64
set CONFIGS=Debug Release

set FAILED=0
set FAILED_LIST=
set OK_LIST=
for %%C in (%CONFIGS%) do (
  for %%P in (%PLATFORMS%) do (
    echo.
    echo Building %%P %%C...
    msbuild DelphiRTTI.dproj /t:Build /p:Config=%%C /p:Platform=%%P
    if errorlevel 1 (
      echo [FAILED] %%P %%C
      set /a FAILED+=1
      set "FAILED_LIST=!FAILED_LIST!%%P::%%C "
    ) else (
      echo [OK] %%P %%C
      set "OK_LIST=!OK_LIST!%%P::%%C "
    )
  )
)

echo.
echo --- Summary ---
for %%a in (!OK_LIST!) do if not "%%a"=="" echo %%a ... [OK]
for %%a in (!FAILED_LIST!) do if not "%%a"=="" echo %%a ... [FAILED]
echo.
if %FAILED% gtr 0 (
  exit /b 1
)
exit /b 0
