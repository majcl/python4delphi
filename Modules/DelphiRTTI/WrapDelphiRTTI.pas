unit WrapDelphiRTTI;

interface

uses
  PythonEngine,
  WrapDelphi;

procedure RegisterDelphiRTTI(AModule: TPythonModule; AWrapper: TPyDelphiWrapper);

implementation

uses
  System.SysUtils,
  System.Rtti,
  System.TypInfo,
  System.Generics.Collections,
  WrapDelphiClasses,      // for TPyDelphiObject
  {$IFDEF MSWINDOWS}
  Vcl.Forms,              // Force VCL types into RTTI context
  Fmx.Forms;              // Force FMX types into RTTI context
  {$ENDIF}

var
  GRttiContext: TRttiContext;
  GWrapper: TPyDelphiWrapper;

type
  // Base for all RTTI python objects
  TPyRttiBase = class(TPyObject)
  private
    FRttiObj: TObject;
  public
    property RttiObj: TObject read FRttiObj write FRttiObj;
  end;

  TPyRttiType = class(TPyRttiBase)
  public
    class procedure SetupType(APythonType: TPythonType); override;

    function Get_Name(AContext: Pointer): PPyObject; cdecl;
    function Get_QualifiedName(AContext: Pointer): PPyObject; cdecl;
    function Get_UnitName(AContext: Pointer): PPyObject; cdecl;
    function Get_Kind(AContext: Pointer): PPyObject; cdecl;

    function Get_BaseType(AContext: Pointer): PPyObject; cdecl;
    function Get_Properties(AContext: Pointer): PPyObject; cdecl;
    function Get_Methods(AContext: Pointer): PPyObject; cdecl;
    function Get_Fields(AContext: Pointer): PPyObject; cdecl;
    function Get_Attributes(AContext: Pointer): PPyObject; cdecl;
  end;

  TPyRttiProperty = class(TPyRttiBase)
  public
    class procedure SetupType(APythonType: TPythonType); override;

    function Get_Name(AContext: Pointer): PPyObject; cdecl;
    function Get_Visibility(AContext: Pointer): PPyObject; cdecl;
    function Get_IsReadable(AContext: Pointer): PPyObject; cdecl;
    function Get_IsWritable(AContext: Pointer): PPyObject; cdecl;
    function Get_IsIndexed(AContext: Pointer): PPyObject; cdecl;

    function Get_PropertyType(AContext: Pointer): PPyObject; cdecl;
    function Get_IndexParameters(AContext: Pointer): PPyObject; cdecl;

    function Get_Default(AContext: Pointer): PPyObject; cdecl;
    function Get_Attributes(AContext: Pointer): PPyObject; cdecl;
  end;

  TPyRttiMethod = class(TPyRttiBase)
  public
    class procedure SetupType(APythonType: TPythonType); override;

    function Get_Name(AContext: Pointer): PPyObject; cdecl;
    function Get_Visibility(AContext: Pointer): PPyObject; cdecl;
    function Get_MethodKind(AContext: Pointer): PPyObject; cdecl;
    function Get_IsClassMethod(AContext: Pointer): PPyObject; cdecl;
    function Get_IsStatic(AContext: Pointer): PPyObject; cdecl;
    function Get_CallingConvention(AContext: Pointer): PPyObject; cdecl;

    function Get_ReturnType(AContext: Pointer): PPyObject; cdecl;
    function Get_Parameters(AContext: Pointer): PPyObject; cdecl;
    function Get_Attributes(AContext: Pointer): PPyObject; cdecl;
  end;

  TPyRttiParameter = class(TPyRttiBase)
  public
    class procedure SetupType(APythonType: TPythonType); override;

    function Get_Name(AContext: Pointer): PPyObject; cdecl;
    function Get_Flags(AContext: Pointer): PPyObject; cdecl;
    function Get_ParamType(AContext: Pointer): PPyObject; cdecl;
    function Get_Attributes(AContext: Pointer): PPyObject; cdecl;
  end;

  TPyRttiField = class(TPyRttiBase)
  public
    class procedure SetupType(APythonType: TPythonType); override;

    function Get_Name(AContext: Pointer): PPyObject; cdecl;
    function Get_Visibility(AContext: Pointer): PPyObject; cdecl;
    function Get_FieldType(AContext: Pointer): PPyObject; cdecl;
    function Get_Attributes(AContext: Pointer): PPyObject; cdecl;
  end;

  // Wrap actual attribute instances (TCustomAttribute descendants)
  TPyRttiAttribute = class(TPyRttiBase)
  public
    class procedure SetupType(APythonType: TPythonType); override;

    function Get_ClassName(AContext: Pointer): PPyObject; cdecl;
    function Get_AttributeType(AContext: Pointer): PPyObject; cdecl;
    function Get_PublishedProps(AContext: Pointer): PPyObject; cdecl; // �ctor args where possible�
  end;

var
  PyType_RttiType: TPythonType;
  PyType_RttiProperty: TPythonType;
  PyType_RttiMethod: TPythonType;
  PyType_RttiParameter: TPythonType;
  PyType_RttiField: TPythonType;
  PyType_RttiAttribute: TPythonType;

function WrapRttiObj(Obj: TObject): PPyObject; forward;

{ -------------------- Helper: wrap array<TObject> as python list -------------------- }

function WrapObjList(const Items: TArray<TObject>): PPyObject;
var
  I: Integer;
begin
  Result := GetPythonEngine.PyList_New(Length(Items));
  for I := 0 to High(Items) do
    GetPythonEngine.PyList_SetItem(Result, I, WrapRttiObj(Items[I])); // steals ref
end;

function WrapAttributes(const Attrs: TArray<TCustomAttribute>): PPyObject;
var
  I: Integer;
begin
  Result := GetPythonEngine.PyList_New(Length(Attrs));
  for I := 0 to High(Attrs) do
    GetPythonEngine.PyList_SetItem(Result, I, WrapRttiObj(Attrs[I]));
end;

{ -------------------- Core dispatch: NO HOLES -------------------- }

