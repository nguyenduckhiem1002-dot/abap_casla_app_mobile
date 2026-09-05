@EndUserText.label: 'Tham số refresh token di động'
define abstract entity ZA_MOB_Refresh {
  @EndUserText.label: 'Token làm mới'
  RefreshToken : abap.char(128);
  @EndUserText.label: 'Mã thiết bị'
  DeviceID : abap.char(120);
}
