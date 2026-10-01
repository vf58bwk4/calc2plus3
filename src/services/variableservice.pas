unit VariableService;

{$mode ObjFPC}
{$H+}
{$inline ON}

interface

uses
  Grids;

procedure Initialize(AVarList: TStringGrid);
procedure UpsertItem(const VarName: String; const NewValue: Double);
function RemoveItem: Boolean;
function GetValue(const VarName: String): Double;
function Grid: TStringGrid;

implementation

uses
  SysUtils, Math, Config, ExprService, ExprLocale, Storage, GridUtils, Logger;

var
  VarList: TStringGrid;

procedure Initialize(AVarList: TStringGrid);
var
  Row, SkippedCount: Integer;
  Value:             Double;
begin
  VarList                     := AVarList;
  VarList.AutoFillColumns     := True;
  VarList.AllowOutboundEvents := False;

  Storage.LoadGridFromDataFile(VarList, VARS_FILE, @ExprLocale.ToLocal);

  SkippedCount := 0;
  for Row := VarList.RowCount - 1 downto VarList.FixedRows do
    begin
    if IsValidVariableName(VarList.Cells[0, Row])
       and TryParseNumber(VarList.Cells[1, Row], Value)
       and not (IsInfinite(Value) or IsNan(Value)) then
      begin
      ExprService.UpsertVariable(VarList.Cells[0, Row], Value);
      end
    else
      begin
      VarList.DeleteRow(Row);
      Inc(SkippedCount);
      end;
    end;

  if SkippedCount > 0 then
    begin
    LogWarning(Format('Skipped %d invalid rows in %s', [SkippedCount, VARS_FILE.Filename]));
    end;
end;

procedure UpsertItem(const VarName: String; const NewValue: Double);
var
  VarFound:     Boolean;
  DeleteRowIdx: Integer;
begin
  VarFound := FindRowByCol0Value(VarList, VarName, DeleteRowIdx);

  ExprService.UpsertVariable(VarName, NewValue);

  if VarFound then
    begin
    VarList.DeleteRow(DeleteRowIdx);
    end;
  VarList.InsertRowWithValues(VarList.FixedRows, [VarName, FormatNumber(NewValue)]);

  Storage.SaveGridToDataFile(VarList, VARS_FILE, @ExprLocale.ToInvariant);
end;

function RemoveItem: Boolean;
var
  DeleteRowIdx: Integer;
  VarName:      String;
begin
  Result := TryGetClickedRow(VarList, DeleteRowIdx);
  if Result then
    begin
    VarName := VarList.Cells[VarList.FixedCols, DeleteRowIdx];

    VarList.DeleteRow(DeleteRowIdx);
    ExprService.RemoveVariable(VarName);

    Storage.SaveGridToDataFile(VarList, VARS_FILE, @ExprLocale.ToInvariant);
    end;
end;

function GetValue(const VarName: String): Double;
var
  RowIdx: Integer;
begin
  if FindRowByCol0Value(VarList, VarName, RowIdx) then
    begin
    Result := ParseNumber(VarList.Cells[1, RowIdx]);
    end
  else
    begin
    Result := 0.0; // TODO: consider refactor this silent return
    end;
end;

function Grid: TStringGrid;
begin
  Result := VarList;
end;

end.
