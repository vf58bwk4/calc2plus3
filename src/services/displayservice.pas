unit DisplayService;

{$mode ObjFPC}
{$H+}
{$inline ON}

interface

uses
  ComCtrls;

procedure Initialize(StatusBar: TStatusBar);
procedure StatusOK;
procedure StatusError(const Message: String);
function  FormatNumber(const Value: Double): String;

implementation

uses
  SysUtils;

const
  STATUS_OK           = 'OK';
  STATUS_ERROR_PREFIX = 'ERROR: ';

var
  _StatusBar: TStatusBar;

procedure Initialize(StatusBar: TStatusBar);
begin
  _StatusBar := StatusBar;
end;

procedure StatusOK; inline;
begin
  _StatusBar.SimpleText := STATUS_OK;
end;

procedure StatusError(const Message: String); inline;
begin
  _StatusBar.SimpleText := STATUS_ERROR_PREFIX + Message;
end;

function FormatNumber(const Value: Double): String; inline;
begin
  Result := Value.ToString;
end;

end.
