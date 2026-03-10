unit WorkspaceController;

{$mode ObjFPC}
{$H+}
{$inline ON}

interface

uses
  MainForm;

procedure Initialize(const F: TCalculator);
procedure SaveWorkspace(const VarNameText, ExpressionText: String);
procedure SaveWindowPos(const F: TCalculator);

implementation

uses
  SysUtils, Types, Workspace,
  DisplayService, HistoryService, VariableService;

procedure Initialize(const F: TCalculator);
var
  WS: TWorkspaceState;
  WP: TRect;
begin
  DisplayService.Initialize(F.StatusBar);
  HistoryService.Initialize(F.History);
  VariableService.Initialize(F.VarList);

  WS              := Workspace.LoadWorkspace;
  F.VarName.Text  := WS.VarName;
  F.Expression.Text := WS.Expression;

  WP := Workspace.AdjustWindowPos(Workspace.LoadWindowPos);
  if (WP.Right > WP.Left) and (WP.Bottom > WP.Top) then
    begin
    F.BoundsRect := WP;
    end;
end;

procedure SaveWorkspace(const VarNameText, ExpressionText: String);
begin
  Workspace.SaveWorkspace(VarNameText, ExpressionText);
end;

procedure SaveWindowPos(const F: TCalculator);
begin
  Workspace.SaveWindowPos(F.BoundsRect);
end;

end.
