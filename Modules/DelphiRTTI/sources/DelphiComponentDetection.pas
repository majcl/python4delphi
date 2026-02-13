unit DelphiComponentDetection;

interface

uses
  System.Rtti,
  System.SysUtils,
  PythonEngine,
  DelphiRTTIExceptions,
  WrapDelphi;


function is_delphi_class(const obj: PPyObject): Boolean;
function is_delphi_object(const py_obj: PPyObject): Boolean;

function get_delphi_based_class(const obj: PPyObject): TClass;



implementation

uses
    SimpleLogging,
    System.SyncObjs,
    System.TypInfo,
    System.Diagnostics,
    System.Classes,
    System.Generics.Collections;

// We want this class to be shared - Singleton.
// This is somewhat more convenient, than getInstance for each interaction.
type CacheDeallocPointer = class
  public
    class constructor Create;
    class destructor Destroy;
    class procedure add(obj_type: PPyTypeObject);
    class function contains(obj_type: PPyTypeObject): Boolean; overload;
    class function contains(ptr: Pointer): Boolean; overload;

  private
    class var dealloc_pointers: TList<Pointer>;
    class var lock_list: TCriticalSection;
end;

class constructor CacheDeallocPointer.Create;
begin
  dealloc_pointers := TList<Pointer>.Create;
  lock_list := TCriticalSection.Create;
end;
class destructor CacheDeallocPointer.Destroy;
begin
  // As it is whole "singleton" and class methods, consider do nothing,
  // just let the OS process tear down deal with this.
  // If we renounce destructor locking gymnastics, we can ignore
  // TCriticalSection altogether and use rather TMonitor
  lock_list.Acquire;
  try
    dealloc_pointers.Free;
    dealloc_pointers := nil;
  finally
    lock_list.Release;
  end;

  lock_list.Free;
end;
class procedure CacheDeallocPointer.add(obj_type: PPyTypeObject);
begin
  // This is not so trivial - custom types created in python would have the same dealloc,
  // regardless if they are descendand of Delphi Class.
  // However we need the custom type object, that IS descendand of Delphi Class
  // to pass as True. Though his dealloc isnt right.
  // The only way to do this, is to get original dealloc, in that delphi module.
  // To do this, we cannot use this simple tp_dealloc from object, but dealloc that would have
  // some of its base object, but not necessarily direct parent, since this still
  // might be python defined class.
  // As all Delphi Classes has same dealloc, we need to iterate back to first
  // guaranteed delphi class in MRO, and read the tp_dealloc pointer
  // from there. However, since we dont know (and dont want to) know ALL Delphi
  // Classes tree, we need to traverse to common ancestor. This is for example
  // TPersistent. Since this will happen ONLY once for each possible module
  // with Delphi Classes, that we make instance from, this is not too much price
  // to pay.

  if not Assigned(obj_type) then
    Exit;

  while Assigned(obj_type) do begin
    if Assigned(obj_type^.tp_name) and (obj_type^.tp_name = 'Persistent') then begin
      lock_list.Acquire;
      try
        // PARANOID: If acquired from another thread just after free in destructor
        if Assigned(dealloc_pointers)
            // Even though from outer logic, this cant happen. Let us be
            // self sufficient.
            and not (dealloc_pointers.Contains(@obj_type^.tp_dealloc)) then
          dealloc_pointers.add(@obj_type^.tp_dealloc);
      finally
        lock_list.Release;
      end;

      break;
    end;
    obj_type := obj_type^.tp_base;
  end;
end;
class function CacheDeallocPointer.contains(obj_type: PPyTypeObject): Boolean;
begin
  // Not so trivial - see add().
  // We need to find, if any on the descendancy tree has same dealloc pointer
  // as registered one.
  if not Assigned(obj_type) then
    Exit(False);

  lock_list.Acquire;
  try
     // PARANOID: If acquired from another thread just after free in destructor
    if not Assigned(dealloc_pointers) then Exit(False);

    while Assigned(obj_type) do begin
      if dealloc_pointers.Contains(@obj_type^.tp_dealloc) then
        Exit(True);
      obj_type := obj_type^.tp_base;
    end;
  finally
    lock_list.Release;
  end;

  Exit(False);
