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
  Path:         array[0..MAX_PATH] of Char;
  BaseDir:      String;
  FolderResult: HRESULT;
begin
  FolderResult := SHGetFolderPath(0, CSIDL_APPDATA, 0, 0, Path);
  if FolderResult <> S_OK then
    begin
    raise EStorageError.CreateFmt('Could not get AppData\Roaming folder: %s (HRESULT 0x%.8x)',
      [SysErrorMessage(FolderResult), DWORD(FolderResult)]);
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
      raise EStorageError.CreateFmt('Could not create directory "%s": %s', [DataDir, SysErrorMessage(GetLastError)]);
      end;
    end;
  Result := DataDir;
end;

end.
