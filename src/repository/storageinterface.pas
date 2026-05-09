unit StorageInterface;

{$mode ObjFPC}
{$H+}
{$inline ON}

interface

uses
  Types, Grids, Config;

type
  TWorkspaceState = record
    VarName:    String;
    Expression: String;
  end;

function MakeWorkspaceState(const VarName, Expression: String): TWorkspaceState;

type
  IStorage = interface
    function LoadWindowPos: TPoint;
    function LoadWorkspace: TWorkspaceState;

    procedure SaveWorkspace(const VarName, Expression: String);
    procedure SaveWindowPos(const Pos: TPoint);

    procedure SaveGridToDataFile(const Grid: TStringGrid; const DataFile: TDataFile);
    procedure LoadGridFromDataFile(Grid: TStringGrid; const DataFile: TDataFile);
  end;

implementation

function MakeWorkspaceState(const VarName, Expression: String): TWorkspaceState;
begin
  Result.VarName    := VarName;
  Result.Expression := Expression;
end;


end.
