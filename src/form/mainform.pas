unit MainForm;

{$mode ObjFPC}
{$H+}
{$modeswitch nestedprocvars}
{$inline ON}

interface

uses
  Classes, LCLType, Controls, StdCtrls, ComCtrls, Grids, ExtCtrls, Menus,
  Forms, LCLIntf, Windows, Messages;

type

  { TCalculator }

  TCalculator = class(TForm)
    History:    TStringGrid;
    VarName:    TEdit;
    Expression: TEdit;
    VarList:    TStringGrid;

    StatusBar: TStatusBar;

    TrayIcon:          TTrayIcon;
    TrayIconPopupMenu: TPopupMenu;
    MenuItemClose:     TMenuItem;

    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);

    procedure ExpressionKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ExpressionChange(Sender: TObject);
    procedure VarNameChange(Sender: TObject);
    procedure FormChangeBounds(Sender: TObject);
    procedure VarNameKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure HistoryKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure HistoryDblClick(Sender: TObject);
    procedure VariableListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure VarListDblClick(Sender: TObject);

    procedure GridMouseWheelDown(Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean);
    procedure GridMouseWheelUp(Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean);

    procedure TrayIconMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure MenuItemCloseClick(Sender: TObject);

    procedure WMHotKey(var Msg: TMessage); Message WM_HOTKEY;
  Private
    procedure ShowNormalWindow;
  end;

var
  Calculator: TCalculator;

implementation

{$R *.lfm}

uses
  Config, FormUtils, GridUtils, InputController, Autorun,
  Storage, DisplayService, HistoryService, VariableService, UndoRedoService, Types;

const
  HOTKEY_ID = 1;


procedure TCalculator.FormCreate(Sender: TObject);
var
  WS: TWorkspaceState;
  WP: TPoint;
begin
  Windows.RegisterHotKey(Handle, HOTKEY_ID, HOT_KEY.ModKey, HOT_KEY.VirtualKey);

  Caption       := Application.Title;
  TrayIcon.Hint := Application.Title;

  WP   := FormUtils.AdjustWindowPos(Storage.LoadWindowPos, Width, Height);
  Left := WP.X;
  Top  := WP.Y;

  WS              := Storage.LoadWorkspace;
  VarName.Text    := WS.VarName;
  Expression.Text := WS.Expression;

  InputController.Initialize(self);
  DisplayService.Initialize(StatusBar);
  HistoryService.Initialize(History);
  VariableService.Initialize(VarList);
  UndoRedoService.SetExpressionState(Expression.Text, Expression.SelStart);

  SetEditMargins(VarName, 8, 8);
  SetEditMargins(Expression, 8, 8);
  SetEditWordBreakCallback(Expression);

  VarName.OnChange    := @VarNameChange;
  Expression.OnChange := @ExpressionChange;

  DisplayService.StatusOK;
end;

procedure TCalculator.FormDestroy(Sender: TObject);
begin
  Windows.UnregisterHotKey(Handle, HOTKEY_ID);
end;

procedure TCalculator.FormShow(Sender: TObject);
begin
  InputController.SetFocus;
end;

procedure TCalculator.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  if WindowState = wsMinimized then
    begin
    Application.ProcessMessages;
    end;
  CloseAction := caHide;
end;

procedure TCalculator.ShowNormalWindow; inline;
begin
  WindowState := wsNormal;
  Show;
end;

procedure TCalculator.TrayIconMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbRight then
    begin
    TrayIconPopupMenu.PopUp;
    end;
  if Button = mbLeft then
    begin
    ShowNormalWindow;
    end;
end;

procedure TCalculator.MenuItemCloseClick(Sender: TObject);
begin
  UnregisterAutoRun(APP_NAME);
  Application.Terminate;
end;

procedure TCalculator.WMHotKey(var Msg: TMessage);
begin
  if Msg.wParam = HOTKEY_ID then
    begin
    if Visible then
      begin
      if not IsTopMostWindow(self) then
        begin
        ShowNormalWindow;
        end
      else
        begin
        Hide;
        end;
      end
    else
      begin
      ShowNormalWindow;
      end;
    end;
end;

procedure TCalculator.GridMouseWheelDown(Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean);
begin
  GridUtils.StringGridMouseWheelDown(Sender as TStringGrid, Shift, MousePos, Handled);
end;

procedure TCalculator.GridMouseWheelUp(Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean);
begin
  GridUtils.StringGridMouseWheelUp(Sender as TStringGrid, Shift, MousePos, Handled);
end;

procedure TCalculator.ExpressionChange(Sender: TObject);
begin
  InputController.ExpressionChange;
  Storage.SaveWorkspace(VarName.Text, Expression.Text);
end;

procedure TCalculator.VarNameChange(Sender: TObject);
begin
  Storage.SaveWorkspace(VarName.Text, Expression.Text);
