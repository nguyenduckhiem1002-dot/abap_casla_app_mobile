@EndUserText.label: 'Tham số đăng nhập di động'
define abstract entity ZA_MOB_Login {
  Username : abap.char(80);
  Password : abap.char(255);
  DeviceID : abap.char(120);
}
