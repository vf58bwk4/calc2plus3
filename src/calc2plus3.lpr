program Calc2plus3;

{$mode ObjFPC}
{$H+}
{$modeswitch nestedprocvars}
{$inline ON}

uses
  Forms,
  Interfaces,
  AppWideLock,
  MainForm;

  {$R *.res}

const
  AppWideLockName = 'e045ebf8-d1c3-4572-ad38-64c3105ea46b';
  AppTitle        = '2 + 3';

begin
  if not AppWideLock.CreateLock(AppWideLockName) then
    begin
    Exit;
    end;

  Application.Title  := AppTitle;
  Application.Scaled := True;

  Application.Initialize;
  Application.CreateForm(TCalculator, Calculator);

  Application.Run;

  AppWideLock.DropLock;
end.
