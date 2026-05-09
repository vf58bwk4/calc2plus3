unit VariableService;

{$mode ObjFPC}
{$H+}
{$inline ON}

interface

uses
  Grids;

procedure Initialize(AVarList: TStringGrid);
function FormatNumber(const Value: Double): String;
procedure ModifyVariable(const VarName: String; const NewValue: Double);
procedure RemoveItem;
function GetValue(const VarName: String): Double;
function Grid: TStringGrid;

implementation

uses
  SysUtils, Config, ExprService, Storage, GridUtils;

var
  VarList: TStringGrid;

function FormatNumber(const Value: Double): String;
begin
  Result := Value.ToString;
end;


procedure Initialize(AVarList: TStringGrid);
var
  Row: Integer;
begin
  VarList                 := AVarList;
  VarList.AutoFillColumns := True;

    try
      begin
      Storage.LoadGridFromDataFile(VarList, VARS_FILE);

      for Row := VarList.FixedRows to VarList.RowCount - 1 do
        begin
        ExprService.UpsertVariable(VarList.Cells[0, Row], StrToFloat(VarList.Cells[1, Row]));
        end;
      end;
    except
      begin
      // TODO: cleanup VarList and ExprService variables
      end;
    end;
end;

procedure ModifyVariable(const VarName: String; const NewValue: Double);
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

  Storage.SaveGridToDataFile(VarList, VARS_FILE);
end;

procedure RemoveItem;
var
  DeleteRowIdx: Integer;
  VarName:      String;
begin
  DeleteRowIdx := GetClickedGridRowIndex(VarList);
  VarName      := VarList.Cells[VarList.FixedCols, DeleteRowIdx];

  VarList.DeleteRow(DeleteRowIdx);
  ExprService.RemoveVariable(VarName);

  Storage.SaveGridToDataFile(VarList, VARS_FILE);
end;

function GetValue(const VarName: String): Double;
var
  RowIdx: Integer;
begin
  if FindRowByCol0Value(VarList, VarName, RowIdx) then
    begin
    Result := StrToFloat(VarList.Cells[1, RowIdx]);
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
