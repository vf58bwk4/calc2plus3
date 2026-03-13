unit Autorun;

{$mode ObjFPC}
{$H+}

interface

procedure RegisterAutoRun(const AppName, AppPath: String);
procedure UnregisterAutoRun(const AppName: String);

implementation

uses
  Windows, Registry;

const
  AutoRunRegPath = 'Software\Microsoft\Windows\CurrentVersion\Run';

procedure RegisterAutoRun(const AppName, AppPath: String);
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create;
    try
      begin
      Reg.RootKey := HKEY_CURRENT_USER;
      if Reg.OpenKey(AutoRunRegPath, True) then
        begin
        Reg.WriteString(AppName, AppPath);
        Reg.CloseKey;
        end;
      end;
    finally
    Reg.Free;
    end;
end;

procedure UnregisterAutoRun(const AppName: String);
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create;
    try
      begin
      Reg.RootKey := HKEY_CURRENT_USER;
      if Reg.OpenKey(AutoRunRegPath, False) then
        begin
        Reg.DeleteValue(AppName);
        Reg.CloseKey;
        end;
      end;
    finally
    Reg.Free;
    end;
end;

end.
