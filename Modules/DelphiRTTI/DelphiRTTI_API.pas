unit DelphiRTTI_API;

interface

uses
  PythonEngine;

function PyInit_delphirtti: PPyObject; cdecl;

implementation

uses
  System.SysUtils,
  WrapDelphi,
  WrapDelphiClasses,
  WrapDelphiRTTI;

var
  Engine: TPythonEngine;
  Wrapper: TPyDelphiWrapper;
  Module: TPythonModule;

function PyInit_DelphiRTTI: PPyObject; cdecl;
begin
  // Create engine and wrapper similarly to other P4D extension modules.
  Engine := TPythonEngine.Create(nil);
  Engine.AutoFinalize := False;
  Engine.UseLastKnownVersion := True;

  // NOTE: In extension modules you must bind to the already-running interpreter.
  // P4D has "LoadDllInExtensionModule" for that.
  Engine.LoadDllInExtensionModule;

  Wrapper := TPyDelphiWrapper.Create(nil);
  Wrapper.Engine := Engine;

  Module := TPythonModule.Create(nil);
  Module.Engine := Engine;
  Module.ModuleName := 'delphirtti';

  RegisterDelphiRTTI(Module, Wrapper);

  Result := Module.Module;
end;

end.

