@EndUserText.label: 'Tham số thu hồi phân bổ'
define abstract entity ZA_PP_Recall
{
  ProductionOrder : abap.char(12);
  Operation : abap.char(4);
  WorkerID : abap.char(8);
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  Quantity : abap.quan(15,3);
  UnitOfMeasure : abap.unit(3);
  ExecutionDate : abap.dats;
  OriginalTransactionUUID : sysuuid_x16;
  AccessToken : abap.char(128);
  DeviceID : abap.char(120);
  WorkerPassword : abap.char(255);
  SyncItemUUID : sysuuid_x16;
}
