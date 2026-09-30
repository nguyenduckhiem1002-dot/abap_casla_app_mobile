@EndUserText.label: 'Kết quả thao tác vị trí công nhân'
define abstract entity ZA_PP_PosCommandResult
{
  Status     : abap.char(20);
  WorkCenter : abap.char(8);
  PositionID : abap.char(10);
  MachineID  : abap.char(10);
  WorkerID   : abap.char(8);
  Message    : abap.char(255);
}
