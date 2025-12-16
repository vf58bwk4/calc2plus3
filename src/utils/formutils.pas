unit FormUtils;

{$mode objfpc}
{$modeswitch nestedprocvars}
{$H+}
{$inline ON}

interface

uses
  Classes, StdCtrls, Forms;

type
  TVK_KeyCode    = 0..254;
  TVK_KeyCodeSet = set of TVK_KeyCode;

function IsTopMostWindow(const AForm: TForm): Boolean;

function IsKeyCombinationMatch(var Key: Word; const Mods: TShiftState; const ExpectedKeys: TVK_KeyCodeSet; const ExpectedMods: TShiftState): Boolean;
function CheckModsState(const Mods, ExpectedMods: TShiftState): Boolean;

procedure SetEditWordBreakCallback(Edit: TEdit);

procedure SetEditMargins(Edit: TEdit; const LeftPad, RightPad: Integer);
procedure SetEditCuebanner(Edit: TEdit; const Cuebanner: String);

function IsEditEmpty(Edit: TEdit): Boolean;
function IsEditTextSelected(Edit: TEdit): Boolean;
procedure SelectAllEditText(Edit: TEdit);

procedure DoCtrlBackspace(Edit: TEdit);

implementation

uses
  Windows, Messages, SysUtils, DebugLog;

const
  EM_GETSCROLLPOS = $04DD;
  EM_SETCUEBANNER = $1501;

  EXPRESSION_DELIMITERS = [' ', #9, #10, #13, '+', '-', '*', '/', '^', '(', ')', ',', '$', '%', '&'];

function IsTopMostWindow(const AForm: TForm): Boolean; inline;
begin
  Result := (GetForegroundWindow = AForm.Handle);
end;

function IsKeyCombinationMatch(var Key: Word; const Mods: TShiftState; const ExpectedKeys: TVK_KeyCodeSet; const ExpectedMods: TShiftState): Boolean;
begin
  Result := (Key in ExpectedKeys) and CheckModsState(Mods, ExpectedMods);
  if Result then
    begin
    Key := 0;
    end;
end;

function CheckModsState(const Mods, ExpectedMods: TShiftState): Boolean;
const
  SHIFTSTATES_ALL: TShiftState = [Low(TShiftStateEnum)..High(TShiftStateEnum)];
var
  NotExpectedMods: TShiftState;
begin
  NotExpectedMods := SHIFTSTATES_ALL - ExpectedMods;
  Result          := (ExpectedMods * Mods = ExpectedMods) and (NotExpectedMods * Mods = []);
end;


procedure SkipDelimitersLeft(const Text: Pwidechar; const TextLength: Integer; var CurrentPosition: Integer);
begin
  while (0 <= CurrentPosition) and (CurrentPosition < TextLength) and (Text[CurrentPosition] in EXPRESSION_DELIMITERS) do
    begin
    Dec(CurrentPosition);
    end;
end;

procedure SkipNonDelimitersLeft(const Text: Pwidechar; const TextLength: Integer; var CurrentPosition: Integer);
begin
  while (0 <= CurrentPosition) and (CurrentPosition < TextLength) and not (Text[CurrentPosition] in EXPRESSION_DELIMITERS) do
    begin
    Dec(CurrentPosition);
    end;
end;

procedure SkipDelimitersRight(const Text: Pwidechar; const TextLength: Integer; var CurrentPosition: Integer);
begin
  while (0 <= CurrentPosition) and (CurrentPosition < TextLength) and (Text[CurrentPosition] in EXPRESSION_DELIMITERS) do
    begin
    Inc(CurrentPosition);
    end;
end;

procedure SkipNonDelimitersRight(const Text: Pwidechar; const TextLength: Integer; var CurrentPosition: Integer);
begin
  while (0 <= CurrentPosition) and (CurrentPosition < TextLength) and not (Text[CurrentPosition] in EXPRESSION_DELIMITERS) do
    begin
    Inc(CurrentPosition);
    end;
end;

type
  TWordBreakState = (WBS_CLEAR, WBS_SKIPRIGHT);

var
  WordBreakState: TWordBreakState;

function EditWordBreakProc(Text: Pwidechar; CurrentPosition: Integer; TextLength: Integer; BreakCode: Integer): Integer; Stdcall;
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
      WordBreakState := WBS_SKIPRIGHT;
      Result         := 1; // 0: LEFT + RIGHT, 1: RIGHT + RIGHT
      end;
    WB_RIGHT:
      begin
      case WordBreakState of
        WBS_SKIPRIGHT:
          begin
          WordBreakState := WBS_CLEAR;
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
  WordBreakState := WBS_CLEAR;
  if Edit <> nil then
    begin
    SendMessage(Edit.Handle, EM_SETWORDBREAKPROC, 0, LParam(@EditWordBreakProc));
    end;
end;

procedure SetEditMargins(Edit: TEdit; const LeftPad, RightPad: Integer); inline;
begin
  if Edit <> nil then
    begin
    SendMessage(Edit.Handle, EM_SETMARGINS, EC_LEFTMARGIN or EC_RIGHTMARGIN, MakeLong(LeftPad, RightPad));
    end;
end;

procedure SetEditCuebanner(Edit: TEdit; const Cuebanner: String); inline;
begin
  if Edit <> nil then
    begin
    SendMessage(Edit.Handle, EM_SETCUEBANNER, 0, LParam(Pwidechar(WideString(Cuebanner))));
    end;
end;

function IsEditEmpty(Edit: TEdit): Boolean; inline;
begin
  Result := (Edit = nil) or (Trim(Edit.Text) = '');
end;

function IsEditTextSelected(Edit: TEdit): Boolean; inline;
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

procedure DoCtrlBackspace(Edit: TEdit);
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

end.