function WrapRttiObj(Obj: TObject): PPyObject;
var
  Inst: TPyRttiBase;

  function NewWrappedRtti(APyType: TPythonType; ARttiObj: TObject): PPyObject;
  var
    PyObj: PPyObject;
    DelphiSide: TPyRttiBase;
  begin
    if not Assigned(APyType) then
    begin
      GetPythonEngine.PyErr_SetString(GetPythonEngine.PyExc_RuntimeError^,
        PAnsiChar(AnsiString('RTTI type not initialized')));
      Exit(nil);
    end;

    // Lazy initialization: initialize type if not already initialized
    // This avoids assertion failures during module registration
    if not APyType.Initialized then
      APyType.Initialize;

    PyObj := APyType.CreateInstance;
    if PyObj = nil then
      Exit(nil); // Python error already set by CreateInstance

    // Get the Delphi side object and set the RTTI object reference
    var PyDelphiObj := PythonToDelphi(PyObj);
    if not Assigned(PyDelphiObj) then
    begin
      GetPythonEngine.Py_DecRef(PyObj);
      GetPythonEngine.PyErr_SetString(GetPythonEngine.PyExc_RuntimeError^,
        PAnsiChar(AnsiString('Failed to get Delphi side object')));
      Exit(nil);
    end;
    
    if PyDelphiObj is TPyRttiBase then
    begin
      DelphiSide := TPyRttiBase(PyDelphiObj);
      DelphiSide.RttiObj := ARttiObj;
    end
    else
    begin
      GetPythonEngine.Py_DecRef(PyObj);
      GetPythonEngine.PyErr_SetString(GetPythonEngine.PyExc_RuntimeError^,
        PAnsiChar(AnsiString('Delphi object is not TPyRttiBase')));
      Exit(nil);
    end;

    Result := PyObj;
  end;

begin
  if Obj = nil then
    Exit(GetPythonEngine.ReturnNone);

  if Obj is TRttiType then
    Exit(NewWrappedRtti(PyType_RttiType, Obj));

  if Obj is TRttiProperty then
    Exit(NewWrappedRtti(PyType_RttiProperty, Obj));

  if Obj is TRttiMethod then
    Exit(NewWrappedRtti(PyType_RttiMethod, Obj));

  if Obj is TRttiParameter then
    Exit(NewWrappedRtti(PyType_RttiParameter, Obj));

  if Obj is TRttiField then
    Exit(NewWrappedRtti(PyType_RttiField, Obj));

  if Obj is TCustomAttribute then
    Exit(NewWrappedRtti(PyType_RttiAttribute, Obj));

  // Unknown RTTI node: return None (you can later add TRttiIndexedProperty, TRttiMethodType etc.)
  Result := GetPythonEngine.ReturnNone;
end;

{ -------------------- Resolving get_type(arg) -------------------- }

function TryResolveClassFromPy(Arg: PPyObject; out Cls: TClass): Boolean;
var
  PyT: TPythonType;
  PyObj: TPyObject;
  RttiType: TRttiType;
  Field: TRttiField;
  DelphiObj: TObject;
begin
  Result := False;
  Cls := nil;

  // 1) wrapped instance -> DelphiObject.ClassType
  // Try PythonToDelphi first (uses IsDelphiObject check)
  try
    PyObj := PythonToDelphi(Arg);
    if Assigned(PyObj) and (PyObj is TPyDelphiObject) then
    begin
      var Obj := TPyDelphiObject(PyObj).DelphiObject;
      if Assigned(Obj) then
      begin
        Cls := Obj.ClassType;
        Exit(True);
      end;
    end;
  except
    // PythonToDelphi failed (probably object from different module/engine)
    // Try direct memory access as fallback - this works for cross-module objects
    // The memory structure is the same! TPyObject is always at PyObject + SizeOf(PyObject)
    try
      if Assigned(Arg) then
      begin
        // Direct cast: TPyObject is stored right after PyObject header
        PyObj := TPyObject(PAnsiChar(Arg) + SizeOf(PyObject));
        if Assigned(PyObj) then
        begin
          // Try to access DelphiObject directly without 'is' check
          // This avoids VMT access issues across modules
          try
            var Obj := TPyDelphiObject(PyObj).DelphiObject;
            if Assigned(Obj) then
            begin
              Cls := Obj.ClassType;
              Exit(True);
            end;
          except
            // Direct field access failed - object might not be a TPyDelphiObject
          end;
        end;
      end;
    except
      // Direct memory access failed - object might not be a P4D object
    end;
  end;

  // 2) python type object (frm.ClassType()) � validate as class ref of any kind
  // Try both PyClass_Check (old-style) and PyType_CheckExact (new-style/type objects)
  if GetPythonEngine.PyClass_Check(Arg) or GetPythonEngine.PyType_CheckExact(Arg) then
  begin
    PyT := FindPythonType(PPyTypeObject(Arg));
    if Assigned(PyT) and PyT.PyObjectClass.InheritsFrom(TPyDelphiObject) then
    begin
      // This is the Delphi class that this python type wraps
      Cls := TPyDelphiObjectClass(PyT.PyObjectClass).DelphiObjectClass;
      Exit(Assigned(Cls));
    end;

    // Alternative path: use ValidateClassRef when you have a reference expected class.
    // Here we want �any class�, so the PyT-path is the right one.
  end;

  // 3) string handled elsewhere
end;

function ResolveTypeByName(const NameOrQualified: string): TRttiType;
var
  Hits: TList<TRttiType>;
  T: TRttiType;
  Simple: string;
begin
  Result := nil;

  // Qualified name: try FindType first (fast path)
  if NameOrQualified.Contains('.') then
  begin
    Result := GRttiContext.FindType(NameOrQualified);
    // If FindType fails, try iterating through all types
    // This is necessary because some types might not be indexed by FindType
    if Result = nil then
    begin
      for T in GRttiContext.GetTypes do
      begin
        if SameText(T.QualifiedName, NameOrQualified) then
        begin
          Result := T;
          Exit;
        end;
      end;
    end
    else
      Exit;
  end;

  Simple := NameOrQualified;
  Hits := TList<TRttiType>.Create;
  try
    for T in GRttiContext.GetTypes do
      if SameText(T.Name, Simple) then
        Hits.Add(T);

    if (Hits.Count = 0) and (Simple <> '') and (Simple[1] <> 'T') then
    begin
      Simple := 'T' + Simple;
      for T in GRttiContext.GetTypes do
        if SameText(T.Name, Simple) then
          Hits.Add(T);
    end;

    if Hits.Count = 1 then
      Exit(Hits[0]);

    if Hits.Count > 1 then
    begin
      // Ambiguous: return nil and let caller raise helpful error
      Exit(nil);
    end;
  finally
    Hits.Free;
  end;
