unit HistoryService;

{$mode ObjFPC}
{$H+}
{$inline ON}

interface

uses
  Grids;

procedure Initialize(History: TStringGrid);
procedure InsertItem(const ResultText, ExpressionText: String);
procedure RemoveItem;
function  Grid: TStringGrid;

implementation

uses
  SysUtils, Config, GridUtils, DisplayService;

var
  _History: TStringGrid;

procedure Initialize(History: TStringGrid);
begin
  _History := History;
  _History.AutoFillColumns := True;

  LoadGridFromDataFile(_History, HISTORY_FILE);

  _History.Row := _History.RowCount - 1;
  _History.Col := 0;
end;

procedure InsertItem(const ResultText, ExpressionText: String);
var
  OldExpression, OldResult: String;
  LastRowIdx, NewRowIdx:    Integer;

  procedure AppendRow;
  begin
    NewRowIdx                     := _History.RowCount;
    _History.RowCount            := NewRowIdx + 1;
    _History.Cells[0, NewRowIdx] := ResultText;
    _History.Cells[1, NewRowIdx] := ExpressionText;
    _History.TopRow              := NewRowIdx;
  end;

begin
  if _History.RowCount = 0 then
    begin
    AppendRow;
    end
  else
    begin
    LastRowIdx    := _History.RowCount - 1;
    OldResult     := _History.Cells[0, LastRowIdx];
    OldExpression := _History.Cells[1, LastRowIdx];
    if not ((ResultText = OldResult) and (ExpressionText = OldExpression)) then
      begin
      AppendRow;
      end;
    end;

  SaveGridToDataFile(_History, HISTORY_FILE);
end;

procedure RemoveItem;
begin
    try
      begin
      _History.DeleteRow(GetClickedGridRowIndex(_History));

      SaveGridToDataFile(_History, HISTORY_FILE);

      DisplayService.StatusOK;
      end
    except
    on E: Exception do
      begin
      DisplayService.StatusError(E.Message);
      end;
    end;
end;

function Grid: TStringGrid;
begin
  Result := _History;
end;

end.
