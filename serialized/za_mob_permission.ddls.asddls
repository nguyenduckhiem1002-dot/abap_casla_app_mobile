@EndUserText.label: 'Quyền chức năng của tài khoản di động'
define abstract entity ZA_MOB_Permission
{
  _LoginResult : association to parent ZA_MOB_LoginResult;
  @EndUserText.label: 'Mã chức năng'
  FuncID : abap.char(30);
  @EndUserText.label: 'Tên chức năng'
  FuncName : abap.char(120);
  @EndUserText.label: 'Phân hệ ứng dụng'
  AppModule : abap.char(50);
}
