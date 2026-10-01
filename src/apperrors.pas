unit AppErrors;

{$mode ObjFPC}
{$H+}
{$inline ON}

interface

uses
  SysUtils;

type
  // An expected failure: its message is meant for the user and is shown as is
  EAppError     = class(Exception);
  EInputError   = class(EAppError);
  EStorageError = class(EAppError);

implementation

end.
