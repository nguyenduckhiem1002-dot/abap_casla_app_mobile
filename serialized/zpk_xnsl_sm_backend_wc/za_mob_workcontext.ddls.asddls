@EndUserText.label: 'Vị trí làm việc hiệu lực của tài khoản'
define abstract entity ZA_MOB_WorkContext
{
  _LoginResult : association to parent ZA_MOB_LoginResult;
  WorkID : abap.char(30);
  WorkName : abap.char(100);
  Plant : abap.char(4);
  WorkCenter : abap.char(8);
  BoPhan : abap.char(60);
  Location : abap.char(100);
}
