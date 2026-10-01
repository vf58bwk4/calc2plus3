unit LegacyMigration;

{ One-time move from the old technical name '2plus3' to APP_NAME.
  Can be removed once all installations have been started with the new name. }

{$mode ObjFPC}
{$H+}

interface

procedure MigrateFromLegacyName;

implementation

uses
  SysUtils, Config, DataDir, Autorun, Logger;

const
  LEGACY_APP_NAME = '2plus3';
  LEGACY_DATA_DIR = LEGACY_APP_NAME;

{ Must run before anything writes to the data folder, otherwise the new folder already exists }
procedure MigrateFromLegacyName;
var
  OldDir, NewDir: String;
begin
    try
      begin
      OldDir := GetDataDir(LEGACY_DATA_DIR);
      NewDir := GetDataDir(DATA_DIR);
      if DirectoryExists(OldDir) and not DirectoryExists(NewDir) then
        begin
        if not RenameFile(OldDir, NewDir) then
          begin
          LogWarning(Format('Could not move data folder "%s" to "%s": %s', [OldDir, NewDir, SysErrorMessage(GetLastOSError)]));
          end;
        end;
      end;
    except
    on E: Exception do
      begin
      LogWarning('Could not move data folder: ' + E.ClassName + ': ' + E.Message);
      end;
    end;

  Autorun.UnregisterAutorun(LEGACY_APP_NAME);
end;

end.
