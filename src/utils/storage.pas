unit Storage;

{$mode ObjFPC}
{$H+}
{$inline ON}

interface

uses
  Types, Grids, Config, Classes, ExtCtrls;

type
  TWorkspaceState = record
    VarName:    String;
    Expression: String;
  end;

function ForceDataDir(const Dir: String): String;

procedure SaveGridToDataFile(const Grid: TStringGrid; const DataFile: TDataFile);
procedure LoadGridFromDataFile(Grid: TStringGrid; const DataFile: TDataFile);

procedure SaveWorkspace(const VarName, Expression: String);
function LoadWorkspace: TWorkspaceState;

procedure SaveWorkspaceDebounced(const VarName, Expression: String);

procedure SaveWindowPos(const Pos: TPoint);
function LoadWindowPos: TPoint;

procedure InitializeWindowPosDebouncing;
procedure FinalizeWindowPosDebouncing;

implementation

uses
  SysUtils, Windows, ShlObj, CsvDocument;

const
  CSV_DELIMITER = '|';
  DEBOUNCE_INTERVAL = 1000; // milliseconds

type
  TDebounceHelper = class
    procedure OnTimer(Sender: TObject);
  end;

var
  _DebounceTimer: TTimer;
  _DebounceHelper: TDebounceHelper;
  _PendingWindowPos: TPoint;
  _LastSavedWindowPos: TPoint;
  _PendingWorkspace: TWorkspaceState;
  _LastSavedWorkspace: TWorkspaceState;
  _WorkspaceDirty: Boolean;

procedure _WriteWindowPos(const Pos: TPoint); forward;
procedure _WriteWorkspace(const VarName, Expression: String); forward;

procedure TDebounceHelper.OnTimer(Sender: TObject);
begin
  _DebounceTimer.Enabled := False;

  if (_PendingWindowPos.X <> _LastSavedWindowPos.X) or
     (_PendingWindowPos.Y <> _LastSavedWindowPos.Y) then
    begin
    _WriteWindowPos(_PendingWindowPos);
    _LastSavedWindowPos := _PendingWindowPos;
    end;

  if _WorkspaceDirty then
    begin
    if (_PendingWorkspace.VarName <> _LastSavedWorkspace.VarName) or
       (_PendingWorkspace.Expression <> _LastSavedWorkspace.Expression) then
      begin
      _WriteWorkspace(_PendingWorkspace.VarName, _PendingWorkspace.Expression);
      _LastSavedWorkspace := _PendingWorkspace;
      end;
    _WorkspaceDirty := False;
    end;
end;

function GetDataDir(const Dir: String): String;
var
  Path:    array[0..MAX_PATH] of Char;
  BaseDir: String;
begin
  if SHGetFolderPath(0, CSIDL_APPDATA, 0, 0, Path) <> S_OK then
    begin
    raise Exception.CreateFmt('Could not get AppData\Roaming folder (error %d)', [GetLastError]);
    end;

  BaseDir := IncludeTrailingPathDelimiter(Path);
  Result  := BaseDir + Dir;
end;

function ForceDataDir(const Dir: String): String;
var
  DataDir: String;
begin
  DataDir := GetDataDir(Dir);
  if not DirectoryExists(DataDir) then
    begin
    if not ForceDirectories(DataDir) then
      begin
      raise Exception.Create('Could not create directory: ' + DataDir);
      end;
    end;
  Result := DataDir;
end;

procedure SaveGridToDataFile(const Grid: TStringGrid; const DataFile: TDataFile);
var
  PathFilename: String;
  TmpFile:      String;
  CSV:          TCSVDocument;
  Row, Col:     Integer;
begin
  PathFilename := ForceDataDir(DataFile.Dirname) + '\' + DataFile.Filename;
  TmpFile      := PathFilename + '.tmp';

  CSV           := TCSVDocument.Create;
  CSV.Delimiter := CSV_DELIMITER;
    try
      try
        begin
        for Row := 0 to Grid.RowCount - Grid.FixedRows - 1 do
          begin
          for Col := 0 to Grid.ColCount - Grid.FixedCols - 1 do
            begin
            CSV.Cells[Col, Row] := Grid.Cells[Grid.FixedCols + Col, Grid.FixedRows + Row];
            end;
          end;
        CSV.SaveToFile(TmpFile);
        end;
      finally
        begin
        CSV.Free;
        end;
      end;
    except
      begin
      raise Exception.CreateFmt('Could not save file "%s" (error %d)', [DataFile.Filename, GetLastError]);
      end;
    end;

  if not MoveFileEx(PChar(TmpFile), PChar(PathFilename), MOVEFILE_REPLACE_EXISTING) then
    begin
    SysUtils.DeleteFile(TmpFile);
    raise Exception.CreateFmt('Could not save file "%s" (error %d)', [DataFile.Filename, GetLastError]);
    end;
end;

procedure LoadGridFromDataFile(Grid: TStringGrid; const DataFile: TDataFile);
var
  PathFilename: String;
  CSV:          TCSVDocument;
  Row, Col:     Integer;
