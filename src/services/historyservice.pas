unit HistoryService;

{$mode ObjFPC}
{$H+}
{$inline ON}

interface

uses
  Grids;

procedure Initialize(AHistory: TStringGrid);
procedure InsertItem(const ResultText, ExpressionText: String);
procedure RemoveItem;
function Grid: TStringGrid;

implementation

uses
  Config, Storage, GridUtils;

var
  History: TStringGrid;

procedure Initialize(AHistory: TStringGrid);
begin
  History                 := AHistory;
  History.AutoFillColumns := True;

  Storage.LoadGridFromDataFile(History, HISTORY_FILE);

  History.Row := History.RowCount - 1;
  History.Col := 0;
end;

procedure InsertItem(const ResultText, ExpressionText: String);
var
  OldExpression, OldResult: String;
  LastRowIdx, NewRowIdx:    Integer;

  procedure AppendRow;
  begin
    NewRowIdx                   := History.RowCount;
    History.RowCount            := NewRowIdx + 1;
    History.Cells[0, NewRowIdx] := ResultText;
    History.Cells[1, NewRowIdx] := ExpressionText;
    History.TopRow              := NewRowIdx;
  end;

begin
  if History.RowCount = 0 then
    begin
    AppendRow;
    end
  else
    begin
    LastRowIdx    := History.RowCount - 1;
    OldResult     := History.Cells[0, LastRowIdx];
    OldExpression := History.Cells[1, LastRowIdx];
    if not ((ResultText = OldResult) and (ExpressionText = OldExpression)) then
      begin
      AppendRow;
      end;
    end;
  Storage.SaveGridToDataFile(History, HISTORY_FILE);
end;

procedure RemoveItem;
begin
  History.DeleteRow(GetClickedGridRowIndex(History));
  Storage.SaveGridToDataFile(History, HISTORY_FILE);
end;

function Grid: TStringGrid;
begin
  Result := History;
end;

end.
