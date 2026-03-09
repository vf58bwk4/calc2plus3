unit GridUtils;

{$mode objfpc}
{$modeswitch nestedprocvars}
{$H+}
{$inline ON}

interface

uses
  Classes, Grids, Config;

procedure StringGridMouseWheelDown(SenderGrid: TStringGrid; const Shift: TShiftState; const MousePos: TPoint; var Handled: Boolean);
procedure StringGridMouseWheelUp(SenderGrid: TStringGrid; const Shift: TShiftState; const MousePos: TPoint; var Handled: Boolean);

function GetClickedGridRowIndex(const Grid: TCustomGrid): Integer;

procedure LoadStringGridFromCSV(Grid: TStringGrid; const Filename: String; const Delimiter: Char = ',');
procedure SaveStringGridToCSV(const Grid: TStringGrid; const Filename: String; const Delimiter: Char = ',');

function FindRowByCol0Value(const Grid: TStringGrid; const Col0Value: String; out aRow: Integer): Boolean;

procedure LoadGridFromDataFile(Grid: TStringGrid; const DataFile: TDataFile);
procedure SaveGridToDataFile(const Grid: TStringGrid; const DataFile: TDataFile);

implementation

uses
  SysUtils, Windows, Controls, CsvDocument, DataDir;

procedure LoadStringGridFromCSV(Grid: TStringGrid; const Filename: String; const Delimiter: Char);
var
  CSV:      TCSVDocument;
  Row, Col: Integer;
begin
  // Clean up any stale temp file left by a previous crashed save
  if FileExists(Filename + '.tmp') then
    SysUtils.DeleteFile(Filename + '.tmp');

  if not FileExists(Filename) then
    begin
    Exit;
    end;

  CSV           := TCSVDocument.Create;
  CSV.Delimiter := Delimiter;
    try
      begin
      CSV.LoadFromFile(Filename);

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

procedure SaveStringGridToCSV(const Grid: TStringGrid; const Filename: String; const Delimiter: Char);
var
  CSV:      TCSVDocument;
  TmpFile:  String;
  Row, Col: Integer;
begin
  TmpFile       := Filename + '.tmp';
  CSV           := TCSVDocument.Create;
  CSV.Delimiter := Delimiter;
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

  // Atomically replace the real file with the fully-written temp file
  if not MoveFileEx(PChar(TmpFile), PChar(Filename), MOVEFILE_REPLACE_EXISTING) then
    begin
    SysUtils.DeleteFile(TmpFile);
    raise Exception.CreateFmt('Could not save file "%s" (error %d)', [Filename, GetLastError]);
    end;
end;

function GetClickedGridRowIndex(const Grid: TCustomGrid): Integer;
var
  LocalPos: TPoint;
begin
  LocalPos := Grid.ScreenToClient(Mouse.CursorPos);
  Result := Grid.MouseToCell(LocalPos).Y;
end;

procedure StringGridMouseWheelDown(SenderGrid: TStringGrid; const Shift: TShiftState; const MousePos: TPoint; var Handled: Boolean);
var
  MaxTopRow: Integer;
begin
  MaxTopRow := SenderGrid.RowCount - (SenderGrid.ClientHeight div SenderGrid.DefaultRowHeight);
  if SenderGrid.TopRow < MaxTopRow then
    begin
    SenderGrid.TopRow := SenderGrid.TopRow + 1;
    end;
  Handled := True;
end;

procedure StringGridMouseWheelUp(SenderGrid: TStringGrid; const Shift: TShiftState; const MousePos: TPoint; var Handled: Boolean);
begin
  if SenderGrid.TopRow > 0 then
    begin
    SenderGrid.TopRow := SenderGrid.TopRow - 1;
    end;
  Handled := True;
end;

function FindRowByCol0Value(const Grid: TStringGrid; const Col0Value: String; out aRow: Integer): Boolean;
var
  Row: Integer;
begin
  for Row := Grid.FixedRows to Grid.RowCount - 1 do
    begin
    if AnsiCompareText(Grid.Cells[0, Row], Col0Value) = 0 then
      begin
      aRow := Row;
      Exit(True);
      end;
    end;
  Result := False;
end;

procedure LoadGridFromDataFile(Grid: TStringGrid; const DataFile: TDataFile);
var
  PathFilename: String;
begin
  PathFilename := GetDataDir(DataFile.Dirname) + '\' + DataFile.Filename;
  LoadStringGridFromCSV(Grid, PathFilename);
end;

procedure SaveGridToDataFile(const Grid: TStringGrid; const DataFile: TDataFile);
var
  PathFilename: String;
begin
  PathFilename := ForceDataDir(DataFile.Dirname) + '\' + DataFile.Filename;
  SaveStringGridToCSV(Grid, PathFilename);
end;

end.
