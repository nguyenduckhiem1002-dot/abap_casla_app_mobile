@EndUserText.label: 'Tham số phân bổ mới'
define abstract entity ZA_PP_InitialAssign
{
  ProductionOrder : abap.char(12);
  Operation : abap.char(4);
  ToWorkerID : abap.char(8);
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  Quantity : abap.quan(15,3);
  UnitOfMeasure : abap.unit(3);
  @EndUserText.label: 'Mã ca'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_PP_Shift', element: 'ShiftID' } }]
  ShiftID : abap.char(10);
  ExecutionDate : abap.dats;
  @EndUserText.label: 'Thời điểm thực hiện thực tế UTC'
  ExecutedAt : abap.utclong;
  AccessToken : abap.char(128);
  DeviceID : abap.char(120);
  WorkerPassword : abap.char(255);
  SyncItemUUID : sysuuid_x16;
}
