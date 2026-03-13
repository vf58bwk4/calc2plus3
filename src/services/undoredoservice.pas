unit UndoRedoService;

{$mode ObjFPC}
{$H+}
{$inline ON}

interface

type
  TUndoRedoState = record
    Text:     String;
    SelStart: Integer;
  end;

procedure SetExpressionState(const Text: String; const SelStart: Integer);
procedure RecordExpressionChange(const Text: String; const SelStart: Integer);

function Undo(out Prev: TUndoRedoState): Boolean;
function Redo(out Next: TUndoRedoState): Boolean;

procedure BeforeMutatingState;
procedure AfterMutatingState;

implementation

const
  STACK_MAX = 100;

var
  _UndoStack: array[0..STACK_MAX - 1] of TUndoRedoState;
  _RedoStack: array[0..STACK_MAX - 1] of TUndoRedoState;
  _UndoHead:  Integer;
  _UndoCount: Integer;
  _RedoHead:  Integer;
  _RedoCount: Integer;
  _Suppressed: Boolean;

procedure UndoPush(const State: TUndoRedoState); inline;
begin
  _UndoStack[_UndoHead] := State;
  _UndoHead  := (_UndoHead + 1) mod STACK_MAX;
  if _UndoCount < STACK_MAX then Inc(_UndoCount);
end;

function UndoPop: TUndoRedoState; inline;
begin
  _UndoHead := (_UndoHead - 1 + STACK_MAX) mod STACK_MAX;
  Result    := _UndoStack[_UndoHead];
  Dec(_UndoCount);
end;

function UndoPeek: TUndoRedoState; inline;
begin
  Result := _UndoStack[(_UndoHead - 1 + STACK_MAX) mod STACK_MAX];
end;

procedure RedoPush(const State: TUndoRedoState); inline;
begin
  _RedoStack[_RedoHead] := State;
  _RedoHead  := (_RedoHead + 1) mod STACK_MAX;
  if _RedoCount < STACK_MAX then Inc(_RedoCount);
end;

function RedoPop: TUndoRedoState; inline;
begin
  _RedoHead := (_RedoHead - 1 + STACK_MAX) mod STACK_MAX;
  Result    := _RedoStack[_RedoHead];
  Dec(_RedoCount);
end;

function CanPush(const NewText: String): Boolean; inline;
begin
  if _Suppressed then Exit(False);
  if (_UndoCount > 0) and (NewText = UndoPeek.Text) then Exit(False);
  Result := True;
end;

procedure SetExpressionState(const Text: String; const SelStart: Integer);
var
  State: TUndoRedoState;
begin
  State.Text := Text;
  State.SelStart := SelStart;
  UndoPush(State);
  _RedoCount := 0;
  _RedoHead  := 0;
end;

procedure RecordExpressionChange(const Text: String; const SelStart: Integer);
var
  State: TUndoRedoState;
begin
  if CanPush(Text) then
    begin
    State.Text := Text;
    State.SelStart := SelStart;
    UndoPush(State);
    _RedoCount := 0;
    _RedoHead  := 0;
    end;
end;

function Undo(out Prev: TUndoRedoState): Boolean;
begin
  if _UndoCount < 2 then Exit(False);
  RedoPush(UndoPop);
  Prev   := UndoPeek;
  Result := True;
end;

function Redo(out Next: TUndoRedoState): Boolean;
begin
  if _RedoCount = 0 then Exit(False);
  Next := RedoPop;
  UndoPush(Next);
  Result := True;
end;

procedure BeforeMutatingState;
begin
  _Suppressed := True;
end;

procedure AfterMutatingState;
begin
  _Suppressed := False;
end;

end.
