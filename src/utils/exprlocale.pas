unit ExprLocale;

{ Converts expression text between two formats:
  - local: the Windows locale, used in the Expression box and the grids;
  - invariant: '.' as decimal separator and ',' between function arguments,
    used by the parser and in the data files.
  The locale is read once at startup, so a change takes effect after restart. }

{$mode ObjFPC}
{$H+}
{$inline ON}

interface

function ToInvariant(const Text: String): String;
function ToLocal(const Text: String): String;

function FormatNumber(const Value: Double): String;
function ParseNumber(const Text: String): Double;
function TryParseNumber(const Text: String; out Value: Double): Boolean;

{ Returns local text with digit grouping removed from numbers, e.g.
  1'234'567.89, 1.234.567,89 or 12,34,567.89 become 1234567.89 (en-GB) }
function NormalizePastedText(const Text: String): String;

implementation

uses
  SysUtils;

const
  INVARIANT_DECIMAL_SEPARATOR  = '.';
  INVARIANT_ARGUMENT_SEPARATOR = ',';

var
  LocalDecimalSeparator:  Char;
  LocalArgumentSeparator: Char;
  LocalGroupSeparator:    Char;
  InvariantFormat:        TFormatSettings;

  {================ Private routines ================}

function IsInvariantLocale: Boolean; inline;
begin
  Result := (LocalDecimalSeparator = INVARIANT_DECIMAL_SEPARATOR) and
            (LocalArgumentSeparator = INVARIANT_ARGUMENT_SEPARATOR);
end;

procedure ReadLocale;
begin
  LocalDecimalSeparator := DefaultFormatSettings.DecimalSeparator;
  if not (LocalDecimalSeparator in ['.', ',']) then
    begin
    LocalDecimalSeparator := INVARIANT_DECIMAL_SEPARATOR;
    end;

  LocalArgumentSeparator := DefaultFormatSettings.ListSeparator;
  if not (LocalArgumentSeparator in [',', ';']) or (LocalArgumentSeparator = LocalDecimalSeparator) then
    begin
    if LocalDecimalSeparator = ',' then
      begin
      LocalArgumentSeparator := ';';
      end
    else
      begin
      LocalArgumentSeparator := ',';
      end;
    end;

  InvariantFormat                   := DefaultFormatSettings;
  InvariantFormat.DecimalSeparator  := INVARIANT_DECIMAL_SEPARATOR;
  InvariantFormat.ThousandSeparator := #0;

  LocalGroupSeparator := DefaultFormatSettings.ThousandSeparator;
end;

