unit MainService;

{$mode ObjFPC}
{$H+}
{$modeswitch nestedprocvars}
{$inline ON}

interface

uses
  MainForm;

procedure Initialize(const F: TMainForm);
procedure Finalize;

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
  TGridValueContext = (vcSingleColumnGrid = 1, vcTwoColumnsGrid = 2);
  TGridValueGetter  = function(const Grid: TStringGrid; const Context: Integer): String;

procedure ExecuteActionFromGrid(Action: TValueAction; ValueGetter: TGridValueGetter; Context: TGridValueContext; Grid: TStringGrid);
begin
    try
      begin
      Action(ValueGetter(Grid, Ord(Context)));

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
  TValueUpdater = function(const OldValue, NewValue: Double): Double is nested;

procedure CalculateAndModifyVariable(const OpFunc: TValueUpdater);
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

procedure Initialize(const F: TMainForm);
var
  WP: TPoint;
  WS: TWorkspaceState;
begin
  DisplayService.Initialize(F.StatusBar);
  DisplayService.StatusOK;

  _MainForm   := F;
  _VarName    := F.VarName;
  _Expression := F.Expression;
    try
      begin
      WP     := FormUtils.AdjustWindowPos(Storage.LoadWindowPos, F.Width, F.Height);
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

    try
      begin
      VariableService.Initialize(F.VarList);
      end;
    except
      begin
      DisplayService.StatusError('Failed to load variables.');
      end;
    end;

    try
      begin
      HistoryService.Initialize(F.History);
      end;
    except
      begin
      DisplayService.StatusError('Failed to load history.');
      end;
    end;

  UndoRedoService.SetUndoRedoState(MakeUndoRedoState(_Expression.Text, _Expression.SelStart));
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

  function Updater(const OldVal, NewVal: Double): Double;
  begin
    Result := NewVal;
  end;

begin
  CalculateAndModifyVariable(@Updater);
end;

procedure CalculateAndAddVariable;

  function Updater(const OldVal, NewVal: Double): Double;
  begin
    Result := OldVal + NewVal;
  end;

begin
  CalculateAndModifyVariable(@Updater);
end;

procedure CalculateAndSubtractVariable;

  function Updater(const OldVal, NewVal: Double): Double;
  begin
    Result := OldVal - NewVal;
  end;

begin
  CalculateAndModifyVariable(@Updater);
end;

procedure CalculateAndInsertInHistory;
var
  NewExpression, NewResult: String;
begin
    try
      begin
      NewExpression := _Expression.Text;
      NewResult     := VariableService.FormatNumber(ExprService.Calculate(NewExpression));

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

procedure CopyFromHistoryToExpressionOnClick;
begin
  ExecuteActionFromGrid(@InsertInExpression, @GridUtils.GetClickedCellValue, vcTwoColumnsGrid, HistoryService.Grid);
end;

procedure CopyFromHistoryToExpressionOnKey;
begin
  ExecuteActionFromGrid(@InsertInExpression, @GridUtils.GetKeyDownCellValue, vcTwoColumnsGrid, HistoryService.Grid);
end;

procedure ReplaceExpressionFromHistoryOnClick;
begin
  ExecuteActionFromGrid(@ReplaceExpression, @GridUtils.GetClickedCellValue, vcTwoColumnsGrid, HistoryService.Grid);
end;

procedure ReplaceExpressionFromHistoryOnKey;
begin
  ExecuteActionFromGrid(@ReplaceExpression, @GridUtils.GetKeyDownCellValue, vcTwoColumnsGrid, HistoryService.Grid);
end;

procedure CopyFromVarListToExpressionOnKey;
begin
  ExecuteActionFromGrid(@InsertInExpression, @GridUtils.GetKeyDownCellValue, vcTwoColumnsGrid, VariableService.Grid);
end;

procedure CopyFromVarListToExpressionOnClick;
begin
  ExecuteActionFromGrid(@InsertInExpression, @GridUtils.GetClickedCellValue, vcTwoColumnsGrid, VariableService.Grid);
end;

procedure ReplaceExpressionFromVarListOnClick;
begin
  ExecuteActionFromGrid(@ReplaceExpression, @GridUtils.GetClickedCellValue, vcTwoColumnsGrid, VariableService.Grid);
end;

procedure ReplaceExpressionFromVarListOnKey;
begin
  ExecuteActionFromGrid(@ReplaceExpression, @GridUtils.GetKeyDownCellValue, vcTwoColumnsGrid, VariableService.Grid);
end;

procedure ReplaceVarNameFromVarListOnClick;
begin
  ExecuteActionFromGrid(@ReplaceVarName, @GridUtils.GetClickedCellValue, vcSingleColumnGrid, VariableService.Grid);
end;

procedure ReplaceVarNameFromVarListOnKey;
begin
  ExecuteActionFromGrid(@ReplaceVarName, @GridUtils.GetKeyDownCellValue, vcSingleColumnGrid, VariableService.Grid);
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
  DisplayService.StatusOK;
end;

procedure RemoveHistoryItem;
begin
  HistoryService.RemoveItem;
  DisplayService.StatusOK;
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