end;

function py_get_type(Self, Args: PPyObject): PPyObject; cdecl;
var
  Arg: PPyObject;
  Cls: TClass;
  Rt: TRttiType;
  S: string;
begin
  Result := nil;
  with GetPythonEngine do
  begin
    if PyArg_ParseTuple(Args, 'O:get_type', @Arg) = 0 then Exit;

    Rt := nil;

    // instance or python type
    if TryResolveClassFromPy(Arg, Cls) then
      Rt := GRttiContext.GetType(Cls)
    else if PyUnicode_Check(Arg) then
    begin
      S := PyUnicodeAsString(Arg);
      Rt := ResolveTypeByName(S);
      if Rt = nil then
      begin
        PyErr_SetString(PyExc_LookupError^,
          PAnsiChar(AnsiString('Type not found or ambiguous: ' + S +
            '. Use qualified name like "Vcl.Forms.TForm" / "Fmx.Forms.TForm".')));
        Exit(nil);
      end;
    end;

    if Rt = nil then
    begin
      PyErr_SetString(PyExc_TypeError^,
        'get_type expects a wrapped Delphi instance, a Delphi python class (ClassType()), or a type name string.');
      Exit(nil);
    end;

    Result := WrapRttiObj(Rt);
  end;
end;

{ -------------------- TRttiType getters - standalone wrappers -------------------- }

function GetRttiType_Name(obj: PPyObject; context: Pointer): PPyObject; cdecl;
var
  SelfObj: TPyRttiType;
  PyDelphiObj: TPyObject;
begin
  try
    PyDelphiObj := PythonToDelphi(obj);
    if not Assigned(PyDelphiObj) or not (PyDelphiObj is TPyRttiType) then
      Exit(GetPythonEngine.ReturnNone);
    SelfObj := TPyRttiType(PyDelphiObj);
    if not Assigned(SelfObj) or not Assigned(SelfObj.RttiObj) then
      Exit(GetPythonEngine.ReturnNone);
    Result := GetPythonEngine.PyUnicodeFromString(TRttiType(SelfObj.RttiObj).Name);
  except
    Result := GetPythonEngine.ReturnNone;
  end;
end;

function GetRttiType_QualifiedName(obj: PPyObject; context: Pointer): PPyObject; cdecl;
var
  SelfObj: TPyRttiType;
  PyDelphiObj: TPyObject;
begin
  try
    PyDelphiObj := PythonToDelphi(obj);
    if not Assigned(PyDelphiObj) or not (PyDelphiObj is TPyRttiType) then
      Exit(GetPythonEngine.ReturnNone);
    SelfObj := TPyRttiType(PyDelphiObj);
    if not Assigned(SelfObj) or not Assigned(SelfObj.RttiObj) then
      Exit(GetPythonEngine.ReturnNone);
    Result := GetPythonEngine.PyUnicodeFromString(TRttiType(SelfObj.RttiObj).QualifiedName);
  except
    Result := GetPythonEngine.ReturnNone;
  end;
end;

function GetRttiType_UnitName(obj: PPyObject; context: Pointer): PPyObject; cdecl;
var
  SelfObj: TPyRttiType;
  PyDelphiObj: TPyObject;
begin
  try
    PyDelphiObj := PythonToDelphi(obj);
    if not Assigned(PyDelphiObj) or not (PyDelphiObj is TPyRttiType) then
      Exit(GetPythonEngine.ReturnNone);
    SelfObj := TPyRttiType(PyDelphiObj);
    if not Assigned(SelfObj) or not Assigned(SelfObj.RttiObj) then
      Exit(GetPythonEngine.ReturnNone);
    Result := GetPythonEngine.PyUnicodeFromString(TRttiType(SelfObj.RttiObj).UnitName);
  except
    Result := GetPythonEngine.ReturnNone;
  end;
end;

function GetRttiType_Kind(obj: PPyObject; context: Pointer): PPyObject; cdecl;
var
  SelfObj: TPyRttiType;
  PyDelphiObj: TPyObject;
begin
  try
    PyDelphiObj := PythonToDelphi(obj);
    if not Assigned(PyDelphiObj) or not (PyDelphiObj is TPyRttiType) then
      Exit(GetPythonEngine.ReturnNone);
    SelfObj := TPyRttiType(PyDelphiObj);
    if not Assigned(SelfObj) or not Assigned(SelfObj.RttiObj) then
      Exit(GetPythonEngine.ReturnNone);
    Result := GetPythonEngine.PyLong_FromLong(Ord(TRttiType(SelfObj.RttiObj).TypeKind));
  except
    Result := GetPythonEngine.ReturnNone;
  end;
end;

function GetRttiType_BaseType(obj: PPyObject; context: Pointer): PPyObject; cdecl;
var
  SelfObj: TPyRttiType;
  PyDelphiObj: TPyObject;
begin
  try
    PyDelphiObj := PythonToDelphi(obj);
    if not Assigned(PyDelphiObj) or not (PyDelphiObj is TPyRttiType) then
      Exit(GetPythonEngine.ReturnNone);
    SelfObj := TPyRttiType(PyDelphiObj);
    if not Assigned(SelfObj) or not Assigned(SelfObj.RttiObj) then
      Exit(GetPythonEngine.ReturnNone);
    Result := WrapRttiObj(TRttiType(SelfObj.RttiObj).BaseType);
  except
    Result := GetPythonEngine.ReturnNone;
  end;
end;

function GetRttiType_Properties(obj: PPyObject; context: Pointer): PPyObject; cdecl;
var
  SelfObj: TPyRttiType;
  PyDelphiObj: TPyObject;
  P: TArray<TRttiProperty>;
  I: Integer;
