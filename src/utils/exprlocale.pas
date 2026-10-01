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

implementation

uses
  SysUtils;

const
  INVARIANT_DECIMAL_SEPARATOR  = '.';
  INVARIANT_ARGUMENT_SEPARATOR = ',';

var
  LocalDecimalSeparator:  Char;
  LocalArgumentSeparator: Char;
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

initialization
  ReadLocale;

end.
