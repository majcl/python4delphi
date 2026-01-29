unit DelphiComponentDetection;

interface

uses
  PythonEngine,
  WrapDelphi;


function is_delphi_class(const obj: PPyObject): Boolean;
function is_delphi_object(const py_obj: PPyObject): Boolean;

implementation

uses
    System.SyncObjs,
    System.Generics.Collections;

// We want this class to be shared - Singleton.
// This is somewhat more convenient, than getInstance for each interaction.
type CacheDeallocPointer = class
  public
    class constructor Create;
    class destructor Destroy;
    class procedure add(obj_type: PPyTypeObject);
    class function contains(obj_type: PPyTypeObject): Boolean;

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
  // Not so trivial - see add_dealloc.
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

  // Even though these are hard Delphi Classes ancestry tree, we
  // still cant be definitely sure, something else doesnt mimic same names.
  // (as we are checking only by names)
  Result := check_ancestor_list(obj_type, FMX_TYPES)
            or
            check_ancestor_list(obj_type, VCL_TYPES);

  // This is another stacked tests - these attributes are also somewhat unique.
  var obj := PPyObject(obj_type); // Yes, this is ALWAYS safe cast, see definiton of PyObject and PyTypeobject
  Result := Result
            and has_attr(engine, obj, '__bound__') //from Persistent(TPersistent)
            and has_attr(engine, obj, '__owned__') //from Persistent(TPersistent)
            and has_callable_attr(engine, obj, 'InheritsFrom') //from Object(TObject)
            and has_callable_attr(engine, obj, 'Free')  //from Object(TObject)
            and has_callable_attr(engine, obj, 'SetProps');  //from Object(TObject)

  // Previous two tests stacks and thus might be be enough to be sure.
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

end.
