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

procedure SetEditWordBreakCallback(Edit: TEdit);

procedure SetEditMargins(Edit: TEdit; const LeftPad, RightPad: Integer);
procedure SetEditCueBanner(Edit: TEdit; const CueBanner: String);

function IsEditEmpty(Edit: TEdit): Boolean;
function IsAllEditTextSelected(Edit: TEdit): Boolean;
procedure SelectAllEditText(Edit: TEdit);

procedure DeleteWordLeft(Edit: TEdit);

function AdjustWindowPos(const Pos: TPoint; const W, H: Integer): TPoint;

implementation

uses
  Windows, Messages, SysUtils, Math, DebugLog;

const
  EM_GETSCROLLPOS = $04DD;
  EM_SETCUEBANNER = $1501;

  EXPRESSION_DELIMITERS = [' ', #9, #10, #13, '+', '-', '*', '/', '^', '(', ')', ',', '$', '%', '&'];

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


procedure SkipDelimitersLeft(const Text: PWideChar; const TextLength: Integer; var CurrentPosition: Integer);
begin
  while (0 <= CurrentPosition) and (CurrentPosition < TextLength) and (Text[CurrentPosition] in EXPRESSION_DELIMITERS) do
    begin
    Dec(CurrentPosition);
    end;
end;

procedure SkipNonDelimitersLeft(const Text: PWideChar; const TextLength: Integer; var CurrentPosition: Integer);
begin
  while (0 <= CurrentPosition) and (CurrentPosition < TextLength) and not (Text[CurrentPosition] in EXPRESSION_DELIMITERS) do
    begin
    Dec(CurrentPosition);
    end;
end;

procedure SkipDelimitersRight(const Text: PWideChar; const TextLength: Integer; var CurrentPosition: Integer);
begin
  while (0 <= CurrentPosition) and (CurrentPosition < TextLength) and (Text[CurrentPosition] in EXPRESSION_DELIMITERS) do
    begin
    Inc(CurrentPosition);
    end;
end;

procedure SkipNonDelimitersRight(const Text: PWideChar; const TextLength: Integer; var CurrentPosition: Integer);
begin
  while (0 <= CurrentPosition) and (CurrentPosition < TextLength) and not (Text[CurrentPosition] in EXPRESSION_DELIMITERS) do
    begin
    Inc(CurrentPosition);
    end;
end;

type
  TWordBreakState = (wbsClear, wbsSkipRight);

var
  WordBreakState: TWordBreakState;

function EditWordBreakProc(Text: PWideChar; CurrentPosition: Integer; TextLength: Integer; BreakCode: Integer): Integer; stdcall;
begin
  case BreakCode of
    WB_LEFT:
      begin
      Dec(CurrentPosition);
      if (0 <= CurrentPosition) and (CurrentPosition < TextLength) and (Text[CurrentPosition] in EXPRESSION_DELIMITERS) then
        begin
        SkipDelimitersLeft(Text, TextLength, CurrentPosition);
        end
      else
        begin
        SkipNonDelimitersLeft(Text, TextLength, CurrentPosition);
        end;
      Result := CurrentPosition + 1;
      end;
    WB_ISDELIMITER:
      begin
      WordBreakState := wbsSkipRight;
      Result         := 1; // 0: LEFT + RIGHT, 1: RIGHT + RIGHT
      end;
    WB_RIGHT:
      begin
      case WordBreakState of
        wbsSkipRight:
          begin
          WordBreakState := wbsClear;
          Result         := CurrentPosition;
          end;
        else
          begin
          Dec(CurrentPosition);
          if (0 <= CurrentPosition) and (CurrentPosition < TextLength) and (Text[CurrentPosition] in EXPRESSION_DELIMITERS) then
            begin
            SkipDelimitersRight(Text, TextLength, CurrentPosition);
            end
          else
            begin
            SkipNonDelimitersRight(Text, TextLength, CurrentPosition);
            end;
          Result := CurrentPosition;
          end;
        end;
      end;
    else
      begin
      Result := CurrentPosition;
      end;
    end;
end;

procedure SetEditWordBreakCallback(Edit: TEdit); inline;
begin
  WordBreakState := wbsClear;
  if Edit <> nil then
    begin
    SendMessage(Edit.Handle, EM_SETWORDBREAKPROC, 0, LPARAM(@EditWordBreakProc));
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

procedure DeleteWordLeft(Edit: TEdit);
var
  Text:             String;
  InitIdx, CurrIdx: Integer;
begin
  if Edit <> nil then
    begin
    if Edit.SelLength > 0 then
      begin
      Edit.SelText := '';
      end
    else
      begin
      Text    := Edit.Text;
      InitIdx := Edit.SelStart;
      CurrIdx := InitIdx;
      if (CurrIdx > 0) and (Text[CurrIdx] in EXPRESSION_DELIMITERS) then
        begin
        while (CurrIdx > 0) and (Text[CurrIdx] in EXPRESSION_DELIMITERS) do
          begin
          Dec(CurrIdx);
          end;
        end
      else
        begin
        while (CurrIdx > 0) and not (Text[CurrIdx] in EXPRESSION_DELIMITERS) do
          begin
          Dec(CurrIdx);
          end;
        end;
      if InitIdx - CurrIdx > 0 then
        begin
        Delete(Text, CurrIdx + 1, InitIdx - CurrIdx);
        Edit.Text     := Text;
        Edit.SelStart := CurrIdx;
        end;
      end;
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
