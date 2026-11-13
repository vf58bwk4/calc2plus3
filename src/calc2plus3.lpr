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
  MainForm;

  {$R *.res}

begin
  if AppWideLock.CreateLock(APP_WIDE_LOCK_NAME) then
    begin
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
