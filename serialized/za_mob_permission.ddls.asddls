@EndUserText.label: 'Quyền chức năng của tài khoản di động'
define abstract entity ZA_MOB_Permission
{
  _LoginResult : association to parent ZA_MOB_LoginResult;
  FuncID : abap.char(30);
  FuncName : abap.char(120);
  Module : abap.char(50);
}
