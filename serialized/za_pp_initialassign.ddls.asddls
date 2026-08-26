@EndUserText.label: 'Tham số phân bổ mới'
define abstract entity ZA_PP_InitialAssign
{
  ProductionOrder : abap.char(12);
  Operation : abap.char(4);
  ToWorkerID : abap.char(8);
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  Quantity : abap.quan(15,3);
  UnitOfMeasure : abap.unit(3);
  ExecutionDate : abap.dats;
  AccessToken : abap.char(128);
  DeviceID : abap.char(120);
  WorkerPassword : abap.char(255);
  SyncItemUUID : sysuuid_x16;
}
