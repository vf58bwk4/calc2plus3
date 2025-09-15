unit CalcService;

{$mode ObjFPC}
{$H+}

interface

uses
  Classes, SysUtils, Windows, StdCtrls, ComCtrls, Grids,
  ExprService, MainForm;

procedure SetCalculator(F: TCalculator);

procedure SetupFocus;
procedure SetupHistory;

procedure CalculateAndUpsertVariable;
procedure CalculateAndAddVariable;
procedure CalculateAndSubtractVariable;
procedure CalculateAndInsertInHistory;

procedure CopyFromHistoryToExpressionOnClick;
procedure CopyFromHistoryToExpressionOnKey;

procedure ReplaceExpressionFromHistoryOnClick;
procedure ReplaceExpressionFromHistoryOnKey;

procedure CopyFromVarListToExpressionOnClick;
procedure CopyFromVarListToExpressionOnKey;

procedure ReplaceExpressionFromVarListOnClick;
procedure ReplaceExpressionFromVarListOnKey;

procedure ReplaceVarNameFromVarListOnClick;
procedure ReplaceVarNameFromVarListOnKey;

procedure RemoveVariable;

procedure LoadHistory;
procedure LoadVarList;


implementation

uses
  Controls, FormUtils;

const
  DATA_DIR  = '2plus3';
  HIST_FILE = 'history.2p3';
  VARS_FILE = 'variables.2p3';

var
  LCHistory:      TStringGrid;
  LCVarName:     TEdit;
  LCExpression:   TEdit;
  LCVarList: TStringGrid;
  LCStatusBar:    TStatusBar;

procedure StatusOK;
begin
  LCStatusBar.SimpleText := 'OK';
end;

procedure StatusError(Message: String);
begin
  LCStatusBar.SimpleText := 'ERROR: ' + Message;
end;

procedure SaveGrid(Grid: TStringGrid; Filename: String);
var
  PathFilename: String;
begin
  PathFilename := ForceDataDir(DATA_DIR) + '\' + Filename;
  SaveStringGridToCSV(Grid, PathFilename);
end;

procedure SaveHistory;
begin
  SaveGrid(LCHistory, HIST_FILE);
end;

procedure SaveVariables;
begin
  SaveGrid(LCVarList, VARS_FILE);
end;

type
  TModifyVariableOp = (moReplace, moAdd, moSubtract);

procedure CalculateAndModifyVariable(Op: TModifyVariableOp);
var
  VarName:      String;
  VarValue, OldVarValue, NewVarValue: Double;
  DeleteRowIdx: Integer;
begin
  VarName         := Trim(LCVarName.Text);
  LCVarName.Text := VarName;
    try
      begin
      VarValue := ExprService.Calculate(LCExpression.Text);
      ExprService.UpsertVariable(VarName, VarValue);

      if FindRowByCol0Value(LCVarList, VarName, DeleteRowIdx) then
        begin
        OldVarValue := StrToFloat(LCVarList.Cells[1, DeleteRowIdx]);
        LCVarList.DeleteRow(DeleteRowIdx);
        end
      else
        begin
        OldVarValue := 0.0;
        end;
      case Op of
        moReplace:
          begin
          NewVarValue := VarValue;
          end;
        moAdd:
          begin
          NewVarValue := OldVarValue + VarValue;
          end;
        moSubtract:
          begin
          NewVarValue := OldVarValue - VarValue;
          end;
        end;
      LCVarList.InsertRowWithValues(LCVarList.FixedRows, [VarName, NewVarValue.ToString]);

      SaveVariables;

      StatusOK;
      end;
    except
    on E: Exception do
      begin
      StatusError(E.Message);
      end;
    end;
end;

procedure CalculateAndUpsertVariable;
begin
  CalculateAndModifyVariable(moReplace);
end;

procedure CalculateAndAddVariable;
begin
  CalculateAndModifyVariable(moAdd);
end;

procedure CalculateAndSubtractVariable;
begin
  CalculateAndModifyVariable(moSubtract);
end;


