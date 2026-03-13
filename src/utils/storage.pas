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

procedure LoadGridFromDataFile(Grid: TStringGrid; const DataFile: TDataFile);
procedure SaveGridToDataFile(const Grid: TStringGrid; const DataFile: TDataFile);

procedure SaveWorkspace(const VarName, Expression: String);
function LoadWorkspace: TWorkspaceState;

procedure SaveWindowPos(const Pos: TPoint);
function LoadWindowPos: TPoint;

implementation

uses
  SysUtils, Windows, ShlObj, CsvDocument;

function GetDataDir(const Dir: String): String;
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

procedure LoadGridFromDataFile(Grid: TStringGrid; const DataFile: TDataFile);
var
  PathFilename: String;
  CSV:          TCSVDocument;
  Row, Col:     Integer;
begin
  PathFilename := GetDataDir(DataFile.Dirname) + '\' + DataFile.Filename;

  // Clean up any stale temp file left by a previous crashed save
  if FileExists(PathFilename + '.tmp') then
    SysUtils.DeleteFile(PathFilename + '.tmp');

  if not FileExists(PathFilename) then
    begin
    Exit;
    end;

  CSV           := TCSVDocument.Create;
  CSV.Delimiter := ',';
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
end;

procedure SaveGridToDataFile(const Grid: TStringGrid; const DataFile: TDataFile);
var
  PathFilename: String;
  TmpFile:      String;
  CSV:          TCSVDocument;
  Row, Col:     Integer;
begin
  try
    begin
    PathFilename := ForceDataDir(DataFile.Dirname) + '\' + DataFile.Filename;
    TmpFile      := PathFilename + '.tmp';

    CSV           := TCSVDocument.Create;
    CSV.Delimiter := ',';
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

    if not MoveFileEx(PChar(TmpFile), PChar(PathFilename), MOVEFILE_REPLACE_EXISTING) then
      begin
      SysUtils.DeleteFile(TmpFile);
      raise Exception.CreateFmt('Could not save file "%s" (error %d)', [PathFilename, GetLastError]);
      end;
    end;
  except
  on E: Exception do
    raise;
  end;
end;

const
  CSV_COL: record
    Key:   Byte;
    Value: Byte;
  end = (Key: 0; Value: 1);

  WORKSPACE_ROWS: record
    VarName:    Byte;
    Expression: Byte;
  end = (VarName: 0; Expression: 1);

  WINPOS_ROWS: record
    Left: Byte;
    Top:  Byte;
  end = (Left: 0; Top: 1);

procedure SaveWorkspace(const VarName, Expression: String);
var
  CSV:          TCSVDocument;
  PathFilename: String;
  TmpFilename:  String;
begin
  try
    begin
    PathFilename := ForceDataDir(WORKSPACE_FILE.Dirname) + '\' + WORKSPACE_FILE.Filename;
    TmpFilename  := PathFilename + '.tmp';

    CSV           := TCSVDocument.Create;
    CSV.Delimiter := ',';
      try
        begin
        CSV.Cells[CSV_COL.Key,   WORKSPACE_ROWS.VarName]    := 'varname';
        CSV.Cells[CSV_COL.Value, WORKSPACE_ROWS.VarName]    := VarName;
        CSV.Cells[CSV_COL.Key,   WORKSPACE_ROWS.Expression] := 'expression';
        CSV.Cells[CSV_COL.Value, WORKSPACE_ROWS.Expression] := Expression;
        CSV.SaveToFile(TmpFilename);
        end;
      finally
        begin
        CSV.Free;
        end;
      end;

    if not MoveFileEx(PChar(TmpFilename), PChar(PathFilename), MOVEFILE_REPLACE_EXISTING) then
      begin
      SysUtils.DeleteFile(TmpFilename);
      raise Exception.CreateFmt('Could not save workspace file "%s" (error %d)', [PathFilename, GetLastError]);
      end;
    end;
  except
  on E: Exception do
    raise;
  end;
end;

