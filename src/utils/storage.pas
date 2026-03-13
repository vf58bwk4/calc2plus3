unit Storage;

{$mode ObjFPC}
{$H+}
{$inline ON}

interface

uses
  Types, Grids, Config;

type
  TWorkspaceState = record
    VarName:    String;
    Expression: String;
  end;

function ForceDataDir(const Dir: String): String;

procedure SaveGridToDataFile(const Grid: TStringGrid; const DataFile: TDataFile);
procedure LoadGridFromDataFile(Grid: TStringGrid; const DataFile: TDataFile);

procedure SaveWorkspace(const VarName, Expression: String);
function LoadWorkspace: TWorkspaceState;

procedure SaveWindowPos(const Pos: TPoint);
function LoadWindowPos: TPoint;

implementation

uses
  SysUtils, Windows, ShlObj, CsvDocument;

const
  CSV_DELIMITER = '|';

function GetDataDir(const Dir: String): String;
var
  Path:    array[0..MAX_PATH] of Char;
  BaseDir: String;
begin
  if SHGetFolderPath(0, CSIDL_APPDATA, 0, 0, Path) <> S_OK then
    begin
    raise Exception.CreateFmt('Could not get AppData\Roaming folder (error %d)', [GetLastError]);
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
      raise Exception.Create('Could not create directory: ' + DataDir);
      end;
    end;
  Result := DataDir;
end;

procedure SaveGridToDataFile(const Grid: TStringGrid; const DataFile: TDataFile);
var
  PathFilename: String;
  TmpFile:      String;
  CSV:          TCSVDocument;
  Row, Col:     Integer;
begin
  PathFilename := ForceDataDir(DataFile.Dirname) + '\' + DataFile.Filename;
  TmpFile      := PathFilename + '.tmp';

  CSV           := TCSVDocument.Create;
  CSV.Delimiter := CSV_DELIMITER;
    try
      try
        begin
        for Row := 0 to Grid.RowCount - Grid.FixedRows - 1 do
          begin
          for Col := 0 to Grid.ColCount - Grid.FixedCols - 1 do
            begin
            CSV.Cells[Col, Row] := Grid.Cells[Grid.FixedCols + Col, Grid.FixedRows + Row];
            end;
          end;
        CSV.SaveToFile(TmpFile);
        end;
      finally
        begin
        CSV.Free;
        end;
      end;
    except
      begin
      raise Exception.CreateFmt('Could not save file "%s" (error %d)', [DataFile.Filename, GetLastError]);
      end;
    end;

  if not MoveFileEx(PChar(TmpFile), PChar(PathFilename), MOVEFILE_REPLACE_EXISTING) then
    begin
    SysUtils.DeleteFile(TmpFile);
    raise Exception.CreateFmt('Could not save file "%s" (error %d)', [DataFile.Filename, GetLastError]);
    end;
end;

procedure LoadGridFromDataFile(Grid: TStringGrid; const DataFile: TDataFile);
var
  PathFilename: String;
  CSV:          TCSVDocument;
  Row, Col:     Integer;
begin
  PathFilename := GetDataDir(DataFile.Dirname) + '\' + DataFile.Filename;

  // Clean up any stale temp file left by a previous crashed save
  SysUtils.DeleteFile(PathFilename + '.tmp');

  if FileExists(PathFilename) then
    begin
    CSV           := TCSVDocument.Create;
    CSV.Delimiter := CSV_DELIMITER;
      try
        try
          begin
          CSV.LoadFromFile(PathFilename);
          Grid.RowCount := Grid.FixedRows + CSV.RowCount;
          for Row := 0 to CSV.RowCount - 1 do
            begin
            for Col := 0 to CSV.ColCount[Row] - 1 do
              begin
              Grid.Cells[Grid.FixedCols + Col, Grid.FixedRows + Row] := CSV.Cells[Col, Row];
              end;
            end;
          end;
        finally
          begin
          CSV.Free;
          end;
        end;
      except
        begin
        raise Exception.CreateFmt('Could not load file "%s" (error %d)', [DataFile.Filename, GetLastError]);
        end;
      end;
    end;
end;

const
  CSV_COL: record
      Key:   Byte;
      Value: Byte;
      end
  = (Key: 0; Value: 1);

  WORKSPACE_ROWS: record
      VarName:    Byte;
      Expression: Byte;
      end
  = (VarName: 0; Expression: 1);

  WINPOS_ROWS: record
      Left: Byte;
      Top:  Byte;
      end
  = (Left: 0; Top: 1);

procedure SaveWorkspace(const VarName, Expression: String);
var
  DataFile:     TDataFile;
  CSV:          TCSVDocument;
  PathFilename: String;
  TmpFilename:  String;