begin
  try
    PyDelphiObj := PythonToDelphi(obj);
    if not Assigned(PyDelphiObj) or not (PyDelphiObj is TPyRttiType) then
      Exit(GetPythonEngine.PyList_New(0));
    SelfObj := TPyRttiType(PyDelphiObj);
    if not Assigned(SelfObj) or not Assigned(SelfObj.RttiObj) then
      Exit(GetPythonEngine.PyList_New(0));
    P := TRttiType(SelfObj.RttiObj).GetProperties;
    Result := GetPythonEngine.PyList_New(Length(P));
    for I := 0 to High(P) do
      GetPythonEngine.PyList_SetItem(Result, I, WrapRttiObj(P[I]));
  except
    Result := GetPythonEngine.PyList_New(0);
  end;
end;

function GetRttiType_Methods(obj: PPyObject; context: Pointer): PPyObject; cdecl;
var
  SelfObj: TPyRttiType;
  PyDelphiObj: TPyObject;
  M: TArray<TRttiMethod>;
  I: Integer;
begin
  try
    PyDelphiObj := PythonToDelphi(obj);
    if not Assigned(PyDelphiObj) or not (PyDelphiObj is TPyRttiType) then
      Exit(GetPythonEngine.PyList_New(0));
    SelfObj := TPyRttiType(PyDelphiObj);
    if not Assigned(SelfObj) or not Assigned(SelfObj.RttiObj) then
      Exit(GetPythonEngine.PyList_New(0));
    M := TRttiType(SelfObj.RttiObj).GetMethods;
    Result := GetPythonEngine.PyList_New(Length(M));
    for I := 0 to High(M) do
      GetPythonEngine.PyList_SetItem(Result, I, WrapRttiObj(M[I]));
  except
    Result := GetPythonEngine.PyList_New(0);
  end;
end;

function GetRttiType_Fields(obj: PPyObject; context: Pointer): PPyObject; cdecl;
var
  SelfObj: TPyRttiType;
  PyDelphiObj: TPyObject;
  F: TArray<TRttiField>;
  I: Integer;
begin
  try
    PyDelphiObj := PythonToDelphi(obj);
    if not Assigned(PyDelphiObj) or not (PyDelphiObj is TPyRttiType) then
      Exit(GetPythonEngine.PyList_New(0));
    SelfObj := TPyRttiType(PyDelphiObj);
    if not Assigned(SelfObj) or not Assigned(SelfObj.RttiObj) then
      Exit(GetPythonEngine.PyList_New(0));
    F := TRttiType(SelfObj.RttiObj).GetFields;
    Result := GetPythonEngine.PyList_New(Length(F));
    for I := 0 to High(F) do
      GetPythonEngine.PyList_SetItem(Result, I, WrapRttiObj(F[I]));
  except
    Result := GetPythonEngine.PyList_New(0);
  end;
end;

function GetRttiType_Attributes(obj: PPyObject; context: Pointer): PPyObject; cdecl;
var
  SelfObj: TPyRttiType;
  PyDelphiObj: TPyObject;
begin
  try
    PyDelphiObj := PythonToDelphi(obj);
    if not Assigned(PyDelphiObj) or not (PyDelphiObj is TPyRttiType) then
      Exit(GetPythonEngine.PyList_New(0));
    SelfObj := TPyRttiType(PyDelphiObj);
    if not Assigned(SelfObj) or not Assigned(SelfObj.RttiObj) then
      Exit(GetPythonEngine.PyList_New(0));
    Result := WrapAttributes(TRttiType(SelfObj.RttiObj).GetAttributes);
  except
    Result := GetPythonEngine.PyList_New(0);
  end;
end;

{ -------------------- TRttiType -------------------- }

class procedure TPyRttiType.SetupType(APythonType: TPythonType);
begin
  inherited;
  APythonType.AddGetSet('name', @GetRttiType_Name, nil, nil, nil);
  APythonType.AddGetSet('qualified_name', @GetRttiType_QualifiedName, nil, nil, nil);
  APythonType.AddGetSet('unit_name', @GetRttiType_UnitName, nil, nil, nil);
  APythonType.AddGetSet('kind', @GetRttiType_Kind, nil, nil, nil);

  APythonType.AddGetSet('base_type', @GetRttiType_BaseType, nil, nil, nil);
  APythonType.AddGetSet('properties', @GetRttiType_Properties, nil, nil, nil);
  APythonType.AddGetSet('methods', @GetRttiType_Methods, nil, nil, nil);
  APythonType.AddGetSet('fields', @GetRttiType_Fields, nil, nil, nil);
  APythonType.AddGetSet('attributes', @GetRttiType_Attributes, nil, nil, nil);
end;

function TPyRttiType.Get_Name(AContext: Pointer): PPyObject; cdecl;
begin Result := GetPythonEngine.PyUnicodeFromString(TRttiType(RttiObj).Name); end;

function TPyRttiType.Get_QualifiedName(AContext: Pointer): PPyObject; cdecl;
begin Result := GetPythonEngine.PyUnicodeFromString(TRttiType(RttiObj).QualifiedName); end;

function TPyRttiType.Get_UnitName(AContext: Pointer): PPyObject; cdecl;
begin Result := GetPythonEngine.PyUnicodeFromString(TRttiType(RttiObj).UnitName); end;

function TPyRttiType.Get_Kind(AContext: Pointer): PPyObject; cdecl;
begin
  // Exact ordinal of TTypeKind / TRttiTypeKind, python can map it to Enum via .pyi
  Result := GetPythonEngine.PyLong_FromLong(Ord(TRttiType(RttiObj).TypeKind));
end;

function TPyRttiType.Get_BaseType(AContext: Pointer): PPyObject; cdecl;
begin
  Result := WrapRttiObj(TRttiType(RttiObj).BaseType);
end;

function TPyRttiType.Get_Properties(AContext: Pointer): PPyObject; cdecl;
var
  P: TArray<TRttiProperty>;
  I: Integer;
