unit ExprService;

{$mode ObjFPC}
{$H+}

interface

function Calculate(Expression: String): Double;
procedure RemoveVariable(const Name: String);
procedure UpsertVariable(const Name: String; const Value: Double);

implementation

uses
  SysUtils, RegExpr, FPExprPars;

var
  Parser: TFPExpressionParser;

function IsValidVariableName(const S: String): Boolean;
var
  RE: TRegExpr;
begin
  RE := TRegExpr.Create;
    try
      begin
      RE.Expression := '^[A-Za-z_][A-Za-z0-9_]*$';
      Result        := RE.Exec(S);
      end;
    finally
      begin
      RE.Free;
      end;
    end;
end;

procedure RemoveVariable(const Name: String);
var
  VarIdx: Integer;
begin
  VarIdx := Parser.Identifiers.IndexOfIdentifier(Name);

  if VarIdx >= 0 then
    begin
    Parser.Identifiers.Delete(VarIdx);
    { Clear Parser cache }
    Parser.Expression := '0';
    Parser.Evaluate;
    end;
end;

procedure UpsertVariable(const Name: String; const Value: Double);
var
  VarObj: TFPExprIdentifierDef;
begin
  if not IsValidVariableName(Name) then
    begin
    raise EExprParser.Create('Wrong variable name');
    end;

  VarObj := Parser.Identifiers.FindIdentifier(Name);
  if VarObj <> nil then
    begin
    VarObj.AsFloat := Value;
    end
  else
    begin
    Parser.Identifiers.AddFloatVariable(Name, Value);
    end;
end;

function Calculate(Expression: String): Double;
var
  ParserResult: TFPExpressionResult;
begin
  Parser.Expression := Expression;
  ParserResult      := Parser.Evaluate;
  case ParserResult.ResultType of
    rtInteger:
      begin
      Result := ParserResult.ResInteger;
      end;
    rtFloat:
      begin
      Result := ParserResult.ResFloat;
      end;
    else
      begin
      raise EExprParser.Create('Unsupported type of the result');
      end;
    end;
end;

initialization
  Parser          := TFPExpressionParser.Create(nil);
  Parser.Builtins := [bcMath];

finalization
  FreeAndNil(Parser);

end.
