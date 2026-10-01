unit DebouncedStorage;

{$mode ObjFPC}
{$H+}
{$inline ON}

interface

uses
  Grids, ExtCtrls, Config, Storage;

type
  TDebouncedStorage = class(TInterfacedObject, IStorage)
  private
    FStorage:              IStorage;
    FDebounceTimer:        TTimer;
    FPendingWindowState:   TMainWindowState;
    FLastSavedWindowState: TMainWindowState;
    FPendingWorkspace:     TWorkspaceState;
    FLastSavedWorkspace:   TWorkspaceState;
    FWorkspaceDirty:       Boolean;

    procedure DebounceTimerTimer(Sender: TObject);
    procedure WritePendingWindowState;
    procedure WritePendingWorkspace;
  public
    constructor Create(AStorage: IStorage);
    destructor Destroy; override;

    procedure SaveGridToDataFile(const Grid: TStringGrid; const DataFile: TDataFile; const ConvertCell: TCellConverter);
    procedure LoadGridFromDataFile(Grid: TStringGrid; const DataFile: TDataFile; const ConvertCell: TCellConverter);

    procedure SaveWorkspace(const VarName, Expression: String; const Force: Boolean = False);
    function LoadWorkspace: TWorkspaceState;

    procedure SaveWindowState(const State: TMainWindowState; const Force: Boolean = False);
    function LoadWindowState: TMainWindowState;
  end;

implementation

uses
  SysUtils;

const
  DEBOUNCE_INTERVAL = 1000; // milliseconds

  {================ Private methods =================}

function SameWindowState(const A, B: TMainWindowState): Boolean; inline;
begin
  Result := (A.Left = B.Left) and (A.Top = B.Top) and (A.Visible = B.Visible);
end;

procedure TDebouncedStorage.DebounceTimerTimer(Sender: TObject);
begin
  FDebounceTimer.Enabled := False;

    try
      begin
      WritePendingWindowState;
      end;
    finally
      begin
      WritePendingWorkspace;
      end;
    end;
end;

procedure TDebouncedStorage.WritePendingWindowState;
begin
  if not SameWindowState(FPendingWindowState, FLastSavedWindowState) then
    begin
    FStorage.SaveWindowState(FPendingWindowState);
    FLastSavedWindowState := FPendingWindowState;
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
  FDebounceTimer.OnTimer  := @DebounceTimerTimer;
  FDebounceTimer.Enabled  := False;
end;

destructor TDebouncedStorage.Destroy;
begin
  FreeAndNil(FDebounceTimer);
  FStorage := nil;

  inherited Destroy;
end;

procedure TDebouncedStorage.SaveGridToDataFile(const Grid: TStringGrid; const DataFile: TDataFile; const ConvertCell: TCellConverter);
begin
  FStorage.SaveGridToDataFile(Grid, DataFile, ConvertCell);
end;

procedure TDebouncedStorage.LoadGridFromDataFile(Grid: TStringGrid; const DataFile: TDataFile; const ConvertCell: TCellConverter);
begin
  FStorage.LoadGridFromDataFile(Grid, DataFile, ConvertCell);
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

procedure TDebouncedStorage.SaveWindowState(const State: TMainWindowState; const Force: Boolean);
begin
  if Force then
    begin
    FPendingWindowState := State;
    WritePendingWindowState;
    end
  else
    begin
    if not SameWindowState(State, FPendingWindowState) then
      begin
      FPendingWindowState := State;
      if not FDebounceTimer.Enabled then
        begin
        FDebounceTimer.Enabled := True;
        end;
      end;
    end;
end;

function TDebouncedStorage.LoadWindowState: TMainWindowState;
begin
  Result := FStorage.LoadWindowState;

  FPendingWindowState   := Result;
  FLastSavedWindowState := Result;
end;

end.
