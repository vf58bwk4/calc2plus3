unit GridUtils;

{$mode objfpc}
{$modeswitch nestedprocvars}
{$H+}
{$inline ON}

interface

uses
  Classes, Grids;

procedure StringGridMouseWheelDown(SenderGrid: TStringGrid; const Shift: TShiftState; const MousePos: TPoint; var Handled: Boolean);
procedure StringGridMouseWheelUp(SenderGrid: TStringGrid; const Shift: TShiftState; const MousePos: TPoint; var Handled: Boolean);

procedure LoadStringGridFromCSV(Grid: TStringGrid; const Filename: String; const Delimiter: Char = ',');
procedure SaveStringGridToCSV(const Grid: TStringGrid; const Filename: String; const Delimiter: Char = ',');

function FindRowByCol0Value(const Grid: TStringGrid; const Col0Value: String; out aRow: Integer): Boolean;

implementation

uses
  SysUtils, CsvDocument;

procedure LoadStringGridFromCSV(Grid: TStringGrid; const Filename: String; const Delimiter: Char);
var
  CSV:      TCSVDocument;
  Row, Col: Integer;
begin
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
  Row, Col: Integer;
begin
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
      CSV.SaveToFile(Filename);
      end;
    finally
      begin
      CSV.Free;
      end;
    end;
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

end.