end;
class function CacheDeallocPointer.contains(ptr: Pointer): Boolean;
begin
  lock_list.Acquire;
  try
    Exit(dealloc_pointers.Contains(ptr));
  finally
    lock_list.Release;
  end;
end;



function check_ancestor_list(obj_type: PPyTypeObject; const ancestor_list: array of AnsiString) : Boolean;
var
  idx: Integer;
begin
  if not Assigned(obj_type) then
    Exit(False);

  idx := 0;

  while Assigned(obj_type) and (idx < Length(ancestor_list)) do begin
    if Assigned(obj_type^.tp_name) and (obj_type^.tp_name = ancestor_list[idx]) then
      Inc(idx)
    else if idx <> 0 then begin
      idx := 0;
      continue;
    end;
    obj_type := obj_type^.tp_base;
  end;

  Result := (idx = Length(ancestor_list));
end;

function has_callable_attr(engine: TPythonEngine; obj: PPyObject; const name: PAnsiChar): Boolean;
begin
  Result := False;

  if not Assigned(obj) then Exit;

  var attr := engine.PyObject_GetAttrString(obj, name);
  if attr <> nil then begin
    Result := engine.PyCallable_Check(attr) <> 0;
    engine.Py_XDECREF(attr);
  end else
    engine.PyErr_Clear;  //We dont care about errors from GetAttrString
end;

function has_attr(engine: TPythonEngine; obj: PPyObject; const name: PAnsiChar): Boolean;
begin
  //consider using obj.ob_type^.tp_dict - might be faster, maybe
  Result := Assigned(obj) and (engine.PyObject_HasAttrString(obj, name) <> 0);
end;


function _is_delphi_type(const obj_type: PPyTypeObject): Boolean;
const
{$WRITEABLECONST OFF}
  FMX_TYPES: array[0..3] of AnsiString = ('FmxObject', 'Component', 'Persistent', 'Object');
  VCL_TYPES: array[0..2] of AnsiString = ('Component', 'Persistent', 'Object');
begin
  if not Assigned(obj_type) then Exit(False);

  // This is performance-wise cache. Working similarly to PythonEngine.IsDelphiObject
  // But on the contrary to mentioned function - this will work also cross module.
  if CacheDeallocPointer.contains(obj_type) then
    Exit(True);

  var engine := GetPythonEngine;

  { 1. Check Type Ancestry tree. All Delphi Components has some common ancestors }
  // Even though these are hard Delphi Classes ancestry tree, we
  // still cant be definitely sure, something else doesnt mimic same names.
  // (as we are checking only by names)
  Result := check_ancestor_list(obj_type, FMX_TYPES)
            or
            check_ancestor_list(obj_type, VCL_TYPES);

  { 2. Wrapped delphi components are always exposing some attributes }
  // This is another stacked tests - these attributes are also somewhat unique.
  var obj := PPyObject(obj_type); // Yes, this is ALWAYS safe cast, see definiton of PyObject and PyTypeobject
  Result := Result
            and has_attr(engine, obj, '__bound__') //from Persistent(TPersistent)
            and has_attr(engine, obj, '__owned__') //from Persistent(TPersistent)
            and has_callable_attr(engine, obj, 'InheritsFrom') //from Object(TObject)
            and has_callable_attr(engine, obj, 'Free')  //from Object(TObject)
            and has_callable_attr(engine, obj, 'SetProps');  //from Object(TObject)

  { 3. CPython PPyObject has always at least size containing both PyObject
    and TPyObject in P4D. See documentatiuon around PythonEngine.pas:TPyObject }
  Result := Result
            and (obj_type^.tp_basicsize >=  SizeOf(PyObject) + SizeOf(TPyObject));

  // Previous tests stacks and thus might be be enough to be sure.
  // This is however not 100%. If any other meaningful test comes to mind, we
  // sure should use it.

  if Result then
    CacheDeallocPointer.add(obj_type);
end;



function is_delphi_object(const py_obj: PPyObject): Boolean;
begin
  if not Assigned(py_obj) then
    Exit(False);

  // We dont need to worry, this returning TRUE if this is "type object" and not
  // instance, since the ob_type would then point to python metaclass.
  Result := _is_delphi_type(py_obj^.ob_type);
