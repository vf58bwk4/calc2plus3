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
    Modifiers, VirtualKey: UINT;
  end;

const
  APP_NAME  = 'calc2plus3';
  APP_TITLE = '2 + 3';

  DATA_DIR                = APP_NAME;
  HISTORY_FILE: TDataFile   = (Dirname: DATA_DIR; Filename: 'history.2p3');
  VARS_FILE: TDataFile      = (Dirname: DATA_DIR; Filename: 'variables.2p3');
  WORKSPACE_FILE: TDataFile = (Dirname: DATA_DIR; Filename: 'workspace.2p3');
  WINPOS_FILE: TDataFile    = (Dirname: DATA_DIR; Filename: 'winpos.2p3');
  LOG_FILE: TDataFile       = (Dirname: DATA_DIR; Filename: 'calc2plus3.log');

  HOT_KEY: THotKey = (Modifiers: MOD_ALT; VirtualKey: VK_K);

implementation

end.
