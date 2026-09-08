@EndUserText.label: 'Tham số tạo tài khoản di động'
define abstract entity ZA_MOB_CreateUser {
  @EndUserText.label: 'Tên đăng nhập'
  Username : abap.char(80);
  @EndUserText.label: 'Mật khẩu'
  Password : abap.char(255);
  @EndUserText.label: 'Họ và tên'
  FullName : abap.char(120);
  @EndUserText.label: 'Email'
  Email : abap.char(255);
  @EndUserText.label: 'Mã nhân công'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_PP_Worker_VH', element: 'WorkerID' } }]
  WorkerID : abap.char(8);
  @EndUserText.label: 'Chức danh ban đầu (tùy chọn)'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_MOB_Role_VH', element: 'RoleID' } }]
  RoleID : abap.char(20);
}