begin
  PathFilename := GetDataDir(DataFile.Dirname) + '\' + DataFile.Filename;

  // Clean up any stale temp file left by a previous crashed save
  SysUtils.DeleteFile(PathFilename + '.tmp');

  if FileExists(PathFilename) then
    begin
    CSV           := TCSVDocument.Create;
    CSV.Delimiter := CSV_DELIMITER;
      try
        try
          begin
          CSV.LoadFromFile(PathFilename);
          Grid.RowCount := Grid.FixedRows + CSV.RowCount;
          for Row := 0 to CSV.RowCount - 1 do
            begin
            for Col := 0 to CSV.ColCount[Row] - 1 do
              begin
              Grid.Cells[Grid.FixedCols + Col, Grid.FixedRows + Row] := CSV.Cells[Col, Row];
              end;
            end;
          end;
        finally
          begin
          CSV.Free;
          end;
        end;
      except
        begin
        raise Exception.CreateFmt('Could not load file "%s" (error %d)', [DataFile.Filename, GetLastError]);
        end;
      end;
    end;
end;

const
  CSV_COL: record
      Key:   Byte;
      Value: Byte;
      end
  = (Key: 0; Value: 1);

  WORKSPACE_ROWS: record
      VarName:    Byte;
      Expression: Byte;
      end
  = (VarName: 0; Expression: 1);

  WINPOS_ROWS: record
      Left: Byte;
      Top:  Byte;
      end
  = (Left: 0; Top: 1);

procedure SaveWorkspace(const VarName, Expression: String);
begin
  SaveWorkspaceDebounced(VarName, Expression);
end;

procedure SaveWorkspaceDebounced(const VarName, Expression: String);
begin
  _PendingWorkspace.VarName := VarName;
  _PendingWorkspace.Expression := Expression;
  _WorkspaceDirty := True;

  if not _DebounceTimer.Enabled then
    _DebounceTimer.Enabled := True;
end;

function LoadWorkspace: TWorkspaceState;
var
  DataFile:     TDataFile;
  PathFilename: String;
  CSV:          TCSVDocument;
begin
  DataFile          := WORKSPACE_FILE;
  Result.VarName    := '';
  Result.Expression := '';

  PathFilename := GetDataDir(DataFile.Dirname) + '\' + DataFile.Filename;

  // Clean up any stale temp file from a previous crashed save
  SysUtils.DeleteFile(PathFilename + '.tmp');

  if SysUtils.FileExists(PathFilename) then
    begin
    CSV           := TCSVDocument.Create;
    CSV.Delimiter := CSV_DELIMITER;
      try
        try
          begin
          CSV.LoadFromFile(PathFilename);
          if CSV.RowCount > WORKSPACE_ROWS.VarName then
            begin
            Result.VarName := CSV.Cells[CSV_COL.Value, WORKSPACE_ROWS.VarName];
            end;
          if CSV.RowCount > WORKSPACE_ROWS.Expression then
            begin
            Result.Expression := CSV.Cells[CSV_COL.Value, WORKSPACE_ROWS.Expression];
            end;
          end;
        finally
          begin
          CSV.Free;
          end;
        end;
      except
        begin
        raise Exception.CreateFmt('Could not load file "%s" (error %d)', [DataFile.Filename, GetLastError]);
        end;
      end;
    end;
end;

procedure SaveWindowPos(const Pos: TPoint);
begin
  if (Pos.X <> _PendingWindowPos.X) or (Pos.Y <> _PendingWindowPos.Y) then
    begin
    _PendingWindowPos := Pos;
    if not _DebounceTimer.Enabled then
      _DebounceTimer.Enabled := True;
    end;
end;

function LoadWindowPos: TPoint;
var
  DataFile:     TDataFile;
  PathFilename: String;
  CSV:          TCSVDocument;
begin
  DataFile := WINPOS_FILE;
  Result.X := 0;
  Result.Y := 0;

  PathFilename := GetDataDir(DataFile.Dirname) + '\' + DataFile.Filename;

  // Clean up any stale temp file from a previous crashed save
  SysUtils.DeleteFile(PathFilename + '.tmp');

  if SysUtils.FileExists(PathFilename) then
    begin
    CSV           := TCSVDocument.Create;
    CSV.Delimiter := CSV_DELIMITER;
      try
        try
          begin
          CSV.LoadFromFile(PathFilename);
          if CSV.RowCount > WINPOS_ROWS.Left then
            begin
            Result.X := StrToIntDef(CSV.Cells[CSV_COL.Value, WINPOS_ROWS.Left], 0);
            end;
          if CSV.RowCount > WINPOS_ROWS.Top then
            begin
            Result.Y := StrToIntDef(CSV.Cells[CSV_COL.Value, WINPOS_ROWS.Top], 0);
            end;
          end;
        finally
          begin
          CSV.Free;
          end;
        end;
      except
        begin
        raise Exception.CreateFmt('Could not load file "%s" (error %d)', [DataFile.Filename, GetLastError]);
        end;
      end;
    end;
