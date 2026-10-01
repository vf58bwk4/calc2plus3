unit MainService;

{$mode ObjFPC}
{$H+}
{$modeswitch nestedprocvars}
{$inline ON}

interface

uses
  MainForm;

procedure Initialize(const AMainForm: TMainForm);
procedure Finalize;

procedure CalculateAndUpsertVariable;
procedure CalculateAndAddVariable;
procedure CalculateAndSubtractVariable;
procedure CalculateAndAppendToHistory;

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

procedure DeleteWordLeft;
procedure ClearVarName;

procedure RemoveVarListItem;
procedure RemoveHistoryItem;

procedure SetInitialFocus;

procedure ExpressionChange;
procedure VarNameChange;

procedure UndoExpression;
procedure RedoExpression;

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
  TValueAction      = procedure(const Value: String);
  TGridValueContext = (gvcSingleColumnGrid = 1, gvcTwoColumnsGrid = 2);
  TGridValueGetter  = function(const Grid: TStringGrid; const MaxCol: Integer; out Value: String): Boolean;

procedure ExecuteActionFromGrid(Action: TValueAction; ValueGetter: TGridValueGetter; Context: TGridValueContext; Grid: TStringGrid);
var
  Value: String;
begin
  if ValueGetter(Grid, Ord(Context), Value) then
    begin
    Action(Value);

    DisplayService.StatusOK;
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
  _VarName.Text := Value;
  _VarName.SelectAll;
  _VarName.SetFocus;
end;

type
  TValueUpdater = function(const OldValue, NewValue: Double): Double is nested;

procedure CalculateAndModifyVariable(const ValueUpdater: TValueUpdater);
var
  VarName:  String;
  VarValue: Double;
begin
  VarName       := Trim(_VarName.Text);
  _VarName.Text := VarName;

  VarValue := ExprService.Calculate(_Expression.Text);

  VariableService.UpsertItem(VarName, ValueUpdater(VariableService.GetValue(VarName), VarValue));

  DisplayService.StatusOK;
end;

{================ Interface routines ==============}

procedure Initialize(const AMainForm: TMainForm);
var
  WinPos:    TPoint;
  Workspace: TWorkspaceState;
begin
  DisplayService.StatusOK;

  _MainForm   := AMainForm;
  _VarName    := AMainForm.VarName;
  _Expression := AMainForm.Expression;
    try
      begin
      WinPos         := FormUtils.AdjustWindowPos(Storage.LoadWindowPos, AMainForm.Width, AMainForm.Height);
      AMainForm.Left := WinPos.X;
      AMainForm.Top  := WinPos.Y;

      Workspace        := Storage.LoadWorkspace;
      _VarName.Text    := Workspace.VarName;
      _Expression.Text := Workspace.Expression;
      end;
    except
      begin
      DisplayService.StatusError('Failed to load workspace.');
      end;
    end;

    try
      begin
      VariableService.Initialize(AMainForm.VarList);
      end;
    except
      begin
      DisplayService.StatusError('Failed to load variables.');
      end;
    end;

    try
      begin
      HistoryService.Initialize(AMainForm.History);
      end;
    except
      begin
      DisplayService.StatusError('Failed to load history.');
      end;
    end;

  UndoRedoService.CommitState(MakeUndoRedoState(_Expression.Text, _Expression.SelStart));
end;

procedure Finalize;
begin
    try
      begin
      Storage.SaveWorkspace(_VarName.Text, _Expression.Text, True);
      end;
    finally
      begin
      Storage.SaveWindowPos(Point(_MainForm.Left, _MainForm.Top), True);
      end;
    end;
end;

procedure CalculateAndUpsertVariable;

  function Updater(const OldValue, NewValue: Double): Double;
  begin
    Result := NewValue;
  end;

begin
  CalculateAndModifyVariable(@Updater);
end;

procedure CalculateAndAddVariable;

  function Updater(const OldValue, NewValue: Double): Double;
  begin
    Result := OldValue + NewValue;
  end;

begin
  CalculateAndModifyVariable(@Updater);