{ Length of a digit group separator at S[I], 0 if there is none }
function GroupSeparatorLength(const S: String; const I: Integer): Integer;
begin
  case S[I] of
    ',', '.', '''', '_', ' ':
      begin
      Result := 1;
      end;
    #$C2:
      begin
      // no-break space
      if Copy(S, I, 2) = #$C2#$A0 then
        begin
        Result := 2;
        end
      else
        begin
        Result := 0;
        end;
      end;
    #$E2:
      begin
      // narrow no-break space, thin space, right single quotation mark
      if (Copy(S, I, 2) = #$E2#$80) and (I + 2 <= Length(S)) and (S[I + 2] in [#$AF, #$89, #$99]) then
        begin
        Result := 3;
        end
      else
        begin
        Result := 0;
        end;
      end;
    else
      begin
      Result := 0;
      end;
    end;
end;

{ Western: 1,234,567. Indian (lakh, crore): 12,34,567. A leading zero is never grouped. }
function IsValidGrouping(const Groups: TStringArray; const Count: Integer; const Separator: String): Boolean;
var
  I:               Integer;
  Western, Indian: Boolean;
begin
  if Groups[0][1] = '0' then
    begin
    Exit(False);
    end;

  Western := Length(Groups[0]) <= 3;
  for I := 1 to Count - 1 do
    begin
    Western := Western and (Length(Groups[I]) = 3);
    end;

  Indian := (Separator = ',') and (Count >= 3) and (Length(Groups[0]) <= 2) and (Length(Groups[Count - 1]) = 3);
  for I := 1 to Count - 2 do
    begin
    Indian := Indian and (Length(Groups[I]) = 2);
    end;

  Result := Western or Indian;
end;

function JoinGroups(const Groups: TStringArray; const Count: Integer): String;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to Count - 1 do
    begin
    Result := Result + Groups[I];
    end;
end;

{ Groups has one item more than Separators. Returns Original when the format is not recognised. }
function NormalizeNumber(const Groups, Separators: TStringArray; const Original: String): String;
var
  I, Count:     Integer;
  Last:         String;
  SameGrouping: Boolean;
begin
  Result := Original;
  Count  := Length(Separators);
  if Count = 0 then
    begin
    Exit;
    end;

  Last := Separators[Count - 1];
  if (Count = 1) and ((Last = '.') or (Last = ',')) then
    begin
    // 1,234 is grouping only if the locale groups with ',' (like Excel); 1,5 stays as typed
    if (Last = LocalGroupSeparator) and (Length(Groups[1]) = 3) and IsValidGrouping(Groups, 2, Last) then
      begin
      Result := JoinGroups(Groups, 2);
      end;
    Exit;
    end;

  SameGrouping := True;
  for I := 1 to Count - 2 do
    begin
    SameGrouping := SameGrouping and (Separators[I] = Separators[0]);
    end;

  if SameGrouping and ((Last = '.') or (Last = ',')) and (Last <> Separators[0]) then
    begin
    // 1.234.567,89 - the last separator is the decimal one
    if IsValidGrouping(Groups, Count, Separators[0]) then
      begin
      Result := JoinGroups(Groups, Count) + LocalDecimalSeparator + Groups[Count];
      end;
    end
  else if SameGrouping and (Last = Separators[0]) and IsValidGrouping(Groups, Count + 1, Last) then
      begin
      Result := JoinGroups(Groups, Count + 1);
      end;
end;

{================ Interface routines ==============}

{ A '.' typed in a ',' locale stays '.', so it is accepted as a decimal point }
function ToInvariant(const Text: String): String;
var
  I: Integer;
begin
  Result := Text;
  if IsInvariantLocale then
    begin
    Exit;
    end;

  UniqueString(Result);
  for I := 1 to Length(Result) do
    begin
    if Result[I] = LocalDecimalSeparator then
      begin
      Result[I] := INVARIANT_DECIMAL_SEPARATOR;
      end
    else if Result[I] = LocalArgumentSeparator then
        begin
        Result[I] := INVARIANT_ARGUMENT_SEPARATOR;
        end;
    end;
end;

function ToLocal(const Text: String): String;
var
  I: Integer;
begin
  Result := Text;
  if IsInvariantLocale then
    begin
    Exit;
    end;

  UniqueString(Result);
  for I := 1 to Length(Result) do
    begin
    if Result[I] = INVARIANT_DECIMAL_SEPARATOR then
      begin
      Result[I] := LocalDecimalSeparator;
      end
    else if Result[I] = INVARIANT_ARGUMENT_SEPARATOR then
        begin
        Result[I] := LocalArgumentSeparator;
        end;
    end;
end;

function FormatNumber(const Value: Double): String;
begin
  Result := ToLocal(FloatToStr(Value, InvariantFormat));
end;

function ParseNumber(const Text: String): Double;
begin
  Result := StrToFloat(ToInvariant(Text), InvariantFormat);
end;

function TryParseNumber(const Text: String; out Value: Double): Boolean;
begin
  Result := TryStrToFloat(ToInvariant(Text), Value, InvariantFormat);
end;

function NormalizePastedText(const Text: String): String;
const
  DIGITS           = ['0'..'9'];
  IDENTIFIER_START = ['A'..'Z', 'a'..'z', '_'];
  IDENTIFIER_CHARS = IDENTIFIER_START + DIGITS;
var
  S:                      String;
  I, Start, SeparatorLen: Integer;
  Groups, Separators:     TStringArray;
begin
  S      := Trim(StringReplace(StringReplace(StringReplace(Text, #13, ' ', [rfReplaceAll]), #10, ' ', [rfReplaceAll]),
    #9, ' ', [rfReplaceAll]));
  Result := '';
  I      := 1;
  while I <= Length(S) do
    begin
    Start := I;
    if S[I] in IDENTIFIER_START then
      begin
      // digits inside a name such as x1 are not a number
      while (I <= Length(S)) and (S[I] in IDENTIFIER_CHARS) do
        begin
        Inc(I);
        end;
      Result := Result + Copy(S, Start, I - Start);
      end
    else if S[I] in DIGITS then
        begin
        Groups     := nil;
        Separators := nil;
        repeat
          SetLength(Groups, Length(Groups) + 1);
          Groups[High(Groups)] := '';
          while (I <= Length(S)) and (S[I] in DIGITS) do
            begin
            Groups[High(Groups)] := Groups[High(Groups)] + S[I];
            Inc(I);
            end;

          SeparatorLen := 0;
          if I <= Length(S) then
            begin
            SeparatorLen := GroupSeparatorLength(S, I);
            end;
          if (SeparatorLen > 0) and (I + SeparatorLen <= Length(S)) and (S[I + SeparatorLen] in DIGITS) then
            begin
            SetLength(Separators, Length(Separators) + 1);
            Separators[High(Separators)] := Copy(S, I, SeparatorLen);
            Inc(I, SeparatorLen);
            end
          else
            begin
            SeparatorLen := 0;
            end;
        until SeparatorLen = 0;
        Result := Result + NormalizeNumber(Groups, Separators, Copy(S, Start, I - Start));
        end
      else
        begin
        Result := Result + S[I];
        Inc(I);
        end;
    end;
end;

initialization
  ReadLocale;

end.
