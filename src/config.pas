unit Config;

{$mode ObjFPC}
{$H+}
{$modeswitch nestedprocvars}
{$inline ON}

interface

type
  TDataFile = record
    Dirname, Filename: String;
  end;

const
  { The Debug build mode defines DEVELOP: it runs side by side with the release build,
    with its own executable, single-instance lock, data folder and autorun entry }
  {$IFDEF DEVELOP}
  APP_NAME  = 'calc2plus3-dev';
  APP_TITLE = '2 + 3 (dev)';

  APP_WIDE_LOCK_NAME = 'bfcdc1e2-2816-4479-bed9-eb8b3148ea38';
  {$ELSE}
  APP_NAME  = 'calc2plus3';
  APP_TITLE = '2 + 3';

  APP_WIDE_LOCK_NAME = '58f158a7-f385-43e2-b391-58e3136bec19';
  {$ENDIF}

  DATA_DIR                = APP_NAME;
  HISTORY_FILE: TDataFile  = (Dirname: DATA_DIR; Filename: 'history.2p3');
  VARS_FILE: TDataFile     = (Dirname: DATA_DIR; Filename: 'variables.2p3');
  SETTINGS_FILE: TDataFile = (Dirname: DATA_DIR; Filename: 'settings.ini');
  LOG_FILE: TDataFile      = (Dirname: DATA_DIR; Filename: 'calc2plus3.log');

implementation

end.
