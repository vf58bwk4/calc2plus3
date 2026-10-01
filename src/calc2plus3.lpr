program Calc2Plus3;

{$mode ObjFPC}
{$H+}
{$modeswitch nestedprocvars}
{$inline ON}

uses
  Forms,
  Interfaces,
  Config,
  AppWideLock,
  Autorun,
  LegacyMigration,
  MainForm;

  {$R *.res}

const
  APP_WIDE_LOCK_NAME = '58f158a7-f385-43e2-b391-58e3136bec19';

begin
  if AppWideLock.CreateLock(APP_WIDE_LOCK_NAME) then
    begin
    LegacyMigration.MigrateFromLegacyName;
    Autorun.RegisterAutorun(APP_NAME, ParamStr(0));

    Application.Title  := APP_TITLE;
    Application.Scaled := True;

    Application.Initialize;
    Application.CreateForm(TMainForm, MainFormInstance);

    Application.Run;

    MainFormInstance.Free;

    Autorun.UnregisterAutorun(APP_NAME);
    AppWideLock.DropLock;
    end;
end.
