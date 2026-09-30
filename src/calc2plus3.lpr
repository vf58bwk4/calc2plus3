program Calc2plus3;

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
  MainForm;

  {$R *.res}

const
  AppWideLockName = '58f158a7-f385-43e2-b391-58e3136bec19';

begin
  if AppWideLock.CreateLock(AppWideLockName) then
    begin
    Autorun.RegisterAutoRun(APP_NAME, ParamStr(0));

    Application.Title  := APP_TITLE;
    Application.Scaled := True;

    Application.Initialize;
    Application.CreateForm(TMainForm, MainFormInstance);

    Application.Run;

    MainFormInstance.Free;

    Autorun.UnregisterAutoRun(APP_NAME);
    AppWideLock.DropLock;
    end;
end.
