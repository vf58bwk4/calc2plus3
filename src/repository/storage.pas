unit Storage;

{$mode ObjFPC}
{$H+}
{$inline ON}

interface

uses
  Grids, Config;

type
  TWorkspaceState = record
    VarName:    String;
    Expression: String;
  end;

  TMainWindowState = record
    Left, Top: Integer;
    Visible:   Boolean;
  end;

  { Applied to every cell: on save from grid to file, on load from file to grid }
  TCellConverter = function(const Text: String): String;

  IStorage = interface
    procedure SaveGridToDataFile(const Grid: TStringGrid; const DataFile: TDataFile; const ConvertCell: TCellConverter);
    procedure LoadGridFromDataFile(Grid: TStringGrid; const DataFile: TDataFile; const ConvertCell: TCellConverter);

    procedure SaveWorkspace(const VarName, Expression: String; const Force: Boolean = False);
    function LoadWorkspace: TWorkspaceState;

    procedure SaveWindowState(const State: TMainWindowState; const Force: Boolean = False);
    function LoadWindowState: TMainWindowState;
  end;

procedure Initialize;
procedure Finalize;

procedure SaveGridToDataFile(const Grid: TStringGrid; const DataFile: TDataFile; const ConvertCell: TCellConverter);
procedure LoadGridFromDataFile(Grid: TStringGrid; const DataFile: TDataFile; const ConvertCell: TCellConverter);

procedure SaveWorkspace(const VarName, Expression: String; const Force: Boolean = False);
function LoadWorkspace: TWorkspaceState;

procedure SaveWindowState(const State: TMainWindowState; const Force: Boolean = False);
function LoadWindowState: TMainWindowState;

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

procedure SaveGridToDataFile(const Grid: TStringGrid; const DataFile: TDataFile; const ConvertCell: TCellConverter);
begin
  _Storage.SaveGridToDataFile(Grid, DataFile, ConvertCell);
end;

procedure LoadGridFromDataFile(Grid: TStringGrid; const DataFile: TDataFile; const ConvertCell: TCellConverter);
begin
  _Storage.LoadGridFromDataFile(Grid, DataFile, ConvertCell);
end;

procedure SaveWorkspace(const VarName, Expression: String; const Force: Boolean);
begin
  _Storage.SaveWorkspace(VarName, Expression, Force);
end;

function LoadWorkspace: TWorkspaceState;
begin
  Result := _Storage.LoadWorkspace;
end;

procedure SaveWindowState(const State: TMainWindowState; const Force: Boolean);
begin
  _Storage.SaveWindowState(State, Force);
end;

function LoadWindowState: TMainWindowState;
begin
  Result := _Storage.LoadWindowState;
end;

end.
