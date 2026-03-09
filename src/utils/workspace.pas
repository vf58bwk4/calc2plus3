unit Workspace;

{$mode ObjFPC}
{$H+}
{$inline ON}

interface

type
  TWorkspaceState = record
    VarName:    String;
    Expression: String;
  end;

  TWindowPos = record
    Left:   Integer;
    Top:    Integer;
    Width:  Integer;
    Height: Integer;
  end;

procedure SaveWorkspace(const VarName, Expression: String);
function LoadWorkspace: TWorkspaceState;

procedure SaveWindowPos(const Left, Top, Width, Height: Integer);
function LoadWindowPos: TWindowPos;
function AdjustWindowPos(const WP: TWindowPos): TWindowPos;

implementation

uses
  SysUtils, Windows, Math, Forms, CsvDocument,
  Config, DataDir;

const
  CSV_COL: record
    Key:   Byte;
    Value: Byte;
  end = (Key: 0; Value: 1);

  WORKSPACE_ROWS: record
    VarName:    Byte;
    Expression: Byte;
  end = (VarName: 0; Expression: 1);

  WINPOS_ROWS: record
    Left:   Byte;
    Top:    Byte;
    Width:  Byte;
    Height: Byte;
  end = (Left: 0; Top: 1; Width: 2; Height: 3);

procedure SaveWorkspace(const VarName, Expression: String);
var
  CSV:          TCSVDocument;
  PathFilename: String;
  TmpFilename:  String;
begin
    try
      begin
      PathFilename := ForceDataDir(WORKSPACE_FILE.Dirname) + '\' + WORKSPACE_FILE.Filename;
      TmpFilename  := PathFilename + '.tmp';

      CSV           := TCSVDocument.Create;
      CSV.Delimiter := ',';
        try
          begin
          CSV.Cells[CSV_COL.Key,   WORKSPACE_ROWS.VarName]    := 'varname';
          CSV.Cells[CSV_COL.Value, WORKSPACE_ROWS.VarName]    := VarName;
          CSV.Cells[CSV_COL.Key,   WORKSPACE_ROWS.Expression] := 'expression';
          CSV.Cells[CSV_COL.Value, WORKSPACE_ROWS.Expression] := Expression;
          CSV.SaveToFile(TmpFilename);
          end;
        finally
          begin
          CSV.Free;
          end;
        end;

      if not MoveFileEx(PChar(TmpFilename), PChar(PathFilename), MOVEFILE_REPLACE_EXISTING) then
        begin
        SysUtils.DeleteFile(TmpFilename);
        end;
      end;
    except
      // Save is best-effort; never surface errors to the user
    end;
end;

function LoadWorkspace: TWorkspaceState;
var
  PathFilename: String;
  CSV:          TCSVDocument;
begin
  Result.VarName    := '';
  Result.Expression := '';

    try
      begin
      PathFilename := GetDataDir(WORKSPACE_FILE.Dirname) + '\' + WORKSPACE_FILE.Filename;

      // Clean up any stale temp file from a previous crashed save
      if SysUtils.FileExists(PathFilename + '.tmp') then
        SysUtils.DeleteFile(PathFilename + '.tmp');

      if SysUtils.FileExists(PathFilename) then
        begin
        CSV           := TCSVDocument.Create;
        CSV.Delimiter := ',';
          try
            begin
            CSV.LoadFromFile(PathFilename);
            if CSV.RowCount > WORKSPACE_ROWS.VarName then
              Result.VarName := CSV.Cells[CSV_COL.Value, WORKSPACE_ROWS.VarName];
            if CSV.RowCount > WORKSPACE_ROWS.Expression then
              Result.Expression := CSV.Cells[CSV_COL.Value, WORKSPACE_ROWS.Expression];
            end;
          finally
            begin
            CSV.Free;
            end;
          end;
        end;
      end;
    except
      // Load is best-effort; return empty defaults on any error
    end;
end;

procedure SaveWindowPos(const Left, Top, Width, Height: Integer);
var
  CSV:          TCSVDocument;
  PathFilename: String;
  TmpFilename:  String;
