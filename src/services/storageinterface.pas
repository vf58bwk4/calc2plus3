unit StorageInterface;

{$mode ObjFPC}
{$H+}
{$inline ON}

interface

uses
  Types;

type
  TWorkspaceState = record
    VarName:    String;
    Expression: String;
  end;

  IStorage = interface
    ['{A3B5C7D9-E1F3-4A5B-8C9D-E0F1A2B3C4D5}']
    
    function LoadWindowPos: TPoint;
    function LoadWorkspace: TWorkspaceState;
    
    procedure SaveWorkspace(const VarName, Expression: String);
    procedure SaveWindowPos(const Pos: TPoint);
    
    procedure InitializeWindowPosDebouncing;
    procedure FinalizeWindowPosDebouncing;
  end;

implementation

end.
