unit CSVStorage;

{$mode ObjFPC}
{$H+}
{$inline ON}

interface

uses
  Grids, Config, Storage;

type
  TCSVStorage = class(TInterfacedObject, IStorage)
  public
    procedure SaveGridToDataFile(const Grid: TStringGrid; const DataFile: TDataFile; const ConvertCell: TCellConverter);
    procedure LoadGridFromDataFile(Grid: TStringGrid; const DataFile: TDataFile; const ConvertCell: TCellConverter);

    procedure SaveWorkspace(const VarName, Expression: String; const Force: Boolean = False);
    function LoadWorkspace: TWorkspaceState;

    procedure SaveWindowState(const State: TMainWindowState; const Force: Boolean = False);
    function LoadWindowState: TMainWindowState;
  end;

implementation

uses
  SysUtils, Classes, Windows, CsvDocument, DataDir, AppErrors;

const
  CSV_DELIMITER = '|';

  CSV_COLS: record
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
      Left:    Byte;
      Top:     Byte;
      Visible: Byte;
      end
  = (Left: 0; Top: 1; Visible: 2);

  {================ Private routines ================}

function CreateCSV: TCSVDocument;
begin
  Result           := TCSVDocument.Create;
  Result.Delimiter := CSV_DELIMITER;
end;

{ Writes CSV to a temp file, then replaces the data file with it in one step }
procedure WriteDataFile(const CSV: TCSVDocument; const DataFile: TDataFile);
var
  PathFilename: String;
  TmpFilename:  String;
  ErrorCode:    DWORD;
begin
  PathFilename := ForceDataDir(DataFile.Dirname) + '\' + DataFile.Filename;
  TmpFilename  := PathFilename + '.tmp';

    try
      begin
      CSV.SaveToFile(TmpFilename);
      end;
    except
    on E: EStreamError do
      begin
      raise EStorageError.CreateFmt('Could not save file "%s": %s', [DataFile.Filename, E.Message]);
      end;
    end;

  if not MoveFileEx(PChar(TmpFilename), PChar(PathFilename), MOVEFILE_REPLACE_EXISTING) then
    begin
    ErrorCode := GetLastError;
    SysUtils.DeleteFile(TmpFilename);
    raise EStorageError.CreateFmt('Could not save file "%s": %s', [DataFile.Filename, SysErrorMessage(ErrorCode)]);
    end;
end;

{ Loads the data file into CSV. Returns False if the file does not exist }
function ReadDataFile(const DataFile: TDataFile; CSV: TCSVDocument): Boolean;
var
  PathFilename: String;
begin
  PathFilename := GetDataDir(DataFile.Dirname) + '\' + DataFile.Filename;

  // Clean up any stale temp file left by a previous crashed save
  SysUtils.DeleteFile(PathFilename + '.tmp');

  Result := SysUtils.FileExists(PathFilename);
  if Result then
    begin
      try
        begin
        CSV.LoadFromFile(PathFilename);
        end;
      except
      on E: EStreamError do
        begin
        raise EStorageError.CreateFmt('Could not load file "%s": %s', [DataFile.Filename, E.Message]);
        end;
      end;
    end;
end;

{================ Interface methods ===============}

procedure TCSVStorage.SaveGridToDataFile(const Grid: TStringGrid; const DataFile: TDataFile; const ConvertCell: TCellConverter);
var
  CSV:      TCSVDocument;
  Row, Col: Integer;
begin
  CSV := CreateCSV;
    try
      begin
      for Row := 0 to Grid.RowCount - Grid.FixedRows - 1 do
        begin
        for Col := 0 to Grid.ColCount - Grid.FixedCols - 1 do
          begin
          CSV.Cells[Col, Row] := ConvertCell(Grid.Cells[Grid.FixedCols + Col, Grid.FixedRows + Row]);
          end;
        end;
      WriteDataFile(CSV, DataFile);
      end;
    finally
      begin
      CSV.Free;
      end;
    end;
end;

procedure TCSVStorage.LoadGridFromDataFile(Grid: TStringGrid; const DataFile: TDataFile; const ConvertCell: TCellConverter);
var
  CSV:      TCSVDocument;
  Row, Col: Integer;
