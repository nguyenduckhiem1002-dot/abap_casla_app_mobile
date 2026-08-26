@EndUserText.label: 'Tham số thu hồi phân bổ'
define abstract entity ZA_PP_Recall
{
  WorkerID : abap.char(8);
  @Semantics.quantity.unitOfMeasure: 'UnitOfMeasure'
  Quantity : abap.quan(15,3);
  UnitOfMeasure : abap.unit(3);
  ExecutionDate : abap.dats;
  OriginalTransactionUUID : sysuuid_x16;
  WorkerPassword : abap.char(255);
  ActorUserUUID : sysuuid_x16;
  SyncItemUUID : sysuuid_x16;
}