end;

function is_delphi_class(const obj: PPyObject): Boolean;
begin
  if not GetPythonEngine.PyClass_Check(obj) then
    Exit(False);

  // This is always safe cast, see definition of PPyObject and PPyTypeObject
  Result := _is_delphi_type(PPyTypeObject(obj));
end;

/// <summary>
///    Internal function! Used to find first ancestral type, that is directly
///    wrapped Delphi Class. IE. If passed python object, it wents
///    backward on ancestor, until it finds ancestor, that is directly
///    Delphi Wrapped type - this should have always have filled some
///    informations, for other usage, that python descendands may not have.
/// </summary>
///
/// <param name="obj"> The python object (can be instance or class), that is
///    of wrapped delphi type.
/// </param>
///
/// <returns>
///    Pointer to TPythonType instance packed within (PPyObject:PyTypeObject).
///    See PyTypeObject.tp_pythontype in PythonEngine.pas
/// </returns>
///
/// <remarks> For INTERNAL USE ONLY!! This relies on previous
/// CacheDeallocPointer cache (filled for example by is_delphi_object/class)
/// methods. Also it intentionally raises, when its not used on delphi based
/// object/type.
/// </remarks>
function find_delphi_base_python_type(obj_type: PPyTypeObject): Pointer;
begin

  while Assigned(obj_type) do begin
    if Assigned(obj_type^.tp_pythontype) then begin
      // This is sanity check: If dealloc is not cached, then we never
      // checked whether this is really delphi type, and thus we cant
      // be sure, this is not some kind of serious screw up. We could
      // reluctantly check with internal _is_delphi_type, but still.
      // The only place it could fail if tp_pythontype is propagated
      // further downhill of descendants tree, than tp_dealloc, which should
      // never happen.
      if not CacheDeallocPointer.contains(@obj_type^.tp_dealloc) then
        raise Exception.Create('Not a delphi descendand type: dealloc missing!');
      Exit(obj_type^.tp_pythontype);
    end;
    obj_type := obj_type^.tp_base;
  end;

  raise Exception.Create('Not a delphi descendand type: pythontype not found!');
end;

function _get_field_ptr(obj_ptr: Pointer; field_name: AnsiString): Pointer;
///  <summary>
///    Gets pointer to objects attribute by name. It will not suppose
///  any type, or anything, so it can work in various crossmodule
///  objects. This must use strictly RTTI, that has most chance t
///
begin
  var obj := TObject(obj_ptr);
  var cls := obj.ClassType;

  var rtti := TRTTIContext.Create;

  var cls_rtti := rtti.GetType(cls);
  if cls_rtti = nil then
    raise EDelphiRTTI.CreateFmt('No RTTIType for class object %p', [cls.ClassName]);


  var field_rtti := cls_rtti.GetField(field_name);
  if field_rtti = nil then
    raise EDelphiRTTI.CreateFmt('Field %s not found on class %s',
      [field_name, cls.ClassName]
    );

  Result := PPointer(PByte(obj_ptr) + field_rtti.Offset)^;
  TLogger.DEBUG('[%p:%d] ...', [obj_ptr, field_rtti.Offset]);
end;

function _invoke_class_method(cls: TClass; method_name: AnsiString): TValue;
begin
  var rtti := TRTTIContext.Create;

  var cls_rtti := rtti.GetType(cls);
  if cls_rtti = nil then
    raise EDelphiRTTI.CreateFmt('No RTTIType for class object %p', [cls.ClassName]);

  var method := cls_rtti.GetMethod(method_name);
  if (method = nil) then
    raise EDelphiRTTI.CreateFmt('Method %s not found on %s',
      [method_name, cls.ClassName]
    );
  if  not method.IsClassMethod then
    raise EDelphiRTTI.CreateFmt('Method %s is not class method on %s',
      [method_name, cls.ClassName]
    );

  var value := method.Invoke(cls, []);
  if value.IsEmpty then
    raise EDelphiRTTI.Create('Result of invoked method %s is empty!');

  Result := value;

end;

