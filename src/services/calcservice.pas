unit CalcService;

{$mode ObjFPC}
{$H+}
{$modeswitch nestedprocvars}
{$inline ON}

interface

uses
  MainForm;

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

procedure Receive(const F: TCalculator);
procedure Initialize;


implementation

uses
  SysUtils, Windows, Controls, StdCtrls, ComCtrls, Grids,
  Config, ExprService, DataDir, FormUtils, GridUtils;

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

procedure StatusError(const Message: String); inline;
begin
  LCStatusBar.SimpleText := 'ERROR: ' + Message;
end;

procedure LoadGrid(Grid: TStringGrid; const DataFile: TDataFile);
var
  PathFilename: String;
begin
  PathFilename := GetDataDir(DataFile.Dirname) + '\' + DataFile.Filename;
  LoadStringGridFromCSV(Grid, PathFilename);
end;

procedure SaveGrid(const Grid: TStringGrid; const DataFile: TDataFile);
var
  PathFilename: String;
begin
  PathFilename := ForceDataDir(DataFile.Dirname) + '\' + DataFile.Filename;
  SaveStringGridToCSV(Grid, PathFilename);
end;

type
  TActionProc   = procedure(const Value: String);
  TGetValueFunc = function(const Source: TStringGrid; const Param: Integer): String;

procedure DoActionFromSource(ActionProc: TActionProc; GetValueFunc: TGetValueFunc; GetValueFuncParam: Integer; Source: TStringGrid);
begin
    try
      begin
      ActionProc(GetValueFunc(Source, GetValueFuncParam));

      StatusOK;
      end;
    except
    on E: Exception do
      begin
      StatusError(E.Message);
      end;
    end;
end;

procedure InsertInExpression(const Value: String);
var
  CursorPos, OldSelLength: Integer;
begin
  CursorPos    := LCExpression.SelStart;
  OldSelLength := LCExpression.SelLength;

  LCExpression.Text     := Copy(LCExpression.Text, 1, CursorPos) + Value + Copy(LCExpression.Text, CursorPos +
    OldSelLength + 1, Length(LCExpression.Text));
  LCExpression.SelStart := CursorPos + Length(Value);

  LCExpression.SetFocus;
end;

procedure ReplaceExpression(const Value: String);
begin
  LCExpression.Text     := Value;
  LCExpression.SelStart := Length(Value);
  LCExpression.SetFocus;
end;

procedure ReplaceVarName(const Value: String);
begin
  LCVarName.Text      := Value;
  LCVarName.SelStart  := 1;
  LCVarName.SelLength := Length(Value);
  LCVarName.SetFocus;
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
  TOperationFunc = function(const A, B: Double): Double is nested;

procedure CalculateAndModifyVariable(const OpFunc: TOperationFunc);
var
  VarName:      String;
  VarValue, OldVarValue, NewVarValue: Double;
  VarFound:     Boolean;
  DeleteRowIdx: Integer;
begin
    try
      begin
      VarName        := Trim(LCVarName.Text);
      LCVarName.Text := VarName;

      VarFound := FindRowByCol0Value(LCVarList, VarName, DeleteRowIdx);
      if VarFound then
        begin
        OldVarValue := StrToFloat(LCVarList.Cells[1, DeleteRowIdx]);
        end
      else
        begin
        OldVarValue := 0.0;
        end;
      VarValue    := ExprService.Calculate(LCExpression.Text);
      NewVarValue := OpFunc(OldVarValue, VarValue);

      ExprService.UpsertVariable(VarName, NewVarValue);
      SaveGrid(LCVarList, VARS_FILE);

      if VarFound then
        begin
        LCVarList.DeleteRow(DeleteRowIdx);
        end;
      LCVarList.InsertRowWithValues(LCVarList.FixedRows, [VarName, NewVarValue.ToString]);

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

  function OpFunc(const OldVal, NewVal: Double): Double;
  begin
    Result := NewVal;
  end;

begin
  CalculateAndModifyVariable(@OpFunc);
end;

procedure CalculateAndAddVariable;

  function OpFunc(const OldVal, NewVal: Double): Double;
  begin
    Result := OldVal + NewVal;
  end;

begin
  CalculateAndModifyVariable(@OpFunc);
end;

procedure CalculateAndSubtractVariable;

  function OpFunc(const OldVal, NewVal: Double): Double;
  begin
    Result := OldVal - NewVal;
  end;

begin
  CalculateAndModifyVariable(@OpFunc);
end;

