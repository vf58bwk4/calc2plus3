unit Autorun;

{$mode ObjFPC}
{$H+}

interface

procedure RegisterAutorun(const AppName, AppPath: String);
procedure UnregisterAutorun(const AppName: String);

implementation

uses
  SysUtils, Registry, Logger;

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
        end
      else
        begin
        LogWarning('Could not register autorun: cannot open HKCU\' + AUTORUN_REG_PATH);
        end;
      finally
      Reg.Free;
      end;
    except
    on E: Exception do
      begin
      LogWarning('Could not register autorun: ' + E.ClassName + ': ' + E.Message);
      end;
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
    on E: Exception do
      begin
      LogWarning('Could not unregister autorun: ' + E.ClassName + ': ' + E.Message);
      end;
    end;
end;

end.
