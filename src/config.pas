unit Config;

{$mode ObjFPC}
{$H+}
{$modeswitch nestedprocvars}
{$inline ON}

interface

uses
  Windows;

type
  TDataFile = record
    Dirname, Filename: String;
  end;

  THotKey = record
    ModKey, VirtualKey: UINT;
  end;

const
  APP_NAME  = '2plus3';
  APP_TITLE = '2 + 3';

  DATA_DIR                = APP_NAME;
  HISTORY_FILE: TDataFile = (Dirname: DATA_DIR; Filename: 'history.2p3');
  VARS_FILE: TDataFile = (Dirname: DATA_DIR; Filename: 'variables.2p3');

  HOT_KEY: THotKey = (ModKey: MOD_ALT; VirtualKey: VK_K);

implementation

end.
