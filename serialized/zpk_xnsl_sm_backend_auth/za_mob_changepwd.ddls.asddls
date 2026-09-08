@EndUserText.label: 'Tham số đổi mật khẩu di động'
define abstract entity ZA_MOB_ChangePwd {
  AccessToken : abap.char(128);
  CurrentPassword : abap.char(255);
  NewPassword : abap.char(255);
  DeviceID : abap.char(120);
}