end;

procedure _WriteWindowPos(const Pos: TPoint);
var
  DataFile:     TDataFile;
  CSV:          TCSVDocument;
  PathFilename: String;
  TmpFilename:  String;
begin
  DataFile := WINPOS_FILE;

  PathFilename := ForceDataDir(DataFile.Dirname) + '\' + DataFile.Filename;
  TmpFilename  := PathFilename + '.tmp';

  CSV           := TCSVDocument.Create;
  CSV.Delimiter := CSV_DELIMITER;
    try
      try
        begin
        CSV.Cells[CSV_COL.Key, WINPOS_ROWS.Left]   := 'left';
        CSV.Cells[CSV_COL.Value, WINPOS_ROWS.Left] := IntToStr(Pos.X);
        CSV.Cells[CSV_COL.Key, WINPOS_ROWS.Top]    := 'top';
        CSV.Cells[CSV_COL.Value, WINPOS_ROWS.Top]  := IntToStr(Pos.Y);
        CSV.SaveToFile(TmpFilename);
        end;
      finally
        begin
        CSV.Free;
        end;
      end;
    except
      begin
      raise Exception.CreateFmt('Could not save file "%s" (error %d)', [DataFile.Filename, GetLastError]);
      end;
    end;

  if not MoveFileEx(PChar(TmpFilename), PChar(PathFilename), MOVEFILE_REPLACE_EXISTING) then
    begin
    SysUtils.DeleteFile(TmpFilename);
    raise Exception.CreateFmt('Could not save file "%s" (error %d)', [DataFile.Filename, GetLastError]);
    end;
end;

procedure _WriteWorkspace(const VarName, Expression: String);
var
  DataFile:     TDataFile;
  CSV:          TCSVDocument;
  PathFilename: String;
  TmpFilename:  String;
begin
  DataFile     := WORKSPACE_FILE;
  PathFilename := ForceDataDir(DataFile.Dirname) + '\' + DataFile.Filename;
  TmpFilename  := PathFilename + '.tmp';

  CSV           := TCSVDocument.Create;
  CSV.Delimiter := CSV_DELIMITER;
    try
      try
        begin
        CSV.Cells[CSV_COL.Key, WORKSPACE_ROWS.VarName]      := 'varname';
        CSV.Cells[CSV_COL.Value, WORKSPACE_ROWS.VarName]    := VarName;
        CSV.Cells[CSV_COL.Key, WORKSPACE_ROWS.Expression]   := 'expression';
        CSV.Cells[CSV_COL.Value, WORKSPACE_ROWS.Expression] := Expression;
        CSV.SaveToFile(TmpFilename);
        end;
      finally
        begin
        CSV.Free;
        end;
      end;
    except
      begin
      raise Exception.CreateFmt('Could not save file "%s" (error %d)', [DataFile.Filename, GetLastError]);
      end;
    end;

  if not MoveFileEx(PChar(TmpFilename), PChar(PathFilename), MOVEFILE_REPLACE_EXISTING) then
    begin
    SysUtils.DeleteFile(TmpFilename);
    raise Exception.CreateFmt('Could not save file "%s" (error %d)', [DataFile.Filename, GetLastError]);
    end;
end;

procedure InitializeWindowPosDebouncing;
var
  Workspace: TWorkspaceState;
begin
  if _DebounceHelper = nil then
    _DebounceHelper := TDebounceHelper.Create;

  _DebounceTimer := TTimer.Create(nil);
  _DebounceTimer.Interval := DEBOUNCE_INTERVAL;
  _DebounceTimer.OnTimer := @_DebounceHelper.OnTimer;
  _DebounceTimer.Enabled := False;

  _PendingWindowPos := TPoint.Create(0, 0);
  _LastSavedWindowPos := TPoint.Create(0, 0);

  // Initialize workspace buffers
  Workspace := LoadWorkspace;
  _PendingWorkspace := Workspace;
  _LastSavedWorkspace := Workspace;
  _WorkspaceDirty := False;
end;

procedure FinalizeWindowPosDebouncing;
begin
  if _DebounceTimer <> nil then
    begin
    if _DebounceTimer.Enabled then
      _DebounceTimer.Enabled := False;

    if (_PendingWindowPos.X <> _LastSavedWindowPos.X) or
       (_PendingWindowPos.Y <> _LastSavedWindowPos.Y) then
      begin
      _WriteWindowPos(_PendingWindowPos);
      end;

    if _WorkspaceDirty then
      begin
      if (_PendingWorkspace.VarName <> _LastSavedWorkspace.VarName) or
         (_PendingWorkspace.Expression <> _LastSavedWorkspace.Expression) then
        begin
        _WriteWorkspace(_PendingWorkspace.VarName, _PendingWorkspace.Expression);
        end;
      end;

    FreeAndNil(_DebounceTimer);
    end;

  if _DebounceHelper <> nil then
    FreeAndNil(_DebounceHelper);
end;

end.
