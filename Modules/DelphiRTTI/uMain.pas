unit uMain;

interface

uses
  PythonEngine;

function PyInit_DelphiRTTI: PPyObject; cdecl;

implementation

uses
  System.SysUtils,
  WrapDelphi,
  WrapDelphiRTTI;

var
  gEngine: TPythonEngine = nil;
  gModule: TPythonModule = nil;
  gDelphiWrapper: TPyDelphiWrapper = nil;

function PyInit_DelphiRTTI: PPyObject; cdecl;
begin
  if not Assigned(gEngine) then
  begin
    try
      gEngine := TPythonEngine.Create(nil);
      gEngine.AutoFinalize := False;
      gEngine.UseLastKnownVersion := True;

      gDelphiWrapper := TPyDelphiWrapper.Create(nil);
      gDelphiWrapper.Engine := gEngine;

      // Extension module must be the last engine client created
      gModule := TPythonModule.Create(nil);
      gModule.Engine := gEngine;
      gModule.ModuleName := 'DelphiRTTI';

      gModule.IsExtensionModule := True;
      gModule.MultInterpretersSupport := mmiPerInterpreterGIL;

      gDelphiWrapper.Module := gModule;

      // IMPORTANT: bind to the already-running interpreter FIRST
      gEngine.LoadDllInExtensionModule;

      // Now it's safe to create TPythonType, call Py* APIs, etc.
      RegisterDelphiRTTI(gModule, gDelphiWrapper);

    except
      on E: Exception do
      begin
        var ErrMsg := AnsiString('DelphiRTTI init failed: ' + E.ClassName + ': ' + E.Message);
         if Assigned(gEngine) and gEngine.IsHandleValid then
          gEngine.PyErr_SetString(gEngine.PyExc_RuntimeError^, PAnsiChar(ErrMsg))
         else
          WriteLn(ErrOutput, ErrMsg);
        Exit(nil);
      end;
    end;
  end;

  Result := gEngine.PyModuleDef_Init(@gModule.ModuleDef);
  
  // Types will be initialized lazily when first used (in NewWrappedRtti)
  // This avoids assertion failures during module registration
end;

initialization
  gEngine := nil;
  gModule := nil;
  gDelphiWrapper := nil;
//  PyDocServer := TPythonDocServer.Create();

finalization
  // Note: In extension modules, be careful with finalization ordering;
  // Python may already be unloading. Keep it simple.
  // If you see shutdown issues, comment these out or guard by Assigned(gEngine).
//  PyDocServer := nil;
  gModule.Free;
  gDelphiWrapper.Free;
  gEngine.Free;

end.

