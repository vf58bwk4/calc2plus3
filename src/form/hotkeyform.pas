unit HotKeyForm;

{$mode ObjFPC}
{$H+}
{$inline ON}

interface

uses
  Classes, SysUtils, Controls, StdCtrls, Forms, LMessages;

const
  WM_USED_HOT_KEY = LM_USER + 1; // WParam: the TShortCut taken by the keyboard hook

type

  { Learns a new hotkey: the keys pressed are shown and checked; OK or Enter applies them.
    Backspace or Delete chooses no hotkey, the keyboard way to the None button.
    No control takes the focus by keyboard, so every key reaches the form.
    A hotkey of another program would never reach it: a keyboard hook takes such keys first }
  THotKeyForm = class(TForm)
    PromptLabel:  TLabel;
    HotKeyLabel:  TLabel;
    MessageLabel: TLabel;
    OKButton:     TButton;
    NoneButton:   TButton;
    CancelButton: TButton;

    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure OKButtonClick(Sender: TObject);
    procedure NoneButtonClick(Sender: TObject);
    procedure CancelButtonClick(Sender: TObject);
  private
    FHotKey:           TShortCut;
    FShowingModifiers: Boolean;
    FHookWarning:      String;

    procedure ShowHotKey;
    procedure ShowModifiers;
    procedure ShowError(const ErrorMessage: String);
    procedure Apply(const HotKey: TShortCut);
    procedure FocusForm;
    procedure WMUsedHotKey(var Message: TLMessage); message WM_USED_HOT_KEY;
  public
    { Shown whenever there is no error for the keys pressed }
    procedure ShowHookWarning(const Warning: String);
  end;

{ Shows the dialog. The hotkey is suspended meanwhile, so that its keys can be learned.
  Returns '' or an error message about the hotkey active afterwards; the error is already logged }
function ChangeHotKey: String;

implementation

{$R *.lfm}

uses
  Windows, LCLType, HotKeyService, Logger;

const
  NO_HOT_KEY_TEXT = '(none)';
  HOOK_WARNING    = 'Hotkeys of other programs cannot be detected here';

  MODIFIER_KEYS = [VK_SHIFT, VK_CONTROL, VK_MENU, VK_LSHIFT, VK_RSHIFT, VK_LCONTROL, VK_RCONTROL,
    VK_LMENU, VK_RMENU, VK_LWIN, VK_RWIN];

  WH_KEYBOARD_LL = 13; // missing in FPC 3.2.2
  // an unassigned key, sent after a taken key so that releasing Alt or Win opens no menu
  MASK_KEY       = $E8;

type
  // missing in FPC 3.2.2
  TKbdLLHookStruct = record
    vkCode:      DWORD;
    scanCode:    DWORD;
    flags:       DWORD;
    time:        DWORD;
    dwExtraInfo: ULONG_PTR;
  end;
  PKbdLLHookStruct = ^TKbdLLHookStruct;

var
  LearningForm: THotKeyForm = nil;

{ The keyboard state while the key event is not yet processed }
function AsyncShiftState: TShiftState;
begin
  Result := [];
  if GetAsyncKeyState(VK_SHIFT) < 0 then
    begin
    Include(Result, ssShift);
    end;
  if GetAsyncKeyState(VK_CONTROL) < 0 then
    begin
    Include(Result, ssCtrl);
    end;
  if GetAsyncKeyState(VK_MENU) < 0 then
    begin
    Include(Result, ssAlt);
    end;
  if (GetAsyncKeyState(VK_LWIN) < 0) or (GetAsyncKeyState(VK_RWIN) < 0) then
    begin
    Include(Result, ssMeta);
    end;
end;

{ Windows sends the keys of a hotkey registered by another program to that program only.
  While the dialog is in the foreground, such keys are taken here and passed to it }
function KeyboardHook(Code: LongInt; WParam: WPARAM; LParam: LPARAM): LRESULT; stdcall;
var
  Key:    Word;
  Shift:  TShiftState;
  HotKey: TShortCut;
begin
  if (Code = HC_ACTION) and ((WParam = WM_KEYDOWN) or (WParam = WM_SYSKEYDOWN))
    and Assigned(LearningForm) and (GetForegroundWindow = LearningForm.Handle) then
    begin
    Key := Word(PKbdLLHookStruct(LParam)^.vkCode);
    if not (Key in MODIFIER_KEYS) and (Key <> MASK_KEY) then
      begin
      Shift  := AsyncShiftState;
      HotKey := KeyToShortCut(Key, Shift);
      if (CheckHotKey(HotKey) = '') and (CheckNotUsed(HotKey) <> '') then
        begin
        if Shift * [ssAlt, ssMeta] <> [] then
          begin
          keybd_event(MASK_KEY, 0, 0, 0);
          keybd_event(MASK_KEY, 0, KEYEVENTF_KEYUP, 0);
          end;
        PostMessage(LearningForm.Handle, WM_USED_HOT_KEY, HotKey, 0);
        Exit(1);
        end;
      end;
    end;
  Result := CallNextHookEx(0, Code, WParam, LParam);
end;

function ChangeHotKey: String;
var
  Form: THotKeyForm;
  Hook: HHOOK;
