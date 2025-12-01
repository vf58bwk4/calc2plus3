unit AppWideLock;

{$mode objfpc}
{$modeswitch nestedprocvars}
{$H+}
{$inline ON}

interface

function CreateLock(const Name: Pchar): Boolean;
procedure DropLock;

implementation

uses
  Windows;

var
  AppMutex: THandle;

function CreateLock(const Name: Pchar): Boolean;
begin
  AppMutex := CreateMutex(nil, True, Name);
  Result   := (AppMutex <> 0) and (GetLastError <> ERROR_ALREADY_EXISTS);
end;

procedure DropLock;
begin
  if AppMutex <> 0 then
    begin
    CloseHandle(AppMutex);
    end;
end;

end.
