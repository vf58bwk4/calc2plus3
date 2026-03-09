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

procedure DoCtrlBackspace;
procedure ClearVarName;

procedure RemoveVariable;
procedure RemoveHistoryItem;

procedure SetFocus;

procedure ExpressionChange;
procedure UndoExpression;
procedure RedoExpression;

procedure SaveWorkspace;
procedure SaveWindowPos;

procedure Receive(const F: TCalculator);
procedure Initialize;


implementation

uses
  SysUtils, Windows, Controls, StdCtrls, Grids,
  ExprService, FormUtils,
  DisplayService, HistoryService, VariableService, WorkspaceController;

const
  UNDO_MAX = 100;

type
  TExprState = record
    Text:     String;
    SelStart: Integer;
  end;

var
  _VarName:    TEdit;
  _Expression: TEdit;
  _Form:       TCalculator;
  FocusSet:    Boolean;

  _UndoStack:        array[0..UNDO_MAX - 1] of TExprState;
  _RedoStack:        array[0..UNDO_MAX - 1] of TExprState;
  _UndoHead:         Integer;   { next write position }
  _UndoCount:        Integer;
  _RedoHead:         Integer;   { next write position }
  _RedoCount:        Integer;
  _SuppressUndoPush: Boolean;

  {================ Private routines ================}

procedure UndoPush(const State: TExprState); inline;
begin
  _UndoStack[_UndoHead] := State;
  _UndoHead  := (_UndoHead + 1) mod UNDO_MAX;
  if _UndoCount < UNDO_MAX then Inc(_UndoCount);
end;

function UndoPop: TExprState; inline;
begin
  _UndoHead := (_UndoHead - 1 + UNDO_MAX) mod UNDO_MAX;
  Result    := _UndoStack[_UndoHead];
  Dec(_UndoCount);
end;

function UndoPeek: TExprState; inline;
begin
  Result := _UndoStack[(_UndoHead - 1 + UNDO_MAX) mod UNDO_MAX];
end;

procedure RedoPush(const State: TExprState); inline;
begin
  _RedoStack[_RedoHead] := State;
  _RedoHead  := (_RedoHead + 1) mod UNDO_MAX;
  if _RedoCount < UNDO_MAX then Inc(_RedoCount);
end;

function RedoPop: TExprState; inline;
begin
  _RedoHead := (_RedoHead - 1 + UNDO_MAX) mod UNDO_MAX;
  Result    := _RedoStack[_RedoHead];
  Dec(_RedoCount);
end;

function ExprState: TExprState; inline;
begin
  Result.Text     := _Expression.Text;
  Result.SelStart := _Expression.SelStart;
end;





type
  TActionProc   = procedure(const Value: String);
  TGetValueFunc = function(const Source: TStringGrid; const Param: Integer): String;

procedure DoActionFromSource(ActionProc: TActionProc; GetValueFunc: TGetValueFunc; GetValueFuncParam: Integer; Source: TStringGrid);
begin
    try
      begin
      ActionProc(GetValueFunc(Source, GetValueFuncParam));

      DisplayService.StatusOK;
      end;
    except
    on E: Exception do
      begin
      DisplayService.StatusError(E.Message);
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




{================ Interface routines ==============}

type
  TOperationFunc = function(const A, B: Double): Double is nested;

procedure CalculateAndModifyVariable(const OpFunc: TOperationFunc);
var
  VarName:  String;
  VarValue: Double;
begin
    try
      begin
      VarName       := Trim(_VarName.Text);
      _VarName.Text := VarName;

      VarValue := ExprService.Calculate(_Expression.Text);

      VariableService.ModifyVariable(VarName, OpFunc(VariableService.GetValue(VarName), VarValue));

      DisplayService.StatusOK;
      end
    except
    on E: Exception do
      begin
      DisplayService.StatusError(E.Message);
      end;
    end;
end;

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
begin
    try
      begin
      NewExpression := _Expression.Text;
      NewResult     := DisplayService.FormatNumber(ExprService.Calculate(NewExpression));

      _Expression.Text     := NewResult;
      _Expression.SelStart := Length(NewResult);

      HistoryService.InsertItem(NewResult, NewExpression);

      DisplayService.StatusOK;
      end
    except
    on E: Exception do
      begin
      DisplayService.StatusError(E.Message);
      end;
    end;
end;