procedure CalculateAndInsertInHistory;
var
  NewExpression, NewResult: String;

  procedure InsertInHistory;
  var
    OldExpression, OldResult: String;
    LastRowIdx:               Integer;

    procedure HistoryInsertNewItem;
    var
      NewRowIdx: Integer;
    begin
      NewRowIdx                     := LCHistory.RowCount;
      LCHistory.RowCount            := NewRowIdx + 1;
      LCHistory.Cells[0, NewRowIdx] := NewResult;
      LCHistory.Cells[1, NewRowIdx] := NewExpression;
      LCHistory.TopRow              := NewRowIdx;
    end;

  begin
    if LCHistory.RowCount = 0 then
      begin
      HistoryInsertNewItem;
      end
    else
      begin
      LastRowIdx    := LCHistory.RowCount - 1;
      OldResult     := LCHistory.Cells[0, LastRowIdx];
      OldExpression := LCHistory.Cells[1, LastRowIdx];
      if not ((NewResult = OldResult) and (NewExpression = OldExpression)) then
        begin
        HistoryInsertNewItem;
        end;
      end;
  end;

begin
    try
      begin
      NewExpression := LCExpression.Text;
      NewResult     := ExprService.Calculate(NewExpression).ToString;

      LCExpression.Text     := NewResult;
      LCExpression.SelStart := Length(NewResult);

      InsertInHistory;
      SaveGrid(LCHistory, HISTORY_FILE);

      StatusOK;
      end
    except
    on E: Exception do
      begin
      StatusError(E.Message);
      end;
    end;
end;

const
  ONE_COLUMN  = 0;
  TWO_COLUMNS = 1;

procedure CopyFromHistoryToExpressionOnClick;
begin
  DoActionFromSource(@InsertInExpression, @GetClickedCellValue, TWO_COLUMNS, LCHistory);
end;

procedure CopyFromHistoryToExpressionOnKey;
begin
  DoActionFromSource(@InsertInExpression, @GetKeyDownCellValue, TWO_COLUMNS, LCHistory);
end;

procedure ReplaceExpressionFromHistoryOnClick;
begin
  DoActionFromSource(@ReplaceExpression, @GetClickedCellValue, TWO_COLUMNS, LCHistory);
end;

procedure ReplaceExpressionFromHistoryOnKey;
begin
  DoActionFromSource(@ReplaceExpression, @GetKeyDownCellValue, TWO_COLUMNS, LCHistory);
end;

procedure CopyFromVarListToExpressionOnKey;
begin
  DoActionFromSource(@InsertInExpression, @GetKeyDownCellValue, TWO_COLUMNS, LCVarList);
end;

procedure CopyFromVarListToExpressionOnClick;
begin
  DoActionFromSource(@InsertInExpression, @GetClickedCellValue, TWO_COLUMNS, LCVarList);
end;

procedure ReplaceExpressionFromVarListOnClick;
begin
  DoActionFromSource(@ReplaceExpression, @GetClickedCellValue, TWO_COLUMNS, LCVarList);
end;

procedure ReplaceExpressionFromVarListOnKey;
begin
  DoActionFromSource(@ReplaceExpression, @GetKeyDownCellValue, TWO_COLUMNS, LCVarList);
end;

procedure ReplaceVarNameFromVarListOnClick;
begin
  DoActionFromSource(@ReplaceVarName, @GetClickedCellValue, ONE_COLUMN, LCVarList);
end;

procedure ReplaceVarNameFromVarListOnKey;
begin
  DoActionFromSource(@ReplaceVarName, @GetKeyDownCellValue, ONE_COLUMN, LCVarList);
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
    try
      begin
      LocalPos     := LCVarList.ScreenToClient(Mouse.CursorPos);
      DeleteRowIdx := LCVarList.MouseToCell(LocalPos).Y;
      VarName      := LCVarList.Cells[LCVarList.FixedCols, DeleteRowIdx];

      LCVarList.DeleteRow(DeleteRowIdx);
      ExprService.RemoveVariable(VarName);

      SaveGrid(LCVarList, VARS_FILE);

      StatusOK;
      end
    except
    on E: Exception do
      begin
      StatusError(E.Message);
      end;
    end;
end;

var
  FocusSet: Boolean;

procedure SetFocus;
begin
  if not FocusSet then
    begin
    LCExpression.SetFocus;
    FocusSet := True;
    end;
end;

procedure Receive(const F: TCalculator);
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

procedure Initialize;
begin
  LCHistory.AutoFillColumns := True;
  LCVarList.AutoFillColumns := True;

  SetEditMargins(LCVarName, 8, 8);
  SetEditMargins(LCExpression, 8, 8);

    try
      begin
      LoadGrid(LCHistory, HISTORY_FILE);
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