procedure CalculateAndInsertInHistory;
var
  NewExpression, NewResult: String;
  OldExpression, OldResult: String;
  LastRowIdx:               Integer;

  procedure HistoryInsertNewItem;
  var
    NewRowIdx: Integer;
  begin
    with LCHistory do
      begin
      NewRowIdx           := RowCount;
      RowCount            := NewRowIdx + 1;
      Cells[0, NewRowIdx] := NewResult;
      Cells[1, NewRowIdx] := NewExpression;
      TopRow              := NewRowIdx;
      end;
  end;

begin
    try
      begin
      NewExpression := LCExpression.Text;
      NewResult     := ExprService.Calculate(NewExpression).ToString;

      // TODO: move insertion logic away
      with LCHistory do
        begin
        if RowCount = 0 then
          begin
          HistoryInsertNewItem;
          end
        else
          begin
          LastRowIdx    := RowCount - 1;
          OldResult     := Cells[0, LastRowIdx];
          OldExpression := Cells[1, LastRowIdx];
          if not ((NewResult = OldResult) and (NewExpression = OldExpression)) then
            begin
            HistoryInsertNewItem;
            end;
          end;
        end;

      LCExpression.Text     := NewResult;
      LCExpression.SelStart := Length(NewResult);

      SaveHistory;

      StatusOK;
      end
    except
    on E: Exception do
      begin
      StatusError(E.Message);
      end;
    end;

end;

procedure InsertInExpression(Value: String);
var
  CursorPos, OldSelLength: Integer;
begin
  with LCExpression do
    begin
    CursorPos    := SelStart;
    OldSelLength := SelLength;

    Text     := Copy(Text, 1, CursorPos) + Value + Copy(Text, CursorPos + OldSelLength + 1, Length(Text));
    SelStart := CursorPos + Length(Value);

    SetFocus;
    end;
end;

procedure ReplaceExpression(Value: String);
begin
  LCExpression.Text     := Value;
  LCExpression.SelStart := Length(Value);
  LCExpression.SetFocus;
end;

procedure ReplaceVarName(Value: String);
begin
  LCVarName.Text      := Value;
  LCVarName.SelStart  := 1;
  LCVarName.SelLength := Length(Value);
  LCVarName.SetFocus;
end;

function GetClickedCellValue(Source: TStringGrid): String;
var
  LocalPos, CellPos: TPoint;
begin
  LocalPos := Source.ScreenToClient(Mouse.CursorPos);
  CellPos  := Source.MouseToCell(LocalPos);

  if (CellPos.Y >= Source.FixedRows) and (CellPos.X >= Source.FixedCols) then
    begin
    Result := Source.Cells[CellPos.X, CellPos.Y];
    end
  else
    begin
    raise Exception.Create('Clicked out of range');
    end;
end;

function GetKeyDownCellValue(Source: TStringGrid): String;
begin
  Result := Source.Cells[Source.Col, Source.Row];
end;

function GetClickedVarValue(Source: TStringGrid): String;
var
  LocalPos, CellPos: TPoint;
begin
  LocalPos := Source.ScreenToClient(Mouse.CursorPos);
  CellPos  := Source.MouseToCell(LocalPos);

  if (CellPos.Y >= Source.FixedRows) and (CellPos.X = Source.FixedCols) then
    begin
    Result := Source.Cells[CellPos.X, CellPos.Y];
    end
  else
    begin
    raise Exception.Create('Clicked on non-variable column');
    end;
end;

function GetKeyDownVarValue(Source: TStringGrid): String;
begin
  if Source.Col = Source.FixedCols then
    begin
    Result := Source.Cells[Source.Col, Source.Row];
    end
  else
    begin
    raise Exception.Create('Key down on non-variable column');
    end;
end;

type
  TOp       = (opCopy, opReplace);
  TOnAction = (oaKey, oaClick);
  TDestEdit = (deExpression, deVarName);

procedure Operation(Op: TOp; Source: TStringGrid; Dest: TDestEdit; Action: TOnAction);
var
  CellValue: String;
