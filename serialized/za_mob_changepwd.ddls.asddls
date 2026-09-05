@EndUserText.label: 'Tham số đổi mật khẩu di động'
define abstract entity ZA_MOB_ChangePwd {
  @EndUserText.label: 'Token truy cập'
  AccessToken : abap.char(128);
  @EndUserText.label: 'Mật khẩu hiện tại'
  CurrentPassword : abap.char(255);
  @EndUserText.label: 'Mật khẩu mới'
  NewPassword : abap.char(255);
  @EndUserText.label: 'Mã thiết bị'
  DeviceID : abap.char(120);
}
