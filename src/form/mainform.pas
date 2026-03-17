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

  { TMainForm }

  TMainForm = class(TForm)
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
    procedure AppExceptionHandler(Sender: TObject; E: Exception);
  end;

var
  MainFormInstance: TMainForm;

implementation

{$R *.lfm}

uses
  Config, FormUtils, GridUtils, MainService, Autorun,
  Storage, DisplayService, HistoryService, VariableService, UndoRedoService, Types, Dialogs;

const
  HOTKEY_ID = 1;


procedure TMainForm.FormCreate(Sender: TObject);
var
begin
  Windows.RegisterHotKey(Handle, HOTKEY_ID, HOT_KEY.ModKey, HOT_KEY.VirtualKey);

  Caption       := Application.Title;
  TrayIcon.Hint := Application.Title;

  MainService.Initialize(self);
  Application.OnException := @MainFormInstance.AppExceptionHandler;

  VarName.OnChange    := @VarNameChange;
  Expression.OnChange := @ExpressionChange;

  Storage.InitializeWindowPosDebouncing;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  Windows.UnregisterHotKey(Handle, HOTKEY_ID);
  Storage.FinalizeWindowPosDebouncing;
end;

procedure TMainForm.FormShow(Sender: TObject);
begin
  MainService.SetFocus;
end;

procedure TMainForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  if WindowState = wsMinimized then
    begin
    Application.ProcessMessages;
    end;
  CloseAction := caHide;
end;

procedure TMainForm.ShowNormalWindow; inline;
begin
  WindowState := wsNormal;
  Show;
end;

procedure TMainForm.TrayIconMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
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

procedure TMainForm.MenuItemCloseClick(Sender: TObject);
begin
  Application.Terminate;
end;

procedure TMainForm.WMHotKey(var Msg: TMessage);
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

procedure TMainForm.GridMouseWheelDown(Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean);
begin
  GridUtils.StringGridMouseWheelDown(Sender as TStringGrid, Shift, MousePos, Handled);
end;

procedure TMainForm.GridMouseWheelUp(Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean);
begin
  GridUtils.StringGridMouseWheelUp(Sender as TStringGrid, Shift, MousePos, Handled);
end;

procedure TMainForm.ExpressionChange(Sender: TObject);
begin
  MainService.ExpressionChange;
end;

procedure TMainForm.VarNameChange(Sender: TObject);
begin
  MainService.VarNameChange;
end;

procedure TMainForm.FormChangeBounds(Sender: TObject);
begin
  Storage.SaveWindowPos(Point(Left, Top));
end;

procedure TMainForm.VarNameKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if IsKeyCombinationMatch(Key, Shift, [VK_BACK], [ssCtrl]) then
    begin
    MainService.ClearVarName;
    end;
  if IsKeyCombinationMatch(Key, Shift, [VK_RETURN], [ssCtrl]) then
    begin
    MainService.CalculateAndUpsertVariable;
    end;
  if IsKeyCombinationMatch(Key, Shift, [VK_ADD, VK_OEM_PLUS], [ssCtrl]) then
    begin
    MainService.CalculateAndAddVariable;
    end;
  if IsKeyCombinationMatch(Key, Shift, [VK_SUBTRACT, VK_OEM_MINUS], [ssCtrl]) then
    begin
    MainService.CalculateAndSubtractVariable;
    end;
end;

procedure TMainForm.ExpressionKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if IsKeyCombinationMatch(Key, Shift, [VK_Z], [ssCtrl]) then
    begin
    MainService.UndoExpression;
    end;
  if IsKeyCombinationMatch(Key, Shift, [VK_Y], [ssCtrl]) then
    begin
    MainService.RedoExpression;
    end;
  if IsKeyCombinationMatch(Key, Shift, [VK_BACK], [ssCtrl]) then
    begin
    MainService.DoCtrlBackspace;
    end;
  if IsKeyCombinationMatch(Key, Shift, [VK_RETURN], [ssCtrl]) then
    begin
    MainService.CalculateAndUpsertVariable;
    end;
  if IsKeyCombinationMatch(Key, Shift, [VK_ADD, VK_OEM_PLUS], [ssCtrl]) then
    begin
    MainService.CalculateAndAddVariable;
    end;
  if IsKeyCombinationMatch(Key, Shift, [VK_SUBTRACT, VK_OEM_MINUS], [ssCtrl]) then
    begin
    MainService.CalculateAndSubtractVariable;
    end;
  if IsKeyCombinationMatch(Key, Shift, [VK_RETURN], []) then
    begin
    MainService.CalculateAndInsertInHistory;
    end;
  if IsKeyCombinationMatch(Key, Shift, [VK_ESCAPE], []) then
    begin
    if IsEditEmpty(Expression) then
      begin
      Hide;
      end
    else if IsEditTextSelected(Expression) then
        begin
        MainService.DoCtrlBackspace;
        end
      else
        begin
        SelectAllEditText(Expression);
        end;
    end;
end;

procedure TMainForm.HistoryKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if IsKeyCombinationMatch(Key, Shift, [VK_RETURN], [ssCtrl]) then
    begin
    MainService.ReplaceExpressionFromHistoryOnKey;
    end;
  if IsKeyCombinationMatch(Key, Shift, [VK_RETURN], []) then
    begin
    MainService.CopyFromHistoryToExpressionOnKey;
    end;
end;

procedure TMainForm.HistoryDblClick(Sender: TObject);
var
  Mods: TShiftState;
begin
  Mods := KeyboardStateToShiftState;

  if CheckModsState(Mods, []) then
    begin
    MainService.CopyFromHistoryToExpressionOnClick;
    end;
  if CheckModsState(Mods, [ssCtrl]) then
    begin
    MainService.ReplaceExpressionFromHistoryOnClick;
    end;
  if CheckModsState(Mods, [ssCtrl, ssAlt]) then
    begin
    MainService.RemoveHistoryItem;
    end;
end;

procedure TMainForm.VariableListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if IsKeyCombinationMatch(Key, Shift, [VK_RETURN], [ssCtrl]) then
    begin
    MainService.ReplaceExpressionFromVarListOnKey;
    end;
  if IsKeyCombinationMatch(Key, Shift, [VK_RETURN], []) then
    begin
    MainService.CopyFromVarListToExpressionOnKey;
    end;
  if IsKeyCombinationMatch(Key, Shift, [VK_RETURN], [ssShift]) then
    begin
    MainService.ReplaceVarNameFromVarListOnKey;
    end;
end;

procedure TMainForm.VarListDblClick(Sender: TObject);
var
  Mods: TShiftState;
begin
  Mods := KeyboardStateToShiftState;

  if CheckModsState(Mods, []) then
    begin
    MainService.CopyFromVarListToExpressionOnClick;
    end;
  if CheckModsState(Mods, [ssCtrl]) then
    begin
    MainService.ReplaceExpressionFromVarListOnClick;
    end;
  if CheckModsState(Mods, [ssShift]) then
    begin
    MainService.ReplaceVarNameFromVarListOnClick;
    end;
  if CheckModsState(Mods, [ssCtrl, ssAlt]) then
    begin
    MainService.RemoveVariable;
    end;
end;

procedure TMainForm.AppExceptionHandler(Sender: TObject; E: Exception);
begin
  try
    DisplayService.StatusError(E.Message);
  except
  end;
  try
    ShowMessage('Unhandled exception: ' + E.ClassName + ': ' + E.Message);
  except
  end;
end;


end.