begin
  P := TRttiType(RttiObj).GetProperties;
  Result := GetPythonEngine.PyList_New(Length(P));
  for I := 0 to High(P) do
    GetPythonEngine.PyList_SetItem(Result, I, WrapRttiObj(P[I]));
end;

function TPyRttiType.Get_Methods(AContext: Pointer): PPyObject; cdecl;
var
  M: TArray<TRttiMethod>;
  I: Integer;
begin
  M := TRttiType(RttiObj).GetMethods;
  Result := GetPythonEngine.PyList_New(Length(M));
  for I := 0 to High(M) do
    GetPythonEngine.PyList_SetItem(Result, I, WrapRttiObj(M[I]));
end;

function TPyRttiType.Get_Fields(AContext: Pointer): PPyObject; cdecl;
var
  F: TArray<TRttiField>;
  I: Integer;
begin
  F := TRttiType(RttiObj).GetFields;
  Result := GetPythonEngine.PyList_New(Length(F));
  for I := 0 to High(F) do
    GetPythonEngine.PyList_SetItem(Result, I, WrapRttiObj(F[I]));
end;

function TPyRttiType.Get_Attributes(AContext: Pointer): PPyObject; cdecl;
begin
  Result := WrapAttributes(TRttiType(RttiObj).GetAttributes);
end;

{ -------------------- TRttiProperty getters - standalone wrappers -------------------- }

function GetRttiProperty_Name(obj: PPyObject; context: Pointer): PPyObject; cdecl;
var
  SelfObj: TPyRttiProperty;
  PyDelphiObj: TPyObject;
begin
  try
    PyDelphiObj := PythonToDelphi(obj);
    if not Assigned(PyDelphiObj) or not (PyDelphiObj is TPyRttiProperty) then
      Exit(GetPythonEngine.ReturnNone);
    SelfObj := TPyRttiProperty(PyDelphiObj);
    if not Assigned(SelfObj) or not Assigned(SelfObj.RttiObj) then
      Exit(GetPythonEngine.ReturnNone);
    Result := GetPythonEngine.PyUnicodeFromString(TRttiProperty(SelfObj.RttiObj).Name);
  except
    Result := GetPythonEngine.ReturnNone;
  end;
end;

function GetRttiProperty_Visibility(obj: PPyObject; context: Pointer): PPyObject; cdecl;
var
  SelfObj: TPyRttiProperty;
  PyDelphiObj: TPyObject;
begin
  try
    PyDelphiObj := PythonToDelphi(obj);
    if not Assigned(PyDelphiObj) or not (PyDelphiObj is TPyRttiProperty) then
      Exit(GetPythonEngine.ReturnNone);
    SelfObj := TPyRttiProperty(PyDelphiObj);
    if not Assigned(SelfObj) or not Assigned(SelfObj.RttiObj) then
      Exit(GetPythonEngine.ReturnNone);
    Result := GetPythonEngine.PyLong_FromLong(Ord(TRttiProperty(SelfObj.RttiObj).Visibility));
  except
    Result := GetPythonEngine.ReturnNone;
  end;
end;

function GetRttiProperty_IsReadable(obj: PPyObject; context: Pointer): PPyObject; cdecl;
var
  SelfObj: TPyRttiProperty;
  PyDelphiObj: TPyObject;
begin
  try
    PyDelphiObj := PythonToDelphi(obj);
    if not Assigned(PyDelphiObj) or not (PyDelphiObj is TPyRttiProperty) then
      Exit(GetPythonEngine.ReturnNone);
    SelfObj := TPyRttiProperty(PyDelphiObj);
    if not Assigned(SelfObj) or not Assigned(SelfObj.RttiObj) then
      Exit(GetPythonEngine.ReturnNone);
    Result := GetPythonEngine.PyBool_FromLong(Ord(TRttiProperty(SelfObj.RttiObj).IsReadable));
  except
    Result := GetPythonEngine.ReturnNone;
  end;
end;

function GetRttiProperty_IsWritable(obj: PPyObject; context: Pointer): PPyObject; cdecl;
var
  SelfObj: TPyRttiProperty;
  PyDelphiObj: TPyObject;
begin
  try
    PyDelphiObj := PythonToDelphi(obj);
    if not Assigned(PyDelphiObj) or not (PyDelphiObj is TPyRttiProperty) then
      Exit(GetPythonEngine.ReturnNone);
    SelfObj := TPyRttiProperty(PyDelphiObj);
    if not Assigned(SelfObj) or not Assigned(SelfObj.RttiObj) then
      Exit(GetPythonEngine.ReturnNone);
    Result := GetPythonEngine.PyBool_FromLong(Ord(TRttiProperty(SelfObj.RttiObj).IsWritable));
  except
    Result := GetPythonEngine.ReturnNone;
  end;
end;

function GetRttiProperty_IsIndexed(obj: PPyObject; context: Pointer): PPyObject; cdecl;
var
  SelfObj: TPyRttiProperty;
  PyDelphiObj: TPyObject;
begin
  try
    PyDelphiObj := PythonToDelphi(obj);
    if not Assigned(PyDelphiObj) or not (PyDelphiObj is TPyRttiProperty) then
      Exit(GetPythonEngine.ReturnNone);
    SelfObj := TPyRttiProperty(PyDelphiObj);
    if not Assigned(SelfObj) or not Assigned(SelfObj.RttiObj) then
      Exit(GetPythonEngine.ReturnNone);
    Result := GetPythonEngine.PyBool_FromLong(Ord(SelfObj.RttiObj is TRttiIndexedProperty));
  except
    Result := GetPythonEngine.ReturnNone;
  end;
end;

function GetRttiProperty_PropertyType(obj: PPyObject; context: Pointer): PPyObject; cdecl;
var
  SelfObj: TPyRttiProperty;
  PyDelphiObj: TPyObject;
begin
  try
    PyDelphiObj := PythonToDelphi(obj);
    if not Assigned(PyDelphiObj) or not (PyDelphiObj is TPyRttiProperty) then
      Exit(GetPythonEngine.ReturnNone);
    SelfObj := TPyRttiProperty(PyDelphiObj);
    if not Assigned(SelfObj) or not Assigned(SelfObj.RttiObj) then
      Exit(GetPythonEngine.ReturnNone);
    Result := WrapRttiObj(TRttiProperty(SelfObj.RttiObj).PropertyType);
  except
    Result := GetPythonEngine.ReturnNone;
  end;
