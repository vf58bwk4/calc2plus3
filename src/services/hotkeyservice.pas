unit HotKeyService;

{$mode ObjFPC}
{$H+}
{$inline ON}

interface

uses
  Classes, Windows;

const
  HOT_KEY_ID  = 1;
  NO_HOT_KEY  = TShortCut(0);

{ Hotkeys are TShortCut values; the text form is Lazarus' non-localized one, e.g. 'Ctrl+Alt+K'.
  NO_HOT_KEY is written as an empty text }
function HotKeyToText(const HotKey: TShortCut): String;
function TryTextToHotKey(const Text: String; out HotKey: TShortCut): Boolean;

{ Returns '' if HotKey may be used as a system-wide hotkey, otherwise the reason why not }
function CheckHotKey(const HotKey: TShortCut): String;

{ Returns '' if no other program has registered HotKey, otherwise the error message; nothing is logged }
function CheckNotUsed(const HotKey: TShortCut): String;

{ Loads the stored hotkey and registers it for AWindow.
  Returns '' or an error message for the user; the error is already logged }
function Initialize(const AWindow: HWND): String;
procedure Finalize;

{ The configured hotkey; it is NO_HOT_KEY or registered unless an error was reported }
function CurrentHotKey: TShortCut;

{ Suspend unregisters the hotkey, so that its keys reach the application, e.g. while a new hotkey is learned.
  Resume registers it again; returns '' or a logged error message }
procedure Suspend;
function Resume: String;

{ Registers and stores NewHotKey instead of the current one.
  On failure the current hotkey stays unregistered until Resume }
function TryChange(const NewHotKey: TShortCut; out ErrorMessage: String): Boolean;

implementation

uses
  SysUtils, LCLType, LCLProc, Config, Storage, Logger;

const
  MOD_NOREPEAT = $4000; // missing in FPC 3.2.2: no repeated WM_HOTKEY while the keys are held down

  TEST_HOT_KEY_ID = HOT_KEY_ID + 1;

  MODIFIER_KEYS = [VK_SHIFT, VK_CONTROL, VK_MENU, VK_LSHIFT, VK_RSHIFT, VK_LCONTROL, VK_RCONTROL,
    VK_LMENU, VK_RMENU, VK_LWIN, VK_RWIN];
  FUNCTION_KEYS = [VK_F1..VK_F24];

var
  Window:     HWND;
  Current:    TShortCut;
  Registered: Boolean;

  {================ Private routines ================}

function KeyOf(const HotKey: TShortCut): Word; inline;
begin
  Result := HotKey and $FF;
end;

function ToModifiers(const HotKey: TShortCut): UINT;
begin
  Result := MOD_NOREPEAT;
  if HotKey and scShift <> 0 then
    begin
    Result := Result or MOD_SHIFT;
    end;
  if HotKey and scCtrl <> 0 then
    begin
    Result := Result or MOD_CONTROL;
    end;
  if HotKey and scAlt <> 0 then
    begin
    Result := Result or MOD_ALT;
    end;
  if HotKey and scMeta <> 0 then
    begin
    Result := Result or MOD_WIN;
    end;
end;

function RegisterError(const HotKey: TShortCut; const ErrorCode: DWORD): String;
begin
  if ErrorCode = ERROR_HOTKEY_ALREADY_REGISTERED then
    begin
    Result := Format('Hotkey %s is already used by another program', [HotKeyToText(HotKey)]);
    end
  else
    begin
    Result := Format('Could not register hotkey %s: %s', [HotKeyToText(HotKey), SysErrorMessage(ErrorCode)]);
    end;
end;

{ Returns '' or the error message }
function DoRegister(const HotKey: TShortCut): String;
begin
  if Windows.RegisterHotKey(Window, HOT_KEY_ID, ToModifiers(HotKey), KeyOf(HotKey)) then
    begin
    Result := '';
    end
  else
    begin
    Result := RegisterError(HotKey, GetLastError);
    end;
end;

procedure DoUnregister;
begin
  if Registered then
    begin
    Windows.UnregisterHotKey(Window, HOT_KEY_ID);
    Registered := False;
    end;
end;

{================ Interface routines ==============}

function HotKeyToText(const HotKey: TShortCut): String;
begin
  if HotKey = NO_HOT_KEY then
    begin
    Result := '';
    end
  else
    begin
    Result := ShortCutToTextRaw(HotKey);
    end;
end;

