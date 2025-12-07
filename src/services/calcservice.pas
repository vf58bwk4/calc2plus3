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
procedure RemoveHistoryItem;

procedure SetFocus;

procedure Receive(const F: TCalculator);
procedure Initialize;


implementation

uses
  SysUtils, Windows, Controls, StdCtrls, ComCtrls, Grids,
  Config, ExprService, DataDir, FormUtils, GridUtils;

var
  _History:    TStringGrid;
  _VarName:    TEdit;
  _Expression: TEdit;
  _VarList:    TStringGrid;
  _StatusBar:  TStatusBar;

  {================ Private routines ================}

procedure StatusOK; inline;
begin
  _StatusBar.SimpleText := 'OK';
end;

procedure StatusError(const Message: String); inline;
begin
  _StatusBar.SimpleText := 'ERROR: ' + Message;
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
  CursorPos    := _Expression.SelStart;
  OldSelLength := _Expression.SelLength;

  _Expression.Text     := Copy(_Expression.Text, 1, CursorPos) + Value + Copy(_Expression.Text, CursorPos +
    OldSelLength + 1, Length(_Expression.Text));
  _Expression.SelStart := CursorPos + Length(Value);

  _Expression.SetFocus;
end;

procedure ReplaceExpression(const Value: String);
begin
  _Expression.Text     := Value;
  _Expression.SelStart := Length(Value);
  _Expression.SetFocus;
end;

procedure ReplaceVarName(const Value: String);
begin
  _VarName.Text      := Value;
  _VarName.SelStart  := 1;
  _VarName.SelLength := Length(Value);
  _VarName.SetFocus;
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
  for Row := _VarList.FixedRows to _VarList.RowCount - 1 do
    begin
    ExprService.UpsertVariable(_VarList.Cells[0, Row], StrToFloat(_VarList.Cells[1, Row]));
    end;
end;

procedure SetupHistory; inline;
begin
  _History.Row := _History.RowCount - 1;
  _History.Col := 0;
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
      VarName        := Trim(_VarName.Text);
      _VarName.Text := VarName;

      VarFound := FindRowByCol0Value(_VarList, VarName, DeleteRowIdx);
      if VarFound then
        begin
        OldVarValue := StrToFloat(_VarList.Cells[1, DeleteRowIdx]);
        end
      else
        begin
        OldVarValue := 0.0;
        end;
      VarValue    := ExprService.Calculate(_Expression.Text);
      NewVarValue := OpFunc(OldVarValue, VarValue);

      ExprService.UpsertVariable(VarName, NewVarValue);
      SaveGrid(_VarList, VARS_FILE);

      if VarFound then
        begin
        _VarList.DeleteRow(DeleteRowIdx);
        end;
      _VarList.InsertRowWithValues(_VarList.FixedRows, [VarName, NewVarValue.ToString]);

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
      NewRowIdx                     := _History.RowCount;
      _History.RowCount            := NewRowIdx + 1;
      _History.Cells[0, NewRowIdx] := NewResult;
      _History.Cells[1, NewRowIdx] := NewExpression;
      _History.TopRow              := NewRowIdx;
    end;

  begin
    if _History.RowCount = 0 then
      begin
      HistoryInsertNewItem;
      end
    else
      begin
      LastRowIdx    := _History.RowCount - 1;
      OldResult     := _History.Cells[0, LastRowIdx];
      OldExpression := _History.Cells[1, LastRowIdx];
      if not ((NewResult = OldResult) and (NewExpression = OldExpression)) then
        begin
        HistoryInsertNewItem;
        end;
      end;
  end;

begin
    try
      begin
      NewExpression := _Expression.Text;
      NewResult     := ExprService.Calculate(NewExpression).ToString;

      _Expression.Text     := NewResult;
      _Expression.SelStart := Length(NewResult);

      InsertInHistory;
      SaveGrid(_History, HISTORY_FILE);

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
  FROM_ONE_COLUMN  = 0;
  FROM_TWO_COLUMNS = 1;

procedure CopyFromHistoryToExpressionOnClick;
begin
  DoActionFromSource(@InsertInExpression, @GetClickedCellValue, FROM_TWO_COLUMNS, _History);
end;

procedure CopyFromHistoryToExpressionOnKey;
begin
  DoActionFromSource(@InsertInExpression, @GetKeyDownCellValue, FROM_TWO_COLUMNS, _History);
end;

procedure ReplaceExpressionFromHistoryOnClick;
begin
  DoActionFromSource(@ReplaceExpression, @GetClickedCellValue, FROM_TWO_COLUMNS, _History);
end;

procedure ReplaceExpressionFromHistoryOnKey;
begin
  DoActionFromSource(@ReplaceExpression, @GetKeyDownCellValue, FROM_TWO_COLUMNS, _History);
end;

procedure CopyFromVarListToExpressionOnKey;
begin
  DoActionFromSource(@InsertInExpression, @GetKeyDownCellValue, FROM_TWO_COLUMNS, _VarList);
end;

procedure CopyFromVarListToExpressionOnClick;
begin
  DoActionFromSource(@InsertInExpression, @GetClickedCellValue, FROM_TWO_COLUMNS, _VarList);
end;

procedure ReplaceExpressionFromVarListOnClick;
begin
  DoActionFromSource(@ReplaceExpression, @GetClickedCellValue, FROM_TWO_COLUMNS, _VarList);
end;

procedure ReplaceExpressionFromVarListOnKey;
begin
  DoActionFromSource(@ReplaceExpression, @GetKeyDownCellValue, FROM_TWO_COLUMNS, _VarList);
end;

procedure ReplaceVarNameFromVarListOnClick;
begin
  DoActionFromSource(@ReplaceVarName, @GetClickedCellValue, FROM_ONE_COLUMN, _VarList);
end;

procedure ReplaceVarNameFromVarListOnKey;
begin
  DoActionFromSource(@ReplaceVarName, @GetKeyDownCellValue, FROM_ONE_COLUMN, _VarList);
end;

procedure ClearExpression;
begin
  _Expression.Clear;
end;

procedure ClearVarName;
begin
  _VarName.Clear;
end;

procedure RemoveVariable;
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

      SaveGrid(_VarList, VARS_FILE);

      StatusOK;
      end
    except
    on E: Exception do
      begin
      StatusError(E.Message);
      end;
    end;
end;

procedure RemoveHistoryItem;
begin
    try
      begin
      _History.DeleteRow(GetClickedGridRowIndex(_History));

      SaveGrid(_History, HISTORY_FILE);

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
    _Expression.SetFocus;
    FocusSet := True;
    end;
end;

procedure Receive(const F: TCalculator);
begin
  with F do
    begin
    _History    := History;
    _VarName    := VarName;
    _Expression := Expression;
    _VarList    := VarList;
    _StatusBar  := StatusBar;
    end;
end;

procedure Initialize;
begin
  _History.AutoFillColumns := True;
  _VarList.AutoFillColumns := True;

  SetEditMargins(_VarName, 8, 8);
  SetEditMargins(_Expression, 8, 8);
  SetEditWordBreakCallback(_Expression);

    try
      begin
      LoadGrid(_History, HISTORY_FILE);
      SetupHistory;

      LoadGrid(_VarList, VARS_FILE);
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