end;

function GetRttiProperty_IndexParameters(obj: PPyObject; context: Pointer): PPyObject; cdecl;
var
  SelfObj: TPyRttiProperty;
  PyDelphiObj: TPyObject;
  IP: TRttiIndexedProperty;
  M: TRttiMethod;
  Params: TArray<TRttiParameter>;
  I: Integer;
begin
  try
    PyDelphiObj := PythonToDelphi(obj);
    if not Assigned(PyDelphiObj) or not (PyDelphiObj is TPyRttiProperty) then
      Exit(GetPythonEngine.PyList_New(0));
    SelfObj := TPyRttiProperty(PyDelphiObj);
    if not Assigned(SelfObj) or not Assigned(SelfObj.RttiObj) or not (SelfObj.RttiObj is TRttiIndexedProperty) then
      Exit(GetPythonEngine.PyList_New(0));
    IP := TRttiIndexedProperty(SelfObj.RttiObj);
    M := IP.ReadMethod;
    if M = nil then
      Exit(GetPythonEngine.PyList_New(0));
    Params := M.GetParameters;
    Result := GetPythonEngine.PyList_New(Length(Params));
    for I := 0 to High(Params) do
      GetPythonEngine.PyList_SetItem(Result, I, WrapRttiObj(Params[I]));
  except
    Result := GetPythonEngine.PyList_New(0);
  end;
end;

function GetRttiProperty_Default(obj: PPyObject; context: Pointer): PPyObject; cdecl;
var
  SelfObj: TPyRttiProperty;
  PyDelphiObj: TPyObject;
  IP: TRttiInstanceProperty;
begin
  try
    PyDelphiObj := PythonToDelphi(obj);
    if not Assigned(PyDelphiObj) or not (PyDelphiObj is TPyRttiProperty) then
      Exit(GetPythonEngine.ReturnNone);
    SelfObj := TPyRttiProperty(PyDelphiObj);
    if not Assigned(SelfObj) or not Assigned(SelfObj.RttiObj) then
      Exit(GetPythonEngine.ReturnNone);
    if SelfObj.RttiObj is TRttiInstanceProperty then
    begin
      IP := TRttiInstanceProperty(SelfObj.RttiObj);
      Result := GetPythonEngine.PyLong_FromLong(IP.Default);
    end
    else
      Result := GetPythonEngine.ReturnNone;
  except
    Result := GetPythonEngine.ReturnNone;
  end;
end;

function GetRttiProperty_Attributes(obj: PPyObject; context: Pointer): PPyObject; cdecl;
var
  SelfObj: TPyRttiProperty;
  PyDelphiObj: TPyObject;
begin
  try
    PyDelphiObj := PythonToDelphi(obj);
    if not Assigned(PyDelphiObj) or not (PyDelphiObj is TPyRttiProperty) then
      Exit(GetPythonEngine.PyList_New(0));
    SelfObj := TPyRttiProperty(PyDelphiObj);
    if not Assigned(SelfObj) or not Assigned(SelfObj.RttiObj) then
      Exit(GetPythonEngine.PyList_New(0));
    Result := WrapAttributes(TRttiProperty(SelfObj.RttiObj).GetAttributes);
  except
    Result := GetPythonEngine.PyList_New(0);
  end;
end;

{ -------------------- TRttiProperty -------------------- }

class procedure TPyRttiProperty.SetupType(APythonType: TPythonType);
begin
  inherited;
  APythonType.AddGetSet('name', @GetRttiProperty_Name, nil, nil, nil);
  APythonType.AddGetSet('visibility', @GetRttiProperty_Visibility, nil, nil, nil);
  APythonType.AddGetSet('is_readable', @GetRttiProperty_IsReadable, nil, nil, nil);
  APythonType.AddGetSet('is_writable', @GetRttiProperty_IsWritable, nil, nil, nil);
  APythonType.AddGetSet('is_indexed', @GetRttiProperty_IsIndexed, nil, nil, nil);
  APythonType.AddGetSet('property_type', @GetRttiProperty_PropertyType, nil, nil, nil);
  APythonType.AddGetSet('index_parameters', @GetRttiProperty_IndexParameters, nil, nil, nil);
  APythonType.AddGetSet('default', @GetRttiProperty_Default, nil, nil, nil);
  APythonType.AddGetSet('attributes', @GetRttiProperty_Attributes, nil, nil, nil);
end;

function TPyRttiProperty.Get_Name(AContext: Pointer): PPyObject; cdecl;
begin Result := GetPythonEngine.PyUnicodeFromString(TRttiProperty(RttiObj).Name); end;

function TPyRttiProperty.Get_Visibility(AContext: Pointer): PPyObject; cdecl;
begin Result := GetPythonEngine.PyLong_FromLong(Ord(TRttiProperty(RttiObj).Visibility)); end;

function TPyRttiProperty.Get_IsReadable(AContext: Pointer): PPyObject; cdecl;
begin Result := GetPythonEngine.PyBool_FromLong(Ord(TRttiProperty(RttiObj).IsReadable)); end;

function TPyRttiProperty.Get_IsWritable(AContext: Pointer): PPyObject; cdecl;
begin Result := GetPythonEngine.PyBool_FromLong(Ord(TRttiProperty(RttiObj).IsWritable)); end;

function TPyRttiProperty.Get_IsIndexed(AContext: Pointer): PPyObject; cdecl;
begin Result := GetPythonEngine.PyBool_FromLong(Ord(RttiObj is TRttiIndexedProperty)); end;

function TPyRttiProperty.Get_PropertyType(AContext: Pointer): PPyObject; cdecl;
begin Result := WrapRttiObj(TRttiProperty(RttiObj).PropertyType); end;

function TPyRttiProperty.Get_IndexParameters(AContext: Pointer): PPyObject; cdecl;
var
  IP: TRttiIndexedProperty;
  M: TRttiMethod;
  Params: TArray<TRttiParameter>;
  I: Integer;
