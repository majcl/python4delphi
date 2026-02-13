unit SimpleLogging;

interface
type LoggingOutputSystem = (stderr, stdout, filesystem);
type LoggingLevel = (DEBUG, INFO, WARN, ERROR, FATAL);
type TLogger = class(TObject)
  private
    class var FOutputSystem: LoggingOutputSystem;
    class var FFilepath: string;
    class var FOutputFile: TextFile;
    class var FOutputFileOpened: Boolean;
    class var PFOutputFD: ^TextFile;
    class var FAlwaysFlush: Boolean;
    class var FLogLevel: LoggingLevel;

    class procedure SetOutputSystem(const AOutputSystem: LoggingOutputSystem); static;
    class procedure SetOutputFile(const AFilepath: string); static;

  public
    class property OutputSystem: LoggingOutputSystem read FOutputSystem write SetOutputSystem;
    class property Filepath: string read FFilepath write SetOutputFile;
    class property LogLevel: Logginglevel read FLogLevel write FLogLevel;
    class property AlwaysFlush: Boolean read FAlwaysFlush write FAlwaysFlush;


    class constructor Create;
    class destructor Destroy;

    class procedure LOG(const ALevel: LoggingLevel; const AMessage: string); overload;
    class procedure LOG(const ALevel: LoggingLevel; const AFormatMessage: string; AArgs: array of const); overload;

    class procedure DEBUG(const AMessage: string); overload;
    class procedure DEBUG(const AFormatMessage: string; AArgs: array of const); overload;
    class procedure INFO(const AMessage: string); overload;
    class procedure INFO(const AFormatMessage: string; AArgs: array of const); overload;
    class procedure WARN(const AMessage: string); overload;
    class procedure WARN(const AFormatMessage: string; AArgs: array of const); overload;
    class procedure ERROR(const AMessage: string); overload;
    class procedure ERROR(const AFormatMessage: string; AArgs: array of const); overload;
    class procedure FATAL(const AMessage: string); overload;
    class procedure FATAL(const AFormatMessage: string; AArgs: array of const); overload;



end;

implementation
uses
  System.SysUtils;


procedure FinishFile(var F: TextFile);
begin
  Flush(F);
  CloseFile(F);
end;


 { -------------------------------------------------------------------------}
 { -------------------------------  TLogger  -------------------------------}
 { -------------------------------------------------------------------------}
class constructor TLogger.Create;
begin
  FAlwaysFlush := True;
  FLogLevel := LoggingLevel.INFO;
  FFilepath := '';
  FOutputFileOpened := False;
  OutputSystem := LoggingOutputSystem.stderr;
end;
class destructor TLogger.Destroy;
begin
  if FOutputFileOpened then
  begin
    FinishFile(FOutputFile);
    FOutputFileOpened := False;
  end;
end;


class procedure TLogger.SetOutputSystem(const AOutputSystem: LoggingOutputSystem);
begin
  FOutputSystem := AOutputSystem;
  case AOutputSystem of
    stderr: PFOutputFD := @ErrOutput;
    stdout: PFOutputFD := @Output;
    filesystem: begin
      if not FOutputFileOpened then
        SetOutputFile(FFilepath)
      else
        PFOutputFD := @FOutputFile;
    end;
  end;
end;


class procedure TLogger.SetOutputFile(const AFilepath: string);
begin
  if FOutputFileOpened then
  begin
    FinishFile(FOutputFile);
    FOutputFileOpened := False;
  end;


  AssignFile(FOutputFile, AFilepath);
  Rewrite(FOutputFile);
  PFOutputFD := @FOutputFile;
  FOutputFileOpened := True;
  FFilepath := AFilePath;
end;

class procedure TLogger.LOG(const ALevel: LoggingLevel; const AMessage: string);
begin
  if ALevel < TLogger.FLogLevel then
    Exit;

  WriteLn(PFOutputFD^, AMessage);

  if FAlwaysFlush then
    Flush(PFOutputFD^);
end;

class procedure TLogger.LOG(const ALevel: LoggingLevel; const AFormatMessage: string; AArgs: array of const);
begin
  LOG(ALevel, Format(AFormatMessage, AArgs));
end;

class procedure TLogger.DEBUG(const AMessage: string);
begin
  TLogger.LOG(LoggingLevel.DEBUG, AMessage);
end;

class procedure TLogger.DEBUG(const AFormatMessage: string; AArgs: array of const);
begin
  TLogger.LOG(LoggingLevel.DEBUG, AFormatMessage, AArgs);
end;

class procedure TLogger.INFO(const AMessage: string);
begin
  TLogger.LOG(LoggingLevel.INFO, AMessage);
end;

class procedure TLogger.INFO(const AFormatMessage: string; AArgs: array of const);
begin
  TLogger.LOG(LoggingLevel.INFO, AFormatMessage, AArgs);
end;

class procedure TLogger.WARN(const AMessage: string);
begin
  TLogger.LOG(LoggingLevel.WARN, AMessage);
end;

class procedure TLogger.WARN(const AFormatMessage: string; AArgs: array of const);
begin
  TLogger.LOG(LoggingLevel.WARN, AFormatMessage, AArgs);
end;

class procedure TLogger.ERROR(const AMessage: string);
begin
  TLogger.LOG(LoggingLevel.ERROR, AMessage);
end;

class procedure TLogger.ERROR(const AFormatMessage: string; AArgs: array of const);
begin
  TLogger.LOG(LoggingLevel.ERROR, AFormatMessage, AArgs);
end;

class procedure TLogger.FATAL(const AMessage: string);
begin
  TLogger.LOG(LoggingLevel.FATAL, AMessage);
end;

class procedure TLogger.FATAL(const AFormatMessage: string; AArgs: array of const);
begin
  TLogger.LOG(LoggingLevel.FATAL, AFormatMessage, AArgs);
end;

end.