begin
  CSV := CreateCSV;
    try
      begin
      if ReadDataFile(DataFile, CSV) then
        begin
        Grid.RowCount := Grid.FixedRows + CSV.RowCount;
        for Row := 0 to CSV.RowCount - 1 do
          begin
          for Col := 0 to CSV.ColCount[Row] - 1 do
            begin
            Grid.Cells[Grid.FixedCols + Col, Grid.FixedRows + Row] := ConvertCell(CSV.Cells[Col, Row]);
            end;
          end;
        end;
      end;
    finally
      begin
      CSV.Free;
      end;
    end;
end;

procedure TCSVStorage.SaveWorkspace(const VarName, Expression: String; const Force: Boolean);
var
  CSV: TCSVDocument;
begin
  CSV := CreateCSV;
    try
      begin
      CSV.Cells[CSV_COLS.Key, WORKSPACE_ROWS.VarName]      := 'varname';
      CSV.Cells[CSV_COLS.Value, WORKSPACE_ROWS.VarName]    := VarName;
      CSV.Cells[CSV_COLS.Key, WORKSPACE_ROWS.Expression]   := 'expression';
      CSV.Cells[CSV_COLS.Value, WORKSPACE_ROWS.Expression] := Expression;
      WriteDataFile(CSV, WORKSPACE_FILE);
      end;
    finally
      begin
      CSV.Free;
      end;
    end;
end;

function TCSVStorage.LoadWorkspace: TWorkspaceState;
var
  CSV: TCSVDocument;
begin
  Result.VarName    := '';
  Result.Expression := '';

  CSV := CreateCSV;
    try
      begin
      if ReadDataFile(WORKSPACE_FILE, CSV) then
        begin
        if CSV.RowCount > WORKSPACE_ROWS.VarName then
          begin
          Result.VarName := CSV.Cells[CSV_COLS.Value, WORKSPACE_ROWS.VarName];
          end;
        if CSV.RowCount > WORKSPACE_ROWS.Expression then
          begin
          Result.Expression := CSV.Cells[CSV_COLS.Value, WORKSPACE_ROWS.Expression];
          end;
        end;
      end;
    finally
      begin
      CSV.Free;
      end;
    end;
end;

procedure TCSVStorage.SaveWindowState(const State: TMainWindowState; const Force: Boolean);
var
  CSV: TCSVDocument;
begin
  CSV := CreateCSV;
    try
      begin
      CSV.Cells[CSV_COLS.Key, WINPOS_ROWS.Left]      := 'left';
      CSV.Cells[CSV_COLS.Value, WINPOS_ROWS.Left]    := IntToStr(State.Left);
      CSV.Cells[CSV_COLS.Key, WINPOS_ROWS.Top]       := 'top';
      CSV.Cells[CSV_COLS.Value, WINPOS_ROWS.Top]     := IntToStr(State.Top);
      CSV.Cells[CSV_COLS.Key, WINPOS_ROWS.Visible]   := 'visible';
      CSV.Cells[CSV_COLS.Value, WINPOS_ROWS.Visible] := BoolToStr(State.Visible, '1', '0');
      WriteDataFile(CSV, WINPOS_FILE);
      end;
    finally
      begin
      CSV.Free;
      end;
    end;
end;

{ Without a stored state (first start) the window starts hidden }
function TCSVStorage.LoadWindowState: TMainWindowState;
var
  CSV: TCSVDocument;
begin
  Result.Left    := 0;
  Result.Top     := 0;
  Result.Visible := False;

  CSV := CreateCSV;
    try
      begin
      if ReadDataFile(WINPOS_FILE, CSV) then
        begin
        if CSV.RowCount > WINPOS_ROWS.Left then
          begin
          Result.Left := StrToIntDef(CSV.Cells[CSV_COLS.Value, WINPOS_ROWS.Left], 0);
          end;
        if CSV.RowCount > WINPOS_ROWS.Top then
          begin
          Result.Top := StrToIntDef(CSV.Cells[CSV_COLS.Value, WINPOS_ROWS.Top], 0);
          end;
        if CSV.RowCount > WINPOS_ROWS.Visible then
          begin
          Result.Visible := CSV.Cells[CSV_COLS.Value, WINPOS_ROWS.Visible] = '1';
          end;
        end;
      end;
    finally
      begin
      CSV.Free;
      end;
    end;
end;

end.
