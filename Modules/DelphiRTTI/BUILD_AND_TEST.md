# Build and Test

## Build

Set up the Delphi/RAD Studio environment first (PATH, BDS, etc.), then run MSBuild. Use **RAD Studio Command Prompt** from the Start Menu, or run `rsvars.bat` from the IDE `bin` folder (e.g. `C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat`).

**Cmd (adjust rsvars path to your install):**
```batch
call "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat" && msbuild DelphiRTTI.dproj /t:Build /p:Config=Debug /p:Platform=Win64
```

**PowerShell:**
```powershell
cmd /c "call `"C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat`" && msbuild DelphiRTTI.dproj /t:Build /p:Config=Debug /p:Platform=Win64"
```

Output: `pyd\Win64\Debug` (or `Release`).

## Tests

From project root, with the built `pyd\Win64\Debug` (or `Release`) on PYTHONPATH or from that directory:

```batch
pytest tests\ -v
```

(To be updated when new tests are added.)