end;

procedure CalculateAndSubtractVariable;

  function Updater(const OldValue, NewValue: Double): Double;
  begin
    Result := OldValue - NewValue;
  end;

begin
  CalculateAndModifyVariable(@Updater);
end;

procedure CalculateAndAppendToHistory;
var
  NewExpression, NewResult: String;
begin
  NewExpression := _Expression.Text;
  NewResult     := VariableService.FormatNumber(ExprService.Calculate(NewExpression));

  _Expression.Text     := NewResult;
  _Expression.SelStart := Length(NewResult);

  HistoryService.AppendItem(NewResult, NewExpression);

  DisplayService.StatusOK;
end;

procedure CopyFromHistoryToExpressionOnClick;
begin
  ExecuteActionFromGrid(@InsertInExpression, @GridUtils.TryGetClickedCellValue, gvcTwoColumnsGrid, HistoryService.Grid);
end;

procedure CopyFromHistoryToExpressionOnKey;
begin
  ExecuteActionFromGrid(@InsertInExpression, @GridUtils.TryGetKeyDownCellValue, gvcTwoColumnsGrid, HistoryService.Grid);
end;

procedure ReplaceExpressionFromHistoryOnClick;
begin
  ExecuteActionFromGrid(@ReplaceExpression, @GridUtils.TryGetClickedCellValue, gvcTwoColumnsGrid, HistoryService.Grid);
end;

procedure ReplaceExpressionFromHistoryOnKey;
begin
  ExecuteActionFromGrid(@ReplaceExpression, @GridUtils.TryGetKeyDownCellValue, gvcTwoColumnsGrid, HistoryService.Grid);
end;

procedure CopyFromVarListToExpressionOnKey;
begin
  ExecuteActionFromGrid(@InsertInExpression, @GridUtils.TryGetKeyDownCellValue, gvcTwoColumnsGrid, VariableService.Grid);
end;

procedure CopyFromVarListToExpressionOnClick;
begin
  ExecuteActionFromGrid(@InsertInExpression, @GridUtils.TryGetClickedCellValue, gvcTwoColumnsGrid, VariableService.Grid);
end;

procedure ReplaceExpressionFromVarListOnClick;
begin
  ExecuteActionFromGrid(@ReplaceExpression, @GridUtils.TryGetClickedCellValue, gvcTwoColumnsGrid, VariableService.Grid);
end;

procedure ReplaceExpressionFromVarListOnKey;
begin
  ExecuteActionFromGrid(@ReplaceExpression, @GridUtils.TryGetKeyDownCellValue, gvcTwoColumnsGrid, VariableService.Grid);
end;

procedure ReplaceVarNameFromVarListOnClick;
begin
  ExecuteActionFromGrid(@ReplaceVarName, @GridUtils.TryGetClickedCellValue, gvcSingleColumnGrid, VariableService.Grid);
end;

procedure ReplaceVarNameFromVarListOnKey;
begin
  ExecuteActionFromGrid(@ReplaceVarName, @GridUtils.TryGetKeyDownCellValue, gvcSingleColumnGrid, VariableService.Grid);
end;

procedure DeleteWordLeft;
begin
  FormUtils.DeleteWordLeft(_Expression);
end;

procedure ClearVarName;
begin
  _VarName.Clear;
end;

procedure RemoveVarListItem;
begin
  if VariableService.RemoveItem then
    begin
    DisplayService.StatusOK;
    end;
end;

procedure RemoveHistoryItem;
begin
  if HistoryService.RemoveItem then
    begin
    DisplayService.StatusOK;
    end;
end;

procedure SetInitialFocus;
begin
  if not FocusSet then
    begin
    _Expression.SetFocus;
    FocusSet := True;
    end;
end;

procedure ExpressionChange;
begin
  UndoRedoService.RecordChange(MakeUndoRedoState(_Expression.Text, _Expression.SelStart));
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

procedure SaveWindowPos;
begin
  Storage.SaveWindowPos(Point(_MainForm.Left, _MainForm.Top));
end;

end.
