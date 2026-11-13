unit CSVStorage;

{$mode ObjFPC}
{$H+}
{$inline ON}

interface

uses
  Grids, Config, Storage;

type
  { Grids are kept in CSV files; window state, workspace and hotkey in one INI file }
  TCSVStorage = class(TInterfacedObject, IStorage)
  public
    procedure SaveGridToDataFile(const Grid: TStringGrid; const DataFile: TDataFile; const ConvertCell: TCellConverter);
    procedure LoadGridFromDataFile(Grid: TStringGrid; const DataFile: TDataFile; const ConvertCell: TCellConverter);

    procedure SaveWorkspace(const VarName, Expression: String; const Force: Boolean = False);
    function LoadWorkspace: TWorkspaceState;

    procedure SaveWindowState(const State: TMainWindowState; const Force: Boolean = False);
    function LoadWindowState: TMainWindowState;

    procedure SaveHotKey(const HotKey: String);
    function LoadHotKey: String;
  end;

implementation

uses
  SysUtils, Classes, Windows, IniFiles, CsvDocument, DataDir, AppErrors;

const
  CSV_DELIMITER = '|';
  TMP_SUFFIX    = '.tmp';
  UTF8_BOM      = #$EF#$BB#$BF;

  INI_WINDOW: record
      Section: String;
      Left:    String;
      Top:     String;
      Visible: String;
      end
  = (Section: 'Window'; Left: 'Left'; Top: 'Top'; Visible: 'Visible');

  INI_WORKSPACE: record
      Section:    String;
      VarName:    String;
      Expression: String;
      end
  = (Section: 'Workspace'; VarName: 'VarName'; Expression: 'Expression');

  INI_SETTINGS: record
      Section: String;
      HotKey:  String;
      end
  = (Section: 'Settings'; HotKey: 'HotKey');

  {================ Private routines ================}

function CreateCSV: TCSVDocument;
begin
  Result           := TCSVDocument.Create;
  Result.Delimiter := CSV_DELIMITER;
end;

{ With ForceDir the data folder is created if missing }
function DataFilePath(const DataFile: TDataFile; const ForceDir: Boolean): String;
begin
  if ForceDir then
    begin
    Result := ForceDataDir(DataFile.Dirname);
    end
  else
    begin
    Result := GetDataDir(DataFile.Dirname);
    end;
  Result := Result + '\' + DataFile.Filename;
end;

{ Replaces the data file with its temp copy in one step }
procedure CommitTempFile(const PathFilename: String; const DataFile: TDataFile);
var
  TmpFilename: String;
  ErrorCode:   DWORD;
begin
  TmpFilename := PathFilename + TMP_SUFFIX;
  if not MoveFileEx(PChar(TmpFilename), PChar(PathFilename), MOVEFILE_REPLACE_EXISTING) then
    begin
    ErrorCode := GetLastError;
    SysUtils.DeleteFile(TmpFilename);
    raise EStorageError.CreateFmt('Could not save file "%s": %s', [DataFile.Filename, SysErrorMessage(ErrorCode)]);
    end;
end;

{ Returns the path of the data file, or '' if it does not exist }
function FindDataFile(const DataFile: TDataFile): String;
begin
  Result := DataFilePath(DataFile, False);

  // Clean up any stale temp file left by a previous crashed save
  SysUtils.DeleteFile(Result + TMP_SUFFIX);

  if not SysUtils.FileExists(Result) then
    begin
    Result := '';
    end;
end;

{ Writes CSV to a temp file, then replaces the data file with it in one step }
procedure WriteDataFile(const CSV: TCSVDocument; const DataFile: TDataFile);
var
  PathFilename: String;
begin
  PathFilename := DataFilePath(DataFile, True);

    try
      begin
      CSV.SaveToFile(PathFilename + TMP_SUFFIX);
      end;
    except
    on E: EStreamError do
      begin
      raise EStorageError.CreateFmt('Could not save file "%s": %s', [DataFile.Filename, E.Message]);
      end;
    end;

  CommitTempFile(PathFilename, DataFile);
end;

{ Loads the data file into CSV. Returns False if the file does not exist }
function ReadDataFile(const DataFile: TDataFile; CSV: TCSVDocument): Boolean;
var
  PathFilename: String;
