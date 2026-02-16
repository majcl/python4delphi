{$IFDEF ANDROID}
program DelphiRTTI;
{$ELSE}
library DelphiRTTI;
{$ENDIF ANDROID}




{ Important note about DLL memory management: ShareMem must be the
  first unit in your library's USES clause AND your project's (select
  Project-View Source) USES clause if your DLL exports any procedures or
  functions that pass strings as parameters or function results. This
  applies to all strings passed to and from your DLL--even those that
  are nested in records and classes. ShareMem is the interface unit to
  the BORLNDMM.DLL shared memory manager, which must be deployed along
  with your DLL. To avoid using BORLNDMM.DLL, pass string information
  using PChar or ShortString parameters.

  Important note about VCL usage: when this DLL will be implicitly
  loaded and this DLL uses TWicImage / TImageCollection created in
  any unit initialization section, then Vcl.WicImageInit must be
  included into your library's USES clause. }


uses
  System.SysUtils,
  { P4D patched: cross-module TCustomAttribute fix; all "uses System.Rtti" in this project resolve to this copy }
  System.Rtti in 'sources\System.Rtti.pas',
  uMain in 'sources\uMain.pas',
  WrapDelphiRTTI in 'sources\WrapDelphiRTTI.pas',
  WrapDelphiRTTI_DebugHelpers in 'sources\debug_helpers\WrapDelphiRTTI_DebugHelpers.pas',
  WrapSimpleLogging in 'sources\WrapSimpleLogging.pas',
  DelphiComponentDetection in 'sources\DelphiComponentDetection.pas',
  DelphiRTTIExceptions in 'sources\DelphiRTTIExceptions.pas',
  PythonObjectPrinter in 'sources\PythonObjectPrinter.pas' {,
  System.Rtti;

{$STRONGLINKTYPES ON},
  SimpleLogging in 'sources\SimpleLogging.pas';

{$STRONGLINKTYPES ON}

//{$I ..\..\Source\Definition.Inc}

exports
  // This must match the pattern "PyInit_[ProjectName]"
	// So if the project is named DelphiFMX then
	//   the export must be PyInit_DelphiFMX
	PyInit_DelphiRTTI;

{$IFDEF MSWINDOWS}
{$E pyd}
{$ENDIF}
{$WARN SYMBOL_PLATFORM OFF}
{$IFDEF LINUX}
{$SONAME 'DelphiRTTI'}
{$ENDIF}
{$WARN SYMBOL_PLATFORM ON}
begin
  ReportMemoryLeaksOnShutdown := True;
end.