function convert_PythonTypePtr_to_TClass(python_type_ptr: Pointer): TClass;
/// <summary>
///    Extract base Delphi TClass from ^TPythonType.
///    The pointer to TPythonType can be extracted from PyTypeObject.tp_pythontype.
/// </summary>
///
/// <param name="python_type_ptr"> The pointer to TPythonType instance, that is
///    part of each PPyObject that is somehow wrapped Delphi (instance or class).
/// </param>
///
/// <returns>
///   Delphi TClass. Metaclass containing real Delphi class of wrapped PPyObject.
/// </returns>
///
/// <remarks>
/// The whole idea how to get to real delphi background type is from TPythonType
///   is based on following:
///
///  PPyObject
///    ↓ ob_type
///  PPyTypeObject
///    ↓ tp_pythontype
///  TPythonType
///    ↓ FPyObjectClass
///  TPyDelphiObject (wrapper class - all wrapped types should inherit from this)
///    ↓ DelphiObjectClass
///  TClass (actual Delphi type)
///  </remarks>
begin
  if python_type_ptr = nil then
    raise EDelphiRTTI.Create('Nil is definitely not TPythonType instance!');

  // This is the critical trick: get the *foreign* class, not my local TPythonType
  // Treat (POSSIBLY) foreign TPythonType instance as TObject
  // We cant treat is as local TPythonType object.
  // Since this type from different module can be different, we need to treat
  // it as object that wont be different, and  most safe for this would be
  // base delphi TObject. And from this we can actually get real class RTTI.
  // We could ofc use anything after TObject up to TPythonType, but the TObject
  // is safest bet here, since this type layout will probably never change even
  // between delphi versions (and thus will work also over different modules).
  var python_type_object := TObject(python_type_ptr);

  var py_object_class_ptr := _get_field_ptr(python_type_ptr, 'FPyObjectClass');

  var py_object_class := TClass(py_object_class_ptr);
  TLogger.DEBUG('TPyDelphiObject[%s] ...', [py_object_class.ClassName]);

  var value := _invoke_class_method(py_object_class, 'DelphiObjectClass');
  if not (value.Kind in [tkClass, tkClassRef]) then begin
    raise EDelphiRTTI.Create(Format('Result of DelphiObjectClass is Wrong! kind=%d type=%s ...', [
      GetEnumName(TypeInfo(TTypeKind), Ord(value.Kind)),
      string(value.TypeInfo.Name)
    ]));
  end;

  // safest: treat it as raw pointer-sized value
  //  Result := value.AsType<TClass>; <-- this is doing too much "damage",
  // and actually doesnt work (somehow).
  var value_content_ptr := PPointer(value.GetReferenceToRawData)^;
  Result := TClass(value_content_ptr);
end;

function get_delphi_based_class(const obj: PPyObject): TClass;
var
  // Pointer to TPythonType instance, however this is instance of type
  // from POSSIBLY different module, so not directly accessible.
  type_object: PPyTypeObject;

begin
  if is_delphi_object(obj) then begin
// For pure object (instance) this was tested to work even crossmodule,
// but its not probably always safe with object created in different module
// (unless TPyDelphiObject is guaranteed to be of same memory layout).
// First cast would be safe probably, this will not change and its even
// documented in PythonEngine.pas.
//    var py_object := TPyObject(PAnsiChar(obj)+Sizeof(PyObject));
//    var py_delphi_object := TPyDelphiObject(py_object);
//    var py_delphi_class := py_delphi_object.DelphiObjectClass;

    type_object := obj.ob_type;
    TLogger.DEBUG('    OBJECT...');
  end
  else if is_delphi_class(obj) then begin
    type_object := PPyTypeObject(obj);
    TLogger.DEBUG('    CLASS...');
  end
  else
    raise EDelphiRTTIInvalidArgument.Create('Argument not Delphi based object.');

  var python_type_ptr := find_delphi_base_python_type(type_object);
  TLogger.DEBUG('    %p', [python_type_ptr]);

  TLogger.DEBUG('Converting...');
  var delphi_type := convert_PythonTypePtr_to_TClass(python_type_ptr);
  TLogger.DEBUG(Format('Result type: %s', [delphi_type.ClassName]));

  Result := delphi_type;
end;

end.