begin
    try
      begin
      if (Action = oaKey) and (Dest = deExpression) then
        begin
        CellValue := GetKeyDownCellValue(Source);
        end;
      if (Action = oaKey) and (Dest = deVarName) then
        begin
        CellValue := GetKeyDownVarValue(Source);
        end;
      if (Action = oaClick) and (Dest = deExpression) then
        begin
        CellValue := GetClickedCellValue(Source);
        end;
      if (Action = oaClick) and (Dest = deVarName) then
        begin
        CellValue := GetClickedVarValue(Source);
        end;

      if (Op = opCopy) and (Dest = deExpression) then
        begin
        InsertInExpression(CellValue);
        end;
      if (Op = opReplace) and (Dest = deExpression) then
        begin
        ReplaceExpression(CellValue);
        end;

      if (Op = opReplace) and (Dest = deVarName) then
        begin
        ReplaceVarName(CellValue);
        end;
      end;
    except
    end;
end;

procedure CopyFromHistoryToExpressionOnClick;
begin
  Operation(opCopy, LCHistory, deExpression, oaClick);
end;

procedure CopyFromHistoryToExpressionOnKey;
begin
  Operation(opCopy, LCHistory, deExpression, oaKey);
end;

procedure ReplaceExpressionFromHistoryOnClick;
begin
  Operation(opReplace, LCHistory, deExpression, oaClick);
end;

procedure ReplaceExpressionFromHistoryOnKey;
begin
  Operation(opReplace, LCHistory, deExpression, oaKey);
end;

procedure CopyFromVarListToExpressionOnKey;
begin
  Operation(opCopy, LCVarList, deExpression, oaKey);
end;

procedure CopyFromVarListToExpressionOnClick;
begin
  Operation(opCopy, LCVarList, deExpression, oaClick);
end;

procedure ReplaceExpressionFromVarListOnClick;
begin
  Operation(opReplace, LCVarList, deExpression, oaClick);
end;

procedure ReplaceExpressionFromVarListOnKey;
begin
  Operation(opReplace, LCVarList, deExpression, oaKey);
end;

procedure ReplaceVarNameFromVarListOnClick;
begin
  Operation(opReplace, LCVarList, deVarName, oaClick);
end;

procedure ReplaceVarNameFromVarListOnKey;
begin
  Operation(opReplace, LCVarList, deVarName, oaKey);
end;

procedure RemoveVariable;
var
  LocalPos:     TPoint;
  DeleteRowIdx: Integer;
  VarName:      String;
begin
  LocalPos     := LCVarList.ScreenToClient(Mouse.CursorPos);
  DeleteRowIdx := LCVarList.MouseToCell(LocalPos).Y;
  VarName      := LCVarList.Cells[LCVarList.FixedCols, DeleteRowIdx];

  LCVarList.DeleteRow(DeleteRowIdx);
  ExprService.RemoveVariable(VarName);

  SaveVariables;
end;

procedure SetupFocus;
begin
  LCExpression.SetFocus;
end;

procedure SetCalculator(F: TCalculator);
begin
  LCHistory                 := F.History;
  LCHistory.AutoFillColumns := True;

  LCVarName := F.VarName;
  SetEditMargins(LCVarName, 8, 8);

  LCExpression := F.Expression;
  SetEditMargins(LCExpression, 8, 8);

  LCVarList                 := F.VarList;
  LCVarList.AutoFillColumns := True;

  LCStatusBar := F.StatusBar;
  StatusOK;
end;

procedure LoadGrid(Grid: TStringGrid; Filename: String);
var
  PathFilename: String;
begin
    try
      begin
      PathFilename := GetDataDir(DATA_DIR) + '\' + Filename;
      LoadStringGridFromCSV(Grid, PathFilename);
      end;
    except
    on E: Exception do
      begin
      StatusError(E.Message);
      end;
    end;
end;


procedure UpsertVarList;
var
  Row: Integer;
begin
  for Row := LCVarList.FixedRows to LCVarList.RowCount - 1 do
    begin
    ExprService.UpsertVariable(LCVarList.Cells[0, Row], StrToFloat(LCVarList.Cells[1, Row]));
    end;
end;

procedure LoadHistory;
begin
  LoadGrid(LCHistory, HIST_FILE);
end;

procedure LoadVarList;
begin
  LoadGrid(LCVarList, VARS_FILE);
  UpsertVarList;
end;

procedure SetupHistory;
begin
  LCHistory.Row := LCHistory.RowCount - 1;
  LCHistory.Col := 0;
end;

end.
