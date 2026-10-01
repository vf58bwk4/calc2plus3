unit GridUtils;

{$mode ObjFPC}
{$modeswitch nestedprocvars}
{$H+}
{$inline ON}

interface

uses
  Classes, Grids;

procedure StringGridMouseWheelDown(Grid: TStringGrid; const Shift: TShiftState; const MousePos: TPoint; var Handled: Boolean);
procedure StringGridMouseWheelUp(Grid: TStringGrid; const Shift: TShiftState; const MousePos: TPoint; var Handled: Boolean);

function TryGetClickedRow(const Grid: TStringGrid; out Row: Integer): Boolean;

function FindRowByCol0Value(const Grid: TStringGrid; const Col0Value: String; out RowIdx: Integer): Boolean;

function TryGetClickedCellValue(const Grid: TStringGrid; const MaxCol: Integer; out Value: String): Boolean;
function TryGetKeyDownCellValue(const Grid: TStringGrid; const MaxCol: Integer; out Value: String): Boolean;

implementation

uses
  SysUtils, Controls, Windows;

function IsDataRow(const Grid: TStringGrid; const Row: Integer): Boolean;
begin
  Result := (Row >= Grid.FixedRows) and (Row < Grid.RowCount);
end;

function TryGetClickedRow(const Grid: TStringGrid; out Row: Integer): Boolean;
var
  LocalPos: TPoint;
begin
  LocalPos := Grid.ScreenToClient(Mouse.CursorPos);
  Row      := Grid.MouseToCell(LocalPos).Y;
  Result   := IsDataRow(Grid, Row);
end;

procedure StringGridMouseWheelDown(Grid: TStringGrid; const Shift: TShiftState; const MousePos: TPoint; var Handled: Boolean);
var
  MaxTopRow: Integer;
begin
  MaxTopRow := Grid.RowCount - (Grid.ClientHeight div Grid.DefaultRowHeight);
  if Grid.TopRow < MaxTopRow then
    begin
    Grid.TopRow := Grid.TopRow + 1;
    end;
  Handled := True;
end;

procedure StringGridMouseWheelUp(Grid: TStringGrid; const Shift: TShiftState; const MousePos: TPoint; var Handled: Boolean);
begin
  if Grid.TopRow > 0 then
    begin
    Grid.TopRow := Grid.TopRow - 1;
    end;
  Handled := True;
end;

function FindRowByCol0Value(const Grid: TStringGrid; const Col0Value: String; out RowIdx: Integer): Boolean;
var
  Row: Integer;
begin
  for Row := Grid.FixedRows to Grid.RowCount - 1 do
    begin
    if AnsiCompareText(Grid.Cells[0, Row], Col0Value) = 0 then
      begin
      RowIdx := Row;
      Exit(True);
      end;
    end;
  Result := False;
end;

function TryGetClickedCellValue(const Grid: TStringGrid; const MaxCol: Integer; out Value: String): Boolean;
var
  LocalPos, CellPos: TPoint;
  ClickedCol:        Integer;
begin
  LocalPos   := Grid.ScreenToClient(Mouse.CursorPos);
  CellPos    := Grid.MouseToCell(LocalPos);
  ClickedCol := CellPos.X - Grid.FixedCols;

  Value  := '';
  Result := IsDataRow(Grid, CellPos.Y) and (ClickedCol >= 0) and (ClickedCol < MaxCol);
  if Result then
    begin
    Value := Grid.Cells[CellPos.X, CellPos.Y];
    end;
end;

function TryGetKeyDownCellValue(const Grid: TStringGrid; const MaxCol: Integer; out Value: String): Boolean;
var
  KeyDownCol: Integer;
begin
  KeyDownCol := Grid.Col - Grid.FixedCols;

  Value  := '';
  Result := IsDataRow(Grid, Grid.Row) and (KeyDownCol >= 0) and (KeyDownCol < MaxCol);
  if Result then
    begin
    Value := Grid.Cells[Grid.Col, Grid.Row];
    end;
end;

end.
