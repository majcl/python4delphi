unit WrapSimpleLogging;

interface

uses
  PythonEngine;

procedure RegisterSimpleLogging(AModule: TPythonModule);

implementation

uses
  System.SysUtils,
  SimpleLogging,
  DelphiRTTIExceptions;

function LoggingLevelToText(const ALevel: LoggingLevel): string;
begin
  case ALevel of
    LoggingLevel.DEBUG: Result := 'debug';
    LoggingLevel.INFO: Result := 'info';
    LoggingLevel.WARN: Result := 'warn';
    LoggingLevel.ERROR: Result := 'error';
    LoggingLevel.FATAL: Result := 'fatal';
  else
    Result := 'info';
  end;
end;

function TryParseLoggingLevel(const AText: string; out ALevel: LoggingLevel): Boolean;
var
  Normalized: string;
begin
  Normalized := LowerCase(Trim(AText));
  if Normalized = 'debug' then
    ALevel := LoggingLevel.DEBUG
  else if Normalized = 'info' then
    ALevel := LoggingLevel.INFO
  else if (Normalized = 'warn') or (Normalized = 'warning') then
    ALevel := LoggingLevel.WARN
  else if Normalized = 'error' then
    ALevel := LoggingLevel.ERROR
  else if Normalized = 'fatal' then
    ALevel := LoggingLevel.FATAL
  else
    Exit(False);
  Result := True;
end;

function OutputSystemToText(const AOutputSystem: LoggingOutputSystem): string;
begin
  case AOutputSystem of
    LoggingOutputSystem.stderr: Result := 'stderr';
    LoggingOutputSystem.stdout: Result := 'stdout';
    LoggingOutputSystem.filesystem: Result := 'filesystem';
  else
    Result := 'stderr';
  end;
end;

function TryParseOutputSystem(const AText: string; out AOutputSystem: LoggingOutputSystem): Boolean;
var
  Normalized: string;
begin
  Normalized := LowerCase(Trim(AText));
  if Normalized = 'stderr' then
    AOutputSystem := LoggingOutputSystem.stderr
  else if Normalized = 'stdout' then
    AOutputSystem := LoggingOutputSystem.stdout
  else if (Normalized = 'filesystem') or (Normalized = 'file') then
    AOutputSystem := LoggingOutputSystem.filesystem
  else
    Exit(False);
  Result := True;
end;

function py_set_logger_level(Self, Args: PPyObject): PPyObject; cdecl;
var
  LevelName: PAnsiChar;
  Level: LoggingLevel;
begin
  Result := nil;
  with GetPythonEngine do
  begin
    if PyArg_ParseTuple(Args, 's:set_logger_level', @LevelName) = 0 then
      Exit;

    if not TryParseLoggingLevel(string(LevelName), Level) then
    begin
      SetPythonError(PyExc_ValueError^, 'Unsupported log level "%s". Use: debug, info, warn, error, fatal.', [string(LevelName)]);
      Exit(nil);
    end;

    TLogger.LogLevel := Level;
    Result := ReturnNone;
  end;
end;

function py_get_logger_level(Self, Args: PPyObject): PPyObject; cdecl;
begin
  Result := nil;
  with GetPythonEngine do
  begin
    if PyArg_ParseTuple(Args, ':get_logger_level') = 0 then
      Exit;
    Result := PyUnicodeFromString(LoggingLevelToText(TLogger.LogLevel));
  end;
end;

function py_set_logger_output_system(Self, Args: PPyObject): PPyObject; cdecl;
var
  OutputSystemName: PAnsiChar;
  OutputSystem: LoggingOutputSystem;
begin
  Result := nil;
  with GetPythonEngine do
  begin
    if PyArg_ParseTuple(Args, 's:set_logger_output_system', @OutputSystemName) = 0 then
      Exit;

    if not TryParseOutputSystem(string(OutputSystemName), OutputSystem) then
    begin
      SetPythonError(PyExc_ValueError^, 'Unsupported output system "%s". Use: stderr, stdout, filesystem.', [string(OutputSystemName)]);
      Exit(nil);
    end;

    try
      TLogger.OutputSystem := OutputSystem;
    except
      on E: Exception do
      begin
        SetPythonError(PyExc_RuntimeError^, 'Failed to set output system: %s: %s', [E.ClassName, E.Message]);
        Exit(nil);
      end;
    end;
    Result := ReturnNone;
  end;
end;

function py_get_logger_output_system(Self, Args: PPyObject): PPyObject; cdecl;
begin
  Result := nil;
  with GetPythonEngine do
  begin
    if PyArg_ParseTuple(Args, ':get_logger_output_system') = 0 then
      Exit;
    Result := PyUnicodeFromString(OutputSystemToText(TLogger.OutputSystem));
  end;
end;

function py_set_logger_output_file(Self, Args: PPyObject): PPyObject; cdecl;
var
  Filepath: PAnsiChar;
