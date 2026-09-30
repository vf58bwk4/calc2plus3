unit Storage;

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

  IStorage = interface
    procedure SaveGridToDataFile(const Grid: TStringGrid; const DataFile: TDataFile);
    procedure LoadGridFromDataFile(Grid: TStringGrid; const DataFile: TDataFile);

    procedure SaveWorkspace(const VarName, Expression: String; const Force: Boolean = False);
    function LoadWorkspace: TWorkspaceState;

    procedure SaveWindowPos(const Pos: TPoint; const Force: Boolean = False);
    function LoadWindowPos: TPoint;
  end;

procedure Initialize;
procedure Finalize;

procedure SaveGridToDataFile(const Grid: TStringGrid; const DataFile: TDataFile);
procedure LoadGridFromDataFile(Grid: TStringGrid; const DataFile: TDataFile);

procedure SaveWorkspace(const VarName, Expression: String; const Force: Boolean = False);
function LoadWorkspace: TWorkspaceState;

procedure SaveWindowPos(const Pos: TPoint; const Force: Boolean = False);
function LoadWindowPos: TPoint;

implementation

uses
  CSVStorage, DebouncedStorage;

var
  _Storage: IStorage;

procedure Initialize;
begin
  _Storage := TDebouncedStorage.Create(TCSVStorage.Create);
end;

procedure Finalize;
begin
  _Storage := nil;
end;

procedure SaveGridToDataFile(const Grid: TStringGrid; const DataFile: TDataFile);
begin
  _Storage.SaveGridToDataFile(Grid, DataFile);
end;

procedure LoadGridFromDataFile(Grid: TStringGrid; const DataFile: TDataFile);
begin
  _Storage.LoadGridFromDataFile(Grid, DataFile);
end;

procedure SaveWorkspace(const VarName, Expression: String; const Force: Boolean);
begin
  _Storage.SaveWorkspace(VarName, Expression, Force);
end;

function LoadWorkspace: TWorkspaceState;
begin
  Result := _Storage.LoadWorkspace;
end;

procedure SaveWindowPos(const Pos: TPoint; const Force: Boolean);
begin
  _Storage.SaveWindowPos(Pos, Force);
end;

function LoadWindowPos: TPoint;
begin
  Result := _Storage.LoadWindowPos;
end;

end.
