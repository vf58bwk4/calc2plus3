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

implementation

uses
  SysUtils;

const
  STATUS_OK           = 'OK';
  STATUS_ERROR_PREFIX = 'ERROR: ';

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

end.
