@EndUserText.label: 'Tham số đăng nhập di động'
define abstract entity ZA_MOB_Login {
  @EndUserText.label: 'Tên đăng nhập'
  Username : abap.char(80);
  @EndUserText.label: 'Mật khẩu'
  Password : abap.char(255);
  @EndUserText.label: 'Mã thiết bị'
  DeviceID : abap.char(120);
}