begin
  HotKeyService.Suspend;
  Hook := 0;
    try
      begin
      Form := THotKeyForm.Create(nil);
        try
          begin
          LearningForm := Form;
          Hook         := SetWindowsHookEx(WH_KEYBOARD_LL, HOOKPROC(@KeyboardHook), HInstance, 0);
          if Hook = 0 then
            begin
            LogWarning('Could not install the keyboard hook: ' + SysErrorMessage(GetLastError));
            Form.ShowHookWarning(HOOK_WARNING);
            end;
          Form.ShowModal;
          end;
        finally
          begin
          if Hook <> 0 then
            begin
            UnhookWindowsHookEx(Hook);
            end;
          LearningForm := nil;
          Form.Free;
          end;
        end;
      end;
    finally
      begin
      Result := HotKeyService.Resume;
      end;
    end;
end;

{ Modifier keys as they are written in the hotkey text, e.g. 'Ctrl+Alt+' }
function ModifiersText(const Shift: TShiftState): String;
begin
  Result := HotKeyToText(KeyToShortCut(VK_A, Shift));
  SetLength(Result, Length(Result) - Length('A'));
end;

function IsPlainKey(const Key: Word; const Shift: TShiftState; const PlainKey: Word): Boolean; inline;
begin
  Result := (Key = PlainKey) and (Shift * [ssShift, ssCtrl, ssAlt, ssMeta] = []);
end;

procedure THotKeyForm.FormCreate(Sender: TObject);
begin
  FHotKey := HotKeyService.CurrentHotKey;
  ShowHotKey;
end;

procedure THotKeyForm.FormShow(Sender: TObject);
begin
  FocusForm;
end;

procedure THotKeyForm.ShowHotKey;
var
  ErrorMessage: String;
begin
  FShowingModifiers := False;
  if FHotKey = NO_HOT_KEY then
    begin
    HotKeyLabel.Caption := NO_HOT_KEY_TEXT;
    ShowError('');
    OKButton.Enabled    := HotKeyService.CurrentHotKey <> NO_HOT_KEY;
    end
  else
    begin
    ErrorMessage := CheckHotKey(FHotKey);
    if ErrorMessage = '' then
      begin
      ErrorMessage := CheckNotUsed(FHotKey);
      end;
    HotKeyLabel.Caption := HotKeyToText(FHotKey);
    ShowError(ErrorMessage);
    OKButton.Enabled    := ErrorMessage = '';
    end;
end;

procedure THotKeyForm.ShowError(const ErrorMessage: String);
begin
  if ErrorMessage <> '' then
    begin
    MessageLabel.Caption := ErrorMessage;
    end
  else
    begin
    MessageLabel.Caption := FHookWarning;
    end;
end;

procedure THotKeyForm.ShowHookWarning(const Warning: String);
begin
  FHookWarning := Warning;
  ShowHotKey;
end;

{ While only modifiers are held down }
procedure THotKeyForm.ShowModifiers;
var
  Shift: TShiftState;
begin
  Shift := KeyboardStateToShiftState * [ssShift, ssCtrl, ssAlt, ssMeta];
  if Shift = [] then
    begin
    ShowHotKey;
    end
  else
    begin
    HotKeyLabel.Caption := ModifiersText(Shift) + '...';
    ShowError('');
    FShowingModifiers   := True;
    end;
end;

procedure THotKeyForm.Apply(const HotKey: TShortCut);
var
  ErrorMessage: String;
begin
  if HotKeyService.TryChange(HotKey, ErrorMessage) then
    begin
    ModalResult := mrOk;
    end
  else
    begin
    ShowError(ErrorMessage);
    FocusForm;
    end;
end;

{ A clicked button takes the focus: give it back to the form, so that Space does not press the button }
procedure THotKeyForm.FocusForm;
begin
  ActiveControl := nil;
  if CanFocus then
    begin
    SetFocus;
    end;
end;

procedure THotKeyForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = MASK_KEY then
    begin
    Key := 0;
    Exit;
    end;

  // LCL leaves the Win key out of Shift on key events
  Shift := KeyboardStateToShiftState;

  if Key in MODIFIER_KEYS then
    begin
    ShowModifiers;
    end
  else if IsPlainKey(Key, Shift, VK_ESCAPE) then
      begin
      ModalResult := mrCancel;
      end
    else if IsPlainKey(Key, Shift, VK_RETURN) then
        begin
        if OKButton.Enabled then
          begin
          Apply(FHotKey);
          end;
        end
      else if IsPlainKey(Key, Shift, VK_BACK) or IsPlainKey(Key, Shift, VK_DELETE) then
          begin
          FHotKey := NO_HOT_KEY;
          ShowHotKey;
          end
        else
          begin
          FHotKey := KeyToShortCut(Key, Shift * [ssShift, ssCtrl, ssAlt, ssMeta]);
          ShowHotKey;
          end;

  // the keys are learned, not used: no system menu on Alt or F10, no button press on Space
  Key := 0;
end;

procedure THotKeyForm.FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key in MODIFIER_KEYS) and FShowingModifiers then
    begin
    ShowModifiers;
    end;
  Key := 0;
end;

procedure THotKeyForm.OKButtonClick(Sender: TObject);
begin
  Apply(FHotKey);
end;

procedure THotKeyForm.NoneButtonClick(Sender: TObject);
begin
  Apply(NO_HOT_KEY);
end;

procedure THotKeyForm.CancelButtonClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure THotKeyForm.WMUsedHotKey(var Message: TLMessage);
begin
  FHotKey := TShortCut(Message.WParam);
  ShowHotKey;
end;

end.
