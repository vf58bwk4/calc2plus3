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

function MakeUndoRedoState(const Text: String; const SelStart: Integer): TUndoRedoState;

procedure CommitState(const State: TUndoRedoState);
procedure RecordChange(const State: TUndoRedoState);

function Undo(out Prev: TUndoRedoState): Boolean;
function Redo(out Next: TUndoRedoState): Boolean;

procedure BeforeMutatingState;
procedure AfterMutatingState;

implementation

const
  STACK_SIZE = 100;

var
  UndoStack:  array[0..STACK_SIZE - 1] of TUndoRedoState;
  RedoStack:  array[0..STACK_SIZE - 1] of TUndoRedoState;
  UndoHead:   Integer;
  UndoCount:  Integer;
  RedoHead:   Integer;
  RedoCount:  Integer;
  Suppressed: Boolean;

  {================ Private routines ================}

procedure UndoPush(const State: TUndoRedoState); inline;
begin
  UndoStack[UndoHead] := State;
  UndoHead            := (UndoHead + 1) mod STACK_SIZE;
  if UndoCount < STACK_SIZE then
    begin
    Inc(UndoCount);
    end;
end;

function UndoPop: TUndoRedoState; inline;
begin
  UndoHead := (UndoHead - 1 + STACK_SIZE) mod STACK_SIZE;
  Result   := UndoStack[UndoHead];
  Dec(UndoCount);
end;

function UndoPeek: TUndoRedoState; inline;
begin
  Result := UndoStack[(UndoHead - 1 + STACK_SIZE) mod STACK_SIZE];
end;

procedure RedoPush(const State: TUndoRedoState); inline;
begin
  RedoStack[RedoHead] := State;
  RedoHead            := (RedoHead + 1) mod STACK_SIZE;
  if RedoCount < STACK_SIZE then
    begin
    Inc(RedoCount);
    end;
end;

function RedoPop: TUndoRedoState; inline;
begin
  RedoHead := (RedoHead - 1 + STACK_SIZE) mod STACK_SIZE;
  Result   := RedoStack[RedoHead];
  Dec(RedoCount);
end;

function CanPush(const NewText: String): Boolean; inline;
begin
  Result := (not Suppressed) and ((UndoCount = 0) or (NewText <> UndoPeek.Text));
end;

{================ Interface routines ==============}

function MakeUndoRedoState(const Text: String; const SelStart: Integer): TUndoRedoState;
begin
  Result.Text     := Text;
  Result.SelStart := SelStart;
end;

procedure CommitState(const State: TUndoRedoState);
begin
  UndoPush(State);
  RedoCount := 0;
  RedoHead  := 0;
end;

procedure RecordChange(const State: TUndoRedoState);
begin
  if CanPush(State.Text) then
    begin
    CommitState(State);
    end;
end;

function Undo(out Prev: TUndoRedoState): Boolean;
begin
  if UndoCount < 2 then
    begin
    Result := False;
    end
  else
    begin
    RedoPush(UndoPop);
    Prev   := UndoPeek;
    Result := True;
    end;
end;

function Redo(out Next: TUndoRedoState): Boolean;
begin
  if RedoCount = 0 then
    begin
    Result := False;
    end
  else
    begin
    Next := RedoPop;
    UndoPush(Next);
    Result := True;
    end;
end;

procedure BeforeMutatingState;
begin
  Suppressed := True;
end;

procedure AfterMutatingState;
begin
  Suppressed := False;
end;

end.