function LoadWorkspace: TWorkspaceState;
var
  PathFilename: String;
  CSV:          TCSVDocument;
begin
  Result.VarName    := '';
  Result.Expression := '';

    try
      begin
      PathFilename := GetDataDir(WORKSPACE_FILE.Dirname) + '\' + WORKSPACE_FILE.Filename;

      // Clean up any stale temp file from a previous crashed save
      if SysUtils.FileExists(PathFilename + '.tmp') then
        SysUtils.DeleteFile(PathFilename + '.tmp');

      if SysUtils.FileExists(PathFilename) then
        begin
        CSV           := TCSVDocument.Create;
        CSV.Delimiter := ',';
          try
            begin
            CSV.LoadFromFile(PathFilename);
            if CSV.RowCount > WORKSPACE_ROWS.VarName then
              Result.VarName := CSV.Cells[CSV_COL.Value, WORKSPACE_ROWS.VarName];
            if CSV.RowCount > WORKSPACE_ROWS.Expression then
              Result.Expression := CSV.Cells[CSV_COL.Value, WORKSPACE_ROWS.Expression];
            end;
          finally
            begin
            CSV.Free;
            end;
          end;
        end;
      end;
    except
      // Load is best-effort; return empty defaults on any error
    end;
end;

procedure SaveWindowPos(const Pos: TPoint);
var
  CSV:          TCSVDocument;
  PathFilename: String;
  TmpFilename:  String;
begin
  try
    begin
    PathFilename := ForceDataDir(WINPOS_FILE.Dirname) + '\' + WINPOS_FILE.Filename;
    TmpFilename  := PathFilename + '.tmp';

    CSV           := TCSVDocument.Create;
    CSV.Delimiter := ',';
      try
        begin
        CSV.Cells[CSV_COL.Key,   WINPOS_ROWS.Left] := 'left';
        CSV.Cells[CSV_COL.Value, WINPOS_ROWS.Left] := IntToStr(Pos.X);
        CSV.Cells[CSV_COL.Key,   WINPOS_ROWS.Top]  := 'top';
        CSV.Cells[CSV_COL.Value, WINPOS_ROWS.Top]  := IntToStr(Pos.Y);
        CSV.SaveToFile(TmpFilename);
        end;
      finally
        begin
        CSV.Free;
        end;
      end;

    if not MoveFileEx(PChar(TmpFilename), PChar(PathFilename), MOVEFILE_REPLACE_EXISTING) then
      begin
      SysUtils.DeleteFile(TmpFilename);
      raise Exception.CreateFmt('Could not save window position file "%s" (error %d)', [PathFilename, GetLastError]);
      end;
    end;
  except
  on E: Exception do
    raise;
  end;
end;

function LoadWindowPos: TPoint;
var
  PathFilename: String;
  CSV:          TCSVDocument;
begin
  Result.X := 0;
  Result.Y := 0;

    try
      begin
      PathFilename := GetDataDir(WINPOS_FILE.Dirname) + '\' + WINPOS_FILE.Filename;

      // Clean up any stale temp file from a previous crashed save
      if SysUtils.FileExists(PathFilename + '.tmp') then
        SysUtils.DeleteFile(PathFilename + '.tmp');

      if SysUtils.FileExists(PathFilename) then
        begin
        CSV           := TCSVDocument.Create;
        CSV.Delimiter := ',';
          try
            begin
            CSV.LoadFromFile(PathFilename);
            if CSV.RowCount > WINPOS_ROWS.Left then Result.X := StrToIntDef(CSV.Cells[CSV_COL.Value, WINPOS_ROWS.Left], 0);
            if CSV.RowCount > WINPOS_ROWS.Top  then Result.Y := StrToIntDef(CSV.Cells[CSV_COL.Value, WINPOS_ROWS.Top],  0);
            end;
          finally
            begin
            CSV.Free;
            end;
          end;
        end;
      end;
    except
      // Load is best-effort; return zeroed defaults on any error
    end;
end;

end.
