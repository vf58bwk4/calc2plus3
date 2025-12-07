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

implementation

uses
  Windows, Messages, SysUtils, DebugLog;

const
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

function EditWordBreakProc(Text: Pwidechar; CurrentPosition: Integer; TextLength: Integer; BreakCode: Integer): Integer; Stdcall;
begin
  case BreakCode of
    WB_ISDELIMITER:
      begin
      Result := 1; // 0: LEFT + RIGHT, 1: RIGHT + RIGHT
      end;
    WB_LEFT:
      begin
      Dec(CurrentPosition);
      while (0 <= CurrentPosition) and (Text[CurrentPosition] in EXPRESSION_DELIMITERS) do
        begin
        Dec(CurrentPosition);
        end;
      while (0 <= CurrentPosition) and not (Text[CurrentPosition] in EXPRESSION_DELIMITERS) do
        begin
        Dec(CurrentPosition);
        end;
      Result := CurrentPosition + 1;
      end;
    WB_RIGHT:
      begin
      if CurrentPosition > 0 then
        begin
        Dec(CurrentPosition);
        while (CurrentPosition < TextLength) and not (Text[CurrentPosition] in EXPRESSION_DELIMITERS) do
          begin
          Inc(CurrentPosition);
          end;
        while (CurrentPosition < TextLength) and (Text[CurrentPosition] in EXPRESSION_DELIMITERS) do
          begin
          Inc(CurrentPosition);
          end;
        end;
      Result := CurrentPosition;
      end;
    else
      begin
      Result := CurrentPosition;
      end;
    end;
  //DebugLog('BreakCode = ' + IntToStr(BreakCode) + ', CurrentPosition = ' + IntToStr(CurrentPosition) + ', Result = ' + IntToStr(Result));
end;

procedure SetEditWordBreakCallback(Edit: TEdit); inline;
begin
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

end.
