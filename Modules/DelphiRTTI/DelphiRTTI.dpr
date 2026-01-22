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
  uMain in 'uMain.pas',
  WrapDelphiRTTI in 'WrapDelphiRTTI.pas';

{$I ..\..\Source\Definition.Inc}

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
end.


