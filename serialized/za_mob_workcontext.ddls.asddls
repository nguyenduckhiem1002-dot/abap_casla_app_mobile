@EndUserText.label: 'Vị trí làm việc hiệu lực của tài khoản'
define abstract entity ZA_MOB_WorkContext
{
  _LoginResult : association to parent ZA_MOB_LoginResult;
  @EndUserText.label: 'Work ID'
  WorkID : abap.char(30);
  @EndUserText.label: 'Tên vị trí làm việc'
  WorkName : abap.char(100);
  @EndUserText.label: 'Nhà máy'
  Plant : abap.char(4);
  @EndUserText.label: 'Trung tâm làm việc'
  WorkCenter : abap.char(8);
  @EndUserText.label: 'Bộ phận'
  BoPhan : abap.char(60);
  @EndUserText.label: 'Địa điểm'
  Location : abap.char(100);
}
