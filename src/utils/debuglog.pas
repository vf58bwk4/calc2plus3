unit DebugLog;

{$mode objfpc}
{$modeswitch nestedprocvars}
{$H+}
{$inline ON}

interface

procedure DebugLog(const Msg: String);

implementation

uses
  SysUtils, DataDir;

procedure DebugLog(const Msg: String);
var
  LogFile: TextFile;
  LogPath: String;
begin
  LogPath := ForceDataDir('2plus3') + '\' + 'debug.log';

  AssignFile(LogFile, LogPath);
  if FileExists(LogPath) then
    begin
    Append(LogFile);
    end
  else
    begin
    Rewrite(LogFile);
    end;

  Writeln(LogFile, FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) + ' - ' + Msg);
  CloseFile(LogFile);
end;

end.

