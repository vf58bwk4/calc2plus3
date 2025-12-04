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

procedure SetEditMargins(Edit: TEdit; const LeftPad, RightPad: Integer);
procedure SetEditCuebanner(Edit: TEdit; const Cuebanner: String);

function IsEditEmpty(Edit: TEdit): Boolean;
function IsEditTextSelected(Edit: TEdit): Boolean;
procedure SelectAllEditText(Edit: TEdit);

implementation

uses
  SysUtils, Windows;

const
  EM_SETCUEBANNER = $1501;

  SHIFTSTATES_ALL: TShiftState = [Low(TShiftStateEnum)..High(TShiftStateEnum)];

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
var
  NotExpectedMods: TShiftState;
begin
  NotExpectedMods := SHIFTSTATES_ALL - ExpectedMods;
  Result          := (ExpectedMods * Mods = ExpectedMods) and (NotExpectedMods * Mods = []);
end;

procedure SetEditMargins(Edit: TEdit; const LeftPad, RightPad: Integer); inline;
begin
  SendMessage(Edit.Handle, EM_SETMARGINS, EC_LEFTMARGIN or EC_RIGHTMARGIN, MakeLong(LeftPad, RightPad));
end;

procedure SetEditCuebanner(Edit: TEdit; const Cuebanner: String); inline;
begin
  SendMessage(Edit.Handle, EM_SETCUEBANNER, WParam(0), LParam(Pwidechar(WideString(Cuebanner))));
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
