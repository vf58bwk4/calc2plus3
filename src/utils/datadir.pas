unit DataDir;

{$mode ObjFPC}
{$H+}
{$inline ON}

interface

function GetDataDir(const Dir: String): String;
function ForceDataDir(const Dir: String): String;

implementation

uses
  SysUtils, Windows, ShlObj, AppErrors;

function GetDataDir(const Dir: String): String;
var
  Path:    array[0..MAX_PATH] of Char;
  BaseDir: String;
begin
  if SHGetFolderPath(0, CSIDL_APPDATA, 0, 0, Path) <> S_OK then
    begin
    raise EStorageError.CreateFmt('Could not get AppData\Roaming folder (error %d)', [GetLastError]);
    end;

  BaseDir := IncludeTrailingPathDelimiter(Path);
  Result  := BaseDir + Dir;
end;

function ForceDataDir(const Dir: String): String;
var
  DataDir: String;
begin
  DataDir := GetDataDir(Dir);
  if not DirectoryExists(DataDir) then
    begin
    if not ForceDirectories(DataDir) then
      begin
      raise EStorageError.Create('Could not create directory: ' + DataDir);
      end;
    end;
  Result := DataDir;
end;

end.
