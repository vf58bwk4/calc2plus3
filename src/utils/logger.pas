unit Logger;

{$mode ObjFPC}
{$H+}
{$inline ON}

interface

procedure LogError(const Message: String);
procedure LogWarning(const Message: String);

implementation

uses
  SysUtils, EventLog, LazFileUtils, Config, DataDir;

const
  LOG_SIZE_LIMIT = 1024 * 1024; // bytes; a bigger log is cleared on the first write of a session

var
  AppLog: TEventLog;

  {================ Private routines ================}

function CreateAppLog: TEventLog;
var
  LogPath: String;
begin
  LogPath := ForceDataDir(LOG_FILE.Dirname) + '\' + LOG_FILE.Filename;

  Result                       := TEventLog.Create(nil);
  Result.LogType               := ltFile;
  Result.FileName              := LogPath;
  Result.Identification        := APP_NAME;
  Result.AppendContent         := FileSizeUtf8(LogPath) < LOG_SIZE_LIMIT;
  Result.RaiseExceptionOnError := False;
end;

procedure WriteLog(const EventType: TEventType; const Message: String);
begin
    try
      begin
      if AppLog = nil then
        begin
        AppLog := CreateAppLog;
        end;
      AppLog.Log(EventType, Message);
      end;
    except
      begin
      // Logging must never break the application
      end;
    end;
end;

{================ Interface routines ==============}

procedure LogError(const Message: String);
begin
  WriteLog(etError, Message);
end;

procedure LogWarning(const Message: String);
begin
  WriteLog(etWarning, Message);
end;

finalization
  FreeAndNil(AppLog);

end.
