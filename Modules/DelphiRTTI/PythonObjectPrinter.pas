unit PythonObjectPrinter;

interface

uses
  PythonEngine;

  procedure print_metadata(const obj: PPyObject);

implementation

uses
  System.SysUtils;

procedure print_metadata(const obj: PPyObject);
begin
  with obj.ob_type^ do begin
    Writeln(Format('Generic: Type: %s ; PythonType: %s ', [
      tp_name,
      tp_base^.tp_name
    ]));
  end;


  Writeln(Format('IsDelphiObject: %s ; Assigned: %s ; FindPythonType: %s; obj->tpname: %s; tpdealloc: %s', [
    BoolToStr(IsDelphiObject(obj), True),
    BoolToStr(Assigned(obj), True),
    BoolToStr((PythonEngine.FindPythonType(obj.ob_type) <> nil), True),
    obj.ob_type^.tp_name,
    BoolToStr(@obj.ob_type^.tp_dealloc = @PyObjectDestructor, True)
  ]));

  Writeln(Format('tpdealloc: %p ; tpfree: %p ; tpdel: %p ; tpfinalize: %p ; tpnew: %p ; PyObjectDestructor: %p', [
    @obj.ob_type^.tp_dealloc,
    @obj.ob_type^.tp_free,
    @obj.ob_type^.tp_del,
    @obj.ob_type^.tp_finalize,
    @obj.ob_type^.tp_new,
    @PyObjectDestructor
  ]));
  Flush(Output);

  WriteLn(Format('obtype->name: %s ; obtype->obtype->name: %s ; obtype->obtype->obtype->name: %s', [
    obj.ob_type^.tp_name,
    obj.ob_type^.ob_type^.tp_name,
    obj.ob_type^.ob_type^.ob_type^.tp_name
//      obj.ob_type^.tp_base^.tp_name,
//      obj.ob_type^.tp_base^.tp_base^.tp_name,
//      obj.ob_type^.tp_base^.tp_base^.tp_base^.tp_name
  ]));
  Flush(Output);

  var objtype := obj.ob_type;
  while Assigned(objtype) do begin
    Write('Typename: ', objtype^.tp_name, ' ; '); Flush(Output);
    objtype := objtype^.tp_base;
  end;
  Writeln;

  objtype := obj.ob_type;
  Write('DEALLOCs: ');
  while Assigned(objtype) do begin
    Write(Format('%p ; ', [@objtype^.tp_dealloc])); Flush(Output);
    objtype := objtype^.tp_base;
  end;
  Writeln;

  WriteLn(Format('SIZES: PyObject: %d ; TPyObject: %d ; TPyObject.InstanceSize: %d ; obtype.basicsize: %d ;', [
     SizeOf(PyObject),
     SizeOf(TPyObject),
     TPyObject.InstanceSize,
     obj^.ob_type^.tp_basicsize
  ]));

  WriteLn(Format('POINTERS: PPyObject: %p ; TPyObject: %p ; tp_pythontype: %p', [
    Pointer(PAnsiChar(obj)),
    Pointer(PAnsiChar(obj)+Sizeof(PyObject)),
    obj.ob_type^.tp_pythontype
  ]));

end;

end.