begin
  Result := nil;
  with GetPythonEngine do
  begin
    if PyArg_ParseTuple(Args, 's:set_logger_output_file', @Filepath) = 0 then
      Exit;
    try
      TLogger.Filepath := string(Filepath);
    except
      on E: Exception do
      begin
        SetPythonError(PyExc_RuntimeError^, 'Failed to set logger output file: %s: %s', [E.ClassName, E.Message]);
        Exit(nil);
      end;
    end;
    Result := ReturnNone;
  end;
end;

function py_get_logger_output_file(Self, Args: PPyObject): PPyObject; cdecl;
begin
  Result := nil;
  with GetPythonEngine do
  begin
    if PyArg_ParseTuple(Args, ':get_logger_output_file') = 0 then
      Exit;
    Result := PyUnicodeFromString(TLogger.Filepath);
  end;
end;

function py_set_logger_always_flush(Self, Args: PPyObject): PPyObject; cdecl;
var
  AlwaysFlushInt: Integer;
begin
  Result := nil;
  with GetPythonEngine do
  begin
    if PyArg_ParseTuple(Args, 'p:set_logger_always_flush', @AlwaysFlushInt) = 0 then
      Exit;
    TLogger.AlwaysFlush := AlwaysFlushInt <> 0;
    Result := ReturnNone;
  end;
end;

function py_get_logger_always_flush(Self, Args: PPyObject): PPyObject; cdecl;
begin
  Result := nil;
  with GetPythonEngine do
  begin
    if PyArg_ParseTuple(Args, ':get_logger_always_flush') = 0 then
      Exit;
    Result := PyBool_FromLong(Ord(TLogger.AlwaysFlush));
  end;
end;

function py_logger_debug(Self, Args: PPyObject): PPyObject; cdecl;
var
  Msg: PAnsiChar;
begin
  Result := nil;
  with GetPythonEngine do
  begin
    if PyArg_ParseTuple(Args, 's:logger_debug', @Msg) = 0 then
      Exit;
    TLogger.DEBUG(string(Msg));
    Result := ReturnNone;
  end;
end;

function py_logger_info(Self, Args: PPyObject): PPyObject; cdecl;
var
  Msg: PAnsiChar;
begin
  Result := nil;
  with GetPythonEngine do
  begin
    if PyArg_ParseTuple(Args, 's:logger_info', @Msg) = 0 then
      Exit;
    TLogger.INFO(string(Msg));
    Result := ReturnNone;
  end;
end;

function py_logger_warn(Self, Args: PPyObject): PPyObject; cdecl;
var
  Msg: PAnsiChar;
begin
  Result := nil;
  with GetPythonEngine do
  begin
    if PyArg_ParseTuple(Args, 's:logger_warn', @Msg) = 0 then
      Exit;
    TLogger.WARN(string(Msg));
    Result := ReturnNone;
  end;
end;

function py_logger_error(Self, Args: PPyObject): PPyObject; cdecl;
var
  Msg: PAnsiChar;
begin
  Result := nil;
  with GetPythonEngine do
  begin
    if PyArg_ParseTuple(Args, 's:logger_error', @Msg) = 0 then
      Exit;
    TLogger.ERROR(string(Msg));
    Result := ReturnNone;
  end;
end;

function py_logger_fatal(Self, Args: PPyObject): PPyObject; cdecl;
var
  Msg: PAnsiChar;
begin
  Result := nil;
  with GetPythonEngine do
  begin
    if PyArg_ParseTuple(Args, 's:logger_fatal', @Msg) = 0 then
      Exit;
    TLogger.FATAL(string(Msg));
    Result := ReturnNone;
  end;
end;

procedure RegisterSimpleLogging(AModule: TPythonModule);
begin
  AModule.AddMethod('set_logger_level', @py_set_logger_level, 'set_logger_level(level: str) -> None. Level: debug|info|warn|error|fatal');
  AModule.AddMethod('get_logger_level', @py_get_logger_level, 'get_logger_level() -> str');
  AModule.AddMethod('set_logger_output_system', @py_set_logger_output_system, 'set_logger_output_system(system: str) -> None. System: stderr|stdout|filesystem');
  AModule.AddMethod('get_logger_output_system', @py_get_logger_output_system, 'get_logger_output_system() -> str');
  AModule.AddMethod('set_logger_output_file', @py_set_logger_output_file, 'set_logger_output_file(path: str) -> None');
  AModule.AddMethod('get_logger_output_file', @py_get_logger_output_file, 'get_logger_output_file() -> str');
  AModule.AddMethod('set_logger_always_flush', @py_set_logger_always_flush, 'set_logger_always_flush(enabled: bool) -> None');
  AModule.AddMethod('get_logger_always_flush', @py_get_logger_always_flush, 'get_logger_always_flush() -> bool');
  AModule.AddMethod('logger_debug', @py_logger_debug, 'logger_debug(message: str) -> None');
  AModule.AddMethod('logger_info', @py_logger_info, 'logger_info(message: str) -> None');
  AModule.AddMethod('logger_warn', @py_logger_warn, 'logger_warn(message: str) -> None');
  AModule.AddMethod('logger_error', @py_logger_error, 'logger_error(message: str) -> None');
  AModule.AddMethod('logger_fatal', @py_logger_fatal, 'logger_fatal(message: str) -> None');
end;

end.
