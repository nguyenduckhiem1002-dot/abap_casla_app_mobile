@EndUserText.label: 'Tham số chuyển phân bổ'
define abstract entity ZA_PP_Transfer
{
  FromWorkerID : abap.char(8);
  ToWorkerID : abap.char(8);
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  Quantity : abap.quan(15,3);
  UnitOfMeasure : abap.unit(3);
  ExecutionDate : abap.dats;
  WorkerPassword : abap.char(255);
  ActorUserUUID : sysuuid_x16;
  SyncItemUUID : sysuuid_x16;
}
