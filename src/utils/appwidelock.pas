unit AppWideLock;

{$mode ObjFPC}
{$modeswitch nestedprocvars}
{$H+}
{$inline ON}

interface

function CreateLock(const Name: PChar): Boolean;
procedure DropLock;

implementation

uses
  Windows;

var
  AppMutex: THandle;

function CreateLock(const Name: PChar): Boolean;
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
