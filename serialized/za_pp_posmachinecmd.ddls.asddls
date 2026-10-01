@EndUserText.label: 'Lệnh đổi máy của vị trí làm việc'
define abstract entity ZA_PP_PosMachineCmd
{
  AccessToken : abap.char(128);
  DeviceID    : abap.char(120);
  WorkCenter  : abap.char(8);
  PositionID  : abap.char(10);
  // Máy mới; dòng máy cũ của vị trí tự chuyển I.
  MachineID   : abap.char(10);
}
