(*******************************************************************************
  Diagnostic helpers for DelphiRTTI module.

  Exposes Python functions for low-level RTTI inspection:
    - get_method_names(obj|class)    -> dict with method/property/field details
    - get_property_names(obj|class)  -> list[str] of property names

  These are useful for debugging and exploring RTTI metadata but are not part
  of the core public API.  They can be removed from the build by simply
  removing this unit from the .dpr uses clause and uMain registration call.

  RTTI: uses the project's patched System.Rtti (sources\System.Rtti.pas), not
  the stock RTL; see DelphiRTTI.dpr.
*******************************************************************************)
unit WrapDelphiRTTI_DebugHelpers;

interface

uses
  PythonEngine,
  System.Rtti;  { project patched copy, see .dpr }

procedure RegisterDebugHelpers(AModule: TPythonModule);

implementation

uses
  System.SysUtils,
  System.TypInfo,
  DelphiComponentDetection,
  DelphiRTTIExceptions;

var
  GRttiContext: TRttiContext;

{ Helper: resolve the Delphi TClass + TRttiType from a Python argument. }
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
      on E: Exception do
      begin
        SetPythonError(E);
        Exit;
      end;
    end;

    RttiType := GRttiContext.GetType(AClass);
    if RttiType = nil then
    begin
      SetPythonError(EDelphiRTTIInternal.CreateFmt(
        'Can''t Create RTTI Type for known class: %s', [AClass.ClassName]));
      Exit;
    end;
  end;
  Result := True;
end;

// ============================================================================
//  Python-exported diagnostic functions
// ============================================================================

{ Return a Python dict with RTTI probe results per hierarchy level. }
function py_get_method_names(Self, Args: PPyObject): PPyObject; cdecl;
var
  AClass: TClass;
  RttiType: TRttiType;
  I: Integer;