begin
  PathFilename := FindDataFile(DataFile);

  Result := PathFilename <> '';
  if Result then
    begin
      try
        begin
        CSV.LoadFromFile(PathFilename);
        end;
      except
      on E: EStreamError do
        begin
        raise EStorageError.CreateFmt('Could not load file "%s": %s', [DataFile.Filename, E.Message]);
        end;
      end;
    end;
end;

{ Writes Ini to a temp file as is (UTF-8, no BOM), then replaces the data file with it in one step }
procedure WriteIniFile(const Ini: TMemIniFile; const DataFile: TDataFile);
var
  PathFilename: String;
  Lines:        TStringList;
  Stream:       TFileStream;
begin
  PathFilename := DataFilePath(DataFile, True);

  Lines := TStringList.Create;
    try
      begin
      Ini.GetStrings(Lines);
        try
          begin
          Stream := TFileStream.Create(PathFilename + TMP_SUFFIX, fmCreate);
            try
              begin
              Lines.SaveToStream(Stream, True);
              end;
            finally
              begin
              Stream.Free;
              end;
            end;
          end;
        except
        on E: EStreamError do
          begin
          raise EStorageError.CreateFmt('Could not save file "%s": %s', [DataFile.Filename, E.Message]);
          end;
        end;
      end;
    finally
      begin
      Lines.Free;
      end;
    end;

  CommitTempFile(PathFilename, DataFile);
end;

{ An editor may save the file with a BOM; left in place, it hides the first section header }
procedure RemoveUTF8BOM(Lines: TStringList);
begin
  if (Lines.Count > 0) and (Copy(Lines[0], 1, Length(UTF8_BOM)) = UTF8_BOM) then
    begin
    Lines[0] := Copy(Lines[0], Length(UTF8_BOM) + 1, MaxInt);
    end;
end;

{ Loads the data file (UTF-8, with or without BOM) into a new INI, empty if the file does not exist.
  The INI has no file name, so it never writes the file by itself.
  Values are written in quotes where spaces matter: reading trims them, then strips the quotes }
function ReadIniFile(const DataFile: TDataFile): TMemIniFile;
var
  PathFilename: String;
  Lines:        TStringList;
  Stream:       TFileStream;
begin
  Result := TMemIniFile.Create('', [ifoStripQuotes]);
    try
      begin
      PathFilename := FindDataFile(DataFile);
      if PathFilename <> '' then
        begin
        Lines := TStringList.Create;
          try
            begin
              try
                begin
                Stream := TFileStream.Create(PathFilename, fmOpenRead or fmShareDenyWrite);
                  try
                    begin
                    Lines.LoadFromStream(Stream, True);
                    end;
                  finally
                    begin
                    Stream.Free;
                    end;
                  end;
                end;
              except
              on E: EStreamError do
                begin
                raise EStorageError.CreateFmt('Could not load file "%s": %s', [DataFile.Filename, E.Message]);
                end;
              end;
            RemoveUTF8BOM(Lines);
            Result.SetStrings(Lines);
            end;
          finally
            begin
            Lines.Free;
            end;
          end;
        end;
      end;
    except
      begin
      Result.Free;
      raise;
      end;
    end;
end;

function Quoted(const Value: String): String; inline;
begin
  Result := '"' + Value + '"';
end;

{================ Interface methods ===============}

procedure TCSVStorage.SaveGridToDataFile(const Grid: TStringGrid; const DataFile: TDataFile; const ConvertCell: TCellConverter);
var
  CSV:      TCSVDocument;
  Row, Col: Integer;
begin
  CSV := CreateCSV;
    try
      begin
      for Row := 0 to Grid.RowCount - Grid.FixedRows - 1 do
        begin
        for Col := 0 to Grid.ColCount - Grid.FixedCols - 1 do
          begin
          CSV.Cells[Col, Row] := ConvertCell(Grid.Cells[Grid.FixedCols + Col, Grid.FixedRows + Row]);
          end;
        end;
      WriteDataFile(CSV, DataFile);
      end;
    finally
      begin
      CSV.Free;
      end;
    end;
end;

