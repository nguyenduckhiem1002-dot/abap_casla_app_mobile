@EndUserText.label: 'Tham số kiểm tra quyền công đoạn'
define abstract entity ZA_PP_OperationAccessQuery
{
  AccessToken : abap.char(128);
  DeviceID : abap.char(120);
  @EndUserText.label: 'Lệnh sản xuất'
  ProductionOrder : abap.char(12);
  @EndUserText.label: 'Công đoạn'
  Operation : abap.char(4);
  @EndUserText.label: 'Vị trí làm việc'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_MOB_Work_VH', element: 'WorkID' } }]
  WorkID : abap.char(30);
  @EndUserText.label: 'Mã ca'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_PP_Shift', element: 'ShiftID' } }]
  ShiftID : abap.char(10);
  @EndUserText.label: 'Thời điểm quét UTC'
  ExecutedAt : abap.utclong;
}
