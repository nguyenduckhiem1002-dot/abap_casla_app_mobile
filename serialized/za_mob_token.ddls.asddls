@EndUserText.label: 'Tham số access token di động'
define abstract entity ZA_MOB_Token {
  @EndUserText.label: 'Token truy cập'
  AccessToken : abap.char(128);
  @EndUserText.label: 'Mã thiết bị'
  DeviceID : abap.char(120);
}
