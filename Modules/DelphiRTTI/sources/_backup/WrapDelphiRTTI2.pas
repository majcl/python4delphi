unit WrapDelphiRTTI2;
{$STRONGLINKTYPES ON}
interface

uses
  PythonEngine,
  WrapDelphi;

procedure RegisterDelphiRTTI2(AModule: TPythonModule);

function get_type_wrapper(Self, Args: PPyObject): PPyObject; cdecl;



implementation

uses
  System.SysUtils,
  System.Rtti,
  DelphiComponentDetection;


function get_type_wrapper(Self, Args: PPyObject): PPyObject;
var
  type_to_inspect: PPyObject;
begin
  with GetPythonEngine do
  begin
    if PyArg_ParseTuple(Args, 'O:get_type', @type_to_inspect) = 0 then begin
      if PyErr_Occurred <> nil then begin
        WriteLn(Format('Error with argument parsing.', [])); Flush(Output);
        Exit
      end else
        PyErr_SetString(PyExc_TypeError^, 'get_type expect PyObject argument,' +
        ' that is wrapped delphi object or type or string name of type.');
    end;


//    var MinSize := SizeOf(PyObject) + SizeOf(TPyObject);  TPyObject.InstanceSize
//    if type_to_inspect^.ob_type^.tp_basicsize < SizeOf(PyObject) + SizeOf(TPyObject) then
//    Exit;
//    TRttiContext.FindType

    var rtti := TRttiContext.Create;
    var types := rtti.GetTypes;
    Write('RTTI Types: ');
    for var rtti_type in types do begin
      WriteLn('   ', rtti_type.ToString, ' -> ',
              rtti_type.QualifiedName, ' -> ',
              rtti_type.QualifiedClassName, ' ...  ',
              '[', rtti_type.UnitName, ':', rtti_type.UnitScope, ']');
    end;
    Writeln('====================================================='); Flush(Output);

    Write('RTTI Packages: ');
    for var rtti_pkg in rtti.GetPackages do begin
      Write(rtti_pkg.ToString, ' ; ');
    end;
    Writeln; Flush(Output);




    if PyUnicode_Check(type_to_inspect) then begin
      var type_str := PyUnicodeAsString(type_to_inspect);
      Writeln(Format('TYPE: string: %s', [type_str])); Flush(Output);
    end
    else if is_delphi_class(type_to_inspect) then begin
      WriteLn(Format('TYPE: Delphi Class type: %s', [
        PPyTypeObject(type_to_inspect)^.tp_name
      ])); Flush(Output)
    end else if is_delphi_object(type_to_inspect) then begin
      WriteLn(Format('TYPE: instance of Delphi Class: %s', [
        type_to_inspect.ob_type^.tp_name
      ]));
      Flush(Output);
    end else begin
      WriteLn(Format('TYPE: UNKNOWN.', [])); Flush(Output);
    end;


    Result := GetPythonEngine.ReturnNone;
  end;
end;

procedure RegisterDelphiRTTI2(AModule: TPythonModule);
begin
  AModule.AddMethod('get_type', @get_type_wrapper, 'get_type(obj | class | name) -> RttiType');
end;


initialization

finalization


end.
