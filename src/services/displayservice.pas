unit DisplayService;

{$mode ObjFPC}
{$H+}
{$inline ON}

interface

uses
  ComCtrls;

procedure Initialize(AStatusBar: TStatusBar);
procedure StatusOK;
procedure StatusError(const Message: String);
{ Like StatusError, but keeps an error already shown }
procedure AddStatusError(const Message: String);

implementation

uses
  SysUtils;

const
  STATUS_OK           = 'OK';
  STATUS_ERROR_PREFIX = 'ERROR: ';
  ERROR_SEPARATOR     = ' | ';

var StatusBar: TStatusBar;

procedure Initialize(AStatusBar: TStatusBar);
begin
  StatusBar := AStatusBar;
end;

procedure StatusOK;
begin
  StatusBar.SimpleText := STATUS_OK;
end;

procedure StatusError(const Message: String);
begin
  StatusBar.SimpleText := STATUS_ERROR_PREFIX + Message;
end;

procedure AddStatusError(const Message: String);
begin
  if Pos(STATUS_ERROR_PREFIX, StatusBar.SimpleText) = 1 then
    begin
    StatusBar.SimpleText := StatusBar.SimpleText + ERROR_SEPARATOR + Message;
    end
  else
    begin
    StatusError(Message);
    end;
end;

end.
