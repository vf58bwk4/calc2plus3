unit TokenBreak;

{ Word-wise caret stops in the Expression box. A token is an operand, a run of
  operators or a single parenthesis; spaces between tokens are skipped.
  Positions are UTF-16 indices between characters: 0..Length(Text). }

{$mode ObjFPC}
{$H+}

interface

{ Start of the token before Pos: target of Ctrl+Left and Ctrl+Backspace }
function PrevTokenStart(const Text: UnicodeString; const Pos: Integer): Integer;
{ Start of the token after Pos: target of Ctrl+Right and Ctrl+Delete }
function NextTokenStart(const Text: UnicodeString; const Pos: Integer): Integer;

{ EM_SETWORDBREAKPROC callback: Ctrl+arrows, Ctrl+Shift+arrows and double-click }
function EditTokenBreakProc(Text: PWideChar; CurrentPosition: Integer; TextLength: Integer; BreakCode: Integer): Integer; stdcall;

implementation

uses
  Windows, Math, ExprLocale;

type
  TCharKind = (ckSpace, ckOperator, ckParenthesis, ckOperand);

function CharKind(const C: WideChar): TCharKind;
begin
  case C of
    ' ', #9, #10, #13:
      begin
      Result := ckSpace;
      end;
    '(', ')':
      begin
      Result := ckParenthesis;
      end;
    '+', '-', '*', '/', '^', '$', '%', '&':
      begin
      Result := ckOperator;
      end;
    else
      begin
      if C = WideChar(ExprLocale.ArgumentSeparator) then
        begin
        Result := ckOperator;
        end
      else
        begin
        Result := ckOperand;
        end;
      end;
    end;
end;

function IsSameToken(const Left, Right: WideChar): Boolean;
begin
  Result := (CharKind(Left) = CharKind(Right)) and (CharKind(Left) <> ckParenthesis);
end;

function PrevTokenStart(const Text: UnicodeString; const Pos: Integer): Integer;
begin
  Result := EnsureRange(Pos, 0, Length(Text));
  while (Result > 0) and (CharKind(Text[Result]) = ckSpace) do
    begin
    Dec(Result);
    end;
  if Result > 0 then
    begin
    Dec(Result);
    while (Result > 0) and IsSameToken(Text[Result], Text[Result + 1]) do
      begin
      Dec(Result);
      end;
    end;
end;

function NextTokenStart(const Text: UnicodeString; const Pos: Integer): Integer;
var
  Len: Integer;
begin
  Len    := Length(Text);
  Result := EnsureRange(Pos, 0, Len);
  if (Result < Len) and (CharKind(Text[Result + 1]) <> ckSpace) then
    begin
    Inc(Result);
    while (Result < Len) and IsSameToken(Text[Result], Text[Result + 1]) do
      begin
      Inc(Result);
      end;
    end;
  while (Result < Len) and (CharKind(Text[Result + 1]) = ckSpace) do
    begin
    Inc(Result);
    end;
end;

var
  RightMovePending:  Boolean;
  RightMoveStartPos: Integer;

{ comctl32 6.0 calls D(c), R(c), R(c + 1) for Ctrl+Right and uses the last result;
  it calls L(c), R(L + 1) for Ctrl+Left (uses L) and double-click (selects L..R) }
function EditTokenBreakProc(Text: PWideChar; CurrentPosition: Integer; TextLength: Integer; BreakCode: Integer): Integer; stdcall;
var
  S: UnicodeString;
begin
  SetString(S, Text, TextLength);
  Result := CurrentPosition;
  case BreakCode of
    WB_ISDELIMITER:
      begin
      RightMovePending  := True;
      RightMoveStartPos := CurrentPosition;
      Result            := 1;
      end;
    WB_LEFT:
      begin
      RightMovePending := False;
      Result           := PrevTokenStart(S, CurrentPosition);
      end;
    WB_RIGHT:
      begin
      if RightMovePending and (CurrentPosition = RightMoveStartPos) then
        begin
        RightMovePending := False;
        end
      else
        begin
        RightMovePending := False;
        Result           := NextTokenStart(S, Max(CurrentPosition - 1, 0));
        end;
      end;
    end;
end;

end.
