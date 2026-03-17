unit MainService;

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

procedure Initialize(const F: TMainForm);
procedure SaveWindowPos;


implementation

uses
  SysUtils, Windows, Controls, StdCtrls, Grids, Types,
  FormUtils, GridUtils, Storage,
  ExprService, DisplayService, HistoryService, VariableService, UndoRedoService;

var
  _VarName:    TEdit;
  _Expression: TEdit;
  FocusSet:    Boolean;
  _MainForm:   TMainForm;

  {================ Private routines ================}

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

  _Expression.Text := Copy(_Expression.Text, 1, CursorPos) + Value + Copy(_Expression.Text, CursorPos + OldSelLength +
    1, Length(_Expression.Text));

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
  DoActionFromSource(@InsertInExpression, @GridUtils.GetClickedCellValue, FROM_TWO_COLUMNS, HistoryService.Grid);
end;

procedure CopyFromHistoryToExpressionOnKey;
begin
  DoActionFromSource(@InsertInExpression, @GridUtils.GetKeyDownCellValue, FROM_TWO_COLUMNS, HistoryService.Grid);
end;

procedure ReplaceExpressionFromHistoryOnClick;
begin
  DoActionFromSource(@ReplaceExpression, @GridUtils.GetClickedCellValue, FROM_TWO_COLUMNS, HistoryService.Grid);
end;

procedure ReplaceExpressionFromHistoryOnKey;
begin
  DoActionFromSource(@ReplaceExpression, @GridUtils.GetKeyDownCellValue, FROM_TWO_COLUMNS, HistoryService.Grid);
end;

procedure CopyFromVarListToExpressionOnKey;
begin
  DoActionFromSource(@InsertInExpression, @GridUtils.GetKeyDownCellValue, FROM_TWO_COLUMNS, VariableService.Grid);
end;

procedure CopyFromVarListToExpressionOnClick;
begin
  DoActionFromSource(@InsertInExpression, @GridUtils.GetClickedCellValue, FROM_TWO_COLUMNS, VariableService.Grid);
end;

procedure ReplaceExpressionFromVarListOnClick;
begin
  DoActionFromSource(@ReplaceExpression, @GridUtils.GetClickedCellValue, FROM_TWO_COLUMNS, VariableService.Grid);
end;

procedure ReplaceExpressionFromVarListOnKey;
begin
  DoActionFromSource(@ReplaceExpression, @GridUtils.GetKeyDownCellValue, FROM_TWO_COLUMNS, VariableService.Grid);
end;

procedure ReplaceVarNameFromVarListOnClick;
begin
  DoActionFromSource(@ReplaceVarName, @GridUtils.GetClickedCellValue, FROM_ONE_COLUMN, VariableService.Grid);
end;

procedure ReplaceVarNameFromVarListOnKey;
begin
  DoActionFromSource(@ReplaceVarName, @GridUtils.GetKeyDownCellValue, FROM_ONE_COLUMN, VariableService.Grid);
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

procedure SetFocus;
begin
  if not FocusSet then
    begin
    _Expression.SetFocus;
    FocusSet := True;
    end;
end;

procedure ExpressionChange;
begin
  UndoRedoService.RecordExpressionChange(_Expression.Text, _Expression.SelStart);
  Storage.SaveWorkspace(_VarName.Text, _Expression.Text);
end;

procedure VarNameChange;
begin
  Storage.SaveWorkspace(_VarName.Text, _Expression.Text);
end;

procedure UndoExpression;
var
  Prev: TUndoRedoState;
begin
  UndoRedoService.BeforeMutatingState;
  if UndoRedoService.Undo(Prev) then
    begin
    _Expression.Text     := Prev.Text;
    _Expression.SelStart := Prev.SelStart;
    end;
  UndoRedoService.AfterMutatingState;
end;

procedure RedoExpression;
var
  Next: TUndoRedoState;
begin
  UndoRedoService.BeforeMutatingState;
  if UndoRedoService.Redo(Next) then
    begin
    _Expression.Text     := Next.Text;
    _Expression.SelStart := Next.SelStart;
    end;
  UndoRedoService.AfterMutatingState;
end;

procedure Initialize(const F: TMainForm);
var
  WP: TPoint;
  WS: TWorkspaceState;
begin
  DisplayService.Initialize(F.StatusBar);
  DisplayService.StatusOK;

  _VarName    := F.VarName;
  _Expression := F.Expression;
    try
      begin
      WP   := FormUtils.AdjustWindowPos(Storage.LoadWindowPos, Width, Height);
      F.Left := WP.X;
      F.Top  := WP.Y;

      WS               := Storage.LoadWorkspace;
      _VarName.Text    := WS.VarName;
      _Expression.Text := WS.Expression;
      end;
    except
      begin
      DisplayService.StatusError('Failed to load workspace.');
      end;
    end;

  UndoRedoService.SetExpressionState(_Expression.Text, _Expression.SelStart);
  HistoryService.Initialize(F.History);
  VariableService.Initialize(F.VarList);
  _MainForm := F;
end;

procedure SaveWindowPos;
var
  P: TPoint;
begin
  if not Assigned(_MainForm) then
    Exit;
  P := Point(_MainForm.Left, _MainForm.Top);
  Storage.SaveWindowPos(P);
end;

end.
