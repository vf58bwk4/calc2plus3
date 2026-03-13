unit VariableService;

{$mode ObjFPC}
{$H+}
{$inline ON}

interface

uses
  Grids;

procedure Initialize(VarList: TStringGrid);
procedure ModifyVariable(const VarName: String; const NewValue: Double);
procedure RemoveItem;
function  GetValue(const VarName: String): Double;
function  Grid: TStringGrid;

implementation

uses
  SysUtils, Config, ExprService, Storage, GridUtils, DisplayService;

var
  _VarList: TStringGrid;

procedure Initialize(VarList: TStringGrid);
var
  Row: Integer;
begin
  _VarList := VarList;
  _VarList.AutoFillColumns := True;

  LoadGridFromDataFile(_VarList, VARS_FILE);

  for Row := _VarList.FixedRows to _VarList.RowCount - 1 do
    begin
    ExprService.UpsertVariable(_VarList.Cells[0, Row], StrToFloat(_VarList.Cells[1, Row]));
    end;
end;

procedure ModifyVariable(const VarName: String; const NewValue: Double);
var
  VarFound:     Boolean;
  DeleteRowIdx: Integer;
begin
  VarFound := FindRowByCol0Value(_VarList, VarName, DeleteRowIdx);

  ExprService.UpsertVariable(VarName, NewValue);

  if VarFound then
    begin
    _VarList.DeleteRow(DeleteRowIdx);
    end;
  _VarList.InsertRowWithValues(_VarList.FixedRows, [VarName, DisplayService.FormatNumber(NewValue)]);

  SaveGridToDataFile(_VarList, VARS_FILE);
end;

procedure RemoveItem;
var
  DeleteRowIdx: Integer;
  VarName:      String;
begin
    try
      begin
      DeleteRowIdx := GetClickedGridRowIndex(_VarList);
      VarName      := _VarList.Cells[_VarList.FixedCols, DeleteRowIdx];

      _VarList.DeleteRow(DeleteRowIdx);
      ExprService.RemoveVariable(VarName);

      SaveGridToDataFile(_VarList, VARS_FILE);

      DisplayService.StatusOK;
      end
    except
    on E: Exception do
      begin
      DisplayService.StatusError(E.Message);
      end;
    end;
end;

function GetValue(const VarName: String): Double;
var
  RowIdx: Integer;
begin
  if FindRowByCol0Value(_VarList, VarName, RowIdx) then
    begin
    Result := StrToFloat(_VarList.Cells[1, RowIdx]);
    end
  else
    begin
    Result := 0.0;
    end;
end;

function Grid: TStringGrid;
begin
  Result := _VarList;
end;

end.