function TryTextToHotKey(const Text: String; out HotKey: TShortCut): Boolean;
begin
  if Trim(Text) = '' then
    begin
    HotKey := NO_HOT_KEY;
    Result := True;
    end
  else
    begin
    HotKey := TextToShortCutRaw(Trim(Text));
    Result := HotKey <> NO_HOT_KEY;
    end;
end;

function CheckHotKey(const HotKey: TShortCut): String;
var
  Key: Word;
begin
  Result := '';
  Key    := KeyOf(HotKey);

  if (Key = 0) or (Key in MODIFIER_KEYS) or (HotKeyToText(HotKey) = '') then
    begin
    Result := 'Press a key, not only modifiers';
    end
  else if (HotKey and (scCtrl or scAlt or scMeta) = 0) and not (Key in FUNCTION_KEYS) then
      begin
      // it would take the key away from typing in every program
      Result := 'Add Ctrl, Alt or Meta (Win); only F1-F24 work alone or with Shift';
      end
    else if HotKey = (scAlt or VK_F4) then
        begin
        Result := 'Alt+F4 closes windows';
        end;
end;

{ Windows tells only by a failing registration; the test registration is undone at once }
function CheckNotUsed(const HotKey: TShortCut): String;
begin
  if Registered and (HotKey = Current) then
    begin
    Result := '';
    end
  else if Windows.RegisterHotKey(Window, TEST_HOT_KEY_ID, ToModifiers(HotKey), KeyOf(HotKey)) then
      begin
      Windows.UnregisterHotKey(Window, TEST_HOT_KEY_ID);
      Result := '';
      end
    else
      begin
      Result := RegisterError(HotKey, GetLastError);
      end;
end;

function Initialize(const AWindow: HWND): String;
var
  Text:   String;
  HotKey: TShortCut;
begin
  Window     := AWindow;
  Current    := NO_HOT_KEY;
  Registered := False;
  Result     := '';

    try
      begin
      Text := Storage.LoadHotKey;
      end;
    except
    on E: Exception do
      begin
      Result := 'Could not load the hotkey: ' + E.Message;
      LogWarning(Result + ' (' + E.ClassName + ')');
      Exit;
      end;
    end;

  if not TryTextToHotKey(Text, HotKey) then
    begin
    Result := Format('Unknown hotkey "%s" in %s', [Text, SETTINGS_FILE.Filename]);
    end
  else if HotKey <> NO_HOT_KEY then
      begin
      Result := CheckHotKey(HotKey);
      if Result <> '' then
        begin
        Result := Format('Hotkey "%s" in %s is not allowed: %s', [Text, SETTINGS_FILE.Filename, Result]);
        end
      else
        begin
        Current := HotKey;
        Result  := Resume;
        Exit; // Resume logs its error
        end;
      end;

  if Result <> '' then
    begin
    LogWarning(Result);
    end;
end;

procedure Finalize;
begin
  DoUnregister;
end;

function CurrentHotKey: TShortCut;
begin
  Result := Current;
end;

procedure Suspend;
begin
  DoUnregister;
end;

function Resume: String;
begin
  Result := '';
  if (Current <> NO_HOT_KEY) and not Registered then
    begin
    Result     := DoRegister(Current);
    Registered := Result = '';
    if not Registered then
      begin
      LogWarning(Result);
      end;
    end;
end;

function TryChange(const NewHotKey: TShortCut; out ErrorMessage: String): Boolean;
begin
  ErrorMessage := '';
  if NewHotKey <> NO_HOT_KEY then
    begin
    ErrorMessage := CheckHotKey(NewHotKey);
    end;

  if ErrorMessage = '' then
    begin
    DoUnregister;
    if NewHotKey <> NO_HOT_KEY then
      begin
      ErrorMessage := DoRegister(NewHotKey);
      end;
    end;

  if ErrorMessage = '' then
    begin
      try
        begin
        Storage.SaveHotKey(HotKeyToText(NewHotKey));
        end;
      except
      on E: Exception do
        begin
        if NewHotKey <> NO_HOT_KEY then
          begin
          Windows.UnregisterHotKey(Window, HOT_KEY_ID);
          end;
        ErrorMessage := 'Could not save the hotkey: ' + E.Message;
        LogWarning(ErrorMessage + ' (' + E.ClassName + ')');
        end;
      end;
    end;

  Result := ErrorMessage = '';
  if Result then
    begin
    Current    := NewHotKey;
    Registered := NewHotKey <> NO_HOT_KEY;
    end;
end;

end.
