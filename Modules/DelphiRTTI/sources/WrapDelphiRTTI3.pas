(*******************************************************************************
  Delphi RTTI module - P4D idiomatic wrappers.
  Uses get_delphi_based_class for the single Python->TClass boundary (no P4D
  on incoming arguments). Registers RTTI types with TPyClassWrapper<T> so P4D
  automatically exposes methods/properties via EXTENDED_RTTI and wraps return
  values (TRttiType, TRttiProperty, etc.) through the same wrapper.
  Requires EXTENDED_RTTI (e.g. include Definition.Inc or Delphi XE2+).
*******************************************************************************)
unit WrapDelphiRTTI3;

interface

uses
  PythonEngine,
  WrapDelphi;

procedure RegisterDelphiRTTI3(AModule: TPythonModule; AWrapper: TPyDelphiWrapper);

implementation

uses
  System.SysUtils,
  System.Rtti,
  DelphiComponentDetection,
  DelphiRTTIExceptions;

var
  GRttiContext: TRttiContext;
  GWrapper: TPyDelphiWrapper;

function py_get_type(Self, Args: PPyObject): PPyObject; cdecl;
var
  Arg: PPyObject;
  AClass: TClass;
  RttiType: TRttiType;
begin
  Result := nil;
  if not Assigned(GWrapper) then
  begin
    GetPythonEngine.PyErr_SetString(GetPythonEngine.PyExc_RuntimeError^, 'DelphiRTTI: wrapper not initialized');
    Exit(nil);
  end;
  with GetPythonEngine do
  begin
    if PyArg_ParseTuple(Args, 'O:get_type', @Arg) = 0 then
      Exit;

    try
      AClass := get_delphi_based_class(Arg);
    except
      on E: EDelphiRTTIInvalidArgument do
      begin
        PyErr_SetString(PyExc_TypeError^, PAnsiChar(AnsiString(E.Message)));
        Exit(nil);
      end;
      on E: Exception do
      begin
        PyErr_SetString(PyExc_RuntimeError^, PAnsiChar(AnsiString(E.ClassName + ': ' + E.Message)));
        Exit(nil);
      end;
    end;

    RttiType := GRttiContext.GetType(AClass);
    if RttiType = nil then
    begin
      PyErr_SetString(PyExc_RuntimeError^, PAnsiChar(AnsiString('RTTI type not found for ' + AClass.ClassName)));
      Exit(nil);
    end;


    try
      Result := GWrapper.Wrap(RttiType, soReference);
    except
      on E: Exception do
      begin
        PyErr_SetString(PyExc_RuntimeError^, PAnsiChar(AnsiString('Wrap failed: ' + E.ClassName + ': ' + E.Message)));
        Result := nil;
      end;
    end;
  end;
end;

procedure RegisterDelphiRTTI3(AModule: TPythonModule; AWrapper: TPyDelphiWrapper);
begin
  GWrapper := AWrapper;
  GRttiContext := TRttiContext.Create;

  AWrapper.RegisterDelphiWrapper(TPyClassWrapper<TRttiType>);
  AWrapper.RegisterDelphiWrapper(TPyClassWrapper<TRttiProperty>);
  AWrapper.RegisterDelphiWrapper(TPyClassWrapper<TRttiMethod>);
  AWrapper.RegisterDelphiWrapper(TPyClassWrapper<TRttiParameter>);
  AWrapper.RegisterDelphiWrapper(TPyClassWrapper<TRttiField>);
  AWrapper.RegisterDelphiWrapper(TPyClassWrapper<TCustomAttribute>);

  AModule.AddMethod('get_type3', @py_get_type, 'get_type3(obj | class) -> RttiType. Argument must be a wrapped Delphi instance or class.');
end;


initialization

finalization


end.
