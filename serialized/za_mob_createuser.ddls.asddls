@EndUserText.label: 'Tham số tạo tài khoản di động'
define abstract entity ZA_MOB_CreateUser {
  Username : abap.char(80);
  Password : abap.char(255);
  FullName : abap.char(120);
  Email : abap.char(255);
}
