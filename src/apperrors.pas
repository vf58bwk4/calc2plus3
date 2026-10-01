unit AppErrors;

{$mode ObjFPC}
{$H+}
{$inline ON}

interface

uses
  SysUtils;

type
  // An expected failure: its message is meant for the user and is shown as is
  EAppError     = class(Exception);
  EInputError   = class(EAppError);
  EStorageError = class(EAppError);

// Logs E if it is unexpected and returns the text to show to the user
function ReportError(const E: Exception): String;

implementation

uses
  FPExprPars, Logger;

// The message of an expected error is enough for the user; anything else is a bug
function IsExpectedError(const E: Exception): Boolean;
begin
  Result := (E is EAppError) or (E is EExprParser) or (E is EExprScanner) or (E is EMathError) or (E is EDivByZero);
end;

function ReportError(const E: Exception): String;
begin
  if IsExpectedError(E) then
    begin
    Result := E.Message;
    end
  else
    begin
    LogError(E.ClassName + ': ' + E.Message);
    Result := 'Unexpected: ' + E.ClassName + ': ' + E.Message;
    end;
end;

end.
