unit MainForm;

{$mode ObjFPC}
{$H+}
{$modeswitch nestedprocvars}
{$inline ON}

interface

uses
  Classes, SysUtils, LCLType, Controls, StdCtrls, ComCtrls, Grids, ExtCtrls, Menus,
  Forms, LCLIntf, Windows, Messages;

type

  { Lets the form handle Ctrl+V, Shift+Insert and the context menu Paste }
  TEdit = class(StdCtrls.TEdit)
  private
    FOnPaste: TNotifyEvent;
    procedure WMPaste(var Msg: TMessage); message WM_PASTE;
  public
    property OnPaste: TNotifyEvent read FOnPaste write FOnPaste;
  end;

  { TMainForm }

  TMainForm = class(TForm)
    History:    TStringGrid;
    VarName:    TEdit;
    Expression: TEdit;
    VarList:    TStringGrid;

    StatusBar: TStatusBar;

    TrayIcon:             TTrayIcon;
    TrayIconPopupMenu:    TPopupMenu;
    MenuItemChangeHotKey: TMenuItem;
    MenuItemClose:        TMenuItem;

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
    procedure VarListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure VarListDblClick(Sender: TObject);

    procedure GridMouseWheelDown(Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean);
    procedure GridMouseWheelUp(Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean);

    procedure TrayIconMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure TrayIconMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure MenuItemChangeHotKeyClick(Sender: TObject);
    procedure MenuItemCloseClick(Sender: TObject);

    procedure WMHotKey(var Msg: TMessage); message WM_HOTKEY;
  private
    FHotKeyError:    String;
    FChangingHotKey: Boolean;

    procedure ShowMainWindow;
    procedure HideMainWindow;
    procedure ApplicationException(Sender: TObject; E: Exception);
    procedure ExpressionPaste(Sender: TObject);
    procedure ReportHotKeyError(const Message: String);
    procedure ReportPendingHotKeyError(Data: PtrInt);
  end;

var
  MainFormInstance: TMainForm;

implementation

{$R *.lfm}

uses
  Config, FormUtils, GridUtils, MainService, HotKeyService, HotKeyForm,
  Storage, DisplayService, Types, Dialogs, AppErrors;

procedure TEdit.WMPaste(var Msg: TMessage);
begin
  if Assigned(FOnPaste) then
    begin
    FOnPaste(Self);
    Msg.Result := 1;
    end
  else
    begin
    inherited;
    end;
end;

procedure TMainForm.ShowMainWindow;
begin
  WindowState := wsNormal;
  Show;
  MainService.SaveWindowVisible(True);
end;

procedure TMainForm.HideMainWindow;
begin
  Hide;
  MainService.SaveWindowVisible(False);
end;

procedure TMainForm.ApplicationException(Sender: TObject; E: Exception);
begin
  DisplayService.StatusError(ReportError(E));
end;

procedure TMainForm.ExpressionPaste(Sender: TObject);
begin
  MainService.PasteToExpression;
end;

{ Shown in the status bar and, as the window may be hidden, in a tray balloon; the error is already logged }
procedure TMainForm.ReportHotKeyError(const Message: String);
begin
  DisplayService.AddStatusError(Message);

  TrayIcon.BalloonTitle := Application.Title;
  TrayIcon.BalloonHint  := Message;
  TrayIcon.BalloonFlags := bfWarning;
  TrayIcon.ShowBalloonHint;
end;

{ Startup errors are reported once the application runs, so that the tray icon is shown }
procedure TMainForm.ReportPendingHotKeyError(Data: PtrInt);
begin
  ReportHotKeyError(FHotKeyError);
  FHotKeyError := '';
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  Application.OnException := @ApplicationException;
  DisplayService.Initialize(StatusBar);

  Storage.Initialize;

  Caption       := Application.Title;
  TrayIcon.Hint := Application.Title;

  MainService.Initialize(Self);

  FHotKeyError := HotKeyService.Initialize(Handle);
  if FHotKeyError <> '' then
    begin
    Application.QueueAsyncCall(@ReportPendingHotKeyError, 0);
    end;

  VarName.OnChange    := @VarNameChange;
  Expression.OnChange := @ExpressionChange;
  Expression.OnPaste  := @ExpressionPaste;

  SetEditTokenBreakCallback(Expression);
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  Application.RemoveAsyncCalls(Self);
  HotKeyService.Finalize;
  Application.OnException := nil;

    try
      begin
      MainService.Finalize;
      end;
    finally
      begin
      Storage.Finalize;
      end;
    end;
