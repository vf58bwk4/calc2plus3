unit MainForm;

{$mode ObjFPC}
{$H+}
{$modeswitch nestedprocvars}
{$inline ON}

interface

uses
  Classes, Forms, Windows, Controls, StdCtrls, ComCtrls, Grids, ExtCtrls, Menus;

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
  Config, FormUtils, GridUtils, CalcService;

const
  HOTKEY_ID = 1;

procedure TCalculator.FormCreate(Sender: TObject);
begin
  Windows.RegisterHotKey(Handle, HOTKEY_ID, HOT_KEY.ModKey, HOT_KEY.VirtualKey);

  Caption       := Application.Title;
  TrayIcon.Hint := Application.Title;

  CalcService.Receive(self);
  CalcService.Initialize;
end;

procedure TCalculator.FormDestroy(Sender: TObject);
begin
  Windows.UnregisterHotKey(Handle, HOTKEY_ID);
end;

procedure TCalculator.FormShow(Sender: TObject);
begin
  CalcService.SetFocus;
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

procedure TCalculator.VarNameKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if IsKeyCombinationMatch(Key, Shift, [VK_BACK], [ssCtrl]) then
    begin
    CalcService.ClearVarName;
    end;
  if IsKeyCombinationMatch(Key, Shift, [VK_RETURN], [ssCtrl]) then
    begin
    CalcService.CalculateAndUpsertVariable;
    end;
  if IsKeyCombinationMatch(Key, Shift, [VK_ADD, VK_OEM_PLUS], [ssCtrl]) then
    begin
    CalcService.CalculateAndAddVariable;
    end;
  if IsKeyCombinationMatch(Key, Shift, [VK_SUBTRACT, VK_OEM_MINUS], [ssCtrl]) then
    begin
    CalcService.CalculateAndSubtractVariable;
    end;
end;

procedure TCalculator.ExpressionKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if IsKeyCombinationMatch(Key, Shift, [VK_BACK], [ssCtrl]) then
    begin
    CalcService.ClearExpression;
    end;
  if IsKeyCombinationMatch(Key, Shift, [VK_RETURN], [ssCtrl]) then
    begin
    CalcService.CalculateAndUpsertVariable;
    end;
  if IsKeyCombinationMatch(Key, Shift, [VK_ADD, VK_OEM_PLUS], [ssCtrl]) then
    begin
    CalcService.CalculateAndAddVariable;
    end;
  if IsKeyCombinationMatch(Key, Shift, [VK_SUBTRACT, VK_OEM_MINUS], [ssCtrl]) then
    begin
    CalcService.CalculateAndSubtractVariable;
    end;
  if IsKeyCombinationMatch(Key, Shift, [VK_RETURN], []) then
    begin
    CalcService.CalculateAndInsertInHistory;
    end;
  if IsKeyCombinationMatch(Key, Shift, [VK_ESCAPE], []) then
    begin
    if IsEditEmpty(Expression) then
      begin
      Hide;
      end
    else if IsEditTextSelected(Expression) then
        begin
        CalcService.ClearExpression;
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
    CalcService.ReplaceExpressionFromHistoryOnKey;
    end;
  if IsKeyCombinationMatch(Key, Shift, [VK_RETURN], []) then
    begin
    CalcService.CopyFromHistoryToExpressionOnKey;
    end;
end;

procedure TCalculator.HistoryDblClick(Sender: TObject);
var
  Mods: TShiftState;
begin
  Mods := KeyboardStateToShiftState;

  if CheckModsState(Mods, []) then
    begin
    CalcService.CopyFromHistoryToExpressionOnClick;
    end;
  if CheckModsState(Mods, [ssCtrl]) then
    begin
    CalcService.ReplaceExpressionFromHistoryOnClick;
    end;
end;

procedure TCalculator.VariableListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if IsKeyCombinationMatch(Key, Shift, [VK_RETURN], [ssCtrl]) then
    begin
    CalcService.ReplaceExpressionFromVarListOnKey;
    end;
  if IsKeyCombinationMatch(Key, Shift, [VK_RETURN], []) then
    begin
    CalcService.CopyFromVarListToExpressionOnKey;
    end;
  if IsKeyCombinationMatch(Key, Shift, [VK_RETURN], [ssShift]) then
    begin
    CalcService.ReplaceVarNameFromVarListOnKey;
    end;
end;

procedure TCalculator.VarListDblClick(Sender: TObject);
var
  Mods: TShiftState;
begin
  Mods := KeyboardStateToShiftState;

  if CheckModsState(Mods, []) then
    begin
    CalcService.CopyFromVarListToExpressionOnClick;
    end;
  if CheckModsState(Mods, [ssCtrl]) then
    begin
    CalcService.ReplaceExpressionFromVarListOnClick;
    end;
  if CheckModsState(Mods, [ssShift]) then
    begin
    CalcService.ReplaceVarNameFromVarListOnClick;
    end;
  if CheckModsState(Mods, [ssCtrl, ssAlt]) then
    begin
    CalcService.RemoveVariable;
    end;
end;

end.