begin
  if not (RttiObj is TRttiIndexedProperty) then
    Exit(GetPythonEngine.PyList_New(0));

  IP := TRttiIndexedProperty(RttiObj);

  // Getter method holds index parameters
  M := IP.ReadMethod;
  if M = nil then
    Exit(GetPythonEngine.PyList_New(0));

  Params := M.GetParameters;

  Result := GetPythonEngine.PyList_New(Length(Params));
  for I := 0 to High(Params) do
    GetPythonEngine.PyList_SetItem(Result, I, WrapRttiObj(Params[I]));
end;

function TPyRttiProperty.Get_Default(AContext: Pointer): PPyObject; cdecl;
var
  IP: TRttiInstanceProperty;
begin
  if RttiObj is TRttiInstanceProperty then
  begin
    IP := TRttiInstanceProperty(RttiObj);
    Result := GetPythonEngine.PyLong_FromLong(IP.Default);
  end
  else
    Result := GetPythonEngine.ReturnNone;
end;

function TPyRttiProperty.Get_Attributes(AContext: Pointer): PPyObject; cdecl;
begin Result := WrapAttributes(TRttiProperty(RttiObj).GetAttributes); end;

{ -------------------- TRttiMethod -------------------- }


class procedure TPyRttiMethod.SetupType(APythonType: TPythonType);
begin
  inherited;
  APythonType.AddGetSet('name', @TPyRttiMethod.Get_Name, nil, nil, nil);
  APythonType.AddGetSet('visibility', @TPyRttiMethod.Get_Visibility, nil, nil, nil);
  APythonType.AddGetSet('method_kind', @TPyRttiMethod.Get_MethodKind, nil, nil, nil);
  APythonType.AddGetSet('is_classmethod', @TPyRttiMethod.Get_IsClassMethod, nil, nil, nil);
  APythonType.AddGetSet('is_static', @TPyRttiMethod.Get_IsStatic, nil, nil, nil);
  APythonType.AddGetSet('calling_convention', @TPyRttiMethod.Get_CallingConvention, nil, nil, nil);
  APythonType.AddGetSet('return_type', @TPyRttiMethod.Get_ReturnType, nil, nil, nil);
  APythonType.AddGetSet('parameters', @TPyRttiMethod.Get_Parameters, nil, nil, nil);
  APythonType.AddGetSet('attributes', @TPyRttiMethod.Get_Attributes, nil, nil, nil);
end;

function TPyRttiMethod.Get_Name(AContext: Pointer): PPyObject; cdecl;
begin Result := GetPythonEngine.PyUnicodeFromString(TRttiMethod(RttiObj).Name); end;

function TPyRttiMethod.Get_Visibility(AContext: Pointer): PPyObject; cdecl;
begin Result := GetPythonEngine.PyLong_FromLong(Ord(TRttiMethod(RttiObj).Visibility)); end;

function TPyRttiMethod.Get_MethodKind(AContext: Pointer): PPyObject; cdecl;
begin Result := GetPythonEngine.PyLong_FromLong(Ord(TRttiMethod(RttiObj).MethodKind)); end;

function TPyRttiMethod.Get_IsClassMethod(AContext: Pointer): PPyObject; cdecl;
begin Result := GetPythonEngine.PyBool_FromLong(Ord(TRttiMethod(RttiObj).IsClassMethod)); end;

function TPyRttiMethod.Get_IsStatic(AContext: Pointer): PPyObject; cdecl;
begin Result := GetPythonEngine.PyBool_FromLong(Ord(TRttiMethod(RttiObj).IsStatic)); end;

function TPyRttiMethod.Get_CallingConvention(AContext: Pointer): PPyObject; cdecl;
begin Result := GetPythonEngine.PyLong_FromLong(Ord(TRttiMethod(RttiObj).CallingConvention)); end;

function TPyRttiMethod.Get_ReturnType(AContext: Pointer): PPyObject; cdecl;
begin Result := WrapRttiObj(TRttiMethod(RttiObj).ReturnType); end;

function TPyRttiMethod.Get_Parameters(AContext: Pointer): PPyObject; cdecl;
var
  P: TArray<TRttiParameter>;
  I: Integer;
begin
  P := TRttiMethod(RttiObj).GetParameters;
  Result := GetPythonEngine.PyList_New(Length(P));
  for I := 0 to High(P) do
    GetPythonEngine.PyList_SetItem(Result, I, WrapRttiObj(P[I]));
end;

function TPyRttiMethod.Get_Attributes(AContext: Pointer): PPyObject; cdecl;
begin Result := WrapAttributes(TRttiMethod(RttiObj).GetAttributes); end;

{ -------------------- TRttiParameter -------------------- }


class procedure TPyRttiParameter.SetupType(APythonType: TPythonType);
begin
  inherited;
  APythonType.AddGetSet('name', @TPyRttiParameter.Get_Name, nil, nil, nil);
  APythonType.AddGetSet('flags', @TPyRttiParameter.Get_Flags, nil, nil, nil);
  APythonType.AddGetSet('param_type', @TPyRttiParameter.Get_ParamType, nil, nil, nil);
  APythonType.AddGetSet('attributes', @TPyRttiParameter.Get_Attributes, nil, nil, nil);
end;

function TPyRttiParameter.Get_Name(AContext: Pointer): PPyObject; cdecl;
begin Result := GetPythonEngine.PyUnicodeFromString(TRttiParameter(RttiObj).Name); end;

function TPyRttiParameter.Get_Flags(AContext: Pointer): PPyObject; cdecl;
  function ParamFlagsToMask(const Flags: TParamFlags): Integer;
  var
    F: TParamFlag;
  begin
    Result := 0;
    for F in Flags do
      Result := Result or (1 shl Ord(F));
  end;
begin
  // Exact bitmask of TParamFlags
  Result := GetPythonEngine.PyLong_FromLong( ParamFlagsToMask(TRttiParameter(RttiObj).Flags));
end;

function TPyRttiParameter.Get_ParamType(AContext: Pointer): PPyObject; cdecl;
begin Result := WrapRttiObj(TRttiParameter(RttiObj).ParamType); end;