end;

procedure TMainForm.FormShow(Sender: TObject);
begin
  MainService.SetInitialFocus;
end;

procedure TMainForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  if WindowState = wsMinimized then
    begin
    Application.ProcessMessages;
    end;
  CloseAction := caHide;
  MainService.SaveWindowVisible(False);
end;

procedure TMainForm.TrayIconMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then
    begin
    ShowMainWindow;
    end;
end;

procedure TMainForm.TrayIconMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbRight then
    begin
    // Windows closes the menu on an outside click only if our thread owns the foreground (KB135788).
    // Use the tray window: LCL moves focus away from Application.Handle, which closes the menu.
    Windows.SetForegroundWindow(TrayIcon.Handle);
    TrayIconPopupMenu.PopUp;
    Windows.PostMessage(TrayIcon.Handle, WM_NULL, 0, 0);
    end;
end;

procedure TMainForm.MenuItemChangeHotKeyClick(Sender: TObject);
var
  ErrorMessage: String;
begin
  // the tray menu stays available while the modal dialog is shown
  if FChangingHotKey then
    begin
    Exit;
    end;

  FChangingHotKey := True;
    try
      begin
      ErrorMessage := HotKeyForm.ChangeHotKey;
      if ErrorMessage <> '' then
        begin
        ReportHotKeyError(ErrorMessage);
        end;
      end;
    finally
      begin
      FChangingHotKey := False;
      end;
    end;
end;

procedure TMainForm.MenuItemCloseClick(Sender: TObject);
begin
  Application.Terminate;
end;

procedure TMainForm.WMHotKey(var Msg: TMessage);
begin
  if Msg.wParam = HotKeyService.HOT_KEY_ID then
    begin
    if Visible then
      begin
      if not IsForegroundWindow(Self) then
        begin
        ShowMainWindow;
        end
      else
        begin
        HideMainWindow;
        end;
      end
    else
      begin
      ShowMainWindow;
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
  MainService.SaveWindowState;
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
    MainService.DeleteWordLeft;
    end;
  if IsKeyCombinationMatch(Key, Shift, [VK_DELETE], [ssCtrl]) then
    begin
    MainService.DeleteWordRight;
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
    MainService.CalculateAndAppendToHistory;
    end;
  if IsKeyCombinationMatch(Key, Shift, [VK_ESCAPE], []) then
    begin
    if IsEditEmpty(Expression) then
      begin
      HideMainWindow;
      end
    else if IsAllEditTextSelected(Expression) then
        begin
        MainService.DeleteWordLeft;
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

  if IsModsStateMatch(Mods, []) then
    begin
    MainService.CopyFromHistoryToExpressionOnClick;
    end;
  if IsModsStateMatch(Mods, [ssCtrl]) then
    begin
    MainService.ReplaceExpressionFromHistoryOnClick;
    end;
  if IsModsStateMatch(Mods, [ssCtrl, ssAlt]) then
    begin
    MainService.RemoveHistoryItem;
    end;
end;

procedure TMainForm.VarListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
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

  if IsModsStateMatch(Mods, []) then
    begin
    MainService.CopyFromVarListToExpressionOnClick;
    end;
  if IsModsStateMatch(Mods, [ssCtrl]) then
    begin
    MainService.ReplaceExpressionFromVarListOnClick;
    end;
  if IsModsStateMatch(Mods, [ssShift]) then
    begin
    MainService.ReplaceVarNameFromVarListOnClick;
    end;
  if IsModsStateMatch(Mods, [ssCtrl, ssAlt]) then
    begin
    MainService.RemoveVarListItem;
    end;
end;

end.
