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

procedure SaveWorkspace(const VarName, Expression: String);
function LoadWorkspace: TWorkspaceState;

implementation

uses
  SysUtils, Windows, CsvDocument,
  Config, DataDir;

const
  COL_KEY        = 0;
  COL_VALUE      = 1;
  ROW_VARNAME    = 0;
  ROW_EXPRESSION = 1;

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
          CSV.Cells[COL_KEY,   ROW_VARNAME]    := 'varname';
          CSV.Cells[COL_VALUE, ROW_VARNAME]    := VarName;
          CSV.Cells[COL_KEY,   ROW_EXPRESSION] := 'expression';
          CSV.Cells[COL_VALUE, ROW_EXPRESSION] := Expression;
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
            // Row 0 is the header; data starts at row 1
            if CSV.RowCount > ROW_VARNAME then
              Result.VarName := CSV.Cells[COL_VALUE, ROW_VARNAME];
            if CSV.RowCount > ROW_EXPRESSION then
              Result.Expression := CSV.Cells[COL_VALUE, ROW_EXPRESSION];
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

end.
