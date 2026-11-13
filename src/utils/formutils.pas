unit FormUtils;

{$mode ObjFPC}
{$modeswitch nestedprocvars}
{$H+}
{$inline ON}

interface

uses
  Classes, Types, StdCtrls, Forms;

type
  TVirtualKey    = 0..254;
  TVirtualKeySet = set of TVirtualKey;

function IsForegroundWindow(const Form: TForm): Boolean;

function IsKeyCombinationMatch(var Key: Word; const Mods: TShiftState; const ExpectedKeys: TVirtualKeySet; const ExpectedMods: TShiftState): Boolean;
function IsModsStateMatch(const Mods, ExpectedMods: TShiftState): Boolean;

procedure SetEditTokenBreakCallback(Edit: TEdit);

procedure SetEditMargins(Edit: TEdit; const LeftPad, RightPad: Integer);
procedure SetEditCueBanner(Edit: TEdit; const CueBanner: String);

function IsEditEmpty(Edit: TEdit): Boolean;
function IsAllEditTextSelected(Edit: TEdit): Boolean;
procedure SelectAllEditText(Edit: TEdit);

procedure DeleteWordLeft(Edit: TEdit);
procedure DeleteWordRight(Edit: TEdit);

function AdjustWindowPos(const Pos: TPoint; const W, H: Integer): TPoint;

implementation

uses
  Windows, Messages, SysUtils, Math, TokenBreak;

const
  EM_GETSCROLLPOS = $04DD;
  EM_SETCUEBANNER = $1501;

function IsForegroundWindow(const Form: TForm): Boolean; inline;
begin
  Result := (GetForegroundWindow = Form.Handle);
end;

function IsKeyCombinationMatch(var Key: Word; const Mods: TShiftState; const ExpectedKeys: TVirtualKeySet; const ExpectedMods: TShiftState): Boolean;
begin
  Result := (Key in ExpectedKeys) and IsModsStateMatch(Mods, ExpectedMods);
  if Result then
    begin
    Key := 0;
    end;
end;

function IsModsStateMatch(const Mods, ExpectedMods: TShiftState): Boolean;
const
  SHIFTSTATES_ALL: TShiftState = [Low(TShiftStateEnum)..High(TShiftStateEnum)];
var
  NotExpectedMods: TShiftState;
begin
  NotExpectedMods := SHIFTSTATES_ALL - ExpectedMods;
  Result          := (ExpectedMods * Mods = ExpectedMods) and (NotExpectedMods * Mods = []);
end;

procedure SetEditTokenBreakCallback(Edit: TEdit);
begin
  if Edit <> nil then
    begin
    SendMessageW(Edit.Handle, EM_SETWORDBREAKPROC, 0, LPARAM(@EditTokenBreakProc));
    end;
end;

procedure SetEditMargins(Edit: TEdit; const LeftPad, RightPad: Integer); inline;
begin
  if Edit <> nil then
    begin
    SendMessage(Edit.Handle, EM_SETMARGINS, EC_LEFTMARGIN or EC_RIGHTMARGIN, MAKELONG(LeftPad, RightPad));
    end;
end;

procedure SetEditCueBanner(Edit: TEdit; const CueBanner: String); inline;
begin
  if Edit <> nil then
    begin
    SendMessage(Edit.Handle, EM_SETCUEBANNER, 0, LPARAM(PWideChar(WideString(CueBanner))));
    end;
end;

function IsEditEmpty(Edit: TEdit): Boolean; inline;
begin
  Result := (Edit = nil) or (Trim(Edit.Text) = '');
end;

function IsAllEditTextSelected(Edit: TEdit): Boolean; inline;
begin
  Result := (Edit <> nil) and (Edit.SelLength = Length(Edit.Text));
end;

procedure SelectAllEditText(Edit: TEdit); inline;
begin
  if Edit <> nil then
    begin
    Edit.SelectAll;
    end;
end;

{ Selection in UTF-16 indices, as used by the edit control and TokenBreak }
procedure GetEditSelection(Edit: TEdit; out SelStart, SelEnd: Integer);
var
  S, E: DWORD;
begin
  S := 0;
  E := 0;
  SendMessageW(Edit.Handle, EM_GETSEL, WPARAM(@S), LPARAM(@E));
  SelStart := S;
  SelEnd   := E;
end;

procedure DeleteEditRange(Edit: TEdit; const FromPos, ToPos: Integer);
const
  NO_TEXT: array[0..0] of WideChar = (#0);
begin
  if FromPos < ToPos then
    begin
    SendMessageW(Edit.Handle, EM_SETSEL, FromPos, ToPos);
    SendMessageW(Edit.Handle, EM_REPLACESEL, 1, LPARAM(@NO_TEXT[0]));
    end;
end;

procedure DeleteWordLeft(Edit: TEdit);
var
  SelStart, SelEnd: Integer;
begin
  if Edit <> nil then
    begin
    GetEditSelection(Edit, SelStart, SelEnd);
    if SelStart = SelEnd then
      begin
      SelStart := PrevTokenStart(UTF8Decode(Edit.Text), SelEnd);
      end;
    DeleteEditRange(Edit, SelStart, SelEnd);
    end;
end;

procedure DeleteWordRight(Edit: TEdit);
var
  SelStart, SelEnd: Integer;
begin
  if Edit <> nil then
    begin
    GetEditSelection(Edit, SelStart, SelEnd);
    if SelStart = SelEnd then
      begin
      SelEnd := NextTokenStart(UTF8Decode(Edit.Text), SelStart);
      end;
    DeleteEditRange(Edit, SelStart, SelEnd);
    end;
end;

function AdjustWindowPos(const Pos: TPoint; const W, H: Integer): TPoint;
var
  Monitor:  TMonitor;
  WorkArea: TRect;
  Center:   TPoint;
begin
  Result := Pos;

  // Find the monitor whose work area is nearest to the window centre
  Center.X := Pos.X + W div 2;
  Center.Y := Pos.Y + H div 2;
  Monitor  := Screen.MonitorFromPoint(Center);
  WorkArea := Monitor.WorkareaRect;

  // Clamp position so the whole window fits within the work area
  Result.X := EnsureRange(Pos.X, WorkArea.Left, Max(WorkArea.Left, WorkArea.Right  - W));
  Result.Y := EnsureRange(Pos.Y, WorkArea.Top,  Max(WorkArea.Top,  WorkArea.Bottom - H));
end;

end.