function TPyRttiParameter.Get_Attributes(AContext: Pointer): PPyObject; cdecl;
begin Result := WrapAttributes(TRttiParameter(RttiObj).GetAttributes); end;

{ -------------------- TRttiField -------------------- }


class procedure TPyRttiField.SetupType(APythonType: TPythonType);
begin
  inherited;
  APythonType.AddGetSet('name', @TPyRttiField.Get_Name, nil, nil, nil);
  APythonType.AddGetSet('visibility', @TPyRttiField.Get_Visibility, nil, nil, nil);
  APythonType.AddGetSet('field_type', @TPyRttiField.Get_FieldType, nil, nil, nil);
  APythonType.AddGetSet('attributes', @TPyRttiField.Get_Attributes, nil, nil, nil);
end;

function TPyRttiField.Get_Name(AContext: Pointer): PPyObject; cdecl;
begin Result := GetPythonEngine.PyUnicodeFromString(TRttiField(RttiObj).Name); end;

function TPyRttiField.Get_Visibility(AContext: Pointer): PPyObject; cdecl;
begin Result := GetPythonEngine.PyLong_FromLong(Ord(TRttiField(RttiObj).Visibility)); end;

function TPyRttiField.Get_FieldType(AContext: Pointer): PPyObject; cdecl;
begin Result := WrapRttiObj(TRttiField(RttiObj).FieldType); end;

function TPyRttiField.Get_Attributes(AContext: Pointer): PPyObject; cdecl;
begin Result := WrapAttributes(TRttiField(RttiObj).GetAttributes); end;

{ -------------------- Attribute wrapper -------------------- }

class procedure TPyRttiAttribute.SetupType(APythonType: TPythonType);
begin
  inherited;
  APythonType.AddGetSet('class_name', @TPyRttiAttribute.Get_ClassName, nil, nil, nil);
  APythonType.AddGetSet('attribute_type', @TPyRttiAttribute.Get_AttributeType, nil, nil, nil);
  // �ctor args where possible�: we cannot recover raw ctor args unless stored,
  // but we CAN reflect the attribute instance�s published properties as a proxy.
  APythonType.AddGetSet('published_props', @TPyRttiAttribute.Get_PublishedProps, nil, nil, nil);
end;

function TPyRttiAttribute.Get_ClassName(AContext: Pointer): PPyObject; cdecl;
begin
  Result := GetPythonEngine.PyUnicodeFromString(TCustomAttribute(RttiObj).ClassName);
end;

function TPyRttiAttribute.Get_AttributeType(AContext: Pointer): PPyObject; cdecl;
begin
  Result := WrapRttiObj(GRttiContext.GetType(TCustomAttribute(RttiObj).ClassType));
end;

function TPyRttiAttribute.Get_PublishedProps(AContext: Pointer): PPyObject; cdecl;
var
  Attr: TObject;
  PropList: PPropList;
  Count, I: Integer;
  Name: string;
  V: Variant;
  D: PPyObject;
begin
  Attr := TCustomAttribute(RttiObj);
  Count := GetPropList(Attr.ClassInfo, tkProperties, nil);
  Result := GetPythonEngine.PyDict_New;

  if Count <= 0 then Exit;

  GetMem(PropList, Count * SizeOf(PPropInfo));
  try
    GetPropList(Attr.ClassInfo, tkProperties, PropList);
    for I := 0 to Count - 1 do
    begin
      Name := string(PropList[I]^.Name);
      // This is �best effort�: only simple published properties can be read as Variant
      try
        V := GetPropValue(Attr, Name, True);
        D := GetPythonEngine.VariantAsPyObject(V);
      except
        D := GetPythonEngine.ReturnNone;
      end;
      GetPythonEngine.PyDict_SetItemString(Result, PAnsiChar(AnsiString(Name)), D);
      GetPythonEngine.Py_DecRef(D);
    end;
  finally
    FreeMem(PropList);
  end;
end;

{ -------------------- Registration -------------------- }

procedure RegisterDelphiRTTI(AModule: TPythonModule; AWrapper: TPyDelphiWrapper);
begin
  GWrapper := AWrapper;
  GRttiContext := TRttiContext.Create;

  // Create Python types
  PyType_RttiType := TPythonType.Create(nil);
  PyType_RttiType.Engine := GetPythonEngine;
  PyType_RttiType.Module := AModule;
  PyType_RttiType.PyObjectClass := TPyRttiType;
  PyType_RttiType.TypeName := 'RttiType';

  PyType_RttiProperty := TPythonType.Create(nil);
  PyType_RttiProperty.Engine := GetPythonEngine;
  PyType_RttiProperty.Module := AModule;
  PyType_RttiProperty.PyObjectClass := TPyRttiProperty;
  PyType_RttiProperty.TypeName := 'RttiProperty';

  PyType_RttiMethod := TPythonType.Create(nil);
  PyType_RttiMethod.Engine := GetPythonEngine;
  PyType_RttiMethod.Module := AModule;
  PyType_RttiMethod.PyObjectClass := TPyRttiMethod;
  PyType_RttiMethod.TypeName := 'RttiMethod';

  PyType_RttiParameter := TPythonType.Create(nil);
  PyType_RttiParameter.Engine := GetPythonEngine;
  PyType_RttiParameter.Module := AModule;
  PyType_RttiParameter.PyObjectClass := TPyRttiParameter;
  PyType_RttiParameter.TypeName := 'RttiParameter';

  PyType_RttiField := TPythonType.Create(nil);
  PyType_RttiField.Engine := GetPythonEngine;
  PyType_RttiField.Module := AModule;
  PyType_RttiField.PyObjectClass := TPyRttiField;
  PyType_RttiField.TypeName := 'RttiField';

  PyType_RttiAttribute := TPythonType.Create(nil);
  PyType_RttiAttribute.Engine := GetPythonEngine;
  PyType_RttiAttribute.Module := AModule;
  PyType_RttiAttribute.PyObjectClass := TPyRttiAttribute;
  PyType_RttiAttribute.TypeName := 'RttiAttribute';

  // Exported functions
  AModule.AddMethod('get_type', @py_get_type, 'get_type(obj | class | name) -> RttiType');
end;

end.

