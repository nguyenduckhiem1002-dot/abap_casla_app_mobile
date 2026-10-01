@EndUserText.label: 'Lệnh tạo vị trí làm việc'
define abstract entity ZA_PP_PosCreateCmd
{
  AccessToken  : abap.char(128);
  DeviceID     : abap.char(120);
  WorkCenter   : abap.char(8);
  PositionID   : abap.char(10);
  MachineID    : abap.char(10);
  PositionName : abap.char(60);
}