const
  FROM_ONE_COLUMN  = 0;
  FROM_TWO_COLUMNS = 1;

procedure CopyFromHistoryToExpressionOnClick;
begin
  DoActionFromSource(@InsertInExpression, @GetClickedCellValue, FROM_TWO_COLUMNS, HistoryService.Grid);
end;

procedure CopyFromHistoryToExpressionOnKey;
begin
  DoActionFromSource(@InsertInExpression, @GetKeyDownCellValue, FROM_TWO_COLUMNS, HistoryService.Grid);
end;

procedure ReplaceExpressionFromHistoryOnClick;
begin
  DoActionFromSource(@ReplaceExpression, @GetClickedCellValue, FROM_TWO_COLUMNS, HistoryService.Grid);
end;

procedure ReplaceExpressionFromHistoryOnKey;
begin
  DoActionFromSource(@ReplaceExpression, @GetKeyDownCellValue, FROM_TWO_COLUMNS, HistoryService.Grid);
end;

procedure CopyFromVarListToExpressionOnKey;
begin
  DoActionFromSource(@InsertInExpression, @GetKeyDownCellValue, FROM_TWO_COLUMNS, VariableService.Grid);
end;

procedure CopyFromVarListToExpressionOnClick;
begin
  DoActionFromSource(@InsertInExpression, @GetClickedCellValue, FROM_TWO_COLUMNS, VariableService.Grid);
end;

procedure ReplaceExpressionFromVarListOnClick;
begin
  DoActionFromSource(@ReplaceExpression, @GetClickedCellValue, FROM_TWO_COLUMNS, VariableService.Grid);
end;

procedure ReplaceExpressionFromVarListOnKey;
begin
  DoActionFromSource(@ReplaceExpression, @GetKeyDownCellValue, FROM_TWO_COLUMNS, VariableService.Grid);
end;

procedure ReplaceVarNameFromVarListOnClick;
begin
  DoActionFromSource(@ReplaceVarName, @GetClickedCellValue, FROM_ONE_COLUMN, VariableService.Grid);
end;

procedure ReplaceVarNameFromVarListOnKey;
begin
  DoActionFromSource(@ReplaceVarName, @GetKeyDownCellValue, FROM_ONE_COLUMN, VariableService.Grid);
end;

procedure DoCtrlBackspace;
begin
  FormUtils.DoCtrlBackspace(_Expression);
end;

procedure ClearVarName;
begin
  _VarName.Clear;
end;

procedure RemoveVariable;
begin
  VariableService.RemoveItem;
end;

procedure RemoveHistoryItem;
begin
  HistoryService.RemoveItem;
end;

procedure SaveWorkspace;
begin
  WorkspaceController.SaveWorkspace(_VarName.Text, _Expression.Text);
end;

procedure SaveWindowPos;
begin
  WorkspaceController.SaveWindowPos(_Form);
end;

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
  _Form := F;
  with F do
    begin
    _VarName    := VarName;
    _Expression := Expression;
    end;
end;

procedure Initialize;
begin
  WorkspaceController.Initialize(_Form);

  SetEditMargins(_VarName, 8, 8);
  SetEditMargins(_Expression, 8, 8);
  SetEditWordBreakCallback(_Expression);

    try
      begin
      UndoPush(ExprState);

      DisplayService.StatusOK;
      end;
    except
    on E: Exception do
      begin
      DisplayService.StatusError(E.Message);
      end;
    end;
end;

procedure ExpressionChange;
begin
  if _SuppressUndoPush then Exit;
  if (_UndoCount > 0) and (_Expression.Text = UndoPeek.Text) then Exit;
  UndoPush(ExprState);
  _RedoCount := 0;
  _RedoHead  := 0;
end;

procedure UndoExpression;
var
  Prev: TExprState;
begin
  if _UndoCount < 2 then Exit;
  RedoPush(UndoPop);
  Prev := UndoPeek;
  _SuppressUndoPush    := True;
  _Expression.Text     := Prev.Text;
  _Expression.SelStart := Prev.SelStart;
  _SuppressUndoPush    := False;
end;

procedure RedoExpression;
var
  Next: TExprState;
begin
  if _RedoCount = 0 then Exit;
  Next := RedoPop;
  UndoPush(Next);
  _SuppressUndoPush    := True;
  _Expression.Text     := Next.Text;
  _Expression.SelStart := Next.SelStart;
  _SuppressUndoPush    := False;
end;

end.
