(*******************************************************************************
  Delphi RTTI module - P4D idiomatic wrappers.
  Uses get_delphi_based_class for the single Python->TClass boundary.

  Registers RTTI types (RttiType, TRttiProperty, etc.)



  IMPORTANT: Linux cross-module fix:
    Each .so statically links its own RTL, so TypeInfo(TCustomAttribute) has
    a different pointer in DelphiRTTI.so vs DelphiFMX.so.  System.Rtti's
    ConstructAttributes calls .AsType<TCustomAttribute>, which compares
    TypeInfo pointers and raises EInvalidCast for cross-module classes.

    Fix: a patched copy of System.Rtti.pas is included in the source path.
    The single change (ConstructAttribute line ~5490) replaces
      .AsType<TCustomAttribute>
    with
      TCustomAttribute(...AsObject)
    bypassing the TypeInfo pointer comparison entirely.
*******************************************************************************)
unit WrapDelphiRTTI;

interface

uses
  PythonEngine,
  WrapDelphi;

procedure RegisterDelphiRTTI(AModule: TPythonModule; AWrapper: TPyDelphiWrapper);

implementation

uses
  System.SysUtils,
  System.Rtti,  { project copy: sources\System.Rtti.pas (P4D patch), see .dpr }
  DelphiComponentDetection,
  DelphiRTTIExceptions;

var
  GRttiContext: TRttiContext;
  GWrapper: TPyDelphiWrapper;

// ============================================================================
//  Core RTTI resolution
// ============================================================================

{ Helper: resolve the Delphi TClass + TRttiType from a Python argument.
  Returns True on success, False when a Python exception has been set. }
function ResolveRttiType(Args: PPyObject; const FuncName: AnsiString;
  out AClass: TClass; out RttiType: TRttiType): Boolean;
var
  Arg: PPyObject;
  ParseFmt: AnsiString;
begin
  Result := False;
  AClass := nil;
  RttiType := nil;

  ParseFmt := 'O:' + FuncName;
  with GetPythonEngine do
  begin
    if PyArg_ParseTuple(Args, PAnsiChar(ParseFmt), @Arg) = 0 then
      Exit;

    try
      AClass := get_delphi_based_class(Arg);
    except
      on E: EDelphiRTTIInvalidArgument do
      begin
        SetPythonError(PyExc_TypeError^, E.Message);
        Exit;
      end;
      on E: Exception do
      begin
        SetPythonError(PyExc_RuntimeError^, '%s: %s', [E.ClassName, E.Message]);
        Exit;
      end;
    end;

    RttiType := GRttiContext.GetType(AClass);
    if RttiType = nil then
    begin
      SetPythonError(PyExc_RuntimeError^, 'RTTI type not found for %s', [AClass.ClassName]);
      Exit;
    end;
  end;
  Result := True;
end;

// ============================================================================
//  Python-exported functions
// ============================================================================

function py_get_type(Self, Args: PPyObject): PPyObject; cdecl;
begin
  Result := nil;
  var Python := GetPythonEngine;
  var InputPythonObject: PPyObject;
  if Python.PyArg_ParseTuple(Args, 'O:get_type_rtti', @InputPythonObject) = 0 then
    Exit;

  if not Assigned(GWrapper) then
    raise EDelphiRTTIInternal.Create('Global Type Wrapper  not initialized!');

  try
    var AClass := get_delphi_based_class(InputPythonObject);

    var RttiType := GRttiContext.GetType(AClass);
    if RttiType = nil then
      raise EDelphiRTTIInternal.CreateFmt(
        'Can''t Create RTTI Type for known class: %s', [
           AClass.ClassName
        ]);

    Result := GWrapper.Wrap(RttiType, soReference);

  except
    on E: EDelphiRTTIInvalidArgument do begin
       SetPythonError(Python.PyExc_TypeError^, E.Message);
    end;

    on E: Exception do
    begin
      SetPythonError(Python.PyExc_RuntimeError^, 'Wrap failed: %s: %s', [E.ClassName, E.Message]);
      Result := nil;
    end;
  end;
end;

// ============================================================================
//  Module registration
// ============================================================================

procedure RegisterDelphiRTTI(AModule: TPythonModule; AWrapper: TPyDelphiWrapper);
begin
  GWrapper := AWrapper;
  GRttiContext := TRttiContext.Create;

//  Register TRtti<Types> with TPyClassWrapper<T>:
//  P4D automatically exposes methods/properties via EXTENDED_RTTI and
//  wraps return  values (TRttiType, TRttiProperty, etc.) through the same wrapper.
//  Requires EXTENDED_RTTI (e.g. include Definition.Inc or Delphi XE2+).
  AWrapper.RegisterDelphiWrapper(TPyClassWrapper<TRttiType>);
  AWrapper.RegisterDelphiWrapper(TPyClassWrapper<TRttiProperty>);
  AWrapper.RegisterDelphiWrapper(TPyClassWrapper<TRttiMethod>);
  AWrapper.RegisterDelphiWrapper(TPyClassWrapper<TRttiParameter>);
  AWrapper.RegisterDelphiWrapper(TPyClassWrapper<TRttiField>);
  AWrapper.RegisterDelphiWrapper(TPyClassWrapper<TCustomAttribute>);

  AModule.AddMethod('get_type_rtti', @py_get_type,
    'get_type_rtti(obj | class) -> RttiType. Argument must be a wrapped Delphi instance or class.');
end;

initialization

finalization

end.
