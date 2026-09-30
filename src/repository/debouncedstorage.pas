unit DebouncedStorage;

{$mode ObjFPC}
{$H+}
{$inline ON}

interface

uses
  Types, Grids, ExtCtrls, Config, Storage;

type
  TDebouncedStorage = class(TInterfacedObject, IStorage)
  private
    FStorage:            IStorage;
    FDebounceTimer:      TTimer;
    FPendingWindowPos:   TPoint;
    FLastSavedWindowPos: TPoint;
    FPendingWorkspace:   TWorkspaceState;
    FLastSavedWorkspace: TWorkspaceState;
    FWorkspaceDirty:     Boolean;

    procedure OnDebounceTimer(Sender: TObject);
    procedure WritePendingWindowPos;
    procedure WritePendingWorkspace;
  public
    constructor Create(AStorage: IStorage);
    destructor Destroy; override;

    procedure SaveGridToDataFile(const Grid: TStringGrid; const DataFile: TDataFile);
    procedure LoadGridFromDataFile(Grid: TStringGrid; const DataFile: TDataFile);

    procedure SaveWorkspace(const VarName, Expression: String; const Force: Boolean = False);
    function LoadWorkspace: TWorkspaceState;

    procedure SaveWindowPos(const Pos: TPoint; const Force: Boolean = False);
    function LoadWindowPos: TPoint;
  end;

implementation

uses
  SysUtils;

const
  DEBOUNCE_INTERVAL = 1000; // milliseconds

  {================ Private methods =================}

procedure TDebouncedStorage.OnDebounceTimer(Sender: TObject);
begin
  FDebounceTimer.Enabled := False;

  WritePendingWindowPos;
  WritePendingWorkspace;
end;

procedure TDebouncedStorage.WritePendingWindowPos;
begin
  if (FPendingWindowPos.X <> FLastSavedWindowPos.X) or
     (FPendingWindowPos.Y <> FLastSavedWindowPos.Y) then
    begin
    FStorage.SaveWindowPos(FPendingWindowPos);
    FLastSavedWindowPos := FPendingWindowPos;
    end;
end;

procedure TDebouncedStorage.WritePendingWorkspace;
begin
  if FWorkspaceDirty then
    begin
    if (FPendingWorkspace.VarName <> FLastSavedWorkspace.VarName) or
       (FPendingWorkspace.Expression <> FLastSavedWorkspace.Expression) then
      begin
      FStorage.SaveWorkspace(FPendingWorkspace.VarName, FPendingWorkspace.Expression);
      FLastSavedWorkspace := FPendingWorkspace;
      end;
    FWorkspaceDirty := False;
    end;
end;

{================ Interface methods ===============}

constructor TDebouncedStorage.Create(AStorage: IStorage);
begin
  inherited Create;

  FStorage := AStorage;

  FDebounceTimer          := TTimer.Create(nil);
  FDebounceTimer.Interval := DEBOUNCE_INTERVAL;
  FDebounceTimer.OnTimer  := @OnDebounceTimer;
  FDebounceTimer.Enabled  := False;
end;

destructor TDebouncedStorage.Destroy;
begin
  FreeAndNil(FDebounceTimer);
  FStorage := nil;

  inherited Destroy;
end;

procedure TDebouncedStorage.SaveGridToDataFile(const Grid: TStringGrid; const DataFile: TDataFile);
begin
  FStorage.SaveGridToDataFile(Grid, DataFile);
end;

procedure TDebouncedStorage.LoadGridFromDataFile(Grid: TStringGrid; const DataFile: TDataFile);
begin
  FStorage.LoadGridFromDataFile(Grid, DataFile);
end;

procedure TDebouncedStorage.SaveWorkspace(const VarName, Expression: String; const Force: Boolean);
begin
  FPendingWorkspace.VarName    := VarName;
  FPendingWorkspace.Expression := Expression;
  FWorkspaceDirty              := True;

  if Force then
    begin
    WritePendingWorkspace;
    end
  else
    begin
    if not FDebounceTimer.Enabled then
      begin
      FDebounceTimer.Enabled := True;
      end;
    end;
end;

function TDebouncedStorage.LoadWorkspace: TWorkspaceState;
begin
  Result := FStorage.LoadWorkspace;

  FPendingWorkspace   := Result;
  FLastSavedWorkspace := Result;
  FWorkspaceDirty     := False;
end;

procedure TDebouncedStorage.SaveWindowPos(const Pos: TPoint; const Force: Boolean);
begin
  if Force then
    begin
    FPendingWindowPos := Pos;
    WritePendingWindowPos;
    end
  else
    begin
    if (Pos.X <> FPendingWindowPos.X) or (Pos.Y <> FPendingWindowPos.Y) then
      begin
      FPendingWindowPos := Pos;
      if not FDebounceTimer.Enabled then
        begin
        FDebounceTimer.Enabled := True;
        end;
      end;
    end;
end;

function TDebouncedStorage.LoadWindowPos: TPoint;
begin
  Result := FStorage.LoadWindowPos;

  FPendingWindowPos   := Result;
  FLastSavedWindowPos := Result;
end;

end.
