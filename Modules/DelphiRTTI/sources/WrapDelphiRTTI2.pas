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
  WrapDelphiVcl,
  Vcl.Forms,
  System.SysUtils,
  System.Rtti,
  Winapi.Windows,
  DelphiComponentDetection,
  DelphiRTTIExceptions;


function get_type_wrapper(Self, Args: PPyObject): PPyObject;
var
  type_to_inspect: PPyObject;
begin
  Result := GetPythonEngine.ReturnNone;

  with GetPythonEngine do  begin
    if PyArg_ParseTuple(Args, 'O:get_type', @type_to_inspect) = 0 then begin
      if PyErr_Occurred <> nil then begin
        WriteLn(Format('Error with argument parsing.', [])); Flush(Output);
        Exit
      end else
        PyErr_SetString(PyExc_TypeError^, 'get_type expect PyObject argument,' +
        ' that is wrapped delphi object or type or string name of type.');
    end;

    try
     var tt := get_delphi_based_class(type_to_inspect);
    except
      on E: EDelphiRTTIInvalidArgument do begin
       WriteLn(Format('Error on getting type info: %s', [E.ToString]));
       Exit(ReturnNone);
      end;
    end;
  end;

end;

procedure RegisterDelphiRTTI2(AModule: TPythonModule);
begin
  AModule.AddMethod('get_type', @get_type_wrapper, 'get_type(obj | class | name) -> RttiType');
end;


initialization

finalization


end.
