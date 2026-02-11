unit DelphiRTTIExceptions;

interface

uses
  System.SysUtils,
  PythonEngine;

type
  EDelphiRTTI = class(Exception)
  end;

  EDelphiRTTIInvalidArgument = class(EDelphiRTTI)
  end;

{ Set current Python exception. Use before returning nil from a cdecl export. }
procedure SetPythonError(ExcType: PPyObject; const AMessage: string); overload;
procedure SetPythonError(ExcType: PPyObject; const AFormat: string; const AArgs: array of const); overload;

implementation

procedure SetPythonError(ExcType: PPyObject; const AMessage: string);
begin
  GetPythonEngine.PyErr_SetString(ExcType, PAnsiChar(AnsiString(AMessage)));
end;

procedure SetPythonError(ExcType: PPyObject; const AFormat: string; const AArgs: array of const);
begin
  SetPythonError(ExcType, Format(AFormat, AArgs));
end;

end.
