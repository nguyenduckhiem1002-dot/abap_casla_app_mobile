@EndUserText.label: 'Lệnh xếp công nhân vào vị trí'
define abstract entity ZA_PP_PosTransferCmd
{
  AccessToken : abap.char(128);
  DeviceID    : abap.char(120);
  WorkCenter  : abap.char(8);
  PositionID  : abap.char(10);
  WorkerID    : abap.char(8);
}
