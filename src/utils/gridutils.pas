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

function GetClickedGridRowIndex(const Grid: TCustomGrid): Integer;

function FindRowByCol0Value(const Grid: TStringGrid; const Col0Value: String; out RowIdx: Integer): Boolean;

function GetClickedCellValue(const Grid: TStringGrid; const MaxCol: Integer): String;
function GetKeyDownCellValue(const Grid: TStringGrid; const MaxCol: Integer): String;

implementation

uses
  SysUtils, Controls, Windows;

function GetClickedGridRowIndex(const Grid: TCustomGrid): Integer;
var
  LocalPos: TPoint;
begin
  LocalPos := Grid.ScreenToClient(Mouse.CursorPos);
  Result := Grid.MouseToCell(LocalPos).Y;
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

function GetClickedCellValue(const Grid: TStringGrid; const MaxCol: Integer): String;
var
  LocalPos, CellPos: TPoint;
  ClickedCol:        Integer;
begin
  LocalPos   := Grid.ScreenToClient(Mouse.CursorPos);
  CellPos    := Grid.MouseToCell(LocalPos);
  ClickedCol := CellPos.X - Grid.FixedCols;

  if (CellPos.Y >= Grid.FixedRows) and (ClickedCol >= 0) and (ClickedCol < MaxCol) then
    begin
    Result := Grid.Cells[CellPos.X, CellPos.Y];
    end
  else
    begin
    raise Exception.Create('Clicked out of range');
    end;
end;

function GetKeyDownCellValue(const Grid: TStringGrid; const MaxCol: Integer): String;
begin
  if (Grid.Col - Grid.FixedCols < MaxCol) then
    begin
    Result := Grid.Cells[Grid.Col, Grid.Row];
    end
  else
    begin
    raise Exception.Create('Key down on non-variable column');
    end;
end;

end.
