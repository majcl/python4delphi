unit DelphiRTTIExceptions;

interface

uses
  System.SysUtils,
  PythonEngine;

type
  EDelphiRTTI = class(Exception)
  public
    constructor Create(const Msg: string); reintroduce;
    constructor CreateFmt(const Msg: string; const Args: array of const); reintroduce;
  end;

  EDelphiRTTIInternal = class(EDelphiRTTI)
  end;

  EDelphiRTTIInvalidArgument = class(EDelphiRTTI)
  end;

{ Set current Python exception. Use before returning nil from a cdecl export. }
procedure SetPythonError(ExcType: PPyObject; const AMessage: string); overload;
procedure SetPythonError(ExcType: PPyObject; const AFormat: string; const AArgs: array of const); overload;
procedure SetPythonError(DelphiException: Exception); overload;

implementation

uses
  SimpleLogging;


procedure SetPythonError(ExcType: PPyObject; const AMessage: string); overload;
begin
  GetPythonEngine.PyErr_SetString(ExcType, PAnsiChar(AnsiString(AMessage)));
end;

procedure SetPythonError(ExcType: PPyObject; const AFormat: string; const AArgs: array of const); overload;
begin
  SetPythonError(ExcType, Format(AFormat, AArgs));
end;

procedure SetPythonError(DelphiException: Exception); overload;
var
  PythonException: PPPyObject;
begin
  if DelphiException is EDelphiRTTIInvalidArgument then
    PythonException := GetPythonEngine.PyExc_TypeError
  else if DelphiException is EDelphiRTTIInternal then
    PythonException := GetPythonEngine.PyExc_RuntimeError
  else
    PythonException := GetPythonEngine.PyExc_RuntimeError;

  SetPythonError(PythonException^, DelphiException.Message);
end;


constructor EDelphiRTTI.Create(const Msg: string);
begin
  inherited Create(Msg);
  TLogger.ERROR('%s: %s', [ClassName, Message]);
end;

constructor EDelphiRTTI.CreateFmt(const Msg: string; const Args: array of const);
begin
  inherited CreateFmt(Msg, Args);
  TLogger.ERROR('%s: %s', [ClassName, Message]);
end;

end.
