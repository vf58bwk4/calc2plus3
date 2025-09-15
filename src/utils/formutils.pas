unit FormUtils;

{$mode ObjFPC}
{$H+}
{$inline ON}

interface

uses
  Classes, StdCtrls, Grids, Forms;

type
  TVK_KeyCode    = 0..254;
  TVK_KeyCodeSet = set of TVK_KeyCode;

procedure DebugLog(const Msg: String);

procedure LoadStringGridFromCSV(Grid: TStringGrid; const Filename: String; const Delimiter: Char = ',');
procedure SaveStringGridToCSV(Grid: TStringGrid; const Filename: String; const Delimiter: Char = ',');

function GetDataDir(Dir: String): String;
function ForceDataDir(Dir: String): String;

function IsTopMostWindow(AForm: TForm): Boolean;

function IsKeyCombinationMatch(var Key: Word; const Mods: TShiftState; const ExpectedKeys: TVK_KeyCodeSet; const ExpectedMods: TShiftState): Boolean;
function CheckModsState(const Mods, ExpectedMods: TShiftState): Boolean;

procedure SetEditMargins(Edit: TEdit; LeftPad, RightPad: Integer);
procedure SetEditCuebanner(Edit: TEdit; Cuebanner: String);

function FindRowByCol0Value(Grid: TStringGrid; const Col0Value: String; out aRow: Integer): Boolean;

procedure StringGridMouseWheelDown(Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean);
procedure StringGridMouseWheelUp(Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean);


implementation

uses
  SysUtils, Windows, ShlObj, CsvDocument;

const
  EM_SETCUEBANNER = $1501;

  SHIFTSTATES_ALL: TShiftState = [Low(TShiftStateEnum)..High(TShiftStateEnum)];

procedure DebugLog(const Msg: String);
var
  LogFile: TextFile;
  LogPath: String;
begin
  LogPath := ForceDataDir('2plus3') + '\' + 'debug.log';

  AssignFile(LogFile, LogPath);
  if FileExists(LogPath) then
    begin
    Append(LogFile);
    end
  else
    begin
    Rewrite(LogFile);
    end;

  Writeln(LogFile, FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) + ' - ' + Msg);
  CloseFile(LogFile);
end;

procedure LoadStringGridFromCSV(Grid: TStringGrid; const Filename: String; const Delimiter: Char);
var
  CSV:      TCSVDocument;
  Row, Col: Integer;
begin
  if not FileExists(Filename) then
    begin
    Exit;
    end;

  CSV           := TCSVDocument.Create;
  CSV.Delimiter := Delimiter;
    try
      begin
      CSV.LoadFromFile(Filename);

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
end;

procedure SaveStringGridToCSV(Grid: TStringGrid; const Filename: String; const Delimiter: Char);
var
  CSV:      TCSVDocument;
  Row, Col: Integer;
begin
  CSV           := TCSVDocument.Create;
  CSV.Delimiter := Delimiter;
    try
      begin
      for Row := 0 to Grid.RowCount - Grid.FixedRows - 1 do
        begin
        for Col := 0 to Grid.ColCount - Grid.FixedCols - 1 do
          begin
          CSV.Cells[Col, Row] := Grid.Cells[Grid.FixedCols + Col, Grid.FixedRows + Row];
          end;
        end;
      CSV.SaveToFile(Filename);
      end;
    finally
      begin
      CSV.Free;
      end;
    end;
end;

function GetDataDir(Dir: String): String;
var
  Path:    array[0..MAX_PATH] of Char;
  BaseDir: String;
begin
  if SHGetFolderPath(0, CSIDL_APPDATA, 0, 0, Path) <> S_OK then
    begin
    raise Exception.Create('Could not get AppData\Roaming folder');
    end;

  BaseDir := IncludeTrailingPathDelimiter(Path);
  Result  := BaseDir + Dir;
end;


function ForceDataDir(Dir: String): String;
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

function IsTopMostWindow(AForm: TForm): Boolean; inline;
begin
  Result := (GetForegroundWindow = AForm.Handle);
end;

function IsKeyCombinationMatch(var Key: Word; const Mods: TShiftState; const ExpectedKeys: TVK_KeyCodeSet; const ExpectedMods: TShiftState): Boolean;
begin
  Result := (Key in ExpectedKeys) and CheckModsState(Mods, ExpectedMods);
  if Result then
    begin
    Key := 0;
    end;
end;

function CheckModsState(const Mods, ExpectedMods: TShiftState): Boolean;
var
  NotExpectedMods: TShiftState;
begin
  NotExpectedMods := SHIFTSTATES_ALL - ExpectedMods;
  Result          := (ExpectedMods * Mods = ExpectedMods) and (NotExpectedMods * Mods = []);
end;

procedure SetEditMargins(Edit: TEdit; LeftPad, RightPad: Integer); inline;
begin
  SendMessage(Edit.Handle, EM_SETMARGINS, EC_LEFTMARGIN or EC_RIGHTMARGIN, MakeLong(LeftPad, RightPad));
end;

procedure SetEditCuebanner(Edit: TEdit; Cuebanner: String); inline;
begin
  SendMessage(Edit.Handle, EM_SETCUEBANNER, WParam(0), LParam(Pwidechar(WideString(Cuebanner))));
end;

function FindRowByCol0Value(Grid: TStringGrid; const Col0Value: String; out aRow: Integer): Boolean;
var
  Row: Integer;
begin
  for Row := Grid.FixedRows to Grid.RowCount - 1 do
    begin
    if AnsiCompareText(Grid.Cells[0, Row], Col0Value) = 0 then
      begin
      aRow := Row;
      Exit(True);
      end;
    end;
  Result := False;
end;

procedure StringGridMouseWheelDown(Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean);
var
  SenderGrid: TStringGrid;
  MaxTopRow:  Integer;
begin
  SenderGrid := Sender as TStringGrid;
  MaxTopRow  := SenderGrid.RowCount - (SenderGrid.ClientHeight div SenderGrid.DefaultRowHeight);
  if SenderGrid.TopRow < MaxTopRow then
    begin
    SenderGrid.TopRow := SenderGrid.TopRow + 1;
    end;
  Handled := True;
end;

procedure StringGridMouseWheelUp(Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean);
var
  SenderGrid: TStringGrid;
begin
  SenderGrid := Sender as TStringGrid;
  if SenderGrid.TopRow > 0 then
    begin
    SenderGrid.TopRow := SenderGrid.TopRow - 1;
    end;
  Handled := True;
end;


end.
