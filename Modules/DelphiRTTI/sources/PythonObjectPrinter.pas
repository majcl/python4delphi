unit PythonObjectPrinter;

interface

uses
  PythonEngine;

  procedure print_metadata(const obj: PPyObject);

implementation

uses
  System.SysUtils,
  SimpleLogging;

procedure print_metadata(const obj: PPyObject);
begin
  with obj.ob_type^ do begin
    TLogger.DEBUG('Generic: Type: %s ; PythonType: %s ', [
      tp_name,
      tp_base^.tp_name
    ]);
  end;


  TLogger.DEBUG('IsDelphiObject: %s ; Assigned: %s ; FindPythonType: %s; obj->tpname: %s; tpdealloc: %s', [
    BoolToStr(IsDelphiObject(obj), True),
    BoolToStr(Assigned(obj), True),
    BoolToStr((PythonEngine.FindPythonType(obj.ob_type) <> nil), True),
    obj.ob_type^.tp_name,
    BoolToStr(@obj.ob_type^.tp_dealloc = @PyObjectDestructor, True)
  ]);

  TLogger.DEBUG('tpdealloc: %p ; tpfree: %p ; tpdel: %p ; tpfinalize: %p ; tpnew: %p ; PyObjectDestructor: %p', [
    @obj.ob_type^.tp_dealloc,
    @obj.ob_type^.tp_free,
    @obj.ob_type^.tp_del,
    @obj.ob_type^.tp_finalize,
    @obj.ob_type^.tp_new,
    @PyObjectDestructor
  ]);

  TLogger.DEBUG('obtype->name: %s ; obtype->obtype->name: %s ; obtype->obtype->obtype->name: %s', [
    obj.ob_type^.tp_name,
    obj.ob_type^.ob_type^.tp_name,
    obj.ob_type^.ob_type^.ob_type^.tp_name
//      obj.ob_type^.tp_base^.tp_name,
//      obj.ob_type^.tp_base^.tp_base^.tp_name,
//      obj.ob_type^.tp_base^.tp_base^.tp_base^.tp_name
  ]);

  var objtype := obj.ob_type;
  var type_chain := '';
  while Assigned(objtype) do begin
    type_chain := type_chain + 'Typename: ' + string(objtype^.tp_name) + ' ; ';
    objtype := objtype^.tp_base;
  end;
  TLogger.DEBUG(type_chain);

  objtype := obj.ob_type;
  var dealloc_chain := 'DEALLOCs: ';
  while Assigned(objtype) do begin
    dealloc_chain := dealloc_chain + Format('%p ; ', [@objtype^.tp_dealloc]);
    objtype := objtype^.tp_base;
  end;
  TLogger.DEBUG(dealloc_chain);

  TLogger.DEBUG('SIZES: PyObject: %d ; TPyObject: %d ; TPyObject.InstanceSize: %d ; obtype.basicsize: %d ;', [
     SizeOf(PyObject),
     SizeOf(TPyObject),
     TPyObject.InstanceSize,
     obj^.ob_type^.tp_basicsize
  ]);

  TLogger.DEBUG('POINTERS: PPyObject: %p ; TPyObject: %p ; tp_pythontype: %p', [
    Pointer(PAnsiChar(obj)),
    Pointer(PAnsiChar(obj)+Sizeof(PyObject)),
    obj.ob_type^.tp_pythontype
  ]);

end;

end.
