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

function GetClickedGridRowIndex(const Grid: TCustomGrid): Integer;

function FindRowByCol0Value(const Grid: TStringGrid; const Col0Value: String; out aRow: Integer): Boolean;

function GetClickedCellValue(const Source: TStringGrid; const MaxClickedCol: Integer): String;
function GetKeyDownCellValue(const Source: TStringGrid; const MaxClickedCol: Integer): String;

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

function GetClickedCellValue(const Source: TStringGrid; const MaxClickedCol: Integer): String;
var
  LocalPos, CellPos: TPoint;
  ClickedCol:        Integer;
begin
  LocalPos   := Source.ScreenToClient(Mouse.CursorPos);
  CellPos    := Source.MouseToCell(LocalPos);
  ClickedCol := CellPos.X - Source.FixedCols;

  if (CellPos.Y >= Source.FixedRows) and (ClickedCol >= 0) and (ClickedCol <= MaxClickedCol) then
    begin
    Result := Source.Cells[CellPos.X, CellPos.Y];
    end
  else
    begin
    raise Exception.Create('Clicked out of range');
    end;
end;

function GetKeyDownCellValue(const Source: TStringGrid; const MaxClickedCol: Integer): String;
begin
  if (Source.Col - Source.FixedCols <= MaxClickedCol) then
    begin
    Result := Source.Cells[Source.Col, Source.Row];
    end
  else
    begin
    raise Exception.Create('Key down on non-variable column');
    end;
end;

end.