begin
  DataFile     := WORKSPACE_FILE;
  PathFilename := ForceDataDir(DataFile.Dirname) + '\' + DataFile.Filename;
  TmpFilename  := PathFilename + '.tmp';

  CSV           := TCSVDocument.Create;
  CSV.Delimiter := CSV_DELIMITER;
    try
      try
        begin
        CSV.Cells[CSV_COL.Key, WORKSPACE_ROWS.VarName]      := 'varname';
        CSV.Cells[CSV_COL.Value, WORKSPACE_ROWS.VarName]    := VarName;
        CSV.Cells[CSV_COL.Key, WORKSPACE_ROWS.Expression]   := 'expression';
        CSV.Cells[CSV_COL.Value, WORKSPACE_ROWS.Expression] := Expression;
        CSV.SaveToFile(TmpFilename);
        end;
      finally
        begin
        CSV.Free;
        end;
      end;
    except
      begin
      raise Exception.CreateFmt('Could not save file "%s" (error %d)', [DataFile.Filename, GetLastError]);
      end;
    end;

  if not MoveFileEx(PChar(TmpFilename), PChar(PathFilename), MOVEFILE_REPLACE_EXISTING) then
    begin
    SysUtils.DeleteFile(TmpFilename);
    raise Exception.CreateFmt('Could not save file "%s" (error %d)', [DataFile.Filename, GetLastError]);
    end;
end;

function LoadWorkspace: TWorkspaceState;
var
  DataFile:     TDataFile;
  PathFilename: String;
  CSV:          TCSVDocument;
begin
  DataFile          := WORKSPACE_FILE;
  Result.VarName    := '';
  Result.Expression := '';

  PathFilename := GetDataDir(DataFile.Dirname) + '\' + DataFile.Filename;

  // Clean up any stale temp file from a previous crashed save
  SysUtils.DeleteFile(PathFilename + '.tmp');

  if SysUtils.FileExists(PathFilename) then
    begin
    CSV           := TCSVDocument.Create;
    CSV.Delimiter := CSV_DELIMITER;
      try
        try
          begin
          CSV.LoadFromFile(PathFilename);
          if CSV.RowCount > WORKSPACE_ROWS.VarName then
            begin
            Result.VarName := CSV.Cells[CSV_COL.Value, WORKSPACE_ROWS.VarName];
            end;
          if CSV.RowCount > WORKSPACE_ROWS.Expression then
            begin
            Result.Expression := CSV.Cells[CSV_COL.Value, WORKSPACE_ROWS.Expression];
            end;
          end;
        finally
          begin
          CSV.Free;
          end;
        end;
      except
        begin
        raise Exception.CreateFmt('Could not load file "%s" (error %d)', [DataFile.Filename, GetLastError]);
        end;
      end;
    end;
end;

procedure SaveWindowPos(const Pos: TPoint);
var
  DataFile:     TDataFile;
  CSV:          TCSVDocument;
  PathFilename: String;
  TmpFilename:  String;
begin
  DataFile := WINPOS_FILE;

  PathFilename := ForceDataDir(DataFile.Dirname) + '\' + DataFile.Filename;
  TmpFilename  := PathFilename + '.tmp';

  CSV           := TCSVDocument.Create;
  CSV.Delimiter := CSV_DELIMITER;
    try
      try
        begin
        CSV.Cells[CSV_COL.Key, WINPOS_ROWS.Left]   := 'left';
        CSV.Cells[CSV_COL.Value, WINPOS_ROWS.Left] := IntToStr(Pos.X);
        CSV.Cells[CSV_COL.Key, WINPOS_ROWS.Top]    := 'top';
        CSV.Cells[CSV_COL.Value, WINPOS_ROWS.Top]  := IntToStr(Pos.Y);
        CSV.SaveToFile(TmpFilename);
        end;
      finally
        begin
        CSV.Free;
        end;
      end;
    except
      begin
      raise Exception.CreateFmt('Could not save file "%s" (error %d)', [DataFile.Filename, GetLastError]);
      end;
    end;

  if not MoveFileEx(PChar(TmpFilename), PChar(PathFilename), MOVEFILE_REPLACE_EXISTING) then
    begin
    SysUtils.DeleteFile(TmpFilename);
    raise Exception.CreateFmt('Could not save file "%s" (error %d)', [DataFile.Filename, GetLastError]);
    end;
end;

function LoadWindowPos: TPoint;
var
  DataFile:     TDataFile;
  PathFilename: String;
  CSV:          TCSVDocument;
begin
  DataFile := WINPOS_FILE;
  Result.X := 0;
  Result.Y := 0;

  PathFilename := GetDataDir(DataFile.Dirname) + '\' + DataFile.Filename;

  // Clean up any stale temp file from a previous crashed save
  SysUtils.DeleteFile(PathFilename + '.tmp');

  if SysUtils.FileExists(PathFilename) then
    begin
    CSV           := TCSVDocument.Create;
    CSV.Delimiter := CSV_DELIMITER;
      try
        try
          begin
          CSV.LoadFromFile(PathFilename);
          if CSV.RowCount > WINPOS_ROWS.Left then
            begin
            Result.X := StrToIntDef(CSV.Cells[CSV_COL.Value, WINPOS_ROWS.Left], 0);
            end;
          if CSV.RowCount > WINPOS_ROWS.Top then
            begin
            Result.Y := StrToIntDef(CSV.Cells[CSV_COL.Value, WINPOS_ROWS.Top], 0);
            end;
          end;
        finally
          begin
          CSV.Free;
          end;
        end;
      except
        begin
        raise Exception.CreateFmt('Could not load file "%s" (error %d)', [DataFile.Filename, GetLastError]);
        end;
      end;
    end;
end;

end.