begin
    try
      begin
      PathFilename := ForceDataDir(WINPOS_FILE.Dirname) + '\' + WINPOS_FILE.Filename;
      TmpFilename  := PathFilename + '.tmp';

      CSV           := TCSVDocument.Create;
      CSV.Delimiter := ',';
        try
          begin
          CSV.Cells[CSV_COL.Key,   WINPOS_ROWS.Left]   := 'left';
          CSV.Cells[CSV_COL.Value, WINPOS_ROWS.Left]   := IntToStr(Left);
          CSV.Cells[CSV_COL.Key,   WINPOS_ROWS.Top]    := 'top';
          CSV.Cells[CSV_COL.Value, WINPOS_ROWS.Top]    := IntToStr(Top);
          CSV.Cells[CSV_COL.Key,   WINPOS_ROWS.Width]  := 'width';
          CSV.Cells[CSV_COL.Value, WINPOS_ROWS.Width]  := IntToStr(Width);
          CSV.Cells[CSV_COL.Key,   WINPOS_ROWS.Height] := 'height';
          CSV.Cells[CSV_COL.Value, WINPOS_ROWS.Height] := IntToStr(Height);
          CSV.SaveToFile(TmpFilename);
          end;
        finally
          begin
          CSV.Free;
          end;
        end;

      if not MoveFileEx(PChar(TmpFilename), PChar(PathFilename), MOVEFILE_REPLACE_EXISTING) then
        begin
        SysUtils.DeleteFile(TmpFilename);
        end;
      end;
    except
      // Save is best-effort; never surface errors to the user
    end;
end;

function LoadWindowPos: TWindowPos;
var
  PathFilename: String;
  CSV:          TCSVDocument;
begin
  Result.Left   := 0;
  Result.Top    := 0;
  Result.Width  := 0;
  Result.Height := 0;

    try
      begin
      PathFilename := GetDataDir(WINPOS_FILE.Dirname) + '\' + WINPOS_FILE.Filename;

      // Clean up any stale temp file from a previous crashed save
      if SysUtils.FileExists(PathFilename + '.tmp') then
        SysUtils.DeleteFile(PathFilename + '.tmp');

      if SysUtils.FileExists(PathFilename) then
        begin
        CSV           := TCSVDocument.Create;
        CSV.Delimiter := ',';
          try
            begin
            CSV.LoadFromFile(PathFilename);
            if CSV.RowCount > WINPOS_ROWS.Left   then Result.Left   := StrToIntDef(CSV.Cells[CSV_COL.Value, WINPOS_ROWS.Left],   0);
            if CSV.RowCount > WINPOS_ROWS.Top    then Result.Top    := StrToIntDef(CSV.Cells[CSV_COL.Value, WINPOS_ROWS.Top],    0);
            if CSV.RowCount > WINPOS_ROWS.Width  then Result.Width  := StrToIntDef(CSV.Cells[CSV_COL.Value, WINPOS_ROWS.Width],  0);
            if CSV.RowCount > WINPOS_ROWS.Height then Result.Height := StrToIntDef(CSV.Cells[CSV_COL.Value, WINPOS_ROWS.Height], 0);
            end;
          finally
            begin
            CSV.Free;
            end;
          end;
        end;
      end;
    except
      // Load is best-effort; return zeroed defaults on any error
    end;
end;

function AdjustWindowPos(const WP: TWindowPos): TWindowPos;
var
  Monitor:  TMonitor;
  WorkArea: TRect;
  Center:   TPoint;
begin
  Result := WP;

  if (WP.Width <= 0) or (WP.Height <= 0) then
    Exit;

  // Find the monitor whose work area is nearest to the window centre
  Center.X := WP.Left + WP.Width  div 2;
  Center.Y := WP.Top  + WP.Height div 2;
  Monitor  := Screen.MonitorFromPoint(Center);
  WorkArea := Monitor.WorkareaRect;

  // Clamp position so the window fits entirely within the work area
  Result.Left := EnsureRange(WP.Left, WorkArea.Left, Max(WorkArea.Left, WorkArea.Right  - WP.Width));
  Result.Top  := EnsureRange(WP.Top,  WorkArea.Top,  Max(WorkArea.Top,  WorkArea.Bottom - WP.Height));
end;

end.