procedure TCSVStorage.LoadGridFromDataFile(Grid: TStringGrid; const DataFile: TDataFile; const ConvertCell: TCellConverter);
var
  CSV:      TCSVDocument;
  Row, Col: Integer;
begin
  CSV := CreateCSV;
    try
      begin
      if ReadDataFile(DataFile, CSV) then
        begin
        Grid.RowCount := Grid.FixedRows + CSV.RowCount;
        for Row := 0 to CSV.RowCount - 1 do
          begin
          for Col := 0 to CSV.ColCount[Row] - 1 do
            begin
            Grid.Cells[Grid.FixedCols + Col, Grid.FixedRows + Row] := ConvertCell(CSV.Cells[Col, Row]);
            end;
          end;
        end;
      end;
    finally
      begin
      CSV.Free;
      end;
    end;
end;

procedure TCSVStorage.SaveWorkspace(const VarName, Expression: String; const Force: Boolean);
var
  Ini: TMemIniFile;
begin
  Ini := ReadIniFile(SETTINGS_FILE);
    try
      begin
      Ini.WriteString(INI_WORKSPACE.Section, INI_WORKSPACE.VarName, Quoted(VarName));
      Ini.WriteString(INI_WORKSPACE.Section, INI_WORKSPACE.Expression, Quoted(Expression));
      WriteIniFile(Ini, SETTINGS_FILE);
      end;
    finally
      begin
      Ini.Free;
      end;
    end;
end;

function TCSVStorage.LoadWorkspace: TWorkspaceState;
var
  Ini: TMemIniFile;
begin
  Ini := ReadIniFile(SETTINGS_FILE);
    try
      begin
      Result.VarName    := Ini.ReadString(INI_WORKSPACE.Section, INI_WORKSPACE.VarName, '');
      Result.Expression := Ini.ReadString(INI_WORKSPACE.Section, INI_WORKSPACE.Expression, '');
      end;
    finally
      begin
      Ini.Free;
      end;
    end;
end;

procedure TCSVStorage.SaveWindowState(const State: TMainWindowState; const Force: Boolean);
var
  Ini: TMemIniFile;
begin
  Ini := ReadIniFile(SETTINGS_FILE);
    try
      begin
      Ini.WriteInteger(INI_WINDOW.Section, INI_WINDOW.Left, State.Left);
      Ini.WriteInteger(INI_WINDOW.Section, INI_WINDOW.Top, State.Top);
      Ini.WriteBool(INI_WINDOW.Section, INI_WINDOW.Visible, State.Visible);
      WriteIniFile(Ini, SETTINGS_FILE);
      end;
    finally
      begin
      Ini.Free;
      end;
    end;
end;

{ Without a stored state (first start) the window starts hidden }
function TCSVStorage.LoadWindowState: TMainWindowState;
var
  Ini: TMemIniFile;
begin
  Ini := ReadIniFile(SETTINGS_FILE);
    try
      begin
      Result.Left    := Ini.ReadInteger(INI_WINDOW.Section, INI_WINDOW.Left, 0);
      Result.Top     := Ini.ReadInteger(INI_WINDOW.Section, INI_WINDOW.Top, 0);
      Result.Visible := Ini.ReadBool(INI_WINDOW.Section, INI_WINDOW.Visible, False);
      end;
    finally
      begin
      Ini.Free;
      end;
    end;
end;

procedure TCSVStorage.SaveHotKey(const HotKey: String);
var
  Ini: TMemIniFile;
begin
  Ini := ReadIniFile(SETTINGS_FILE);
    try
      begin
      Ini.WriteString(INI_SETTINGS.Section, INI_SETTINGS.HotKey, HotKey);
      WriteIniFile(Ini, SETTINGS_FILE);
      end;
    finally
      begin
      Ini.Free;
      end;
    end;
end;

function TCSVStorage.LoadHotKey: String;
var
  Ini: TMemIniFile;
begin
  Ini := ReadIniFile(SETTINGS_FILE);
    try
      begin
      Result := Ini.ReadString(INI_SETTINGS.Section, INI_SETTINGS.HotKey, '');
      end;
    finally
      begin
      Ini.Free;
      end;
    end;
end;

end.
