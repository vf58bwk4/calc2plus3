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

procedure SetUndoRedoState(const AState: TUndoRedoState);
procedure RecordChange(const AState: TUndoRedoState);

function Undo(out Prev: TUndoRedoState): Boolean;
function Redo(out Next: TUndoRedoState): Boolean;

procedure BeforeMutatingState;
procedure AfterMutatingState;

implementation

const
  STACK_MAX = 100;

var
  UndoStack:  array[0..STACK_MAX - 1] of TUndoRedoState;
  RedoStack:  array[0..STACK_MAX - 1] of TUndoRedoState;
  UndoHead:   Integer;
  UndoCount:  Integer;
  RedoHead:   Integer;
  RedoCount:  Integer;
  Suppressed: Boolean;

  {================ Private routines ================}

procedure UndoPush(const State: TUndoRedoState); inline;
begin
  UndoStack[UndoHead] := State;
  UndoHead            := (UndoHead + 1) mod STACK_MAX;
  if UndoCount < STACK_MAX then
    begin
    Inc(UndoCount);
    end;
end;

function UndoPop: TUndoRedoState; inline;
begin
  UndoHead := (UndoHead - 1 + STACK_MAX) mod STACK_MAX;
  Result   := UndoStack[UndoHead];
  Dec(UndoCount);
end;

function UndoPeek: TUndoRedoState; inline;
begin
  Result := UndoStack[(UndoHead - 1 + STACK_MAX) mod STACK_MAX];
end;

procedure RedoPush(const State: TUndoRedoState); inline;
begin
  RedoStack[RedoHead] := State;
  RedoHead            := (RedoHead + 1) mod STACK_MAX;
  if RedoCount < STACK_MAX then
    begin
    Inc(RedoCount);
    end;
end;

function RedoPop: TUndoRedoState; inline;
begin
  RedoHead := (RedoHead - 1 + STACK_MAX) mod STACK_MAX;
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

procedure SetUndoRedoState(const AState: TUndoRedoState);
begin
  UndoPush(AState);
  RedoCount := 0;
  RedoHead  := 0;
end;

procedure RecordChange(const AState: TUndoRedoState);
begin
  if CanPush(AState.Text) then
    begin
    SetUndoRedoState(AState);
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
