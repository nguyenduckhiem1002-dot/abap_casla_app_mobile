@EndUserText.label: 'Tham số tạo tài khoản di động'
define abstract entity ZA_MOB_CreateUser {
  Username : abap.char(80);
  Password : abap.char(255);
  FullName : abap.char(120);
  Email : abap.char(255);
  WorkerID : abap.char(8);
  @EndUserText.label: 'Chức danh ban đầu (tùy chọn)'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_MOB_Role_VH', element: 'RoleID' } }]
  RoleID : abap.char(20);
}
