unit DataDir;

{$mode ObjFPC}{$H+}
{$H+}
{$inline ON}

interface

function GetDataDir(Dir: String): String;
function ForceDataDir(Dir: String): String;

implementation

uses
  SysUtils, ShlObj;

function GetDataDir(Dir: String): String;
var
  Path:    array[0..MAX_PATH] of Char;
  BaseDir: String;
begin
  if SHGetFolderPath(0, CSIDL_APPDATA, 0, 0, Path) <> S_OK then
    begin
    raise Exception.Create('Could not get AppData\Roaming folder');
    end;

  BaseDir := IncludeTrailingPathDelimiter(Path);
  Result  := BaseDir + Dir;
end;

function ForceDataDir(Dir: String): String;
var
  DataDir: String;
begin
  DataDir := GetDataDir(Dir);
  if not DirectoryExists(DataDir) then
    begin
    if not ForceDirectories(DataDir) then
      begin
      raise Exception.Create('Could not create directory: ' + DataDir);
      end;
    end;
  Result := DataDir;
end;

end.