begin
  Result := nil;
  if not ResolveRttiType(Args, 'get_method_names', AClass, RttiType) then
    Exit;

  with GetPythonEngine do
  try
    var PyDict := PyDict_New;

    PyDict_SetItemString(PyDict, 'class_name',
      PyUnicodeFromString(AClass.ClassName));
    PyDict_SetItemString(PyDict, 'is_instance_type',
      PyBool_FromLong(Ord(RttiType is TRttiInstanceType)));

    try
      var Declared := RttiType.GetDeclaredMethods;
      var PyList := PyList_New(Length(Declared));
      for I := 0 to High(Declared) do
        PyList_SetItem(PyList, I, PyUnicodeFromString(Declared[I].Name));
      PyDict_SetItemString(PyDict, 'declared_methods', PyList);
    except
      on E: Exception do
        PyDict_SetItemString(PyDict, 'declared_methods_error',
          PyUnicodeFromString(E.ClassName + ': ' + E.Message));
    end;

    try
      var All := RttiType.GetMethods;
      var PyList := PyList_New(Length(All));
      for I := 0 to High(All) do
        PyList_SetItem(PyList, I, PyUnicodeFromString(All[I].Name));
      PyDict_SetItemString(PyDict, 'all_methods', PyList);
    except
      on E: Exception do
        PyDict_SetItemString(PyDict, 'all_methods_error',
          PyUnicodeFromString(E.ClassName + ': ' + E.Message));
    end;

    try
      var DeclProps := RttiType.GetDeclaredProperties;
      var PyList := PyList_New(Length(DeclProps));
      for I := 0 to High(DeclProps) do
        PyList_SetItem(PyList, I, PyUnicodeFromString(DeclProps[I].Name));
      PyDict_SetItemString(PyDict, 'declared_properties', PyList);
    except
      on E: Exception do
        PyDict_SetItemString(PyDict, 'declared_properties_error',
          PyUnicodeFromString(E.ClassName + ': ' + E.Message));
    end;

    try
      var AllProps := RttiType.GetProperties;
      var PyList := PyList_New(Length(AllProps));
      for I := 0 to High(AllProps) do
        PyList_SetItem(PyList, I, PyUnicodeFromString(AllProps[I].Name));
      PyDict_SetItemString(PyDict, 'all_properties', PyList);
    except
      on E: Exception do
        PyDict_SetItemString(PyDict, 'all_properties_error',
          PyUnicodeFromString(E.ClassName + ': ' + E.Message));
    end;

    // Walk BaseType chain: per-level declared counts
    try
      var WalkList := PyList_New(0);
      var Cur: TRttiType := RttiType;
      while Cur <> nil do
      begin
        var MethodInfo, PropInfo, FieldInfo: string;

        try
          var DM := Cur.GetDeclaredMethods;
          MethodInfo := Format('methods=%d', [Length(DM)]);
        except
          on E: Exception do
            MethodInfo := Format('methods_ERR=%s', [E.Message]);
        end;

        try
          var DP := Cur.GetDeclaredProperties;
          PropInfo := Format('props=%d', [Length(DP)]);
        except
          on E: Exception do
            PropInfo := Format('props_ERR=%s', [E.Message]);
        end;

        try
          var DF := Cur.GetDeclaredFields;
          FieldInfo := Format('fields=%d', [Length(DF)]);
        except
          on E: Exception do
            FieldInfo := Format('fields_ERR=%s', [E.Message]);
        end;

        var Info := Format('%s (%s, %s, %s)', [
          Cur.Name, MethodInfo, PropInfo, FieldInfo]);
        PyList_Append(WalkList, PyUnicodeFromString(Info));

        if Cur is TRttiInstanceType then
          Cur := TRttiInstanceType(Cur).BaseType
        else
        begin
          PyList_Append(WalkList,
            PyUnicodeFromString('** STOPPED: not TRttiInstanceType **'));
          Break;
        end;
      end;
      PyDict_SetItemString(PyDict, 'base_type_chain', WalkList);
    except
      on E: Exception do
        PyDict_SetItemString(PyDict, 'base_type_chain_error',
          PyUnicodeFromString(E.ClassName + ': ' + E.Message));
    end;

    Result := PyDict;
  except
    on E: Exception do
    begin
      E.Message := Format('get_method_names failed: %s: %s', [E.ClassName, E.Message]);
      SetPythonError(E);
      Result := nil;
    end;
  end;
end;

{ Return a plain Python list of property-name strings. }
function py_get_property_names(Self, Args: PPyObject): PPyObject; cdecl;
var
  AClass: TClass;
  RttiType: TRttiType;
  Props: TArray<TRttiProperty>;
  PyList, PyStr: PPyObject;
  I: Integer;
begin
  Result := nil;
  if not ResolveRttiType(Args, 'get_property_names', AClass, RttiType) then
    Exit;

  with GetPythonEngine do
  try
    Props := RttiType.GetProperties;
    PyList := PyList_New(Length(Props));
    if PyList = nil then
      Exit;
    for I := 0 to High(Props) do
    begin
      PyStr := PyUnicodeFromString(Props[I].Name);
      PyList_SetItem(PyList, I, PyStr);
    end;
    Result := PyList;
  except
    on E: Exception do
    begin
      E.Message := Format('get_property_names failed: %s: %s', [E.ClassName, E.Message]);
      SetPythonError(E);
      Result := nil;
    end;
  end;
end;

// ============================================================================
//  Registration
// ============================================================================

procedure RegisterDebugHelpers(AModule: TPythonModule);
begin
  GRttiContext := TRttiContext.Create;

  AModule.AddMethod('get_method_names', @py_get_method_names,
    'get_method_names(obj | class) -> dict. RTTI probe with per-level method/prop/field counts.');
  AModule.AddMethod('get_property_names', @py_get_property_names,
    'get_property_names(obj | class) -> list[str]. Returns property names via RTTI (diagnostic).');
end;

end.
