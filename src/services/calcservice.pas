unit CalcService;

{$mode ObjFPC}
{$H+}
{$inline ON}

interface

uses
  Classes, SysUtils, Windows, StdCtrls, ComCtrls, Grids,
  ExprService, MainForm;

procedure CalculateAndUpsertVariable;
procedure CalculateAndAddVariable;
procedure CalculateAndSubtractVariable;
procedure CalculateAndInsertInHistory;

procedure CopyFromHistoryToExpressionOnClick;
procedure CopyFromHistoryToExpressionOnKey;

procedure ReplaceExpressionFromHistoryOnClick;
procedure ReplaceExpressionFromHistoryOnKey;

procedure CopyFromVarListToExpressionOnKey;
procedure CopyFromVarListToExpressionOnClick;

procedure ReplaceExpressionFromVarListOnClick;
procedure ReplaceExpressionFromVarListOnKey;

procedure ReplaceVarNameFromVarListOnClick;
procedure ReplaceVarNameFromVarListOnKey;

procedure ClearExpression;
procedure ClearVarName;

procedure RemoveVariable;

procedure SetFocus;

procedure Init(F: TCalculator);
procedure InitCalculator;


implementation

uses
  Controls, DataDir, FormUtils, GridUtils;

const
  DATA_DIR  = '2plus3';
  HIST_FILE = 'history.2p3';
  VARS_FILE = 'variables.2p3';

var
  LCHistory:    TStringGrid;
  LCVarName:    TEdit;
  LCExpression: TEdit;
  LCVarList:    TStringGrid;
  LCStatusBar:  TStatusBar;

  {================ Private routines ================}

procedure StatusOK; inline;
begin
  LCStatusBar.SimpleText := 'OK';
end;

procedure StatusError(Message: String); inline;
begin
  LCStatusBar.SimpleText := 'ERROR: ' + Message;
end;

procedure LoadGrid(Grid: TStringGrid; Filename: String);
var
  PathFilename: String;
begin
  PathFilename := GetDataDir(DATA_DIR) + '\' + Filename;
  LoadStringGridFromCSV(Grid, PathFilename);
end;

procedure SaveGrid(Grid: TStringGrid; Filename: String);
var
  PathFilename: String;
begin
  PathFilename := ForceDataDir(DATA_DIR) + '\' + Filename;
  SaveStringGridToCSV(Grid, PathFilename);
end;

type
  TActionProc   = procedure(Value: String);
  TGetValueFunc = function(Source: TStringGrid): String;

procedure RunWithHandle(ActionProc: TActionProc; GetValueFunc: TGetValueFunc; Source: TStringGrid);
begin
    try
      begin
      ActionProc(GetValueFunc(Source));

      StatusOK;
      end;
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

procedure UpsertVarList;
var
  Row: Integer;
begin
  for Row := LCVarList.FixedRows to LCVarList.RowCount - 1 do
    begin
    ExprService.UpsertVariable(LCVarList.Cells[0, Row], StrToFloat(LCVarList.Cells[1, Row]));
    end;
end;

procedure SetupHistory; inline;
begin
  LCHistory.Row := LCHistory.RowCount - 1;
  LCHistory.Col := 0;
end;

type
  TModifyVariableOp = (moReplace, moAdd, moSubtract);

procedure CalculateAndModifyVariable(Op: TModifyVariableOp);
var
  VarName:      String;
  VarValue, OldVarValue, NewVarValue: Double;
  DeleteRowIdx: Integer;
begin
  VarName        := Trim(LCVarName.Text);
  LCVarName.Text := VarName;
    try
      begin
      if FindRowByCol0Value(LCVarList, VarName, DeleteRowIdx) then
        begin
        OldVarValue := StrToFloat(LCVarList.Cells[1, DeleteRowIdx]);
        LCVarList.DeleteRow(DeleteRowIdx);
        end
      else
        begin
        OldVarValue := 0.0;
        end;

      VarValue := ExprService.Calculate(LCExpression.Text);
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

      ExprService.UpsertVariable(VarName, VarValue);
      LCVarList.InsertRowWithValues(LCVarList.FixedRows, [VarName, NewVarValue.ToString]);
      SaveGrid(LCVarList, VARS_FILE);

      StatusOK;
      end;
    except
    on E: Exception do
      begin
      StatusError(E.Message);
      end;
    end;
end;


{================ Interface routines ==============}

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

      SaveGrid(LCHistory, HIST_FILE);

      StatusOK;
      end
    except
    on E: Exception do
      begin
      StatusError(E.Message);
      end;
    end;
end;

procedure CopyFromHistoryToExpressionOnClick;
begin
  RunWithHandle(@InsertInExpression, @GetClickedCellValue, LCHistory);
end;

procedure CopyFromHistoryToExpressionOnKey;
begin
  RunWithHandle(@InsertInExpression, @GetKeyDownCellValue, LCHistory);
end;

procedure ReplaceExpressionFromHistoryOnClick;
begin
  RunWithHandle(@ReplaceExpression, @GetClickedCellValue, LCHistory);
end;

procedure ReplaceExpressionFromHistoryOnKey;
begin
  RunWithHandle(@ReplaceExpression, @GetKeyDownCellValue, LCHistory);
end;

procedure CopyFromVarListToExpressionOnKey;
begin
  RunWithHandle(@InsertInExpression, @GetKeyDownCellValue, LCVarList);
end;

procedure CopyFromVarListToExpressionOnClick;
begin
  RunWithHandle(@InsertInExpression, @GetClickedCellValue, LCVarList);
end;

procedure ReplaceExpressionFromVarListOnClick;
begin
  RunWithHandle(@ReplaceExpression, @GetClickedCellValue, LCVarList);
end;

procedure ReplaceExpressionFromVarListOnKey;
begin
  RunWithHandle(@ReplaceExpression, @GetKeyDownCellValue, LCVarList);
end;

procedure ReplaceVarNameFromVarListOnClick;
begin
  RunWithHandle(@ReplaceVarName, @GetClickedVarValue, LCVarList);
end;

procedure ReplaceVarNameFromVarListOnKey;
begin
  RunWithHandle(@ReplaceVarName, @GetKeyDownVarValue, LCVarList);
end;

procedure ClearExpression;
begin
  LCExpression.Clear;
end;

procedure ClearVarName;
begin
  LCVarName.Clear;
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

  SaveGrid(LCVarList, VARS_FILE);
end;

var
  FocusSet: Boolean;

procedure SetFocus; inline;
begin
  if not FocusSet then
    begin
    LCExpression.SetFocus;
    FocusSet := True;
    end;
end;

procedure Init(F: TCalculator);
begin
  with F do
    begin
    LCHistory    := History;
    LCVarName    := VarName;
    LCExpression := Expression;
    LCVarList    := VarList;
    LCStatusBar  := StatusBar;
    end;
end;

procedure InitCalculator;
begin
  LCHistory.AutoFillColumns := True;
  LCVarList.AutoFillColumns := True;

  SetEditMargins(LCVarName, 8, 8);
  SetEditMargins(LCExpression, 8, 8);

    try
      begin
      LoadGrid(LCHistory, HIST_FILE);
      SetupHistory;

      LoadGrid(LCVarList, VARS_FILE);
      UpsertVarList;

      StatusOK;
      end;
    except
    on E: Exception do
      begin
      StatusError(E.Message);
      end;
    end;
end;


end.
