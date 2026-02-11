unit uMain;

interface

uses
  PythonEngine;

function PyInit_DelphiRTTI: PPyObject; cdecl;

implementation

uses
  System.SysUtils,
  WrapDelphi,
  WrapDelphiRTTI,
  DelphiRTTIExceptions;

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

      // Register RTTI types BEFORE LoadDllInExtensionModule.
      // During LoadDll, Engine.Initialize -> Wrapper.Initialize runs and
      // initializes all registered types. Types call Module.AddClient(Self)
      // because Module is not yet initialized. Later, when Python runs
      // Exec_Module, it sets Module.Module and calls ModuleReady on each
      // client type, which runs AddTypeVar and adds them to the module dict.
      RegisterDelphiRTTI(gModule, gDelphiWrapper);

      // IMPORTANT: bind to the already-running interpreter
      gEngine.LoadDllInExtensionModule;

    except
      on E: Exception do
      begin
        if Assigned(gEngine) and gEngine.IsHandleValid then
          SetPythonError(gEngine.PyExc_RuntimeError^, 'DelphiRTTI init failed: %s: %s', [E.ClassName, E.Message])
        else
          WriteLn(ErrOutput, 'DelphiRTTI init failed: ', E.ClassName, ': ', E.Message);
        Exit(nil);
      end;
    end;
  end;

  Result := gEngine.PyModuleDef_Init(@gModule.ModuleDef);

end;

initialization
  gEngine := nil;
  gModule := nil;
  gDelphiWrapper := nil;

finalization
  gModule.Free;
  gDelphiWrapper.Free;
  gEngine.Free;

end.
