unit Autorun;

{$mode ObjFPC}
{$H+}

interface

procedure RegisterAutorun(const AppName, AppPath: String);
procedure UnregisterAutorun(const AppName: String);

implementation

uses
  Windows, Registry;

const
  AUTORUN_REG_PATH = 'Software\Microsoft\Windows\CurrentVersion\Run';

procedure RegisterAutorun(const AppName, AppPath: String);
var
  Reg: TRegistry;
begin
    try
    Reg := TRegistry.Create;
      try
      Reg.RootKey := HKEY_CURRENT_USER;
      if Reg.OpenKey(AUTORUN_REG_PATH, True) then
        begin
        Reg.WriteString(AppName, AppPath);
        Reg.CloseKey;
        end;
      finally
      Reg.Free;
      end;
    except
    end;
end;

procedure UnregisterAutorun(const AppName: String);
var
  Reg: TRegistry;
begin
    try
    Reg := TRegistry.Create;
      try
      Reg.RootKey := HKEY_CURRENT_USER;
      if Reg.OpenKey(AUTORUN_REG_PATH, False) then
        begin
        Reg.DeleteValue(AppName);
        Reg.CloseKey;
        end;
      finally
      Reg.Free;
      end;
    except
    end;
end;

end.