end;

procedure TCalculator.FormChangeBounds(Sender: TObject);
begin
  Storage.SaveWindowPos(Point(Left, Top));
end;

procedure TCalculator.VarNameKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if IsKeyCombinationMatch(Key, Shift, [VK_BACK], [ssCtrl]) then
    begin
    InputController.ClearVarName;
    end;
  if IsKeyCombinationMatch(Key, Shift, [VK_RETURN], [ssCtrl]) then
    begin
    InputController.CalculateAndUpsertVariable;
    end;
  if IsKeyCombinationMatch(Key, Shift, [VK_ADD, VK_OEM_PLUS], [ssCtrl]) then
    begin
    InputController.CalculateAndAddVariable;
    end;
  if IsKeyCombinationMatch(Key, Shift, [VK_SUBTRACT, VK_OEM_MINUS], [ssCtrl]) then
    begin
    InputController.CalculateAndSubtractVariable;
    end;
end;

procedure TCalculator.ExpressionKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if IsKeyCombinationMatch(Key, Shift, [VK_Z], [ssCtrl]) then
    begin
    InputController.UndoExpression;
    end;
  if IsKeyCombinationMatch(Key, Shift, [VK_Y], [ssCtrl]) then
    begin
    InputController.RedoExpression;
    end;
  if IsKeyCombinationMatch(Key, Shift, [VK_BACK], [ssCtrl]) then
    begin
    InputController.DoCtrlBackspace;
    end;
  if IsKeyCombinationMatch(Key, Shift, [VK_RETURN], [ssCtrl]) then
    begin
    InputController.CalculateAndUpsertVariable;
    end;
  if IsKeyCombinationMatch(Key, Shift, [VK_ADD, VK_OEM_PLUS], [ssCtrl]) then
    begin
    InputController.CalculateAndAddVariable;
    end;
  if IsKeyCombinationMatch(Key, Shift, [VK_SUBTRACT, VK_OEM_MINUS], [ssCtrl]) then
    begin
    InputController.CalculateAndSubtractVariable;
    end;
  if IsKeyCombinationMatch(Key, Shift, [VK_RETURN], []) then
    begin
    InputController.CalculateAndInsertInHistory;
    end;
  if IsKeyCombinationMatch(Key, Shift, [VK_ESCAPE], []) then
    begin
    if IsEditEmpty(Expression) then
      begin
      Hide;
      end
    else if IsEditTextSelected(Expression) then
        begin
        InputController.DoCtrlBackspace;
        end
      else
        begin
        SelectAllEditText(Expression);
        end;
    end;
end;

procedure TCalculator.HistoryKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if IsKeyCombinationMatch(Key, Shift, [VK_RETURN], [ssCtrl]) then
    begin
    InputController.ReplaceExpressionFromHistoryOnKey;
    end;
  if IsKeyCombinationMatch(Key, Shift, [VK_RETURN], []) then
    begin
    InputController.CopyFromHistoryToExpressionOnKey;
    end;
end;

procedure TCalculator.HistoryDblClick(Sender: TObject);
var
  Mods: TShiftState;
begin
  Mods := KeyboardStateToShiftState;

  if CheckModsState(Mods, []) then
    begin
    InputController.CopyFromHistoryToExpressionOnClick;
    end;
  if CheckModsState(Mods, [ssCtrl]) then
    begin
    InputController.ReplaceExpressionFromHistoryOnClick;
    end;
  if CheckModsState(Mods, [ssCtrl, ssAlt]) then
    begin
    InputController.RemoveHistoryItem;
    end;
end;

procedure TCalculator.VariableListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if IsKeyCombinationMatch(Key, Shift, [VK_RETURN], [ssCtrl]) then
    begin
    InputController.ReplaceExpressionFromVarListOnKey;
    end;
  if IsKeyCombinationMatch(Key, Shift, [VK_RETURN], []) then
    begin
    InputController.CopyFromVarListToExpressionOnKey;
    end;
  if IsKeyCombinationMatch(Key, Shift, [VK_RETURN], [ssShift]) then
    begin
    InputController.ReplaceVarNameFromVarListOnKey;
    end;
end;

procedure TCalculator.VarListDblClick(Sender: TObject);
var
  Mods: TShiftState;
begin
  Mods := KeyboardStateToShiftState;

  if CheckModsState(Mods, []) then
    begin
    InputController.CopyFromVarListToExpressionOnClick;
    end;
  if CheckModsState(Mods, [ssCtrl]) then
    begin
    InputController.ReplaceExpressionFromVarListOnClick;
    end;
  if CheckModsState(Mods, [ssShift]) then
    begin
    InputController.ReplaceVarNameFromVarListOnClick;
    end;
  if CheckModsState(Mods, [ssCtrl, ssAlt]) then
    begin
    InputController.RemoveVariable;
    end;
end;

end.
