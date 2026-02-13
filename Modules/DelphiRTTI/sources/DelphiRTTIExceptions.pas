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

implementation

uses
  SimpleLogging;

procedure SetPythonError(ExcType: PPyObject; const AMessage: string);
begin
  GetPythonEngine.PyErr_SetString(ExcType, PAnsiChar(AnsiString(AMessage)));
end;

procedure SetPythonError(ExcType: PPyObject; const AFormat: string; const AArgs: array of const);
begin
  SetPythonError(ExcType, Format(AFormat, AArgs));
end;

constructor EDelphiRTTI.Create(const Msg: string);
begin
  inherited Create(Msg);
  TLogger.FATAL('%s: %s', [ClassName, Message]);
end;

constructor EDelphiRTTI.CreateFmt(const Msg: string; const Args: array of const);
begin
  inherited CreateFmt(Msg, Args);
  TLogger.FATAL('%s: %s', [ClassName, Message]);
end;

end.
