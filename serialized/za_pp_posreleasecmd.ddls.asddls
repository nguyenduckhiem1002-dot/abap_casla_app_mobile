@EndUserText.label: 'Lệnh cho công nhân rời vị trí'
define abstract entity ZA_PP_PosReleaseCmd
{
  AccessToken : abap.char(128);
  DeviceID    : abap.char(120);
  WorkCenter  : abap.char(8);
  PositionID  : abap.char(10);
}
